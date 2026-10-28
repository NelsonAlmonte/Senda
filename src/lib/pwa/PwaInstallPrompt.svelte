<script lang="ts">
	import { onMount } from 'svelte';

	let installPrompt = $state<SendaBeforeInstallPromptEvent | null>(null);
	let installing = $state(false);
	let dismissed = $state(false);
	let feedback = $state('');

	function captureInstallPrompt(event: Event) {
		const promptEvent = event as SendaBeforeInstallPromptEvent;
		promptEvent.preventDefault();

		if (dismissed) return;

		installPrompt = promptEvent;
		feedback = '';
	}

	function clearInstallPrompt() {
		installPrompt = null;
		installing = false;
		dismissed = true;
		feedback = '';
	}

	function dismissForSession() {
		installPrompt = null;
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
		window.addEventListener('appinstalled', clearInstallPrompt);

		return () => window.removeEventListener('appinstalled', clearInstallPrompt);
	});
</script>

<svelte:window onbeforeinstallprompt={captureInstallPrompt} />

{#if !dismissed && (installPrompt || installing || feedback)}
	<aside
		class="fixed right-4 bottom-4 left-4 z-40 mx-auto max-w-xl rounded-2xl border border-brand/20 bg-white p-4 shadow-xl shadow-ink/15 sm:right-6 sm:bottom-6 sm:left-auto sm:w-[28rem]"
		aria-labelledby="pwa-install-title"
	>
		<p id="pwa-install-title" class="font-bold text-ink">Instala Senda en este dispositivo</p>

		{#if feedback}
			<p class="mt-2 text-sm leading-6 text-muted" role="status">{feedback}</p>
			<button
				type="button"
				onclick={dismissForSession}
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
					onclick={dismissForSession}
					class="min-h-12 cursor-pointer rounded-xl border border-ink/15 bg-white px-4 font-bold text-ink transition hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none"
				>
					Ahora no
				</button>
			</div>
		{/if}
	</aside>
{/if}
