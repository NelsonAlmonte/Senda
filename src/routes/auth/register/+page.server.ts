import { isValidEmail, normalizeEmail, readText, safeRedirectPath } from '#lib/server/auth.js';
import { fail, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';

export const load: PageServerLoad = ({ locals }) => {
	if (locals.user) redirect(303, '/dashboard');
	return { supabaseConfigured: locals.supabaseConfigured };
};

export const actions: Actions = {
	default: async ({ locals, request, url }) => {
		const formData = await request.formData();
		const fullName = readText(formData.get('fullName'));
		const email = normalizeEmail(formData.get('email'));
		const passwordValue = formData.get('password');
		const confirmationValue = formData.get('passwordConfirmation');
		const password = typeof passwordValue === 'string' ? passwordValue : '';
		const passwordConfirmation = typeof confirmationValue === 'string' ? confirmationValue : '';
		const errors: Record<string, string> = {};

		if (!fullName) errors.fullName = 'Introduce tu nombre.';
		else if (fullName.length > 120) errors.fullName = 'El nombre no puede superar 120 caracteres.';
		if (!isValidEmail(email)) errors.email = 'Introduce un correo electrónico válido.';
		if (password.length < 8) errors.password = 'Usa al menos 8 caracteres.';
		if (password !== passwordConfirmation)
			errors.passwordConfirmation = 'Las contraseñas no coinciden.';

		if (Object.keys(errors).length > 0) {
			return fail(400, { errors, values: { fullName, email } });
		}

		if (!locals.supabase) {
			return fail(503, {
				errors: { form: 'Supabase todavía no está configurado en este entorno.' },
				values: { fullName, email }
			});
		}

		const next = safeRedirectPath(url.searchParams.get('next'));
		const confirmationUrl = new URL('/auth/confirm', url.origin);
		confirmationUrl.searchParams.set('next', next);

		const { data, error } = await locals.supabase.auth.signUp({
			email,
			password,
			options: {
				data: { full_name: fullName },
				emailRedirectTo: confirmationUrl.toString()
			}
		});

		if (error) {
			return fail(400, {
				errors: { form: 'No pudimos crear la cuenta. Revisa los datos o inténtalo más tarde.' },
				values: { fullName, email }
			});
		}

		if (data.session) redirect(303, next);

		return {
			success: true,
			message: 'Revisa tu correo y confirma la cuenta para continuar.'
		};
	}
};
