import type { LocationGeofenceRelation } from '#lib/types/locations.js';

/**
 * Estado de un paciente para priorizar la atención. El orden de la lista es el orden de urgencia.
 * `UNKNOWN` significa que faltó información para decidir: nunca se presenta como "en orden".
 */
export type PatientStatusKind =
	'ALERT' | 'REVIEW' | 'STALE' | 'NO_LOCATION' | 'NO_DEVICE' | 'UNKNOWN' | 'TRANSFER' | 'OK';

export type PatientStatusInput = {
	/** Hay un episodio de salida abierto. */
	hasAlert: boolean;
	/** Hay una asignación de dispositivo activa. */
	hasDevice: boolean;
	/** Hay un traslado planificado en curso. */
	hasActiveTransfer: boolean;
	/** Vigencia de la última lectura; `null` si nunca llegó una. */
	freshness: 'FRESH' | 'STALE' | null;
	/** Clasificación de la última lectura respecto a las geocercas. */
	relation: LocationGeofenceRelation | null;
	/** Falso si alguna consulta necesaria falló: no se puede afirmar que todo está en orden. */
	dataComplete: boolean;
};
