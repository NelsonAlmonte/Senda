import { error as httpError, fail, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';

async function requireArchivedPatientAccess(locals: App.Locals, patientId: string) {
	if (!locals.user || !locals.supabase) redirect(303, '/auth/login');

	const { data: access, error } = await locals.supabase
		.from('patient_access')
		.select(
			'access_role, patient:patients!inner(id, first_name, last_name, archived_at, group:groups!inner(id, name, type))'
		)
		.eq('patient_id', patientId)
		.eq('user_id', locals.user.id)
		.is('revoked_at', null)
		.maybeSingle();

	if (error || !access) httpError(404, 'Paciente archivado no encontrado.');

	const patient = Array.isArray(access.patient) ? access.patient[0] : access.patient;
	if (!patient) httpError(404, 'Paciente archivado no encontrado.');
	if (patient.archived_at === null) redirect(303, `/patients/${patientId}`);

	return {
		supabase: locals.supabase,
		accessRole: access.access_role as 'ADMIN' | 'MONITOR',
		patient
	};
}

export const load: PageServerLoad = async ({ locals, params, url }) => {
	if (!locals.user || !locals.supabase) {
		redirect(303, `/auth/login?next=${encodeURIComponent(url.pathname)}`);
	}

	const { accessRole, patient } = await requireArchivedPatientAccess(locals, params.id);
	const group = Array.isArray(patient.group) ? patient.group[0] : patient.group;

	return {
		patient: {
			id: patient.id,
			firstName: patient.first_name,
			lastName: patient.last_name,
			archivedAt: patient.archived_at,
			group: group
				? {
						id: group.id,
						name: group.name,
						type: group.type
					}
				: null
		},
		accessRole,
		isAdmin: accessRole === 'ADMIN'
	};
};

export const actions: Actions = {
	restore: async ({ locals, params }) => {
		const { supabase, accessRole } = await requireArchivedPatientAccess(locals, params.id);
		if (accessRole !== 'ADMIN') {
			httpError(403, 'Solo un administrador puede restaurar este paciente.');
		}

		const { error } = await supabase.rpc('restore_patient', { p_patient_id: params.id });

		if (error) {
			console.error('restore_patient failed', {
				code: error.code,
				message: error.message,
				details: error.details,
				hint: error.hint
			});

			if (error.code === '42501') {
				httpError(403, 'No tienes permiso para restaurar este paciente.');
			}

			return fail(409, {
				action: 'restore' as const,
				errors: {
					restore: error.message.includes('not archived')
						? 'El paciente ya está activo.'
						: 'No pudimos restaurar el paciente. Inténtalo nuevamente.'
				}
			});
		}

		redirect(303, `/patients/${params.id}?restored=patient`);
	},
	delete: async ({ locals, params, request }) => {
		const { supabase, accessRole, patient } = await requireArchivedPatientAccess(locals, params.id);
		if (accessRole !== 'ADMIN') {
			httpError(403, 'Solo un administrador puede eliminar este paciente.');
		}

		const formData = await request.formData();
		const confirmation = String(formData.get('confirmation') ?? '').trim();
		const expectedConfirmation = `${patient.first_name} ${patient.last_name}`.trim();

		if (confirmation !== expectedConfirmation) {
			return fail(400, {
				action: 'delete' as const,
				errors: {
					confirmation: `Escribe exactamente “${expectedConfirmation}” para confirmar.`
				}
			});
		}

		const { error } = await supabase.rpc('delete_archived_patient', {
			p_patient_id: params.id
		});

		if (error) {
			console.error('delete_archived_patient failed', {
				code: error.code,
				message: error.message,
				details: error.details,
				hint: error.hint
			});

			if (error.code === '42501') {
				httpError(403, 'No tienes permiso para eliminar este paciente.');
			}

			if (error.code === 'P0002') {
				httpError(404, 'Paciente archivado no encontrado.');
			}

			return fail(409, {
				action: 'delete' as const,
				errors: {
					delete: error.message.includes('must be archived')
						? 'El paciente debe permanecer archivado antes de eliminarlo.'
						: 'No pudimos eliminar el paciente. Inténtalo nuevamente.'
				}
			});
		}

		redirect(303, '/patients/archived?deleted=patient');
	}
};
