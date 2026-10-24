begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(17);

select has_table('public', 'invitations', 'invitations table exists');
select ok((select relrowsecurity from pg_class where oid = 'public.invitations'::regclass), 'invitations has RLS enabled');

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values
('00000000-0000-0000-0000-000000000000', '50000000-0000-0000-0000-000000000005', 'authenticated', 'authenticated', 'code-admin@example.test', '', now(), now(), now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb),
('00000000-0000-0000-0000-000000000000', '60000000-0000-0000-0000-000000000006', 'authenticated', 'authenticated', 'code-monitor@example.test', '', now(), now(), now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb);

set local role authenticated;
select set_config('request.jwt.claim.sub', '50000000-0000-0000-0000-000000000005', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select lives_ok($$select * from public.create_patient_onboarding('Familia código', 'FAMILY', 'María', 'Prueba')$$, 'admin creates patient');
select set_config('test.code_patient_id', (select id::text from public.patients limit 1), true);

select lives_ok($$select * from public.create_patient_access_code(current_setting('test.code_patient_id')::uuid)$$, 'ADMIN generates a code');
select set_config('test.access_code', (select access_code from public.create_patient_access_code(current_setting('test.code_patient_id')::uuid) limit 1), true);

select throws_ok(
	$$select count(*) from public.invitations$$,
	'42501',
	'permission denied for table invitations',
	'invitation rows are not directly exposed'
);
select results_eq($$select length(current_setting('test.access_code'))$$, $$values (14)$$, 'generated code has readable format');

select set_config('request.jwt.claim.sub', '60000000-0000-0000-0000-000000000006', true);
select results_eq(
	$$select patient_first_name from public.preview_patient_access_code(current_setting('test.access_code'))$$,
	$$values ('María'::text)$$,
	'monitor previews minimal patient data'
);
select lives_ok($$select * from public.accept_patient_access_code(current_setting('test.access_code'))$$, 'monitor accepts code');
select results_eq($$select access_role from public.patient_access$$, $$values ('MONITOR'::text)$$, 'recipient receives MONITOR access');
select results_eq($$select count(*) from public.patients$$, $$values (1::bigint)$$, 'recipient sees only the authorized patient');
select throws_ok(
	$$select * from public.accept_patient_access_code(current_setting('test.access_code'))$$,
	'22023',
	'Access code is invalid or already used.',
	'code cannot be reused'
);

reset role;
select ok(not has_function_privilege('anon', 'public.create_patient_access_code(uuid)', 'EXECUTE'), 'anon cannot generate codes');
select ok(not has_function_privilege('anon', 'public.preview_patient_access_code(text)', 'EXECUTE'), 'anon cannot preview codes');
select ok(not has_function_privilege('anon', 'public.accept_patient_access_code(text)', 'EXECUTE'), 'anon cannot accept codes');
select ok(has_function_privilege('authenticated', 'public.create_patient_access_code(uuid)', 'EXECUTE'), 'authenticated can call generation RPC with internal authorization');
select ok(not has_table_privilege('authenticated', 'public.invitations', 'SELECT'), 'authenticated cannot select invitation hashes');
select ok(not has_table_privilege('authenticated', 'public.invitations', 'INSERT'), 'authenticated cannot insert invitations directly');

select * from finish();
rollback;
