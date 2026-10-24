import { redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ locals, url }) => {
	if (!locals.user || !locals.supabase) {
		redirect(303, `/auth/login?next=${encodeURIComponent(url.pathname)}`);
	}

	const [profileResult, accessResult] = await Promise.all([
		locals.supabase.from('profiles').select('full_name').eq('id', locals.user.id).maybeSingle(),
		locals.supabase
			.from('patient_access')
			.select(
				'access_role, patient:patients!inner(id, first_name, last_name, created_at, group:groups!inner(id, name, type))'
			)
			.eq('user_id', locals.user.id)
			.is('revoked_at', null)
			.order('created_at', { referencedTable: 'patients', ascending: false })
	]);

	const authorizedPatients = (accessResult.data ?? []).flatMap((access) => {
		const patient = Array.isArray(access.patient) ? access.patient[0] : access.patient;
		if (!patient) return [];

		const group = Array.isArray(patient.group) ? patient.group[0] : patient.group;

		return [
			{
				id: patient.id,
				firstName: patient.first_name,
				lastName: patient.last_name,
				accessRole: access.access_role,
				group: group
					? {
							id: group.id,
							name: group.name,
							type: group.type
						}
					: null
			}
		];
	});
	const patientIds = authorizedPatients.map((patient) => patient.id);
	const assignmentsByPatient = new Map<
		string,
		{ assignedAt: string; device: { id: string; serialNumber: string; kind: string } }
	>();
	let devicesAvailable = true;

	if (patientIds.length > 0) {
		const assignmentResult = await locals.supabase
			.from('device_assignments')
			.select('patient_id, assigned_at, device:devices!inner(id, serial_number, device_kind)')
			.in('patient_id', patientIds)
			.is('unassigned_at', null);

		devicesAvailable = !assignmentResult.error;

		for (const assignment of assignmentResult.data ?? []) {
			const device = Array.isArray(assignment.device) ? assignment.device[0] : assignment.device;
			if (!device) continue;

			assignmentsByPatient.set(assignment.patient_id, {
				assignedAt: assignment.assigned_at,
				device: {
					id: device.id,
					serialNumber: device.serial_number,
					kind: device.device_kind
				}
			});
		}
	}

	const patients = authorizedPatients.map((patient) => ({
		...patient,
		assignment: assignmentsByPatient.get(patient.id) ?? null
	}));

	return {
		profile: profileResult.error ? null : profileResult.data,
		profileAvailable: !profileResult.error,
		patients,
		patientsAvailable: !accessResult.error,
		devicesAvailable,
		patientCreated: url.searchParams.get('created') === 'patient',
		deviceConfigured: url.searchParams.get('configured') === 'device',
		accessAccepted: url.searchParams.get('access') === 'accepted',
		user: locals.user
	};
};
