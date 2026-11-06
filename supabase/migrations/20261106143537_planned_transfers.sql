create table public.planned_transfers (
	id uuid primary key default gen_random_uuid(),
	patient_id uuid not null references public.patients (id) on delete restrict,
	starts_at timestamptz not null,
	ends_at timestamptz not null,
	note text not null,
	created_by uuid not null references auth.users (id) on delete restrict,
	updated_by uuid not null references auth.users (id) on delete restrict,
	ended_at timestamptz,
	ended_by uuid references auth.users (id) on delete restrict,
	cancelled_at timestamptz,
	cancelled_by uuid references auth.users (id) on delete restrict,
	created_at timestamptz not null default now(),
	updated_at timestamptz not null default now(),
	constraint planned_transfers_note_valid
		check (char_length(btrim(note)) between 1 and 500),
	constraint planned_transfers_window_valid
		check (ends_at > starts_at and ends_at <= starts_at + interval '24 hours'),
	constraint planned_transfers_ended_pair_valid
		check ((ended_at is null) = (ended_by is null)),
	constraint planned_transfers_cancelled_pair_valid
		check ((cancelled_at is null) = (cancelled_by is null)),
	constraint planned_transfers_single_terminal_state
		check (ended_at is null or cancelled_at is null),
	constraint planned_transfers_ended_window_valid
		check (ended_at is null or (ended_at >= starts_at and ended_at <= ends_at)),
	constraint planned_transfers_cancelled_after_creation
		check (cancelled_at is null or cancelled_at >= created_at),
	constraint planned_transfers_updated_after_creation
		check (updated_at >= created_at)
);

comment on table public.planned_transfers is
	'Patient travel windows that suppress only the creation of new geofence exit episodes while location ingestion continues.';
comment on column public.planned_transfers.ends_at is
	'Planned end, limited to 24 hours after starts_at. An ADMIN may extend it within that limit.';
comment on column public.planned_transfers.ended_at is
	'Actual early finish. Null means the planned end remains effective.';
comment on column public.planned_transfers.cancelled_at is
	'Cancellation timestamp for a transfer that had not started.';

create index planned_transfers_patient_window_idx
on public.planned_transfers (patient_id, starts_at, ends_at)
where cancelled_at is null;

create index planned_transfers_created_by_idx on public.planned_transfers (created_by);
create index planned_transfers_updated_by_idx on public.planned_transfers (updated_by);
create index planned_transfers_ended_by_idx on public.planned_transfers (ended_by)
where ended_by is not null;
create index planned_transfers_cancelled_by_idx on public.planned_transfers (cancelled_by)
where cancelled_by is not null;

alter table public.planned_transfers enable row level security;

revoke all on table public.planned_transfers from anon, authenticated, service_role;
grant select on table public.planned_transfers to authenticated;

create policy "planned_transfers_select_authorized"
on public.planned_transfers
for select
to authenticated
using (
	exists (
		select 1
		from public.patient_access
		where patient_access.patient_id = planned_transfers.patient_id
			and patient_access.user_id = (select auth.uid())
			and patient_access.revoked_at is null
	)
);

create or replace function private.save_patient_planned_transfer(
	p_transfer_id uuid,
	p_patient_id uuid,
	p_starts_at timestamptz,
	p_ends_at timestamptz,
	p_note text
)
returns table (saved_transfer_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
	caller_user_id uuid;
	action_at timestamptz := clock_timestamp();
	normalized_note text := btrim(coalesce(p_note, ''));
	target_transfer public.planned_transfers%rowtype;
	result_transfer_id uuid;
begin
	if p_patient_id is null then
		raise exception 'Patient is required.' using errcode = '22023';
	end if;

	caller_user_id := private.require_patient_admin(p_patient_id);

	if p_starts_at is null or p_ends_at is null then
		raise exception 'Transfer start and end are required.' using errcode = '22023';
	end if;

	if p_ends_at <= p_starts_at then
		raise exception 'Transfer end must be after its start.' using errcode = '22023';
	end if;

	if p_ends_at > p_starts_at + interval '24 hours' then
		raise exception 'Transfer duration cannot exceed 24 hours.' using errcode = '22023';
	end if;

	if char_length(normalized_note) not between 1 and 500 then
		raise exception 'Transfer note must contain between 1 and 500 characters.'
			using errcode = '22023';
	end if;

	perform 1
	from public.patients
	where patients.id = p_patient_id
	for update;

	if p_transfer_id is null then
		if p_starts_at < action_at - interval '5 minutes' then
			raise exception 'A new transfer cannot start in the past.' using errcode = '22023';
		end if;
	else
		select planned_transfers.*
		into target_transfer
		from public.planned_transfers
		where planned_transfers.id = p_transfer_id
			and planned_transfers.patient_id = p_patient_id
		for update;

		if target_transfer.id is null then
			raise exception 'Transfer was not found.' using errcode = 'P0002';
		end if;

		if target_transfer.cancelled_at is not null
			or target_transfer.ended_at is not null
			or target_transfer.ends_at <= action_at then
			raise exception 'Completed or cancelled transfers cannot be edited.'
				using errcode = '22023';
		end if;

		if target_transfer.starts_at <= action_at then
			if p_starts_at <> target_transfer.starts_at then
				raise exception 'An active transfer start cannot be changed.' using errcode = '22023';
			end if;

			if p_ends_at < target_transfer.ends_at then
				raise exception 'Use the finish action to end an active transfer early.'
					using errcode = '22023';
			end if;
		elsif p_starts_at < action_at - interval '5 minutes' then
			raise exception 'A scheduled transfer cannot be moved into the past.'
				using errcode = '22023';
		end if;
	end if;

	if exists (
		select 1
		from public.planned_transfers
		where planned_transfers.patient_id = p_patient_id
			and planned_transfers.cancelled_at is null
			and (p_transfer_id is null or planned_transfers.id <> p_transfer_id)
			and tstzrange(
				planned_transfers.starts_at,
				coalesce(planned_transfers.ended_at, planned_transfers.ends_at),
				'[)'
			) && tstzrange(p_starts_at, p_ends_at, '[)')
	) then
		raise exception 'Transfer windows cannot overlap for the same patient.'
			using errcode = '23P01';
	end if;

	if p_transfer_id is null then
		insert into public.planned_transfers (
			patient_id,
			starts_at,
			ends_at,
			note,
			created_by,
			updated_by
		)
		values (
			p_patient_id,
			p_starts_at,
			p_ends_at,
			normalized_note,
			caller_user_id,
			caller_user_id
		)
		returning id into result_transfer_id;
	else
		update public.planned_transfers
		set starts_at = p_starts_at,
			ends_at = p_ends_at,
			note = normalized_note,
			updated_by = caller_user_id,
			updated_at = action_at
		where id = p_transfer_id
		returning id into result_transfer_id;
	end if;

	return query select result_transfer_id;
end;
$$;

create or replace function private.cancel_patient_planned_transfer(
	p_transfer_id uuid,
	p_patient_id uuid
)
returns table (cancelled_transfer_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
	caller_user_id uuid;
	action_at timestamptz := clock_timestamp();
	result_transfer_id uuid;
begin
	caller_user_id := private.require_patient_admin(p_patient_id);

	perform 1
	from public.patients
	where patients.id = p_patient_id
	for update;

	update public.planned_transfers
	set cancelled_at = action_at,
		cancelled_by = caller_user_id,
		updated_by = caller_user_id,
		updated_at = action_at
	where id = p_transfer_id
		and patient_id = p_patient_id
		and cancelled_at is null
		and ended_at is null
		and starts_at > action_at
	returning id into result_transfer_id;

	if result_transfer_id is null then
		raise exception 'Only a scheduled transfer can be cancelled.' using errcode = '22023';
	end if;

	return query select result_transfer_id;
end;
$$;

create or replace function private.end_patient_planned_transfer(
	p_transfer_id uuid,
	p_patient_id uuid
)
returns table (ended_transfer_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
	caller_user_id uuid;
	action_at timestamptz := clock_timestamp();
	result_transfer_id uuid;
begin
	caller_user_id := private.require_patient_admin(p_patient_id);

	perform 1
	from public.patients
	where patients.id = p_patient_id
	for update;

	update public.planned_transfers
	set ended_at = action_at,
		ended_by = caller_user_id,
		updated_by = caller_user_id,
		updated_at = action_at
	where id = p_transfer_id
		and patient_id = p_patient_id
		and cancelled_at is null
		and ended_at is null
		and starts_at <= action_at
		and ends_at > action_at
	returning id into result_transfer_id;

	if result_transfer_id is null then
		raise exception 'Only an active transfer can be finished early.' using errcode = '22023';
	end if;

	return query select result_transfer_id;
end;
$$;

revoke execute on function private.save_patient_planned_transfer(
	uuid, uuid, timestamptz, timestamptz, text
) from public, anon, authenticated, service_role;
revoke execute on function private.cancel_patient_planned_transfer(uuid, uuid)
from public, anon, authenticated, service_role;
revoke execute on function private.end_patient_planned_transfer(uuid, uuid)
from public, anon, authenticated, service_role;

grant execute on function private.save_patient_planned_transfer(
	uuid, uuid, timestamptz, timestamptz, text
) to authenticated;
grant execute on function private.cancel_patient_planned_transfer(uuid, uuid) to authenticated;
grant execute on function private.end_patient_planned_transfer(uuid, uuid) to authenticated;

create or replace function public.save_patient_planned_transfer(
	p_transfer_id uuid,
	p_patient_id uuid,
	p_starts_at timestamptz,
	p_ends_at timestamptz,
	p_note text
)
returns table (saved_transfer_id uuid)
language sql
security invoker
set search_path = ''
as $$
	select *
	from private.save_patient_planned_transfer(
		p_transfer_id,
		p_patient_id,
		p_starts_at,
		p_ends_at,
		p_note
	);
$$;

create or replace function public.cancel_patient_planned_transfer(
	p_transfer_id uuid,
	p_patient_id uuid
)
returns table (cancelled_transfer_id uuid)
language sql
security invoker
set search_path = ''
as $$
	select * from private.cancel_patient_planned_transfer(p_transfer_id, p_patient_id);
$$;

create or replace function public.end_patient_planned_transfer(
	p_transfer_id uuid,
	p_patient_id uuid
)
returns table (ended_transfer_id uuid)
language sql
security invoker
set search_path = ''
as $$
	select * from private.end_patient_planned_transfer(p_transfer_id, p_patient_id);
$$;

comment on function public.save_patient_planned_transfer(
	uuid, uuid, timestamptz, timestamptz, text
) is 'Creates or edits a maximum 24-hour transfer after patient-scoped ADMIN authorization.';
comment on function public.cancel_patient_planned_transfer(uuid, uuid) is
	'Cancels a scheduled transfer after patient-scoped ADMIN authorization.';
comment on function public.end_patient_planned_transfer(uuid, uuid) is
	'Finishes an active transfer early after patient-scoped ADMIN authorization.';

revoke execute on function public.save_patient_planned_transfer(
	uuid, uuid, timestamptz, timestamptz, text
) from public, anon, service_role;
revoke execute on function public.cancel_patient_planned_transfer(uuid, uuid)
from public, anon, service_role;
revoke execute on function public.end_patient_planned_transfer(uuid, uuid)
from public, anon, service_role;

grant execute on function public.save_patient_planned_transfer(
	uuid, uuid, timestamptz, timestamptz, text
) to authenticated;
grant execute on function public.cancel_patient_planned_transfer(uuid, uuid) to authenticated;
grant execute on function public.end_patient_planned_transfer(uuid, uuid) to authenticated;

create or replace function private.process_location_alert_episode()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
	location_patient_id uuid;
	previous_location public.locations%rowtype;
	open_episode public.alert_episodes%rowtype;
	location_is_eligible boolean := (
		new.geofence_relation in ('INSIDE', 'OUTSIDE')
		and (new.accuracy_m is null or new.accuracy_m <= 100)
	);
	previous_is_eligible boolean;
	outside_pair_intersects_transfer boolean := false;
begin
	select device_assignments.patient_id
	into location_patient_id
	from public.device_assignments
	where device_assignments.id = new.device_assignment_id
	for update;

	if location_patient_id is null then
		raise exception 'Location assignment has no patient.' using errcode = '23503';
	end if;

	select locations.*
	into previous_location
	from public.locations
	where locations.device_assignment_id = new.device_assignment_id
		and locations.id <> new.id
	order by locations.recorded_at desc, locations.id desc
	limit 1;

	if found and (
		new.recorded_at < previous_location.recorded_at
		or (
			new.recorded_at = previous_location.recorded_at
			and new.id < previous_location.id
		)
	) then
		return new;
	end if;

	if not location_is_eligible or previous_location.id is null then
		return new;
	end if;

	previous_is_eligible := (
		previous_location.geofence_relation in ('INSIDE', 'OUTSIDE')
		and (
			previous_location.accuracy_m is null
			or previous_location.accuracy_m <= 100
		)
	);

	select alert_episodes.*
	into open_episode
	from public.alert_episodes
	where alert_episodes.patient_id = location_patient_id
		and alert_episodes.status = 'OPEN'
	for update;

	if open_episode.id is null then
		select exists (
			select 1
			from public.planned_transfers
			where planned_transfers.patient_id = location_patient_id
				and planned_transfers.cancelled_at is null
				and tstzrange(
					planned_transfers.starts_at,
					coalesce(planned_transfers.ended_at, planned_transfers.ends_at),
					'[)'
				) && tstzrange(
					previous_location.recorded_at,
					new.recorded_at,
					'[]'
				)
		)
		into outside_pair_intersects_transfer;

		if not outside_pair_intersects_transfer
			and new.geofence_relation = 'OUTSIDE'
			and previous_is_eligible
			and previous_location.geofence_relation = 'OUTSIDE' then
			insert into public.alert_episodes (
				patient_id,
				device_assignment_id,
				status,
				started_at,
				confirmed_at,
				first_outside_location_id,
				confirmed_by_location_id
			)
			values (
				location_patient_id,
				new.device_assignment_id,
				'OPEN',
				previous_location.recorded_at,
				new.recorded_at,
				previous_location.id,
				new.id
			)
			on conflict (patient_id) where status = 'OPEN' do nothing;
		end if;
	elsif open_episode.device_assignment_id = new.device_assignment_id
		and new.geofence_relation = 'INSIDE'
		and previous_is_eligible
		and previous_location.geofence_relation = 'INSIDE' then
		update public.alert_episodes
		set status = 'RESOLVED',
			resolved_at = new.recorded_at,
			resolved_by_location_id = new.id,
			updated_at = clock_timestamp()
		where id = open_episode.id
			and status = 'OPEN';
	end if;

	return new;
end;
$$;

comment on function private.process_location_alert_episode() is
	'Opens and resolves basic geofence episodes while planned transfers suppress only new OUTSIDE confirmations that intersect their effective window.';
