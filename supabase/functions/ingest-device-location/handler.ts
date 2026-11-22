export type IngestOutcome =
	| 'CREATED'
	| 'DUPLICATE'
	| 'CONFLICT'
	| 'UNKNOWN_DEVICE'
	| 'NO_ACTIVE_ASSIGNMENT'
	| 'PREDATES_ASSIGNMENT';

export interface DeviceReading {
	hardwareId: string;
	eventId: string;
	latitude: number;
	longitude: number;
	accuracyM: number | null;
	recordedAt: string;
}

export interface IngestResult {
	outcome: IngestOutcome;
	locationId: number | null;
}

/** Raised by the database adapter for a reading that can never be stored (invalid data). */
export class ReadingRejectedError extends Error {}

export interface IngestDependencies {
	ingestSecret: string;
	ingest(reading: DeviceReading): Promise<IngestResult>;
	now?(): Date;
	log?(message: string): void;
	logError?(message: string, error?: unknown): void;
}

const MAX_BODY_BYTES = 16 * 1024;
const HARDWARE_ID_PATTERN = /^[A-Z0-9][A-Z0-9-]{7,31}$/;

type ParsedReading =
	| {
			kind: 'reading';
			hardwareId: string;
			latitude: number;
			longitude: number;
			accuracyM: number | null;
			recordedAt: Date;
	  }
	| { kind: 'ignored'; reason: 'NO_GPS_FIX' }
	| { kind: 'invalid'; reason: string };

function jsonResponse(body: unknown, status: number): Response {
	return Response.json(body, { status, headers: { 'Cache-Control': 'no-store' } });
}

function secretsMatch(expected: string, provided: string): boolean {
	const encoder = new TextEncoder();
	const expectedBytes = encoder.encode(expected);
	const providedBytes = encoder.encode(provided);
	const comparedLength = Math.max(expectedBytes.length, providedBytes.length);
	let difference = expectedBytes.length ^ providedBytes.length;

	for (let index = 0; index < comparedLength; index += 1) {
		difference |= (expectedBytes[index] ?? 0) ^ (providedBytes[index] ?? 0);
	}

	return difference === 0;
}

function readProvidedSecret(request: Request): string {
	const direct = request.headers.get('x-senda-ingest-secret');
	if (direct) return direct;

	const authorization = request.headers.get('authorization') ?? '';
	const match = /^Bearer\s+(.+)$/i.exec(authorization);
	return match ? match[1].trim() : '';
}

function asRecord(value: unknown): Record<string, unknown> | null {
	return value && typeof value === 'object' && !Array.isArray(value)
		? (value as Record<string, unknown>)
		: null;
}

function readFiniteNumber(value: unknown): number | null {
	if (typeof value === 'number' && Number.isFinite(value)) return value;
	if (typeof value === 'string' && value.trim() !== '' && Number.isFinite(Number(value))) {
		return Number(value);
	}
	return null;
}

function readTimestamp(value: unknown): Date | null {
	if (typeof value === 'number' && Number.isFinite(value)) {
		const date = new Date(value);
		return Number.isNaN(date.getTime()) ? null : date;
	}
	if (typeof value === 'string' && value.trim() !== '') {
		const date = new Date(value);
		return Number.isNaN(date.getTime()) ? null : date;
	}
	return null;
}

/**
 * Accepts the Traccar position forward ({ device, position }) or the flat Senda shape
 * ({ hardwareId, latitude, longitude, accuracyM, recordedAt }).
 * The Traccar JSON schema is not documented upstream and must be confirmed with a live test.
 */
export function parseDeviceReading(body: unknown): ParsedReading {
	const root = asRecord(body);
	if (!root) return { kind: 'invalid', reason: 'Body must be a JSON object.' };

	const device = asRecord(root.device);
	const position = asRecord(root.position);

	const rawHardwareId = device ? device.uniqueId : root.hardwareId;
	const source = position ?? root;

	if (position && position.valid === false) return { kind: 'ignored', reason: 'NO_GPS_FIX' };

	const hardwareId =
		typeof rawHardwareId === 'string' || typeof rawHardwareId === 'number'
			? String(rawHardwareId).trim().toUpperCase()
			: '';
	if (!HARDWARE_ID_PATTERN.test(hardwareId)) {
		return { kind: 'invalid', reason: 'Hardware identifier is missing or malformed.' };
	}

	const latitude = readFiniteNumber(source.latitude);
	const longitude = readFiniteNumber(source.longitude);
	if (latitude === null || latitude < -90 || latitude > 90) {
		return { kind: 'invalid', reason: 'Latitude is missing or out of range.' };
	}
	if (longitude === null || longitude < -180 || longitude > 180) {
		return { kind: 'invalid', reason: 'Longitude is missing or out of range.' };
	}

	const rawAccuracy = source.accuracy ?? source.accuracyM;
	let accuracyM: number | null = null;
	if (rawAccuracy !== undefined && rawAccuracy !== null) {
		accuracyM = readFiniteNumber(rawAccuracy);
		if (accuracyM === null || accuracyM < 0) {
			return { kind: 'invalid', reason: 'Accuracy is malformed.' };
		}
	}

	// The GPS fix time is when the position was captured; never fall back to server time.
	const recordedAt = readTimestamp(source.fixTime ?? source.recordedAt);
	if (!recordedAt) return { kind: 'invalid', reason: 'Fix time is missing or malformed.' };

	return {
		kind: 'reading',
		hardwareId,
		latitude,
		longitude,
		accuracyM,
		recordedAt
	};
}

/** Deterministic RFC 4122 version-5-style UUID, so a retried forward maps to the same event. */
export async function deriveEventId(
	hardwareId: string,
	recordedAt: Date,
	latitude: number,
	longitude: number
): Promise<string> {
	const material = [
		hardwareId,
		recordedAt.toISOString(),
		latitude.toFixed(7),
		longitude.toFixed(7)
	].join('|');
	const digest = new Uint8Array(
		await crypto.subtle.digest('SHA-256', new TextEncoder().encode(material))
	);
	const bytes = digest.slice(0, 16);
	bytes[6] = (bytes[6] & 0x0f) | 0x50;
	bytes[8] = (bytes[8] & 0x3f) | 0x80;

	const hex = Array.from(bytes, (byte) => byte.toString(16).padStart(2, '0')).join('');
	return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20, 32)}`;
}

export function createDeviceIngestHandler(dependencies: IngestDependencies) {
	const now = dependencies.now ?? (() => new Date());

	return async function handleRequest(request: Request): Promise<Response> {
		if (request.method !== 'POST') {
			return Response.json(
				{ error: 'Method not allowed.' },
				{ status: 405, headers: { Allow: 'POST', 'Cache-Control': 'no-store' } }
			);
		}

		if (!secretsMatch(dependencies.ingestSecret, readProvidedSecret(request))) {
			return jsonResponse({ error: 'Unauthorized.' }, 401);
		}

		const contentLength = Number(request.headers.get('content-length') ?? '0');
		if (contentLength > MAX_BODY_BYTES) return jsonResponse({ error: 'Payload too large.' }, 413);

		let rawBody: string;
		try {
			rawBody = await request.text();
		} catch {
			return jsonResponse({ error: 'Body could not be read.' }, 400);
		}
		if (new TextEncoder().encode(rawBody).length > MAX_BODY_BYTES) {
			return jsonResponse({ error: 'Payload too large.' }, 413);
		}

		let body: unknown;
		try {
			body = JSON.parse(rawBody);
		} catch {
			return jsonResponse({ error: 'Body must be valid JSON.' }, 400);
		}

		const parsed = parseDeviceReading(body);
		if (parsed.kind === 'invalid') return jsonResponse({ error: parsed.reason }, 400);
		if (parsed.kind === 'ignored') {
			dependencies.log?.('ingest outcome=IGNORED reason=NO_GPS_FIX');
			return jsonResponse({ outcome: 'IGNORED', reason: parsed.reason }, 202);
		}

		const eventId = await deriveEventId(
			parsed.hardwareId,
			parsed.recordedAt,
			parsed.latitude,
			parsed.longitude
		);
		const receivedAt = now();

		try {
			const result = await dependencies.ingest({
				hardwareId: parsed.hardwareId,
				eventId,
				latitude: parsed.latitude,
				longitude: parsed.longitude,
				accuracyM: parsed.accuracyM,
				recordedAt: parsed.recordedAt.toISOString()
			});

			// Timing only: the hardware identifier and coordinates are never logged.
			dependencies.log?.(
				`ingest outcome=${result.outcome} lag_ms=${receivedAt.getTime() - parsed.recordedAt.getTime()}`
			);

			// Permanent, non-retryable outcomes are acknowledged so Traccar does not retry them.
			const status =
				result.outcome === 'CREATED' ? 201 : result.outcome === 'DUPLICATE' ? 200 : 202;
			return jsonResponse(
				{
					outcome: result.outcome,
					locationId: result.locationId,
					receivedAt: receivedAt.toISOString()
				},
				status
			);
		} catch (error) {
			if (error instanceof ReadingRejectedError) {
				dependencies.log?.('ingest outcome=REJECTED');
				return jsonResponse({ outcome: 'REJECTED' }, 202);
			}

			dependencies.logError?.('Device reading could not be persisted.', error);
			return jsonResponse({ error: 'Reading could not be persisted.' }, 500);
		}
	};
}
