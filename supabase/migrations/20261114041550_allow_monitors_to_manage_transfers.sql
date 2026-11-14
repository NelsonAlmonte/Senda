create or replace function private.require_patient_transfer_manager(p_patient_id uuid)
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
		where patient_access.patient_id = p_patient_id
			and patient_access.user_id = caller_user_id
			and patient_access.access_role in ('ADMIN', 'MONITOR')
			and patient_access.revoked_at is null
	) then
		raise exception 'Active ADMIN or MONITOR access to the patient is required.'
			using errcode = '42501';
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

comment on function private.require_patient_transfer_manager(uuid) is
	'Validates active patient-scoped ADMIN or MONITOR access for planned transfer operations and rejects archived patients.';

revoke execute on function private.require_patient_transfer_manager(uuid)
from public, anon, authenticated, service_role;

comment on column public.planned_transfers.ends_at is
	'Planned end, limited to 24 hours after starts_at. An authorized ADMIN or MONITOR may extend it within that limit.';

create or replace function private.save_patient_planned_transfer(
	p_transfer_id uuid,
	p_patient_id uuid,
	p_starts_at timestamptz,
	p_ends_at timestamptz,
	p_note text
)
returns table (saved_transfer_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
	caller_user_id uuid;
	action_at timestamptz := clock_timestamp();
	normalized_note text := btrim(coalesce(p_note, ''));
	target_transfer public.planned_transfers%rowtype;
	result_transfer_id uuid;
begin
	if p_patient_id is null then
		raise exception 'Patient is required.' using errcode = '22023';
	end if;

	caller_user_id := private.require_patient_transfer_manager(p_patient_id);

	if p_starts_at is null or p_ends_at is null then
		raise exception 'Transfer start and end are required.' using errcode = '22023';
	end if;

	if p_ends_at <= p_starts_at then
		raise exception 'Transfer end must be after its start.' using errcode = '22023';
	end if;

	if p_ends_at > p_starts_at + interval '24 hours' then
		raise exception 'Transfer duration cannot exceed 24 hours.' using errcode = '22023';
	end if;

	if char_length(normalized_note) not between 1 and 500 then
		raise exception 'Transfer note must contain between 1 and 500 characters.'
			using errcode = '22023';
	end if;

	perform 1
	from public.patients
	where patients.id = p_patient_id
	for update;

	if p_transfer_id is null then
		if p_starts_at < action_at - interval '5 minutes' then
			raise exception 'A new transfer cannot start in the past.' using errcode = '22023';
		end if;
	else
		select planned_transfers.*
		into target_transfer
		from public.planned_transfers
		where planned_transfers.id = p_transfer_id
			and planned_transfers.patient_id = p_patient_id
		for update;

		if target_transfer.id is null then
			raise exception 'Transfer was not found.' using errcode = 'P0002';
		end if;

		if target_transfer.cancelled_at is not null
			or target_transfer.ended_at is not null
			or target_transfer.ends_at <= action_at then
			raise exception 'Completed or cancelled transfers cannot be edited.'
				using errcode = '22023';
		end if;

		if target_transfer.starts_at <= action_at then
			if p_starts_at <> target_transfer.starts_at then
				raise exception 'An active transfer start cannot be changed.' using errcode = '22023';
			end if;

			if p_ends_at < target_transfer.ends_at then
				raise exception 'Use the finish action to end an active transfer early.'
					using errcode = '22023';
			end if;
		elsif p_starts_at < action_at - interval '5 minutes' then
			raise exception 'A scheduled transfer cannot be moved into the past.'
				using errcode = '22023';
		end if;
	end if;

	if exists (
		select 1
		from public.planned_transfers
		where planned_transfers.patient_id = p_patient_id
			and planned_transfers.cancelled_at is null
			and (p_transfer_id is null or planned_transfers.id <> p_transfer_id)
			and tstzrange(
				planned_transfers.starts_at,
				coalesce(planned_transfers.ended_at, planned_transfers.ends_at),
				'[)'
			) && tstzrange(p_starts_at, p_ends_at, '[)')
	) then
		raise exception 'Transfer windows cannot overlap for the same patient.'
			using errcode = '23P01';
	end if;

	if p_transfer_id is null then
		insert into public.planned_transfers (
			patient_id,
			starts_at,
			ends_at,
			note,
			created_by,
			updated_by
		)
		values (
			p_patient_id,
			p_starts_at,
			p_ends_at,
			normalized_note,
			caller_user_id,
			caller_user_id
		)
		returning id into result_transfer_id;
	else
		update public.planned_transfers
		set starts_at = p_starts_at,
			ends_at = p_ends_at,
			note = normalized_note,
			updated_by = caller_user_id,
			updated_at = action_at
		where id = p_transfer_id
		returning id into result_transfer_id;
	end if;

	return query select result_transfer_id;
end;
$$;

comment on function private.save_patient_planned_transfer(uuid, uuid, timestamptz, timestamptz, text) is
	'Creates or edits a planned transfer after patient-scoped ADMIN or MONITOR authorization.';

create or replace function private.cancel_patient_planned_transfer(
	p_transfer_id uuid,
	p_patient_id uuid
)
returns table (cancelled_transfer_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
	caller_user_id uuid;
	action_at timestamptz := clock_timestamp();
	result_transfer_id uuid;
begin
	caller_user_id := private.require_patient_transfer_manager(p_patient_id);

	perform 1
	from public.patients
	where patients.id = p_patient_id
	for update;

	update public.planned_transfers
	set cancelled_at = action_at,
		cancelled_by = caller_user_id,
		updated_by = caller_user_id,
		updated_at = action_at
	where id = p_transfer_id
		and patient_id = p_patient_id
		and cancelled_at is null
		and ended_at is null
		and starts_at > action_at
	returning id into result_transfer_id;

	if result_transfer_id is null then
		raise exception 'Only a scheduled transfer can be cancelled.' using errcode = '22023';
	end if;

	return query select result_transfer_id;
end;
$$;

comment on function private.cancel_patient_planned_transfer(uuid, uuid) is
	'Cancels a scheduled transfer after patient-scoped ADMIN or MONITOR authorization.';

create or replace function private.end_patient_planned_transfer(
	p_transfer_id uuid,
	p_patient_id uuid
)
returns table (ended_transfer_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
	caller_user_id uuid;
	action_at timestamptz := clock_timestamp();
	result_transfer_id uuid;
begin
	caller_user_id := private.require_patient_transfer_manager(p_patient_id);

	perform 1
	from public.patients
	where patients.id = p_patient_id
	for update;

	update public.planned_transfers
	set ended_at = action_at,
		ended_by = caller_user_id,
		updated_by = caller_user_id,
		updated_at = action_at
	where id = p_transfer_id
		and patient_id = p_patient_id
		and cancelled_at is null
		and ended_at is null
		and starts_at <= action_at
		and ends_at > action_at
	returning id into result_transfer_id;

	if result_transfer_id is null then
		raise exception 'Only an active transfer can be finished early.' using errcode = '22023';
	end if;

	return query select result_transfer_id;
end;
$$;

comment on function private.end_patient_planned_transfer(uuid, uuid) is
	'Finishes an active transfer after patient-scoped ADMIN or MONITOR authorization.';
