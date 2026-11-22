begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(55);

-- Structure and privileges --------------------------------------------------

select has_table('private', 'device_hardware_ids', 'private hardware identifier table exists');
select ok(
	(select relrowsecurity from pg_class where oid = 'private.device_hardware_ids'::regclass),
	'device_hardware_ids has RLS enabled'
);
select ok(
	not has_table_privilege('authenticated', 'private.device_hardware_ids', 'SELECT'),
	'authenticated cannot select hardware identifiers'
);
select ok(
	not has_table_privilege('anon', 'private.device_hardware_ids', 'SELECT'),
	'anon cannot select hardware identifiers'
);
select ok(
	not has_table_privilege('service_role', 'private.device_hardware_ids', 'SELECT'),
	'even service_role reads identifiers only through the guarded functions'
);

select ok(
	has_function_privilege(
		'service_role',
		'public.ingest_device_location(text,uuid,double precision,double precision,double precision,timestamptz)',
		'EXECUTE'
	),
	'service_role can execute device ingestion'
);
select ok(
	not has_function_privilege(
		'authenticated',
		'public.ingest_device_location(text,uuid,double precision,double precision,double precision,timestamptz)',
		'EXECUTE'
	),
	'authenticated cannot execute device ingestion'
);
select ok(
	not has_function_privilege(
		'anon',
		'public.ingest_device_location(text,uuid,double precision,double precision,double precision,timestamptz)',
		'EXECUTE'
	),
	'anon cannot execute device ingestion'
);
select ok(
	not has_function_privilege(
		'authenticated',
		'private.ingest_device_location(text,uuid,double precision,double precision,double precision,timestamptz)',
		'EXECUTE'
	),
	'authenticated cannot execute the private ingestion function'
);
select ok(
	has_function_privilege('service_role', 'public.register_physical_device(text,text)', 'EXECUTE')
	and not has_function_privilege('authenticated', 'public.register_physical_device(text,text)', 'EXECUTE')
	and not has_function_privilege('anon', 'public.register_physical_device(text,text)', 'EXECUTE'),
	'only service_role can register physical devices'
);
select ok(
	has_function_privilege('authenticated', 'public.assign_physical_device(uuid,text)', 'EXECUTE')
	and not has_function_privilege('anon', 'public.assign_physical_device(uuid,text)', 'EXECUTE'),
	'authenticated can assign physical devices but anon cannot'
);

-- Fixtures ------------------------------------------------------------------

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
		'71000000-0000-0000-0000-000000000001',
		'authenticated',
		'authenticated',
		'physical-admin-a@example.test',
		'',
		now(),
		now(),
		now(),
		'{"provider":"email","providers":["email"]}'::jsonb,
		'{"full_name":"Physical Admin A"}'::jsonb
	),
	(
		'00000000-0000-0000-0000-000000000000',
		'72000000-0000-0000-0000-000000000002',
		'authenticated',
		'authenticated',
		'physical-monitor-b@example.test',
		'',
		now(),
		now(),
		now(),
		'{"provider":"email","providers":["email"]}'::jsonb,
		'{"full_name":"Physical Monitor B"}'::jsonb
	),
	(
		'00000000-0000-0000-0000-000000000000',
		'73000000-0000-0000-0000-000000000003',
		'authenticated',
		'authenticated',
		'physical-admin-c@example.test',
		'',
		now(),
		now(),
		now(),
		'{"provider":"email","providers":["email"]}'::jsonb,
		'{"full_name":"Physical Admin C"}'::jsonb
	),
	(
		'00000000-0000-0000-0000-000000000000',
		'74000000-0000-0000-0000-000000000004',
		'authenticated',
		'authenticated',
		'physical-outsider-d@example.test',
		'',
		now(),
		now(),
		now(),
		'{"provider":"email","providers":["email"]}'::jsonb,
		'{"full_name":"Physical Outsider D"}'::jsonb
	);

-- Registration (service role) -----------------------------------------------

set local role service_role;

select lives_ok(
	$$select * from public.register_physical_device('SENDA-GPS-TEST-001', '990000000000001')$$,
	'service_role registers a physical device'
);
select throws_ok(
	$$select * from public.register_physical_device('SENDA-GPS-TEST-002', '990000000000001')$$,
	'23505',
	null,
	'a hardware identifier cannot be registered twice'
);
select throws_ok(
	$$select * from public.register_physical_device('SENDA-GPS-TEST-003', 'short')$$,
	'22023',
	'Hardware identifier format is invalid.',
	'a malformed hardware identifier is rejected'
);
select throws_ok(
	$$select * from public.register_physical_device('bad serial!', '990000000000003')$$,
	'22023',
	'Serial format is invalid.',
	'a malformed serial is rejected'
);

reset role;

select results_eq(
	$$select device_kind from public.devices where serial_number = 'SENDA-GPS-TEST-001'$$,
	$$values ('PHYSICAL'::text)$$,
	'the registered device is stored as PHYSICAL'
);
select results_eq(
	$$select count(*) from public.devices where serial_number = 'SENDA-GPS-TEST-002'$$,
	$$values (0::bigint)$$,
	'a rejected registration leaves no orphan device'
);

-- Assignment (authenticated ADMIN) ------------------------------------------

set local role authenticated;
select set_config('request.jwt.claim.sub', '71000000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select lives_ok(
	$$select * from public.create_patient_onboarding('Familia Fisica A', 'FAMILY', 'Ana', 'Dispositivo')$$,
	'admin A can create a patient'
);
select set_config(
	'test.physical_patient_a',
	(select id::text from public.patients limit 1),
	true
);

select throws_ok(
	$$select * from private.device_hardware_ids$$,
	'42501',
	'permission denied for table device_hardware_ids',
	'a patient admin cannot read hardware identifiers'
);
select throws_ok(
	$$
		select * from public.ingest_device_location(
			'990000000000001',
			gen_random_uuid(),
			18.4861,
			-69.9312,
			8,
			now()
		)
	$$,
	'42501',
	'permission denied for function ingest_device_location',
	'a patient admin cannot call device ingestion'
);
select throws_ok(
	$$
		select * from public.assign_simulated_device(
			current_setting('test.physical_patient_a')::uuid,
			'SENDA-GPS-TEST-001'
		)
	$$,
	'22023',
	'Serial is not registered.',
	'the simulated assignment flow does not accept a physical serial'
);
select throws_ok(
	$$
		select * from public.assign_physical_device(
			current_setting('test.physical_patient_a')::uuid,
			'SENDA-DEMO-001'
		)
	$$,
	'22023',
	'Serial is not registered.',
	'the physical assignment flow does not accept a simulated serial'
);
select lives_ok(
	$$
		select * from public.assign_physical_device(
			current_setting('test.physical_patient_a')::uuid,
			'SENDA-GPS-TEST-001'
		)
	$$,
	'admin A can assign the physical device'
);
select throws_ok(
	$$
		select * from public.ingest_simulated_location(
			current_setting('test.physical_patient_a')::uuid,
			gen_random_uuid(),
			18.4861,
			-69.9312,
			5,
			now(),
			'SIMULATOR'
		)
	$$,
	'22023',
	'Patient has no active simulated device.',
	'the simulator RPC cannot forge readings for a patient with a physical device'
);

reset role;
select set_config(
	'test.physical_assignment_a',
	(select id::text from public.device_assignments where patient_id = current_setting('test.physical_patient_a')::uuid and unassigned_at is null),
	true
);
select set_config(
	'test.physical_device',
	(select device_id::text from public.device_assignments where patient_id = current_setting('test.physical_patient_a')::uuid and unassigned_at is null),
	true
);

insert into public.patient_access (patient_id, user_id, access_role)
values (
	current_setting('test.physical_patient_a')::uuid,
	'72000000-0000-0000-0000-000000000002',
	'MONITOR'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '72000000-0000-0000-0000-000000000002', true);
select throws_ok(
	$$
		select * from public.assign_physical_device(
			current_setting('test.physical_patient_a')::uuid,
			'SENDA-GPS-TEST-001'
		)
	$$,
	'42501',
	'ADMIN access to the patient is required.',
	'a MONITOR cannot assign a physical device'
);
reset role;

-- Ingestion (service role) --------------------------------------------------

set local role service_role;

select results_eq(
	$$
		select ingest_outcome
		from public.ingest_device_location(
			'990000000000099',
			'81000000-0000-0000-0000-000000000001'::uuid,
			18.4861,
			-69.9312,
			8,
			now() + interval '1 second'
		)
	$$,
	$$values ('UNKNOWN_DEVICE'::text)$$,
	'an unregistered hardware identifier is acknowledged as UNKNOWN_DEVICE'
);
select throws_ok(
	$$
		select * from public.ingest_device_location(
			'990000000000001',
			'81000000-0000-0000-0000-000000000002'::uuid,
			91,
			-69.9312,
			8,
			now() + interval '1 second'
		)
	$$,
	'22023',
	'Latitude is invalid.',
	'an invalid latitude is rejected'
);
select throws_ok(
	$$
		select * from public.ingest_device_location(
			'990000000000001',
			'81000000-0000-0000-0000-000000000003'::uuid,
			18.4861,
			-181,
			8,
			now() + interval '1 second'
		)
	$$,
	'22023',
	'Longitude is invalid.',
	'an invalid longitude is rejected'
);
select throws_ok(
	$$
		select * from public.ingest_device_location(
			'990000000000001',
			'81000000-0000-0000-0000-000000000004'::uuid,
			18.4861,
			-69.9312,
			-1,
			now() + interval '1 second'
		)
	$$,
	'22023',
	'Accuracy is invalid.',
	'a negative accuracy is rejected'
);
select throws_ok(
	$$
		select * from public.ingest_device_location(
			'990000000000001',
			'81000000-0000-0000-0000-000000000005'::uuid,
			18.4861,
			-69.9312,
			8,
			now() + interval '1 hour'
		)
	$$,
	'22023',
	'Recorded timestamp is too far in the future.',
	'a timestamp far in the future is rejected'
);
select results_eq(
	$$
		select ingest_outcome
		from public.ingest_device_location(
			'990000000000001',
			'81000000-0000-0000-0000-000000000006'::uuid,
			18.4861,
			-69.9312,
			8,
			now() - interval '1 hour'
		)
	$$,
	$$values ('PREDATES_ASSIGNMENT'::text)$$,
	'a reading captured before the assignment is not attached to the patient'
);
select results_eq(
	$$
		select ingest_outcome
		from public.ingest_device_location(
			' 990000000000001 ',
			'81000000-0000-0000-0000-000000000010'::uuid,
			18.4861,
			-69.9312,
			8,
			now() + interval '1 second'
		)
	$$,
	$$values ('CREATED'::text)$$,
	'a valid reading is created and the identifier is normalized'
);
select results_eq(
	$$
		select ingest_outcome
		from public.ingest_device_location(
			'990000000000001',
			'81000000-0000-0000-0000-000000000010'::uuid,
			18.4861,
			-69.9312,
			8,
			now() + interval '1 second'
		)
	$$,
	$$values ('DUPLICATE'::text)$$,
	'repeating the same event is acknowledged as DUPLICATE'
);
select results_eq(
	$$
		select ingest_outcome
		from public.ingest_device_location(
			'990000000000001',
			'81000000-0000-0000-0000-000000000010'::uuid,
			18.5000,
			-69.9000,
			8,
			now() + interval '1 second'
		)
	$$,
	$$values ('CONFLICT'::text)$$,
	'reusing an event identifier with different data is a CONFLICT'
);

reset role;

select results_eq(
	$$select count(*) from public.locations where device_assignment_id = current_setting('test.physical_assignment_a')::uuid$$,
	$$values (1::bigint)$$,
	'only the single valid reading was persisted'
);
select results_eq(
	$$select source from public.locations where device_assignment_id = current_setting('test.physical_assignment_a')::uuid$$,
	$$values ('DEVICE'::text)$$,
	'the persisted reading uses source DEVICE'
);
select results_eq(
	$$select device_assignment_id from public.locations where event_id = '81000000-0000-0000-0000-000000000010'$$,
	$$values (current_setting('test.physical_assignment_a')::uuid)$$,
	'the reading is linked to the active historical assignment'
);

-- Existing geofence and episode rules apply to DEVICE readings --------------

insert into public.safe_zones (
	patient_id,
	name,
	center_latitude,
	center_longitude,
	radius_m,
	created_by,
	updated_by
)
values (
	current_setting('test.physical_patient_a')::uuid,
	'Casa',
	18.4861,
	-69.9312,
	200,
	'71000000-0000-0000-0000-000000000001',
	'71000000-0000-0000-0000-000000000001'
);

set local role service_role;
select lives_ok(
	$$
		select * from public.ingest_device_location('990000000000001', '81000000-0000-0000-0000-000000000011'::uuid, 18.4900, -69.9312, 8, now() + interval '2 seconds')
		union all
		select * from public.ingest_device_location('990000000000001', '81000000-0000-0000-0000-000000000012'::uuid, 18.4950, -69.9312, 8, now() + interval '3 seconds')
		union all
		select * from public.ingest_device_location('990000000000001', '81000000-0000-0000-0000-000000000013'::uuid, 18.5000, -69.9312, 8, now() + interval '4 seconds')
	$$,
	'device readings leaving the safe zone are accepted'
);
reset role;

select results_eq(
	$$select geofence_relation from public.locations where device_assignment_id = current_setting('test.physical_assignment_a')::uuid order by id desc limit 1$$,
	$$values ('OUTSIDE'::text)$$,
	'the existing classifier evaluates the DEVICE reading as OUTSIDE'
);
select results_eq(
	$$select count(*) from public.alert_episodes where patient_id = current_setting('test.physical_patient_a')::uuid and status = 'OPEN'$$,
	$$values (1::bigint)$$,
	'two confirmed OUTSIDE device readings open one alert episode'
);

set local role service_role;
select lives_ok(
	$$
		select * from public.ingest_device_location('990000000000001', '81000000-0000-0000-0000-000000000014'::uuid, 18.4861, -69.9312, 8, now() + interval '5 seconds')
		union all
		select * from public.ingest_device_location('990000000000001', '81000000-0000-0000-0000-000000000015'::uuid, 18.4862, -69.9312, 8, now() + interval '6 seconds')
	$$,
	'device readings returning to the safe zone are accepted'
);
reset role;

select results_eq(
	$$select count(*) from public.alert_episodes where patient_id = current_setting('test.physical_patient_a')::uuid and status = 'RESOLVED'$$,
	$$values (1::bigint)$$,
	'two confirmed INSIDE device readings resolve the episode'
);

-- Late and out-of-order readings are stored without rewinding state ---------

set local role service_role;
select results_eq(
	$$
		select ingest_outcome
		from public.ingest_device_location(
			'990000000000001',
			'81000000-0000-0000-0000-000000000016'::uuid,
			18.5100,
			-69.9312,
			8,
			now() + interval '1 second'
		)
	$$,
	$$values ('CREATED'::text)$$,
	'a delayed OUTSIDE reading is stored'
);
reset role;

select results_eq(
	$$select count(*) from public.alert_episodes where patient_id = current_setting('test.physical_patient_a')::uuid and status = 'OPEN'$$,
	$$values (0::bigint)$$,
	'a delayed reading does not reopen or rewind the resolved episode'
);

-- Reassignment keeps history isolated ---------------------------------------

update public.device_assignments
set unassigned_at = now() + interval '10 seconds'
where id = current_setting('test.physical_assignment_a')::uuid;

set local role service_role;
select results_eq(
	$$
		select ingest_outcome
		from public.ingest_device_location(
			'990000000000001',
			'81000000-0000-0000-0000-000000000020'::uuid,
			18.4861,
			-69.9312,
			8,
			now() + interval '12 seconds'
		)
	$$,
	$$values ('NO_ACTIVE_ASSIGNMENT'::text)$$,
	'a registered device without an active assignment stores nothing'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', '73000000-0000-0000-0000-000000000003', true);
select lives_ok(
	$$select * from public.create_patient_onboarding('Familia Fisica C', 'FAMILY', 'Carla', 'Dispositivo')$$,
	'admin C can create a separate patient'
);
select set_config(
	'test.physical_patient_c',
	(select id::text from public.patients limit 1),
	true
);
select lives_ok(
	$$
		select * from public.assign_physical_device(
			current_setting('test.physical_patient_c')::uuid,
			'SENDA-GPS-TEST-001'
		)
	$$,
	'the device can be reassigned to another patient after unassignment'
);
reset role;

select set_config(
	'test.physical_assignment_c',
	(
		select id::text
		from public.device_assignments
		where patient_id = current_setting('test.physical_patient_c')::uuid
			and unassigned_at is null
	),
	true
);

-- Both assignments were created in this transaction, so give the new one a
-- later start to model a real reassignment.
update public.device_assignments
set assigned_at = now() + interval '11 seconds'
where id = current_setting('test.physical_assignment_c')::uuid;

set local role service_role;
select results_eq(
	$$
		select ingest_outcome
		from public.ingest_device_location(
			'990000000000001',
			'81000000-0000-0000-0000-000000000021'::uuid,
			18.4700,
			-69.9200,
			8,
			now() + interval '15 seconds'
		)
	$$,
	$$values ('CREATED'::text)$$,
	'a new reading is attached to the new patient assignment'
);
select results_eq(
	$$
		select ingest_outcome
		from public.ingest_device_location(
			'990000000000001',
			'81000000-0000-0000-0000-000000000022'::uuid,
			18.4861,
			-69.9312,
			8,
			now() + interval '5 seconds'
		)
	$$,
	$$values ('PREDATES_ASSIGNMENT'::text)$$,
	'a late reading from the previous assignment is not attached to the new patient'
);
reset role;

select results_eq(
	$$
		select count(*)
		from public.locations
		where device_assignment_id = current_setting('test.physical_assignment_c')::uuid
	$$,
	$$values (1::bigint)$$,
	'the new assignment holds exactly its own reading'
);
select results_eq(
	$$
		select count(*) > 1
		from public.locations
		where device_assignment_id = current_setting('test.physical_assignment_a')::uuid
	$$,
	$$values (true)$$,
	'the previous assignment keeps its own historical readings'
);

-- Read access follows patient_access ----------------------------------------

set local role authenticated;
select set_config('request.jwt.claim.sub', '73000000-0000-0000-0000-000000000003', true);
select results_eq(
	$$select count(*) from public.locations$$,
	$$values (1::bigint)$$,
	'the new patient admin cannot read the previous patient history'
);
select set_config('request.jwt.claim.sub', '72000000-0000-0000-0000-000000000002', true);
select ok(
	(select count(*) from public.locations) > 1,
	'a MONITOR can read the authorized physical-device history'
);
select set_config('request.jwt.claim.sub', '74000000-0000-0000-0000-000000000004', true);
select results_eq(
	$$select count(*) from public.locations$$,
	$$values (0::bigint)$$,
	'an outsider cannot read physical-device locations'
);
select throws_ok(
	$$
		insert into public.locations (device_assignment_id, event_id, latitude, longitude, recorded_at, source)
		values (gen_random_uuid(), gen_random_uuid(), 18.4, -69.9, now(), 'DEVICE')
	$$,
	'42501',
	'permission denied for table locations',
	'authenticated users cannot insert DEVICE locations directly'
);

select * from finish();
rollback;
