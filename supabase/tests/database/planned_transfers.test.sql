begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(65);

select has_table('public', 'planned_transfers', 'planned transfers are persisted');
select ok(
	(select relrowsecurity from pg_class where oid = 'public.planned_transfers'::regclass),
	'planned transfers have RLS enabled'
);
select has_column('public', 'planned_transfers', 'patient_id', 'transfers belong to one patient');
select has_column('public', 'planned_transfers', 'starts_at', 'transfers preserve their planned start');
select has_column('public', 'planned_transfers', 'ends_at', 'transfers preserve their planned end');
select has_column('public', 'planned_transfers', 'note', 'transfers explain their purpose');
select has_column('public', 'planned_transfers', 'ended_at', 'early finishes are audited');
select has_column('public', 'planned_transfers', 'cancelled_at', 'scheduled cancellations are audited');
select ok(
	has_table_privilege('authenticated', 'public.planned_transfers', 'SELECT'),
	'authenticated users can select transfers subject to RLS'
);
select ok(
	not has_table_privilege('authenticated', 'public.planned_transfers', 'INSERT'),
	'authenticated users cannot insert transfers directly'
);
select ok(
	not has_table_privilege('authenticated', 'public.planned_transfers', 'UPDATE'),
	'authenticated users cannot update transfers directly'
);
select ok(
	not has_table_privilege('anon', 'public.planned_transfers', 'SELECT'),
	'anonymous users cannot read transfers'
);
select has_function(
	'public',
	'save_patient_planned_transfer',
	array['uuid', 'uuid', 'timestamp with time zone', 'timestamp with time zone', 'text'],
	'the create and edit RPC exists'
);
select has_function(
	'public',
	'cancel_patient_planned_transfer',
	array['uuid', 'uuid'],
	'the scheduled cancellation RPC exists'
);
select has_function(
	'public',
	'end_patient_planned_transfer',
	array['uuid', 'uuid'],
	'the early finish RPC exists'
);
select has_function(
	'private',
	'require_patient_transfer_manager',
	array['uuid'],
	'the patient-scoped transfer authorization helper exists'
);
select ok(
	not has_function_privilege(
		'authenticated',
		'private.require_patient_transfer_manager(uuid)',
		'EXECUTE'
	),
	'the transfer authorization helper remains internal'
);
select ok(
	has_function_privilege(
		'authenticated',
		'public.save_patient_planned_transfer(uuid,uuid,timestamptz,timestamptz,text)',
		'EXECUTE'
	),
	'authenticated users can call the authorized save RPC'
);
select ok(
	not has_function_privilege(
		'anon',
		'public.save_patient_planned_transfer(uuid,uuid,timestamptz,timestamptz,text)',
		'EXECUTE'
	),
	'anonymous users cannot call the save RPC'
);
select ok(
	not has_function_privilege(
		'authenticated',
		'private.process_location_alert_episode()',
		'EXECUTE'
	),
	'the episode processor remains internal'
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
		'transfer-admin@example.test',
		'',
		now(),
		now(),
		now(),
		'{"provider":"email","providers":["email"]}'::jsonb,
		'{}'::jsonb
	),
	(
		'00000000-0000-0000-0000-000000000000',
		'a2000000-0000-0000-0000-000000000002',
		'authenticated',
		'authenticated',
		'transfer-monitor@example.test',
		'',
		now(),
		now(),
		now(),
		'{"provider":"email","providers":["email"]}'::jsonb,
		'{}'::jsonb
	),
	(
		'00000000-0000-0000-0000-000000000000',
		'a3000000-0000-0000-0000-000000000003',
		'authenticated',
		'authenticated',
		'transfer-outsider@example.test',
		'',
		now(),
		now(),
		now(),
		'{"provider":"email","providers":["email"]}'::jsonb,
		'{}'::jsonb
	);

insert into public.devices (serial_number, device_kind)
values ('SENDA-TEST-TRANSFER-001', 'SIMULATED');

set local role authenticated;
select set_config('request.jwt.claim.sub', 'a1000000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('test.transfer_base_time', (clock_timestamp() - interval '4 minutes')::text, true);

select lives_ok(
	$$select * from public.create_patient_onboarding(
		'Familia traslados',
		'FAMILY',
		'María',
		'Pérez'
	)$$,
	'ADMIN creates the patient used by transfer tests'
);
select set_config('test.transfer_patient_id', (select id::text from public.patients limit 1), true);

select lives_ok(
	$$select * from public.assign_simulated_device(
		current_setting('test.transfer_patient_id')::uuid,
		'SENDA-TEST-TRANSFER-001'
	)$$,
	'ADMIN assigns the simulated device used by transfer tests'
);
select set_config(
	'test.transfer_assignment_id',
	(select id::text from public.device_assignments limit 1),
	true
);

reset role;
update public.device_assignments
set assigned_at = clock_timestamp() - interval '1 hour'
where id = current_setting('test.transfer_assignment_id')::uuid;

insert into public.patient_access (patient_id, user_id, access_role)
values (
	current_setting('test.transfer_patient_id')::uuid,
	'a2000000-0000-0000-0000-000000000002',
	'MONITOR'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'a1000000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select lives_ok(
	$$select * from public.save_patient_safe_zone(
		null,
		current_setting('test.transfer_patient_id')::uuid,
		'Casa',
		18,
		-70,
		250,
		true
	)$$,
	'ADMIN creates the active safe zone used by transfer tests'
);

select lives_ok(
	$$select * from public.save_patient_planned_transfer(
		null,
		current_setting('test.transfer_patient_id')::uuid,
		current_setting('test.transfer_base_time')::timestamptz + interval '1 minute',
		clock_timestamp() + interval '1 hour',
		'  Viaje a la casa de playa  '
	)$$,
	'ADMIN creates an active transfer lasting less than 24 hours'
);
select set_config(
	'test.transfer_active_id',
	(select id::text from public.planned_transfers order by created_at limit 1),
	true
);
select results_eq(
	$$select note from public.planned_transfers
	where id = current_setting('test.transfer_active_id')::uuid$$,
	$$values ('Viaje a la casa de playa'::text)$$,
	'the transfer note is normalized before it is stored'
);
select ok(
	(
		select ends_at - starts_at <= interval '24 hours'
		from public.planned_transfers
		where id = current_setting('test.transfer_active_id')::uuid
	),
	'the persisted transfer respects the 24-hour limit'
);

select set_config('request.jwt.claim.sub', 'a2000000-0000-0000-0000-000000000002', true);
select results_eq(
	$$select count(*) from public.planned_transfers$$,
	$$values (1::bigint)$$,
	'an authorized MONITOR can read the patient transfer'
);
select lives_ok(
	$$select * from public.save_patient_planned_transfer(
		current_setting('test.transfer_active_id')::uuid,
		current_setting('test.transfer_patient_id')::uuid,
		(select starts_at from public.planned_transfers
			where id = current_setting('test.transfer_active_id')::uuid),
		(select ends_at + interval '10 minutes' from public.planned_transfers
			where id = current_setting('test.transfer_active_id')::uuid),
		'Traslado actualizado por monitor'
	)$$,
	'a MONITOR can edit an active patient transfer'
);

select set_config('request.jwt.claim.sub', 'a3000000-0000-0000-0000-000000000003', true);
select results_eq(
	$$select count(*) from public.planned_transfers$$,
	$$values (0::bigint)$$,
	'an outsider cannot read patient transfers'
);

select set_config('request.jwt.claim.sub', 'a1000000-0000-0000-0000-000000000001', true);
select throws_ok(
	$$insert into public.planned_transfers (
		patient_id,
		starts_at,
		ends_at,
		note,
		created_by,
		updated_by
	) values (
		current_setting('test.transfer_patient_id')::uuid,
		clock_timestamp(),
		clock_timestamp() + interval '1 hour',
		'Inserción directa',
		'a1000000-0000-0000-0000-000000000001',
		'a1000000-0000-0000-0000-000000000001'
	)$$,
	'42501',
	'permission denied for table planned_transfers',
	'direct transfer inserts remain blocked'
);
select throws_ok(
	$$select * from public.save_patient_planned_transfer(
		null,
		current_setting('test.transfer_patient_id')::uuid,
		clock_timestamp() + interval '2 hours',
		clock_timestamp() + interval '26 hours 1 minute',
		'Traslado demasiado largo'
	)$$,
	'22023',
	'Transfer duration cannot exceed 24 hours.',
	'a transfer longer than 24 hours is rejected'
);
select throws_ok(
	$$select * from public.save_patient_planned_transfer(
		null,
		current_setting('test.transfer_patient_id')::uuid,
		clock_timestamp() + interval '2 hours',
		clock_timestamp() + interval '3 hours',
		'   '
	)$$,
	'22023',
	'Transfer note must contain between 1 and 500 characters.',
	'a blank transfer note is rejected'
);
select throws_ok(
	$$select * from public.save_patient_planned_transfer(
		null,
		current_setting('test.transfer_patient_id')::uuid,
		clock_timestamp(),
		clock_timestamp() + interval '30 minutes',
		'Traslado superpuesto'
	)$$,
	'23P01',
	'Transfer windows cannot overlap for the same patient.',
	'overlapping transfer windows are rejected'
);

select lives_ok(
	$$select * from public.ingest_simulated_location(
		current_setting('test.transfer_patient_id')::uuid,
		'b1000000-0000-0000-0000-000000000001'::uuid,
		18,
		-70,
		null,
		current_setting('test.transfer_base_time')::timestamptz,
		'SIMULATOR'
	)$$,
	'an INSIDE reading before the transfer establishes a baseline'
);
select lives_ok(
	$$select * from public.ingest_simulated_location(
		current_setting('test.transfer_patient_id')::uuid,
		'b1000000-0000-0000-0000-000000000002'::uuid,
		18.003,
		-70,
		null,
		current_setting('test.transfer_base_time')::timestamptz + interval '2 minutes',
		'SIMULATOR'
	)$$,
	'the first OUTSIDE reading during the transfer is ingested normally'
);
select lives_ok(
	$$select * from public.ingest_simulated_location(
		current_setting('test.transfer_patient_id')::uuid,
		'b1000000-0000-0000-0000-000000000003'::uuid,
		18.0031,
		-70,
		null,
		current_setting('test.transfer_base_time')::timestamptz + interval '3 minutes',
		'SIMULATOR'
	)$$,
	'the second OUTSIDE reading during the transfer is ingested normally'
);
select results_eq(
	$$select count(*) from public.alert_episodes$$,
	$$values (0::bigint)$$,
	'an active transfer suppresses creation of a new exit episode'
);

select lives_ok(
	$$select * from public.end_patient_planned_transfer(
		current_setting('test.transfer_active_id')::uuid,
		current_setting('test.transfer_patient_id')::uuid
	)$$,
	'ADMIN finishes an active transfer early'
);
select lives_ok(
	$$select * from public.ingest_simulated_location(
		current_setting('test.transfer_patient_id')::uuid,
		'b1000000-0000-0000-0000-000000000004'::uuid,
		18.0032,
		-70,
		null,
		clock_timestamp() + interval '10 seconds',
		'SIMULATOR'
	)$$,
	'the first OUTSIDE reading after the transfer is ingested'
);
select results_eq(
	$$select count(*) from public.alert_episodes$$,
	$$values (0::bigint)$$,
	'the last transfer reading is not paired retroactively with the first later reading'
);
select lives_ok(
	$$select * from public.ingest_simulated_location(
		current_setting('test.transfer_patient_id')::uuid,
		'b1000000-0000-0000-0000-000000000005'::uuid,
		18.0033,
		-70,
		null,
		clock_timestamp() + interval '20 seconds',
		'SIMULATOR'
	)$$,
	'the second OUTSIDE reading after the transfer is ingested'
);
select results_eq(
	$$select count(*) from public.alert_episodes where status = 'OPEN'$$,
	$$values (1::bigint)$$,
	'two new OUTSIDE readings after the transfer open an episode'
);

select lives_ok(
	$$select * from public.save_patient_planned_transfer(
		null,
		current_setting('test.transfer_patient_id')::uuid,
		clock_timestamp(),
		clock_timestamp() + interval '1 hour',
		'Regreso familiar'
	)$$,
	'ADMIN starts another transfer while the prior episode remains open'
);
select set_config(
	'test.transfer_second_active_id',
	(select id::text from public.planned_transfers where ended_at is null order by created_at desc limit 1),
	true
);
select throws_ok(
	$$select * from public.cancel_patient_planned_transfer(
		current_setting('test.transfer_second_active_id')::uuid,
		current_setting('test.transfer_patient_id')::uuid
	)$$,
	'22023',
	'Only a scheduled transfer can be cancelled.',
	'an active transfer cannot be cancelled as though it never started'
);
select lives_ok(
	$$select * from public.save_patient_planned_transfer(
		current_setting('test.transfer_second_active_id')::uuid,
		current_setting('test.transfer_patient_id')::uuid,
		(select starts_at from public.planned_transfers
			where id = current_setting('test.transfer_second_active_id')::uuid),
		(select ends_at + interval '30 minutes' from public.planned_transfers
			where id = current_setting('test.transfer_second_active_id')::uuid),
		'Regreso familiar con tráfico'
	)$$,
	'an active transfer can be extended within the 24-hour limit'
);
select results_eq(
	$$select note from public.planned_transfers
	where id = current_setting('test.transfer_second_active_id')::uuid$$,
	$$values ('Regreso familiar con tráfico'::text)$$,
	'an extension also preserves the updated explanatory note'
);
select throws_ok(
	$$select * from public.save_patient_planned_transfer(
		current_setting('test.transfer_second_active_id')::uuid,
		current_setting('test.transfer_patient_id')::uuid,
		(select starts_at from public.planned_transfers
			where id = current_setting('test.transfer_second_active_id')::uuid),
		(select ends_at - interval '10 minutes' from public.planned_transfers
			where id = current_setting('test.transfer_second_active_id')::uuid),
		'Regreso familiar'
	)$$,
	'22023',
	'Use the finish action to end an active transfer early.',
	'an active transfer cannot be shortened through the edit RPC'
);

select lives_ok(
	$$select * from public.ingest_simulated_location(
		current_setting('test.transfer_patient_id')::uuid,
		'b1000000-0000-0000-0000-000000000006'::uuid,
		18,
		-70,
		null,
		clock_timestamp() + interval '30 seconds',
		'SIMULATOR'
	)$$,
	'the first INSIDE reading during a transfer is ingested for an existing episode'
);
select results_eq(
	$$select count(*) from public.alert_episodes where status = 'OPEN'$$,
	$$values (1::bigint)$$,
	'one INSIDE reading still leaves the prior episode open'
);
select lives_ok(
	$$select * from public.ingest_simulated_location(
		current_setting('test.transfer_patient_id')::uuid,
		'b1000000-0000-0000-0000-000000000007'::uuid,
		18,
		-70,
		null,
		clock_timestamp() + interval '40 seconds',
		'SIMULATOR'
	)$$,
	'the second INSIDE reading during a transfer is ingested'
);
select results_eq(
	$$select count(*) from public.alert_episodes where status = 'RESOLVED'$$,
	$$values (1::bigint)$$,
	'an existing episode resolves normally during an active transfer'
);
select lives_ok(
	$$select * from public.end_patient_planned_transfer(
		current_setting('test.transfer_second_active_id')::uuid,
		current_setting('test.transfer_patient_id')::uuid
	)$$,
	'ADMIN finishes the second active transfer'
);

select lives_ok(
	$$select * from public.save_patient_planned_transfer(
		null,
		current_setting('test.transfer_patient_id')::uuid,
		clock_timestamp() + interval '2 hours',
		clock_timestamp() + interval '3 hours',
		'Visita programada'
	)$$,
	'ADMIN creates a future scheduled transfer'
);
select set_config(
	'test.transfer_scheduled_id',
	(select id::text from public.planned_transfers where starts_at > clock_timestamp() order by created_at desc limit 1),
	true
);
select lives_ok(
	$$select * from public.cancel_patient_planned_transfer(
		current_setting('test.transfer_scheduled_id')::uuid,
		current_setting('test.transfer_patient_id')::uuid
	)$$,
	'ADMIN cancels a transfer before it starts'
);
select results_eq(
	$$select cancelled_by from public.planned_transfers
	where id = current_setting('test.transfer_scheduled_id')::uuid$$,
	$$values ('a1000000-0000-0000-0000-000000000001'::uuid)$$,
	'the cancellation keeps its responsible ADMIN'
);
select lives_ok(
	$$select * from public.save_patient_planned_transfer(
		null,
		current_setting('test.transfer_patient_id')::uuid,
		clock_timestamp() + interval '2 hours',
		clock_timestamp() + interval '3 hours',
		'Visita reprogramada'
	)$$,
	'a cancelled window no longer blocks a replacement transfer'
);
select set_config(
	'test.transfer_replacement_scheduled_id',
	(select id::text from public.planned_transfers
		where cancelled_at is null and starts_at > clock_timestamp()
		order by created_at desc limit 1),
	true
);

select set_config('request.jwt.claim.sub', 'a2000000-0000-0000-0000-000000000002', true);
select results_eq(
	$$select count(*) from public.planned_transfers$$,
	$$values (4::bigint)$$,
	'MONITOR can read active, completed, cancelled and scheduled transfer history'
);
select lives_ok(
	$$select * from public.cancel_patient_planned_transfer(
		current_setting('test.transfer_replacement_scheduled_id')::uuid,
		current_setting('test.transfer_patient_id')::uuid
	)$$,
	'MONITOR can cancel a scheduled transfer'
);
select lives_ok(
	$$select * from public.save_patient_planned_transfer(
		null,
		current_setting('test.transfer_patient_id')::uuid,
		clock_timestamp(),
		clock_timestamp() + interval '30 minutes',
		'Traslado gestionado por monitor'
	)$$,
	'MONITOR can create an active transfer'
);
select set_config(
	'test.transfer_monitor_active_id',
	(select id::text from public.planned_transfers
		where created_by = 'a2000000-0000-0000-0000-000000000002'
		order by created_at desc limit 1),
	true
);
select lives_ok(
	$$select * from public.save_patient_planned_transfer(
		current_setting('test.transfer_monitor_active_id')::uuid,
		current_setting('test.transfer_patient_id')::uuid,
		(select starts_at from public.planned_transfers
			where id = current_setting('test.transfer_monitor_active_id')::uuid),
		(select ends_at + interval '10 minutes' from public.planned_transfers
			where id = current_setting('test.transfer_monitor_active_id')::uuid),
		'Traslado extendido por monitor'
	)$$,
	'MONITOR can extend an active transfer'
);
select lives_ok(
	$$select * from public.end_patient_planned_transfer(
		current_setting('test.transfer_monitor_active_id')::uuid,
		current_setting('test.transfer_patient_id')::uuid
	)$$,
	'MONITOR can finish an active transfer early'
);
select results_eq(
	$$select
		(select cancelled_by from public.planned_transfers
			where id = current_setting('test.transfer_replacement_scheduled_id')::uuid),
		created_by,
		updated_by,
		ended_by
	from public.planned_transfers
	where id = current_setting('test.transfer_monitor_active_id')::uuid$$,
	$$values (
		'a2000000-0000-0000-0000-000000000002'::uuid,
		'a2000000-0000-0000-0000-000000000002'::uuid,
		'a2000000-0000-0000-0000-000000000002'::uuid,
		'a2000000-0000-0000-0000-000000000002'::uuid
	)$$,
	'MONITOR transfer operations keep the responsible user in the audit fields'
);

select set_config('request.jwt.claim.sub', 'a1000000-0000-0000-0000-000000000001', true);
select throws_ok(
	$$update public.planned_transfers set note = 'Actualización directa'$$,
	'42501',
	'permission denied for table planned_transfers',
	'direct updates remain blocked'
);
select throws_ok(
	$$delete from public.planned_transfers$$,
	'42501',
	'permission denied for table planned_transfers',
	'direct deletes remain blocked'
);

select set_config('request.jwt.claim.sub', 'a3000000-0000-0000-0000-000000000003', true);
select throws_ok(
	$$select * from public.end_patient_planned_transfer(
		(select id from public.planned_transfers where cancelled_at is null order by created_at desc limit 1),
		current_setting('test.transfer_patient_id')::uuid
	)$$,
	'42501',
	'Active ADMIN or MONITOR access to the patient is required.',
	'an outsider cannot finish a patient transfer'
);

select * from finish();
rollback;
