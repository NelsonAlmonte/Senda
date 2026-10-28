import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import {
	createPushDeliveryHandler,
	type BrowserPushSubscription,
	type PushPayload,
	type StoredPushSubscription
} from './handler.ts';

const WEBHOOK_SECRET = 'test-webhook-secret-with-enough-entropy';
const EPISODE_ID = '11111111-1111-4111-8111-111111111111';
const PATIENT_ID = '22222222-2222-4222-8222-222222222222';

function request(body: unknown, secret = WEBHOOK_SECRET): Request {
	return new Request('https://example.test/functions/v1/send-geofence-alert', {
		method: 'POST',
		headers: {
			'Content-Type': 'application/json',
			'x-senda-webhook-secret': secret
		},
		body: JSON.stringify(body)
	});
}

function validBody() {
	return {
		type: 'INSERT',
		table: 'alert_episodes',
		schema: 'public',
		record: { id: EPISODE_ID, patient_id: PATIENT_ID, status: 'OPEN' }
	};
}

function subscription(id: string): StoredPushSubscription {
	return {
		id,
		endpoint: `https://push.example.test/${id}`,
		p256dh: `p256dh-${id}`,
		auth: `auth-${id}`
	};
}

function dependencies(overrides: {
	getSubscriptions?: (patientId: string) => Promise<StoredPushSubscription[]>;
	sendPush?: (subscription: BrowserPushSubscription, payload: PushPayload) => Promise<boolean>;
	removeSubscription?: (subscriptionId: string) => Promise<void>;
}) {
	return {
		webhookSecret: WEBHOOK_SECRET,
		getSubscriptions: overrides.getSubscriptions ?? (async () => []),
		sendPush: overrides.sendPush ?? (async () => true),
		removeSubscription: overrides.removeSubscription ?? (async () => undefined),
		logError: () => undefined
	};
}

describe('send-geofence-alert handler', () => {
	it('rejects methods other than POST', async () => {
		const handler = createPushDeliveryHandler(dependencies({}));
		const response = await handler(new Request('https://example.test', { method: 'GET' }));

		assert.equal(response.status, 405);
	});

	it('rejects a request with the wrong webhook secret', async () => {
		const handler = createPushDeliveryHandler(dependencies({}));
		const response = await handler(request(validBody(), 'wrong-secret'));

		assert.equal(response.status, 401);
	});

	it('rejects malformed or unrelated database events', async () => {
		const handler = createPushDeliveryHandler(dependencies({}));
		const response = await handler(
			request({
				...validBody(),
				type: 'UPDATE',
				record: { ...validBody().record, status: 'RESOLVED' }
			})
		);

		assert.equal(response.status, 400);
	});

	it('returns zero counts when no authorized browser is subscribed', async () => {
		const handler = createPushDeliveryHandler(dependencies({}));
		const response = await handler(request(validBody()));

		assert.equal(response.status, 200);
		assert.deepEqual(await response.json(), { delivered: 0, removed: 0, failed: 0 });
	});

	it('sends a generic urgent payload without patient identity or coordinates', async () => {
		let receivedPatientId = '';
		let receivedPayload: PushPayload | null = null;
		const handler = createPushDeliveryHandler(
			dependencies({
				getSubscriptions: async (patientId) => {
					receivedPatientId = patientId;
					return [subscription('first')];
				},
				sendPush: async (_subscription, payload) => {
					receivedPayload = payload;
					return true;
				}
			})
		);

		const response = await handler(request(validBody()));

		assert.equal(response.status, 200);
		assert.equal(receivedPatientId, PATIENT_ID);
		assert.deepEqual(receivedPayload, {
			title: 'Alerta de zona segura',
			body: 'Posible salida de una zona segura. Abre Senda para revisar de inmediato.',
			tag: `senda-episode-${EPISODE_ID}`,
			url: '/alerts'
		});
		assert.equal(JSON.stringify(receivedPayload).includes(PATIENT_ID), false);
		assert.deepEqual(await response.json(), { delivered: 1, removed: 0, failed: 0 });
	});

	it('removes only subscriptions reported as permanently gone', async () => {
		const removed: string[] = [];
		const handler = createPushDeliveryHandler(
			dependencies({
				getSubscriptions: async () => [subscription('gone'), subscription('active')],
				sendPush: async (item) => !item.endpoint.endsWith('/gone'),
				removeSubscription: async (id) => {
					removed.push(id);
				}
			})
		);

		const response = await handler(request(validBody()));

		assert.deepEqual(removed, ['gone']);
		assert.deepEqual(await response.json(), { delivered: 1, removed: 1, failed: 0 });
	});

	it('keeps transiently failed subscriptions for future alerts', async () => {
		const removed: string[] = [];
		const handler = createPushDeliveryHandler(
			dependencies({
				getSubscriptions: async () => [subscription('temporary-error')],
				sendPush: async () => {
					throw new Error('temporary provider failure');
				},
				removeSubscription: async (id) => {
					removed.push(id);
				}
			})
		);

		const response = await handler(request(validBody()));

		assert.deepEqual(removed, []);
		assert.deepEqual(await response.json(), { delivered: 0, removed: 0, failed: 1 });
	});

	it('returns a server error when subscriptions cannot be loaded', async () => {
		const handler = createPushDeliveryHandler(
			dependencies({
				getSubscriptions: async () => {
					throw new Error('database unavailable');
				}
			})
		);

		const response = await handler(request(validBody()));

		assert.equal(response.status, 500);
	});
});
