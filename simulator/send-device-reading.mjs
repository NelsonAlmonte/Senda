import process from 'node:process';
import { parseAccuracy, parseLatitude, parseLongitude } from './simulator-client.mjs';

// Emulates the HTTP forward Traccar sends for one position. It exercises the deployed
// ingest-device-location function; it never touches the database or the simulator RPC.
//
//   npm run simulate:device-reading -- <hardware-id> <latitude> <longitude> [accuracy-m]

const [hardwareId, latitude, longitude, accuracy] = process.argv.slice(2);
const url = process.env.SENDA_INGEST_URL;
const secret = process.env.SENDA_INGEST_SECRET;

if (!hardwareId || latitude === undefined || longitude === undefined) {
	console.error(
		'Uso: npm run simulate:device-reading -- <hardware-id> <latitud> <longitud> [precision-m]'
	);
	process.exit(1);
}

if (!url || !secret) {
	console.error('Define SENDA_INGEST_URL y SENDA_INGEST_SECRET en .env.');
	process.exit(1);
}

let body;
try {
	body = {
		device: { uniqueId: hardwareId },
		position: {
			valid: true,
			latitude: parseLatitude(latitude),
			longitude: parseLongitude(longitude),
			...(accuracy === undefined ? {} : { accuracy: parseAccuracy(accuracy) }),
			fixTime: new Date().toISOString()
		}
	};
} catch (error) {
	console.error(error.message);
	process.exit(1);
}

const sentAt = new Date();
const response = await fetch(url, {
	method: 'POST',
	headers: { 'Content-Type': 'application/json', 'x-senda-ingest-secret': secret },
	body: JSON.stringify(body)
});
const receivedAt = new Date();
const result = await response.json().catch(() => ({}));

// The hardware identifier and secret are never printed.
console.log(
	JSON.stringify({
		status: response.status,
		outcome: result.outcome ?? null,
		locationId: result.locationId ?? null,
		sentAt: sentAt.toISOString(),
		respondedAt: receivedAt.toISOString(),
		roundTripMs: receivedAt.getTime() - sentAt.getTime()
	})
);
process.exitCode = response.ok ? 0 : 1;
