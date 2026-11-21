import type { PatientStatusInput, PatientStatusKind } from '#lib/types/patient-status.js';

/** Menor número = más urgente. */
const statusRank: Record<PatientStatusKind, number> = {
	ALERT: 0,
	REVIEW: 1,
	STALE: 2,
	NO_LOCATION: 3,
	NO_DEVICE: 4,
	UNKNOWN: 5,
	TRANSFER: 6,
	OK: 7
};

export function rankPatientStatus(kind: PatientStatusKind): number {
	return statusRank[kind];
}

/** Estados que exigen que alguien haga algo. */
export function needsAttention(kind: PatientStatusKind): boolean {
	return statusRank[kind] <= statusRank.NO_DEVICE;
}

/**
 * Clasifica a un paciente. La salida confirmada gana siempre. "En orden" solo se concede con una
 * lectura reciente clasificada dentro de una zona; si falta cualquier dato, el resultado es
 * `UNKNOWN` o un estado de atención, nunca `OK`.
 */
export function classifyPatientStatus(input: PatientStatusInput): PatientStatusKind {
	if (input.hasAlert) return 'ALERT';
	if (!input.hasDevice) return input.dataComplete ? 'NO_DEVICE' : 'UNKNOWN';
	if (input.freshness === null) return input.dataComplete ? 'NO_LOCATION' : 'UNKNOWN';
	if (input.freshness === 'STALE') return 'STALE';
	if (!input.dataComplete) return 'UNKNOWN';
	if (input.hasActiveTransfer) return 'TRANSFER';

	return input.relation === 'INSIDE' ? 'OK' : 'REVIEW';
}
