begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(39);

select has_table('public', 'locations', 'locations table exists');
select has_view('public', 'latest_locations', 'latest_locations view exists');
select ok(
	(select relrowsecurity from pg_class where oid = 'public.locations'::regclass),
	'locations has RLS enabled'
);
select has_column('public', 'locations', 'device_assignment_id', 'locations stores assignment history');
select has_column('public', 'locations', 'event_id', 'locations stores an idempotency identifier');
select has_column('public', 'locations', 'recorded_at', 'locations stores capture time');
select ok(
	exists (
		select 1
		from pg_publication_tables
		where pubname = 'supabase_realtime'
			and schemaname = 'public'
			and tablename = 'locations'
	),
	'locations is enabled for Supabase Realtime'
);

select ok(
	has_table_privilege('authenticated', 'public.locations', 'SELECT'),
	'authenticated can select locations through RLS'
);
select ok(
	not has_table_privilege('authenticated', 'public.locations', 'INSERT'),
	'authenticated cannot insert locations directly'
);
select ok(
	not has_table_privilege('anon', 'public.locations', 'SELECT'),
	'anon cannot select locations'
);
select ok(
	has_table_privilege('authenticated', 'public.latest_locations', 'SELECT'),
	'authenticated can select the latest-location view'
);
select ok(
	not has_table_privilege('anon', 'public.latest_locations', 'SELECT'),
	'anon cannot select the latest-location view'
);
select ok(
	not has_function_privilege(
		'anon',
		'public.ingest_simulated_location(uuid,uuid,double precision,double precision,double precision,timestamptz,text)',
		'EXECUTE'
	),
	'anon cannot execute simulated ingestion'
);
select ok(
	has_function_privilege(
		'authenticated',
		'public.ingest_simulated_location(uuid,uuid,double precision,double precision,double precision,timestamptz,text)',
		'EXECUTE'
	),
	'authenticated can call the guarded ingestion RPC'
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
		'41000000-0000-0000-0000-000000000001',
		'authenticated',
		'authenticated',
		'location-admin-a@example.test',
		'',
		now(),
		now(),
		now(),
		'{"provider":"email","providers":["email"]}'::jsonb,
		'{"full_name":"Location Admin A"}'::jsonb
	),
	(
		'00000000-0000-0000-0000-000000000000',
		'42000000-0000-0000-0000-000000000002',
		'authenticated',
		'authenticated',
		'location-monitor-b@example.test',
		'',
		now(),
		now(),
		now(),
		'{"provider":"email","providers":["email"]}'::jsonb,
		'{"full_name":"Location Monitor B"}'::jsonb
	),
	(
		'00000000-0000-0000-0000-000000000000',
		'43000000-0000-0000-0000-000000000003',
		'authenticated',
		'authenticated',
		'location-admin-c@example.test',
		'',
		now(),
		now(),
		now(),
		'{"provider":"email","providers":["email"]}'::jsonb,
		'{"full_name":"Location Admin C"}'::jsonb
	);

insert into public.devices (serial_number, device_kind)
values ('SENDA-TEST-LOCATION-001', 'SIMULATED');

set local role authenticated;
select set_config('request.jwt.claim.sub', '41000000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select lives_ok(
	$$select * from public.create_patient_onboarding('Familia Ubicacion A', 'FAMILY', 'Ana', 'Ruta')$$,
	'admin A can create a patient for location tests'
);

select set_config(
	'test.location_patient_a',
	(select id::text from public.patients limit 1),
	true
);

select lives_ok(
	$$
		select *
		from public.assign_simulated_device(
			current_setting('test.location_patient_a')::uuid,
			'SENDA-TEST-LOCATION-001'
		)
	$$,
	'admin A can assign a simulated device'
);

select set_config(
	'test.location_assignment_a',
	(select id::text from public.device_assignments where unassigned_at is null limit 1),
	true
);
select set_config(
	'test.location_device',
	(select device_id::text from public.device_assignments where unassigned_at is null limit 1),
	true
);

select lives_ok(
	$$
		select *
		from public.ingest_simulated_location(
			current_setting('test.location_patient_a')::uuid,
			'51000000-0000-0000-0000-000000000001'::uuid,
			18.4861,
			-69.9312,
			8.5,
			now(),
			'SIMULATOR'
		)
	$$,
	'admin A can ingest a valid simulated location'
);
select results_eq(
	$$select count(*) from public.locations$$,
	$$values (1::bigint)$$,
	'admin A sees the persisted location'
);
select results_eq(
	$$select latitude::numeric(8, 4) from public.latest_locations$$,
	$$values (18.4861::numeric)$$,
	'latest_locations exposes the most recent authorized reading'
);

select lives_ok(
	$$
		select *
		from public.ingest_simulated_location(
			current_setting('test.location_patient_a')::uuid,
			'51000000-0000-0000-0000-000000000001'::uuid,
			18.4861,
			-69.9312,
			8.5,
			now(),
			'SIMULATOR'
		)
	$$,
	'retrying the same event with the same data succeeds'
);
select results_eq(
	$$select count(*) from public.locations$$,
	$$values (1::bigint)$$,
	'idempotent retry does not duplicate the location'
);

select throws_ok(
	$$
		select *
		from public.ingest_simulated_location(
			current_setting('test.location_patient_a')::uuid,
			'51000000-0000-0000-0000-000000000001'::uuid,
			18.5000,
			-69.9312,
			8.5,
			now(),
			'SIMULATOR'
		)
	$$,
	'23505',
	'Event identifier was already used with different location data.',
	'an event identifier cannot be reused with different coordinates'
);
select throws_ok(
	$$
		select * from public.ingest_simulated_location(
			current_setting('test.location_patient_a')::uuid,
			gen_random_uuid(),
			91,
			-69.9,
			5,
			now(),
			'MANUAL'
		)
	$$,
	'22023',
	'Latitude is invalid.',
	'latitude outside its range is rejected'
);
select throws_ok(
	$$
		select * from public.ingest_simulated_location(
			current_setting('test.location_patient_a')::uuid,
			gen_random_uuid(),
			18.4,
			-181,
			5,
			now(),
			'MANUAL'
		)
	$$,
	'22023',
	'Longitude is invalid.',
	'longitude outside its range is rejected'
);
select throws_ok(
	$$
		select * from public.ingest_simulated_location(
			current_setting('test.location_patient_a')::uuid,
			gen_random_uuid(),
			18.4,
			-69.9,
			-1,
			now(),
			'MANUAL'
		)
	$$,
	'22023',
	'Accuracy is invalid.',
	'negative accuracy is rejected'
);
select throws_ok(
	$$
		select * from public.ingest_simulated_location(
			current_setting('test.location_patient_a')::uuid,
			gen_random_uuid(),
			18.4,
			-69.9,
			5,
			now() + interval '2 minutes',
			'MANUAL'
		)
	$$,
	'22023',
	'Recorded timestamp is too far in the future.',
	'a timestamp too far in the future is rejected'
);
select throws_ok(
	$$
		select * from public.ingest_simulated_location(
			current_setting('test.location_patient_a')::uuid,
			gen_random_uuid(),
			18.4,
			-69.9,
			5,
			(select assigned_at - interval '1 second' from public.device_assignments where unassigned_at is null),
			'MANUAL'
		)
	$$,
	'22023',
	'Recorded timestamp predates the active assignment.',
	'a reading cannot predate its assignment'
);
select throws_ok(
	$$
		select * from public.ingest_simulated_location(
			current_setting('test.location_patient_a')::uuid,
			gen_random_uuid(),
			18.4,
			-69.9,
			5,
			now(),
			'DEVICE'
		)
	$$,
	'22023',
	'Simulation source is invalid.',
	'the authenticated simulator cannot claim a physical device source'
);
select throws_ok(
	$$
		insert into public.locations (
			device_assignment_id,
			event_id,
			latitude,
			longitude,
			recorded_at,
			source
		)
		values (
			current_setting('test.location_assignment_a')::uuid,
			gen_random_uuid(),
			18.4,
			-69.9,
			now(),
			'MANUAL'
		)
	$$,
	'42501',
	'permission denied for table locations',
	'authenticated users cannot bypass the ingestion RPC'
);

reset role;
insert into public.patient_access (patient_id, user_id, access_role)
values (
	current_setting('test.location_patient_a')::uuid,
	'42000000-0000-0000-0000-000000000002',
	'MONITOR'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '42000000-0000-0000-0000-000000000002', true);

select results_eq(
	$$select count(*) from public.locations$$,
	$$values (1::bigint)$$,
	'a MONITOR can read locations for an authorized patient'
);
select results_eq(
	$$select count(*) from public.latest_locations$$,
	$$values (1::bigint)$$,
	'a MONITOR can read the latest authorized location'
);
select throws_ok(
	$$
		select * from public.ingest_simulated_location(
			current_setting('test.location_patient_a')::uuid,
			gen_random_uuid(),
			18.5,
			-69.8,
			5,
			now(),
			'SIMULATOR'
		)
	$$,
	'42501',
	'ADMIN access to the patient is required.',
	'a MONITOR cannot ingest simulated locations'
);

select set_config('request.jwt.claim.sub', '43000000-0000-0000-0000-000000000003', true);
select lives_ok(
	$$select * from public.create_patient_onboarding('Familia Ubicacion C', 'FAMILY', 'Carla', 'Ruta')$$,
	'admin C can create a separate patient'
);
select set_config(
	'test.location_patient_c',
	(select id::text from public.patients limit 1),
	true
);

reset role;
update public.device_assignments
set unassigned_at = now()
where id = current_setting('test.location_assignment_a')::uuid;

insert into public.device_assignments (device_id, patient_id)
values (
	current_setting('test.location_device')::uuid,
	current_setting('test.location_patient_c')::uuid
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '43000000-0000-0000-0000-000000000003', true);

select results_eq(
	$$select count(*) from public.locations$$,
	$$values (0::bigint)$$,
	'new patient admin cannot read the previous assignment history'
);
select lives_ok(
	$$
		select * from public.ingest_simulated_location(
			current_setting('test.location_patient_c')::uuid,
			'53000000-0000-0000-0000-000000000003'::uuid,
			18.4700,
			-69.9200,
			6,
			now(),
			'SIMULATOR'
		)
	$$,
	'new patient admin can ingest on the new assignment'
);
select results_eq(
	$$select count(*) from public.locations$$,
	$$values (1::bigint)$$,
	'new patient admin sees only the new assignment location'
);
select results_eq(
	$$select latitude::numeric(8, 4) from public.latest_locations$$,
	$$values (18.4700::numeric)$$,
	'latest_locations does not leak the previous patient position'
);

select set_config('request.jwt.claim.sub', '41000000-0000-0000-0000-000000000001', true);
select results_eq(
	$$select count(*) from public.locations$$,
	$$values (1::bigint)$$,
	'original patient admin retains access to historical assignment locations'
);
select results_eq(
	$$select latitude::numeric(8, 4) from public.latest_locations$$,
	$$values (18.4861::numeric)$$,
	'original patient admin sees only the original assignment latest location'
);

select * from finish();
rollback;
