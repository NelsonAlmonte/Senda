create table public.alert_episodes (
	id uuid primary key default gen_random_uuid(),
	patient_id uuid not null references public.patients (id) on delete restrict,
	device_assignment_id uuid not null references public.device_assignments (id) on delete restrict,
	status text not null default 'OPEN',
	severity text not null default 'LOW',
	started_at timestamptz not null,
	confirmed_at timestamptz not null,
	resolved_at timestamptz,
	first_outside_location_id bigint not null references public.locations (id) on delete restrict,
	confirmed_by_location_id bigint not null references public.locations (id) on delete restrict,
	resolved_by_location_id bigint references public.locations (id) on delete restrict,
	created_at timestamptz not null default now(),
	updated_at timestamptz not null default now(),
	constraint alert_episodes_status_valid check (status in ('OPEN', 'RESOLVED')),
	constraint alert_episodes_severity_valid check (severity = 'LOW'),
	constraint alert_episodes_confirmation_order_valid check (confirmed_at >= started_at),
	constraint alert_episodes_distinct_opening_locations check (
		first_outside_location_id <> confirmed_by_location_id
	),
	constraint alert_episodes_resolution_consistent check (
		(
			status = 'OPEN'
			and resolved_at is null
			and resolved_by_location_id is null
		)
		or (
			status = 'RESOLVED'
			and resolved_at is not null
			and resolved_at >= confirmed_at
			and resolved_by_location_id is not null
			and resolved_by_location_id <> first_outside_location_id
			and resolved_by_location_id <> confirmed_by_location_id
		)
	),
	constraint alert_episodes_updated_after_creation check (updated_at >= created_at)
);

comment on table public.alert_episodes is
	'Patient geofence exits confirmed by two eligible OUTSIDE readings and resolved by two eligible INSIDE readings.';
comment on column public.alert_episodes.status is
	'OPEN while the confirmed exit remains active; RESOLVED after confirmed re-entry.';
comment on column public.alert_episodes.severity is
	'Fixed to LOW in the MVP episode story; timed escalation is intentionally deferred.';
comment on column public.alert_episodes.started_at is
	'Device timestamp of the first eligible OUTSIDE reading in the confirming pair.';
comment on column public.alert_episodes.confirmed_at is
	'Device timestamp of the second consecutive eligible OUTSIDE reading.';
comment on column public.alert_episodes.resolved_at is
	'Device timestamp of the second consecutive eligible INSIDE reading.';

create unique index alert_episodes_one_open_patient_idx
on public.alert_episodes (patient_id)
where status = 'OPEN';

create index alert_episodes_patient_history_idx
on public.alert_episodes (patient_id, confirmed_at desc, id);

create index alert_episodes_assignment_history_idx
on public.alert_episodes (device_assignment_id, confirmed_at desc, id);

create unique index alert_episodes_first_outside_location_idx
on public.alert_episodes (first_outside_location_id);

create unique index alert_episodes_confirmed_location_idx
on public.alert_episodes (confirmed_by_location_id);

create unique index alert_episodes_resolved_location_idx
on public.alert_episodes (resolved_by_location_id)
where resolved_by_location_id is not null;

alter table public.alert_episodes enable row level security;

revoke all on table public.alert_episodes from anon, authenticated;
grant select on table public.alert_episodes to authenticated;

create policy "alert_episodes_select_authorized"
on public.alert_episodes
for select
to authenticated
using (
	exists (
		select 1
		from public.patient_access
		where patient_access.patient_id = alert_episodes.patient_id
			and patient_access.user_id = (select auth.uid())
			and patient_access.revoked_at is null
	)
);

create or replace function private.process_location_alert_episode()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
	location_patient_id uuid;
	previous_location public.locations%rowtype;
	open_episode public.alert_episodes%rowtype;
	location_is_eligible boolean := (
		new.geofence_relation in ('INSIDE', 'OUTSIDE')
		and (new.accuracy_m is null or new.accuracy_m <= 100)
	);
	previous_is_eligible boolean;
begin
	select device_assignments.patient_id
	into location_patient_id
	from public.device_assignments
	where device_assignments.id = new.device_assignment_id
	for update;

	if location_patient_id is null then
		raise exception 'Location assignment has no patient.' using errcode = '23503';
	end if;

	select locations.*
	into previous_location
	from public.locations
	where locations.device_assignment_id = new.device_assignment_id
		and locations.id <> new.id
	order by locations.recorded_at desc, locations.id desc
	limit 1;

	if found and (
		new.recorded_at < previous_location.recorded_at
		or (
			new.recorded_at = previous_location.recorded_at
			and new.id < previous_location.id
		)
	) then
		return new;
	end if;

	if not location_is_eligible or previous_location.id is null then
		return new;
	end if;

	previous_is_eligible := (
		previous_location.geofence_relation in ('INSIDE', 'OUTSIDE')
		and (
			previous_location.accuracy_m is null
			or previous_location.accuracy_m <= 100
		)
	);

	select alert_episodes.*
	into open_episode
	from public.alert_episodes
	where alert_episodes.patient_id = location_patient_id
		and alert_episodes.status = 'OPEN'
	for update;

	if open_episode.id is null then
		if new.geofence_relation = 'OUTSIDE'
			and previous_is_eligible
			and previous_location.geofence_relation = 'OUTSIDE' then
			insert into public.alert_episodes (
				patient_id,
				device_assignment_id,
				status,
				severity,
				started_at,
				confirmed_at,
				first_outside_location_id,
				confirmed_by_location_id
			)
			values (
				location_patient_id,
				new.device_assignment_id,
				'OPEN',
				'LOW',
				previous_location.recorded_at,
				new.recorded_at,
				previous_location.id,
				new.id
			)
			on conflict (patient_id) where status = 'OPEN' do nothing;
		end if;
	elsif open_episode.device_assignment_id = new.device_assignment_id
		and new.geofence_relation = 'INSIDE'
		and previous_is_eligible
		and previous_location.geofence_relation = 'INSIDE' then
		update public.alert_episodes
		set status = 'RESOLVED',
			resolved_at = new.recorded_at,
			resolved_by_location_id = new.id,
			updated_at = clock_timestamp()
		where id = open_episode.id
			and status = 'OPEN';
	end if;

	return new;
end;
$$;

comment on function private.process_location_alert_episode() is
	'Opens and resolves basic LOW geofence episodes from chronological eligible readings; delayed readings never rewind current state.';

revoke execute on function private.process_location_alert_episode()
from public, anon, authenticated, service_role;

create trigger locations_process_alert_episode_after_insert
after insert on public.locations
for each row
execute function private.process_location_alert_episode();

do $$
begin
	if not exists (
		select 1
		from pg_publication_tables
		where pubname = 'supabase_realtime'
			and schemaname = 'public'
			and tablename = 'alert_episodes'
	) then
		alter publication supabase_realtime add table public.alert_episodes;
	end if;
end;
$$;
