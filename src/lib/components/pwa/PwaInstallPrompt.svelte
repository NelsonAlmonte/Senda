<script lang="ts">
	import Download from '@lucide/svelte/icons/download';
	import { getPwaInstallContext, getPwaManualGuideMessage } from '#lib/utils/pwa-install.svelte.js';

	type Props = { authenticated?: boolean };

	let { authenticated = false }: Props = $props();
	const install = getPwaInstallContext();
</script>

{#if !install.dismissed && (install.canInstall || install.installing || install.feedback || install.manualGuide)}
	<aside
		class={[
			'fixed right-4 left-4 z-50 mx-auto max-w-xl rounded-2xl border border-brand/20 bg-white p-4 sm:right-6 sm:left-auto sm:w-112',
			authenticated ? 'bottom-24 lg:bottom-6' : 'bottom-4 sm:bottom-6'
		]}
		aria-labelledby="pwa-install-title"
	>
		<p id="pwa-install-title" class="font-bold text-ink">
			{install.manualGuide ? 'Instala Senda desde Safari' : 'Instala Senda en este dispositivo'}
		</p>

		{#if install.manualGuide}
			<p class="mt-2 text-sm leading-6 text-muted">
				{getPwaManualGuideMessage(install.manualGuide)}
			</p>
			<button
				type="button"
				onclick={install.dismissUntilReload}
				class="mt-3 min-h-12 cursor-pointer rounded-xl border border-ink/15 bg-white px-4 font-bold text-ink transition hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none"
			>
				Ahora no
			</button>
		{:else if install.feedback}
			<p class="mt-2 text-sm leading-6 text-muted" role="status">{install.feedback}</p>
			<button
				type="button"
				onclick={install.clearFeedback}
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
					onclick={install.requestInstall}
					disabled={install.installing}
					class="inline-flex min-h-12 cursor-pointer items-center justify-center gap-2 rounded-xl bg-brand px-4 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none disabled:cursor-wait disabled:opacity-60"
				>
					<Download aria-hidden="true" size={19} strokeWidth={2} />
					{install.installing ? 'Abriendo…' : 'Instalar Senda'}
				</button>
				<button
					type="button"
					onclick={install.dismissUntilReload}
					class="min-h-12 cursor-pointer rounded-xl border border-ink/15 bg-white px-4 font-bold text-ink transition hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none"
				>
					Ahora no
				</button>
			</div>
		{/if}
	</aside>
{/if}
