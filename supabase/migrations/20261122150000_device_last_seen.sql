-- Device connectivity, separate from location freshness.
--
-- A physical tracker keeps reporting while it has no GPS fix (it sends Wi-Fi frames and Traccar
-- repeats the last known position with its old fix time). Those forwards never create a new
-- location, so without this the PWA cannot tell "the device is alive but has no GPS" from "the
-- device is off". `last_seen_at` is the server time of the last authenticated forward from the
-- tracker. It never replaces a location, never feeds the geofence classifier and never creates
-- an alert.

alter table public.devices
	add column last_seen_at timestamptz;

comment on column public.devices.last_seen_at is
	'Server time of the last authenticated report received from the physical tracker (with or without a GPS fix). Connectivity only; not a location.';

-- Records that a registered physical tracker was just heard from. Trusted ingestion only.
-- An unknown hardware identifier is a no-op, so the call reveals nothing about the inventory.
create or replace function private.record_device_heartbeat(p_hardware_id text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
	normalized_hardware_id text := upper(btrim(coalesce(p_hardware_id, '')));
begin
	if normalized_hardware_id !~ '^[A-Z0-9][A-Z0-9-]{7,31}$' then
		raise exception 'Hardware identifier is invalid.' using errcode = '22023';
	end if;

	update public.devices
	set last_seen_at = clock_timestamp()
	from private.device_hardware_ids
	where device_hardware_ids.device_id = devices.id
		and device_hardware_ids.hardware_id = normalized_hardware_id
		and devices.device_kind = 'PHYSICAL';
end;
$$;

comment on function private.record_device_heartbeat(text) is
	'Stamps last_seen_at on the physical device that reports the given hardware identifier. Service role only.';

revoke execute on function private.record_device_heartbeat(text)
from public, anon, authenticated;
grant execute on function private.record_device_heartbeat(text) to service_role;

create or replace function public.record_device_heartbeat(p_hardware_id text)
returns void
language sql
security invoker
set search_path = ''
as $$
	select private.record_device_heartbeat(p_hardware_id);
$$;

comment on function public.record_device_heartbeat(text) is
	'Service-role wrapper used by the trusted ingestion gateway to record that a physical tracker reported.';

revoke execute on function public.record_device_heartbeat(text)
from public, anon, authenticated;
grant execute on function public.record_device_heartbeat(text) to service_role;
