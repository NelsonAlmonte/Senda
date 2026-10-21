import type { LayoutServerLoad } from './$types';

export const load: LayoutServerLoad = ({ locals }) => ({
	supabaseConfigured: locals.supabaseConfigured,
	user: locals.user
});
