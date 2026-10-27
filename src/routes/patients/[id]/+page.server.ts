import { readText } from '#lib/server/auth.js';
import { error as httpError, fail, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';

async function requirePatientAccess(locals: App.Locals, patientId: string) {
	if (!locals.user || !locals.supabase) redirect(303, '/auth/login');

	const { data: access, error } = await locals.supabase
		.from('patient_access')
		.select(
			'access_role, patient:patients!inner(id, first_name, last_name, group:groups!inner(id, name, type))'
		)
		.eq('patient_id', patientId)
		.eq('user_id', locals.user.id)
		.is('revoked_at', null)
		.maybeSingle();

	if (error || !access) httpError(404, 'Paciente no encontrado.');

	const patient = Array.isArray(access.patient) ? access.patient[0] : access.patient;
	if (!patient) httpError(404, 'Paciente no encontrado.');

	return {
		supabase: locals.supabase,
		accessRole: access.access_role as 'ADMIN' | 'MONITOR',
		patient
	};
}

async function requirePatientAdmin(locals: App.Locals, patientId: string) {
	const access = await requirePatientAccess(locals, patientId);
	if (access.accessRole !== 'ADMIN') {
		httpError(403, 'Solo un administrador puede editar los datos del paciente.');
	}

	return access;
}

export const load: PageServerLoad = async ({ locals, params, url }) => {
	if (!locals.user || !locals.supabase) {
		redirect(303, `/auth/login?next=${encodeURIComponent(url.pathname)}`);
	}

	const { supabase, accessRole, patient } = await requirePatientAccess(locals, params.id);
	const isAdmin = accessRole === 'ADMIN';
	const [assignmentResult, rosterResult] = await Promise.all([
		supabase
			.from('device_assignments')
			.select('id, assigned_at, device:devices!inner(id, serial_number, device_kind)')
			.eq('patient_id', params.id)
			.is('unassigned_at', null)
			.maybeSingle(),
		isAdmin ? supabase.rpc('list_patient_access', { p_patient_id: params.id }) : null
	]);

	if (assignmentResult.error) {
		httpError(500, 'No pudimos consultar el dispositivo del paciente.');
	}

	if (rosterResult?.error) {
		console.error('list_patient_access failed while loading patient administration', {
			code: rosterResult.error.code,
			message: rosterResult.error.message,
			details: rosterResult.error.details,
			hint: rosterResult.error.hint
		});
		httpError(500, 'No pudimos consultar los accesos del paciente.');
	}

	const group = Array.isArray(patient.group) ? patient.group[0] : patient.group;
	const assignment = assignmentResult.data;
	const device = assignment
		? Array.isArray(assignment.device)
			? assignment.device[0]
			: assignment.device
		: null;

	return {
		patient: {
			id: patient.id,
			firstName: patient.first_name,
			lastName: patient.last_name,
			group: group
				? {
						id: group.id,
						name: group.name,
						type: group.type
					}
				: null
		},
		accessRole,
		isAdmin,
		activeAccessCount: isAdmin ? (rosterResult?.data?.length ?? 0) : null,
		assignment:
			assignment && device
				? {
						id: assignment.id,
						assignedAt: assignment.assigned_at,
						device: {
							id: device.id,
							serialNumber: device.serial_number,
							kind: device.device_kind
						}
					}
				: null
	};
};

export const actions: Actions = {
	update: async ({ locals, params, request }) => {
		const { supabase } = await requirePatientAdmin(locals, params.id);
		const formData = await request.formData();
		const firstName = readText(formData.get('firstName'));
		const lastName = readText(formData.get('lastName'));
		const values = { firstName, lastName };
		const errors: Record<string, string> = {};

		if (firstName.length < 1 || firstName.length > 80) {
			errors.firstName = 'Escribe un nombre de 1 a 80 caracteres.';
		}

		if (lastName.length < 1 || lastName.length > 80) {
			errors.lastName = 'Escribe un apellido de 1 a 80 caracteres.';
		}

		if (Object.keys(errors).length > 0) {
			return fail(400, { action: 'update' as const, errors, values });
		}

		const { data, error } = await supabase.rpc('update_patient_admin_data', {
			p_patient_id: params.id,
			p_first_name: firstName,
			p_last_name: lastName
		});

		if (error || !data?.[0]) {
			console.error('update_patient_admin_data failed', {
				code: error?.code,
				message: error?.message,
				details: error?.details,
				hint: error?.hint
			});

			if (error?.code === '42501') {
				httpError(403, 'No tienes permiso para editar este paciente.');
			}

			return fail(400, {
				action: 'update' as const,
				errors: { form: 'No pudimos guardar los cambios. Revisa los datos e inténtalo de nuevo.' },
				values
			});
		}

		return {
			action: 'update' as const,
			successMessage: 'Los datos del paciente se actualizaron correctamente.',
			values: {
				firstName: data[0].first_name,
				lastName: data[0].last_name
			}
		};
	}
};
