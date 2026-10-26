begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(36);

select has_column(
	'public',
	'locations',
	'geofence_relation',
	'locations store the per-reading geofence relation'
);
select has_column(
	'public',
	'locations',
	'matched_safe_zone_id',
	'locations preserve the safe zone that determined the relation'
);
select has_column(
	'public',
	'locations',
	'distance_to_boundary_m',
	'locations preserve the signed boundary distance'
);
select has_column(
	'public',
	'locations',
	'effective_tolerance_m',
	'locations preserve the effective GPS tolerance'
);
select has_column(
	'public',
	'locations',
	'geofence_evaluated_at',
	'locations preserve when the backend evaluated the reading'
);
select has_trigger(
	'public',
	'locations',
	'locations_evaluate_geofence_before_insert',
	'new locations are evaluated by a database trigger'
);
select ok(
	not has_function_privilege(
		'authenticated',
		'private.great_circle_distance_m(double precision,double precision,double precision,double precision)',
		'EXECUTE'
	),
	'authenticated users cannot call the internal distance helper'
);
select ok(
	not has_function_privilege(
		'authenticated',
		'private.evaluate_location_geofence()',
		'EXECUTE'
	),
	'authenticated users cannot call the internal trigger function'
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
		'81000000-0000-0000-0000-000000000081',
		'authenticated',
		'authenticated',
		'geofence-admin@example.test',
		'',
		now(),
		now(),
		now(),
		'{"provider":"email","providers":["email"]}'::jsonb,
		'{}'::jsonb
	),
	(
		'00000000-0000-0000-0000-000000000000',
		'82000000-0000-0000-0000-000000000082',
		'authenticated',
		'authenticated',
		'geofence-monitor@example.test',
		'',
		now(),
		now(),
		now(),
		'{"provider":"email","providers":["email"]}'::jsonb,
		'{}'::jsonb
	),
	(
		'00000000-0000-0000-0000-000000000000',
		'83000000-0000-0000-0000-000000000083',
		'authenticated',
		'authenticated',
		'geofence-outsider@example.test',
		'',
		now(),
		now(),
		now(),
		'{"provider":"email","providers":["email"]}'::jsonb,
		'{}'::jsonb
	);

insert into public.devices (serial_number, device_kind)
values ('SENDA-TEST-GEOFENCE-001', 'SIMULATED');

set local role authenticated;
select set_config('request.jwt.claim.sub', '81000000-0000-0000-0000-000000000081', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select lives_ok(
	$$select * from public.create_patient_onboarding('Familia geocerca', 'FAMILY', 'Elena', 'Prueba')$$,
	'ADMIN creates the patient used by geofence evaluation tests'
);
select set_config('test.geofence_patient_id', (select id::text from public.patients limit 1), true);

select lives_ok(
	$$select * from public.assign_simulated_device(
		current_setting('test.geofence_patient_id')::uuid,
		'SENDA-TEST-GEOFENCE-001'
	)$$,
	'ADMIN assigns a simulated device'
);

select lives_ok(
	$$select * from public.save_patient_safe_zone(
		null,
		current_setting('test.geofence_patient_id')::uuid,
		'Casa',
		18,
		-70,
		250,
		true
	)$$,
	'ADMIN creates the first active safe zone'
);
select set_config(
	'test.geofence_home_zone_id',
	(select id::text from public.safe_zones where name = 'Casa'),
	true
);

select lives_ok(
	$$select * from public.ingest_simulated_location(
		current_setting('test.geofence_patient_id')::uuid,
		'84000000-0000-0000-0000-000000000001'::uuid,
		18,
		-70,
		null,
		now(),
		'SIMULATOR'
	)$$,
	'a reading at the safe-zone center is ingested'
);
select results_eq(
	$$select geofence_relation from public.locations where event_id = '84000000-0000-0000-0000-000000000001'::uuid$$,
	$$values ('INSIDE'::text)$$,
	'a reading whose uncertainty fits inside a zone is INSIDE'
);
select results_eq(
	$$select effective_tolerance_m from public.locations where event_id = '84000000-0000-0000-0000-000000000001'::uuid$$,
	$$values (25::double precision)$$,
	'a reading without reported accuracy uses the 25 meter minimum'
);
select results_eq(
	$$select matched_safe_zone_id from public.locations where event_id = '84000000-0000-0000-0000-000000000001'::uuid$$,
	$$values (current_setting('test.geofence_home_zone_id')::uuid)$$,
	'the inside reading identifies its matching zone'
);
select results_eq(
	$$select distance_to_boundary_m < 0 from public.locations where event_id = '84000000-0000-0000-0000-000000000001'::uuid$$,
	$$values (true)$$,
	'distance to boundary is negative while inside'
);
select results_eq(
	$$select geofence_evaluated_at is not null from public.locations where event_id = '84000000-0000-0000-0000-000000000001'::uuid$$,
	$$values (true)$$,
	'the backend records the evaluation time'
);

select lives_ok(
	$$select * from public.ingest_simulated_location(
		current_setting('test.geofence_patient_id')::uuid,
		'84000000-0000-0000-0000-000000000002'::uuid,
		18.002248,
		-70,
		null,
		now(),
		'SIMULATOR'
	)$$,
	'a reading near the circular boundary is ingested'
);
select results_eq(
	$$select geofence_relation from public.locations where event_id = '84000000-0000-0000-0000-000000000002'::uuid$$,
	$$values ('UNCERTAIN'::text)$$,
	'a reading within 25 meters of the boundary is UNCERTAIN'
);

select lives_ok(
	$$select * from public.ingest_simulated_location(
		current_setting('test.geofence_patient_id')::uuid,
		'84000000-0000-0000-0000-000000000003'::uuid,
		18.003,
		-70,
		null,
		now(),
		'SIMULATOR'
	)$$,
	'a reading clearly beyond the safe zone is ingested'
);
select results_eq(
	$$select geofence_relation from public.locations where event_id = '84000000-0000-0000-0000-000000000003'::uuid$$,
	$$values ('OUTSIDE'::text)$$,
	'a reading beyond the zone and tolerance is OUTSIDE'
);
select results_eq(
	$$select distance_to_boundary_m > 25 from public.locations where event_id = '84000000-0000-0000-0000-000000000003'::uuid$$,
	$$values (true)$$,
	'distance to boundary is positive beyond the uncertainty band'
);

select lives_ok(
	$$select * from public.ingest_simulated_location(
		current_setting('test.geofence_patient_id')::uuid,
		'84000000-0000-0000-0000-000000000004'::uuid,
		18.003,
		-70,
		100,
		now(),
		'SIMULATOR'
	)$$,
	'a reading with lower reported GPS precision is ingested'
);
select results_eq(
	$$select effective_tolerance_m from public.locations where event_id = '84000000-0000-0000-0000-000000000004'::uuid$$,
	$$values (100::double precision)$$,
	'reported accuracy above 25 meters becomes the effective tolerance'
);
select results_eq(
	$$select geofence_relation from public.locations where event_id = '84000000-0000-0000-0000-000000000004'::uuid$$,
	$$values ('UNCERTAIN'::text)$$,
	'a larger accuracy radius can make a boundary relation UNCERTAIN'
);

select lives_ok(
	$$select * from public.save_patient_safe_zone(
		null,
		current_setting('test.geofence_patient_id')::uuid,
		'Centro de día',
		18.01,
		-70,
		250,
		true
	)$$,
	'ADMIN creates a second active safe zone'
);
select set_config(
	'test.geofence_center_zone_id',
	(select id::text from public.safe_zones where name = 'Centro de día'),
	true
);
select lives_ok(
	$$select * from public.ingest_simulated_location(
		current_setting('test.geofence_patient_id')::uuid,
		'84000000-0000-0000-0000-000000000005'::uuid,
		18.01,
		-70,
		null,
		now(),
		'SIMULATOR'
	)$$,
	'a reading inside only the second zone is ingested'
);
select results_eq(
	$$select geofence_relation from public.locations where event_id = '84000000-0000-0000-0000-000000000005'::uuid$$,
	$$values ('INSIDE'::text)$$,
	'being inside any active safe zone produces INSIDE'
);
select results_eq(
	$$select matched_safe_zone_id from public.locations where event_id = '84000000-0000-0000-0000-000000000005'::uuid$$,
	$$values (current_setting('test.geofence_center_zone_id')::uuid)$$,
	'the classifier selects the zone that contains the reading'
);

select lives_ok(
	$$select * from public.save_patient_safe_zone(
		current_setting('test.geofence_home_zone_id')::uuid,
		current_setting('test.geofence_patient_id')::uuid,
		'Casa',
		18,
		-70,
		250,
		false
	)$$,
	'the first safe zone can be deactivated'
);
select lives_ok(
	$$select * from public.save_patient_safe_zone(
		current_setting('test.geofence_center_zone_id')::uuid,
		current_setting('test.geofence_patient_id')::uuid,
		'Centro de día',
		18.01,
		-70,
		250,
		false
	)$$,
	'the second safe zone can be deactivated'
);
select lives_ok(
	$$select * from public.ingest_simulated_location(
		current_setting('test.geofence_patient_id')::uuid,
		'84000000-0000-0000-0000-000000000006'::uuid,
		18,
		-70,
		null,
		now(),
		'SIMULATOR'
	)$$,
	'a reading without active safe zones is ingested'
);
select results_eq(
	$$select geofence_relation from public.locations where event_id = '84000000-0000-0000-0000-000000000006'::uuid$$,
	$$values ('NO_ACTIVE_ZONE'::text)$$,
	'only inactive zones produce NO_ACTIVE_ZONE'
);
select results_eq(
	$$select matched_safe_zone_id is null and distance_to_boundary_m is null from public.locations where event_id = '84000000-0000-0000-0000-000000000006'::uuid$$,
	$$values (true)$$,
	'NO_ACTIVE_ZONE does not claim a matching zone or boundary distance'
);

reset role;
insert into public.patient_access (patient_id, user_id, access_role, relationship)
values (
	current_setting('test.geofence_patient_id')::uuid,
	'82000000-0000-0000-0000-000000000082',
	'MONITOR',
	'FAMILY'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '82000000-0000-0000-0000-000000000082', true);
select results_eq(
	$$select count(*) from public.locations where geofence_relation <> 'NOT_EVALUATED'$$,
	$$values (6::bigint)$$,
	'an authorized MONITOR can read stored geofence evaluations'
);

select set_config('request.jwt.claim.sub', '83000000-0000-0000-0000-000000000083', true);
select results_eq(
	$$select count(*) from public.locations$$,
	$$values (0::bigint)$$,
	'an outsider cannot read patient location evaluations'
);

select * from finish();
rollback;
