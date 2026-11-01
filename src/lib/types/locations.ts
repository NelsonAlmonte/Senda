export type LocationGeofenceRelation =
	'NOT_EVALUATED' | 'NO_ACTIVE_ZONE' | 'INSIDE' | 'OUTSIDE' | 'UNCERTAIN';

export type GeofenceAlertEpisodeStatus = 'OPEN' | 'RESOLVED';

export type GeofenceRelationPresentation = {
	title: string;
	description: string;
	tone: 'positive' | 'warning' | 'neutral';
};

export type LocationRealtimeRow = {
	id: number;
	device_assignment_id: string;
	event_id: string;
	latitude: number;
	longitude: number;
	accuracy_m: number | null;
	recorded_at: string;
	received_at: string;
	source: string;
	geofence_relation: LocationGeofenceRelation;
	matched_safe_zone_id: string | null;
	distance_to_boundary_m: number | null;
	effective_tolerance_m: number | null;
	geofence_evaluated_at: string | null;
};

export type LocationRealtimeState = 'CONNECTING' | 'CONNECTED' | 'ERROR';

export type LocationAlertEpisodeRealtimeRow = {
	id: string;
	patient_id: string;
	device_assignment_id: string;
	status: GeofenceAlertEpisodeStatus;
	started_at: string;
	confirmed_at: string;
	resolved_at: string | null;
	first_outside_location_id: number;
	confirmed_by_location_id: number;
	resolved_by_location_id: number | null;
	created_at: string;
	updated_at: string;
};
