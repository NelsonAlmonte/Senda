<script module lang="ts">
	export type MapLocationUpdate = {
		latitude: number;
		longitude: number;
		accuracyM: number | null;
		patientName: string;
		historySegments: MapHistorySegment[];
		panToLocation?: boolean;
	};

	export type MapHistoryPoint = {
		latitude: number;
		longitude: number;
	};

	export type MapHistorySegment = MapHistoryPoint[];

	export type MapSafeZone = {
		id: string;
		name: string;
		centerLatitude: number;
		centerLongitude: number;
		radiusM: number;
	};

	export type MapLocationUpdater = (location: MapLocationUpdate) => void;

	export type MapSimulationPoint = {
		latitude: number;
		longitude: number;
	};

	export type PatientLocationMapController = {
		updateLocation: MapLocationUpdater;
		setSimulationMode: (enabled: boolean) => void;
		setSimulationPoint: (point: MapSimulationPoint | null) => void;
	};
</script>

<script lang="ts">
	import { loadMapDisplayLibraries } from './loader';
	import { untrack } from 'svelte';
	import type { Attachment } from 'svelte/attachments';

	type Props = {
		latitude: number;
		longitude: number;
		accuracyM: number | null;
		patientName: string;
		historySegments: MapHistorySegment[];
		safeZones: MapSafeZone[];
		hasLocation?: boolean;
		manualSimulationEnabled?: boolean;
		onSimulationPointChange?: (point: MapSimulationPoint) => void;
		onReady?: (controller: PatientLocationMapController | null) => void;
	};
	type MapClickEvent = {
		latLng: { lat: () => number; lng: () => number } | null;
	};

	let {
		latitude,
		longitude,
		accuracyM,
		patientName,
		historySegments,
		safeZones,
		hasLocation = true,
		manualSimulationEnabled = false,
		onSimulationPointChange,
		onReady
	}: Props = $props();
	let mapState = $state<'LOADING' | 'READY' | 'ERROR'>('LOADING');
	let retryKey = $state(0);

	function createMapAttachment(_retryKey: number): Attachment<HTMLDivElement> {
		void _retryKey;

		return (element) => {
			const initialState = untrack(() => ({
				position: { lat: latitude, lng: longitude },
				accuracyM,
				markerTitle: `Última ubicación registrada de ${patientName}`,
				historySegments,
				safeZones,
				hasLocation,
				manualSimulationEnabled,
				onSimulationPointChange,
				onReady
			}));
			let disposed = false;
			let removeMapResources: (() => void) | null = null;

			mapState = 'LOADING';

			void (async () => {
				try {
					const [
						{ Map, Circle, Polyline },
						{ AdvancedMarkerElement, PinElement },
						{ LatLngBounds }
					] = await loadMapDisplayLibraries();
					if (disposed) return;

					const map = new Map(element, {
						center: initialState.position,
						zoom: 17,
						mapId: 'DEMO_MAP_ID',
						clickableIcons: false,
						fullscreenControl: true,
						mapTypeControl: false,
						streetViewControl: false,
						gestureHandling: 'greedy'
					});

					const safeZoneCircles = initialState.safeZones.map(
						(zone) =>
							new Circle({
								map,
								center: { lat: zone.centerLatitude, lng: zone.centerLongitude },
								radius: zone.radiusM,
								clickable: false,
								fillColor: '#8fbfaf',
								fillOpacity: 0.14,
								strokeColor: '#355f55',
								strokeOpacity: 0.8,
								strokeWeight: 2,
								zIndex: 1
							})
					);

					const pin = new PinElement({
						background: '#355f55',
						borderColor: '#20373c',
						glyphColor: '#ffffff',
						scale: 1.1
					});

					const marker = new AdvancedMarkerElement({
						map: initialState.hasLocation ? map : null,
						position: initialState.position,
						title: initialState.markerTitle,
						content: pin
					});

					const accuracyCircle = new Circle({
						map,
						center: initialState.position,
						radius: initialState.accuracyM ?? 0,
						visible:
							initialState.hasLocation &&
							initialState.accuracyM !== null &&
							initialState.accuracyM > 0,
						clickable: false,
						fillColor: '#bdd8e9',
						fillOpacity: 0.24,
						strokeColor: '#1f6f8b',
						strokeOpacity: 0.7,
						strokeWeight: 2,
						zIndex: 2
					});

					let routePolylines: Array<InstanceType<typeof Polyline>> = [];
					const renderHistory = (segments: MapHistorySegment[]) => {
						for (const polyline of routePolylines) polyline.setMap(null);
						routePolylines = segments
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
										strokeWeight: 4,
										zIndex: 3
									})
							);
					};

					renderHistory(initialState.historySegments);
					const historyPoints = initialState.historySegments.flat();
					const distinctPositions = new Set(
						historyPoints.map((point) => `${point.latitude}:${point.longitude}`)
					);
					if (distinctPositions.size > 1 || safeZoneCircles.length > 0) {
						const bounds = new LatLngBounds();
						if (initialState.hasLocation) bounds.extend(initialState.position);
						for (const point of historyPoints) {
							bounds.extend({ lat: point.latitude, lng: point.longitude });
						}
						for (const circle of safeZoneCircles) {
							const circleBounds = circle.getBounds();
							if (circleBounds) bounds.union(circleBounds);
						}
						map.fitBounds(bounds, 48);
					}

					const updateLocation: MapLocationUpdater = (location) => {
						const nextPosition = { lat: location.latitude, lng: location.longitude };
						marker.map = map;
						marker.position = nextPosition;
						marker.title = `Última ubicación registrada de ${location.patientName}`;
						accuracyCircle.setCenter(nextPosition);
						accuracyCircle.setRadius(location.accuracyM ?? 0);
						accuracyCircle.setVisible(location.accuracyM !== null && location.accuracyM > 0);
						renderHistory(location.historySegments);
						if (location.panToLocation !== false) map.panTo(nextPosition);
					};

					let simulationMode = false;
					let simulationMarker: InstanceType<typeof AdvancedMarkerElement> | null = null;
					const simulationPin = initialState.manualSimulationEnabled
						? new PinElement({
								background: '#fff3c4',
								borderColor: '#92400e',
								glyphColor: '#92400e',
								scale: 1.05
							})
						: null;

					const setSimulationPoint = (point: MapSimulationPoint | null) => {
						if (!initialState.manualSimulationEnabled) return;

						if (!point) {
							if (simulationMarker) simulationMarker.map = null;
							return;
						}

						const position = { lat: point.latitude, lng: point.longitude };
						if (simulationMarker) {
							simulationMarker.map = map;
							simulationMarker.position = position;
						} else if (simulationPin) {
							simulationMarker = new AdvancedMarkerElement({
								map,
								position,
								title: 'Ubicación simulada pendiente de confirmar',
								content: simulationPin
							});
						}
					};

					const setSimulationMode = (enabled: boolean) => {
						simulationMode = initialState.manualSimulationEnabled && enabled;
						map.setOptions({ draggableCursor: simulationMode ? 'crosshair' : null });
					};

					const mapClickListener = initialState.manualSimulationEnabled
						? map.addListener('click', (event: MapClickEvent) => {
								if (!simulationMode || !event.latLng) return;

								const point = {
									latitude: event.latLng.lat(),
									longitude: event.latLng.lng()
								};
								setSimulationPoint(point);
								initialState.onSimulationPointChange?.(point);
							})
						: null;

					const controller: PatientLocationMapController = {
						updateLocation,
						setSimulationMode,
						setSimulationPoint
					};

					removeMapResources = () => {
						mapClickListener?.remove();
						if (simulationMarker) {
							simulationMarker.map = null;
							simulationMarker.remove();
						}
						marker.map = null;
						marker.remove();
						accuracyCircle.setMap(null);
						for (const circle of safeZoneCircles) circle.setMap(null);
						for (const polyline of routePolylines) polyline.setMap(null);
					};
					initialState.onReady?.(controller);

					mapState = 'READY';
				} catch {
					if (!disposed) mapState = 'ERROR';
				}
			})();

			return () => {
				disposed = true;
				initialState.onReady?.(null);
				removeMapResources?.();
				element.replaceChildren();
			};
		};
	}
</script>

<section
	class="relative min-h-88 overflow-hidden rounded-3xl border border-ink/10 bg-surface-muted shadow-lg shadow-brand/5 sm:min-h-112"
	aria-label={`Mapa de ubicación, recorrido reciente y geocercas activas de ${patientName}`}
	aria-busy={mapState === 'LOADING'}
>
	<div
		class="absolute inset-0"
		{@attach createMapAttachment(retryKey)}
		aria-label={`Google Maps con la ubicación, el recorrido reciente y las geocercas activas de ${patientName}`}
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
				<p class="mt-1 text-sm leading-6 text-muted">Preparando la ubicación del paciente.</p>
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
