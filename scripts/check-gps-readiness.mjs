import net from 'node:net';
import process from 'node:process';

// Pre-flight check for the physical GPS integration. It never writes a location and never
// prints the ingest secret or a full hardware identifier.
//
//   npm run check:gps-readiness
//   npm run check:gps-readiness -- --hardware-id <imei> --traccar-host <host-or-ip> [--ports 5030,5191]

const args = process.argv.slice(2);

function option(name) {
	const index = args.indexOf(`--${name}`);
	return index >= 0 ? args[index + 1] : undefined;
}

const url = process.env.SENDA_INGEST_URL;
const secret = process.env.SENDA_INGEST_SECRET;
const webhookSecret = process.env.SENDA_WEBHOOK_SECRET;
const hardwareId = option('hardware-id');
const traccarHost = option('traccar-host');
const ports = (option('ports') ?? '5030,5191')
	.split(',')
	.map((value) => Number(value.trim()))
	.filter((value) => Number.isInteger(value) && value > 0 && value < 65536);

const results = [];

function record(name, ok, detail) {
	results.push({ name, ok, detail });
}

function maskId(value) {
	return value.length <= 7 ? '***' : `${value.slice(0, 4)}…${value.slice(-3)}`;
}

function probeBody(id, fixTime) {
	return JSON.stringify({
		device: { uniqueId: id },
		position: { valid: true, latitude: 18.4861, longitude: -69.9312, accuracy: 8, fixTime }
	});
}

async function post(headers, body) {
	const response = await fetch(url, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json', ...headers },
		body,
		signal: AbortSignal.timeout(20_000)
	});
	return { status: response.status, json: await response.json().catch(() => null) };
}

function checkPort(host, port) {
	return new Promise((resolve) => {
		const socket = net.createConnection({ host, port, timeout: 6000 });
		socket.once('connect', () => {
			socket.destroy();
			resolve({ ok: true });
		});
		socket.once('timeout', () => {
			socket.destroy();
			resolve({ ok: false, reason: 'timeout' });
		});
		socket.once('error', (error) => resolve({ ok: false, reason: error.code ?? 'error' }));
	});
}

record(
	'Variables SENDA_INGEST_URL y SENDA_INGEST_SECRET',
	Boolean(url && secret && !/your-project-ref|replace-with/.test(`${url}${secret}`)),
	url && secret ? 'definidas' : 'faltan en .env'
);
record(
	'Secreto de ingestión de al menos 32 caracteres',
	Boolean(secret && secret.length >= 32),
	secret ? `${secret.length} caracteres` : 'sin valor'
);
record(
	'Secreto de ingestión distinto del del webhook',
	!(secret && webhookSecret && secret === webhookSecret),
	webhookSecret ? 'comparado' : 'SENDA_WEBHOOK_SECRET no está en .env, no se pudo comparar'
);

if (url && secret) {
	try {
		const probe = await fetch(url, { method: 'GET', signal: AbortSignal.timeout(20_000) });
		record(
			'Función desplegada y configurada (GET → 405)',
			probe.status === 405,
			`respondió ${probe.status}${probe.status === 503 ? ' (falta SENDA_INGEST_SECRET en Supabase)' : ''}`
		);

		const wrong = await post(
			{ 'x-senda-ingest-secret': 'incorrect-secret-for-readiness-probe-0000' },
			probeBody('990000000000000', new Date().toISOString())
		);
		record(
			'Rechaza un secreto incorrecto (401)',
			wrong.status === 401,
			`respondió ${wrong.status}`
		);

		const bearer = await post(
			{ Authorization: 'Bearer incorrect-secret-for-readiness-probe-0000' },
			probeBody('990000000000000', new Date().toISOString())
		);
		record(
			'Rechaza un Bearer incorrecto (401)',
			bearer.status === 401,
			`respondió ${bearer.status}`
		);

		const unknown = await post(
			{ 'x-senda-ingest-secret': secret },
			probeBody('990000000000000', new Date().toISOString())
		);
		record(
			'Acepta el secreto correcto (202 UNKNOWN_DEVICE)',
			unknown.status === 202 && unknown.json?.outcome === 'UNKNOWN_DEVICE',
			`respondió ${unknown.status} ${unknown.json?.outcome ?? ''}`.trim()
		);

		if (hardwareId) {
			// A reading dated in 2000 can never be stored, so this probe only reveals the device state.
			const state = await post(
				{ 'x-senda-ingest-secret': secret },
				probeBody(hardwareId, '2000-01-01T00:00:00.000Z')
			);
			const meaning = {
				UNKNOWN_DEVICE: 'el IMEI NO está registrado en Senda',
				NO_ACTIVE_ASSIGNMENT: 'registrado, pero sin paciente asignado',
				PREDATES_ASSIGNMENT: 'registrado y asignado a un paciente'
			}[state.json?.outcome];
			record(
				`Estado del dispositivo ${maskId(hardwareId)}`,
				state.json?.outcome === 'PREDATES_ASSIGNMENT',
				meaning ?? `respuesta inesperada ${state.status}`
			);
		}
	} catch (error) {
		record('Conexión con la función', false, error instanceof Error ? error.message : 'error');
	}
}

if (traccarHost) {
	for (const port of ports) {
		const outcome = await checkPort(traccarHost, port);
		record(
			`Traccar acepta conexiones TCP en el puerto ${port}`,
			outcome.ok,
			outcome.ok ? 'abierto' : `sin conexión (${outcome.reason})`
		);
	}
}

for (const { name, ok, detail } of results) {
	console.log(`${ok ? 'OK  ' : 'FALLA'}  ${name} — ${detail}`);
}

const failed = results.filter((result) => !result.ok).length;
console.log(failed === 0 ? '\nTodo listo.' : `\n${failed} comprobación(es) con fallo.`);
process.exitCode = failed === 0 ? 0 : 1;
