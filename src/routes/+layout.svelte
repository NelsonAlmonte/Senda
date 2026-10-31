<script lang="ts">
	import { dev } from '$app/env';
	import AppHeader from '#lib/navigation/AppHeader.svelte';
	import AppNavigation from '#lib/navigation/AppNavigation.svelte';
	import PwaInstallPrompt from '#lib/pwa/PwaInstallPrompt.svelte';
	import { onMount } from 'svelte';
	import './layout.css';
	import type { LayoutProps } from './$types';

	let { data, children }: LayoutProps = $props();

	onMount(() => {
		if ('serviceWorker' in navigator) {
			void navigator.serviceWorker
				.register('/sw.js', { scope: '/', type: dev ? 'module' : 'classic' })
				.then((registration) => registration.update())
				.catch(() => undefined);
		}
	});
</script>

<svelte:head>
	<link rel="manifest" href="/manifest.webmanifest" />
	<link rel="icon" href="/favicon.ico" sizes="48x48" />
	<link rel="icon" href="/pwa-source.svg" sizes="any" type="image/svg+xml" />
	<link rel="apple-touch-icon" href="/apple-touch-icon-180x180.png" />
</svelte:head>

<a
	href="#contenido-principal"
	class="fixed top-3 left-3 z-50 -translate-y-24 rounded-lg bg-ink px-4 py-3 font-semibold text-white transition-transform focus:translate-y-0 focus:ring-4 focus:ring-focus/35 focus:outline-none"
>
	Saltar al contenido
</a>

{#if data.user}
	<AppNavigation />
	<div class="min-h-dvh pt-2 pb-28 sm:pt-4 lg:pr-12 lg:pb-4 lg:pl-80">
		<AppHeader hasActiveAlert={data.hasActiveAlert} />
		{@render children()}
	</div>
{:else}
	{@render children()}
{/if}

<PwaInstallPrompt authenticated={Boolean(data.user)} />
