import { readText } from '#lib/server/auth.js';
import { fail, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';

function normalizeCode(value: FormDataEntryValue | null): string {
	return readText(value).toUpperCase();
}

export const load: PageServerLoad = ({ locals, url }) => {
	if (!locals.user || !locals.supabase) {
		redirect(303, `/auth/login?next=${encodeURIComponent(url.pathname)}`);
	}
	return {};
};

export const actions: Actions = {
	preview: async ({ locals, request }) => {
		if (!locals.user || !locals.supabase) redirect(303, '/auth/login?next=/access-code');
		const code = normalizeCode((await request.formData()).get('code'));

		if (!/^[A-F0-9]{4}-?[A-F0-9]{4}-?[A-F0-9]{4}$/.test(code)) {
			return fail(400, { errors: { code: 'Introduce un código válido de 12 caracteres.' }, code });
		}

		const { data, error } = await locals.supabase.rpc('preview_patient_access_code', {
			p_code: code
		});
		const preview = data?.[0];

		if (error || !preview) {
			return fail(400, {
				errors: { code: 'El código no existe, ya fue utilizado o fue escrito incorrectamente.' },
				code
			});
		}

		return {
			stage: 'preview',
			code,
			preview: {
				firstName: preview.patient_first_name,
				lastName: preview.patient_last_name,
				groupName: preview.group_name,
				groupType: preview.group_type
			}
		};
	},
	accept: async ({ locals, request }) => {
		if (!locals.user || !locals.supabase) redirect(303, '/auth/login?next=/access-code');
		const code = normalizeCode((await request.formData()).get('code'));
		const { error } = await locals.supabase.rpc('accept_patient_access_code', { p_code: code });

		if (error) {
			return fail(400, {
				errors: { form: 'No pudimos aceptar el acceso. El código puede haber sido utilizado.' },
				code
			});
		}

		redirect(303, '/dashboard?access=accepted');
	}
};
