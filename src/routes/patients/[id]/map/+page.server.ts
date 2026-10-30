import { SENDA_ENABLE_MANUAL_LOCATION_SIMULATOR } from '$app/env/private';
import { presentLocationTime, type LocationGeofenceRelation } from '#lib/locations/presentation.js';
import { error as httpError, fail, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';

function parseCoordinate(value: FormDataEntryValue | null): number | null {
	if (typeof value !== 'string' || value.trim() === '') return null;

	const coordinate = Number(value);
	return Number.isFinite(coordinate) ? coordinate : null;
}

export const load: PageServerLoad = async ({ depends, locals, params, url }) => {
	if (!locals.user || !locals.supabase) {
		redirect(303, `/auth/login?next=${encodeURIComponent(url.pathname)}`);
	}

	depends('senda:patient-alerts');

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
	const [assignmentResult, safeZonesResult, alertEpisodesResult] = await Promise.all([
		locals.supabase
			.from('device_assignments')
			.select('id, assigned_at, unassigned_at, device:devices!inner(id, device_kind)')
			.eq('patient_id', params.id)
			.order('assigned_at', { ascending: true }),
		locals.supabase
			.from('safe_zones')
			.select('id, name, center_latitude, center_longitude, radius_m')
			.eq('patient_id', params.id)
			.eq('is_active', true)
			.is('archived_at', null)
			.order('name', { ascending: true }),
		locals.supabase
			.from('alert_episodes')
			.select(
				'id, patient_id, device_assignment_id, status, started_at, confirmed_at, resolved_at, first_outside_location_id, confirmed_by_location_id, resolved_by_location_id, created_at, updated_at'
			)
			.eq('patient_id', params.id)
			.order('confirmed_at', { ascending: false })
			.limit(5)
	]);
	const { data: assignments, error: assignmentError } = assignmentResult;

	if (assignmentError) httpError(500, 'No pudimos consultar el dispositivo del paciente.');

	const assignment = assignments?.find((candidate) => candidate.unassigned_at === null) ?? null;
	const device = assignment
		? Array.isArray(assignment.device)
			? assignment.device[0]
			: assignment.device
		: null;
	const safeZones = (safeZonesResult.data ?? []).map((zone) => ({
		id: zone.id,
		name: zone.name,
		centerLatitude: zone.center_latitude,
		centerLongitude: zone.center_longitude,
		radiusM: zone.radius_m
	}));
	const alertEpisodes = (alertEpisodesResult.data ?? []).map((episode) => ({
		id: episode.id,
		patientId: episode.patient_id,
		deviceAssignmentId: episode.device_assignment_id,
		status: episode.status as 'OPEN' | 'RESOLVED',
		startedAt: episode.started_at,
		confirmedAt: episode.confirmed_at,
		resolvedAt: episode.resolved_at,
		firstOutsideLocationId: episode.first_outside_location_id,
		confirmedByLocationId: episode.confirmed_by_location_id,
		resolvedByLocationId: episode.resolved_by_location_id,
		createdAt: episode.created_at,
		updatedAt: episode.updated_at
	}));

	let locationsAvailable = true;
	let latestLocation: {
		id: number;
		latitude: number;
		longitude: number;
		accuracyM: number | null;
		recordedAt: string;
		receivedAt: string;
		source: string;
		geofenceRelation: LocationGeofenceRelation;
		matchedSafeZoneId: string | null;
		distanceToBoundaryM: number | null;
		effectiveToleranceM: number | null;
		geofenceEvaluatedAt: string | null;
		freshness: 'FRESH' | 'STALE';
		ageLabel: string;
		recordedAtLabel: string;
	} | null = null;
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
			.select(
				'id, latitude, longitude, accuracy_m, recorded_at, received_at, source, geofence_relation, matched_safe_zone_id, distance_to_boundary_m, effective_tolerance_m, geofence_evaluated_at'
			)
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
				geofenceRelation: locationResult.data.geofence_relation as LocationGeofenceRelation,
				matchedSafeZoneId: locationResult.data.matched_safe_zone_id,
				distanceToBoundaryM: locationResult.data.distance_to_boundary_m,
				effectiveToleranceM: locationResult.data.effective_tolerance_m,
				geofenceEvaluatedAt: locationResult.data.geofence_evaluated_at,
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
							kind: device.device_kind
						}
					}
				: null,
		latestLocation,
		locationsAvailable,
		safeZones,
		safeZonesAvailable: !safeZonesResult.error,
		alertEpisodes,
		alertEpisodesAvailable: !alertEpisodesResult.error,
		locationHistory,
		manualLocationEnabled:
			SENDA_ENABLE_MANUAL_LOCATION_SIMULATOR &&
			access.access_role === 'ADMIN' &&
			device?.device_kind === 'SIMULATED'
	};
};

export const actions: Actions = {
	saveManualLocation: async ({ locals, params, request }) => {
		if (!locals.user || !locals.supabase) {
			redirect(303, `/auth/login?next=/patients/${params.id}/map`);
		}

		if (!SENDA_ENABLE_MANUAL_LOCATION_SIMULATOR) {
			httpError(404, 'La ubicación manual no está habilitada en este entorno.');
		}

		const formData = await request.formData();
		const latitude = parseCoordinate(formData.get('latitude'));
		const longitude = parseCoordinate(formData.get('longitude'));

		if (latitude === null || latitude < -90 || latitude > 90) {
			return fail(400, {
				message: 'Selecciona una ubicación válida en el mapa.'
			});
		}

		if (longitude === null || longitude < -180 || longitude > 180) {
			return fail(400, {
				message: 'Selecciona una ubicación válida en el mapa.'
			});
		}

		const { data: access, error: accessError } = await locals.supabase
			.from('patient_access')
			.select('access_role')
			.eq('patient_id', params.id)
			.eq('user_id', locals.user.id)
			.is('revoked_at', null)
			.maybeSingle();

		if (accessError) {
			return fail(500, {
				message: 'No pudimos verificar tu acceso. Inténtalo nuevamente.'
			});
		}

		if (access?.access_role !== 'ADMIN') {
			httpError(403, 'Solo un administrador del paciente puede registrar ubicaciones manuales.');
		}

		const { error } = await locals.supabase.rpc('ingest_simulated_location', {
			p_patient_id: params.id,
			p_event_id: crypto.randomUUID(),
			p_latitude: latitude,
			p_longitude: longitude,
			p_accuracy_m: null,
			p_recorded_at: new Date().toISOString(),
			p_source: 'MANUAL'
		});

		if (error) {
			if (error.code === '42501') {
				httpError(403, 'No tienes permiso para registrar ubicaciones manuales de este paciente.');
			}

			if (error.message.includes('Patient has no active simulated device.')) {
				return fail(409, {
					message: 'El paciente necesita un dispositivo activo antes de registrar ubicaciones.'
				});
			}

			return fail(400, {
				message: 'No pudimos guardar la ubicación. Revisa el punto e inténtalo nuevamente.'
			});
		}

		return {
			success: true,
			message: 'Ubicación guardada. El mapa se actualizará automáticamente.'
		};
	}
};
