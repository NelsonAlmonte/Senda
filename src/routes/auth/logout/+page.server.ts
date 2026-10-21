import { redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';

export const load: PageServerLoad = () => redirect(303, '/');

export const actions: Actions = {
	default: async ({ locals }) => {
		if (locals.supabase) await locals.supabase.auth.signOut({ scope: 'local' });
		locals.user = null;
		redirect(303, '/auth/login');
	}
};
