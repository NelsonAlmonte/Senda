begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(12);

-- Structure and privileges --------------------------------------------------

select has_column('public', 'devices', 'last_seen_at', 'devices has a last_seen_at column');
select col_is_null('public', 'devices', 'last_seen_at', 'last_seen_at is empty until the tracker reports');

select ok(
	has_function_privilege('service_role', 'public.record_device_heartbeat(text)', 'EXECUTE'),
	'service_role can record a heartbeat'
);
select ok(
	not has_function_privilege('authenticated', 'public.record_device_heartbeat(text)', 'EXECUTE')
	and not has_function_privilege('anon', 'public.record_device_heartbeat(text)', 'EXECUTE'),
	'authenticated and anon cannot record a heartbeat'
);
select ok(
	not has_function_privilege('authenticated', 'private.record_device_heartbeat(text)', 'EXECUTE'),
	'authenticated cannot execute the private heartbeat function'
);
select ok(
	not has_table_privilege('authenticated', 'public.devices', 'UPDATE'),
	'authenticated cannot write last_seen_at directly'
);

-- Behaviour -----------------------------------------------------------------

select registered_device_id as physical_device_id
from public.register_physical_device('SENDA-SEEN-001', '990000000009001')
\gset

select registered_device_id as other_device_id
from public.register_physical_device('SENDA-SEEN-002', '990000000009002')
\gset

select lives_ok(
	$$select public.record_device_heartbeat('990000000009001')$$,
	'a heartbeat for a registered tracker succeeds'
);

select ok(
	(select last_seen_at from public.devices where id = :'physical_device_id') >= now() - interval '1 minute',
	'the heartbeat stamps the tracker that reported'
);

select is(
	(select last_seen_at from public.devices where id = :'other_device_id'),
	null::timestamptz,
	'a heartbeat does not touch another device'
);

select lives_ok(
	$$select public.record_device_heartbeat('990000000009999')$$,
	'an unknown hardware identifier is a silent no-op'
);

select throws_ok(
	$$select public.record_device_heartbeat('not valid!')$$,
	'22023',
	'Hardware identifier is invalid.',
	'a malformed hardware identifier is rejected'
);

select is(
	(select count(*) from public.locations),
	0::bigint,
	'a heartbeat never creates a location'
);

select * from finish();

rollback;
