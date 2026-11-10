alter table public.device_assignments
add column unassigned_by uuid references auth.users (id) on delete restrict;

comment on column public.device_assignments.unassigned_by is
	'ADMIN who ended this historical assignment. Null is retained for legacy rows.';

create index device_assignments_unassigned_by_idx
on public.device_assignments (unassigned_by)
where unassigned_by is not null;

create or replace function private.unassign_patient_device(
	p_patient_id uuid,
	p_assignment_id uuid
)
returns table (
	unassigned_assignment_id uuid,
	released_device_id uuid,
	unassigned_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
	caller_user_id uuid;
	target_assignment public.device_assignments%rowtype;
	action_at timestamptz;
begin
	if p_patient_id is null or p_assignment_id is null then
		raise exception 'Patient and assignment are required.' using errcode = '22023';
	end if;

	caller_user_id := private.require_patient_admin(p_patient_id);

	perform 1
	from public.patients
	where patients.id = p_patient_id
	for update;

	select device_assignments.*
	into target_assignment
	from public.device_assignments
	where device_assignments.id = p_assignment_id
		and device_assignments.patient_id = p_patient_id
		and device_assignments.unassigned_at is null
	for update;

	if target_assignment.id is null then
		raise exception 'Active device assignment was not found.' using errcode = 'P0002';
	end if;

	if exists (
		select 1
		from public.alert_episodes
		where alert_episodes.patient_id = p_patient_id
			and alert_episodes.status = 'OPEN'
	) then
		raise exception 'An open alert must be resolved before the device can be unassigned.'
			using errcode = '55000';
	end if;

	action_at := clock_timestamp();

	if exists (
		select 1
		from public.planned_transfers
		where planned_transfers.patient_id = p_patient_id
			and planned_transfers.cancelled_at is null
			and planned_transfers.starts_at <= action_at
			and coalesce(planned_transfers.ended_at, planned_transfers.ends_at) > action_at
	) then
		raise exception 'An active transfer must be finished before the device can be unassigned.'
			using errcode = '55000';
	end if;

	return query
	update public.device_assignments
	set
		unassigned_at = action_at,
		unassigned_by = caller_user_id
	where device_assignments.id = target_assignment.id
		and device_assignments.unassigned_at is null
	returning
		device_assignments.id,
		device_assignments.device_id,
		device_assignments.unassigned_at;
end;
$$;

comment on function private.unassign_patient_device(uuid, uuid) is
	'Ends one active device assignment after ADMIN authorization while preserving its history.';

revoke execute on function private.unassign_patient_device(uuid, uuid)
from public, anon, service_role;
grant execute on function private.unassign_patient_device(uuid, uuid) to authenticated;

create or replace function public.unassign_patient_device(
	p_patient_id uuid,
	p_assignment_id uuid
)
returns table (
	unassigned_assignment_id uuid,
	released_device_id uuid,
	unassigned_at timestamptz
)
language sql
security invoker
set search_path = ''
as $$
	select *
	from private.unassign_patient_device(p_patient_id, p_assignment_id);
$$;

comment on function public.unassign_patient_device(uuid, uuid) is
	'Authenticated API for ending a patient device assignment without deleting historical data.';

revoke execute on function public.unassign_patient_device(uuid, uuid)
from public, anon, service_role;
grant execute on function public.unassign_patient_device(uuid, uuid) to authenticated;
