alter table public.locations
add column geofence_relation text not null default 'NOT_EVALUATED',
add column matched_safe_zone_id uuid references public.safe_zones (id) on delete restrict,
add column distance_to_boundary_m double precision,
add column effective_tolerance_m double precision,
add column geofence_evaluated_at timestamptz;

alter table public.locations
add constraint locations_geofence_relation_valid check (
	geofence_relation in (
		'NOT_EVALUATED',
		'NO_ACTIVE_ZONE',
		'INSIDE',
		'OUTSIDE',
		'UNCERTAIN'
	)
),
add constraint locations_distance_to_boundary_valid check (
	distance_to_boundary_m is null
	or distance_to_boundary_m not in (
		'NaN'::double precision,
		'Infinity'::double precision,
		'-Infinity'::double precision
	)
),
add constraint locations_effective_tolerance_valid check (
	effective_tolerance_m is null
	or (
		effective_tolerance_m >= 25
		and effective_tolerance_m not in (
			'NaN'::double precision,
			'Infinity'::double precision,
			'-Infinity'::double precision
		)
	)
),
add constraint locations_geofence_evaluation_consistent check (
	(
		geofence_relation = 'NOT_EVALUATED'
		and matched_safe_zone_id is null
		and distance_to_boundary_m is null
		and effective_tolerance_m is null
		and geofence_evaluated_at is null
	)
	or (
		geofence_relation = 'NO_ACTIVE_ZONE'
		and matched_safe_zone_id is null
		and distance_to_boundary_m is null
		and effective_tolerance_m is not null
		and geofence_evaluated_at is not null
	)
	or (
		geofence_relation in ('INSIDE', 'OUTSIDE', 'UNCERTAIN')
		and matched_safe_zone_id is not null
		and distance_to_boundary_m is not null
		and effective_tolerance_m is not null
		and geofence_evaluated_at is not null
	)
);

comment on column public.locations.geofence_relation is
	'Per-reading relation to the active allowed zones at ingestion time; it is not a confirmed alert.';
comment on column public.locations.matched_safe_zone_id is
	'Active safe zone that determined the stored relation for this reading.';
comment on column public.locations.distance_to_boundary_m is
	'Signed meters from the matched circle boundary: negative inside, positive outside.';
comment on column public.locations.effective_tolerance_m is
	'GPS uncertainty used for classification: the greater of reported accuracy and the 25 m MVP minimum.';
comment on column public.locations.geofence_evaluated_at is
	'Time when the backend classified this reading against then-active safe zones.';

create index locations_matched_safe_zone_id_idx
on public.locations (matched_safe_zone_id)
where matched_safe_zone_id is not null;

create or replace function private.great_circle_distance_m(
	p_latitude_a double precision,
	p_longitude_a double precision,
	p_latitude_b double precision,
	p_longitude_b double precision
)
returns double precision
language sql
immutable
strict
parallel safe
security invoker
set search_path = ''
as $$
	select 2 * 6371008.8 * asin(
		sqrt(
			least(
				1::double precision,
				greatest(
					0::double precision,
					power(sin(radians((p_latitude_b - p_latitude_a) / 2)), 2)
					+ cos(radians(p_latitude_a))
						* cos(radians(p_latitude_b))
						* power(sin(radians((p_longitude_b - p_longitude_a) / 2)), 2)
				)
			)
		)
	);
$$;

create or replace function private.evaluate_location_geofence()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
	location_patient_id uuid;
	effective_tolerance double precision := greatest(coalesce(new.accuracy_m, 0), 25);
	selected_zone_id uuid;
	selected_boundary_distance double precision;
	selected_relation text;
begin
	select device_assignments.patient_id
	into location_patient_id
	from public.device_assignments
	where device_assignments.id = new.device_assignment_id;

	if location_patient_id is null then
		raise exception 'Location assignment has no patient.' using errcode = '23503';
	end if;

	with evaluated_zones as (
		select
			safe_zones.id,
			distance.center_distance_m - safe_zones.radius_m as boundary_distance_m
		from public.safe_zones
		cross join lateral (
			select private.great_circle_distance_m(
				new.latitude,
				new.longitude,
				safe_zones.center_latitude,
				safe_zones.center_longitude
			) as center_distance_m
		) as distance
		where safe_zones.patient_id = location_patient_id
			and safe_zones.is_active
			and safe_zones.archived_at is null
	), classified_zones as (
		select
			evaluated_zones.id,
			evaluated_zones.boundary_distance_m,
			case
				when evaluated_zones.boundary_distance_m <= -effective_tolerance then 'INSIDE'
				when abs(evaluated_zones.boundary_distance_m) <= effective_tolerance then 'UNCERTAIN'
				else 'OUTSIDE'
			end as relation
		from evaluated_zones
	)
	select
		classified_zones.id,
		classified_zones.boundary_distance_m,
		classified_zones.relation
	into selected_zone_id, selected_boundary_distance, selected_relation
	from classified_zones
	order by
		case classified_zones.relation
			when 'INSIDE' then 1
			when 'UNCERTAIN' then 2
			else 3
		end,
		case
			when classified_zones.relation = 'INSIDE' then classified_zones.boundary_distance_m
			when classified_zones.relation = 'UNCERTAIN' then abs(classified_zones.boundary_distance_m)
			else classified_zones.boundary_distance_m
		end,
		classified_zones.id
	limit 1;

	new.effective_tolerance_m := effective_tolerance;
	new.geofence_evaluated_at := clock_timestamp();

	if selected_zone_id is null then
		new.geofence_relation := 'NO_ACTIVE_ZONE';
		new.matched_safe_zone_id := null;
		new.distance_to_boundary_m := null;
	else
		new.geofence_relation := selected_relation;
		new.matched_safe_zone_id := selected_zone_id;
		new.distance_to_boundary_m := selected_boundary_distance;
	end if;

	return new;
end;
$$;

comment on function private.great_circle_distance_m(
	double precision,
	double precision,
	double precision,
	double precision
) is 'Calculates Haversine distance in meters for the MVP circular geofence classifier.';
comment on function private.evaluate_location_geofence() is
	'Classifies each new location against every active, non-archived patient safe zone before persistence.';

revoke execute on function private.great_circle_distance_m(
	double precision,
	double precision,
	double precision,
	double precision
) from public, anon, authenticated;
grant execute on function private.great_circle_distance_m(
	double precision,
	double precision,
	double precision,
	double precision
) to service_role;
revoke execute on function private.evaluate_location_geofence()
from public, anon, authenticated, service_role;

create trigger locations_evaluate_geofence_before_insert
before insert on public.locations
for each row
execute function private.evaluate_location_geofence();

create or replace view public.latest_locations
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
	locations.source,
	locations.geofence_relation,
	locations.matched_safe_zone_id,
	locations.distance_to_boundary_m,
	locations.effective_tolerance_m,
	locations.geofence_evaluated_at
from public.locations
order by locations.device_assignment_id, locations.recorded_at desc, locations.id desc;

comment on view public.latest_locations is
	'Latest authorized reading and its ingestion-time geofence relation per historical device assignment; underlying locations RLS is enforced.';
