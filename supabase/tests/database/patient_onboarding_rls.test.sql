begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(22);

select has_table('public', 'groups', 'groups table exists');
select has_table('public', 'patients', 'patients table exists');
select has_table('public', 'patient_access', 'patient_access table exists');

select ok(
	(select relrowsecurity from pg_class where oid = 'public.groups'::regclass),
	'groups has RLS enabled'
);
select ok(
	(select relrowsecurity from pg_class where oid = 'public.patients'::regclass),
	'patients has RLS enabled'
);
select ok(
	(select relrowsecurity from pg_class where oid = 'public.patient_access'::regclass),
	'patient_access has RLS enabled'
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
		'10000000-0000-0000-0000-000000000001',
		'authenticated',
		'authenticated',
		'patient-owner-a@example.test',
		'',
		now(),
		now(),
		now(),
		'{"provider":"email","providers":["email"]}'::jsonb,
		'{"full_name":"Owner A"}'::jsonb
	),
	(
		'00000000-0000-0000-0000-000000000000',
		'20000000-0000-0000-0000-000000000002',
		'authenticated',
		'authenticated',
		'patient-owner-b@example.test',
		'',
		now(),
		now(),
		now(),
		'{"provider":"email","providers":["email"]}'::jsonb,
		'{"full_name":"Owner B"}'::jsonb
	);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select lives_ok(
	$$select * from public.create_patient_onboarding('Familia A', 'FAMILY', 'Ana', 'Prueba')$$,
	'user A can create an owned group and patient atomically'
);

select results_eq(
	$$select count(*) from public.groups$$,
	$$values (1::bigint)$$,
	'user A sees their group'
);
select results_eq(
	$$select count(*) from public.patients$$,
	$$values (1::bigint)$$,
	'user A sees their patient'
);
select results_eq(
	$$select count(*) from public.patient_access where access_role = 'ADMIN'$$,
	$$values (1::bigint)$$,
	'user A receives ADMIN access'
);

select set_config(
	'test.group_a_id',
	(select id::text from public.groups limit 1),
	true
);

select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-000000000002', true);

select results_eq(
	$$select count(*) from public.groups$$,
	$$values (0::bigint)$$,
	'user B cannot read user A group'
);
select results_eq(
	$$select count(*) from public.patients$$,
	$$values (0::bigint)$$,
	'user B cannot read user A patient'
);
select results_eq(
	$$select count(*) from public.patient_access$$,
	$$values (0::bigint)$$,
	'user B cannot read user A access row'
);

select throws_ok(
	$$
		insert into public.patients (group_id, first_name, last_name)
		values (current_setting('test.group_a_id')::uuid, 'Intruso', 'Prueba')
	$$,
	'42501',
	'new row violates row-level security policy for table "patients"',
	'user B cannot add a patient to user A group'
);

select lives_ok(
	$$select * from public.create_patient_onboarding('Centro B', 'CARE_CENTER', 'Bruno', 'Prueba')$$,
	'user B can create their own onboarding data'
);

select results_eq(
	$$select count(*) from public.groups$$,
	$$values (1::bigint)$$,
	'user B sees only their own group'
);
select results_eq(
	$$select count(*) from public.patients$$,
	$$values (1::bigint)$$,
	'user B sees only their own patient'
);
select results_eq(
	$$select count(*) from public.patient_access where access_role = 'ADMIN'$$,
	$$values (1::bigint)$$,
	'user B sees only their own ADMIN access'
);

reset role;

select ok(
	not has_function_privilege(
		'anon',
		'public.create_patient_onboarding(text,text,text,text)',
		'EXECUTE'
	),
	'anon cannot execute patient onboarding'
);
select ok(
	has_function_privilege(
		'authenticated',
		'public.create_patient_onboarding(text,text,text,text)',
		'EXECUTE'
	),
	'authenticated users can execute patient onboarding'
);

select ok(
	not has_function_privilege(
		'anon',
		'private.is_group_owner(uuid)',
		'EXECUTE'
	),
	'anon cannot execute the private group ownership helper'
);

select ok(
	has_function_privilege(
		'authenticated',
		'private.is_group_owner(uuid)',
		'EXECUTE'
	),
	'authenticated policies can execute the private group ownership helper'
);

select * from finish();
rollback;
