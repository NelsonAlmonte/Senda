<script lang="ts">
	import { enhance, type SubmitFunction } from '$app/forms';
	import { resolve } from '$app/paths';
	import { BellRing, MapPinPlus, MapPinned, Route, ShieldCheck } from '@lucide/svelte';
	import Heading from '#lib/components/ui/Heading.svelte';
	import PatientLocationRealtime, {
		type AlertEpisodeRealtimeRow,
		type LocationRealtimeRow
	} from '#lib/locations/PatientLocationRealtime.svelte';
	import {
		presentDateTime,
		presentGeofenceRelation,
		presentLocationTime
	} from '#lib/locations/presentation.js';
	import PatientLocationMap, {
		type MapHistorySegment,
		type MapManualLocationPoint,
		type PatientLocationMapController
	} from '#lib/maps/PatientLocationMap.svelte';
	import type { PageProps } from './$types';

	type LatestLocation = NonNullable<PageProps['data']['latestLocation']>;
	type HistoryLocation = PageProps['data']['locationHistory'][number];
	type AlertEpisode = PageProps['data']['alertEpisodes'][number];
	type ManualLocationFeedback = { kind: 'success' | 'error'; message: string };

	const defaultMapCenter = { latitude: 18.4861, longitude: -69.9312 };

	let { data }: PageProps = $props();
	let patientName = $derived(`${data.patient.firstName} ${data.patient.lastName}`);
	let latestLocation = $derived(data.latestLocation);
	let locationHistory = $derived(data.locationHistory);
	let alertEpisodes = $derived(data.alertEpisodes);
	let activeAlertEpisode = $derived(
		alertEpisodes.find((episode) => episode.status === 'OPEN') ?? null
	);
	let historySegments = $derived(buildHistorySegments(locationHistory));
	let matchedSafeZoneName = $derived(
		data.safeZones.find((zone) => zone.id === latestLocation?.matchedSafeZoneId)?.name ?? null
	);
	let geofencePresentation = $derived(
		latestLocation
			? presentGeofenceRelation(
					latestLocation.geofenceRelation,
					matchedSafeZoneName,
					latestLocation.effectiveToleranceM
				)
			: null
	);
	let mapController = $state<PatientLocationMapController | null>(null);
	let manualLocationMode = $state(false);
	let manualLocationSubmitting = $state(false);
	let manualLocationFeedback = $state<ManualLocationFeedback | null>(null);
	let latitudeInput = $state<number | undefined>();
	let longitudeInput = $state<number | undefined>();
	let selectedManualLocationPoint = $derived(
		parseManualLocationPoint(latitudeInput, longitudeInput)
	);
	let mapCenter = $derived(
		latestLocation
			? { latitude: latestLocation.latitude, longitude: latestLocation.longitude }
			: defaultMapCenter
	);

	function isNewerLocation(candidate: LatestLocation, current: LatestLocation | null): boolean {
		if (!current) return true;

		const candidateTime = Date.parse(candidate.recordedAt);
		const currentTime = Date.parse(current.recordedAt);
		return (
			candidateTime > currentTime || (candidateTime === currentTime && candidate.id > current.id)
		);
	}

	function presentRealtimeLocation(row: LocationRealtimeRow): LatestLocation {
		return {
			id: row.id,
			latitude: row.latitude,
			longitude: row.longitude,
			accuracyM: row.accuracy_m,
			recordedAt: row.recorded_at,
			receivedAt: row.received_at,
			source: row.source,
			geofenceRelation: row.geofence_relation,
			matchedSafeZoneId: row.matched_safe_zone_id,
			distanceToBoundaryM: row.distance_to_boundary_m,
			effectiveToleranceM: row.effective_tolerance_m,
			geofenceEvaluatedAt: row.geofence_evaluated_at,
			...presentLocationTime(row.recorded_at)
		};
	}

	function presentHistoryLocation(row: LocationRealtimeRow): HistoryLocation {
		return {
			id: row.id,
			deviceAssignmentId: row.device_assignment_id,
			latitude: row.latitude,
			longitude: row.longitude,
			recordedAt: row.recorded_at,
			recordedAtLabel: presentLocationTime(row.recorded_at).recordedAtLabel
		};
	}

	function buildHistorySegments(history: HistoryLocation[]): MapHistorySegment[] {
		const assignmentOrder: string[] = [];
		const segments: Record<string, MapHistorySegment> = {};

		for (const location of history) {
			if (!segments[location.deviceAssignmentId]) {
				assignmentOrder.push(location.deviceAssignmentId);
				segments[location.deviceAssignmentId] = [];
			}

			segments[location.deviceAssignmentId].push({
				latitude: location.latitude,
				longitude: location.longitude
			});
		}

		return assignmentOrder.map((assignmentId) => segments[assignmentId]);
	}

	function mergeHistoryLocation(row: LocationRealtimeRow): HistoryLocation[] {
		const candidate = presentHistoryLocation(row);
		return [...locationHistory.filter((location) => location.id !== candidate.id), candidate]
			.sort((left, right) => {
				const timeDifference = Date.parse(left.recordedAt) - Date.parse(right.recordedAt);
				return timeDifference || left.id - right.id;
			})
			.slice(-200);
	}

	function handleRealtimeLocation(row: LocationRealtimeRow) {
		const candidate = presentRealtimeLocation(row);
		const nextHistory = mergeHistoryLocation(row);
		locationHistory = nextHistory;
		if (isNewerLocation(candidate, latestLocation)) latestLocation = candidate;

		const markerLocation = latestLocation ?? candidate;
		mapController?.updateLocation({
			latitude: markerLocation.latitude,
			longitude: markerLocation.longitude,
			accuracyM: markerLocation.accuracyM,
			patientName,
			historySegments: buildHistorySegments(nextHistory)
		});
	}

	function handleRealtimeAlertEpisode(row: AlertEpisodeRealtimeRow) {
		const episode: AlertEpisode = {
			id: row.id,
			patientId: row.patient_id,
			deviceAssignmentId: row.device_assignment_id,
			status: row.status,
			startedAt: row.started_at,
			confirmedAt: row.confirmed_at,
			resolvedAt: row.resolved_at,
			firstOutsideLocationId: row.first_outside_location_id,
			confirmedByLocationId: row.confirmed_by_location_id,
			resolvedByLocationId: row.resolved_by_location_id,
			createdAt: row.created_at,
			updatedAt: row.updated_at
		};

		alertEpisodes = [...alertEpisodes.filter((candidate) => candidate.id !== episode.id), episode]
			.sort((left, right) => Date.parse(right.confirmedAt) - Date.parse(left.confirmedAt))
			.slice(0, 5);
	}

	function handleMapReady(controller: PatientLocationMapController | null) {
		mapController = controller;
		if (!controller || !latestLocation) return;

		controller.updateLocation({
			latitude: latestLocation.latitude,
			longitude: latestLocation.longitude,
			accuracyM: latestLocation.accuracyM,
			patientName,
			historySegments,
			panToLocation: false
		});
	}

	function parseManualLocationPoint(
		latitudeValue: number | undefined,
		longitudeValue: number | undefined
	): MapManualLocationPoint | null {
		if (
			latitudeValue === undefined ||
			longitudeValue === undefined ||
			!Number.isFinite(latitudeValue) ||
			!Number.isFinite(longitudeValue) ||
			latitudeValue < -90 ||
			latitudeValue > 90 ||
			longitudeValue < -180 ||
			longitudeValue > 180
		) {
			return null;
		}

		return { latitude: latitudeValue, longitude: longitudeValue };
	}

	function activateManualLocationMode() {
		if (!mapController) return;

		manualLocationMode = true;
		manualLocationFeedback = null;
		mapController.setManualLocationMode(true);
	}

	function handleManualLocationPointChange(point: MapManualLocationPoint) {
		latitudeInput = Number(point.latitude.toFixed(6));
		longitudeInput = Number(point.longitude.toFixed(6));
		manualLocationFeedback = null;
	}

	function resetManualLocationSelection() {
		manualLocationMode = false;
		latitudeInput = undefined;
		longitudeInput = undefined;
		mapController?.setManualLocationPoint(null);
		mapController?.setManualLocationMode(false);
	}

	function cancelManualLocation() {
		resetManualLocationSelection();
		manualLocationFeedback = null;
	}

	const enhanceManualLocation: SubmitFunction = () => {
		manualLocationSubmitting = true;
		manualLocationFeedback = null;

		return async ({ result, update }) => {
			manualLocationSubmitting = false;

			if (result.type === 'success') {
				const resultData = result.data as { message?: string } | undefined;
				resetManualLocationSelection();
				manualLocationFeedback = {
					kind: 'success',
					message:
						resultData?.message ?? 'Ubicación guardada. El mapa se actualizará automáticamente.'
				};
			} else if (result.type === 'failure') {
				const resultData = result.data as { message?: string } | undefined;
				manualLocationFeedback = {
					kind: 'error',
					message: resultData?.message ?? 'No pudimos guardar la ubicación. Inténtalo nuevamente.'
				};
			}

			await update({ reset: false, refreshAll: false });
		};
	};
</script>

<svelte:head>
	<title>Mapa de {patientName} | Senda</title>
	<meta
		name="description"
		content={`Consulta la última ubicación y el recorrido reciente de ${patientName} en Senda.`}
	/>
</svelte:head>

<main id="contenido-principal" class="px-5 py-6 sm:px-8 lg:px-0">
	<div class="w-full">
		<div class="max-w-3xl">
			<h2 id="patient-data-title" class="mb-8 text-2xl font-bold text-ink">
				Recorrido del paciente
			</h2>
		</div>
		<section>
			{#if data.assignment && data.locationsAvailable}
				{#key data.assignment.id}
					<PatientLocationRealtime
						assignmentId={data.assignment.id}
						patientId={data.patient.id}
						onLocation={handleRealtimeLocation}
						onAlertEpisode={handleRealtimeAlertEpisode}
					/>
				{/key}
			{/if}

			{#if !data.assignment}
				<div class="rounded-2xl bg-white p-6 shadow-sm">
					<h2 class="text-xl font-bold text-ink">Sin dispositivo configurado</h2>
					<p class="mt-2 max-w-2xl leading-7 text-muted">
						Todavía no existe una asignación activa que pueda enviar ubicaciones para este paciente.
					</p>
					{#if data.patient.accessRole === 'ADMIN'}
						<a
							href={resolve('/patients/[id]/device', { id: data.patient.id })}
							class="mt-5 inline-flex min-h-12 items-center justify-center rounded-xl bg-brand px-5 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none"
						>
							Configurar dispositivo
						</a>
					{/if}
				</div>
			{:else if !data.locationsAvailable}
				<div class="rounded-2xl bg-white p-6 text-amber-950 shadow-sm" role="alert">
					<h2 class="text-xl font-bold">No pudimos consultar la ubicación</h2>
					<p class="mt-2 max-w-2xl leading-7">
						El paciente y su dispositivo siguen disponibles. Inténtalo nuevamente en unos minutos.
					</p>
					<a
						href={resolve('/patients/[id]/map', { id: data.patient.id })}
						class="mt-5 inline-flex min-h-12 items-center justify-center rounded-xl bg-brand px-5 font-bold text-white focus:ring-4 focus:ring-focus/35 focus:outline-none"
					>
						Reintentar
					</a>
				</div>
			{:else if !latestLocation && !data.manualLocationEnabled && data.safeZones.length === 0}
				<div class="rounded-2xl bg-white p-6 shadow-sm">
					<h2 class="text-xl font-bold text-ink">Aún no hay ubicaciones</h2>
					<p class="mt-2 max-w-2xl leading-7 text-muted">
						El dispositivo está configurado, pero todavía no ha enviado una ubicación. Esta pantalla
						la mostrará cuando llegue la primera lectura.
					</p>
				</div>
			{:else}
				{#key data.assignment.id}
					<PatientLocationMap
						latitude={mapCenter.latitude}
						longitude={mapCenter.longitude}
						accuracyM={latestLocation?.accuracyM ?? null}
						{patientName}
						{historySegments}
						safeZones={data.safeZones}
						hasLocation={latestLocation !== null}
						manualLocationEnabled={data.manualLocationEnabled}
						onManualLocationPointChange={handleManualLocationPointChange}
						onReady={handleMapReady}
					/>
				{/key}

				<div class="mt-6 grid items-start gap-6 xl:grid-cols-12">
					<div class="space-y-6 xl:col-span-8">
						<section class="rounded-2xl bg-white p-6 shadow-sm">
							<Heading
								icon={MapPinned}
								title="Estado de ubicación"
								subtitle="Resumen de la última lectura y su relación con las zonas permitidas."
							/>
							<div class="mt-6 grid gap-4 md:grid-cols-3">
								<div class="rounded-2xl bg-surface-muted p-4">
									<p class="text-sm font-semibold text-muted">Última ubicación</p>
									{#if !latestLocation}
										<p class="mt-1 font-bold text-ink">Aún no disponible</p>
										<p class="mt-1 text-sm leading-6 text-muted">
											{data.manualLocationEnabled
												? 'Puedes registrar la primera ubicación desde el mapa.'
												: 'El mapa se actualizará al recibir la primera lectura.'}
										</p>
									{:else if latestLocation.freshness === 'FRESH'}
										<p class="mt-1 font-bold text-ink">Ubicación reciente</p>
										<p class="mt-1 text-sm leading-6 text-muted">
											Última lectura {latestLocation.ageLabel}.
										</p>
									{:else}
										<p class="mt-1 font-bold text-amber-950">Ubicación desactualizada</p>
										<p class="mt-1 text-sm leading-6 text-muted">
											La última lectura fue {latestLocation.ageLabel}. No representa una posición en
											vivo.
										</p>
									{/if}
								</div>

								<div
									class={[
										'rounded-2xl p-4',
										!data.alertEpisodesAvailable || activeAlertEpisode
											? 'bg-amber-50'
											: 'bg-surface-muted'
									]}
									role={!data.alertEpisodesAvailable ? 'alert' : 'status'}
									aria-live="polite"
								>
									<p class="text-sm font-semibold text-muted">Episodio de salida</p>
									{#if !data.alertEpisodesAvailable}
										<p class="mt-1 font-bold text-amber-950">Estado no disponible</p>
										<p class="mt-1 text-sm leading-6 text-muted">
											No pudimos verificar los episodios en este momento.
										</p>
									{:else if activeAlertEpisode}
										<p class="mt-1 font-bold text-amber-950">Salida confirmada activa</p>
										<p class="mt-1 text-sm leading-6 text-muted">
											Confirmada el {presentDateTime(activeAlertEpisode.confirmedAt)}.
										</p>
									{:else}
										<p class="mt-1 font-bold text-ink">Sin episodio activo</p>
										<p class="mt-1 text-sm leading-6 text-muted">
											No existe una salida confirmada activa.
										</p>
									{/if}
								</div>

								<div class="rounded-2xl bg-surface-muted p-4" role="status" aria-live="polite">
									<p class="text-sm font-semibold text-muted">Relación con geocercas</p>
									{#if latestLocation && geofencePresentation}
										<p class="mt-1 font-bold text-ink">{geofencePresentation.title}</p>
										<p class="mt-1 text-sm leading-6 text-muted">
											{geofencePresentation.description}
										</p>
									{:else}
										<p class="mt-1 font-bold text-ink">Pendiente de una ubicación</p>
										<p class="mt-1 text-sm leading-6 text-muted">
											Se evaluará cuando exista una lectura disponible.
										</p>
									{/if}
								</div>
							</div>
						</section>

						<section class="rounded-2xl bg-white p-6 shadow-sm">
							<Heading
								icon={ShieldCheck}
								title="Geocercas activas"
								subtitle="Zonas permitidas visibles sobre el mapa del paciente."
							/>
							<div class="mt-6">
								{#if !data.safeZonesAvailable}
									<p class="text-sm leading-6 text-amber-900" role="alert">
										No pudimos consultar las geocercas. La ubicación sigue disponible.
									</p>
								{:else if data.safeZones.length === 0}
									<p class="text-sm leading-6 text-muted">
										No hay zonas activas para mostrar. Esto no significa que el paciente esté en una
										zona segura.
									</p>
								{:else}
									<ul class="flex flex-wrap gap-2" aria-label="Geocercas visibles en el mapa">
										{#each data.safeZones as zone (zone.id)}
											<li
												class="rounded-full bg-surface-muted px-3 py-2 text-sm font-semibold text-ink"
											>
												{zone.name} · {zone.radiusM.toLocaleString('es-DO')} m
											</li>
										{/each}
									</ul>
								{/if}
							</div>
							<div class="mt-6 border-t border-ink/10 pt-4">
								<a
									href={resolve('/patients/[id]/safe-zones', { id: data.patient.id })}
									class="inline-flex min-h-12 items-center justify-center rounded-xl bg-brand px-5 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none"
								>
									Configurar geocercas
								</a>
							</div>
						</section>

						{#if data.manualLocationEnabled}
							<section class="rounded-2xl bg-white p-6 shadow-sm">
								<Heading
									icon={MapPinPlus}
									title="Registrar ubicación manual"
									subtitle="Selecciona directamente en el mapa el punto que deseas guardar."
								/>

								{#if !manualLocationMode}
									<div class="mt-6 border-t border-ink/10 pt-4">
										<button
											type="button"
											onclick={activateManualLocationMode}
											disabled={!mapController}
											class="min-h-12 cursor-pointer rounded-xl bg-brand px-5 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
										>
											{mapController ? 'Elegir ubicación en el mapa' : 'Esperando el mapa…'}
										</button>
									</div>
								{:else}
									<form
										method="POST"
										action="?/saveManualLocation"
										use:enhance={enhanceManualLocation}
										class="mt-6 border-t border-ink/10 pt-4"
									>
										<p class="text-sm leading-6 font-semibold text-ink">
											Haz clic o toca el mapa para elegir la ubicación.
										</p>
										<input type="hidden" name="latitude" value={latitudeInput ?? ''} />
										<input type="hidden" name="longitude" value={longitudeInput ?? ''} />

										{#if selectedManualLocationPoint}
											<p
												class="mt-3 rounded-2xl bg-surface-muted p-4 text-sm font-semibold text-ink"
												role="status"
											>
												Ubicación seleccionada. Puedes guardarla o elegir otro punto en el mapa.
											</p>
										{/if}

										<div class="mt-4 flex flex-col gap-3 sm:flex-row">
											<button
												type="submit"
												disabled={manualLocationSubmitting || !selectedManualLocationPoint}
												class="min-h-12 cursor-pointer rounded-xl bg-brand px-5 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
											>
												{manualLocationSubmitting ? 'Guardando ubicación…' : 'Guardar ubicación'}
											</button>
											<button
												type="button"
												onclick={cancelManualLocation}
												disabled={manualLocationSubmitting}
												class="min-h-12 cursor-pointer rounded-xl border border-ink/15 bg-white px-5 font-bold text-ink transition hover:bg-surface-muted focus:ring-4 focus:ring-focus/30 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
											>
												Cancelar
											</button>
										</div>
									</form>
								{/if}

								{#if manualLocationFeedback}
									<div
										class={[
											'mt-5 rounded-2xl p-4 text-sm leading-6 font-semibold',
											manualLocationFeedback.kind === 'success'
												? 'bg-surface-muted text-ink'
												: 'bg-red-50 text-red-950'
										]}
										role={manualLocationFeedback.kind === 'error' ? 'alert' : 'status'}
										aria-live="polite"
									>
										{manualLocationFeedback.message}
									</div>
								{/if}
							</section>
						{/if}
					</div>

					<aside class="space-y-6 xl:col-span-4">
						<section class="rounded-2xl bg-white p-6 shadow-sm">
							<Heading
								icon={BellRing}
								title="Episodios recientes"
								subtitle="Las cinco salidas confirmadas más recientes."
							/>
							{#if !data.alertEpisodesAvailable}
								<p class="mt-6 text-sm leading-6 text-amber-900" role="alert">
									El historial no está disponible en este momento.
								</p>
							{:else if alertEpisodes.length === 0}
								<p class="mt-6 text-sm leading-6 text-muted">
									Todavía no se ha confirmado ninguna salida de las zonas permitidas.
								</p>
							{:else}
								<ul class="mt-6 space-y-3">
									{#each alertEpisodes as episode (episode.id)}
										<li class="rounded-2xl bg-surface-muted p-4 text-sm">
											<p class="font-bold text-ink">
												{episode.status === 'OPEN' ? 'Salida activa' : 'Salida resuelta'}
											</p>
											<p class="mt-1 leading-6 text-muted">
												Confirmada el {presentDateTime(episode.confirmedAt)}.
												{#if episode.resolvedAt}
													Resuelta el {presentDateTime(episode.resolvedAt)}.
												{/if}
											</p>
										</li>
									{/each}
								</ul>
							{/if}
							<div class="mt-6 border-t border-ink/10 pt-4">
								<button
									type="button"
									disabled
									title="Historial completo pendiente de implementación"
									class="min-h-12 w-full cursor-not-allowed rounded-xl bg-surface-muted px-5 font-bold text-muted opacity-70"
								>
									Ver todos los episodios
								</button>
								<p class="mt-2 text-center text-xs text-muted">Historial completo próximamente.</p>
							</div>
						</section>

						<section class="rounded-2xl bg-white p-6 shadow-sm">
							<Heading
								icon={Route}
								title="Recorrido reciente"
								subtitle="Resumen del trayecto representado sobre el mapa."
							/>
							{#if !data.historyAvailable}
								<p class="mt-6 text-sm leading-6 text-amber-900" role="alert">
									No pudimos consultar el historial. La última ubicación sigue disponible.
								</p>
							{:else if locationHistory.length === 0}
								<p class="mt-6 text-sm leading-6 text-muted">Aún no hay lecturas para trazar.</p>
							{:else}
								<p class="mt-6 text-sm leading-6 text-muted">
									{locationHistory.length}
									{locationHistory.length === 1 ? 'lectura mostrada' : 'lecturas mostradas'}.
								</p>
								<dl class="mt-4 grid gap-4 text-sm sm:grid-cols-2 xl:grid-cols-1">
									<div class="rounded-2xl bg-surface-muted p-4">
										<dt class="font-semibold text-muted">Desde</dt>
										<dd class="mt-1 text-ink">
											<time datetime={locationHistory[0].recordedAt}
												>{locationHistory[0].recordedAtLabel}</time
											>
										</dd>
									</div>
									<div class="rounded-2xl bg-surface-muted p-4">
										<dt class="font-semibold text-muted">Hasta</dt>
										<dd class="mt-1 text-ink">
											<time datetime={locationHistory.at(-1)?.recordedAt}
												>{locationHistory.at(-1)?.recordedAtLabel}</time
											>
										</dd>
									</div>
								</dl>
								{#if locationHistory.length === 1}
									<p class="mt-4 text-sm leading-6 text-muted">
										Se necesita otra lectura para dibujar el recorrido.
									</p>
								{:else}
									<p class="mt-4 text-sm leading-6 text-muted">
										La línea une lecturas consecutivas de una misma asignación; no representa una
										conexión continua.
									</p>
								{/if}
							{/if}
							{#if latestLocation?.accuracyM !== null && latestLocation?.accuracyM !== undefined && latestLocation.accuracyM > 0}
								<p class="mt-6 border-t border-ink/10 pt-4 text-sm leading-6 text-muted">
									El círculo azul representa la precisión informada. No es una zona permitida.
								</p>
							{/if}
						</section>
					</aside>
				</div>
			{/if}
		</section>
	</div>
</main>
