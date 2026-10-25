import { randomUUID } from 'node:crypto';
import process from 'node:process';
import { createClient } from '@supabase/supabase-js';

const [patientId, latitudeText, longitudeText, accuracyText = '10'] = process.argv.slice(2);
const supabaseUrl = process.env.PUBLIC_SUPABASE_URL;
const publishableKey = process.env.PUBLIC_SUPABASE_PUBLISHABLE_KEY;
const email = process.env.SENDA_SIMULATOR_EMAIL;
const password = process.env.SENDA_SIMULATOR_PASSWORD;

function stop(message) {
	console.error(message);
	process.exitCode = 1;
}

if (!supabaseUrl || !publishableKey || !email || !password) {
	stop(
		'Configura PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_PUBLISHABLE_KEY, SENDA_SIMULATOR_EMAIL y SENDA_SIMULATOR_PASSWORD en .env.'
	);
} else if (!patientId || !latitudeText || !longitudeText) {
	stop('Uso: npm run simulate:location -- <patient-id> <latitud> <longitud> [precision-m]');
} else {
	const latitude = Number(latitudeText);
	const longitude = Number(longitudeText);
	const accuracyM = Number(accuracyText);

	if (!Number.isFinite(latitude) || latitude < -90 || latitude > 90) {
		stop('La latitud debe ser un número entre -90 y 90.');
	} else if (!Number.isFinite(longitude) || longitude < -180 || longitude > 180) {
		stop('La longitud debe ser un número entre -180 y 180.');
	} else if (!Number.isFinite(accuracyM) || accuracyM < 0) {
		stop('La precisión debe ser un número mayor o igual a cero.');
	} else {
		const supabase = createClient(supabaseUrl, publishableKey, {
			auth: { autoRefreshToken: false, persistSession: false }
		});

		const { error: signInError } = await supabase.auth.signInWithPassword({ email, password });
		if (signInError) {
			stop(`No se pudo autenticar la cuenta del simulador: ${signInError.message}`);
		} else {
			try {
				const { data, error } = await supabase.rpc('ingest_simulated_location', {
					p_patient_id: patientId,
					p_event_id: randomUUID(),
					p_latitude: latitude,
					p_longitude: longitude,
					p_accuracy_m: accuracyM,
					p_recorded_at: new Date().toISOString(),
					p_source: 'SIMULATOR'
				});

				if (error) {
					stop(`Supabase rechazó la ubicación simulada: ${error.message}`);
				} else {
					const result = data?.[0];
					console.log(
						JSON.stringify(
							{
								locationId: result?.location_id,
								assignmentId: result?.location_device_assignment_id,
								recordedAt: result?.location_recorded_at,
								created: result?.was_created
							},
							null,
							2
						)
					);
				}
			} finally {
				await supabase.auth.signOut();
			}
		}
	}
}
