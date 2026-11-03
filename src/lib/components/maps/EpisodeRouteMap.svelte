<script lang="ts">
	import RefreshCw from '@lucide/svelte/icons/refresh-cw';
	import type { EpisodeRouteSegment } from '#lib/types/maps.js';
	import { loadMapDisplayLibraries } from '#lib/utils/google-maps.js';
	import { untrack } from 'svelte';
	import type { Attachment } from 'svelte/attachments';

	type Props = {
		patientName: string;
		segments: EpisodeRouteSegment[];
		firstOutsideLocationId: number;
		confirmedByLocationId: number;
		resolvedByLocationId: number | null;
		status: 'OPEN' | 'RESOLVED';
	};

	let {
		patientName,
		segments,
		firstOutsideLocationId,
		confirmedByLocationId,
		resolvedByLocationId,
		status
	}: Props = $props();
	let mapState = $state<'LOADING' | 'READY' | 'ERROR'>('LOADING');
	let retryKey = $state(0);
	const MARKER_OVERLAP_DISTANCE_M = 35;
	const MARKER_OFFSET_PX = 36;

	type MarkerPoint = {
		latitude: number;
		longitude: number;
	};

	function distanceInMeters(first: MarkerPoint, second: MarkerPoint): number {
		const latitudeMeters = (first.latitude - second.latitude) * 111_320;
		const middleLatitudeRadians = ((first.latitude + second.latitude) / 2) * (Math.PI / 180);
		const longitudeMeters =
			(first.longitude - second.longitude) * 111_320 * Math.cos(middleLatitudeRadians);

		return Math.hypot(latitudeMeters, longitudeMeters);
	}

	function markerAnchorLeft(horizontalOffset: number): string {
		if (horizontalOffset === 0) return '-50%';
		return horizontalOffset > 0
			? `calc(-50% + ${horizontalOffset}px)`
			: `calc(-50% - ${Math.abs(horizontalOffset)}px)`;
	}

	function createMapAttachment(_retryKey: number): Attachment<HTMLDivElement> {
		void _retryKey;

		return (element) => {
			const initialState = untrack(() => ({
				patientName,
				segments,
				firstOutsideLocationId,
				confirmedByLocationId,
				resolvedByLocationId,
				status
			}));
			let disposed = false;
			let removeMapResources: (() => void) | null = null;

			mapState = 'LOADING';

			void (async () => {
				try {
					const [{ Map, Polyline }, { AdvancedMarkerElement, PinElement }, { LatLngBounds }] =
						await loadMapDisplayLibraries();
					if (disposed) return;

					const points = initialState.segments.flat();
					const firstPoint = points[0];
					if (!firstPoint) throw new Error('El episodio no contiene ubicaciones visibles.');

					const map = new Map(element, {
						center: { lat: firstPoint.latitude, lng: firstPoint.longitude },
						zoom: 16,
						mapId: 'DEMO_MAP_ID',
						clickableIcons: false,
						fullscreenControl: true,
						mapTypeControl: false,
						streetViewControl: false,
						gestureHandling: 'greedy'
					});

					const routePolylines = initialState.segments
						.filter((segment) => segment.length > 1)
						.map(
							(segment) =>
								new Polyline({
									map,
									path: segment.map((point) => ({
										lat: point.latitude,
										lng: point.longitude
									})),
									clickable: false,
									strokeColor: '#1f6f8b',
									strokeOpacity: 0.9,
									strokeWeight: 5,
									zIndex: 2
								})
						);

					const markerDefinitions = [
						{
							locationId: initialState.firstOutsideLocationId,
							title: `Primera lectura fuera de zona de ${initialState.patientName}`,
							glyph: '1',
							background: '#fef3c7',
							borderColor: '#92400e',
							glyphColor: '#92400e'
						},
						{
							locationId: initialState.confirmedByLocationId,
							title: `Lectura que confirmó la salida de ${initialState.patientName}`,
							glyph: '2',
							background: '#fee2e2',
							borderColor: '#991b1b',
							glyphColor: '#991b1b'
						},
						{
							locationId: initialState.resolvedByLocationId,
							title: `Lectura que confirmó el regreso de ${initialState.patientName}`,
							glyph: '3',
							background: '#dcfce7',
							borderColor: '#166534',
							glyphColor: '#166534'
						}
					];

					const lastPoint = points.at(-1);
					if (
						initialState.status === 'OPEN' &&
						lastPoint &&
						lastPoint.id !== initialState.confirmedByLocationId
					) {
						markerDefinitions.push({
							locationId: lastPoint.id,
							title: `Última lectura del episodio activo de ${initialState.patientName}`,
							glyph: '',
							background: '#355f55',
							borderColor: '#20373c',
							glyphColor: '#ffffff'
						});
					}

					const visibleMarkerDefinitions = markerDefinitions.flatMap((definition) => {
						if (definition.locationId === null) return [];
						const point = points.find((candidate) => candidate.id === definition.locationId);
						return point ? [{ ...definition, point }] : [];
					});
					const markers: Array<InstanceType<typeof AdvancedMarkerElement>> = [];

					visibleMarkerDefinitions.forEach((definition, markerIndex) => {
						const nearbyMarkerIndexes = visibleMarkerDefinitions.flatMap((candidate, index) =>
							distanceInMeters(definition.point, candidate.point) <= MARKER_OVERLAP_DISTANCE_M
								? [index]
								: []
						);
						const nearbyIndex = nearbyMarkerIndexes.indexOf(markerIndex);
						const horizontalOffset =
							nearbyMarkerIndexes.length > 1
								? (nearbyIndex - (nearbyMarkerIndexes.length - 1) / 2) * MARKER_OFFSET_PX
								: 0;
						const pin = new PinElement({
							background: definition.background,
							borderColor: definition.borderColor,
							glyph: definition.glyph,
							glyphColor: definition.glyphColor,
							scale: 1.05
						});

						markers.push(
							new AdvancedMarkerElement({
								map,
								position: {
									lat: definition.point.latitude,
									lng: definition.point.longitude
								},
								title: definition.title,
								content: pin,
								anchorLeft: markerAnchorLeft(horizontalOffset),
								zIndex: 10 + markerIndex
							})
						);
					});

					const bounds = new LatLngBounds();
					for (const point of points) {
						bounds.extend({ lat: point.latitude, lng: point.longitude });
					}
					const distinctPositions = new Set(
						points.map((point) => `${point.latitude}:${point.longitude}`)
					);
					if (distinctPositions.size > 1) map.fitBounds(bounds, 56);

					removeMapResources = () => {
						for (const marker of markers) {
							marker.map = null;
							marker.remove();
						}
						for (const polyline of routePolylines) polyline.setMap(null);
					};

					mapState = 'READY';
				} catch {
					if (!disposed) mapState = 'ERROR';
				}
			})();

			return () => {
				disposed = true;
				removeMapResources?.();
				element.replaceChildren();
			};
		};
	}
</script>

<section
	class="relative min-h-112 overflow-hidden rounded-2xl bg-surface-muted shadow-sm sm:min-h-128 xl:min-h-144"
	aria-label={`Mapa del recorrido del episodio de ${patientName}`}
	aria-busy={mapState === 'LOADING'}
>
	<div
		class="absolute inset-0"
		{@attach createMapAttachment(retryKey)}
		aria-label={`Google Maps con el recorrido registrado durante el episodio de ${patientName}`}
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
				<p class="mt-4 font-bold text-ink">Cargando recorrido…</p>
				<p class="mt-1 text-sm leading-6 text-muted">Preparando el historial del episodio.</p>
			</div>
		</div>
	{:else if mapState === 'ERROR'}
		<div
			class="absolute inset-0 grid place-items-center bg-surface-muted p-6 text-center"
			role="alert"
		>
			<div class="max-w-sm">
				<p class="font-bold text-ink">No pudimos cargar el recorrido</p>
				<p class="mt-2 text-sm leading-6 text-muted">
					Comprueba tu conexión y vuelve a intentarlo. El resumen temporal sigue disponible.
				</p>
				<button
					type="button"
					onclick={() => (retryKey += 1)}
					class="mt-4 inline-flex min-h-12 cursor-pointer items-center justify-center gap-2 rounded-xl bg-brand px-5 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none"
				>
					<RefreshCw aria-hidden="true" size={19} strokeWidth={2} />
					Reintentar
				</button>
			</div>
		</div>
	{/if}
</section>
