import { redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ locals, url }) => {
	if (!locals.user || !locals.supabase) {
		redirect(303, `/auth/login?next=${encodeURIComponent(url.pathname)}`);
	}

	const { data: profile, error } = await locals.supabase
		.from('profiles')
		.select('full_name')
		.eq('id', locals.user.id)
		.maybeSingle();

	return {
		profile: error ? null : profile,
		profileAvailable: !error,
		user: locals.user
	};
};
