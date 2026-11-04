<script lang="ts">
	import Download from '@lucide/svelte/icons/download';
	import { getPwaInstallContext, getPwaManualGuideMessage } from '#lib/utils/pwa-install.svelte.js';

	const install = getPwaInstallContext();
	let showManualGuide = $state(false);
</script>

{#if !install.dismissed && (install.canInstall || install.installing || install.manualGuide)}
	<div class="mt-8 max-w-xl">
		<button
			type="button"
			onclick={() => {
				if (install.manualGuide) {
					showManualGuide = !showManualGuide;
					return;
				}

				void install.requestInstall();
			}}
			disabled={install.installing}
			aria-expanded={install.manualGuide ? showManualGuide : undefined}
			class="inline-flex min-h-12 cursor-pointer items-center justify-center gap-2 rounded-full bg-white px-5 font-bold text-brand transition hover:bg-surface-muted focus:ring-4 focus:ring-focus/30 focus:outline-none disabled:cursor-wait disabled:opacity-60"
		>
			<Download aria-hidden="true" size={19} strokeWidth={2} />
			{install.installing
				? 'Abriendo…'
				: install.manualGuide
					? 'Cómo instalar Senda'
					: 'Instalar Senda'}
		</button>

		{#if showManualGuide && install.manualGuide}
			<p class="mt-4 rounded-2xl bg-white p-4 text-sm leading-6 text-muted" role="status">
				{getPwaManualGuideMessage(install.manualGuide)}
			</p>
		{/if}
	</div>
{:else if install.feedback}
	<div class="mt-8 max-w-xl rounded-2xl bg-white p-4">
		<p class="text-sm leading-6 text-muted" role="status">{install.feedback}</p>
		<button
			type="button"
			onclick={install.clearFeedback}
			class="mt-3 min-h-12 cursor-pointer rounded-full px-4 font-bold text-brand transition hover:bg-surface-muted focus:ring-4 focus:ring-focus/30 focus:outline-none"
		>
			Entendido
		</button>
	</div>
{/if}
