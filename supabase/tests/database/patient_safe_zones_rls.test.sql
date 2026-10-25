begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(29);

select has_table('public', 'safe_zones', 'safe_zones table exists');
select ok(
	(select relrowsecurity from pg_class where oid = 'public.safe_zones'::regclass),
	'safe_zones has RLS enabled'
);
select ok(
	has_table_privilege('authenticated', 'public.safe_zones', 'SELECT'),
	'authenticated can select rows subject to RLS'
);
select ok(
	not has_table_privilege('authenticated', 'public.safe_zones', 'INSERT'),
	'authenticated cannot insert safe zones directly'
);

insert into auth.users (
	instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
	created_at, updated_at, raw_app_meta_data, raw_user_meta_data
)
values
(
	'00000000-0000-0000-0000-000000000000',
	'71000000-0000-0000-0000-000000000071',
	'authenticated', 'authenticated', 'zone-admin@example.test', '', now(), now(), now(),
	'{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb
),
(
	'00000000-0000-0000-0000-000000000000',
	'72000000-0000-0000-0000-000000000072',
	'authenticated', 'authenticated', 'zone-monitor@example.test', '', now(), now(), now(),
	'{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb
),
(
	'00000000-0000-0000-0000-000000000000',
	'73000000-0000-0000-0000-000000000073',
	'authenticated', 'authenticated', 'zone-outsider@example.test', '', now(), now(), now(),
	'{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '71000000-0000-0000-0000-000000000071', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select lives_ok(
	$$select * from public.create_patient_onboarding('Familia zonas', 'FAMILY', 'María', 'Prueba')$$,
	'ADMIN creates the patient used by safe-zone tests'
);
select set_config('test.zone_patient_id', (select id::text from public.patients limit 1), true);

select lives_ok(
	$$select * from public.save_patient_safe_zone(
		null,
		current_setting('test.zone_patient_id')::uuid,
		'Casa',
		18.4861,
		-69.9312,
		250,
		true
	)$$,
	'ADMIN creates a safe zone'
);
select set_config('test.zone_id', (select id::text from public.safe_zones where name = 'Casa'), true);
select results_eq(
	$$select count(*) from public.safe_zones$$,
	$$values (1::bigint)$$,
	'ADMIN reads the patient safe zone'
);

reset role;
insert into public.patient_access (patient_id, user_id, access_role, relationship)
values (
	current_setting('test.zone_patient_id')::uuid,
	'72000000-0000-0000-0000-000000000072',
	'MONITOR',
	'FAMILY'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '72000000-0000-0000-0000-000000000072', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select lives_ok(
	$$select * from public.save_patient_safe_zone(
		null,
		current_setting('test.zone_patient_id')::uuid,
		'Centro de día',
		18.5000,
		-69.9200,
		500,
		true
	)$$,
	'MONITOR creates a safe zone'
);
select results_eq(
	$$select count(*) from public.safe_zones where is_active and archived_at is null$$,
	$$values (2::bigint)$$,
	'multiple safe zones may be active for one patient'
);

select set_config('request.jwt.claim.sub', '73000000-0000-0000-0000-000000000073', true);
select results_eq(
	$$select count(*) from public.safe_zones$$,
	$$values (0::bigint)$$,
	'an outsider cannot read safe zones'
);
select throws_ok(
	$$select * from public.save_patient_safe_zone(
		null,
		current_setting('test.zone_patient_id')::uuid,
		'Zona ajena',
		18.5,
		-69.9,
		250,
		true
	)$$,
	'42501',
	'Active patient access is required.',
	'an outsider cannot create safe zones'
);

select set_config('request.jwt.claim.sub', '71000000-0000-0000-0000-000000000071', true);
select throws_ok(
	$$insert into public.safe_zones (
		patient_id, name, center_latitude, center_longitude, radius_m, created_by, updated_by
	) values (
		current_setting('test.zone_patient_id')::uuid,
		'Directa',
		18.5,
		-69.9,
		250,
		'71000000-0000-0000-0000-000000000071',
		'71000000-0000-0000-0000-000000000071'
	)$$,
	'42501',
	'permission denied for table safe_zones',
	'direct inserts remain blocked'
);
select throws_ok(
	$$select * from public.save_patient_safe_zone(
		null, current_setting('test.zone_patient_id')::uuid, 'Radio inválido', 18.5, -69.9, 49, true
	)$$,
	'22023',
	'Safe zone radius must be between 50 and 5000 meters.',
	'radius below 50 meters is rejected'
);
select throws_ok(
	$$select * from public.save_patient_safe_zone(
		null, current_setting('test.zone_patient_id')::uuid, 'Latitud inválida', 91, -69.9, 250, true
	)$$,
	'22023',
	'Safe zone latitude is invalid.',
	'invalid latitude is rejected'
);
select throws_ok(
	$$select * from public.save_patient_safe_zone(
		null, current_setting('test.zone_patient_id')::uuid, ' casa ', 18.5, -69.9, 250, true
	)$$,
	'23505',
	'Safe zone name must be unique for the patient.',
	'active names are unique per patient after normalization'
);

select lives_ok(
	$$select * from public.save_patient_safe_zone(
		current_setting('test.zone_id')::uuid,
		current_setting('test.zone_patient_id')::uuid,
		'Casa',
		18.4862,
		-69.9313,
		350,
		true
	)$$,
	'ADMIN updates an existing safe zone'
);
select results_eq(
	$$select radius_m from public.safe_zones where id = current_setting('test.zone_id')::uuid$$,
	$$values (350::double precision)$$,
	'the updated radius is persisted'
);
select lives_ok(
	$$select * from public.save_patient_safe_zone(
		current_setting('test.zone_id')::uuid,
		current_setting('test.zone_patient_id')::uuid,
		'Casa',
		18.4862,
		-69.9313,
		350,
		false
	)$$,
	'ADMIN deactivates a safe zone without archiving it'
);
select results_eq(
	$$select is_active from public.safe_zones where id = current_setting('test.zone_id')::uuid$$,
	$$values (false)$$,
	'deactivation is persisted'
);
select lives_ok(
	$$select * from public.archive_patient_safe_zone(
		current_setting('test.zone_id')::uuid,
		current_setting('test.zone_patient_id')::uuid
	)$$,
	'ADMIN archives a safe zone'
);
select results_eq(
	$$select count(*) from public.safe_zones where id = current_setting('test.zone_id')::uuid$$,
	$$values (1::bigint)$$,
	'archiving preserves the row'
);
select results_eq(
	$$select (archived_at is not null and not is_active) from public.safe_zones where id = current_setting('test.zone_id')::uuid$$,
	$$values (true)$$,
	'an archived zone is inactive'
);
select lives_ok(
	$$select * from public.save_patient_safe_zone(
		null,
		current_setting('test.zone_patient_id')::uuid,
		'Casa',
		18.4861,
		-69.9312,
		250,
		true
	)$$,
	'an archived name can be reused'
);
select lives_ok(
	$$select *
	from generate_series(1, 6) as series(number)
	cross join lateral public.save_patient_safe_zone(
		null,
		current_setting('test.zone_patient_id')::uuid,
		'Zona ' || series.number,
		18.48 + series.number / 1000.0,
		-69.93,
		250,
		true
	)$$,
	'more than five safe zones can be created'
);
select results_eq(
	$$select count(*) >= 7 from public.safe_zones where is_active and archived_at is null$$,
	$$values (true)$$,
	'the database has no artificial safe-zone maximum'
);

reset role;
select ok(
	not has_table_privilege('anon', 'public.safe_zones', 'SELECT'),
	'anon cannot select safe zones'
);
select ok(
	not has_function_privilege(
		'anon',
		'public.save_patient_safe_zone(uuid,uuid,text,double precision,double precision,double precision,boolean)',
		'EXECUTE'
	),
	'anon cannot save safe zones'
);
select ok(
	not has_function_privilege(
		'anon',
		'public.archive_patient_safe_zone(uuid,uuid)',
		'EXECUTE'
	),
	'anon cannot archive safe zones'
);
select ok(
	has_function_privilege(
		'authenticated',
		'public.save_patient_safe_zone(uuid,uuid,text,double precision,double precision,double precision,boolean)',
		'EXECUTE'
	),
	'authenticated can call the save RPC with internal authorization'
);

select * from finish();
rollback;
