create table public.locations (
	id bigint generated always as identity primary key,
	device_assignment_id uuid not null references public.device_assignments (id) on delete restrict,
	event_id uuid not null,
	latitude double precision not null,
	longitude double precision not null,
	accuracy_m double precision,
	recorded_at timestamptz not null,
	received_at timestamptz not null default now(),
	source text not null,
	constraint locations_latitude_valid check (latitude between -90 and 90),
	constraint locations_longitude_valid check (longitude between -180 and 180),
	constraint locations_accuracy_valid check (
		accuracy_m is null
		or (accuracy_m >= 0 and accuracy_m < 'Infinity'::double precision)
	),
	constraint locations_source_valid check (source in ('SIMULATOR', 'MANUAL', 'DEVICE')),
	constraint locations_assignment_event_unique unique (device_assignment_id, event_id)
);

comment on table public.locations is
	'Immutable position readings linked to the historical device assignment that produced them.';
comment on column public.locations.event_id is
	'Client-generated idempotency identifier, unique within one device assignment.';
comment on column public.locations.recorded_at is
	'Time when the simulated or physical device captured the position.';
comment on column public.locations.received_at is
	'Time when Senda persisted the position.';

create index locations_assignment_recorded_idx
on public.locations (device_assignment_id, recorded_at desc, id desc);

alter table public.locations enable row level security;

revoke all on table public.locations from anon, authenticated;
revoke all on sequence public.locations_id_seq from anon, authenticated;
grant select on table public.locations to authenticated;

create policy "locations_select_authorized"
on public.locations
for select
to authenticated
using (
	device_assignment_id in (
		select device_assignments.id
		from public.device_assignments
		join public.patient_access
			on patient_access.patient_id = device_assignments.patient_id
		where patient_access.user_id = (select auth.uid())
			and patient_access.revoked_at is null
	)
);

create view public.latest_locations
with (security_invoker = true)
as
select distinct on (locations.device_assignment_id)
	locations.id,
	locations.device_assignment_id,
	locations.latitude,
	locations.longitude,
	locations.accuracy_m,
	locations.recorded_at,
	locations.received_at,
	locations.source
from public.locations
order by locations.device_assignment_id, locations.recorded_at desc, locations.id desc;

comment on view public.latest_locations is
	'Latest authorized reading per historical device assignment; underlying locations RLS is enforced.';

revoke all on table public.latest_locations from public, anon, authenticated;
grant select on table public.latest_locations to authenticated;

create or replace function private.ingest_simulated_location(
	p_patient_id uuid,
	p_event_id uuid,
	p_latitude double precision,
	p_longitude double precision,
	p_accuracy_m double precision,
	p_recorded_at timestamptz,
	p_source text
)
returns table (
	location_id bigint,
	location_device_assignment_id uuid,
	location_recorded_at timestamptz,
	was_created boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
	caller_user_id uuid := (select auth.uid());
	normalized_source text := upper(btrim(coalesce(p_source, '')));
	matched_assignment_id uuid;
	matched_assigned_at timestamptz;
	new_location_id bigint;
	existing_location public.locations%rowtype;
begin
	if caller_user_id is null then
		raise exception 'Authentication is required.' using errcode = '42501';
	end if;

	if p_patient_id is null then
		raise exception 'Patient is required.' using errcode = '22023';
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

	if normalized_source not in ('SIMULATOR', 'MANUAL') then
		raise exception 'Simulation source is invalid.' using errcode = '22023';
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

	select device_assignments.id, device_assignments.assigned_at
	into matched_assignment_id, matched_assigned_at
	from public.device_assignments
	join public.devices
		on devices.id = device_assignments.device_id
	where device_assignments.patient_id = p_patient_id
		and device_assignments.unassigned_at is null
		and devices.device_kind = 'SIMULATED'
	for update of device_assignments;

	if matched_assignment_id is null then
		raise exception 'Patient has no active simulated device.' using errcode = '22023';
	end if;

	if p_recorded_at < matched_assigned_at then
		raise exception 'Recorded timestamp predates the active assignment.' using errcode = '22023';
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
		normalized_source
	)
	on conflict (device_assignment_id, event_id) do nothing
	returning id into new_location_id;

	if new_location_id is not null then
		return query
		select new_location_id, matched_assignment_id, p_recorded_at, true;
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
		or existing_location.source is distinct from normalized_source then
		raise exception 'Event identifier was already used with different location data.'
			using errcode = '23505';
	end if;

	return query
	select existing_location.id, matched_assignment_id, existing_location.recorded_at, false;
end;
$$;

comment on function private.ingest_simulated_location(
	uuid,
	uuid,
	double precision,
	double precision,
	double precision,
	timestamptz,
	text
) is
	'Persists one idempotent simulated reading after checking active patient-scoped ADMIN access.';

revoke execute on function private.ingest_simulated_location(
	uuid,
	uuid,
	double precision,
	double precision,
	double precision,
	timestamptz,
	text
) from public, anon, service_role;

grant usage on schema private to authenticated;
grant execute on function private.ingest_simulated_location(
	uuid,
	uuid,
	double precision,
	double precision,
	double precision,
	timestamptz,
	text
) to authenticated;

create or replace function public.ingest_simulated_location(
	p_patient_id uuid,
	p_event_id uuid,
	p_latitude double precision,
	p_longitude double precision,
	p_accuracy_m double precision,
	p_recorded_at timestamptz,
	p_source text
)
returns table (
	location_id bigint,
	location_device_assignment_id uuid,
	location_recorded_at timestamptz,
	was_created boolean
)
language sql
security invoker
set search_path = ''
as $$
	select *
	from private.ingest_simulated_location(
		p_patient_id,
		p_event_id,
		p_latitude,
		p_longitude,
		p_accuracy_m,
		p_recorded_at,
		p_source
	);
$$;

comment on function public.ingest_simulated_location(
	uuid,
	uuid,
	double precision,
	double precision,
	double precision,
	timestamptz,
	text
) is
	'Authenticated API wrapper for development-only simulated location ingestion.';

revoke execute on function public.ingest_simulated_location(
	uuid,
	uuid,
	double precision,
	double precision,
	double precision,
	timestamptz,
	text
) from public, anon;

grant execute on function public.ingest_simulated_location(
	uuid,
	uuid,
	double precision,
	double precision,
	double precision,
	timestamptz,
	text
) to authenticated;
