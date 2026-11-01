<script lang="ts">
	import { onMount } from 'svelte';

	type Props = { authenticated?: boolean };

	let { authenticated = false }: Props = $props();
	let installPrompt = $state<SendaBeforeInstallPromptEvent | null>(null);
	let installing = $state(false);
	let dismissed = $state(false);
	let feedback = $state('');
	let manualGuide = $state<'ios-safari' | 'ios-other' | 'macos-safari' | null>(null);

	function detectManualGuide() {
		const userAgent = navigator.userAgent;
		const isIos =
			/iPad|iPhone|iPod/i.test(userAgent) ||
			(navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
		const isSafari =
			/Safari/i.test(userAgent) &&
			!/Chrome|Chromium|CriOS|Edg|EdgiOS|OPR|Firefox|FxiOS|Android/i.test(userAgent);

		if (isIos) return isSafari ? 'ios-safari' : 'ios-other';
		if (isSafari) return 'macos-safari';

		return null;
	}

	function isRunningInstalled() {
		const navigatorWithStandalone = navigator as Navigator & { standalone?: boolean };

		return (
			window.matchMedia('(display-mode: standalone)').matches ||
			navigatorWithStandalone.standalone === true
		);
	}

	function captureInstallPrompt(event: Event) {
		const promptEvent = event as SendaBeforeInstallPromptEvent;
		promptEvent.preventDefault();

		if (dismissed) return;

		installPrompt = promptEvent;
		manualGuide = null;
		feedback = '';
	}

	function clearInstallPrompt() {
		installPrompt = null;
		manualGuide = null;
		installing = false;
		dismissed = true;
		feedback = '';
	}

	function dismissUntilReload() {
		installPrompt = null;
		manualGuide = null;
		dismissed = true;
		feedback = '';
	}

	async function requestInstall() {
		const prompt = installPrompt;
		if (!prompt || installing) return;

		installing = true;
		installPrompt = null;

		try {
			const choice = await prompt.prompt();
			feedback =
				choice.outcome === 'accepted'
					? 'Instalación aceptada. Senda aparecerá entre tus aplicaciones.'
					: 'La instalación se canceló. También puedes instalar Senda desde el menú del navegador.';
		} catch {
			feedback =
				'No pudimos abrir el diálogo. Busca “Instalar aplicación” en el menú del navegador.';
		} finally {
			installing = false;
		}
	}

	onMount(() => {
		if (!isRunningInstalled()) manualGuide = detectManualGuide();
		window.addEventListener('appinstalled', clearInstallPrompt);

		return () => window.removeEventListener('appinstalled', clearInstallPrompt);
	});
</script>

<svelte:window onbeforeinstallprompt={captureInstallPrompt} />

{#if !dismissed && (installPrompt || installing || feedback || manualGuide)}
	<aside
		class={[
			'fixed right-4 left-4 z-50 mx-auto max-w-xl rounded-2xl border border-brand/20 bg-white p-4 sm:right-6 sm:left-auto sm:w-112',
			authenticated ? 'bottom-24 lg:bottom-6' : 'bottom-4 sm:bottom-6'
		]}
		aria-labelledby="pwa-install-title"
	>
		<p id="pwa-install-title" class="font-bold text-ink">
			{manualGuide ? 'Instala Senda desde Safari' : 'Instala Senda en este dispositivo'}
		</p>

		{#if manualGuide}
			<p class="mt-2 text-sm leading-6 text-muted">
				{#if manualGuide === 'ios-safari'}
					Toca <strong>Compartir</strong>, elige <strong>Añadir a pantalla de inicio</strong> y, si
					aparece, activa <strong>Abrir como app</strong>.
				{:else if manualGuide === 'ios-other'}
					Abre esta página en Safari. Luego toca <strong>Compartir</strong> y elige
					<strong>Añadir a pantalla de inicio</strong>; si aparece, activa
					<strong>Abrir como app</strong>.
				{:else}
					En macOS Sonoma 14 o posterior, abre <strong>Archivo</strong> y elige
					<strong>Añadir al Dock</strong>.
				{/if}
			</p>
			<button
				type="button"
				onclick={dismissUntilReload}
				class="mt-3 min-h-12 cursor-pointer rounded-xl border border-ink/15 bg-white px-4 font-bold text-ink transition hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none"
			>
				Ahora no
			</button>
		{:else if feedback}
			<p class="mt-2 text-sm leading-6 text-muted" role="status">{feedback}</p>
			<button
				type="button"
				onclick={dismissUntilReload}
				class="mt-3 min-h-12 cursor-pointer rounded-xl border border-ink/15 bg-white px-4 font-bold text-ink transition hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none"
			>
				Entendido
			</button>
		{:else}
			<p class="mt-2 text-sm leading-6 text-muted">
				Ábrela más rápido desde tu pantalla de inicio, sin buscar la opción en el navegador.
			</p>
			<div class="mt-4 flex flex-wrap gap-3">
				<button
					type="button"
					onclick={requestInstall}
					disabled={installing}
					class="min-h-12 cursor-pointer rounded-xl bg-brand px-4 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none disabled:cursor-wait disabled:opacity-60"
				>
					{installing ? 'Abriendo…' : 'Instalar Senda'}
				</button>
				<button
					type="button"
					onclick={dismissUntilReload}
					class="min-h-12 cursor-pointer rounded-xl border border-ink/15 bg-white px-4 font-bold text-ink transition hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none"
				>
					Ahora no
				</button>
			</div>
		{/if}
	</aside>
{/if}
