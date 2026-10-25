import { randomUUID } from 'node:crypto';
import process from 'node:process';
import { createClient } from '@supabase/supabase-js';

export const DEFAULT_ACCURACY_M = 10;
export const DEFAULT_ROUTE_INTERVAL_MS = 30_000;
export const MIN_ROUTE_INTERVAL_MS = 250;
export const MAX_ROUTE_INTERVAL_MS = 300_000;

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function parseFiniteNumber(value, label) {
	const number = Number(value);
	if (!Number.isFinite(number)) throw new Error(`${label} debe ser un número válido.`);
	return number;
}

export function parsePatientId(value) {
	if (!value || !uuidPattern.test(value)) throw new Error('El patient-id debe ser un UUID válido.');
	return value;
}

export function parseLatitude(value) {
	const latitude = parseFiniteNumber(value, 'La latitud');
	if (latitude < -90 || latitude > 90) {
		throw new Error('La latitud debe estar entre -90 y 90.');
	}
	return latitude;
}

export function parseLongitude(value) {
	const longitude = parseFiniteNumber(value, 'La longitud');
	if (longitude < -180 || longitude > 180) {
		throw new Error('La longitud debe estar entre -180 y 180.');
	}
	return longitude;
}

export function parseAccuracy(value = DEFAULT_ACCURACY_M) {
	const accuracyM = parseFiniteNumber(value, 'La precisión');
	if (accuracyM < 0) throw new Error('La precisión debe ser mayor o igual a cero.');
	return accuracyM;
}

export function parseRouteInterval(value = DEFAULT_ROUTE_INTERVAL_MS) {
	const intervalMs = parseFiniteNumber(value, 'El intervalo');
	if (!Number.isInteger(intervalMs)) throw new Error('El intervalo debe ser un número entero.');
	if (intervalMs < MIN_ROUTE_INTERVAL_MS || intervalMs > MAX_ROUTE_INTERVAL_MS) {
		throw new Error(
			`El intervalo debe estar entre ${MIN_ROUTE_INTERVAL_MS} y ${MAX_ROUTE_INTERVAL_MS} ms.`
		);
	}
	return intervalMs;
}

export function normalizeRoute(points) {
	if (!Array.isArray(points) || points.length < 2) {
		throw new Error('La ruta debe contener al menos dos puntos.');
	}

	return points.map((point, index) => {
		try {
			return {
				latitude: parseLatitude(point.latitude),
				longitude: parseLongitude(point.longitude),
				accuracyM: parseAccuracy(point.accuracyM)
			};
		} catch (error) {
			throw new Error(`Punto ${index + 1}: ${error.message}`, { cause: error });
		}
	});
}

export function readSimulatorConfig(environment = process.env) {
	const supabaseUrl = environment.PUBLIC_SUPABASE_URL;
	const publishableKey = environment.PUBLIC_SUPABASE_PUBLISHABLE_KEY;
	const email = environment.SENDA_SIMULATOR_EMAIL;
	const password = environment.SENDA_SIMULATOR_PASSWORD;

	if (!supabaseUrl || !publishableKey || !email || !password) {
		throw new Error(
			'Configura PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_PUBLISHABLE_KEY, SENDA_SIMULATOR_EMAIL y SENDA_SIMULATOR_PASSWORD en .env.'
		);
	}

	return { supabaseUrl, publishableKey, email, password };
}

export function createSimulatorClient({ supabaseUrl, publishableKey }) {
	return createClient(supabaseUrl, publishableKey, {
		auth: { autoRefreshToken: false, persistSession: false }
	});
}

export async function signInSimulator(supabase, { email, password }) {
	const { error } = await supabase.auth.signInWithPassword({ email, password });
	if (error) throw new Error(`No se pudo autenticar la cuenta del simulador: ${error.message}`);
}

export async function ingestSimulatedLocation(
	supabase,
	{ patientId, latitude, longitude, accuracyM, recordedAt = new Date().toISOString() }
) {
	const { data, error } = await supabase.rpc('ingest_simulated_location', {
		p_patient_id: patientId,
		p_event_id: randomUUID(),
		p_latitude: latitude,
		p_longitude: longitude,
		p_accuracy_m: accuracyM,
		p_recorded_at: recordedAt,
		p_source: 'SIMULATOR'
	});

	if (error) throw new Error(`Supabase rechazó la ubicación simulada: ${error.message}`);
	const result = data?.[0];
	if (!result) throw new Error('Supabase no devolvió el resultado de la ubicación simulada.');

	return {
		locationId: result.location_id,
		assignmentId: result.location_device_assignment_id,
		recordedAt: result.location_recorded_at,
		created: result.was_created
	};
}
