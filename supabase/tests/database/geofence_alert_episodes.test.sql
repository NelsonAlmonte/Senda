begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(55);

select has_table('public', 'alert_episodes', 'alert episodes are persisted');
select has_column('public', 'alert_episodes', 'patient_id', 'episodes belong to one patient');
select has_column(
	'public',
	'alert_episodes',
	'device_assignment_id',
	'episodes preserve the historical device assignment'
);
select has_column('public', 'alert_episodes', 'status', 'episodes preserve open or resolved state');
select hasnt_column(
	'public',
	'alert_episodes',
	'severity',
	'episodes do not store a risk level that the MVP does not use'
);
select has_column(
	'public',
	'alert_episodes',
	'first_outside_location_id',
	'episodes identify the first confirming OUTSIDE reading'
);
select has_column(
	'public',
	'alert_episodes',
	'confirmed_by_location_id',
	'episodes identify the second confirming OUTSIDE reading'
);
select has_column(
	'public',
	'alert_episodes',
	'resolved_by_location_id',
	'episodes identify the second confirming INSIDE reading'
);
select has_trigger(
	'public',
	'locations',
	'locations_process_alert_episode_after_insert',
	'new locations are processed by the episode trigger'
);
select ok(
	not has_function_privilege(
		'authenticated',
		'private.process_location_alert_episode()',
		'EXECUTE'
	),
	'authenticated users cannot call the internal episode processor'
);
select ok(
	exists (
		select 1
		from pg_publication_tables
		where pubname = 'supabase_realtime'
			and schemaname = 'public'
			and tablename = 'alert_episodes'
	),
	'alert episodes are published through Supabase Realtime'
);

insert into auth.users (
	instance_id,
	id,
	aud,
	role,
	email,
	encrypted_password,
	email_confirmed_at,
	created_at,
	updated_at,
	raw_app_meta_data,
	raw_user_meta_data
)
values
	(
		'00000000-0000-0000-0000-000000000000',
		'91000000-0000-0000-0000-000000000091',
		'authenticated',
		'authenticated',
		'episode-admin@example.test',
		'',
		now(),
		now(),
		now(),
		'{"provider":"email","providers":["email"]}'::jsonb,
		'{}'::jsonb
	),
	(
		'00000000-0000-0000-0000-000000000000',
		'92000000-0000-0000-0000-000000000092',
		'authenticated',
		'authenticated',
		'episode-monitor@example.test',
		'',
		now(),
		now(),
		now(),
		'{"provider":"email","providers":["email"]}'::jsonb,
		'{}'::jsonb
	),
	(
		'00000000-0000-0000-0000-000000000000',
		'93000000-0000-0000-0000-000000000093',
		'authenticated',
		'authenticated',
		'episode-outsider@example.test',
		'',
		now(),
		now(),
		now(),
		'{"provider":"email","providers":["email"]}'::jsonb,
		'{}'::jsonb
	);

insert into public.devices (serial_number, device_kind)
values ('SENDA-TEST-EPISODE-001', 'SIMULATED');

set local role authenticated;
select set_config('request.jwt.claim.sub', '91000000-0000-0000-0000-000000000091', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('test.episode_base_time', (now() - interval '1 hour')::text, true);

select lives_ok(
	$$select * from public.create_patient_onboarding('Familia episodios', 'FAMILY', 'Julia', 'Prueba')$$,
	'ADMIN creates the patient used by episode tests'
);
select set_config('test.episode_patient_id', (select id::text from public.patients limit 1), true);

select lives_ok(
	$$select * from public.assign_simulated_device(
		current_setting('test.episode_patient_id')::uuid,
		'SENDA-TEST-EPISODE-001'
	)$$,
	'ADMIN assigns a simulated device'
);
select set_config(
	'test.episode_assignment_id',
	(select id::text from public.device_assignments limit 1),
	true
);

reset role;
update public.device_assignments
set assigned_at = now() - interval '2 hours'
where id = current_setting('test.episode_assignment_id')::uuid;
set local role authenticated;
select set_config('request.jwt.claim.sub', '91000000-0000-0000-0000-000000000091', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select lives_ok(
	$$select * from public.save_patient_safe_zone(
		null,
		current_setting('test.episode_patient_id')::uuid,
		'Casa',
		18,
		-70,
		250,
		true
	)$$,
	'ADMIN creates an active safe zone'
);

select lives_ok(
	$$select * from public.ingest_simulated_location(
		current_setting('test.episode_patient_id')::uuid,
		'94000000-0000-0000-0000-000000000001'::uuid,
		18,
		-70,
		null,
		current_setting('test.episode_base_time')::timestamptz + interval '1 minute',
		'SIMULATOR'
	)$$,
	'an initial INSIDE reading establishes a chronological baseline'
);

select lives_ok(
	$$select * from public.ingest_simulated_location(
		current_setting('test.episode_patient_id')::uuid,
		'94000000-0000-0000-0000-000000000002'::uuid,
		18.003,
		-70,
		null,
		current_setting('test.episode_base_time')::timestamptz + interval '2 minutes',
		'SIMULATOR'
	)$$,
	'the first isolated OUTSIDE reading is ingested'
);
select results_eq(
	$$select count(*) from public.alert_episodes$$,
	$$values (0::bigint)$$,
	'one OUTSIDE reading does not open an episode'
);

select lives_ok(
	$$select * from public.ingest_simulated_location(
		current_setting('test.episode_patient_id')::uuid,
		'94000000-0000-0000-0000-000000000003'::uuid,
		18,
		-70,
		null,
		current_setting('test.episode_base_time')::timestamptz + interval '3 minutes',
		'SIMULATOR'
	)$$,
	'an INSIDE reading after one OUTSIDE reading is ingested'
);
select results_eq(
	$$select count(*) from public.alert_episodes$$,
	$$values (0::bigint)$$,
	'R02 does not confirm an exit when the second reading is INSIDE'
);

select lives_ok(
	$$select * from public.ingest_simulated_location(
		current_setting('test.episode_patient_id')::uuid,
		'94000000-0000-0000-0000-000000000004'::uuid,
		18.003,
		-70,
		null,
		current_setting('test.episode_base_time')::timestamptz + interval '4 minutes',
		'SIMULATOR'
	)$$,
	'the first reading of a confirming OUTSIDE pair is ingested'
);
select results_eq(
	$$select count(*) from public.alert_episodes$$,
	$$values (0::bigint)$$,
	'the first reading of the pair still does not open an episode'
);

select lives_ok(
	$$select * from public.ingest_simulated_location(
		current_setting('test.episode_patient_id')::uuid,
		'94000000-0000-0000-0000-000000000005'::uuid,
		18.0031,
		-70,
		null,
		current_setting('test.episode_base_time')::timestamptz + interval '5 minutes',
		'SIMULATOR'
	)$$,
	'the second consecutive OUTSIDE reading is ingested'
);
select results_eq(
	$$select count(*) from public.alert_episodes where status = 'OPEN'$$,
	$$values (1::bigint)$$,
	'R03 opens one episode after two eligible OUTSIDE readings'
);
select results_eq(
	$$select status from public.alert_episodes$$,
	$$values ('OPEN'::text)$$,
	'the MVP episode opens without a severity level'
);
select results_eq(
	$$select
		first_location.event_id,
		confirming_location.event_id
	from public.alert_episodes
	join public.locations as first_location
		on first_location.id = alert_episodes.first_outside_location_id
	join public.locations as confirming_location
		on confirming_location.id = alert_episodes.confirmed_by_location_id$$,
	$$values (
		'94000000-0000-0000-0000-000000000004'::uuid,
		'94000000-0000-0000-0000-000000000005'::uuid
	)$$,
	'the episode preserves both confirming OUTSIDE readings'
);
select results_eq(
	$$select
		started_at,
		confirmed_at
	from public.alert_episodes$$,
	$$values (
		current_setting('test.episode_base_time')::timestamptz + interval '4 minutes',
		current_setting('test.episode_base_time')::timestamptz + interval '5 minutes'
	)$$,
	'the episode starts at the first OUTSIDE reading and confirms at the second'
);

select lives_ok(
	$$select * from public.ingest_simulated_location(
		current_setting('test.episode_patient_id')::uuid,
		'94000000-0000-0000-0000-000000000006'::uuid,
		18.0032,
		-70,
		null,
		current_setting('test.episode_base_time')::timestamptz + interval '6 minutes',
		'SIMULATOR'
	)$$,
	'a later OUTSIDE reading during the open episode is ingested'
);
select results_eq(
	$$select count(*) from public.alert_episodes$$,
	$$values (1::bigint)$$,
	'an open exit is updated conceptually instead of duplicated per reading'
);

select lives_ok(
	$$select * from public.ingest_simulated_location(
		current_setting('test.episode_patient_id')::uuid,
		'94000000-0000-0000-0000-000000000007'::uuid,
		18,
		-70,
		null,
		current_setting('test.episode_base_time')::timestamptz + interval '7 minutes',
		'SIMULATOR'
	)$$,
	'the first INSIDE reading after an open episode is ingested'
);
select results_eq(
	$$select count(*) from public.alert_episodes where status = 'OPEN'$$,
	$$values (1::bigint)$$,
	'one INSIDE reading does not resolve an episode'
);

select lives_ok(
	$$select * from public.ingest_simulated_location(
		current_setting('test.episode_patient_id')::uuid,
		'94000000-0000-0000-0000-000000000008'::uuid,
		18,
		-70,
		null,
		current_setting('test.episode_base_time')::timestamptz + interval '8 minutes',
		'SIMULATOR'
	)$$,
	'the second consecutive INSIDE reading is ingested'
);
select results_eq(
	$$select status from public.alert_episodes$$,
	$$values ('RESOLVED'::text)$$,
	'R08 resolves the same episode'
);
select results_eq(
	$$select locations.event_id
	from public.alert_episodes
	join public.locations on locations.id = alert_episodes.resolved_by_location_id$$,
	$$values ('94000000-0000-0000-0000-000000000008'::uuid)$$,
	'the episode preserves the second confirming INSIDE reading'
);
select results_eq(
	$$select resolved_at
	from public.alert_episodes$$,
	$$values (
		current_setting('test.episode_base_time')::timestamptz + interval '8 minutes'
	)$$,
	'the episode records the device timestamp of confirmed re-entry'
);

select lives_ok(
	$$select * from public.ingest_simulated_location(
		current_setting('test.episode_patient_id')::uuid,
		'94000000-0000-0000-0000-000000000009'::uuid,
		18.003,
		-70,
		null,
		current_setting('test.episode_base_time')::timestamptz + interval '9 minutes',
		'SIMULATOR'
	)$$,
	'an eligible OUTSIDE reading before a low-precision reading is ingested'
);
select lives_ok(
	$$select * from public.ingest_simulated_location(
		current_setting('test.episode_patient_id')::uuid,
		'94000000-0000-0000-0000-000000000010'::uuid,
		18.02,
		-70,
		150,
		current_setting('test.episode_base_time')::timestamptz + interval '10 minutes',
		'SIMULATOR'
	)$$,
	'an OUTSIDE reading with accuracy worse than 100 meters is ingested'
);
select results_eq(
	$$select geofence_relation from public.locations where event_id = '94000000-0000-0000-0000-000000000010'::uuid$$,
	$$values ('OUTSIDE'::text)$$,
	'the low-precision reading can still be classified OUTSIDE'
);
select results_eq(
	$$select count(*) from public.alert_episodes where status = 'OPEN'$$,
	$$values (0::bigint)$$,
	'a reading with accuracy worse than 100 meters cannot confirm an episode'
);

select lives_ok(
	$$select * from public.ingest_simulated_location(
		current_setting('test.episode_patient_id')::uuid,
		'94000000-0000-0000-0000-000000000011'::uuid,
		18.003,
		-70,
		null,
		current_setting('test.episode_base_time')::timestamptz + interval '11 minutes',
		'SIMULATOR'
	)$$,
	'an eligible OUTSIDE reading after low precision is ingested'
);
select results_eq(
	$$select count(*) from public.alert_episodes where status = 'OPEN'$$,
	$$values (0::bigint)$$,
	'the low-precision reading interrupts the confirming pair'
);

select lives_ok(
	$$select * from public.ingest_simulated_location(
		current_setting('test.episode_patient_id')::uuid,
		'94000000-0000-0000-0000-000000000012'::uuid,
		18.0031,
		-70,
		null,
		current_setting('test.episode_base_time')::timestamptz + interval '12 minutes',
		'SIMULATOR'
	)$$,
	'a second eligible OUTSIDE reading after low precision is ingested'
);
select results_eq(
	$$select count(*) from public.alert_episodes where status = 'OPEN'$$,
	$$values (1::bigint)$$,
	'two new eligible OUTSIDE readings open the next episode'
);

select lives_ok(
	$$select * from public.ingest_simulated_location(
		current_setting('test.episode_patient_id')::uuid,
		'94000000-0000-0000-0000-000000000013'::uuid,
		18,
		-70,
		null,
		current_setting('test.episode_base_time')::timestamptz + interval '13 minutes',
		'SIMULATOR'
	)$$,
	'the first re-entry reading for the second episode is ingested'
);
select lives_ok(
	$$select * from public.ingest_simulated_location(
		current_setting('test.episode_patient_id')::uuid,
		'94000000-0000-0000-0000-000000000014'::uuid,
		18,
		-70,
		null,
		current_setting('test.episode_base_time')::timestamptz + interval '14 minutes',
		'SIMULATOR'
	)$$,
	'the second re-entry reading resolves the second episode'
);

select lives_ok(
	$$select * from public.ingest_simulated_location(
		current_setting('test.episode_patient_id')::uuid,
		'94000000-0000-0000-0000-000000000015'::uuid,
		18.003,
		-70,
		null,
		current_setting('test.episode_base_time')::timestamptz + interval '20 minutes',
		'SIMULATOR'
	)$$,
	'an eligible OUTSIDE reading starts a chronological pair'
);
select lives_ok(
	$$select * from public.ingest_simulated_location(
		current_setting('test.episode_patient_id')::uuid,
		'94000000-0000-0000-0000-000000000016'::uuid,
		18.0031,
		-70,
		null,
		current_setting('test.episode_base_time')::timestamptz + interval '19 minutes',
		'SIMULATOR'
	)$$,
	'an OUTSIDE reading delayed behind the latest timestamp is still stored'
);
select results_eq(
	$$select count(*) from public.alert_episodes where status = 'OPEN'$$,
	$$values (0::bigint)$$,
	'the delayed reading does not rewind state or confirm an episode'
);

select lives_ok(
	$$select * from public.ingest_simulated_location(
		current_setting('test.episode_patient_id')::uuid,
		'94000000-0000-0000-0000-000000000017'::uuid,
		18.0032,
		-70,
		null,
		current_setting('test.episode_base_time')::timestamptz + interval '21 minutes',
		'SIMULATOR'
	)$$,
	'the next chronological OUTSIDE reading is ingested'
);
select results_eq(
	$$select confirming_location.event_id
	from public.alert_episodes
	join public.locations as confirming_location
		on confirming_location.id = alert_episodes.confirmed_by_location_id
	where alert_episodes.status = 'OPEN'$$,
	$$values ('94000000-0000-0000-0000-000000000017'::uuid)$$,
	'the chronological reading, not the delayed reading, confirms the episode'
);
select results_eq(
	$$select first_location.event_id
	from public.alert_episodes
	join public.locations as first_location
		on first_location.id = alert_episodes.first_outside_location_id
	where alert_episodes.status = 'OPEN'$$,
	$$values ('94000000-0000-0000-0000-000000000015'::uuid)$$,
	'the episode begins at the latest chronological first OUTSIDE reading'
);

reset role;
insert into public.patient_access (patient_id, user_id, access_role, relationship)
values (
	current_setting('test.episode_patient_id')::uuid,
	'92000000-0000-0000-0000-000000000092',
	'MONITOR',
	'FAMILY'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '92000000-0000-0000-0000-000000000092', true);
select results_eq(
	$$select count(*) from public.alert_episodes$$,
	$$values (3::bigint)$$,
	'an authorized MONITOR can read the complete patient episode history'
);

select set_config('request.jwt.claim.sub', '93000000-0000-0000-0000-000000000093', true);
select results_eq(
	$$select count(*) from public.alert_episodes$$,
	$$values (0::bigint)$$,
	'an outsider cannot read patient episodes'
);

select set_config('request.jwt.claim.sub', '91000000-0000-0000-0000-000000000091', true);
select throws_ok(
	$$insert into public.alert_episodes (
		patient_id,
		device_assignment_id,
		started_at,
		confirmed_at,
		first_outside_location_id,
		confirmed_by_location_id
	)
	select
		current_setting('test.episode_patient_id')::uuid,
		current_setting('test.episode_assignment_id')::uuid,
		now(),
		now(),
		min(id),
		max(id)
	from public.locations$$,
	'42501',
	'permission denied for table alert_episodes',
	'authenticated users cannot create alert episodes directly'
);
select throws_ok(
	$$update public.alert_episodes set status = 'RESOLVED'$$,
	'42501',
	'permission denied for table alert_episodes',
	'authenticated users cannot alter alert episodes directly'
);
select throws_ok(
	$$delete from public.alert_episodes$$,
	'42501',
	'permission denied for table alert_episodes',
	'authenticated users cannot delete alert episodes directly'
);

select * from finish();
rollback;
