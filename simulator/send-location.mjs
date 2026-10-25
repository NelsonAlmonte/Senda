import process from 'node:process';
import {
	createSimulatorClient,
	ingestSimulatedLocation,
	parseAccuracy,
	parseLatitude,
	parseLongitude,
	parsePatientId,
	readSimulatorConfig,
	signInSimulator
} from './simulator-client.mjs';

const usage = 'Uso: npm run simulate:location -- <patient-id> <latitud> <longitud> [precision-m]';
const [patientIdText, latitudeText, longitudeText, accuracyText] = process.argv.slice(2);

let supabase;
let authenticated = false;

try {
	if (!patientIdText || !latitudeText || !longitudeText) throw new Error(usage);

	const patientId = parsePatientId(patientIdText);
	const latitude = parseLatitude(latitudeText);
	const longitude = parseLongitude(longitudeText);
	const accuracyM = parseAccuracy(accuracyText);
	const config = readSimulatorConfig();
	supabase = createSimulatorClient(config);

	await signInSimulator(supabase, config);
	authenticated = true;

	const result = await ingestSimulatedLocation(supabase, {
		patientId,
		latitude,
		longitude,
		accuracyM
	});
	console.log(JSON.stringify(result, null, 2));
} catch (error) {
	console.error(error.message);
	process.exitCode = 1;
} finally {
	if (authenticated) await supabase.auth.signOut();
}
