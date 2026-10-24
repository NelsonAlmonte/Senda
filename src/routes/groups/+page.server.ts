import { randomUUID } from 'node:crypto';
import { readText } from '#lib/server/auth.js';
import { error as httpError, fail, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';

const groupTypes = ['FAMILY', 'CARE_CENTER'] as const;
const groupModes = ['new', 'existing'] as const;
const serialPattern = /^[A-Z0-9][A-Z0-9-]{7,63}$/;

type GroupType = (typeof groupTypes)[number];
type GroupMode = (typeof groupModes)[number];

function isGroupType(value: string): value is GroupType {
	return groupTypes.includes(value as GroupType);
}

function isGroupMode(value: string): value is GroupMode {
	return groupModes.includes(value as GroupMode);
}

function normalizeSerial(value: FormDataEntryValue | null): string {
	return readText(value).toUpperCase();
}

export const load: PageServerLoad = async ({ locals, url }) => {
	if (!locals.user || !locals.supabase) {
		redirect(303, `/auth/login?next=${encodeURIComponent(url.pathname + url.search)}`);
	}

	const { data: groups, error: groupsError } = await locals.supabase
		.from('groups')
		.select('id, name, type, created_at')
		.eq('owner_user_id', locals.user.id)
		.order('created_at', { ascending: false });

	let onboardingPatient = null;
	if (url.searchParams.get('step') === 'device') {
		const patientId = url.searchParams.get('patient');
		if (!patientId) httpError(400, 'Falta el paciente que se configurará.');

		const { data: access, error: accessError } = await locals.supabase
			.from('patient_access')
			.select(
				'access_role, patient:patients!inner(id, first_name, last_name, group:groups!inner(id, name, type))'
			)
			.eq('patient_id', patientId)
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
			.select('device:devices!inner(serial_number)')
			.eq('patient_id', patientId)
			.is('unassigned_at', null)
			.maybeSingle();

		if (assignmentError) httpError(500, 'No pudimos consultar el dispositivo del paciente.');
		const device = assignment
			? Array.isArray(assignment.device)
				? assignment.device[0]
				: assignment.device
			: null;

		onboardingPatient = {
			id: patient.id,
			firstName: patient.first_name,
			lastName: patient.last_name,
			groupName: group?.name ?? 'Grupo sin nombre',
			serialNumber: device?.serial_number ?? null
		};
	}

	const requestedMode = url.searchParams.get('mode');
	return {
		groups: groupsError ? [] : (groups ?? []),
		groupsAvailable: !groupsError,
		initialMode: requestedMode === 'new' || requestedMode === 'patient' ? requestedMode : null,
		onboardingPatient
	};
};

export const actions: Actions = {
	createPatient: async ({ locals, request }) => {
		if (!locals.user || !locals.supabase) redirect(303, '/auth/login?next=/groups');

		const formData = await request.formData();
		const groupMode = readText(formData.get('groupMode'));
		const groupId = readText(formData.get('groupId'));
		const groupName = readText(formData.get('groupName'));
		const groupType = readText(formData.get('groupType'));
		const patientFirstName = readText(formData.get('patientFirstName'));
		const patientLastName = readText(formData.get('patientLastName'));
		const errors: Record<string, string> = {};

		if (!isGroupMode(groupMode)) errors.groupMode = 'Selecciona cómo deseas continuar.';
		if (groupMode === 'existing' && !groupId) {
			errors.groupId = 'Selecciona uno de tus grupos administrados.';
		}
		if (groupMode === 'new') {
			if (!groupName) errors.groupName = 'Introduce el nombre del grupo.';
			else if (groupName.length > 120) {
				errors.groupName = 'El nombre del grupo no puede superar 120 caracteres.';
			}
			if (!isGroupType(groupType)) errors.groupType = 'Selecciona un tipo de grupo válido.';
		}

		if (!patientFirstName) errors.patientFirstName = 'Introduce el nombre del paciente.';
		else if (patientFirstName.length > 80) {
			errors.patientFirstName = 'El nombre no puede superar 80 caracteres.';
		}
		if (!patientLastName) errors.patientLastName = 'Introduce el apellido del paciente.';
		else if (patientLastName.length > 80) {
			errors.patientLastName = 'El apellido no puede superar 80 caracteres.';
		}

		const values = {
			groupMode,
			groupId,
			groupName,
			groupType,
			patientFirstName,
			patientLastName
		};

		if (Object.keys(errors).length > 0) {
			return fail(400, { stage: 'patient', errors, values });
		}

		let createdPatientId: string | undefined;
		if (groupMode === 'new') {
			const { data, error } = await locals.supabase.rpc('create_patient_onboarding', {
				p_group_name: groupName,
				p_group_type: groupType,
				p_patient_first_name: patientFirstName,
				p_patient_last_name: patientLastName
			});
			createdPatientId = data?.[0]?.created_patient_id;

			if (error || !createdPatientId) {
				return fail(400, {
					stage: 'patient',
					errors: {
						form: 'No pudimos crear el grupo y el paciente. Revisa los datos e inténtalo nuevamente.'
					},
					values
				});
			}
		} else {
			const { data: ownedGroup, error: groupError } = await locals.supabase
				.from('groups')
				.select('id')
				.eq('id', groupId)
				.eq('owner_user_id', locals.user.id)
				.maybeSingle();

			if (groupError || !ownedGroup) {
				return fail(403, {
					stage: 'patient',
					errors: { groupId: 'No puedes agregar pacientes a ese grupo.' },
					values
				});
			}

			const patientId = randomUUID();
			const { error } = await locals.supabase.from('patients').insert({
				id: patientId,
				group_id: ownedGroup.id,
				first_name: patientFirstName,
				last_name: patientLastName
			});

			if (error) {
				return fail(400, {
					stage: 'patient',
					errors: {
						form: 'No pudimos agregar el paciente al grupo. Revisa los datos e inténtalo nuevamente.'
					},
					values
				});
			}
			createdPatientId = patientId;
		}

		redirect(303, `/groups?step=device&patient=${encodeURIComponent(createdPatientId)}`);
	},
	assignDevice: async ({ locals, request }) => {
		if (!locals.user || !locals.supabase) redirect(303, '/auth/login?next=/groups');

		const formData = await request.formData();
		const patientId = readText(formData.get('patientId'));
		const serialNumber = normalizeSerial(formData.get('serialNumber'));
		const values = { serialNumber };

		if (!patientId) httpError(400, 'Falta el paciente que se configurará.');
		if (!serialPattern.test(serialNumber)) {
			return fail(400, {
				stage: 'device',
				patientId,
				errors: {
					serialNumber:
						'Introduce un serial válido de 8 a 64 caracteres usando letras, números o guiones.'
				},
				values
			});
		}

		const { error } = await locals.supabase.rpc('assign_simulated_device', {
			p_patient_id: patientId,
			p_serial_number: serialNumber
		});

		if (error) {
			let message =
				'No pudimos configurar el dispositivo. Revisa el serial e inténtalo nuevamente.';
			if (error.message.includes('Serial is not registered.')) {
				message = 'Ese serial no está registrado en el inventario simulado de Senda.';
			} else if (error.message.includes('Patient already has an active device.')) {
				message = 'Este paciente ya tiene un dispositivo activo.';
			} else if (error.message.includes('Device already has an active patient.')) {
				message = 'Ese dispositivo ya está asignado a otro paciente.';
			} else if (error.code === '42501') {
				httpError(403, 'No tienes permiso para configurar este paciente.');
			}

			return fail(400, {
				stage: 'device',
				patientId,
				errors: { form: message },
				values
			});
		}

		redirect(303, '/dashboard?configured=device');
	}
};
