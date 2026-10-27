import { readText } from '#lib/server/auth.js';
import { error as httpError, fail, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

type PatientAccessRosterRow = {
	access_id: string;
	display_name: string;
	access_role: string;
	relationship: string | null;
	granted_at: string;
	is_current_user: boolean;
};

async function requireAdmin(locals: App.Locals, patientId: string) {
	if (!locals.user || !locals.supabase) redirect(303, '/auth/login');

	const { data, error } = await locals.supabase
		.from('patient_access')
		.select('access_role, patient:patients!inner(id, first_name, last_name)')
		.eq('patient_id', patientId)
		.eq('user_id', locals.user.id)
		.is('revoked_at', null)
		.maybeSingle();

	if (error || !data) httpError(404, 'Paciente no encontrado.');
	if (data.access_role !== 'ADMIN') {
		httpError(403, 'Solo un administrador puede gestionar los accesos del paciente.');
	}

	const patient = Array.isArray(data.patient) ? data.patient[0] : data.patient;
	if (!patient) httpError(404, 'Paciente no encontrado.');

	return { supabase: locals.supabase, patient };
}

export const load: PageServerLoad = async ({ locals, params }) => {
	const { supabase, patient } = await requireAdmin(locals, params.id);
	const { data, error } = await supabase.rpc('list_patient_access', {
		p_patient_id: params.id
	});

	if (error) {
		console.error('list_patient_access failed', {
			code: error.code,
			message: error.message,
			details: error.details,
			hint: error.hint
		});
		httpError(500, 'No pudimos consultar los accesos del paciente.');
	}

	const accessRoster = (data ?? []) as PatientAccessRosterRow[];

	return {
		patient,
		accessRoster: accessRoster.map((access) => ({
			id: access.access_id,
			displayName: access.display_name,
			role: access.access_role as 'ADMIN' | 'MONITOR',
			relationship: access.relationship as 'FAMILY' | 'CAREGIVER' | 'OTHER' | null,
			grantedAt: access.granted_at,
			isCurrentUser: access.is_current_user
		}))
	};
};

export const actions: Actions = {
	createCode: async ({ locals, params }) => {
		const { supabase } = await requireAdmin(locals, params.id);
		const { data, error } = await supabase.rpc('create_patient_access_code', {
			p_patient_id: params.id
		});

		if (error || !data?.[0]) {
			console.error('create_patient_access_code failed', {
				code: error?.code,
				message: error?.message,
				details: error?.details,
				hint: error?.hint
			});
			return fail(400, {
				action: 'createCode' as const,
				error: 'No pudimos generar el código de acceso.'
			});
		}

		return {
			action: 'createCode' as const,
			accessCode: data[0].access_code
		};
	},
	revoke: async ({ locals, params, request }) => {
		const { supabase } = await requireAdmin(locals, params.id);
		const formData = await request.formData();
		const accessId = readText(formData.get('accessId'));

		if (!uuidPattern.test(accessId)) {
			return fail(400, {
				action: 'revoke' as const,
				error: 'El acceso seleccionado no es válido.'
			});
		}

		const { data, error } = await supabase.rpc('revoke_patient_monitor_access', {
			p_access_id: accessId
		});

		if (error || !data?.[0]) {
			console.error('revoke_patient_monitor_access failed', {
				code: error?.code,
				message: error?.message,
				details: error?.details,
				hint: error?.hint
			});

			if (error?.code === '42501') {
				httpError(403, 'No tienes permiso para revocar este acceso.');
			}

			return fail(400, {
				action: 'revoke' as const,
				error: 'No pudimos revocar el acceso seleccionado.'
			});
		}

		return {
			action: 'revoke' as const,
			successMessage: `Se revocó el acceso de ${data[0].revoked_display_name}.`
		};
	}
};
