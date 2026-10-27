do $$
begin
	-- This platform-level helper exists in the development project but is not
	-- created by Senda. Keep fresh/local databases compatible when it is absent.
	if to_regprocedure('public.rls_auto_enable()') is not null then
		execute 'revoke execute on function public.rls_auto_enable() '
			|| 'from public, anon, authenticated, service_role';
	end if;
end;
$$;
