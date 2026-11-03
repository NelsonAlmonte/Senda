export type MapLocationUpdate = {
	latitude: number;
	longitude: number;
	accuracyM: number | null;
	patientName: string;
	historySegments: MapHistorySegment[];
	panToLocation?: boolean;
};

export type MapHistoryPoint = {
	latitude: number;
	longitude: number;
};

export type MapHistorySegment = MapHistoryPoint[];

export type EpisodeRoutePoint = {
	id: number;
	latitude: number;
	longitude: number;
	recordedAt: string;
};

export type EpisodeRouteSegment = EpisodeRoutePoint[];

export type MapSafeZone = {
	id: string;
	name: string;
	centerLatitude: number;
	centerLongitude: number;
	radiusM: number;
};

export type MapLocationUpdater = (location: MapLocationUpdate) => void;

export type MapManualLocationPoint = {
	latitude: number;
	longitude: number;
};

export type PatientLocationMapController = {
	updateLocation: MapLocationUpdater;
	setManualLocationMode: (enabled: boolean) => void;
	setManualLocationPoint: (point: MapManualLocationPoint | null) => void;
};

export type SafeZoneMapItem = {
	id: string;
	name: string;
	centerLatitude: number;
	centerLongitude: number;
	radiusM: number;
	isActive: boolean;
};

export type SafeZoneDraft = {
	centerLatitude: number;
	centerLongitude: number;
	radiusM: number;
};

export type SafeZoneEditorMapController = {
	setZones: (zones: SafeZoneMapItem[], selectedZoneId: string | null) => void;
	setDraft: (draft: SafeZoneDraft | null) => void;
	setSelectionMode: (enabled: boolean) => void;
	fitDraft: () => void;
};
