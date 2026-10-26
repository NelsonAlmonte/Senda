import 'jsr:@supabase/functions-js/edge-runtime.d.ts';

import { createClient } from '@supabase/supabase-js';
import { sendPushNotification } from '@web-push/send';

import {
	createPushDeliveryHandler,
	type BrowserPushSubscription,
	type PushPayload,
	type StoredPushSubscription
} from './handler.ts';

interface PatientAccessRow {
	user_id: string;
}

function readSupabaseSecretKey(): string | null {
	const secretKeys = Deno.env.get('SUPABASE_SECRET_KEYS');
	if (secretKeys) {
		try {
			const parsed = JSON.parse(secretKeys) as Record<string, unknown>;
			if (typeof parsed.default === 'string') return parsed.default;

			const firstKey = Object.values(parsed).find((value) => typeof value === 'string');
			if (typeof firstKey === 'string') return firstKey;
		} catch {
			// Fall through to the legacy local-development variable.
		}
	}

	return Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? null;
}

const configuration = {
	supabaseUrl: Deno.env.get('SUPABASE_URL'),
	supabaseSecretKey: readSupabaseSecretKey(),
	webhookSecret: Deno.env.get('SENDA_WEBHOOK_SECRET'),
	vapidPublicKey: Deno.env.get('PUBLIC_VAPID_PUBLIC_KEY'),
	vapidPrivateKey: Deno.env.get('SENDA_VAPID_PRIVATE_KEY'),
	vapidSubject: Deno.env.get('SENDA_VAPID_SUBJECT')
};

const missingConfiguration = Object.entries(configuration)
	.filter(([, value]) => !value)
	.map(([name]) => name);

if (missingConfiguration.length > 0) {
	console.error(`Web Push configuration is incomplete: ${missingConfiguration.join(', ')}.`);
}

const supabase =
	missingConfiguration.length === 0
		? createClient(configuration.supabaseUrl!, configuration.supabaseSecretKey!, {
				auth: { persistSession: false, autoRefreshToken: false }
			})
		: null;

const deliveryHandler = supabase
	? createPushDeliveryHandler({
			webhookSecret: configuration.webhookSecret!,
			async getSubscriptions(patientId): Promise<StoredPushSubscription[]> {
				const { data: accessRows, error: accessError } = await supabase
					.from('patient_access')
					.select('user_id')
					.eq('patient_id', patientId)
					.is('revoked_at', null);

				if (accessError) throw new Error('Authorized users could not be loaded.');

				const userIds = [
					...new Set((accessRows as PatientAccessRow[] | null)?.map((row) => row.user_id) ?? [])
				];
				if (userIds.length === 0) return [];

				const { data, error } = await supabase
					.from('push_subscriptions')
					.select('id, endpoint, p256dh, auth')
					.in('user_id', userIds);

				if (error) throw new Error('Push subscriptions could not be loaded.');
				return (data ?? []) as StoredPushSubscription[];
			},
			async sendPush(subscription: BrowserPushSubscription, payload: PushPayload) {
				return sendPushNotification(subscription, payload, {
					publicKey: configuration.vapidPublicKey!,
					privateKey: configuration.vapidPrivateKey!,
					subject: configuration.vapidSubject!
				});
			},
			async removeSubscription(subscriptionId) {
				const { error } = await supabase
					.from('push_subscriptions')
					.delete()
					.eq('id', subscriptionId);

				if (error) throw new Error('Expired push subscription could not be removed.');
			},
			logError(message, error) {
				console.error(message, error instanceof Error ? error.message : 'Unknown error.');
			}
		})
	: null;

Deno.serve((request) => {
	if (!deliveryHandler) {
		return Response.json(
			{ error: 'Web Push delivery is not configured.' },
			{ status: 503, headers: { 'Cache-Control': 'no-store' } }
		);
	}

	return deliveryHandler(request);
});
