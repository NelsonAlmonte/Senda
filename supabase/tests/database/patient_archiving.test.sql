begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(38);

select has_column('public', 'patients', 'archived_at', 'patients record the archive timestamp');
select has_column('public', 'patients', 'archived_by', 'patients record the archiving ADMIN');
select has_column(
	'public',
	'invitations',
	'invalidated_at',
	'pending invitations can be invalidated without an EXPIRED status'
);
select has_column(
	'public',
	'invitations',
	'invalidated_by',
	'invitation invalidation records its ADMIN actor'
);
select has_function('public', 'archive_patient', array['uuid'], 'the archive RPC exists');
select has_function('public', 'restore_patient', array['uuid'], 'the restore RPC exists');
select ok(
	has_function_privilege('authenticated', 'public.archive_patient(uuid)', 'EXECUTE'),
	'authenticated users can call the authorized archive wrapper'
);
select ok(
	not has_function_privilege('anon', 'public.archive_patient(uuid)', 'EXECUTE'),
	'anon cannot archive patients'
);
select ok(
	not has_function_privilege('service_role', 'public.archive_patient(uuid)', 'EXECUTE'),
	'service_role cannot call the user-scoped archive wrapper directly'
);
select ok(
	has_function_privilege('authenticated', 'public.restore_patient(uuid)', 'EXECUTE'),
	'authenticated users can call the authorized restore wrapper'
);
select ok(
	not has_table_privilege('authenticated', 'public.patients', 'UPDATE'),
	'authenticated users still cannot update patient lifecycle fields directly'
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
		'c1000000-0000-0000-0000-000000000001',
		'authenticated',
		'authenticated',
		'archive-admin@example.test',
		'',
		now(),
		now(),
		now(),
		'{"provider":"email","providers":["email"]}'::jsonb,
		'{}'::jsonb
	),
	(
		'00000000-0000-0000-0000-000000000000',
		'c2000000-0000-0000-0000-000000000002',
		'authenticated',
		'authenticated',
		'archive-monitor@example.test',
		'',
		now(),
		now(),
		now(),
		'{"provider":"email","providers":["email"]}'::jsonb,
		'{}'::jsonb
	),
	(
		'00000000-0000-0000-0000-000000000000',
		'c3000000-0000-0000-0000-000000000003',
		'authenticated',
		'authenticated',
		'archive-outsider@example.test',
		'',
		now(),
		now(),
		now(),
		'{"provider":"email","providers":["email"]}'::jsonb,
		'{}'::jsonb
	);

select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', 'c1000000-0000-0000-0000-000000000001', true);

insert into public.groups (id, name, type, owner_user_id)
values (
	'c4000000-0000-0000-0000-000000000004',
	'Familia archivo',
	'FAMILY',
	'c1000000-0000-0000-0000-000000000001'
);

insert into public.patients (id, group_id, first_name, last_name)
values
	(
		'c5000000-0000-0000-0000-000000000005',
		'c4000000-0000-0000-0000-000000000004',
		'María',
		'Archivable'
	),
	(
		'c6000000-0000-0000-0000-000000000006',
		'c4000000-0000-0000-0000-000000000004',
		'Juan',
		'Con dispositivo'
	),
	(
		'c7000000-0000-0000-0000-000000000007',
		'c4000000-0000-0000-0000-000000000004',
		'Ana',
		'Con traslado'
	);

insert into public.patient_access (patient_id, user_id, access_role)
values (
	'c5000000-0000-0000-0000-000000000005',
	'c2000000-0000-0000-0000-000000000002',
	'MONITOR'
);

insert into public.safe_zones (
	id,
	patient_id,
	name,
	center_latitude,
	center_longitude,
	radius_m,
	created_by,
	updated_by
)
values (
	'c8000000-0000-0000-0000-000000000008',
	'c5000000-0000-0000-0000-000000000005',
	'Casa',
	18.4861,
	-69.9312,
	250,
	'c1000000-0000-0000-0000-000000000001',
	'c1000000-0000-0000-0000-000000000001'
);

insert into public.devices (id, serial_number, device_kind)
values
	(
		'c9000000-0000-0000-0000-000000000009',
		'SENDA-TEST-ARCHIVE-001',
		'SIMULATED'
	),
	(
		'ca000000-0000-0000-0000-000000000010',
		'SENDA-TEST-ARCHIVE-002',
		'SIMULATED'
	);

insert into public.device_assignments (id, device_id, patient_id)
values (
	'cb000000-0000-0000-0000-000000000011',
	'c9000000-0000-0000-0000-000000000009',
	'c6000000-0000-0000-0000-000000000006'
);

create temporary table archive_test_codes (access_code text not null);

set local role authenticated;

insert into archive_test_codes (access_code)
select access_code
from public.create_patient_access_code('c5000000-0000-0000-0000-000000000005');

select set_config('request.jwt.claim.sub', 'c2000000-0000-0000-0000-000000000002', true);
select throws_ok(
	$$select * from public.archive_patient('c5000000-0000-0000-0000-000000000005')$$,
	'42501',
	'ADMIN access to the patient is required.',
	'a MONITOR cannot archive a patient'
);

select set_config('request.jwt.claim.sub', 'c3000000-0000-0000-0000-000000000003', true);
select throws_ok(
	$$select * from public.archive_patient('c5000000-0000-0000-0000-000000000005')$$,
	'42501',
	'ADMIN access to the patient is required.',
	'an outsider cannot archive a patient'
);

reset request.jwt.claim.sub;
select throws_ok(
	$$select * from public.archive_patient('c5000000-0000-0000-0000-000000000005')$$,
	'42501',
	'Authentication is required.',
	'an unauthenticated caller cannot archive a patient'
);

select set_config('request.jwt.claim.sub', 'c1000000-0000-0000-0000-000000000001', true);
select throws_ok(
	$$select * from public.archive_patient('c6000000-0000-0000-0000-000000000006')$$,
	'55000',
	'The active device must be unassigned before the patient can be archived.',
	'an active device prevents patient archiving'
);

select lives_ok(
	$$select * from public.save_patient_planned_transfer(
		null,
		'c7000000-0000-0000-0000-000000000007',
		clock_timestamp() + interval '1 hour',
		clock_timestamp() + interval '2 hours',
		'Traslado futuro'
	)$$,
	'an ADMIN can create the scheduled transfer guard fixture'
);
select throws_ok(
	$$select * from public.archive_patient('c7000000-0000-0000-0000-000000000007')$$,
	'55000',
	'Current and scheduled transfers must finish or be cancelled before the patient can be archived.',
	'a scheduled transfer prevents patient archiving'
);

select lives_ok(
	$$select * from public.archive_patient('c5000000-0000-0000-0000-000000000005')$$,
	'an ADMIN can archive an eligible patient'
);
select results_eq(
	$$select archived_by from public.patients where id = 'c5000000-0000-0000-0000-000000000005' and archived_at is not null$$,
	$$values ('c1000000-0000-0000-0000-000000000001'::uuid)$$,
	'the archive timestamp and ADMIN actor are recorded'
);
select results_eq(
	$$select invalidated_by from public.invitations where patient_id = 'c5000000-0000-0000-0000-000000000005' and invalidated_at is not null$$,
	$$values ('c1000000-0000-0000-0000-000000000001'::uuid)$$,
	'pending invitations are permanently invalidated by the archiving ADMIN'
);
select results_eq(
	$$select count(*) from public.patient_access where patient_id = 'c5000000-0000-0000-0000-000000000005' and revoked_at is null$$,
	$$values (2::bigint)$$,
	'patient access rows remain active after archiving'
);
select results_eq(
	$$select count(*) from public.safe_zones where patient_id = 'c5000000-0000-0000-0000-000000000005'$$,
	$$values (1::bigint)$$,
	'safe zones are preserved after archiving'
);
select results_eq(
	$$select count(*) from public.preview_patient_access_code((select access_code from archive_test_codes))$$,
	$$values (0::bigint)$$,
	'an invalidated code no longer exposes a patient preview'
);
select throws_ok(
	$$select * from public.accept_patient_access_code((select access_code from archive_test_codes))$$,
	'22023',
	'Access code is invalid or already used.',
	'an invalidated code cannot be accepted'
);
select throws_ok(
	$$select * from public.assign_simulated_device(
		'c5000000-0000-0000-0000-000000000005',
		'SENDA-TEST-ARCHIVE-002'
	)$$,
	'55000',
	'Patient is archived.',
	'an archived patient cannot receive a device'
);
select throws_ok(
	$$select * from public.save_patient_safe_zone(
		'c8000000-0000-0000-0000-000000000008',
		'c5000000-0000-0000-0000-000000000005',
		'Casa editada',
		18.4862,
		-69.9313,
		300,
		true
	)$$,
	'55000',
	'Patient is archived.',
	'an archived patient safe zone cannot be edited'
);
select throws_ok(
	$$select * from public.save_patient_planned_transfer(
		null,
		'c5000000-0000-0000-0000-000000000005',
		clock_timestamp() + interval '1 hour',
		clock_timestamp() + interval '2 hours',
		'No permitido'
	)$$,
	'55000',
	'Patient is archived.',
	'an archived patient cannot receive a planned transfer'
);
select throws_ok(
	$$select * from public.update_patient_admin_data(
		'c5000000-0000-0000-0000-000000000005',
		'Nombre',
		'Nuevo'
	)$$,
	'55000',
	'Patient is archived.',
	'archived patient administrative data is read-only'
);
select throws_ok(
	$$select * from public.archive_patient('c5000000-0000-0000-0000-000000000005')$$,
	'55000',
	'Patient is archived.',
	'an archived patient cannot be archived twice'
);

select set_config('request.jwt.claim.sub', 'c2000000-0000-0000-0000-000000000002', true);
select results_eq(
	$$select count(*) from public.patients where id = 'c5000000-0000-0000-0000-000000000005'$$,
	$$values (1::bigint)$$,
	'an authorized MONITOR retains read access to the archived patient'
);
select results_eq(
	$$select count(*) from public.safe_zones where patient_id = 'c5000000-0000-0000-0000-000000000005'$$,
	$$values (1::bigint)$$,
	'an authorized MONITOR retains read access to preserved history'
);
select throws_ok(
	$$select * from public.restore_patient('c5000000-0000-0000-0000-000000000005')$$,
	'42501',
	'ADMIN access to the patient is required.',
	'a MONITOR cannot restore an archived patient'
);

select set_config('request.jwt.claim.sub', 'c1000000-0000-0000-0000-000000000001', true);
select lives_ok(
	$$select * from public.restore_patient('c5000000-0000-0000-0000-000000000005')$$,
	'an ADMIN can restore an archived patient'
);
select results_eq(
	$$select count(*) from public.patients where id = 'c5000000-0000-0000-0000-000000000005' and archived_at is null and archived_by is null$$,
	$$values (1::bigint)$$,
	'restoration returns the patient to the active state'
);
select results_eq(
	$$select count(*) from public.invitations where patient_id = 'c5000000-0000-0000-0000-000000000005' and invalidated_at is not null$$,
	$$values (1::bigint)$$,
	'restoration does not revive invalidated invitations'
);
select throws_ok(
	$$select * from public.accept_patient_access_code((select access_code from archive_test_codes))$$,
	'22023',
	'Access code is invalid or already used.',
	'the old code remains invalid after restoration'
);
select lives_ok(
	$$select * from public.assign_simulated_device(
		'c5000000-0000-0000-0000-000000000005',
		'SENDA-TEST-ARCHIVE-002'
	)$$,
	'a restored patient can receive a new device'
);
select throws_ok(
	$$select * from public.restore_patient('c5000000-0000-0000-0000-000000000005')$$,
	'55000',
	'Patient is not archived.',
	'an active patient cannot be restored again'
);

reset role;

select * from finish();
rollback;
