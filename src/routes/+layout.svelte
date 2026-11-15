<script lang="ts">
	import { dev } from '$app/env';
	import { page } from '$app/state';
	import PushNotificationPrompt from '#lib/components/push/PushNotificationPrompt.svelte';
	import PwaInstallPrompt from '#lib/components/pwa/PwaInstallPrompt.svelte';
	import Header from '#lib/components/ui/Header.svelte';
	import Navigation from '#lib/components/ui/Navigation.svelte';
	import PageLoad from '#lib/components/ui/PageLoad.svelte';
	import type { PushNotificationPromptState } from '#lib/types/push.js';
	import {
		createPwaInstallController,
		setPwaInstallContext
	} from '#lib/utils/pwa-install.svelte.js';
	import { onMount } from 'svelte';
	import './layout.css';
	import type { LayoutProps } from './$types';

	let { data, children }: LayoutProps = $props();
	let publicLanding = $derived(page.route.id === '/');
	let focusedOnboarding = $derived(
		Boolean(data.user) && Boolean(page.route.id?.startsWith('/onboarding'))
	);
	let focusedAuth = $derived(Boolean(page.route.id?.startsWith('/auth')));
	let authenticatedShell = $derived(Boolean(data.user) && !publicLanding && !focusedOnboarding);
	let pushPromptCheckedForUser = $state<string | null>(null);
	let pushPromptClaimedForUser = $state<string | null>(null);
	let pushReminderScope = $derived(
		Boolean(data.user) && !publicLanding && !focusedOnboarding && !focusedAuth
	);
	let installPromptHidden = $derived(
		pushReminderScope &&
			(pushPromptCheckedForUser !== data.user?.id || pushPromptClaimedForUser === data.user?.id)
	);
	const pwaInstall = createPwaInstallController();

	setPwaInstallContext(pwaInstall);

	function handlePushPromptState(state: PushNotificationPromptState) {
		const userId = data.user?.id;
		if (!userId) return;

		if (state.checked) pushPromptCheckedForUser = userId;
		if (state.needsAttention) pushPromptClaimedForUser = userId;
	}

	onMount(() => {
		pwaInstall.initialize();
		window.addEventListener('appinstalled', pwaInstall.clearInstallPrompt);

		if ('serviceWorker' in navigator) {
			void navigator.serviceWorker
				.register('/sw.js', { scope: '/', type: dev ? 'module' : 'classic' })
				.then((registration) => registration.update())
				.catch(() => undefined);
		}

		return () => window.removeEventListener('appinstalled', pwaInstall.clearInstallPrompt);
	});
</script>

<svelte:head>
	<link rel="manifest" href="/manifest.webmanifest" />
	<link rel="icon" href="/favicon.ico" sizes="48x48" />
	<link rel="icon" href="/pwa-64x64.png" sizes="64x64" type="image/png" />
	<link rel="apple-touch-icon" href="/apple-touch-icon-180x180.png" />
</svelte:head>

<svelte:window onbeforeinstallprompt={pwaInstall.captureInstallPrompt} />

<PageLoad />

<a
	href="#contenido-principal"
	class="fixed top-3 left-3 z-50 -translate-y-24 rounded-lg bg-ink px-4 py-3 font-semibold text-white transition-transform focus:translate-y-0 focus:ring-4 focus:ring-focus/35 focus:outline-none"
>
	Saltar al contenido
</a>

{#if authenticatedShell}
	<Navigation />
	<div class="min-h-dvh pt-2 pb-28 sm:pt-4 lg:pr-12 lg:pb-4 lg:pl-80">
		<Header hasActiveAlert={data.hasActiveAlert} />
		{@render children()}
	</div>
{:else}
	{@render children()}
{/if}

{#if !focusedOnboarding && !publicLanding && !focusedAuth}
	<PwaInstallPrompt authenticated={Boolean(data.user)} hidden={installPromptHidden} />
{/if}

{#if data.user && !publicLanding && !focusedOnboarding && !focusedAuth}
	<PushNotificationPrompt
		suppressed={page.route.id === '/settings'}
		onstatechange={handlePushPromptState}
	/>
{/if}
