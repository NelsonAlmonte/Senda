import { redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ depends, locals, url }) => {
	if (!locals.user || !locals.supabase) {
		redirect(303, `/auth/login?next=${encodeURIComponent(url.pathname)}`);
	}

	depends('senda:patient-alerts');
	depends('senda:dashboard-attention');

	const [profileResult, accessResult] = await Promise.all([
		locals.supabase.from('profiles').select('full_name').eq('id', locals.user.id).maybeSingle(),
		locals.supabase
			.from('patient_access')
			.select('access_role, patient:patients!inner(id, first_name, last_name, created_at)')
			.eq('user_id', locals.user.id)
			.is('revoked_at', null)
			.order('created_at', { referencedTable: 'patients', ascending: false })
	]);

	const authorizedPatients = (accessResult.data ?? []).flatMap((access) => {
		const patient = Array.isArray(access.patient) ? access.patient[0] : access.patient;
		if (!patient) return [];

		return [
			{
				id: patient.id,
				firstName: patient.first_name,
				lastName: patient.last_name,
				accessRole: access.access_role as 'ADMIN' | 'MONITOR'
			}
		];
	});

	const patientIds = authorizedPatients.map((patient) => patient.id);
	const assignmentByPatient = new Map<string, string>();
	const alertByPatient = new Map<string, { confirmedAt: string }>();
	const latestLocationByAssignment = new Map<string, string>();
	let devicesAvailable = true;
	let alertsAvailable = true;
	let locationsAvailable = true;

	if (patientIds.length > 0) {
		const [assignmentResult, alertResult] = await Promise.all([
			locals.supabase
				.from('device_assignments')
				.select('id, patient_id')
				.in('patient_id', patientIds)
				.is('unassigned_at', null),
			locals.supabase
				.from('alert_episodes')
				.select('patient_id, confirmed_at')
				.in('patient_id', patientIds)
				.eq('status', 'OPEN')
		]);

		devicesAvailable = !assignmentResult.error;
		alertsAvailable = !alertResult.error;

		for (const assignment of assignmentResult.data ?? []) {
			assignmentByPatient.set(assignment.patient_id, assignment.id);
		}

		for (const episode of alertResult.data ?? []) {
			alertByPatient.set(episode.patient_id, { confirmedAt: episode.confirmed_at });
		}

		const assignmentIds = [...assignmentByPatient.values()];
		if (assignmentIds.length > 0) {
			const locationResult = await locals.supabase
				.from('latest_locations')
				.select('device_assignment_id, recorded_at')
				.in('device_assignment_id', assignmentIds);

			locationsAvailable = !locationResult.error;

			for (const location of locationResult.data ?? []) {
				latestLocationByAssignment.set(location.device_assignment_id, location.recorded_at);
			}
		}
	}

	const patients = authorizedPatients.map((patient) => {
		const assignmentId = assignmentByPatient.get(patient.id) ?? null;

		return {
			...patient,
			assignmentId,
			activeAlert: alertByPatient.get(patient.id) ?? null,
			latestLocationRecordedAt: assignmentId
				? (latestLocationByAssignment.get(assignmentId) ?? null)
				: null
		};
	});

	return {
		profile: profileResult.error ? null : profileResult.data,
		user: { email: locals.user.email },
		patients,
		patientsAvailable: !accessResult.error,
		devicesAvailable,
		alertsAvailable,
		locationsAvailable,
		loadedAt: Date.now()
	};
};
