create table public.groups (
	id uuid primary key default gen_random_uuid(),
	name text not null,
	type text not null,
	owner_user_id uuid not null references auth.users (id) on delete restrict,
	created_at timestamptz not null default now(),
	constraint groups_name_not_blank check (char_length(btrim(name)) between 1 and 120),
	constraint groups_type_valid check (type in ('FAMILY', 'CARE_CENTER'))
);

comment on table public.groups is 'Lightweight family or care-center context; patient access remains explicit.';
comment on column public.groups.owner_user_id is 'Single administrative owner for the initial MVP.';

create index groups_owner_user_id_idx on public.groups (owner_user_id);

create table public.patients (
	id uuid primary key default gen_random_uuid(),
	group_id uuid not null references public.groups (id) on delete restrict,
	first_name text not null,
	last_name text not null,
	created_at timestamptz not null default now(),
	constraint patients_first_name_not_blank check (
		char_length(btrim(first_name)) between 1 and 80
	),
	constraint patients_last_name_not_blank check (
		char_length(btrim(last_name)) between 1 and 80
	)
);

comment on table public.patients is 'Central monitored person entity with minimal administrative data.';

create index patients_group_id_idx on public.patients (group_id);

create table public.patient_access (
	id uuid primary key default gen_random_uuid(),
	patient_id uuid not null references public.patients (id) on delete cascade,
	user_id uuid not null references auth.users (id) on delete cascade,
	access_role text not null,
	relationship text,
	created_at timestamptz not null default now(),
	revoked_at timestamptz,
	constraint patient_access_role_valid check (access_role in ('ADMIN', 'MONITOR')),
	constraint patient_access_relationship_valid check (
		relationship is null or relationship in ('FAMILY', 'CAREGIVER', 'OTHER')
	),
	constraint patient_access_revoked_after_creation check (
		revoked_at is null or revoked_at >= created_at
	)
);

comment on table public.patient_access is 'Patient-scoped authorization; group membership never replaces this access.';
comment on column public.patient_access.relationship is 'Descriptive only and never used for authorization.';

create unique index patient_access_active_patient_user_idx
on public.patient_access (patient_id, user_id)
where revoked_at is null;

create index patient_access_active_user_patient_idx
on public.patient_access (user_id, patient_id)
where revoked_at is null;

create index patient_access_patient_id_idx on public.patient_access (patient_id);
create index patient_access_user_id_idx on public.patient_access (user_id);

alter table public.groups enable row level security;
alter table public.patients enable row level security;
alter table public.patient_access enable row level security;

revoke all on table public.groups, public.patients, public.patient_access from anon, authenticated;

grant select on table public.groups to authenticated;
grant insert (id, name, type, owner_user_id) on table public.groups to authenticated;
grant select on table public.patients to authenticated;
grant insert (id, group_id, first_name, last_name) on table public.patients to authenticated;
grant select on table public.patient_access to authenticated;

create policy "groups_select_authorized"
on public.groups
for select
to authenticated
using (
	owner_user_id = (select auth.uid())
	or exists (
		select 1
		from public.patients
		join public.patient_access
			on patient_access.patient_id = patients.id
		where patients.group_id = groups.id
			and patient_access.user_id = (select auth.uid())
			and patient_access.revoked_at is null
	)
);

create policy "groups_insert_own"
on public.groups
for insert
to authenticated
with check (owner_user_id = (select auth.uid()));

create policy "patients_select_authorized"
on public.patients
for select
to authenticated
using (
	exists (
		select 1
		from public.patient_access
		where patient_access.patient_id = patients.id
			and patient_access.user_id = (select auth.uid())
			and patient_access.revoked_at is null
	)
);

create policy "patients_insert_into_owned_group"
on public.patients
for insert
to authenticated
with check (
	exists (
		select 1
		from public.groups
		where groups.id = patients.group_id
			and groups.owner_user_id = (select auth.uid())
	)
);

create policy "patient_access_select_own"
on public.patient_access
for select
to authenticated
using (user_id = (select auth.uid()));

create or replace function private.grant_patient_creator_admin()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
	creator_user_id uuid := (select auth.uid());
begin
	if creator_user_id is null then
		raise exception 'Authentication is required.' using errcode = '42501';
	end if;

	insert into public.patient_access (patient_id, user_id, access_role)
	values (new.id, creator_user_id, 'ADMIN');

	return new;
end;
$$;

revoke execute on function private.grant_patient_creator_admin() from public, anon, authenticated, service_role;

create trigger patients_grant_creator_admin
after insert on public.patients
for each row
execute function private.grant_patient_creator_admin();

create or replace function public.create_patient_onboarding(
	p_group_name text,
	p_group_type text,
	p_patient_first_name text,
	p_patient_last_name text
)
returns table (created_group_id uuid, created_patient_id uuid)
language plpgsql
security invoker
set search_path = ''
as $$
declare
	new_group_id uuid := gen_random_uuid();
	new_patient_id uuid := gen_random_uuid();
begin
	if (select auth.uid()) is null then
		raise exception 'Authentication is required.' using errcode = '42501';
	end if;

	if char_length(btrim(coalesce(p_group_name, ''))) not between 1 and 120 then
		raise exception 'Group name must contain between 1 and 120 characters.'
			using errcode = '22023';
	end if;

	if coalesce(p_group_type, '') not in ('FAMILY', 'CARE_CENTER') then
		raise exception 'Group type must be FAMILY or CARE_CENTER.' using errcode = '22023';
	end if;

	if char_length(btrim(coalesce(p_patient_first_name, ''))) not between 1 and 80 then
		raise exception 'Patient first name must contain between 1 and 80 characters.'
			using errcode = '22023';
	end if;

	if char_length(btrim(coalesce(p_patient_last_name, ''))) not between 1 and 80 then
		raise exception 'Patient last name must contain between 1 and 80 characters.'
			using errcode = '22023';
	end if;

	insert into public.groups (id, name, type, owner_user_id)
	values (new_group_id, btrim(p_group_name), p_group_type, (select auth.uid()));

	insert into public.patients (id, group_id, first_name, last_name)
	values (
		new_patient_id,
		new_group_id,
		btrim(p_patient_first_name),
		btrim(p_patient_last_name)
	);

	return query select new_group_id, new_patient_id;
end;
$$;

comment on function public.create_patient_onboarding(text, text, text, text) is
	'Atomically creates an owned group, a patient, and ADMIN access for the authenticated creator.';

revoke execute on function public.create_patient_onboarding(text, text, text, text)
from public, anon;

grant execute on function public.create_patient_onboarding(text, text, text, text)
to authenticated;
