export interface StoredPushSubscription {
	id: string;
	endpoint: string;
	p256dh: string;
	auth: string;
}

export interface BrowserPushSubscription {
	endpoint: string;
	expirationTime: null;
	keys: {
		p256dh: string;
		auth: string;
	};
}

export interface PushPayload {
	title: string;
	body: string;
	tag: string;
	url: string;
}

interface AlertEpisodeWebhookPayload {
	type: 'INSERT';
	table: 'alert_episodes';
	schema: 'public';
	record: {
		id: string;
		patient_id: string;
		status: 'OPEN';
	};
}

export interface DeliveryDependencies {
	webhookSecret: string;
	getSubscriptions(patientId: string): Promise<StoredPushSubscription[]>;
	sendPush(subscription: BrowserPushSubscription, payload: PushPayload): Promise<boolean>;
	removeSubscription(subscriptionId: string): Promise<void>;
	logError?(message: string, error?: unknown): void;
}

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function jsonResponse(body: unknown, status = 200): Response {
	return Response.json(body, {
		status,
		headers: { 'Cache-Control': 'no-store' }
	});
}

function secretsMatch(expected: string, provided: string): boolean {
	const encoder = new TextEncoder();
	const expectedBytes = encoder.encode(expected);
	const providedBytes = encoder.encode(provided);
	const comparedLength = Math.max(expectedBytes.length, providedBytes.length);
	let difference = expectedBytes.length ^ providedBytes.length;

	for (let index = 0; index < comparedLength; index += 1) {
		difference |= (expectedBytes[index] ?? 0) ^ (providedBytes[index] ?? 0);
	}

	return difference === 0;
}

function isWebhookPayload(value: unknown): value is AlertEpisodeWebhookPayload {
	if (!value || typeof value !== 'object') return false;

	const payload = value as Record<string, unknown>;
	if (
		payload.type !== 'INSERT' ||
		payload.table !== 'alert_episodes' ||
		payload.schema !== 'public' ||
		!payload.record ||
		typeof payload.record !== 'object'
	) {
		return false;
	}

	const record = payload.record as Record<string, unknown>;
	return (
		record.status === 'OPEN' &&
		typeof record.id === 'string' &&
		UUID_PATTERN.test(record.id) &&
		typeof record.patient_id === 'string' &&
		UUID_PATTERN.test(record.patient_id)
	);
}

export function createPushDeliveryHandler(dependencies: DeliveryDependencies) {
	const logError = dependencies.logError ?? console.error;

	return async function handlePushDelivery(request: Request): Promise<Response> {
		if (request.method !== 'POST') {
			return jsonResponse({ error: 'Method not allowed.' }, 405);
		}

		const providedSecret = request.headers.get('x-senda-webhook-secret') ?? '';
		if (!secretsMatch(dependencies.webhookSecret, providedSecret)) {
			return jsonResponse({ error: 'Unauthorized.' }, 401);
		}

		let body: unknown;
		try {
			body = await request.json();
		} catch {
			return jsonResponse({ error: 'Invalid JSON body.' }, 400);
		}

		if (!isWebhookPayload(body)) {
			return jsonResponse({ error: 'Invalid alert episode event.' }, 400);
		}

		let subscriptions: StoredPushSubscription[];
		try {
			subscriptions = await dependencies.getSubscriptions(body.record.patient_id);
		} catch (error) {
			logError('Web Push subscriptions could not be loaded.', error);
			return jsonResponse({ error: 'Subscriptions could not be loaded.' }, 500);
		}

		const result = { delivered: 0, removed: 0, failed: 0 };
		const payload: PushPayload = {
			title: 'Alerta de zona segura',
			body: 'Posible salida de una zona segura. Abre Senda para revisar de inmediato.',
			tag: `senda-episode-${body.record.id}`,
			url: '/dashboard'
		};

		for (const subscription of subscriptions) {
			try {
				const delivered = await dependencies.sendPush(
					{
						endpoint: subscription.endpoint,
						expirationTime: null,
						keys: { p256dh: subscription.p256dh, auth: subscription.auth }
					},
					payload
				);

				if (delivered) {
					result.delivered += 1;
					continue;
				}

				await dependencies.removeSubscription(subscription.id);
				result.removed += 1;
			} catch (error) {
				result.failed += 1;
				logError(`Web Push delivery failed for subscription ${subscription.id}.`, error);
			}
		}

		return jsonResponse(result);
	};
}
