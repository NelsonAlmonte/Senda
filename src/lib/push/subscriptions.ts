import { dev } from '$app/env';
import { PUBLIC_VAPID_PUBLIC_KEY } from '$app/env/public';
import { createBrowserSupabaseClient } from '#lib/supabase/client.js';

export type PushNotificationState =
	'CHECKING' | 'ACTIVE' | 'INACTIVE' | 'BLOCKED' | 'UNSUPPORTED' | 'UNCONFIGURED' | 'ERROR';

export interface PushNotificationStatus {
	detail?: string;
	state: PushNotificationState;
}

interface StoredPushSubscription {
	id: string;
}

function supportsWebPush(): boolean {
	return (
		typeof window !== 'undefined' &&
		window.isSecureContext &&
		'Notification' in window &&
		'serviceWorker' in navigator &&
		'PushManager' in window
	);
}

function applicationServerKey(): Uint8Array<ArrayBuffer> {
	const normalized = PUBLIC_VAPID_PUBLIC_KEY.trim().replace(/-/g, '+').replace(/_/g, '/');
	const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, '=');
	const decoded = atob(padded);
	const bytes = new Uint8Array(new ArrayBuffer(decoded.length));

	for (let index = 0; index < decoded.length; index += 1) {
		bytes[index] = decoded.charCodeAt(index);
	}

	if (bytes.length !== 65 || bytes[0] !== 4) {
		throw new Error('La clave pública VAPID configurada no es válida.');
	}

	return bytes;
}

async function serviceWorkerRegistration(): Promise<ServiceWorkerRegistration> {
	const existing = await navigator.serviceWorker.getRegistration('/');
	if (existing) return existing;

	return navigator.serviceWorker.register('/sw.js', {
		scope: '/',
		type: dev ? 'module' : 'classic'
	});
}

async function currentUserId(): Promise<string> {
	const supabase = createBrowserSupabaseClient();
	const { data, error } = await supabase.auth.getUser();

	if (error || !data.user) {
		throw new Error('Tu sesión expiró. Inicia sesión nuevamente para configurar notificaciones.');
	}

	return data.user.id;
}

async function storedSubscription(endpoint: string): Promise<StoredPushSubscription | null> {
	const supabase = createBrowserSupabaseClient();
	const { data, error } = await supabase
		.from('push_subscriptions')
		.select('id')
		.eq('endpoint', endpoint)
		.maybeSingle();

	if (error) throw new Error('No pudimos comprobar el estado de las notificaciones.');
	return data;
}

export async function readPushNotificationStatus(): Promise<PushNotificationStatus> {
	if (!supportsWebPush()) {
		return {
			state: 'UNSUPPORTED',
			detail: 'Este navegador o contexto no admite notificaciones Web Push.'
		};
	}

	if (!PUBLIC_VAPID_PUBLIC_KEY.trim()) {
		return {
			state: 'UNCONFIGURED',
			detail: 'Falta configurar la clave pública VAPID de este entorno.'
		};
	}

	if (Notification.permission === 'denied') {
		return {
			state: 'BLOCKED',
			detail: 'El navegador bloqueó las notificaciones para Senda.'
		};
	}

	try {
		const registration = await serviceWorkerRegistration();
		const subscription = await registration.pushManager.getSubscription();
		if (!subscription) return { state: 'INACTIVE' };

		const stored = await storedSubscription(subscription.endpoint);
		if (stored) return { state: 'ACTIVE' };

		// A browser subscription can survive a logout. Remove an endpoint that is not
		// owned by the current session before another account can reuse this browser.
		await subscription.unsubscribe();
		return { state: 'INACTIVE' };
	} catch (error) {
		return {
			state: 'ERROR',
			detail:
				error instanceof Error
					? error.message
					: 'No pudimos comprobar el estado de las notificaciones.'
		};
	}
}

export async function enablePushNotifications(): Promise<void> {
	if (!supportsWebPush()) {
		throw new Error('Este navegador o contexto no admite notificaciones Web Push.');
	}

	const key = applicationServerKey();
	const permission =
		Notification.permission === 'granted' ? 'granted' : await Notification.requestPermission();

	if (permission !== 'granted') {
		throw new Error('No se concedió permiso para mostrar notificaciones.');
	}

	const registration = await serviceWorkerRegistration();
	let subscription = await registration.pushManager.getSubscription();

	if (subscription && !(await storedSubscription(subscription.endpoint))) {
		await subscription.unsubscribe();
		subscription = null;
	}

	subscription ??= await registration.pushManager.subscribe({
		applicationServerKey: key,
		userVisibleOnly: true
	});

	const serialized = subscription.toJSON();
	const p256dh = serialized.keys?.p256dh;
	const auth = serialized.keys?.auth;

	if (!p256dh || !auth) {
		await subscription.unsubscribe();
		throw new Error('El navegador no devolvió las claves necesarias para Web Push.');
	}

	const userId = await currentUserId();
	const supabase = createBrowserSupabaseClient();
	const { error } = await supabase.from('push_subscriptions').upsert(
		{
			user_id: userId,
			endpoint: subscription.endpoint,
			p256dh,
			auth
		},
		{ onConflict: 'endpoint' }
	);

	if (error) {
		await subscription.unsubscribe();
		throw new Error('No pudimos guardar la suscripción de este dispositivo.');
	}
}

export async function disablePushNotifications(): Promise<void> {
	if (!supportsWebPush()) return;

	const registration = await navigator.serviceWorker.getRegistration('/');
	const subscription = await registration?.pushManager.getSubscription();
	if (!subscription) return;

	const supabase = createBrowserSupabaseClient();
	const { error } = await supabase
		.from('push_subscriptions')
		.delete()
		.eq('endpoint', subscription.endpoint);

	if (error) {
		throw new Error('No pudimos eliminar la suscripción guardada. Inténtalo nuevamente.');
	}

	const unsubscribed = await subscription.unsubscribe();
	if (!unsubscribed) {
		throw new Error('El navegador no pudo desactivar la suscripción. Inténtalo nuevamente.');
	}
}
