begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(14);

select ok(
	exists (select 1 from pg_extension where extname = 'pg_net'),
	'pg_net is enabled for asynchronous webhook delivery'
);
select results_eq(
	$$select pg_namespace.nspname
	from pg_extension
	join pg_namespace on pg_namespace.oid = pg_extension.extnamespace
	where pg_extension.extname = 'pg_net'$$,
	$$values ('extensions'::name)$$,
	'pg_net is registered outside the public schema'
);
select ok(
	to_regprocedure('private.enqueue_alert_episode_web_push()') is not null,
	'the internal Web Push enqueue function exists'
);
select has_trigger(
	'public',
	'alert_episodes',
	'alert_episodes_enqueue_web_push_after_insert',
	'alert episode inserts enqueue Web Push delivery'
);
select results_eq(
	$$select tgtype::integer
	from pg_trigger
	where tgrelid = 'public.alert_episodes'::regclass
		and tgname = 'alert_episodes_enqueue_web_push_after_insert'$$,
	$$values (5)$$,
	'the Web Push trigger runs only after each INSERT'
);
select ok(
	(
		select prosecdef
		from pg_proc
		where oid = 'private.enqueue_alert_episode_web_push()'::regprocedure
	),
	'the enqueue function can read Vault without exposing Vault to clients'
);
select ok(
	(
		select array_to_string(proconfig, ',') like '%search_path=%'
		from pg_proc
		where oid = 'private.enqueue_alert_episode_web_push()'::regprocedure
	),
	'the privileged enqueue function fixes its search path'
);
select ok(
	not has_function_privilege('anon', 'private.enqueue_alert_episode_web_push()', 'EXECUTE'),
	'anonymous users cannot call the enqueue function'
);
select ok(
	not has_function_privilege(
		'authenticated',
		'private.enqueue_alert_episode_web_push()',
		'EXECUTE'
	),
	'authenticated users cannot call the enqueue function'
);
select ok(
	not has_function_privilege(
		'service_role',
		'private.enqueue_alert_episode_web_push()',
		'EXECUTE'
	),
	'service_role cannot bypass the trigger by calling the enqueue function'
);
select ok(
	position(
		'senda_project_url' in pg_get_functiondef(
			'private.enqueue_alert_episode_web_push()'::regprocedure
		)
	) > 0,
	'the webhook URL is loaded from Vault instead of hard-coded per environment'
);
select ok(
	position(
		'senda_webhook_secret' in pg_get_functiondef(
			'private.enqueue_alert_episode_web_push()'::regprocedure
		)
	) > 0,
	'the webhook authentication secret is loaded from Vault'
);
select ok(
	position(
		'net.http_post' in pg_get_functiondef(
			'private.enqueue_alert_episode_web_push()'::regprocedure
		)
	) > 0,
	'the trigger queues an asynchronous HTTP request through pg_net'
);
select ok(
	pg_get_functiondef('private.enqueue_alert_episode_web_push()'::regprocedure) !~
		'(first_name|last_name|latitude|longitude)',
	'the database webhook never includes patient identity or coordinates'
);

select * from finish();
rollback;
