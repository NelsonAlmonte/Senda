alter table public.alert_episodes
drop column severity;

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
				started_at,
				confirmed_at,
				first_outside_location_id,
				confirmed_by_location_id
			)
			values (
				location_patient_id,
				new.device_assignment_id,
				'OPEN',
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
	'Opens and resolves basic geofence exit episodes from chronological eligible readings; delayed readings never rewind current state.';
