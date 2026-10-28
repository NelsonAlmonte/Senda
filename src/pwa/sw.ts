/// <reference no-default-lib="true" />
/// <reference lib="esnext" />
/// <reference lib="webworker" />

import { cleanupOutdatedCaches, precacheAndRoute } from 'workbox-precaching';

declare global {
	interface WorkerGlobalScope {
		__WB_MANIFEST: Array<{ revision: string | null; url: string }>;
	}
}

interface SendaPushPayload {
	tag?: unknown;
	url?: unknown;
}

const sw = self as unknown as ServiceWorkerGlobalScope;
const DEFAULT_NOTIFICATION_URL = '/alerts';

precacheAndRoute(self.__WB_MANIFEST);
cleanupOutdatedCaches();

sw.addEventListener('install', () => {
	void sw.skipWaiting();
});

sw.addEventListener('activate', (event) => {
	event.waitUntil(sw.clients.claim());
});

function parsePayload(event: PushEvent): SendaPushPayload {
	if (!event.data) return {};

	try {
		const payload: unknown = event.data.json();
		return payload && typeof payload === 'object' ? (payload as SendaPushPayload) : {};
	} catch {
		return {};
	}
}

function notificationUrl(value: unknown): string {
	if (typeof value !== 'string') return DEFAULT_NOTIFICATION_URL;

	try {
		const url = new URL(value, sw.location.origin);
		return url.origin === sw.location.origin
			? `${url.pathname}${url.search}${url.hash}`
			: DEFAULT_NOTIFICATION_URL;
	} catch {
		return DEFAULT_NOTIFICATION_URL;
	}
}

function notificationTag(value: unknown): string {
	if (typeof value !== 'string') return 'senda-alert';
	const normalized = value.trim().slice(0, 128);
	return normalized || 'senda-alert';
}

function isAppClient(client: WindowClient): boolean {
	try {
		return new URL(client.url).origin === sw.location.origin;
	} catch {
		return false;
	}
}

async function focusOrOpenNotificationTarget(targetUrl: string): Promise<void> {
	const clients = await sw.clients.matchAll({ includeUncontrolled: true, type: 'window' });
	const appClient = clients.find(isAppClient);

	if (appClient) {
		try {
			if (appClient.url === targetUrl) {
				await appClient.focus();
				return;
			}

			const navigatedClient = await appClient.navigate(targetUrl);
			await (navigatedClient ?? appClient).focus();
			return;
		} catch {
			// The window may have closed; open a new client below.
		}
	}

	const openedClient = await sw.clients.openWindow(targetUrl);
	if (openedClient) await openedClient.focus();
}

sw.addEventListener('push', (event) => {
	const payload = parsePayload(event);
	event.waitUntil(
		sw.registration.showNotification('Alerta de zona segura', {
			body: 'Posible salida de una zona segura. Abre Senda para revisar de inmediato.',
			icon: '/pwa-192x192.png',
			badge: '/pwa-64x64.png',
			tag: notificationTag(payload.tag),
			data: { url: notificationUrl(payload.url) }
		})
	);
});

sw.addEventListener('notificationclick', (event) => {
	event.notification.close();
	const targetPath = notificationUrl(event.notification.data?.url);

	event.waitUntil(
		(async () => {
			const targetUrl = new URL(targetPath, sw.location.origin).href;
			await focusOrOpenNotificationTarget(targetUrl);
		})()
	);
});
