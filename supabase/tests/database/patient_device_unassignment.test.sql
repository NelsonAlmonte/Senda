begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(21);

select has_column(
	'public',
	'device_assignments',
	'unassigned_by',
	'device assignment removal records its ADMIN actor'
);
select has_function(
	'public',
	'unassign_patient_device',
	array['uuid', 'uuid'],
	'the public device unassignment RPC exists'
);
select ok(
	has_function_privilege(
		'authenticated',
		'public.unassign_patient_device(uuid,uuid)',
		'EXECUTE'
	),
	'authenticated users can call the authorized wrapper'
);
select ok(
	not has_function_privilege('anon', 'public.unassign_patient_device(uuid,uuid)', 'EXECUTE'),
	'anon cannot execute device unassignment'
);
select ok(
	not has_function_privilege(
		'service_role',
		'public.unassign_patient_device(uuid,uuid)',
		'EXECUTE'
	),
	'service_role cannot call the user-scoped wrapper directly'
);
select ok(
	not has_table_privilege('authenticated', 'public.device_assignments', 'UPDATE'),
	'authenticated users still cannot update assignments directly'
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
		'b1000000-0000-0000-0000-000000000001',
		'authenticated',
		'authenticated',
		'unassign-admin@example.test',
		'',
		now(),
		now(),
		now(),
		'{"provider":"email","providers":["email"]}'::jsonb,
		'{}'::jsonb
	),
	(
		'00000000-0000-0000-0000-000000000000',
		'b2000000-0000-0000-0000-000000000002',
		'authenticated',
		'authenticated',
		'unassign-monitor@example.test',
		'',
		now(),
		now(),
		now(),
		'{"provider":"email","providers":["email"]}'::jsonb,
		'{}'::jsonb
	),
	(
		'00000000-0000-0000-0000-000000000000',
		'b3000000-0000-0000-0000-000000000003',
		'authenticated',
		'authenticated',
		'unassign-outsider@example.test',
		'',
		now(),
		now(),
		now(),
		'{"provider":"email","providers":["email"]}'::jsonb,
		'{}'::jsonb
	);

select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', 'b1000000-0000-0000-0000-000000000001', true);

insert into public.groups (id, name, type, owner_user_id)
values (
	'b4000000-0000-0000-0000-000000000004',
	'Familia desvinculación',
	'FAMILY',
	'b1000000-0000-0000-0000-000000000001'
);

insert into public.patients (id, group_id, first_name, last_name)
values
	(
		'b5000000-0000-0000-0000-000000000005',
		'b4000000-0000-0000-0000-000000000004',
		'María',
		'Historial'
	),
	(
		'b6000000-0000-0000-0000-000000000006',
		'b4000000-0000-0000-0000-000000000004',
		'Juan',
		'Reasignado'
	);

insert into public.patient_access (patient_id, user_id, access_role)
values
	(
		'b5000000-0000-0000-0000-000000000005',
		'b2000000-0000-0000-0000-000000000002',
		'MONITOR'
	);

insert into public.devices (id, serial_number, device_kind)
values (
	'b7000000-0000-0000-0000-000000000007',
	'SENDA-TEST-UNASSIGN-001',
	'SIMULATED'
);

insert into public.device_assignments (id, device_id, patient_id, assigned_at)
values (
	'b8000000-0000-0000-0000-000000000008',
	'b7000000-0000-0000-0000-000000000007',
	'b5000000-0000-0000-0000-000000000005',
	clock_timestamp() - interval '2 hours'
);

insert into public.locations (
	device_assignment_id,
	event_id,
	latitude,
	longitude,
	accuracy_m,
	recorded_at,
	source
)
values (
	'b8000000-0000-0000-0000-000000000008',
	'b9000000-0000-0000-0000-000000000009',
	18.4861,
	-69.9312,
	12,
	clock_timestamp() - interval '1 hour',
	'DEVICE'
);

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', 'b2000000-0000-0000-0000-000000000002', true);

select throws_ok(
	$$select * from public.unassign_patient_device(
		'b5000000-0000-0000-0000-000000000005',
		'b8000000-0000-0000-0000-000000000008'
	)$$,
	'42501',
	'ADMIN access to the patient is required.',
	'a MONITOR cannot unassign the device'
);

select set_config('request.jwt.claim.sub', 'b3000000-0000-0000-0000-000000000003', true);
select throws_ok(
	$$select * from public.unassign_patient_device(
		'b5000000-0000-0000-0000-000000000005',
		'b8000000-0000-0000-0000-000000000008'
	)$$,
	'42501',
	'ADMIN access to the patient is required.',
	'an outsider cannot unassign the device'
);

reset request.jwt.claim.sub;
select throws_ok(
	$$select * from public.unassign_patient_device(
		'b5000000-0000-0000-0000-000000000005',
		'b8000000-0000-0000-0000-000000000008'
	)$$,
	'42501',
	'Authentication is required.',
	'an unauthenticated caller is rejected'
);

select set_config('request.jwt.claim.sub', 'b1000000-0000-0000-0000-000000000001', true);

select lives_ok(
	$$select * from public.save_patient_planned_transfer(
		null,
		'b5000000-0000-0000-0000-000000000005',
		clock_timestamp() - interval '1 minute',
		clock_timestamp() + interval '1 hour',
		'Traslado activo'
	)$$,
	'an ADMIN can create the active transfer guard fixture'
);

select throws_ok(
	$$select * from public.unassign_patient_device(
		'b5000000-0000-0000-0000-000000000005',
		'b8000000-0000-0000-0000-000000000008'
	)$$,
	'55000',
	'An active transfer must be finished before the device can be unassigned.',
	'an active transfer prevents unassignment'
);

select lives_ok(
	$$select * from public.end_patient_planned_transfer(
		(select id from public.planned_transfers where patient_id = 'b5000000-0000-0000-0000-000000000005'),
		'b5000000-0000-0000-0000-000000000005'
	)$$,
	'the active transfer can be finished before unassignment'
);

reset role;

insert into public.locations (
	device_assignment_id,
	event_id,
	latitude,
	longitude,
	accuracy_m,
	recorded_at,
	source
)
values (
	'b8000000-0000-0000-0000-000000000008',
	'b9000000-0000-0000-0000-000000000010',
	18.4862,
	-69.9313,
	12,
	clock_timestamp() - interval '30 minutes',
	'DEVICE'
);

insert into public.alert_episodes (
	patient_id,
	device_assignment_id,
	status,
	started_at,
	confirmed_at,
	first_outside_location_id,
	confirmed_by_location_id
)
select
	'b5000000-0000-0000-0000-000000000005',
	'b8000000-0000-0000-0000-000000000008',
	'OPEN',
	min(recorded_at),
	max(recorded_at),
	min(id),
	max(id)
from public.locations
where device_assignment_id = 'b8000000-0000-0000-0000-000000000008';

set local role authenticated;

select throws_ok(
	$$select * from public.unassign_patient_device(
		'b5000000-0000-0000-0000-000000000005',
		'b8000000-0000-0000-0000-000000000008'
	)$$,
	'55000',
	'An open alert must be resolved before the device can be unassigned.',
	'an open alert prevents unassignment'
);

reset role;
delete from public.alert_episodes
where patient_id = 'b5000000-0000-0000-0000-000000000005';
set local role authenticated;

select lives_ok(
	$$select * from public.unassign_patient_device(
		'b5000000-0000-0000-0000-000000000005',
		'b8000000-0000-0000-0000-000000000008'
	)$$,
	'an ADMIN can end an eligible active assignment'
);

select results_eq(
	$$select count(*) from public.device_assignments where id = 'b8000000-0000-0000-0000-000000000008' and unassigned_at is not null$$,
	$$values (1::bigint)$$,
	'the historical assignment is retained and marked inactive'
);
select results_eq(
	$$select unassigned_by from public.device_assignments where id = 'b8000000-0000-0000-0000-000000000008'$$,
	$$values ('b1000000-0000-0000-0000-000000000001'::uuid)$$,
	'the ADMIN actor is recorded'
);
select results_eq(
	$$select count(*) from public.locations where device_assignment_id = 'b8000000-0000-0000-0000-000000000008'$$,
	$$values (2::bigint)$$,
	'historical locations remain attached to the ended assignment'
);

select throws_ok(
	$$select * from public.unassign_patient_device(
		'b5000000-0000-0000-0000-000000000005',
		'b8000000-0000-0000-0000-000000000008'
	)$$,
	'P0002',
	'Active device assignment was not found.',
	'an ended assignment cannot be unassigned twice'
);

select lives_ok(
	$$select * from public.assign_simulated_device(
		'b6000000-0000-0000-0000-000000000006',
		'SENDA-TEST-UNASSIGN-001'
	)$$,
	'the released device can be assigned to another patient'
);
select results_eq(
	$$select count(*) from public.device_assignments where device_id = 'b7000000-0000-0000-0000-000000000007'$$,
	$$values (2::bigint)$$,
	'reassignment creates a new historical assignment'
);
select results_eq(
	$$select count(*) from public.locations where device_assignment_id = 'b8000000-0000-0000-0000-000000000008'$$,
	$$values (2::bigint)$$,
	'reassignment does not move the first patient history'
);

reset role;

select * from finish();
rollback;
