begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(23);

select has_table('public', 'devices', 'devices table exists');
select has_table('public', 'device_assignments', 'device_assignments table exists');

select ok(
	(select relrowsecurity from pg_class where oid = 'public.devices'::regclass),
	'devices has RLS enabled'
);
select ok(
	(select relrowsecurity from pg_class where oid = 'public.device_assignments'::regclass),
	'device_assignments has RLS enabled'
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
		'30000000-0000-0000-0000-000000000003',
		'authenticated',
		'authenticated',
		'device-owner-a@example.test',
		'',
		now(),
		now(),
		now(),
		'{"provider":"email","providers":["email"]}'::jsonb,
		'{"full_name":"Device Owner A"}'::jsonb
	),
	(
		'00000000-0000-0000-0000-000000000000',
		'40000000-0000-0000-0000-000000000004',
		'authenticated',
		'authenticated',
		'device-owner-b@example.test',
		'',
		now(),
		now(),
		now(),
		'{"provider":"email","providers":["email"]}'::jsonb,
		'{"full_name":"Device Owner B"}'::jsonb
	);

insert into public.devices (serial_number, device_kind)
values
	('SENDA-TEST-001', 'SIMULATED'),
	('SENDA-TEST-002', 'SIMULATED');

set local role authenticated;
select set_config('request.jwt.claim.sub', '30000000-0000-0000-0000-000000000003', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select lives_ok(
	$$select * from public.create_patient_onboarding('Familia dispositivo A', 'FAMILY', 'Alba', 'Prueba')$$,
	'user A can create their patient'
);

select set_config(
	'test.patient_a_id',
	(select id::text from public.patients limit 1),
	true
);

select results_eq(
	$$select count(*) from public.devices where serial_number like 'SENDA-TEST-%'$$,
	$$values (0::bigint)$$,
	'unassigned inventory is not exposed to user A'
);

select lives_ok(
	$$
		select *
		from public.assign_simulated_device(
			current_setting('test.patient_a_id')::uuid,
			' senda-test-001 '
		)
	$$,
	'user A can assign a registered serial to their patient'
);

select results_eq(
	$$select count(*) from public.device_assignments$$,
	$$values (1::bigint)$$,
	'user A can read the active assignment'
);
select results_eq(
	$$select serial_number from public.devices$$,
	$$values ('SENDA-TEST-001'::text)$$,
	'user A can read only the assigned device'
);

select throws_ok(
	$$
		select *
		from public.assign_simulated_device(
			current_setting('test.patient_a_id')::uuid,
			'SENDA-TEST-002'
		)
	$$,
	'23505',
	'Patient already has an active device.',
	'a patient cannot have two active devices'
);

select throws_ok(
	$$
		select *
		from public.assign_simulated_device(
			current_setting('test.patient_a_id')::uuid,
			'SENDA-UNKNOWN-001'
		)
	$$,
	'22023',
	'Serial is not registered.',
	'an unknown serial cannot be assigned'
);

select set_config('request.jwt.claim.sub', '40000000-0000-0000-0000-000000000004', true);

select results_eq(
	$$select count(*) from public.device_assignments$$,
	$$values (0::bigint)$$,
	'user B cannot read user A assignment'
);
select results_eq(
	$$select count(*) from public.devices$$,
	$$values (0::bigint)$$,
	'user B cannot read user A device'
);

select throws_ok(
	$$
		select *
		from public.assign_simulated_device(
			current_setting('test.patient_a_id')::uuid,
			'SENDA-TEST-002'
		)
	$$,
	'42501',
	'ADMIN access to the patient is required.',
	'user B cannot configure user A patient'
);

reset request.jwt.claim.sub;
select throws_ok(
	$$select * from public.assign_simulated_device(gen_random_uuid(), 'SENDA-TEST-002')$$,
	'42501',
	'Authentication is required.',
	'a request without a valid user claim is rejected'
);

reset role;

select ok(
	not has_function_privilege('anon', 'public.assign_simulated_device(uuid,text)', 'EXECUTE'),
	'anon cannot execute device assignment'
);
select ok(
	has_function_privilege('authenticated', 'public.assign_simulated_device(uuid,text)', 'EXECUTE'),
	'authenticated users can execute the public device assignment wrapper'
);
select ok(
	not has_table_privilege('authenticated', 'public.devices', 'INSERT'),
	'authenticated users cannot insert device inventory directly'
);
select ok(
	not has_table_privilege('authenticated', 'public.device_assignments', 'INSERT'),
	'authenticated users cannot insert assignments directly'
);
select ok(
	not has_table_privilege('authenticated', 'public.devices', 'UPDATE'),
	'authenticated users cannot update device inventory directly'
);
select ok(
	not has_table_privilege('authenticated', 'public.device_assignments', 'UPDATE'),
	'authenticated users cannot update assignments directly'
);
select ok(
	not has_table_privilege('anon', 'public.devices', 'SELECT'),
	'anon cannot read device inventory'
);
select ok(
	not has_table_privilege('anon', 'public.device_assignments', 'SELECT'),
	'anon cannot read assignments'
);

select * from finish();
rollback;
