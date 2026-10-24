create or replace function private.is_group_owner(p_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
	select exists (
		select 1
		from public.groups
		where groups.id = p_group_id
			and groups.owner_user_id = (select auth.uid())
	);
$$;

comment on function private.is_group_owner(uuid) is
	'Checks group ownership without recursively evaluating cross-table RLS policies.';

revoke execute on function private.is_group_owner(uuid)
from public, anon, authenticated, service_role;

grant execute on function private.is_group_owner(uuid)
to authenticated;

drop policy "patients_insert_into_owned_group" on public.patients;

create policy "patients_insert_into_owned_group"
on public.patients
for insert
to authenticated
with check ((select private.is_group_owner(group_id)));
