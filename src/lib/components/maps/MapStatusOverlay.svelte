<script lang="ts">
	import RefreshCw from '@lucide/svelte/icons/refresh-cw';
	import { hasGoogleMapsConfig } from '#lib/utils/google-maps.js';
	import { onMount } from 'svelte';

	interface Props {
		status: 'LOADING' | 'READY' | 'ERROR';
		loadingTitle: string;
		loadingSubtitle: string;
		errorTitle: string;
		errorHint: string;
		onretry: () => void;
	}

	let { status, loadingTitle, loadingSubtitle, errorTitle, errorHint, onretry }: Props = $props();

	// Google avisa por este callback global cuando rechaza la clave. Llega después de crear el mapa,
	// así que este componente permanece montado aunque el mapa ya figure como "listo".
	let authFailed = $state(false);

	onMount(() => {
		const previous = window.gm_authFailure;
		window.gm_authFailure = () => {
			authFailed = true;
			previous?.();
		};

		return () => {
			window.gm_authFailure = previous;
		};
	});

	let misconfigured = $derived(!hasGoogleMapsConfig || authFailed);
	let showError = $derived(misconfigured || status === 'ERROR');
	let showLoading = $derived(!showError && status === 'LOADING');
</script>

{#if showLoading}
	<div
		class="absolute inset-0 grid place-items-center bg-surface-muted p-6 text-center"
		role="status"
	>
		<div>
			<div
				class="mx-auto size-9 animate-spin rounded-full border-4 border-brand/20 border-t-brand motion-reduce:animate-none"
				aria-hidden="true"
			></div>
			<p class="mt-4 font-bold text-ink">{loadingTitle}</p>
			<p class="mt-1 text-sm leading-6 text-muted">{loadingSubtitle}</p>
		</div>
	</div>
{:else if showError}
	<div
		class="absolute inset-0 grid place-items-center bg-surface-muted p-6 text-center"
		role="alert"
	>
		<div class="max-w-sm">
			{#if misconfigured}
				<p class="font-bold text-ink">El mapa no está disponible por ahora</p>
				<p class="mt-2 text-sm leading-6 text-muted">
					Hay un problema de configuración del servicio de mapas. Avisa a quien administra Senda.
					Tus datos no se modificaron.
				</p>
				<details class="mt-3 text-left text-sm text-muted">
					<summary class="cursor-pointer rounded-lg px-1 font-semibold text-ink">
						Detalle técnico
					</summary>
					<p class="mt-2 leading-6">
						{#if !hasGoogleMapsConfig}
							Falta la variable <code class="font-mono">PUBLIC_GOOGLE_MAPS_API_KEY</code> en el entorno
							de compilación.
						{:else}
							Google rechazó la clave (<code class="font-mono">InvalidKeyMapError</code> u otro error
							de autorización). Revisa que la clave esté bien copiada, que la API «Maps JavaScript» esté
							habilitada y que las restricciones de origen incluyan este dominio.
						{/if}
					</p>
				</details>
			{:else}
				<p class="font-bold text-ink">{errorTitle}</p>
				<p class="mt-2 text-sm leading-6 text-muted">{errorHint}</p>
				<button
					type="button"
					onclick={onretry}
					class="mt-4 inline-flex min-h-12 cursor-pointer items-center justify-center gap-2 rounded-xl bg-brand px-5 font-bold text-white transition hover:bg-brand/90"
				>
					<RefreshCw aria-hidden="true" size={19} strokeWidth={2} />
					Reintentar
				</button>
			{/if}
		</div>
	</div>
{/if}
