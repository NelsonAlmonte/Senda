import 'jsr:@supabase/functions-js/edge-runtime.d.ts';

import { createClient } from '@supabase/supabase-js';

import {
	createDeviceIngestHandler,
	ReadingRejectedError,
	type IngestOutcome,
	type IngestResult
} from './handler.ts';

const OUTCOMES: readonly IngestOutcome[] = [
	'CREATED',
	'DUPLICATE',
	'CONFLICT',
	'UNKNOWN_DEVICE',
	'NO_ACTIVE_ASSIGNMENT',
	'PREDATES_ASSIGNMENT'
];

function readSupabaseSecretKey(): string | null {
	const secretKeys = Deno.env.get('SUPABASE_SECRET_KEYS');
	if (secretKeys) {
		try {
			const parsed = JSON.parse(secretKeys) as Record<string, unknown>;
			if (typeof parsed.default === 'string') return parsed.default;

			const firstKey = Object.values(parsed).find((value) => typeof value === 'string');
			if (typeof firstKey === 'string') return firstKey;
		} catch {
			// Fall through to the legacy local-development variable.
		}
	}

	return Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? null;
}

const configuration = {
	supabaseUrl: Deno.env.get('SUPABASE_URL'),
	supabaseSecretKey: readSupabaseSecretKey(),
	ingestSecret: Deno.env.get('SENDA_INGEST_SECRET')
};

const missingConfiguration = Object.entries(configuration)
	.filter(([, value]) => !value)
	.map(([name]) => name);

if (missingConfiguration.length > 0) {
	console.error(
		`Device ingestion configuration is incomplete: ${missingConfiguration.join(', ')}.`
	);
} else if (configuration.ingestSecret!.length < 32) {
	console.error('SENDA_INGEST_SECRET must contain at least 32 characters.');
	missingConfiguration.push('SENDA_INGEST_SECRET');
}

const supabase =
	missingConfiguration.length === 0
		? createClient(configuration.supabaseUrl!, configuration.supabaseSecretKey!, {
				auth: { persistSession: false, autoRefreshToken: false }
			})
		: null;

const ingestHandler = supabase
	? createDeviceIngestHandler({
			ingestSecret: configuration.ingestSecret!,
			async ingest(reading): Promise<IngestResult> {
				const { data, error } = await supabase.rpc('ingest_device_location', {
					p_hardware_id: reading.hardwareId,
					p_event_id: reading.eventId,
					p_latitude: reading.latitude,
					p_longitude: reading.longitude,
					p_accuracy_m: reading.accuracyM,
					p_recorded_at: reading.recordedAt
				});

				// 22023 = invalid reading data; retrying it can never succeed.
				if (error?.code === '22023') throw new ReadingRejectedError(error.message);
				if (error) throw new Error(`Ingestion RPC failed (${error.code ?? 'unknown'}).`);

				const row = Array.isArray(data) ? data[0] : data;
				const outcome = row?.ingest_outcome as IngestOutcome | undefined;
				if (!outcome || !OUTCOMES.includes(outcome)) {
					throw new Error('Ingestion RPC returned an unexpected outcome.');
				}

				return { outcome, locationId: row.location_id ?? null };
			},
			log(message) {
				console.log(message);
			},
			logError(message, error) {
				console.error(message, error instanceof Error ? error.message : 'Unknown error.');
			}
		})
	: null;

Deno.serve((request) => {
	if (!ingestHandler) {
		return Response.json(
			{ error: 'Device ingestion is not configured.' },
			{ status: 503, headers: { 'Cache-Control': 'no-store' } }
		);
	}

	return ingestHandler(request);
});
