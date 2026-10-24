create table public.invitations (
	id uuid primary key default gen_random_uuid(),
	patient_id uuid not null references public.patients (id) on delete cascade,
	email text,
	access_role text not null default 'MONITOR',
	status text not null default 'PENDING',
	token_hash text not null unique,
	invited_by uuid not null references auth.users (id) on delete cascade,
	created_at timestamptz not null default now(),
	accepted_at timestamptz,
	declined_at timestamptz,
	constraint invitations_access_role_valid check (access_role in ('ADMIN', 'MONITOR')),
	constraint invitations_status_valid check (status in ('PENDING', 'ACCEPTED', 'DECLINED')),
	constraint invitations_email_normalized check (email is null or email = lower(btrim(email))),
	constraint invitations_response_dates_valid check (
		(status = 'PENDING' and accepted_at is null and declined_at is null)
		or (status = 'ACCEPTED' and accepted_at is not null and declined_at is null)
		or (status = 'DECLINED' and declined_at is not null and accepted_at is null)
	)
);

comment on table public.invitations is
	'One-time patient access invitations. Manual codes store only a SHA-256 hash.';

create index invitations_patient_id_idx on public.invitations (patient_id);
create index invitations_invited_by_idx on public.invitations (invited_by);
create index invitations_pending_token_idx on public.invitations (token_hash)
where status = 'PENDING';

alter table public.invitations enable row level security;
revoke all on table public.invitations from anon, authenticated;

create or replace function private.hash_access_code(p_code text)
returns text
language sql
immutable
security invoker
set search_path = ''
as $$
	select encode(
		extensions.digest(regexp_replace(upper(btrim(coalesce(p_code, ''))), '[^A-Z0-9]', '', 'g'), 'sha256'),
		'hex'
	);
$$;

revoke execute on function private.hash_access_code(text) from public, anon, service_role;
grant execute on function private.hash_access_code(text) to authenticated;

create or replace function private.create_patient_access_code(p_patient_id uuid)
returns table (invitation_id uuid, access_code text)
language plpgsql
security definer
set search_path = ''
as $$
declare
	caller_user_id uuid := (select auth.uid());
	raw_code text := upper(encode(extensions.gen_random_bytes(6), 'hex'));
	new_invitation_id uuid := gen_random_uuid();
begin
	if caller_user_id is null then
		raise exception 'Authentication is required.' using errcode = '42501';
	end if;

	if not exists (
		select 1 from public.patient_access
		where patient_id = p_patient_id
			and user_id = caller_user_id
			and access_role = 'ADMIN'
			and revoked_at is null
	) then
		raise exception 'ADMIN access to the patient is required.' using errcode = '42501';
	end if;

	insert into public.invitations (
		id, patient_id, access_role, token_hash, invited_by
	)
	values (
		new_invitation_id,
		p_patient_id,
		'MONITOR',
		private.hash_access_code(raw_code),
		caller_user_id
	);

	return query
	select new_invitation_id, format('%s-%s-%s', substr(raw_code, 1, 4), substr(raw_code, 5, 4), substr(raw_code, 9, 4));
end;
$$;

create or replace function private.preview_patient_access_code(p_code text)
returns table (
	patient_first_name text,
	patient_last_name text,
	group_name text,
	group_type text
)
language plpgsql
security definer
set search_path = ''
as $$
begin
	if (select auth.uid()) is null then
		raise exception 'Authentication is required.' using errcode = '42501';
	end if;

	return query
	select patients.first_name, patients.last_name, groups.name, groups.type
	from public.invitations
	join public.patients on patients.id = invitations.patient_id
	join public.groups on groups.id = patients.group_id
	where invitations.token_hash = private.hash_access_code(p_code)
		and invitations.status = 'PENDING';
end;
$$;

create or replace function private.accept_patient_access_code(p_code text)
returns table (accepted_patient_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
	caller_user_id uuid := (select auth.uid());
	matched_invitation public.invitations%rowtype;
begin
	if caller_user_id is null then
		raise exception 'Authentication is required.' using errcode = '42501';
	end if;

	select * into matched_invitation
	from public.invitations
	where token_hash = private.hash_access_code(p_code)
		and status = 'PENDING'
	for update;

	if not found then
		raise exception 'Access code is invalid or already used.' using errcode = '22023';
	end if;

	if exists (
		select 1 from public.patient_access
		where patient_id = matched_invitation.patient_id
			and user_id = caller_user_id
			and revoked_at is null
	) then
		raise exception 'User already has active access to the patient.' using errcode = '23505';
	end if;

	insert into public.patient_access (patient_id, user_id, access_role)
	values (matched_invitation.patient_id, caller_user_id, 'MONITOR');

	update public.invitations
	set status = 'ACCEPTED', accepted_at = now()
	where id = matched_invitation.id;

	return query select matched_invitation.patient_id;
end;
$$;

revoke execute on function private.create_patient_access_code(uuid) from public, anon, service_role;
revoke execute on function private.preview_patient_access_code(text) from public, anon, service_role;
revoke execute on function private.accept_patient_access_code(text) from public, anon, service_role;
grant execute on function private.create_patient_access_code(uuid) to authenticated;
grant execute on function private.preview_patient_access_code(text) to authenticated;
grant execute on function private.accept_patient_access_code(text) to authenticated;

create or replace function public.create_patient_access_code(p_patient_id uuid)
returns table (invitation_id uuid, access_code text)
language sql security invoker set search_path = ''
as $$ select * from private.create_patient_access_code(p_patient_id); $$;

create or replace function public.preview_patient_access_code(p_code text)
returns table (patient_first_name text, patient_last_name text, group_name text, group_type text)
language sql security invoker set search_path = ''
as $$ select * from private.preview_patient_access_code(p_code); $$;

create or replace function public.accept_patient_access_code(p_code text)
returns table (accepted_patient_id uuid)
language sql security invoker set search_path = ''
as $$ select * from private.accept_patient_access_code(p_code); $$;

revoke execute on function public.create_patient_access_code(uuid) from public, anon;
revoke execute on function public.preview_patient_access_code(text) from public, anon;
revoke execute on function public.accept_patient_access_code(text) from public, anon;
grant execute on function public.create_patient_access_code(uuid) to authenticated;
grant execute on function public.preview_patient_access_code(text) to authenticated;
grant execute on function public.accept_patient_access_code(text) to authenticated;
