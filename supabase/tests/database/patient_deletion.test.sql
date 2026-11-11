begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(23);

select has_function(
	'public',
	'delete_archived_patient',
	array['uuid'],
	'the permanent patient deletion RPC exists'
);
select ok(
	has_function_privilege('authenticated', 'public.delete_archived_patient(uuid)', 'EXECUTE'),
	'authenticated users can call the authorized deletion wrapper'
);
select ok(
	not has_function_privilege('anon', 'public.delete_archived_patient(uuid)', 'EXECUTE'),
	'anon cannot delete archived patients'
);
select ok(
	not has_function_privilege('service_role', 'public.delete_archived_patient(uuid)', 'EXECUTE'),
	'service_role cannot call the user-scoped deletion wrapper directly'
);
select ok(
	not has_table_privilege('authenticated', 'public.patients', 'DELETE'),
	'authenticated users cannot delete patients directly'
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
		'd1000000-0000-0000-0000-000000000001',
		'authenticated',
		'authenticated',
		'delete-admin@example.test',
		'',
		now(),
		now(),
		now(),
		'{"provider":"email","providers":["email"]}'::jsonb,
		'{}'::jsonb
	),
	(
		'00000000-0000-0000-0000-000000000000',
		'd2000000-0000-0000-0000-000000000002',
		'authenticated',
		'authenticated',
		'delete-monitor@example.test',
		'',
		now(),
		now(),
		now(),
		'{"provider":"email","providers":["email"]}'::jsonb,
		'{}'::jsonb
	),
	(
		'00000000-0000-0000-0000-000000000000',
		'd3000000-0000-0000-0000-000000000003',
		'authenticated',
		'authenticated',
		'delete-outsider@example.test',
		'',
		now(),
		now(),
		now(),
		'{"provider":"email","providers":["email"]}'::jsonb,
		'{}'::jsonb
	);

select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', 'd1000000-0000-0000-0000-000000000001', true);

insert into public.groups (id, name, type, owner_user_id)
values (
	'd4000000-0000-0000-0000-000000000004',
	'Familia eliminación',
	'FAMILY',
	'd1000000-0000-0000-0000-000000000001'
);

insert into public.patients (id, group_id, first_name, last_name)
values
	(
		'd5000000-0000-0000-0000-000000000005',
		'd4000000-0000-0000-0000-000000000004',
		'María',
		'Eliminable'
	),
	(
		'd6000000-0000-0000-0000-000000000006',
		'd4000000-0000-0000-0000-000000000004',
		'Juan',
		'Activo'
	);

insert into public.patient_access (patient_id, user_id, access_role)
values (
	'd5000000-0000-0000-0000-000000000005',
	'd2000000-0000-0000-0000-000000000002',
	'MONITOR'
);

insert into public.invitations (
	id,
	patient_id,
	access_role,
	status,
	token_hash,
	invited_by
)
values (
	'd7000000-0000-0000-0000-000000000007',
	'd5000000-0000-0000-0000-000000000005',
	'MONITOR',
	'PENDING',
	'delete-archived-patient-token-hash',
	'd1000000-0000-0000-0000-000000000001'
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
	'd8000000-0000-0000-0000-000000000008',
	'd5000000-0000-0000-0000-000000000005',
	'Casa',
	18.4861,
	-69.9312,
	1000,
	'd1000000-0000-0000-0000-000000000001',
	'd1000000-0000-0000-0000-000000000001'
);

insert into public.devices (id, serial_number, device_kind)
values (
	'd9000000-0000-0000-0000-000000000009',
	'SENDA-TEST-DELETE-001',
	'SIMULATED'
);

insert into public.device_assignments (
	id,
	device_id,
	patient_id,
	assigned_at,
	unassigned_at
)
values (
	'da000000-0000-0000-0000-000000000010',
	'd9000000-0000-0000-0000-000000000009',
	'd5000000-0000-0000-0000-000000000005',
	clock_timestamp() - interval '6 hours',
	clock_timestamp() - interval '1 hour'
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
values
	(
		'da000000-0000-0000-0000-000000000010',
		'db000000-0000-0000-0000-000000000011',
		18.4861,
		-69.9312,
		10,
		clock_timestamp() - interval '5 hours',
		'DEVICE'
	),
	(
		'da000000-0000-0000-0000-000000000010',
		'db000000-0000-0000-0000-000000000012',
		18.4862,
		-69.9313,
		10,
		clock_timestamp() - interval '4 hours',
		'DEVICE'
	),
	(
		'da000000-0000-0000-0000-000000000010',
		'db000000-0000-0000-0000-000000000013',
		18.4861,
		-69.9312,
		10,
		clock_timestamp() - interval '3 hours',
		'DEVICE'
	);

insert into public.alert_episodes (
	id,
	patient_id,
	device_assignment_id,
	status,
	started_at,
	confirmed_at,
	resolved_at,
	first_outside_location_id,
	confirmed_by_location_id,
	resolved_by_location_id
)
select
	'dc000000-0000-0000-0000-000000000014',
	'd5000000-0000-0000-0000-000000000005',
	'da000000-0000-0000-0000-000000000010',
	'RESOLVED',
	min(recorded_at),
	max(recorded_at) filter (where event_id <> 'db000000-0000-0000-0000-000000000013'),
	max(recorded_at),
	min(id),
	max(id) filter (where event_id <> 'db000000-0000-0000-0000-000000000013'),
	max(id)
from public.locations
where device_assignment_id = 'da000000-0000-0000-0000-000000000010';

insert into public.planned_transfers (
	id,
	patient_id,
	starts_at,
	ends_at,
	note,
	created_by,
	updated_by,
	ended_at,
	ended_by
)
values (
	'dd000000-0000-0000-0000-000000000015',
	'd5000000-0000-0000-0000-000000000005',
	clock_timestamp() - interval '4 hours',
	clock_timestamp() - interval '2 hours',
	'Traslado histórico',
	'd1000000-0000-0000-0000-000000000001',
	'd1000000-0000-0000-0000-000000000001',
	clock_timestamp() - interval '3 hours',
	'd1000000-0000-0000-0000-000000000001'
);

set local role authenticated;

select lives_ok(
	$$select * from public.archive_patient('d5000000-0000-0000-0000-000000000005')$$,
	'the complete historical fixture can be archived before deletion'
);

select set_config('request.jwt.claim.sub', 'd2000000-0000-0000-0000-000000000002', true);
select throws_ok(
	$$select * from public.delete_archived_patient('d5000000-0000-0000-0000-000000000005')$$,
	'42501',
	'ADMIN access to the patient is required.',
	'a MONITOR cannot permanently delete an archived patient'
);

select set_config('request.jwt.claim.sub', 'd3000000-0000-0000-0000-000000000003', true);
select throws_ok(
	$$select * from public.delete_archived_patient('d5000000-0000-0000-0000-000000000005')$$,
	'42501',
	'ADMIN access to the patient is required.',
	'an outsider cannot permanently delete an archived patient'
);

reset request.jwt.claim.sub;
select throws_ok(
	$$select * from public.delete_archived_patient('d5000000-0000-0000-0000-000000000005')$$,
	'42501',
	'Authentication is required.',
	'an unauthenticated caller cannot permanently delete an archived patient'
);

select set_config('request.jwt.claim.sub', 'd1000000-0000-0000-0000-000000000001', true);
select throws_ok(
	$$select * from public.delete_archived_patient('d6000000-0000-0000-0000-000000000006')$$,
	'55000',
	'Patient must be archived before permanent deletion.',
	'an active patient cannot be permanently deleted'
);

select lives_ok(
	$$select * from public.delete_archived_patient('d5000000-0000-0000-0000-000000000005')$$,
	'an ADMIN can permanently delete an archived patient'
);

reset role;

select is(
	(select count(*) from public.patients where id = 'd5000000-0000-0000-0000-000000000005'),
	0::bigint,
	'the archived patient row is deleted'
);
select is(
	(select count(*) from public.alert_episodes where patient_id = 'd5000000-0000-0000-0000-000000000005'),
	0::bigint,
	'the patient alert episodes are deleted'
);
select is(
	(select count(*) from public.locations where device_assignment_id = 'da000000-0000-0000-0000-000000000010'),
	0::bigint,
	'the patient location history is deleted'
);
select is(
	(select count(*) from public.device_assignments where patient_id = 'd5000000-0000-0000-0000-000000000005'),
	0::bigint,
	'the patient device assignment history is deleted'
);
select is(
	(select count(*) from public.planned_transfers where patient_id = 'd5000000-0000-0000-0000-000000000005'),
	0::bigint,
	'the patient transfer history is deleted'
);
select is(
	(select count(*) from public.safe_zones where patient_id = 'd5000000-0000-0000-0000-000000000005'),
	0::bigint,
	'the patient safe zones are deleted'
);
select is(
	(select count(*) from public.patient_access where patient_id = 'd5000000-0000-0000-0000-000000000005'),
	0::bigint,
	'the patient access rows are deleted'
);
select is(
	(select count(*) from public.invitations where patient_id = 'd5000000-0000-0000-0000-000000000005'),
	0::bigint,
	'the patient invitations are deleted'
);
select is(
	(select count(*) from public.devices where id = 'd9000000-0000-0000-0000-000000000009'),
	1::bigint,
	'the reusable device inventory row is preserved'
);
select is(
	(select count(*) from public.groups where id = 'd4000000-0000-0000-0000-000000000004'),
	1::bigint,
	'the administrative group is preserved'
);
select is(
	(select count(*) from auth.users where id in (
		'd1000000-0000-0000-0000-000000000001',
		'd2000000-0000-0000-0000-000000000002',
		'd3000000-0000-0000-0000-000000000003'
	)),
	3::bigint,
	'Auth users are preserved'
);
select is(
	(select count(*) from public.patients where id = 'd6000000-0000-0000-0000-000000000006'),
	1::bigint,
	'other patients in the group are preserved'
);

select * from finish();
rollback;
