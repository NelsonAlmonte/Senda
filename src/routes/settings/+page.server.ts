import { readText } from '#lib/server/auth.js';
import { fail, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ locals, url }) => {
	if (!locals.user || !locals.supabase)
		redirect(303, `/auth/login?next=${encodeURIComponent(url.pathname)}`);

	const { data: profile, error } = await locals.supabase
		.from('profiles')
		.select('full_name, created_at, updated_at')
		.eq('id', locals.user.id)
		.maybeSingle();

	return { profile: error ? null : profile, user: locals.user };
};

export const actions: Actions = {
	default: async ({ locals, request }) => {
		if (!locals.user || !locals.supabase) redirect(303, '/auth/login?next=/settings');

		const formData = await request.formData();
		const fullName = readText(formData.get('fullName'));

		if (!fullName) return fail(400, { error: 'Introduce tu nombre.', fullName });
		if (fullName.length > 120)
			return fail(400, { error: 'El nombre no puede superar 120 caracteres.', fullName });

		const { error } = await locals.supabase
			.from('profiles')
			.update({ full_name: fullName })
			.eq('id', locals.user.id);

		if (error) return fail(400, { error: 'No pudimos actualizar el perfil.', fullName });
		return { success: true, message: 'Perfil actualizado.' };
	}
};
