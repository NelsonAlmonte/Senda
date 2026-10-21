import { isValidEmail, normalizeEmail, safeRedirectPath } from '#lib/server/auth.js';
import { fail, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';

export const load: PageServerLoad = ({ locals, url }) => {
	if (locals.user) redirect(303, '/dashboard');

	return {
		next: safeRedirectPath(url.searchParams.get('next')),
		supabaseConfigured: locals.supabaseConfigured
	};
};

export const actions: Actions = {
	default: async ({ locals, request, url }) => {
		const formData = await request.formData();
		const email = normalizeEmail(formData.get('email'));
		const passwordValue = formData.get('password');
		const password = typeof passwordValue === 'string' ? passwordValue : '';
		const next = safeRedirectPath(url.searchParams.get('next'));
		const errors: Record<string, string> = {};

		if (!isValidEmail(email)) errors.email = 'Introduce un correo electrónico válido.';
		if (!password) errors.password = 'Introduce tu contraseña.';

		if (Object.keys(errors).length > 0) {
			return fail(400, { errors, email });
		}

		if (!locals.supabase) {
			return fail(503, {
				errors: { form: 'Supabase todavía no está configurado en este entorno.' },
				email
			});
		}

		const { error } = await locals.supabase.auth.signInWithPassword({ email, password });

		if (error) {
			return fail(400, {
				errors: {
					form: 'No pudimos iniciar sesión. Revisa tus credenciales y confirma tu correo.'
				},
				email
			});
		}

		redirect(303, next);
	}
};
