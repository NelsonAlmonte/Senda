import { readText } from '#lib/server/auth.js';
import { error as httpError, fail, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';

const serialPattern = /^[A-Z0-9][A-Z0-9-]{7,63}$/;

function normalizeSerial(value: FormDataEntryValue | null): string {
	return readText(value).toUpperCase();
}

export const load: PageServerLoad = async ({ locals, params, url }) => {
	if (!locals.user || !locals.supabase) {
		redirect(303, `/auth/login?next=${encodeURIComponent(url.pathname + url.search)}`);
	}

	const { data: access, error: accessError } = await locals.supabase
		.from('patient_access')
		.select(
			'access_role, patient:patients!inner(id, first_name, last_name, group:groups!inner(id, name, type))'
		)
		.eq('patient_id', params.id)
		.eq('user_id', locals.user.id)
		.is('revoked_at', null)
		.maybeSingle();

	if (accessError || !access) httpError(404, 'Paciente no encontrado.');
	if (access.access_role !== 'ADMIN') {
		httpError(403, 'Solo un administrador del paciente puede configurar su dispositivo.');
	}

	const patient = Array.isArray(access.patient) ? access.patient[0] : access.patient;
	if (!patient) httpError(404, 'Paciente no encontrado.');

	const group = Array.isArray(patient.group) ? patient.group[0] : patient.group;
	const { data: assignment, error: assignmentError } = await locals.supabase
		.from('device_assignments')
		.select('id, assigned_at, device:devices!inner(id, serial_number, device_kind)')
		.eq('patient_id', params.id)
		.is('unassigned_at', null)
		.maybeSingle();

	if (assignmentError) httpError(500, 'No pudimos consultar el dispositivo del paciente.');

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
			groupName: group?.name ?? null,
			groupType: group?.type ?? null
		},
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
				: null,
		onboarding: url.searchParams.get('onboarding') === '1'
	};
};

export const actions: Actions = {
	default: async ({ locals, params, request }) => {
		if (!locals.user || !locals.supabase) {
			redirect(303, `/auth/login?next=/patients/${params.id}/device`);
		}

		const formData = await request.formData();
		const serialNumber = normalizeSerial(formData.get('serialNumber'));
		const values = { serialNumber };

		if (!serialPattern.test(serialNumber)) {
			return fail(400, {
				errors: {
					serialNumber:
						'Introduce un serial válido de 8 a 64 caracteres usando letras, números o guiones.'
				},
				values
			});
		}

		const { error } = await locals.supabase.rpc('assign_simulated_device', {
			p_patient_id: params.id,
			p_serial_number: serialNumber
		});

		if (error) {
			if (error.message.includes('Serial is not registered.')) {
				return fail(400, {
					errors: {
						serialNumber: 'Ese serial no está registrado en el inventario simulado de Senda.'
					},
					values
				});
			}

			if (error.message.includes('Patient already has an active device.')) {
				return fail(409, {
					errors: { form: 'Este paciente ya tiene un dispositivo activo.' },
					values
				});
			}

			if (error.message.includes('Device already has an active patient.')) {
				return fail(409, {
					errors: { form: 'Ese dispositivo ya está asignado a otro paciente.' },
					values
				});
			}

			if (error.code === '42501')
				httpError(403, 'No tienes permiso para configurar este paciente.');

			return fail(400, {
				errors: {
					form: 'No pudimos configurar el dispositivo. Revisa el serial e inténtalo nuevamente.'
				},
				values
			});
		}

		redirect(303, '/patients?configured=device');
	}
};
