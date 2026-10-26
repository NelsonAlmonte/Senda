begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(29);

select has_table('public', 'push_subscriptions', 'push subscriptions are persisted');
select has_column('public', 'push_subscriptions', 'id', 'subscriptions have an id');
select has_column('public', 'push_subscriptions', 'user_id', 'subscriptions belong to a user');
select has_column('public', 'push_subscriptions', 'endpoint', 'subscriptions store the endpoint');
select has_column('public', 'push_subscriptions', 'p256dh', 'subscriptions store the p256dh key');
select has_column('public', 'push_subscriptions', 'auth', 'subscriptions store the auth key');
select has_column('public', 'push_subscriptions', 'created_at', 'subscriptions preserve creation time');
select ok(
	(
		select relrowsecurity
		from pg_class
		join pg_namespace on pg_namespace.oid = pg_class.relnamespace
		where pg_namespace.nspname = 'public'
			and pg_class.relname = 'push_subscriptions'
	),
	'RLS is enabled for push subscriptions'
);
select ok(
	exists (
		select 1
		from pg_constraint
		where conrelid = 'public.push_subscriptions'::regclass
			and conname = 'push_subscriptions_endpoint_key'
			and contype = 'u'
	),
	'each browser endpoint is stored only once'
);
select ok(
	exists (
		select 1
		from pg_constraint
		where conrelid = 'public.push_subscriptions'::regclass
			and contype = 'f'
			and confrelid = 'auth.users'::regclass
			and confdeltype = 'c'
	),
	'deleting an auth user removes their subscriptions'
);
select ok(
	has_table_privilege('authenticated', 'public.push_subscriptions', 'SELECT'),
	'authenticated users can select through RLS'
);
select ok(
	has_table_privilege('authenticated', 'public.push_subscriptions', 'INSERT'),
	'authenticated users can insert through RLS'
);
select ok(
	has_table_privilege('authenticated', 'public.push_subscriptions', 'UPDATE'),
	'authenticated users can update through RLS'
);
select ok(
	has_table_privilege('authenticated', 'public.push_subscriptions', 'DELETE'),
	'authenticated users can delete through RLS'
);
select ok(
	not has_table_privilege('anon', 'public.push_subscriptions', 'SELECT'),
	'anonymous users cannot read subscriptions'
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
		'push-owner-a@example.test',
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
		'push-owner-b@example.test',
		'',
		now(),
		now(),
		now(),
		'{"provider":"email","providers":["email"]}'::jsonb,
		'{}'::jsonb
	);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'a1000000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select lives_ok(
	$$insert into public.push_subscriptions (user_id, endpoint, p256dh, auth)
	values (
		'a1000000-0000-0000-0000-000000000001',
		'https://push.example.test/a',
		'owner-a-p256dh',
		'owner-a-auth'
	)$$,
	'a user can register their own browser subscription'
);
select results_eq(
	$$select count(*) from public.push_subscriptions$$,
	$$values (1::bigint)$$,
	'the owner can read their subscription'
);
select throws_ok(
	$$insert into public.push_subscriptions (user_id, endpoint, p256dh, auth)
	values (
		'b2000000-0000-0000-0000-000000000002',
		'https://push.example.test/forged',
		'forged-p256dh',
		'forged-auth'
	)$$,
	'42501',
	'new row violates row-level security policy for table "push_subscriptions"',
	'a user cannot register a subscription for somebody else'
);

select set_config('request.jwt.claim.sub', 'b2000000-0000-0000-0000-000000000002', true);
select results_eq(
	$$select count(*) from public.push_subscriptions$$,
	$$values (0::bigint)$$,
	'another user cannot read the first owner subscription'
);
select lives_ok(
	$$insert into public.push_subscriptions (user_id, endpoint, p256dh, auth)
	values (
		'b2000000-0000-0000-0000-000000000002',
		'https://push.example.test/b',
		'owner-b-p256dh',
		'owner-b-auth'
	)$$,
	'a second user can register a separate browser subscription'
);
select results_eq(
	$$select count(*) from public.push_subscriptions$$,
	$$values (1::bigint)$$,
	'the second user sees only their own subscription'
);
select results_eq(
	$$with changed as (
		update public.push_subscriptions
		set p256dh = 'tampered'
		where endpoint = 'https://push.example.test/a'
		returning id
	)
	select count(*) from changed$$,
	$$values (0::bigint)$$,
	'a user cannot update a hidden subscription'
);
select throws_ok(
	$$update public.push_subscriptions
	set user_id = 'a1000000-0000-0000-0000-000000000001'
	where endpoint = 'https://push.example.test/b'$$,
	'42501',
	'new row violates row-level security policy for table "push_subscriptions"',
	'a user cannot transfer their subscription to somebody else'
);
select results_eq(
	$$with removed as (
		delete from public.push_subscriptions
		where endpoint = 'https://push.example.test/a'
		returning id
	)
	select count(*) from removed$$,
	$$values (0::bigint)$$,
	'a user cannot delete a hidden subscription'
);

select set_config('request.jwt.claim.sub', 'a1000000-0000-0000-0000-000000000001', true);
select lives_ok(
	$$update public.push_subscriptions
	set p256dh = 'owner-a-p256dh-updated', auth = 'owner-a-auth-updated'
	where endpoint = 'https://push.example.test/a'$$,
	'the owner can refresh their subscription keys'
);
select results_eq(
	$$select p256dh, auth from public.push_subscriptions$$,
	$$values ('owner-a-p256dh-updated'::text, 'owner-a-auth-updated'::text)$$,
	'the owner reads the refreshed keys'
);
select lives_ok(
	$$delete from public.push_subscriptions
	where endpoint = 'https://push.example.test/a'$$,
	'the owner can remove their browser subscription'
);
select results_eq(
	$$select count(*) from public.push_subscriptions$$,
	$$values (0::bigint)$$,
	'the removed subscription is no longer visible to its owner'
);

reset role;
select results_eq(
	$$select count(*) from public.push_subscriptions$$,
	$$values (1::bigint)$$,
	'deleting one browser subscription does not remove another user subscription'
);

select * from finish();
rollback;
