import assert from 'node:assert/strict';
import { test } from 'node:test';
import { presentDeviceConnection } from './location-presentation.ts';

const NOW = Date.parse('2026-11-22T15:00:00.000Z');

function secondsAgo(seconds: number): string {
	return new Date(NOW - seconds * 1000).toISOString();
}

test('un equipo que nunca reportó no tiene estado de conexión', () => {
	assert.equal(presentDeviceConnection(null, NOW), null);
});

test('un reporte reciente cuenta como equipo conectado', () => {
	assert.deepEqual(presentDeviceConnection(secondsAgo(60), NOW), {
		connected: true,
		ageLabel: 'hace 1 minuto'
	});
	assert.equal(presentDeviceConnection(secondsAgo(180), NOW)?.connected, true);
});

test('un reporte de hace más de 3 minutos deja de contar como conectado', () => {
	assert.deepEqual(presentDeviceConnection(secondsAgo(181), NOW), {
		connected: false,
		ageLabel: 'hace 3 minutos'
	});
});
