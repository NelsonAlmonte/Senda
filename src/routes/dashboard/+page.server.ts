import { redirect } from '@sveltejs/kit';
import type { LocationGeofenceRelation } from '#lib/types/locations.js';
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
			.select(
				'access_role, patient:patients!inner(id, first_name, last_name, created_at, archived_at)'
			)
			.eq('user_id', locals.user.id)
			.is('revoked_at', null)
			.order('created_at', { referencedTable: 'patients', ascending: false })
	]);

	const authorizedPatients = (accessResult.data ?? []).flatMap((access) => {
		const patient = Array.isArray(access.patient) ? access.patient[0] : access.patient;
		if (!patient || patient.archived_at !== null) return [];

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
	const latestLocationByAssignment = new Map<
		string,
		{ recordedAt: string; relation: LocationGeofenceRelation }
	>();
	const transferEndsByPatient = new Map<string, string>();
	let devicesAvailable = true;
	let alertsAvailable = true;
	let locationsAvailable = true;
	let transfersAvailable = true;

	if (patientIds.length > 0) {
		const nowIso = new Date().toISOString();
		const [assignmentResult, alertResult, transferResult] = await Promise.all([
			locals.supabase
				.from('device_assignments')
				.select('id, patient_id')
				.in('patient_id', patientIds)
				.is('unassigned_at', null),
			locals.supabase
				.from('alert_episodes')
				.select('patient_id, confirmed_at')
				.in('patient_id', patientIds)
				.eq('status', 'OPEN'),
			// Un traslado en curso es informativo: no oculta la pérdida de señal (ver classifyPatientStatus).
			locals.supabase
				.from('planned_transfers')
				.select('patient_id, ends_at')
				.in('patient_id', patientIds)
				.is('ended_at', null)
				.is('cancelled_at', null)
				.lte('starts_at', nowIso)
				.gt('ends_at', nowIso)
		]);

		devicesAvailable = !assignmentResult.error;
		alertsAvailable = !alertResult.error;
		transfersAvailable = !transferResult.error;

		for (const transfer of transferResult.data ?? []) {
			const current = transferEndsByPatient.get(transfer.patient_id);
			if (!current || Date.parse(transfer.ends_at) > Date.parse(current)) {
				transferEndsByPatient.set(transfer.patient_id, transfer.ends_at);
			}
		}

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
				.select('device_assignment_id, recorded_at, geofence_relation')
				.in('device_assignment_id', assignmentIds);

			locationsAvailable = !locationResult.error;

			for (const location of locationResult.data ?? []) {
				latestLocationByAssignment.set(location.device_assignment_id, {
					recordedAt: location.recorded_at,
					relation: location.geofence_relation as LocationGeofenceRelation
				});
			}
		}
	}

	const patients = authorizedPatients.map((patient) => {
		const assignmentId = assignmentByPatient.get(patient.id) ?? null;

		const latest = assignmentId ? (latestLocationByAssignment.get(assignmentId) ?? null) : null;

		return {
			...patient,
			assignmentId,
			activeAlert: alertByPatient.get(patient.id) ?? null,
			latestLocationRecordedAt: latest?.recordedAt ?? null,
			latestGeofenceRelation: latest?.relation ?? null,
			activeTransferEndsAt: transferEndsByPatient.get(patient.id) ?? null
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
		transfersAvailable,
		loadedAt: Date.now()
	};
};
