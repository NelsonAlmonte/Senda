<script lang="ts">
	import { loadMapDisplayLibraries } from './loader';
	import type { Attachment } from 'svelte/attachments';

	type Props = {
		latitude: number;
		longitude: number;
		accuracyM: number | null;
		patientName: string;
	};

	let { latitude, longitude, accuracyM, patientName }: Props = $props();
	let mapState = $state<'LOADING' | 'READY' | 'ERROR'>('LOADING');
	let retryKey = $state(0);

	function createMapAttachment(_retryKey: number): Attachment<HTMLDivElement> {
		void _retryKey;

		return (element) => {
			const position = { lat: latitude, lng: longitude };
			const accuracy = accuracyM;
			const markerTitle = `Última ubicación registrada de ${patientName}`;
			let disposed = false;
			let removeMarker: (() => void) | null = null;
			let removeAccuracyCircle: (() => void) | null = null;

			mapState = 'LOADING';

			void (async () => {
				try {
					const [{ Map, Circle }, { AdvancedMarkerElement, PinElement }] =
						await loadMapDisplayLibraries();
					if (disposed) return;

					const map = new Map(element, {
						center: position,
						zoom: 17,
						mapId: 'DEMO_MAP_ID',
						clickableIcons: false,
						fullscreenControl: true,
						mapTypeControl: false,
						streetViewControl: false,
						gestureHandling: 'cooperative'
					});

					const pin = new PinElement({
						background: '#355f55',
						borderColor: '#20373c',
						glyphColor: '#ffffff',
						scale: 1.1
					});

					const marker = new AdvancedMarkerElement({
						map,
						position,
						title: markerTitle,
						content: pin
					});
					removeMarker = () => {
						marker.map = null;
						marker.remove();
					};

					if (accuracy !== null && accuracy > 0) {
						const accuracyCircle = new Circle({
							map,
							center: position,
							radius: accuracy,
							clickable: false,
							fillColor: '#bdd8e9',
							fillOpacity: 0.24,
							strokeColor: '#1f6f8b',
							strokeOpacity: 0.7,
							strokeWeight: 2
						});
						removeAccuracyCircle = () => accuracyCircle.setMap(null);
					}

					mapState = 'READY';
				} catch {
					if (!disposed) mapState = 'ERROR';
				}
			})();

			return () => {
				disposed = true;
				removeMarker?.();
				removeAccuracyCircle?.();
				element.replaceChildren();
			};
		};
	}
</script>

<section
	class="relative min-h-88 overflow-hidden rounded-3xl border border-ink/10 bg-surface-muted shadow-lg shadow-brand/5 sm:min-h-112"
	aria-label={`Mapa de la última ubicación de ${patientName}`}
	aria-busy={mapState === 'LOADING'}
>
	<div
		class="absolute inset-0"
		{@attach createMapAttachment(retryKey)}
		aria-label={`Google Maps con la última ubicación registrada de ${patientName}`}
	></div>

	{#if mapState === 'LOADING'}
		<div
			class="absolute inset-0 grid place-items-center bg-surface-muted p-6 text-center"
			role="status"
		>
			<div>
				<div
					class="mx-auto size-9 animate-spin rounded-full border-4 border-brand/20 border-t-brand motion-reduce:animate-none"
					aria-hidden="true"
				></div>
				<p class="mt-4 font-bold text-ink">Cargando mapa…</p>
				<p class="mt-1 text-sm leading-6 text-muted">La ubicación ya está disponible.</p>
			</div>
		</div>
	{:else if mapState === 'ERROR'}
		<div
			class="absolute inset-0 grid place-items-center bg-surface-muted p-6 text-center"
			role="alert"
		>
			<div class="max-w-sm">
				<p class="font-bold text-ink">No pudimos cargar Google Maps</p>
				<p class="mt-2 text-sm leading-6 text-muted">
					Comprueba tu conexión y vuelve a intentarlo. Los datos de ubicación siguen protegidos.
				</p>
				<button
					type="button"
					onclick={() => (retryKey += 1)}
					class="mt-4 min-h-12 cursor-pointer rounded-xl bg-brand px-5 font-bold text-white shadow-sm transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none"
				>
					Reintentar
				</button>
			</div>
		</div>
	{/if}
</section>
