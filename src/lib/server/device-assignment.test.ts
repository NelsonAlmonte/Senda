import assert from 'node:assert/strict';
import { test } from 'node:test';
import { assignDeviceBySerial } from './device-assignment.ts';

type RpcResult = { error: { message: string; code?: string } | null };

function fakeSupabase(results: Record<string, RpcResult>) {
	const calls: Array<{ name: string; args: Record<string, unknown> }> = [];
	const client = {
		rpc(name: string, args: Record<string, unknown>) {
			calls.push({ name, args });
			return Promise.resolve(results[name] ?? { error: { message: `unexpected ${name}` } });
		}
	};
	return { client: client as never, calls };
}

const PATIENT = '11111111-2222-4333-8444-555555555555';
const SERIAL = 'SENDA-GPS-001';

test('asigna con el flujo simulado y no toca el físico', async () => {
	const { client, calls } = fakeSupabase({ assign_simulated_device: { error: null } });

	assert.equal(await assignDeviceBySerial(client, PATIENT, SERIAL), null);
	assert.deepEqual(
		calls.map((call) => call.name),
		['assign_simulated_device']
	);
});

test('reintenta con el flujo físico cuando el serial no está en el inventario simulado', async () => {
	const { client, calls } = fakeSupabase({
		assign_simulated_device: { error: { message: 'Serial is not registered.' } },
		assign_physical_device: { error: null }
	});

	assert.equal(await assignDeviceBySerial(client, PATIENT, SERIAL), null);
	assert.deepEqual(
		calls.map((call) => call.name),
		['assign_simulated_device', 'assign_physical_device']
	);
	assert.deepEqual(calls[1].args, { p_patient_id: PATIENT, p_serial_number: SERIAL });
});

test('devuelve el error del flujo físico si el serial tampoco existe allí', async () => {
	const { client } = fakeSupabase({
		assign_simulated_device: { error: { message: 'Serial is not registered.' } },
		assign_physical_device: { error: { message: 'Serial is not registered.' } }
	});

	const error = await assignDeviceBySerial(client, PATIENT, SERIAL);
	assert.equal(error?.message, 'Serial is not registered.');
});

test('un dispositivo ya ocupado se informa sin intentar el flujo físico', async () => {
	const { client, calls } = fakeSupabase({
		assign_simulated_device: { error: { message: 'Device already has an active patient.' } }
	});

	const error = await assignDeviceBySerial(client, PATIENT, SERIAL);
	assert.equal(error?.message, 'Device already has an active patient.');
	assert.deepEqual(
		calls.map((call) => call.name),
		['assign_simulated_device']
	);
});

test('un dispositivo físico ya ocupado conserva su error propio', async () => {
	const { client } = fakeSupabase({
		assign_simulated_device: { error: { message: 'Serial is not registered.' } },
		assign_physical_device: { error: { message: 'Device already has an active patient.' } }
	});

	const error = await assignDeviceBySerial(client, PATIENT, SERIAL);
	assert.equal(error?.message, 'Device already has an active patient.');
});
