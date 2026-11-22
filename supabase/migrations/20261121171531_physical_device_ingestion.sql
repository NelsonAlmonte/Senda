-- Physical GPS devices: private hardware identifiers, ADMIN assignment and
-- trusted-service location ingestion. Additive: the simulator flow is unchanged.

-- The hardware identifier (IMEI or equivalent) lives in the private schema so it
-- is never readable through PostgREST by patient-scoped users.
create table private.device_hardware_ids (
	device_id uuid primary key references public.devices (id) on delete restrict,
	hardware_id text not null unique,
	created_at timestamptz not null default now(),
	constraint device_hardware_ids_format_valid check (
		hardware_id = upper(btrim(hardware_id))
		and hardware_id ~ '^[A-Z0-9][A-Z0-9-]{7,31}$'
	)
);

comment on table private.device_hardware_ids is
	'Private mapping from a physical device to the identifier its tracker reports (IMEI). Not exposed to the PWA.';

alter table private.device_hardware_ids enable row level security;
revoke all on table private.device_hardware_ids from public, anon, authenticated, service_role;

grant usage on schema private to service_role;

-- Registers one physical device in the inventory. Trusted operators only.
create or replace function private.register_physical_device(
	p_serial_number text,
	p_hardware_id text
)
returns table (
	registered_device_id uuid,
	registered_serial_number text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
	normalized_serial text := upper(btrim(coalesce(p_serial_number, '')));
	normalized_hardware_id text := upper(btrim(coalesce(p_hardware_id, '')));
	new_device_id uuid;
begin
	if normalized_serial !~ '^[A-Z0-9][A-Z0-9-]{7,63}$' then
		raise exception 'Serial format is invalid.' using errcode = '22023';
	end if;

	if normalized_hardware_id !~ '^[A-Z0-9][A-Z0-9-]{7,31}$' then
		raise exception 'Hardware identifier format is invalid.' using errcode = '22023';
	end if;

	insert into public.devices (serial_number, device_kind)
	values (normalized_serial, 'PHYSICAL')
	returning id into new_device_id;

	insert into private.device_hardware_ids (device_id, hardware_id)
	values (new_device_id, normalized_hardware_id);

	return query
	select new_device_id, normalized_serial;
end;
$$;

comment on function private.register_physical_device(text, text) is
	'Adds a PHYSICAL device and its private hardware identifier to the inventory. Service role only.';

revoke execute on function private.register_physical_device(text, text)
from public, anon, authenticated;
grant execute on function private.register_physical_device(text, text) to service_role;

create or replace function public.register_physical_device(
	p_serial_number text,
	p_hardware_id text
)
returns table (
	registered_device_id uuid,
	registered_serial_number text
)
language sql
security invoker
set search_path = ''
as $$
	select *
	from private.register_physical_device(p_serial_number, p_hardware_id);
$$;

comment on function public.register_physical_device(text, text) is
	'Service-role wrapper for registering a physical device in the inventory.';

revoke execute on function public.register_physical_device(text, text)
from public, anon, authenticated;
grant execute on function public.register_physical_device(text, text) to service_role;

-- Assigns a registered physical device to a patient. Mirrors the simulated flow:
-- patient-scoped ADMIN access, one active device per patient and per device.
create or replace function private.assign_physical_device(
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
		and devices.device_kind = 'PHYSICAL'
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

comment on function private.assign_physical_device(uuid, text) is
	'Assigns one registered physical device after checking patient-scoped ADMIN access.';

revoke execute on function private.assign_physical_device(uuid, text)
from public, anon, service_role;
grant execute on function private.assign_physical_device(uuid, text) to authenticated;

create or replace function public.assign_physical_device(
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
	from private.assign_physical_device(p_patient_id, p_serial_number);
$$;

comment on function public.assign_physical_device(uuid, text) is
	'Authenticated API wrapper for the physical device assignment operation.';

revoke execute on function public.assign_physical_device(uuid, text)
from public, anon;
grant execute on function public.assign_physical_device(uuid, text) to authenticated;

-- Persists one reading reported by a physical tracker. The caller is the trusted
-- ingestion service, never a browser. The patient is derived from the active
-- assignment of the device, so no client-supplied patient or role is trusted.
-- Domain conditions return an outcome instead of raising, so the gateway can
-- acknowledge permanent rejections without triggering retry storms.
create or replace function private.ingest_device_location(
	p_hardware_id text,
	p_event_id uuid,
	p_latitude double precision,
	p_longitude double precision,
	p_accuracy_m double precision,
	p_recorded_at timestamptz
)
returns table (
	ingest_outcome text,
	location_id bigint,
	location_device_assignment_id uuid,
	location_recorded_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
	normalized_hardware_id text := upper(btrim(coalesce(p_hardware_id, '')));
	matched_device_id uuid;
	matched_assignment_id uuid;
	matched_assigned_at timestamptz;
	new_location_id bigint;
	existing_location public.locations%rowtype;
begin
	if normalized_hardware_id !~ '^[A-Z0-9][A-Z0-9-]{7,31}$' then
		raise exception 'Hardware identifier is invalid.' using errcode = '22023';
	end if;

	if p_event_id is null then
		raise exception 'Event identifier is required.' using errcode = '22023';
	end if;

	if p_latitude is null or p_latitude not between -90 and 90 then
		raise exception 'Latitude is invalid.' using errcode = '22023';
	end if;

	if p_longitude is null or p_longitude not between -180 and 180 then
		raise exception 'Longitude is invalid.' using errcode = '22023';
	end if;

	if p_accuracy_m is not null and (
		p_accuracy_m < 0
		or p_accuracy_m >= 'Infinity'::double precision
	) then
		raise exception 'Accuracy is invalid.' using errcode = '22023';
	end if;

	if p_recorded_at is null then
		raise exception 'Recorded timestamp is required.' using errcode = '22023';
	end if;

	if p_recorded_at > clock_timestamp() + interval '1 minute' then
		raise exception 'Recorded timestamp is too far in the future.' using errcode = '22023';
	end if;

	select device_hardware_ids.device_id
	into matched_device_id
	from private.device_hardware_ids
	join public.devices
		on devices.id = device_hardware_ids.device_id
	where device_hardware_ids.hardware_id = normalized_hardware_id
		and devices.device_kind = 'PHYSICAL';

	if matched_device_id is null then
		return query
		select 'UNKNOWN_DEVICE'::text, null::bigint, null::uuid, null::timestamptz;
		return;
	end if;

	select device_assignments.id, device_assignments.assigned_at
	into matched_assignment_id, matched_assigned_at
	from public.device_assignments
	where device_assignments.device_id = matched_device_id
		and device_assignments.unassigned_at is null
	for update;

	if matched_assignment_id is null then
		return query
		select 'NO_ACTIVE_ASSIGNMENT'::text, null::bigint, null::uuid, null::timestamptz;
		return;
	end if;

	-- A reading captured before the active assignment began belongs to a previous
	-- patient (or to no patient) and must never be attached to the current one.
	if p_recorded_at < matched_assigned_at then
		return query
		select 'PREDATES_ASSIGNMENT'::text, null::bigint, matched_assignment_id, null::timestamptz;
		return;
	end if;

	insert into public.locations (
		device_assignment_id,
		event_id,
		latitude,
		longitude,
		accuracy_m,
		recorded_at,
		source
	)
	values (
		matched_assignment_id,
		p_event_id,
		p_latitude,
		p_longitude,
		p_accuracy_m,
		p_recorded_at,
		'DEVICE'
	)
	on conflict (device_assignment_id, event_id) do nothing
	returning id into new_location_id;

	if new_location_id is not null then
		return query
		select 'CREATED'::text, new_location_id, matched_assignment_id, p_recorded_at;
		return;
	end if;

	select locations.*
	into existing_location
	from public.locations
	where locations.device_assignment_id = matched_assignment_id
		and locations.event_id = p_event_id;

	if existing_location.latitude is distinct from p_latitude
		or existing_location.longitude is distinct from p_longitude
		or existing_location.accuracy_m is distinct from p_accuracy_m
		or existing_location.recorded_at is distinct from p_recorded_at
		or existing_location.source is distinct from 'DEVICE' then
		return query
		select 'CONFLICT'::text, existing_location.id, matched_assignment_id, existing_location.recorded_at;
		return;
	end if;

	return query
	select 'DUPLICATE'::text, existing_location.id, matched_assignment_id, existing_location.recorded_at;
end;
$$;

comment on function private.ingest_device_location(
	text,
	uuid,
	double precision,
	double precision,
	double precision,
	timestamptz
) is
	'Persists one idempotent DEVICE reading for the active assignment of a registered physical device. Service role only.';

revoke execute on function private.ingest_device_location(
	text,
	uuid,
	double precision,
	double precision,
	double precision,
	timestamptz
) from public, anon, authenticated;
grant execute on function private.ingest_device_location(
	text,
	uuid,
	double precision,
	double precision,
	double precision,
	timestamptz
) to service_role;

create or replace function public.ingest_device_location(
	p_hardware_id text,
	p_event_id uuid,
	p_latitude double precision,
	p_longitude double precision,
	p_accuracy_m double precision,
	p_recorded_at timestamptz
)
returns table (
	ingest_outcome text,
	location_id bigint,
	location_device_assignment_id uuid,
	location_recorded_at timestamptz
)
language sql
security invoker
set search_path = ''
as $$
	select *
	from private.ingest_device_location(
		p_hardware_id,
		p_event_id,
		p_latitude,
		p_longitude,
		p_accuracy_m,
		p_recorded_at
	);
$$;

comment on function public.ingest_device_location(
	text,
	uuid,
	double precision,
	double precision,
	double precision,
	timestamptz
) is
	'Service-role wrapper used by the trusted ingestion gateway for physical device readings.';

revoke execute on function public.ingest_device_location(
	text,
	uuid,
	double precision,
	double precision,
	double precision,
	timestamptz
) from public, anon, authenticated;
grant execute on function public.ingest_device_location(
	text,
	uuid,
	double precision,
	double precision,
	double precision,
	timestamptz
) to service_role;
