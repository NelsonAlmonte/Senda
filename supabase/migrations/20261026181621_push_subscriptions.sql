-- Version aligned with the migration recorded in Supabase development.
create table public.push_subscriptions (
	id uuid primary key default gen_random_uuid(),
	user_id uuid not null references auth.users (id) on delete cascade,
	endpoint text not null,
	p256dh text not null,
	auth text not null,
	created_at timestamptz not null default now(),
	constraint push_subscriptions_endpoint_not_blank check (
		char_length(btrim(endpoint)) between 1 and 2048
	),
	constraint push_subscriptions_p256dh_not_blank check (
		char_length(btrim(p256dh)) between 1 and 512
	),
	constraint push_subscriptions_auth_not_blank check (
		char_length(btrim(auth)) between 1 and 512
	),
	constraint push_subscriptions_endpoint_key unique (endpoint)
);

comment on table public.push_subscriptions is
	'Browser Web Push subscriptions. Each authenticated user can manage only their own endpoints.';
comment on column public.push_subscriptions.endpoint is
	'Push service capability URL. It is private to its owner and must not be exposed globally.';

create index push_subscriptions_user_id_created_at_idx
on public.push_subscriptions (user_id, created_at desc);

alter table public.push_subscriptions enable row level security;

revoke all on table public.push_subscriptions from public, anon, authenticated;
grant select, insert, update, delete on table public.push_subscriptions to authenticated;
grant select, insert, update, delete on table public.push_subscriptions to service_role;

create policy "push_subscriptions_select_own"
on public.push_subscriptions
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "push_subscriptions_insert_own"
on public.push_subscriptions
for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy "push_subscriptions_update_own"
on public.push_subscriptions
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "push_subscriptions_delete_own"
on public.push_subscriptions
for delete
to authenticated
using ((select auth.uid()) = user_id);
