create table public.safe_zones (
	id uuid primary key default gen_random_uuid(),
	patient_id uuid not null references public.patients (id) on delete cascade,
	name text not null,
	center_latitude double precision not null,
	center_longitude double precision not null,
	radius_m double precision not null default 250,
	is_active boolean not null default true,
	created_by uuid not null references auth.users (id) on delete restrict,
	updated_by uuid not null references auth.users (id) on delete restrict,
	created_at timestamptz not null default now(),
	updated_at timestamptz not null default now(),
	archived_at timestamptz,
	constraint safe_zones_name_valid check (char_length(btrim(name)) between 1 and 60),
	constraint safe_zones_latitude_valid check (
		center_latitude between -90 and 90
		and center_latitude <> 'NaN'::double precision
	),
	constraint safe_zones_longitude_valid check (
		center_longitude between -180 and 180
		and center_longitude <> 'NaN'::double precision
	),
	constraint safe_zones_radius_valid check (
		radius_m between 50 and 5000
		and radius_m <> 'NaN'::double precision
	),
	constraint safe_zones_archived_inactive check (archived_at is null or not is_active),
	constraint safe_zones_updated_after_creation check (updated_at >= created_at),
	constraint safe_zones_archived_after_creation check (
		archived_at is null or archived_at >= created_at
	)
);

comment on table public.safe_zones is
	'Circular allowed areas configured per patient. Archived zones are retained but never evaluated.';
comment on column public.safe_zones.radius_m is 'Circle radius in meters, limited to 50-5000 for the MVP.';
comment on column public.safe_zones.is_active is
	'Only active, non-archived zones participate in the future safety evaluation.';

create unique index safe_zones_patient_normalized_name_idx
on public.safe_zones (patient_id, lower(btrim(name)))
where archived_at is null;

create index safe_zones_patient_active_idx
on public.safe_zones (patient_id, is_active, updated_at desc)
where archived_at is null;

create index safe_zones_created_by_idx on public.safe_zones (created_by);
create index safe_zones_updated_by_idx on public.safe_zones (updated_by);

alter table public.safe_zones enable row level security;

revoke all on table public.safe_zones from anon, authenticated;
grant select on table public.safe_zones to authenticated;

create policy "safe_zones_select_authorized"
on public.safe_zones
for select
to authenticated
using (
	exists (
		select 1
		from public.patient_access
		where patient_access.patient_id = safe_zones.patient_id
			and patient_access.user_id = (select auth.uid())
			and patient_access.revoked_at is null
	)
);

create or replace function private.save_patient_safe_zone(
	p_zone_id uuid,
	p_patient_id uuid,
	p_name text,
	p_center_latitude double precision,
	p_center_longitude double precision,
	p_radius_m double precision,
	p_is_active boolean
)
returns table (saved_zone_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
	caller_user_id uuid := (select auth.uid());
	normalized_name text := btrim(coalesce(p_name, ''));
	result_zone_id uuid;
begin
	if caller_user_id is null then
		raise exception 'Authentication is required.' using errcode = '42501';
	end if;

	if p_patient_id is null then
		raise exception 'Patient is required.' using errcode = '22023';
	end if;

	if not exists (
		select 1
		from public.patient_access
		where patient_access.patient_id = p_patient_id
			and patient_access.user_id = caller_user_id
			and patient_access.access_role in ('ADMIN', 'MONITOR')
			and patient_access.revoked_at is null
	) then
		raise exception 'Active patient access is required.' using errcode = '42501';
	end if;

	if char_length(normalized_name) not between 1 and 60 then
		raise exception 'Safe zone name must contain between 1 and 60 characters.'
			using errcode = '22023';
	end if;

	if p_center_latitude is null
		or p_center_latitude not between -90 and 90
		or p_center_latitude = 'NaN'::double precision then
		raise exception 'Safe zone latitude is invalid.' using errcode = '22023';
	end if;

	if p_center_longitude is null
		or p_center_longitude not between -180 and 180
		or p_center_longitude = 'NaN'::double precision then
		raise exception 'Safe zone longitude is invalid.' using errcode = '22023';
	end if;

	if p_radius_m is null
		or p_radius_m not between 50 and 5000
		or p_radius_m = 'NaN'::double precision then
		raise exception 'Safe zone radius must be between 50 and 5000 meters.'
			using errcode = '22023';
	end if;

	if p_is_active is null then
		raise exception 'Safe zone active state is required.' using errcode = '22023';
	end if;

	if exists (
		select 1
		from public.safe_zones
		where safe_zones.patient_id = p_patient_id
			and lower(btrim(safe_zones.name)) = lower(normalized_name)
			and safe_zones.archived_at is null
			and (p_zone_id is null or safe_zones.id <> p_zone_id)
	) then
		raise exception 'Safe zone name must be unique for the patient.' using errcode = '23505';
	end if;

	if p_zone_id is null then
		insert into public.safe_zones (
			patient_id,
			name,
			center_latitude,
			center_longitude,
			radius_m,
			is_active,
			created_by,
			updated_by
		)
		values (
			p_patient_id,
			normalized_name,
			p_center_latitude,
			p_center_longitude,
			p_radius_m,
			p_is_active,
			caller_user_id,
			caller_user_id
		)
		returning id into result_zone_id;
	else
		update public.safe_zones
		set name = normalized_name,
			center_latitude = p_center_latitude,
			center_longitude = p_center_longitude,
			radius_m = p_radius_m,
			is_active = p_is_active,
			updated_by = caller_user_id,
			updated_at = now()
		where id = p_zone_id
			and patient_id = p_patient_id
			and archived_at is null
		returning id into result_zone_id;

		if result_zone_id is null then
			raise exception 'Safe zone was not found.' using errcode = 'P0002';
		end if;
	end if;

	return query select result_zone_id;
end;
$$;

create or replace function private.archive_patient_safe_zone(
	p_zone_id uuid,
	p_patient_id uuid
)
returns table (archived_zone_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
	caller_user_id uuid := (select auth.uid());
	result_zone_id uuid;
begin
	if caller_user_id is null then
		raise exception 'Authentication is required.' using errcode = '42501';
	end if;

	if not exists (
		select 1
		from public.patient_access
		where patient_access.patient_id = p_patient_id
			and patient_access.user_id = caller_user_id
			and patient_access.access_role in ('ADMIN', 'MONITOR')
			and patient_access.revoked_at is null
	) then
		raise exception 'Active patient access is required.' using errcode = '42501';
	end if;

	update public.safe_zones
	set is_active = false,
		archived_at = now(),
		updated_by = caller_user_id,
		updated_at = now()
	where id = p_zone_id
		and patient_id = p_patient_id
		and archived_at is null
	returning id into result_zone_id;

	if result_zone_id is null then
		raise exception 'Safe zone was not found.' using errcode = 'P0002';
	end if;

	return query select result_zone_id;
end;
$$;

revoke execute on function private.save_patient_safe_zone(
	uuid, uuid, text, double precision, double precision, double precision, boolean
) from public, anon, service_role;
revoke execute on function private.archive_patient_safe_zone(uuid, uuid)
from public, anon, service_role;
grant usage on schema private to authenticated;
grant execute on function private.save_patient_safe_zone(
	uuid, uuid, text, double precision, double precision, double precision, boolean
) to authenticated;
grant execute on function private.archive_patient_safe_zone(uuid, uuid) to authenticated;

create or replace function public.save_patient_safe_zone(
	p_zone_id uuid,
	p_patient_id uuid,
	p_name text,
	p_center_latitude double precision,
	p_center_longitude double precision,
	p_radius_m double precision,
	p_is_active boolean
)
returns table (saved_zone_id uuid)
language sql
security invoker
set search_path = ''
as $$
	select *
	from private.save_patient_safe_zone(
		p_zone_id,
		p_patient_id,
		p_name,
		p_center_latitude,
		p_center_longitude,
		p_radius_m,
		p_is_active
	);
$$;

create or replace function public.archive_patient_safe_zone(
	p_zone_id uuid,
	p_patient_id uuid
)
returns table (archived_zone_id uuid)
language sql
security invoker
set search_path = ''
as $$
	select * from private.archive_patient_safe_zone(p_zone_id, p_patient_id);
$$;

comment on function public.save_patient_safe_zone(
	uuid, uuid, text, double precision, double precision, double precision, boolean
) is 'Creates or updates one circular safe zone after patient-scoped authorization.';
comment on function public.archive_patient_safe_zone(uuid, uuid) is
	'Archives a safe zone without deleting its audit history.';

revoke execute on function public.save_patient_safe_zone(
	uuid, uuid, text, double precision, double precision, double precision, boolean
) from public, anon;
revoke execute on function public.archive_patient_safe_zone(uuid, uuid) from public, anon;
grant execute on function public.save_patient_safe_zone(
	uuid, uuid, text, double precision, double precision, double precision, boolean
) to authenticated;
grant execute on function public.archive_patient_safe_zone(uuid, uuid) to authenticated;
