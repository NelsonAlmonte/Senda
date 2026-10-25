<script module lang="ts">
	export type SafeZoneMapItem = {
		id: string;
		name: string;
		centerLatitude: number;
		centerLongitude: number;
		radiusM: number;
		isActive: boolean;
	};

	export type SafeZoneDraft = {
		centerLatitude: number;
		centerLongitude: number;
		radiusM: number;
	};

	export type SafeZoneEditorMapController = {
		setZones: (zones: SafeZoneMapItem[], selectedZoneId: string | null) => void;
		setDraft: (draft: SafeZoneDraft | null) => void;
		setSelectionMode: (enabled: boolean) => void;
		fitDraft: () => void;
	};
</script>

<script lang="ts">
	import { untrack } from 'svelte';
	import type { Attachment } from 'svelte/attachments';
	import { SvelteMap } from 'svelte/reactivity';
	import { loadMapsLibrary } from './loader';

	type Props = {
		latitude: number;
		longitude: number;
		patientName: string;
		zones: SafeZoneMapItem[];
		selectedZoneId: string | null;
		draft: SafeZoneDraft | null;
		selectionMode: boolean;
		onCenterSelected?: (point: { latitude: number; longitude: number }) => void;
		onDraftCenterChanged?: (point: { latitude: number; longitude: number }) => void;
		onZoneSelected?: (zoneId: string) => void;
		onReady?: (controller: SafeZoneEditorMapController | null) => void;
	};

	type MapClickEvent = {
		latLng: { lat: () => number; lng: () => number } | null;
	};

	let {
		latitude,
		longitude,
		patientName,
		zones,
		selectedZoneId,
		draft,
		selectionMode,
		onCenterSelected,
		onDraftCenterChanged,
		onZoneSelected,
		onReady
	}: Props = $props();
	let mapState = $state<'LOADING' | 'READY' | 'ERROR'>('LOADING');
	let retryKey = $state(0);
	let controller = $state.raw<SafeZoneEditorMapController | null>(null);

	$effect(() => {
		const currentController = controller;
		const nextZones = zones;
		const nextSelectedZoneId = selectedZoneId;
		const nextDraft = draft;
		const nextSelectionMode = selectionMode;
		if (!currentController) return;

		untrack(() => {
			currentController.setZones(nextZones, nextSelectedZoneId);
			currentController.setDraft(nextDraft);
			currentController.setSelectionMode(nextSelectionMode);
		});
	});

	function createMapAttachment(_retryKey: number): Attachment<HTMLDivElement> {
		void _retryKey;

		return (element) => {
			const initialState = untrack(() => ({
				center: { lat: latitude, lng: longitude },
				zones,
				selectedZoneId,
				draft,
				selectionMode
			}));
			let disposed = false;
			let cleanup: (() => void) | null = null;

			mapState = 'LOADING';

			void (async () => {
				try {
					const { Map: GoogleMap, Circle } = await loadMapsLibrary();
					if (disposed) return;

					const map = new GoogleMap(element, {
						center: initialState.center,
						zoom: 15,
						mapId: 'DEMO_MAP_ID',
						clickableIcons: false,
						fullscreenControl: true,
						mapTypeControl: false,
						streetViewControl: false,
						gestureHandling: 'greedy'
					});

					type CircleInstance = InstanceType<typeof Circle>;
					type Listener = { remove: () => void };
					const zoneCircles = new SvelteMap<
						string,
						{ circle: CircleInstance; listener: Listener }
					>();
					let draftCircle: CircleInstance | null = null;
					let draftDragListener: Listener | null = null;
					let centerSelectionEnabled = initialState.selectionMode;
					let currentZones = initialState.zones;
					let currentSelectedZoneId = initialState.selectedZoneId;

					const zoneOptions = (zone: SafeZoneMapItem, isSelected: boolean) => ({
						map: zone.isActive || isSelected ? map : null,
						center: { lat: zone.centerLatitude, lng: zone.centerLongitude },
						radius: zone.radiusM,
						clickable: !centerSelectionEnabled,
						fillColor: zone.isActive ? '#8fbfaf' : '#cbd5e1',
						fillOpacity: isSelected ? 0.32 : 0.16,
						strokeColor: zone.isActive ? '#355f55' : '#64748b',
						strokeOpacity: isSelected ? 1 : 0.65,
						strokeWeight: isSelected ? 4 : 2,
						zIndex: isSelected ? 3 : 1
					});

					const setZones = (nextZones: SafeZoneMapItem[], nextSelectedZoneId: string | null) => {
						currentZones = nextZones;
						currentSelectedZoneId = nextSelectedZoneId;
						const nextIds = new Set(nextZones.map((zone) => zone.id));
						for (const [zoneId, entry] of zoneCircles) {
							if (nextIds.has(zoneId)) continue;
							entry.listener.remove();
							entry.circle.setMap(null);
							zoneCircles.delete(zoneId);
						}

						for (const zone of nextZones) {
							const options = zoneOptions(zone, zone.id === nextSelectedZoneId);
							const current = zoneCircles.get(zone.id);
							if (current) {
								current.circle.setOptions(options);
								continue;
							}

							const circle = new Circle(options);
							const listener = circle.addListener('click', () => onZoneSelected?.(zone.id));
							zoneCircles.set(zone.id, { circle, listener });
						}
					};

					const setDraft = (nextDraft: SafeZoneDraft | null) => {
						if (!nextDraft) {
							draftCircle?.setMap(null);
							return;
						}

						const options = {
							map,
							center: { lat: nextDraft.centerLatitude, lng: nextDraft.centerLongitude },
							radius: nextDraft.radiusM,
							clickable: !centerSelectionEnabled,
							draggable: !centerSelectionEnabled,
							fillColor: '#f5c451',
							fillOpacity: 0.25,
							strokeColor: '#92400e',
							strokeOpacity: 0.95,
							strokeWeight: 3,
							zIndex: 4
						};

						if (draftCircle) {
							draftCircle.setOptions(options);
						} else {
							draftCircle = new Circle(options);
							draftDragListener = draftCircle.addListener('dragend', () => {
								const center = draftCircle?.getCenter();
								if (!center) return;

								onDraftCenterChanged?.({
									latitude: center.lat(),
									longitude: center.lng()
								});
							});
						}
					};

					const setSelectionMode = (enabled: boolean) => {
						centerSelectionEnabled = enabled;
						map.setOptions({ draggableCursor: enabled ? 'crosshair' : null });
						setZones(currentZones, currentSelectedZoneId);
						draftCircle?.setOptions({
							clickable: !enabled,
							draggable: !enabled
						});
					};

					const fitDraft = () => {
						const bounds = draftCircle?.getBounds();
						if (bounds) map.fitBounds(bounds, 56);
					};

					const mapClickListener = map.addListener('click', (event: MapClickEvent) => {
						if (!centerSelectionEnabled || !event.latLng) return;
						onCenterSelected?.({
							latitude: event.latLng.lat(),
							longitude: event.latLng.lng()
						});
					});

					const nextController: SafeZoneEditorMapController = {
						setZones,
						setDraft,
						setSelectionMode,
						fitDraft
					};

					setZones(initialState.zones, initialState.selectedZoneId);
					setDraft(initialState.draft);
					setSelectionMode(initialState.selectionMode);
					controller = nextController;
					onReady?.(nextController);
					mapState = 'READY';

					cleanup = () => {
						mapClickListener.remove();
						draftDragListener?.remove();
						for (const entry of zoneCircles.values()) {
							entry.listener.remove();
							entry.circle.setMap(null);
						}
						draftCircle?.setMap(null);
					};
				} catch {
					if (!disposed) mapState = 'ERROR';
				}
			})();

			return () => {
				disposed = true;
				controller = null;
				onReady?.(null);
				cleanup?.();
				element.replaceChildren();
			};
		};
	}
</script>

<section
	class="relative min-h-88 overflow-hidden rounded-3xl border border-ink/10 bg-surface-muted shadow-lg shadow-brand/5 sm:min-h-120"
	aria-label={`Editor de geocercas de ${patientName}`}
	aria-busy={mapState === 'LOADING'}
>
	<div
		class="absolute inset-0"
		{@attach createMapAttachment(retryKey)}
		aria-label={`Google Maps para configurar las geocercas de ${patientName}`}
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
				<p class="mt-1 text-sm leading-6 text-muted">Preparando el editor de geocercas.</p>
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
					Comprueba tu conexión y vuelve a intentarlo. Tus geocercas guardadas no se modificaron.
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
