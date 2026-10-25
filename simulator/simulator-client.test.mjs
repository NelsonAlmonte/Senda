import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { demoRoute } from './routes/demo-route.mjs';
import {
	DEFAULT_ROUTE_INTERVAL_MS,
	normalizeRoute,
	parseAccuracy,
	parseLatitude,
	parseLongitude,
	parsePatientId,
	parseRouteInterval,
	readSimulatorConfig
} from './simulator-client.mjs';

describe('simulator input validation', () => {
	it('accepts valid location inputs', () => {
		assert.equal(
			parsePatientId('580be56d-ef61-414a-9a21-fa377b29c3aa'),
			'580be56d-ef61-414a-9a21-fa377b29c3aa'
		);
		assert.equal(parseLatitude('18.4861'), 18.4861);
		assert.equal(parseLongitude('-69.9312'), -69.9312);
		assert.equal(parseAccuracy('8.5'), 8.5);
	});

	it('rejects invalid coordinates and identifiers', () => {
		assert.throws(() => parsePatientId('patient-1'), /UUID válido/);
		assert.throws(() => parseLatitude('91'), /entre -90 y 90/);
		assert.throws(() => parseLongitude('-181'), /entre -180 y 180/);
		assert.throws(() => parseAccuracy('-1'), /mayor o igual a cero/);
	});

	it('uses the documented nominal interval and validates overrides', () => {
		assert.equal(parseRouteInterval(), DEFAULT_ROUTE_INTERVAL_MS);
		assert.equal(parseRouteInterval('2000'), 2000);
		assert.throws(() => parseRouteInterval('100'), /entre 250 y 300000/);
		assert.throws(() => parseRouteInterval('1000.5'), /número entero/);
	});

	it('normalizes every point and rejects invalid routes', () => {
		assert.deepEqual(
			normalizeRoute([
				{ latitude: '18.4', longitude: '-69.9', accuracyM: '7' },
				{ latitude: 18.5, longitude: -69.8 }
			]),
			[
				{ latitude: 18.4, longitude: -69.9, accuracyM: 7 },
				{ latitude: 18.5, longitude: -69.8, accuracyM: 10 }
			]
		);
		assert.throws(() => normalizeRoute([{ latitude: 18.4, longitude: -69.9 }]), /dos puntos/);
	});

	it('ships a valid deterministic route with twelve points', () => {
		const route = normalizeRoute(demoRoute);
		assert.equal(route.length, 12);
		assert.deepEqual(route[0], { latitude: 18.4861, longitude: -69.9312, accuracyM: 8 });
		assert.deepEqual(route.at(-1), {
			latitude: 18.48636,
			longitude: -69.93128,
			accuracyM: 8
		});
	});

	it('requires all development credentials without exposing their values', () => {
		assert.throws(() => readSimulatorConfig({}), /Configura PUBLIC_SUPABASE_URL/);
	});
});
