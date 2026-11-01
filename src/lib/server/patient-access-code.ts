import { readText } from '#lib/server/auth.js';
import { fail, redirect, type RequestEvent } from '@sveltejs/kit';

type AcceptAccessCodeOptions = { outcome: 'redirect'; redirectTo: string } | { outcome: 'success' };

function normalizeCode(value: FormDataEntryValue | null): string {
	return readText(value).toUpperCase();
}

function requireAccessCodeSession({ locals, url }: RequestEvent) {
	if (!locals.user || !locals.supabase) {
		redirect(303, `/auth/login?next=${encodeURIComponent(url.pathname)}`);
	}

	return { supabase: locals.supabase };
}

export async function previewPatientAccessCode(event: RequestEvent) {
	const { supabase } = requireAccessCodeSession(event);
	const code = normalizeCode((await event.request.formData()).get('code'));

	if (!/^[A-F0-9]{4}-?[A-F0-9]{4}-?[A-F0-9]{4}$/.test(code)) {
		return fail(400, {
			errors: { code: 'Introduce un código válido de 12 caracteres.' },
			code
		});
	}

	const { data, error } = await supabase.rpc('preview_patient_access_code', {
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
}

export async function acceptPatientAccessCode(
	event: RequestEvent,
	options: AcceptAccessCodeOptions
) {
	const { supabase } = requireAccessCodeSession(event);
	const code = normalizeCode((await event.request.formData()).get('code'));
	const { data, error } = await supabase.rpc('accept_patient_access_code', { p_code: code });

	if (error) {
		return fail(400, {
			errors: { form: 'No pudimos aceptar el acceso. El código puede haber sido utilizado.' },
			code
		});
	}

	if (options.outcome === 'redirect') {
		redirect(303, options.redirectTo);
	}

	const acceptedPatientId = data?.[0]?.accepted_patient_id;
	let patientName = '';

	if (acceptedPatientId) {
		const { data: patient } = await supabase
			.from('patients')
			.select('first_name, last_name')
			.eq('id', acceptedPatientId)
			.maybeSingle();

		if (patient) {
			patientName = `${patient.first_name} ${patient.last_name}`.trim();
		}
	}

	return { stage: 'success', patientName };
}
