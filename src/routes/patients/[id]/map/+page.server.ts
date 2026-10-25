import { presentLocationTime } from '#lib/locations/presentation.js';
import { error as httpError, redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ locals, params, url }) => {
	if (!locals.user || !locals.supabase) {
		redirect(303, `/auth/login?next=${encodeURIComponent(url.pathname)}`);
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

	const patient = Array.isArray(access.patient) ? access.patient[0] : access.patient;
	if (!patient) httpError(404, 'Paciente no encontrado.');

	const group = Array.isArray(patient.group) ? patient.group[0] : patient.group;
	const { data: assignments, error: assignmentError } = await locals.supabase
		.from('device_assignments')
		.select('id, assigned_at, unassigned_at, device:devices!inner(id, serial_number, device_kind)')
		.eq('patient_id', params.id)
		.order('assigned_at', { ascending: true });

	if (assignmentError) httpError(500, 'No pudimos consultar el dispositivo del paciente.');

	const assignment = assignments?.find((candidate) => candidate.unassigned_at === null) ?? null;
	const device = assignment
		? Array.isArray(assignment.device)
			? assignment.device[0]
			: assignment.device
		: null;

	let locationsAvailable = true;
	let latestLocation: {
		id: number;
		latitude: number;
		longitude: number;
		accuracyM: number | null;
		recordedAt: string;
		receivedAt: string;
		source: string;
		freshness: 'FRESH' | 'STALE';
		ageLabel: string;
		recordedAtLabel: string;
	} | null = null;
	let historyAvailable = true;
	let locationHistory: Array<{
		id: number;
		deviceAssignmentId: string;
		latitude: number;
		longitude: number;
		recordedAt: string;
		recordedAtLabel: string;
	}> = [];

	const assignmentIds = assignments?.map((candidate) => candidate.id) ?? [];
	if (assignmentIds.length > 0) {
		const historyResult = await locals.supabase
			.from('locations')
			.select('id, device_assignment_id, latitude, longitude, recorded_at')
			.in('device_assignment_id', assignmentIds)
			.order('recorded_at', { ascending: false })
			.order('id', { ascending: false })
			.limit(200);

		historyAvailable = !historyResult.error;
		if (historyResult.data) {
			locationHistory = historyResult.data
				.map((location) => ({
					id: location.id,
					deviceAssignmentId: location.device_assignment_id,
					latitude: location.latitude,
					longitude: location.longitude,
					recordedAt: location.recorded_at,
					recordedAtLabel: presentLocationTime(location.recorded_at).recordedAtLabel
				}))
				.reverse();
		}
	}

	if (assignment && device) {
		const locationResult = await locals.supabase
			.from('latest_locations')
			.select('id, latitude, longitude, accuracy_m, recorded_at, received_at, source')
			.eq('device_assignment_id', assignment.id)
			.maybeSingle();

		locationsAvailable = !locationResult.error;
		if (locationResult.data) {
			latestLocation = {
				id: locationResult.data.id,
				latitude: locationResult.data.latitude,
				longitude: locationResult.data.longitude,
				accuracyM: locationResult.data.accuracy_m,
				recordedAt: locationResult.data.recorded_at,
				receivedAt: locationResult.data.received_at,
				source: locationResult.data.source,
				...presentLocationTime(locationResult.data.recorded_at)
			};
		}
	}

	return {
		patient: {
			id: patient.id,
			firstName: patient.first_name,
			lastName: patient.last_name,
			groupName: group?.name ?? null,
			groupType: group?.type ?? null,
			accessRole: access.access_role
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
		latestLocation,
		locationsAvailable,
		locationHistory,
		historyAvailable
	};
};
