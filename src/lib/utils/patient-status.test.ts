import assert from 'node:assert/strict';
import { test } from 'node:test';
import { classifyPatientStatus, needsAttention, rankPatientStatus } from './patient-status.ts';

type Input = Parameters<typeof classifyPatientStatus>[0];

const healthy: Input = {
	hasAlert: false,
	hasDevice: true,
	hasActiveTransfer: false,
	freshness: 'FRESH',
	relation: 'INSIDE',
	dataComplete: true
};

const classify = (overrides: Partial<Input>) => classifyPatientStatus({ ...healthy, ...overrides });

test('lectura reciente dentro de una zona es la única forma de estar en orden', () => {
	assert.equal(classify({}), 'OK');
});

test('una salida confirmada gana a cualquier otro estado', () => {
	assert.equal(classify({ hasAlert: true }), 'ALERT');
	assert.equal(classify({ hasAlert: true, freshness: 'STALE', hasDevice: false }), 'ALERT');
	assert.equal(classify({ hasAlert: true, hasActiveTransfer: true }), 'ALERT');
});

test('fuera de zona, incierta o sin geocerca nunca es "en orden"', () => {
	for (const relation of ['OUTSIDE', 'UNCERTAIN', 'NO_ACTIVE_ZONE', 'NOT_EVALUATED'] as const) {
		assert.equal(classify({ relation }), 'REVIEW', relation);
	}
	assert.equal(classify({ relation: null }), 'REVIEW');
});

test('sin dispositivo y sin lecturas se distinguen', () => {
	assert.equal(classify({ hasDevice: false, freshness: null, relation: null }), 'NO_DEVICE');
	assert.equal(classify({ freshness: null, relation: null }), 'NO_LOCATION');
});

test('una lectura vieja es STALE aunque estuviera dentro de la zona', () => {
	assert.equal(classify({ freshness: 'STALE', relation: 'INSIDE' }), 'STALE');
});

test('un traslado en curso no tapa la pérdida de señal', () => {
	assert.equal(classify({ hasActiveTransfer: true }), 'TRANSFER');
	assert.equal(classify({ hasActiveTransfer: true, freshness: 'STALE' }), 'STALE');
});

test('si faltan datos jamás se afirma que todo está en orden', () => {
	assert.equal(classify({ dataComplete: false }), 'UNKNOWN');
	assert.equal(classify({ dataComplete: false, hasDevice: false }), 'UNKNOWN');
	assert.equal(classify({ dataComplete: false, freshness: null }), 'UNKNOWN');
	assert.equal(classify({ dataComplete: false, hasActiveTransfer: true }), 'UNKNOWN');
	// Aun con datos incompletos, lo que ya se sabe que es urgente se sigue mostrando.
	assert.equal(classify({ dataComplete: false, hasAlert: true }), 'ALERT');
	assert.equal(classify({ dataComplete: false, freshness: 'STALE' }), 'STALE');
});

test('el orden de urgencia es el acordado', () => {
	const order = [
		'ALERT',
		'REVIEW',
		'STALE',
		'NO_LOCATION',
		'NO_DEVICE',
		'UNKNOWN',
		'TRANSFER',
		'OK'
	] as const;
	const ranks = order.map(rankPatientStatus);
	assert.deepEqual(
		ranks,
		[...ranks].sort((a, b) => a - b)
	);
	assert.equal(new Set(ranks).size, order.length);
});

test('requieren atención los estados accionables, no los informativos', () => {
	for (const kind of ['ALERT', 'REVIEW', 'STALE', 'NO_LOCATION', 'NO_DEVICE'] as const) {
		assert.equal(needsAttention(kind), true, kind);
	}
	for (const kind of ['UNKNOWN', 'TRANSFER', 'OK'] as const) {
		assert.equal(needsAttention(kind), false, kind);
	}
});
