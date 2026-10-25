import process from 'node:process';
import { demoRoute } from './routes/demo-route.mjs';
import {
	createSimulatorClient,
	ingestSimulatedLocation,
	normalizeRoute,
	parsePatientId,
	parseRouteInterval,
	readSimulatorConfig,
	signInSimulator
} from './simulator-client.mjs';

const usage = 'Uso: npm run simulate:route -- <patient-id> [intervalo-ms]';
const [patientIdText, intervalText] = process.argv.slice(2);
const abortController = new AbortController();

function stopRoute() {
	if (!abortController.signal.aborted) {
		console.log('\nDeteniendo la ruta después de la lectura actual…');
		abortController.abort();
	}
}

function wait(milliseconds, signal) {
	return new Promise((resolve) => {
		if (signal.aborted) {
			resolve();
			return;
		}

		const timer = setTimeout(finish, milliseconds);
		function finish() {
			clearTimeout(timer);
			signal.removeEventListener('abort', finish);
			resolve();
		}
		signal.addEventListener('abort', finish, { once: true });
	});
}

let supabase;
let authenticated = false;
process.once('SIGINT', stopRoute);

try {
	if (patientIdText === '--help' || patientIdText === '-h') {
		console.log(`${usage}\nIntervalo predeterminado: 30000 ms. Usa Ctrl+C para detener la ruta.`);
	} else {
		if (!patientIdText) throw new Error(usage);

		const patientId = parsePatientId(patientIdText);
		const intervalMs = parseRouteInterval(intervalText);
		const route = normalizeRoute(demoRoute);
		const config = readSimulatorConfig();
		supabase = createSimulatorClient(config);

		await signInSimulator(supabase, config);
		authenticated = true;
		console.log(
			`Reproduciendo ${route.length} lecturas cada ${intervalMs} ms. Usa Ctrl+C para detener.`
		);

		for (const [index, point] of route.entries()) {
			if (abortController.signal.aborted) break;

			const result = await ingestSimulatedLocation(supabase, { patientId, ...point });
			console.log(
				`[${index + 1}/${route.length}] ${point.latitude.toFixed(5)}, ${point.longitude.toFixed(5)} · ubicación ${result.locationId}`
			);

			if (index < route.length - 1) await wait(intervalMs, abortController.signal);
		}

		console.log(
			abortController.signal.aborted ? 'Ruta detenida.' : 'Ruta simulada completada correctamente.'
		);
	}
} catch (error) {
	console.error(error.message);
	process.exitCode = 1;
} finally {
	process.removeListener('SIGINT', stopRoute);
	if (authenticated) await supabase.auth.signOut();
}
