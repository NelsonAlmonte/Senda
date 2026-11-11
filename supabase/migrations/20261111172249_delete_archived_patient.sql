create or replace function private.delete_archived_patient(p_patient_id uuid)
returns table (deleted_patient_id uuid)
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
		raise exception 'Patient must be archived before permanent deletion.' using errcode = '55000';
	end if;

	if exists (
		select 1
		from public.device_assignments
		where device_assignments.patient_id = p_patient_id
			and device_assignments.unassigned_at is null
	) then
		raise exception 'Archived patient still has an active device assignment.' using errcode = '55000';
	end if;

	delete from public.alert_episodes
	where alert_episodes.patient_id = p_patient_id;

	delete from public.locations
	where locations.device_assignment_id in (
		select device_assignments.id
		from public.device_assignments
		where device_assignments.patient_id = p_patient_id
	);

	delete from public.device_assignments
	where device_assignments.patient_id = p_patient_id;

	delete from public.planned_transfers
	where planned_transfers.patient_id = p_patient_id;

	return query
	delete from public.patients
	where patients.id = p_patient_id
	returning patients.id;
end;
$$;

comment on function private.delete_archived_patient(uuid) is
	'Permanently deletes an archived patient and all patient-scoped history while preserving group, device inventory, and Auth users.';

revoke execute on function private.delete_archived_patient(uuid)
from public, anon, authenticated, service_role;
grant execute on function private.delete_archived_patient(uuid) to authenticated;

create or replace function public.delete_archived_patient(p_patient_id uuid)
returns table (deleted_patient_id uuid)
language sql
security invoker
set search_path = ''
as $$
	select * from private.delete_archived_patient(p_patient_id);
$$;

comment on function public.delete_archived_patient(uuid) is
	'Authenticated API for permanently deleting an archived patient after patient-scoped ADMIN authorization.';

revoke execute on function public.delete_archived_patient(uuid)
from public, anon, service_role;
grant execute on function public.delete_archived_patient(uuid) to authenticated;
