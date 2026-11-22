import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import {
	createDeviceIngestHandler,
	deriveEventId,
	parseDeviceReading,
	ReadingRejectedError,
	type DeviceReading,
	type IngestResult
} from './handler.ts';

const SECRET = 'test-ingest-secret-with-enough-entropy';
const HARDWARE_ID = '990000000000001';
const NOW = new Date('2026-11-21T17:00:30.000Z');
const FIX_TIME = '2026-11-21T17:00:00.000Z';

function traccarBody(overrides: Record<string, unknown> = {}) {
	return {
		device: { id: 7, uniqueId: HARDWARE_ID, name: 'MT710L' },
		position: {
			valid: true,
			latitude: 18.4861,
			longitude: -69.9312,
			accuracy: 8.5,
			fixTime: FIX_TIME,
			...overrides
		}
	};
}

function request(
	body: unknown,
	headers: Record<string, string> = { 'x-senda-ingest-secret': SECRET },
	method = 'POST'
): Request {
	return new Request('https://example.test/functions/v1/ingest-device-location', {
		method,
		headers: { 'Content-Type': 'application/json', ...headers },
		body: method === 'POST' ? (typeof body === 'string' ? body : JSON.stringify(body)) : undefined
	});
}

function createHarness(result: IngestResult | Error = { outcome: 'CREATED', locationId: 42 }) {
	const readings: DeviceReading[] = [];
	const logs: string[] = [];
	const errors: string[] = [];

	const handler = createDeviceIngestHandler({
		ingestSecret: SECRET,
		now: () => NOW,
		async ingest(reading) {
			readings.push(reading);
			if (result instanceof Error) throw result;
			return result;
		},
		log: (message) => logs.push(message),
		logError: (message, error) =>
			errors.push(`${message} ${error instanceof Error ? error.message : ''}`)
	});

	return { handler, readings, logs, errors };
}

describe('ingest-device-location handler', () => {
	it('rejects non-POST methods', async () => {
		const { handler, readings } = createHarness();
		const response = await handler(request(null, { 'x-senda-ingest-secret': SECRET }, 'GET'));

		assert.equal(response.status, 405);
		assert.equal(readings.length, 0);
	});

	it('rejects a missing or wrong secret without touching the database', async () => {
		const { handler, readings } = createHarness();

		assert.equal((await handler(request(traccarBody(), {}))).status, 401);
		assert.equal(
			(await handler(request(traccarBody(), { 'x-senda-ingest-secret': 'wrong-secret' }))).status,
			401
		);
		assert.equal(readings.length, 0);
	});

	it('accepts the secret as a Bearer token', async () => {
		const { handler, readings } = createHarness();
		const response = await handler(request(traccarBody(), { authorization: `Bearer ${SECRET}` }));

		assert.equal(response.status, 201);
		assert.equal(readings.length, 1);
	});

	it('creates a reading from a Traccar position forward', async () => {
		const { handler, readings } = createHarness();
		const response = await handler(request(traccarBody()));
		const body = await response.json();

		assert.equal(response.status, 201);
		assert.equal(body.outcome, 'CREATED');
		assert.equal(body.locationId, 42);
		assert.equal(body.receivedAt, NOW.toISOString());
		assert.equal(readings[0].hardwareId, HARDWARE_ID);
		assert.equal(readings[0].latitude, 18.4861);
		assert.equal(readings[0].accuracyM, 8.5);
		assert.equal(readings[0].recordedAt, FIX_TIME);
		assert.match(
			readings[0].eventId,
			/^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/
		);
	});

	it('accepts the exact payload captured from Traccar 6.x (OsmAnd test device)', async () => {
		// Captured on 2026-11-21 from a local Traccar container forwarding with forward.type=json.
		const captured = {
			position: {
				id: 0,
				attributes: { distance: 0, totalDistance: 0, motion: false },
				deviceId: 1,
				protocol: 'osmand',
				serverTime: '2026-11-21T17:52:32.406+00:00',
				deviceTime: '2026-11-21T17:52:32.000+00:00',
				fixTime: '2026-11-21T17:52:32.000+00:00',
				valid: true,
				latitude: 18.49,
				longitude: -69.9312,
				altitude: 0,
				speed: 0,
				course: 0,
				address: null,
				accuracy: 8,
				network: null,
				geofenceIds: null
			},
			device: {
				id: 1,
				attributes: {},
				groupId: 0,
				calendarId: 0,
				name: HARDWARE_ID,
				uniqueId: HARDWARE_ID,
				status: 'online',
				lastUpdate: '2026-11-21T17:52:32.427+00:00',
				positionId: 0,
				phone: null,
				model: null,
				contact: null,
				category: null,
				disabled: false,
				expirationTime: null
			}
		};
		const { handler, readings } = createHarness();
		const response = await handler(request(captured));

		assert.equal(response.status, 201);
		assert.equal(readings[0].hardwareId, HARDWARE_ID);
		assert.equal(readings[0].latitude, 18.49);
		assert.equal(readings[0].longitude, -69.9312);
		assert.equal(readings[0].accuracyM, 8);
		assert.equal(readings[0].recordedAt, '2026-11-21T17:52:32.000Z');
	});

	it('accepts the flat Senda shape and epoch timestamps', async () => {
		const { handler, readings } = createHarness();
		const response = await handler(
			request({
				hardwareId: HARDWARE_ID,
				latitude: '18.4861',
				longitude: '-69.9312',
				recordedAt: Date.parse(FIX_TIME)
			})
		);

		assert.equal(response.status, 201);
		assert.equal(readings[0].accuracyM, null);
		assert.equal(readings[0].recordedAt, FIX_TIME);
	});

	it('acknowledges a duplicate without error', async () => {
		const { handler } = createHarness({ outcome: 'DUPLICATE', locationId: 42 });
		const response = await handler(request(traccarBody()));

		assert.equal(response.status, 200);
		assert.equal((await response.json()).outcome, 'DUPLICATE');
	});

	it('acknowledges non-retryable domain outcomes with 202', async () => {
		for (const outcome of [
			'UNKNOWN_DEVICE',
			'NO_ACTIVE_ASSIGNMENT',
			'PREDATES_ASSIGNMENT',
			'CONFLICT'
		] as const) {
			const { handler } = createHarness({ outcome, locationId: null });
			const response = await handler(request(traccarBody()));

			assert.equal(response.status, 202, outcome);
			assert.equal((await response.json()).outcome, outcome);
		}
	});

	it('ignores a position without a GPS fix', async () => {
		const { handler, readings, logs } = createHarness();
		const response = await handler(request(traccarBody({ valid: false })));

		assert.equal(response.status, 202);
		assert.equal((await response.json()).outcome, 'IGNORED');
		assert.equal(readings.length, 0);
		assert.deepEqual(logs, ['ingest outcome=IGNORED reason=NO_GPS_FIX']);
	});

	it('rejects malformed readings before ingestion', async () => {
		const { handler, readings } = createHarness();
		const invalidBodies = [
			'not json',
			[],
			traccarBody({ latitude: 91 }),
			traccarBody({ longitude: -181 }),
			traccarBody({ latitude: 'abc' }),
			traccarBody({ accuracy: -1 }),
			traccarBody({ fixTime: 'not a date' }),
			traccarBody({ fixTime: undefined }),
			{ device: { uniqueId: 'x' }, position: traccarBody().position },
			{ position: traccarBody().position }
		];

		for (const body of invalidBodies) {
			const response = await handler(request(body));
			assert.equal(response.status, 400, JSON.stringify(body));
		}
		assert.equal(readings.length, 0);
	});

	it('rejects oversized payloads', async () => {
		const { handler, readings } = createHarness();
		const response = await handler(request({ ...traccarBody(), padding: 'x'.repeat(20_000) }));

		assert.equal(response.status, 413);
		assert.equal(readings.length, 0);
	});

	it('acknowledges data the database rejects permanently', async () => {
		const { handler } = createHarness(new ReadingRejectedError('Latitude is invalid.'));
		const response = await handler(request(traccarBody()));

		assert.equal(response.status, 202);
		assert.equal((await response.json()).outcome, 'REJECTED');
	});

	it('returns 500 on transient failures so Traccar can retry', async () => {
		const { handler, errors } = createHarness(new Error('connection reset'));
		const response = await handler(request(traccarBody()));

		assert.equal(response.status, 500);
		assert.equal(errors.length, 1);
	});

	it('never logs or echoes the hardware identifier, coordinates or secret', async () => {
		const { handler, logs, errors } = createHarness();
		const created = await (await handler(request(traccarBody()))).text();
		const failing = createHarness(new Error('connection reset'));
		const failed = await (await failing.handler(request(traccarBody()))).text();

		const everything = [
			created,
			failed,
			...logs,
			...errors,
			...failing.logs,
			...failing.errors
		].join('\n');
		assert.ok(!everything.includes(HARDWARE_ID));
		assert.ok(!everything.includes('18.4861'));
		assert.ok(!everything.includes(SECRET));
		assert.match(logs[0], /^ingest outcome=CREATED lag_ms=30000$/);
	});
});

describe('deriveEventId', () => {
	it('is deterministic for the same fix and differs for another', async () => {
		const fix = new Date(FIX_TIME);
		const first = await deriveEventId(HARDWARE_ID, fix, 18.4861, -69.9312);
		const repeated = await deriveEventId(HARDWARE_ID, new Date(FIX_TIME), 18.4861, -69.9312);
		const moved = await deriveEventId(HARDWARE_ID, fix, 18.4862, -69.9312);
		const otherDevice = await deriveEventId('990000000000002', fix, 18.4861, -69.9312);

		assert.equal(first, repeated);
		assert.notEqual(first, moved);
		assert.notEqual(first, otherDevice);
	});
});

describe('parseDeviceReading', () => {
	it('normalizes a numeric Traccar uniqueId to the hardware identifier', () => {
		const parsed = parseDeviceReading({
			device: { uniqueId: 990000000000001 },
			position: { latitude: 18.4, longitude: -69.9, fixTime: FIX_TIME }
		});

		assert.equal(parsed.kind, 'reading');
		if (parsed.kind === 'reading') assert.equal(parsed.hardwareId, HARDWARE_ID);
	});
});
