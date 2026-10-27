begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(32);

select has_function(
	'public',
	'list_patient_access',
	array['uuid'],
	'patient access roster RPC exists'
);
select has_function(
	'public',
	'update_patient_admin_data',
	array['uuid', 'text', 'text'],
	'patient update RPC exists'
);
select has_function(
	'public',
	'revoke_patient_monitor_access',
	array['uuid'],
	'MONITOR revocation RPC exists'
);
select ok(
	has_function_privilege('authenticated', 'public.list_patient_access(uuid)', 'EXECUTE'),
	'authenticated can execute the roster RPC'
);
select ok(
	not has_function_privilege('anon', 'public.list_patient_access(uuid)', 'EXECUTE'),
	'anon cannot execute the roster RPC'
);
select ok(
	has_function_privilege('authenticated', 'public.update_patient_admin_data(uuid,text,text)', 'EXECUTE'),
	'authenticated can execute the patient update RPC'
);
select ok(
	not has_function_privilege('anon', 'public.update_patient_admin_data(uuid,text,text)', 'EXECUTE'),
	'anon cannot execute the patient update RPC'
);
select ok(
	has_function_privilege('authenticated', 'public.revoke_patient_monitor_access(uuid)', 'EXECUTE'),
	'authenticated can execute the revocation RPC'
);
select ok(
	not has_function_privilege('anon', 'public.revoke_patient_monitor_access(uuid)', 'EXECUTE'),
	'anon cannot execute the revocation RPC'
);
select ok(
	not has_table_privilege('authenticated', 'public.patients', 'UPDATE'),
	'authenticated cannot update patients directly'
);
select ok(
	not has_table_privilege('authenticated', 'public.patient_access', 'UPDATE'),
	'authenticated cannot revoke access directly'
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
	'a1000000-0000-0000-0000-000000000001',
	'authenticated',
	'authenticated',
	'patient-admin@example.test',
	'',
	now(),
	now(),
	now(),
	'{"provider":"email","providers":["email"]}'::jsonb,
	'{"full_name":"Ana Administradora"}'::jsonb
),
(
	'00000000-0000-0000-0000-000000000000',
	'b2000000-0000-0000-0000-000000000002',
	'authenticated',
	'authenticated',
	'patient-monitor@example.test',
	'',
	now(),
	now(),
	now(),
	'{"provider":"email","providers":["email"]}'::jsonb,
	'{"full_name":"Mario Monitor"}'::jsonb
),
(
	'00000000-0000-0000-0000-000000000000',
	'c3000000-0000-0000-0000-000000000003',
	'authenticated',
	'authenticated',
	'patient-outsider@example.test',
	'',
	now(),
	now(),
	now(),
	'{"provider":"email","providers":["email"]}'::jsonb,
	'{"full_name":"Olga Externa"}'::jsonb
);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'a1000000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select lives_ok(
	$$select * from public.create_patient_onboarding('Familia administración', 'FAMILY', 'María', 'Inicial')$$,
	'ADMIN creates the patient used by the suite'
);
select set_config('test.patient_id', (select id::text from public.patients limit 1), true);
select set_config(
	'test.admin_access_id',
	(select id::text from public.patient_access where access_role = 'ADMIN' limit 1),
	true
);
select set_config(
	'test.access_code',
	(
		select access_code
		from public.create_patient_access_code(current_setting('test.patient_id')::uuid)
		limit 1
	),
	true
);

select set_config('request.jwt.claim.sub', 'b2000000-0000-0000-0000-000000000002', true);
select lives_ok(
	$$select * from public.accept_patient_access_code(current_setting('test.access_code'))$$,
	'MONITOR accepts access to the patient'
);
select set_config(
	'test.monitor_access_id',
	(select id::text from public.patient_access where user_id = (select auth.uid()) limit 1),
	true
);

select set_config('request.jwt.claim.sub', 'a1000000-0000-0000-0000-000000000001', true);
select results_eq(
	$$select count(*) from public.list_patient_access(current_setting('test.patient_id')::uuid)$$,
	$$values (2::bigint)$$,
	'ADMIN sees both active access records'
);
select results_eq(
	$$select display_name from public.list_patient_access(current_setting('test.patient_id')::uuid) order by access_role, display_name$$,
	$$values ('Ana Administradora'::text), ('Mario Monitor'::text)$$,
	'roster exposes display names but no auth email lookup is needed'
);
select results_eq(
	$$select access_role from public.list_patient_access(current_setting('test.patient_id')::uuid) order by access_role$$,
	$$values ('ADMIN'::text), ('MONITOR'::text)$$,
	'roster identifies ADMIN and MONITOR roles'
);
select results_eq(
	$$select count(*) from public.list_patient_access(current_setting('test.patient_id')::uuid) where is_current_user$$,
	$$values (1::bigint)$$,
	'roster marks only the current ADMIN'
);
select lives_ok(
	$$select * from public.update_patient_admin_data(current_setting('test.patient_id')::uuid, '  María Elena  ', '  Actualizada  ')$$,
	'ADMIN updates the patient name'
);
select results_eq(
	$$select first_name || ' ' || last_name from public.patients where id = current_setting('test.patient_id')::uuid$$,
	$$values ('María Elena Actualizada'::text)$$,
	'patient names are trimmed and persisted'
);
select throws_ok(
	$$update public.patients set first_name = 'Directo' where id = current_setting('test.patient_id')::uuid$$,
	'42501',
	'permission denied for table patients',
	'direct patient updates remain blocked'
);
select throws_ok(
	$$update public.patient_access set revoked_at = now() where id = current_setting('test.monitor_access_id')::uuid$$,
	'42501',
	'permission denied for table patient_access',
	'direct access revocation remains blocked'
);
select throws_ok(
	$$select * from public.revoke_patient_monitor_access(current_setting('test.admin_access_id')::uuid)$$,
	'22023',
	'Only active MONITOR access can be revoked.',
	'ADMIN access cannot be revoked by the MONITOR-only RPC'
);

select set_config('request.jwt.claim.sub', 'b2000000-0000-0000-0000-000000000002', true);
select throws_ok(
	$$select * from public.list_patient_access(current_setting('test.patient_id')::uuid)$$,
	'42501',
	'ADMIN access to the patient is required.',
	'MONITOR cannot list the access roster'
);
select throws_ok(
	$$select * from public.update_patient_admin_data(current_setting('test.patient_id')::uuid, 'Sin', 'Permiso')$$,
	'42501',
	'ADMIN access to the patient is required.',
	'MONITOR cannot edit patient data'
);
select throws_ok(
	$$select * from public.revoke_patient_monitor_access(current_setting('test.monitor_access_id')::uuid)$$,
	'42501',
	'ADMIN access to the patient is required.',
	'MONITOR cannot revoke their own access'
);

select set_config('request.jwt.claim.sub', 'c3000000-0000-0000-0000-000000000003', true);
select throws_ok(
	$$select * from public.list_patient_access(current_setting('test.patient_id')::uuid)$$,
	'42501',
	'ADMIN access to the patient is required.',
	'external user cannot list patient access'
);
select throws_ok(
	$$select * from public.update_patient_admin_data(current_setting('test.patient_id')::uuid, 'Sin', 'Acceso')$$,
	'42501',
	'ADMIN access to the patient is required.',
	'external user cannot edit patient data'
);
select throws_ok(
	$$select * from public.revoke_patient_monitor_access(current_setting('test.monitor_access_id')::uuid)$$,
	'42501',
	'ADMIN access to the patient is required.',
	'external user cannot revoke patient access'
);

select set_config('request.jwt.claim.sub', 'a1000000-0000-0000-0000-000000000001', true);
select lives_ok(
	$$select * from public.revoke_patient_monitor_access(current_setting('test.monitor_access_id')::uuid)$$,
	'ADMIN revokes MONITOR access'
);

-- Active-access RLS intentionally hides revoked rows from application users.
-- Return to the session owner only for the audit-preservation assertion.
reset role;
select results_eq(
	$$select count(*) from public.patient_access where id = current_setting('test.monitor_access_id')::uuid and revoked_at is not null$$,
	$$values (1::bigint)$$,
	'revocation preserves the access row and sets revoked_at'
);
set local role authenticated;
select results_eq(
	$$select count(*) from public.list_patient_access(current_setting('test.patient_id')::uuid)$$,
	$$values (1::bigint)$$,
	'revoked access disappears from the active roster'
);

select set_config('request.jwt.claim.sub', 'b2000000-0000-0000-0000-000000000002', true);
select results_eq(
	$$select count(*) from public.patients where id = current_setting('test.patient_id')::uuid$$,
	$$values (0::bigint)$$,
	'revoked MONITOR immediately loses patient visibility through RLS'
);

select * from finish();
rollback;
