create table public.devices (
	id uuid primary key default gen_random_uuid(),
	serial_number text not null unique,
	device_kind text not null default 'SIMULATED',
	created_at timestamptz not null default now(),
	constraint devices_serial_number_valid check (
		serial_number = upper(btrim(serial_number))
		and serial_number ~ '^[A-Z0-9][A-Z0-9-]{7,63}$'
	),
	constraint devices_kind_valid check (device_kind in ('SIMULATED', 'PHYSICAL'))
);

comment on table public.devices is
	'Device inventory. The MVP only registers preexisting simulated serial numbers.';
comment on column public.devices.serial_number is
	'Normalized public device identifier for simulated onboarding; it is not a secret.';

create table public.device_assignments (
	id uuid primary key default gen_random_uuid(),
	device_id uuid not null references public.devices (id) on delete restrict,
	patient_id uuid not null references public.patients (id) on delete restrict,
	assigned_at timestamptz not null default now(),
	unassigned_at timestamptz,
	constraint device_assignments_dates_valid check (
		unassigned_at is null or unassigned_at >= assigned_at
	)
);

comment on table public.device_assignments is
	'Historical device-to-patient links. Locations will reference this assignment, not only a device or patient.';

create unique index device_assignments_one_active_device_idx
on public.device_assignments (device_id)
where unassigned_at is null;

create unique index device_assignments_one_active_patient_idx
on public.device_assignments (patient_id)
where unassigned_at is null;

create index device_assignments_device_history_idx
on public.device_assignments (device_id, assigned_at desc);

create index device_assignments_patient_history_idx
on public.device_assignments (patient_id, assigned_at desc);

alter table public.devices enable row level security;
alter table public.device_assignments enable row level security;

revoke all on table public.devices, public.device_assignments from anon, authenticated;
grant select on table public.devices, public.device_assignments to authenticated;

create policy "device_assignments_select_authorized"
on public.device_assignments
for select
to authenticated
using (
	exists (
		select 1
		from public.patient_access
		where patient_access.patient_id = device_assignments.patient_id
			and patient_access.user_id = (select auth.uid())
			and patient_access.revoked_at is null
	)
);

create policy "devices_select_authorized"
on public.devices
for select
to authenticated
using (
	exists (
		select 1
		from public.device_assignments
		join public.patient_access
			on patient_access.patient_id = device_assignments.patient_id
		where device_assignments.device_id = devices.id
			and patient_access.user_id = (select auth.uid())
			and patient_access.revoked_at is null
	)
);

create or replace function private.assign_simulated_device(
	p_patient_id uuid,
	p_serial_number text
)
returns table (
	assigned_assignment_id uuid,
	assigned_device_id uuid,
	assigned_serial_number text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
	caller_user_id uuid := (select auth.uid());
	normalized_serial text := upper(btrim(coalesce(p_serial_number, '')));
	matched_device_id uuid;
	new_assignment_id uuid := gen_random_uuid();
begin
	if caller_user_id is null then
		raise exception 'Authentication is required.' using errcode = '42501';
	end if;

	if p_patient_id is null then
		raise exception 'Patient is required.' using errcode = '22023';
	end if;

	if normalized_serial !~ '^[A-Z0-9][A-Z0-9-]{7,63}$' then
		raise exception 'Serial format is invalid.' using errcode = '22023';
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

	select devices.id
	into matched_device_id
	from public.devices
	where devices.serial_number = normalized_serial
		and devices.device_kind = 'SIMULATED'
	for update;

	if matched_device_id is null then
		raise exception 'Serial is not registered.' using errcode = '22023';
	end if;

	if exists (
		select 1
		from public.device_assignments
		where device_assignments.device_id = matched_device_id
			and device_assignments.unassigned_at is null
	) then
		raise exception 'Device already has an active patient.' using errcode = '23505';
	end if;

	if exists (
		select 1
		from public.device_assignments
		where device_assignments.patient_id = p_patient_id
			and device_assignments.unassigned_at is null
	) then
		raise exception 'Patient already has an active device.' using errcode = '23505';
	end if;

	insert into public.device_assignments (id, device_id, patient_id)
	values (new_assignment_id, matched_device_id, p_patient_id);

	return query
	select new_assignment_id, matched_device_id, normalized_serial;
end;
$$;

comment on function private.assign_simulated_device(uuid, text) is
	'Assigns one pre-registered simulated device after checking patient-scoped ADMIN access.';

revoke execute on function private.assign_simulated_device(uuid, text)
from public, anon, service_role;

grant usage on schema private to authenticated;
grant execute on function private.assign_simulated_device(uuid, text) to authenticated;

create or replace function public.assign_simulated_device(
	p_patient_id uuid,
	p_serial_number text
)
returns table (
	assigned_assignment_id uuid,
	assigned_device_id uuid,
	assigned_serial_number text
)
language sql
security invoker
set search_path = ''
as $$
	select *
	from private.assign_simulated_device(p_patient_id, p_serial_number);
$$;

comment on function public.assign_simulated_device(uuid, text) is
	'Authenticated API wrapper for the simulated device assignment operation.';

revoke execute on function public.assign_simulated_device(uuid, text)
from public, anon;

grant execute on function public.assign_simulated_device(uuid, text)
to authenticated;

insert into public.devices (serial_number, device_kind)
values
	('SENDA-DEMO-001', 'SIMULATED'),
	('SENDA-DEMO-002', 'SIMULATED'),
	('SENDA-DEMO-003', 'SIMULATED');
