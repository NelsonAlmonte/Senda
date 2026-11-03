import { error as httpError, redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

const MAX_ROUTE_POINTS = 500;
const EDGE_ROUTE_POINTS = MAX_ROUTE_POINTS / 2;
const INITIAL_FETCH_LIMIT = MAX_ROUTE_POINTS + 1;

type EpisodeBoundary = {
	startedAt: string;
	firstOutsideLocationId: number;
	resolvedAt: string | null;
	resolvedByLocationId: number | null;
};

type LocationRow = {
	id: number;
	latitude: number;
	longitude: number;
	recorded_at: string;
};

function compareLocationToBoundary(location: LocationRow, recordedAt: string, id: number): number {
	const timeDifference = Date.parse(location.recorded_at) - Date.parse(recordedAt);
	return timeDifference === 0 ? location.id - id : timeDifference;
}

function isInsideEpisode(location: LocationRow, boundary: EpisodeBoundary): boolean {
	if (
		compareLocationToBoundary(location, boundary.startedAt, boundary.firstOutsideLocationId) < 0
	) {
		return false;
	}

	if (
		boundary.resolvedAt &&
		boundary.resolvedByLocationId !== null &&
		compareLocationToBoundary(location, boundary.resolvedAt, boundary.resolvedByLocationId) > 0
	) {
		return false;
	}

	return true;
}

function presentLocation(location: LocationRow) {
	return {
		id: location.id,
		latitude: location.latitude,
		longitude: location.longitude,
		recordedAt: location.recorded_at
	};
}

export const load: PageServerLoad = async ({ depends, locals, params, url }) => {
	if (!locals.user || !locals.supabase) {
		redirect(303, `/auth/login?next=${encodeURIComponent(url.pathname)}`);
	}

	depends('senda:episode-route');
	depends('senda:patient-alerts');

	const { data: access, error: accessError } = await locals.supabase
		.from('patient_access')
		.select('access_role, patient:patients!inner(id, first_name, last_name)')
		.eq('patient_id', params.id)
		.eq('user_id', locals.user.id)
		.is('revoked_at', null)
		.maybeSingle();

	if (accessError) httpError(500, 'No pudimos verificar tu acceso al paciente.');
	if (!access) httpError(404, 'Paciente no encontrado.');

	const patient = Array.isArray(access.patient) ? access.patient[0] : access.patient;
	if (!patient) httpError(404, 'Paciente no encontrado.');

	const { data: episode, error: episodeError } = await locals.supabase
		.from('alert_episodes')
		.select(
			'id, patient_id, device_assignment_id, status, started_at, confirmed_at, resolved_at, first_outside_location_id, confirmed_by_location_id, resolved_by_location_id, updated_at'
		)
		.eq('id', params.episodeId)
		.eq('patient_id', params.id)
		.maybeSingle();

	if (episodeError) httpError(500, 'No pudimos consultar el episodio.');
	if (!episode) httpError(404, 'Episodio no encontrado.');

	const { data: episodeAssignment, error: assignmentError } = await locals.supabase
		.from('device_assignments')
		.select('id')
		.eq('id', episode.device_assignment_id)
		.eq('patient_id', params.id)
		.maybeSingle();

	if (assignmentError) httpError(500, 'No pudimos verificar la asignación del episodio.');
	if (!episodeAssignment) httpError(500, 'La asignación histórica del episodio no es válida.');

	const boundary: EpisodeBoundary = {
		startedAt: episode.started_at,
		firstOutsideLocationId: episode.first_outside_location_id,
		resolvedAt: episode.resolved_at,
		resolvedByLocationId: episode.resolved_by_location_id
	};

	let firstLocationsQuery = locals.supabase
		.from('locations')
		.select('id, latitude, longitude, recorded_at', { count: 'exact' })
		.eq('device_assignment_id', episodeAssignment.id)
		.gte('recorded_at', episode.started_at);

	if (episode.resolved_at) {
		firstLocationsQuery = firstLocationsQuery.lte('recorded_at', episode.resolved_at);
	}

	const firstLocationsResult = await firstLocationsQuery
		.order('recorded_at', { ascending: true })
		.order('id', { ascending: true })
		.limit(INITIAL_FETCH_LIMIT);

	if (firstLocationsResult.error) {
		httpError(500, 'No pudimos consultar el recorrido del episodio.');
	}

	const firstRows = (firstLocationsResult.data ?? []) as LocationRow[];
	const eligibleFirstRows = firstRows.filter((location) => isInsideEpisode(location, boundary));
	const hasUnfetchedRows = (firstLocationsResult.count ?? firstRows.length) > firstRows.length;
	const routeTruncated = hasUnfetchedRows || eligibleFirstRows.length > MAX_ROUTE_POINTS;

	let routeRows = eligibleFirstRows.slice(0, MAX_ROUTE_POINTS);
	let latestRows: LocationRow[] = [];

	if (routeTruncated) {
		let latestLocationsQuery = locals.supabase
			.from('locations')
			.select('id, latitude, longitude, recorded_at')
			.eq('device_assignment_id', episodeAssignment.id)
			.gte('recorded_at', episode.started_at);

		if (episode.resolved_at) {
			latestLocationsQuery = latestLocationsQuery.lte('recorded_at', episode.resolved_at);
		}

		const latestLocationsResult = await latestLocationsQuery
			.order('recorded_at', { ascending: false })
			.order('id', { ascending: false })
			.limit(INITIAL_FETCH_LIMIT);

		if (latestLocationsResult.error) {
			httpError(500, 'No pudimos completar el recorrido del episodio.');
		}

		latestRows = ((latestLocationsResult.data ?? []) as LocationRow[])
			.filter((location) => isInsideEpisode(location, boundary))
			.slice(0, EDGE_ROUTE_POINTS)
			.reverse();
		routeRows = eligibleFirstRows.slice(0, EDGE_ROUTE_POINTS);
	}

	const firstSegment = routeRows.map(presentLocation);
	const firstSegmentIds = new Set(firstSegment.map((location) => location.id));
	const latestSegment = latestRows
		.filter((location) => !firstSegmentIds.has(location.id))
		.map(presentLocation);
	const routeSegments = [firstSegment, latestSegment].filter((segment) => segment.length > 0);
	const displayedPointCount = routeSegments.reduce((total, segment) => total + segment.length, 0);

	return {
		patient: {
			id: patient.id,
			firstName: patient.first_name,
			lastName: patient.last_name,
			accessRole: access.access_role as 'ADMIN' | 'MONITOR'
		},
		episode: {
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
			updatedAt: episode.updated_at
		},
		routeSegments,
		displayedPointCount,
		routeTruncated
	};
};
