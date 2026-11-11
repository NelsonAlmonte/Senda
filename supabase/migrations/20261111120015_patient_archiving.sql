alter table public.patients
add column archived_at timestamptz,
add column archived_by uuid references auth.users (id) on delete restrict,
add constraint patients_archived_pair_valid
	check ((archived_at is null) = (archived_by is null)),
add constraint patients_archived_after_creation
	check (archived_at is null or archived_at >= created_at);

comment on column public.patients.archived_at is
	'Administrative archive timestamp. Archiving preserves patient history and access rows.';
comment on column public.patients.archived_by is
	'ADMIN who archived the patient. Null while the patient is active.';

create index patients_archived_by_idx
on public.patients (archived_by)
where archived_by is not null;

alter table public.invitations
add column invalidated_at timestamptz,
add column invalidated_by uuid references auth.users (id) on delete restrict,
add constraint invitations_invalidated_pair_valid
	check ((invalidated_at is null) = (invalidated_by is null)),
add constraint invitations_invalidated_after_creation
	check (invalidated_at is null or invalidated_at >= created_at),
add constraint invitations_only_pending_invalidated
	check (invalidated_at is null or status = 'PENDING');

comment on column public.invitations.invalidated_at is
	'Permanent invalidation timestamp for a pending token without adding an EXPIRED status.';
comment on column public.invitations.invalidated_by is
	'ADMIN who invalidated the pending token by archiving its patient.';

create index invitations_invalidated_by_idx
on public.invitations (invalidated_by)
where invalidated_by is not null;

create or replace function private.require_patient_admin(p_patient_id uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
	caller_user_id uuid := (select auth.uid());
	patient_archived_at timestamptz;
begin
	if caller_user_id is null then
		raise exception 'Authentication is required.' using errcode = '42501';
	end if;

	if not exists (
		select 1
		from public.patient_access
		where patient_id = p_patient_id
			and user_id = caller_user_id
			and access_role = 'ADMIN'
			and revoked_at is null
	) then
		raise exception 'ADMIN access to the patient is required.' using errcode = '42501';
	end if;

	select patients.archived_at
	into patient_archived_at
	from public.patients
	where patients.id = p_patient_id;

	if not found then
		raise exception 'Patient was not found.' using errcode = 'P0002';
	end if;

	if patient_archived_at is not null then
		raise exception 'Patient is archived.' using errcode = '55000';
	end if;

	return caller_user_id;
end;
$$;

comment on function private.require_patient_admin(uuid) is
	'Validates active patient-scoped ADMIN access and rejects archived patients.';

create or replace function private.prevent_archived_patient_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
	target_patient_id uuid := new.patient_id;
	patient_archived_at timestamptz;
begin
	select patients.archived_at
	into patient_archived_at
	from public.patients
	where patients.id = target_patient_id
	for key share;

	if patient_archived_at is not null then
		raise exception 'Patient is archived.' using errcode = '55000';
	end if;

	return new;
end;
$$;

comment on function private.prevent_archived_patient_mutation() is
	'Prevents operational child rows from being inserted or updated for an archived patient.';

revoke execute on function private.prevent_archived_patient_mutation()
from public, anon, authenticated, service_role;

create trigger patient_access_reject_archived_patient
before insert or update on public.patient_access
for each row execute function private.prevent_archived_patient_mutation();

create trigger invitations_reject_archived_patient
before insert or update on public.invitations
for each row execute function private.prevent_archived_patient_mutation();

create trigger device_assignments_reject_archived_patient
before insert or update on public.device_assignments
for each row execute function private.prevent_archived_patient_mutation();

create trigger safe_zones_reject_archived_patient
before insert or update on public.safe_zones
for each row execute function private.prevent_archived_patient_mutation();

create trigger planned_transfers_reject_archived_patient
before insert or update on public.planned_transfers
for each row execute function private.prevent_archived_patient_mutation();

create or replace function private.archive_patient(p_patient_id uuid)
returns table (archived_patient_id uuid, archived_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
	caller_user_id uuid;
	target_patient public.patients%rowtype;
	action_at timestamptz := clock_timestamp();
begin
	if p_patient_id is null then
		raise exception 'Patient is required.' using errcode = '22023';
	end if;

	caller_user_id := private.require_patient_admin(p_patient_id);

	select patients.*
	into target_patient
	from public.patients
	where patients.id = p_patient_id
	for update;

	if target_patient.id is null then
		raise exception 'Patient was not found.' using errcode = 'P0002';
	end if;

	if target_patient.archived_at is not null then
		raise exception 'Patient is already archived.' using errcode = '55000';
	end if;

	if exists (
		select 1
		from public.device_assignments
		where device_assignments.patient_id = p_patient_id
			and device_assignments.unassigned_at is null
	) then
		raise exception 'The active device must be unassigned before the patient can be archived.'
			using errcode = '55000';
	end if;

	if exists (
		select 1
		from public.alert_episodes
		where alert_episodes.patient_id = p_patient_id
			and alert_episodes.status = 'OPEN'
	) then
		raise exception 'The open alert must be resolved before the patient can be archived.'
			using errcode = '55000';
	end if;

	if exists (
		select 1
		from public.planned_transfers
		where planned_transfers.patient_id = p_patient_id
			and planned_transfers.cancelled_at is null
			and planned_transfers.ended_at is null
			and planned_transfers.ends_at > action_at
	) then
		raise exception 'Current and scheduled transfers must finish or be cancelled before the patient can be archived.'
			using errcode = '55000';
	end if;

	update public.invitations
	set invalidated_at = action_at,
		invalidated_by = caller_user_id
	where invitations.patient_id = p_patient_id
		and invitations.status = 'PENDING'
		and invitations.invalidated_at is null;

	return query
	update public.patients
	set archived_at = action_at,
		archived_by = caller_user_id
	where patients.id = p_patient_id
		and patients.archived_at is null
	returning patients.id, patients.archived_at;
end;
$$;

comment on function private.archive_patient(uuid) is
	'Archives an unassigned patient, preserves history and access, and permanently invalidates pending invitations.';

create or replace function private.restore_patient(p_patient_id uuid)
returns table (restored_patient_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
	caller_user_id uuid := (select auth.uid());
	target_patient public.patients%rowtype;
begin
	if caller_user_id is null then
		raise exception 'Authentication is required.' using errcode = '42501';
	end if;

	if p_patient_id is null then
		raise exception 'Patient is required.' using errcode = '22023';
	end if;

	if not exists (
		select 1
		from public.patient_access
		where patient_access.patient_id = p_patient_id
			and patient_access.user_id = caller_user_id
			and patient_access.access_role = 'ADMIN'
			and patient_access.revoked_at is null
	) then
		raise exception 'ADMIN access to the patient is required.' using errcode = '42501';
	end if;

	select patients.*
	into target_patient
	from public.patients
	where patients.id = p_patient_id
	for update;

	if target_patient.id is null then
		raise exception 'Patient was not found.' using errcode = 'P0002';
	end if;

	if target_patient.archived_at is null then
		raise exception 'Patient is not archived.' using errcode = '55000';
	end if;

	return query
	update public.patients
	set archived_at = null,
		archived_by = null
	where patients.id = p_patient_id
		and patients.archived_at is not null
	returning patients.id;
end;
$$;

comment on function private.restore_patient(uuid) is
	'Restores an archived patient without recreating device assignments or invalidated invitations.';

revoke execute on function private.archive_patient(uuid)
from public, anon, authenticated, service_role;
revoke execute on function private.restore_patient(uuid)
from public, anon, authenticated, service_role;
grant execute on function private.archive_patient(uuid) to authenticated;
grant execute on function private.restore_patient(uuid) to authenticated;

create or replace function public.archive_patient(p_patient_id uuid)
returns table (archived_patient_id uuid, archived_at timestamptz)
language sql
security invoker
set search_path = ''
as $$
	select * from private.archive_patient(p_patient_id);
$$;

create or replace function public.restore_patient(p_patient_id uuid)
returns table (restored_patient_id uuid)
language sql
security invoker
set search_path = ''
as $$
	select * from private.restore_patient(p_patient_id);
$$;

comment on function public.archive_patient(uuid) is
	'Authenticated API for archiving an eligible patient without deleting historical data.';
comment on function public.restore_patient(uuid) is
	'Authenticated API for restoring an archived patient without reviving prior invitations.';

revoke execute on function public.archive_patient(uuid)
from public, anon, service_role;
revoke execute on function public.restore_patient(uuid)
from public, anon, service_role;
grant execute on function public.archive_patient(uuid) to authenticated;
grant execute on function public.restore_patient(uuid) to authenticated;

create or replace function private.preview_patient_access_code(p_code text)
returns table (
	patient_first_name text,
	patient_last_name text,
	group_name text,
	group_type text
)
language plpgsql
security definer
set search_path = ''
as $$
begin
	if (select auth.uid()) is null then
		raise exception 'Authentication is required.' using errcode = '42501';
	end if;

	return query
	select patients.first_name, patients.last_name, groups.name, groups.type
	from public.invitations
	join public.patients on patients.id = invitations.patient_id
	join public.groups on groups.id = patients.group_id
	where invitations.token_hash = private.hash_access_code(p_code)
		and invitations.status = 'PENDING'
		and invitations.invalidated_at is null
		and patients.archived_at is null;
end;
$$;

create or replace function private.accept_patient_access_code(p_code text)
returns table (accepted_patient_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
	caller_user_id uuid := (select auth.uid());
	matched_patient_id uuid;
	matched_invitation public.invitations%rowtype;
begin
	if caller_user_id is null then
		raise exception 'Authentication is required.' using errcode = '42501';
	end if;

	select invitations.patient_id
	into matched_patient_id
	from public.invitations
	where invitations.token_hash = private.hash_access_code(p_code)
		and invitations.status = 'PENDING'
		and invitations.invalidated_at is null;

	if matched_patient_id is null then
		raise exception 'Access code is invalid or already used.' using errcode = '22023';
	end if;

	perform 1
	from public.patients
	where patients.id = matched_patient_id
		and patients.archived_at is null
	for key share;

	if not found then
		raise exception 'Access code is invalid or already used.' using errcode = '22023';
	end if;

	select invitations.*
	into matched_invitation
	from public.invitations
	where invitations.token_hash = private.hash_access_code(p_code)
		and invitations.status = 'PENDING'
		and invitations.invalidated_at is null
		and invitations.patient_id = matched_patient_id
	for update of invitations;

	if not found then
		raise exception 'Access code is invalid or already used.' using errcode = '22023';
	end if;

	if exists (
		select 1
		from public.patient_access
		where patient_id = matched_invitation.patient_id
			and user_id = caller_user_id
			and revoked_at is null
	) then
		raise exception 'User already has active access to the patient.' using errcode = '23505';
	end if;

	insert into public.patient_access (patient_id, user_id, access_role)
	values (matched_invitation.patient_id, caller_user_id, 'MONITOR');

	update public.invitations
	set status = 'ACCEPTED', accepted_at = now()
	where id = matched_invitation.id;

	return query select matched_invitation.patient_id;
end;
$$;
