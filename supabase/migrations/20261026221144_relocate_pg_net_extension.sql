-- Version aligned with the migration recorded in Supabase development.
drop trigger if exists alert_episodes_enqueue_web_push_after_insert
on public.alert_episodes;

drop function if exists private.enqueue_alert_episode_web_push();

drop extension if exists pg_net;
create schema if not exists extensions;
create extension pg_net with schema extensions;

create or replace function private.enqueue_alert_episode_web_push()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
	project_url text;
	webhook_secret text;
begin
	if new.status <> 'OPEN' then
		return new;
	end if;

	select decrypted_secret
	into project_url
	from vault.decrypted_secrets
	where name = 'senda_project_url'
	limit 1;

	select decrypted_secret
	into webhook_secret
	from vault.decrypted_secrets
	where name = 'senda_webhook_secret'
	limit 1;

	if nullif(btrim(project_url), '') is null
		or nullif(btrim(webhook_secret), '') is null then
		raise warning 'Senda Web Push is not configured; episode % remains stored.', new.id;
		return new;
	end if;

	perform net.http_post(
		url := rtrim(project_url, '/') || '/functions/v1/send-geofence-alert',
		body := jsonb_build_object(
			'type', 'INSERT',
			'table', tg_table_name,
			'schema', tg_table_schema,
			'record', jsonb_build_object(
				'id', new.id,
				'patient_id', new.patient_id,
				'status', new.status
			)
		),
		headers := jsonb_build_object(
			'Content-Type', 'application/json',
			'x-senda-webhook-secret', webhook_secret
		),
		timeout_milliseconds := 5000
	);

	return new;
exception
	when others then
		raise warning 'Senda Web Push could not be queued for episode %.', new.id;
		return new;
end;
$$;

comment on function private.enqueue_alert_episode_web_push() is
	'Queues one asynchronous Web Push request when a geofence episode opens; delivery failures never roll back the episode.';

revoke execute on function private.enqueue_alert_episode_web_push()
from public, anon, authenticated, service_role;

create trigger alert_episodes_enqueue_web_push_after_insert
after insert on public.alert_episodes
for each row
execute function private.enqueue_alert_episode_web_push();
