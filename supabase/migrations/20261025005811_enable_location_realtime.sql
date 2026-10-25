do $$
begin
	if not exists (
		select 1
		from pg_publication_tables
		where pubname = 'supabase_realtime'
			and schemaname = 'public'
			and tablename = 'locations'
	) then
		alter publication supabase_realtime add table public.locations;
	end if;
end;
$$;

comment on table public.locations is
	'Immutable position readings linked to historical assignments and published through Supabase Realtime under RLS.';
