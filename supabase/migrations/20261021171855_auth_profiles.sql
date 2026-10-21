create schema if not exists private;

revoke all on schema private from public;

create table public.profiles (
	id uuid primary key references auth.users (id) on delete cascade,
	full_name text not null default '',
	created_at timestamptz not null default now(),
	updated_at timestamptz not null default now(),
	constraint profiles_full_name_length check (char_length(full_name) <= 120)
);

comment on table public.profiles is 'Minimal application profile linked one-to-one with Supabase Auth.';
comment on column public.profiles.full_name is 'Display name only; never used for authorization.';

alter table public.profiles enable row level security;

revoke all on table public.profiles from anon, authenticated;
grant select, update on table public.profiles to authenticated;

create policy "profiles_select_own"
on public.profiles
for select
to authenticated
using ((select auth.uid()) = id);

create policy "profiles_update_own"
on public.profiles
for update
to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

create or replace function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
	new.updated_at = now();
	return new;
end;
$$;

revoke execute on function private.set_updated_at() from public, anon, authenticated;

create trigger profiles_set_updated_at
before update on public.profiles
for each row
execute function private.set_updated_at();

create or replace function private.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
	insert into public.profiles (id, full_name)
	values (
		new.id,
		left(trim(coalesce(new.raw_user_meta_data ->> 'full_name', '')), 120)
	);

	return new;
end;
$$;

revoke execute on function private.handle_new_auth_user() from public, anon, authenticated, service_role;

insert into public.profiles (id, full_name)
select
	id,
	left(trim(coalesce(raw_user_meta_data ->> 'full_name', '')), 120)
from auth.users
on conflict (id) do nothing;

create trigger on_auth_user_created
after insert on auth.users
for each row
execute function private.handle_new_auth_user();
