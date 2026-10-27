-- Version aligned with the migration recorded in Supabase development.
create or replace function private.require_patient_admin(p_patient_id uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
	caller_user_id uuid := (select auth.uid());
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

	return caller_user_id;
end;
$$;

comment on function private.require_patient_admin(uuid) is
	'Validates active patient-scoped ADMIN access without exposing patient_access rows.';

create or replace function private.list_patient_access(p_patient_id uuid)
returns table (
	access_id uuid,
	display_name text,
	access_role text,
	relationship text,
	granted_at timestamptz,
	is_current_user boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
	caller_user_id uuid;
begin
	caller_user_id := private.require_patient_admin(p_patient_id);

	return query
	select
		patient_access.id,
		coalesce(nullif(btrim(profiles.full_name), ''), 'Usuario de Senda'),
		patient_access.access_role,
		patient_access.relationship,
		patient_access.created_at,
		patient_access.user_id = caller_user_id
	from public.patient_access
	left join public.profiles on profiles.id = patient_access.user_id
	where patient_access.patient_id = p_patient_id
		and patient_access.revoked_at is null
	order by
		case patient_access.access_role when 'ADMIN' then 0 else 1 end,
		patient_access.created_at,
		patient_access.id;
end;
$$;

comment on function private.list_patient_access(uuid) is
	'Returns the minimum active access roster to an ADMIN of the same patient.';

create or replace function private.update_patient_admin_data(
	p_patient_id uuid,
	p_first_name text,
	p_last_name text
)
returns table (
	updated_patient_id uuid,
	first_name text,
	last_name text
)
language plpgsql
security definer
set search_path = ''
as $$
begin
	perform private.require_patient_admin(p_patient_id);

	if char_length(btrim(coalesce(p_first_name, ''))) not between 1 and 80 then
		raise exception 'Patient first name must contain between 1 and 80 characters.'
			using errcode = '22023';
	end if;

	if char_length(btrim(coalesce(p_last_name, ''))) not between 1 and 80 then
		raise exception 'Patient last name must contain between 1 and 80 characters.'
			using errcode = '22023';
	end if;

	return query
	update public.patients
	set
		first_name = btrim(p_first_name),
		last_name = btrim(p_last_name)
	where id = p_patient_id
	returning id, patients.first_name, patients.last_name;
end;
$$;

comment on function private.update_patient_admin_data(uuid, text, text) is
	'Updates only the minimal administrative patient fields after patient-scoped ADMIN authorization.';

create or replace function private.revoke_patient_monitor_access(p_access_id uuid)
returns table (
	revoked_access_id uuid,
	revoked_display_name text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
	target_access public.patient_access%rowtype;
	target_display_name text;
begin
	select *
	into target_access
	from public.patient_access
	where id = p_access_id
		and revoked_at is null
	for update;

	if not found then
		raise exception 'Access cannot be revoked.' using errcode = '42501';
	end if;

	perform private.require_patient_admin(target_access.patient_id);

	if target_access.access_role <> 'MONITOR' then
		raise exception 'Only active MONITOR access can be revoked.' using errcode = '22023';
	end if;

	select coalesce(nullif(btrim(profiles.full_name), ''), 'Usuario de Senda')
	into target_display_name
	from public.profiles
	where profiles.id = target_access.user_id;

	update public.patient_access
	set revoked_at = now()
	where id = target_access.id;

	return query
	select target_access.id, coalesce(target_display_name, 'Usuario de Senda');
end;
$$;

comment on function private.revoke_patient_monitor_access(uuid) is
	'Soft-revokes one active MONITOR access after patient-scoped ADMIN authorization.';

revoke execute on function private.require_patient_admin(uuid)
from public, anon, authenticated, service_role;
revoke execute on function private.list_patient_access(uuid)
from public, anon, service_role;
revoke execute on function private.update_patient_admin_data(uuid, text, text)
from public, anon, service_role;
revoke execute on function private.revoke_patient_monitor_access(uuid)
from public, anon, service_role;

grant execute on function private.list_patient_access(uuid) to authenticated;
grant execute on function private.update_patient_admin_data(uuid, text, text) to authenticated;
grant execute on function private.revoke_patient_monitor_access(uuid) to authenticated;

create or replace function public.list_patient_access(p_patient_id uuid)
returns table (
	access_id uuid,
	display_name text,
	access_role text,
	relationship text,
	granted_at timestamptz,
	is_current_user boolean
)
language sql
stable
security invoker
set search_path = ''
as $$
	select * from private.list_patient_access(p_patient_id);
$$;

create or replace function public.update_patient_admin_data(
	p_patient_id uuid,
	p_first_name text,
	p_last_name text
)
returns table (
	updated_patient_id uuid,
	first_name text,
	last_name text
)
language sql
security invoker
set search_path = ''
as $$
	select * from private.update_patient_admin_data(p_patient_id, p_first_name, p_last_name);
$$;

create or replace function public.revoke_patient_monitor_access(p_access_id uuid)
returns table (
	revoked_access_id uuid,
	revoked_display_name text
)
language sql
security invoker
set search_path = ''
as $$
	select * from private.revoke_patient_monitor_access(p_access_id);
$$;

comment on function public.list_patient_access(uuid) is
	'Lists active patient access with minimal profile data for an authorized ADMIN.';
comment on function public.update_patient_admin_data(uuid, text, text) is
	'Updates first and last name for a patient administered by the authenticated user.';
comment on function public.revoke_patient_monitor_access(uuid) is
	'Soft-revokes an active MONITOR access while preserving its audit row.';

revoke execute on function public.list_patient_access(uuid) from public, anon, service_role;
revoke execute on function public.update_patient_admin_data(uuid, text, text)
from public, anon, service_role;
revoke execute on function public.revoke_patient_monitor_access(uuid)
from public, anon, service_role;

grant execute on function public.list_patient_access(uuid) to authenticated;
grant execute on function public.update_patient_admin_data(uuid, text, text) to authenticated;
grant execute on function public.revoke_patient_monitor_access(uuid) to authenticated;
