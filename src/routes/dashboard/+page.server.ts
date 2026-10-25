import { presentLocationTime } from '#lib/server/location-presentation.js';
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
		{
			id: string;
			assignedAt: string;
			device: { id: string; serialNumber: string; kind: string };
		}
	>();
	const latestLocationsByAssignment = new Map<
		string,
		{
			latitude: number;
			longitude: number;
			accuracyM: number | null;
			recordedAt: string;
			receivedAt: string;
			source: string;
		}
	>();
	let devicesAvailable = true;
	let locationsAvailable = true;

	if (patientIds.length > 0) {
		const assignmentResult = await locals.supabase
			.from('device_assignments')
			.select('id, patient_id, assigned_at, device:devices!inner(id, serial_number, device_kind)')
			.in('patient_id', patientIds)
			.is('unassigned_at', null);

		devicesAvailable = !assignmentResult.error;

		for (const assignment of assignmentResult.data ?? []) {
			const device = Array.isArray(assignment.device) ? assignment.device[0] : assignment.device;
			if (!device) continue;

			assignmentsByPatient.set(assignment.patient_id, {
				id: assignment.id,
				assignedAt: assignment.assigned_at,
				device: {
					id: device.id,
					serialNumber: device.serial_number,
					kind: device.device_kind
				}
			});
		}

		const assignmentIds = [...assignmentsByPatient.values()].map((assignment) => assignment.id);
		if (assignmentIds.length > 0) {
			const locationResult = await locals.supabase
				.from('latest_locations')
				.select(
					'device_assignment_id, latitude, longitude, accuracy_m, recorded_at, received_at, source'
				)
				.in('device_assignment_id', assignmentIds);

			locationsAvailable = !locationResult.error;
			for (const location of locationResult.data ?? []) {
				latestLocationsByAssignment.set(location.device_assignment_id, {
					latitude: location.latitude,
					longitude: location.longitude,
					accuracyM: location.accuracy_m,
					recordedAt: location.recorded_at,
					receivedAt: location.received_at,
					source: location.source
				});
			}
		}
	}

	const now = Date.now();
	const patients = authorizedPatients.map((patient) => {
		const assignment = assignmentsByPatient.get(patient.id);
		if (!assignment) return { ...patient, assignment: null };

		const location = latestLocationsByAssignment.get(assignment.id);
		return {
			...patient,
			assignment: {
				...assignment,
				latestLocation: location
					? {
							...location,
							...presentLocationTime(location.recordedAt, now)
						}
					: null
			}
		};
	});

	return {
		profile: profileResult.error ? null : profileResult.data,
		profileAvailable: !profileResult.error,
		patients,
		patientsAvailable: !accessResult.error,
		devicesAvailable,
		locationsAvailable,
		patientCreated: url.searchParams.get('created') === 'patient',
		deviceConfigured: url.searchParams.get('configured') === 'device',
		accessAccepted: url.searchParams.get('access') === 'accepted',
		user: locals.user
	};
};
