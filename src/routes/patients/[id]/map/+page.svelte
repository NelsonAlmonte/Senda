<script lang="ts">
	import { enhance, type SubmitFunction } from '$app/forms';
	import { resolve } from '$app/paths';
	import PatientLocationRealtime, {
		type AlertEpisodeRealtimeRow,
		type LocationRealtimeRow,
		type LocationRealtimeState
	} from '#lib/locations/PatientLocationRealtime.svelte';
	import {
		presentDateTime,
		presentGeofenceRelation,
		presentLocationTime
	} from '#lib/locations/presentation.js';
	import PatientLocationMap, {
		type MapHistorySegment,
		type MapSimulationPoint,
		type PatientLocationMapController
	} from '#lib/maps/PatientLocationMap.svelte';
	import type { PageProps } from './$types';

	type LatestLocation = NonNullable<PageProps['data']['latestLocation']>;
	type HistoryLocation = PageProps['data']['locationHistory'][number];
	type AlertEpisode = PageProps['data']['alertEpisodes'][number];
	type RealtimeState = 'IDLE' | LocationRealtimeState;
	type SimulatorFeedback = { kind: 'success' | 'error'; message: string };

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
	let realtimeState = $state<RealtimeState>('IDLE');
	let mapController = $state<PatientLocationMapController | null>(null);
	let simulationMode = $state(false);
	let simulatorSubmitting = $state(false);
	let simulatorFeedback = $state<SimulatorFeedback | null>(null);
	let latitudeInput = $state<number | undefined>();
	let longitudeInput = $state<number | undefined>();
	let selectedSimulationPoint = $derived(parseSimulationPoint(latitudeInput, longitudeInput));
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
			.slice(0, 10);
	}

	function handleRealtimeState(state: LocationRealtimeState) {
		realtimeState = state;
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

	function parseSimulationPoint(
		latitudeValue: number | undefined,
		longitudeValue: number | undefined
	): MapSimulationPoint | null {
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

	function activateSimulationMode() {
		if (!mapController) return;

		simulationMode = true;
		simulatorFeedback = null;
		mapController.setSimulationMode(true);
	}

	function handleSimulationPointChange(point: MapSimulationPoint) {
		latitudeInput = Number(point.latitude.toFixed(6));
		longitudeInput = Number(point.longitude.toFixed(6));
		simulatorFeedback = null;
	}

	function syncSimulationPointFromInputs() {
		simulatorFeedback = null;
		mapController?.setSimulationPoint(parseSimulationPoint(latitudeInput, longitudeInput));
	}

	function handleLatitudeInput(event: Event & { currentTarget: HTMLInputElement }) {
		latitudeInput = Number.isNaN(event.currentTarget.valueAsNumber)
			? undefined
			: event.currentTarget.valueAsNumber;
		syncSimulationPointFromInputs();
	}

	function handleLongitudeInput(event: Event & { currentTarget: HTMLInputElement }) {
		longitudeInput = Number.isNaN(event.currentTarget.valueAsNumber)
			? undefined
			: event.currentTarget.valueAsNumber;
		syncSimulationPointFromInputs();
	}

	function resetSimulationSelection() {
		simulationMode = false;
		latitudeInput = undefined;
		longitudeInput = undefined;
		mapController?.setSimulationPoint(null);
		mapController?.setSimulationMode(false);
	}

	function cancelSimulation() {
		resetSimulationSelection();
		simulatorFeedback = null;
	}

	const enhanceSimulation: SubmitFunction = () => {
		simulatorSubmitting = true;
		simulatorFeedback = null;

		return async ({ result, update }) => {
			simulatorSubmitting = false;

			if (result.type === 'success') {
				const resultData = result.data as { message?: string } | undefined;
				resetSimulationSelection();
				simulatorFeedback = {
					kind: 'success',
					message:
						resultData?.message ??
						'Ubicación simulada enviada. El mapa se actualizará al recibirla por Realtime.'
				};
			} else if (result.type === 'failure') {
				const resultData = result.data as { message?: string } | undefined;
				simulatorFeedback = {
					kind: 'error',
					message:
						resultData?.message ?? 'No pudimos guardar la ubicación simulada. Inténtalo nuevamente.'
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

<main id="contenido-principal" class="min-h-dvh px-5 py-6 sm:px-8 lg:px-12">
	<div class="mx-auto w-full max-w-6xl">
		<header class="flex flex-wrap items-center justify-between gap-4 border-b border-ink/10 pb-5">
			<a
				href={resolve('/dashboard')}
				class="inline-flex min-h-12 items-center rounded-xl font-bold text-brand focus:ring-4 focus:ring-focus/30 focus:outline-none"
			>
				<span aria-hidden="true">←</span><span class="ml-2">Volver al panel</span>
			</a>
			<p class="text-sm font-semibold text-muted">
				Tu acceso: {data.patient.accessRole === 'ADMIN' ? 'Administrador' : 'Monitor'}
			</p>
		</header>

		<section class="py-8 sm:py-12">
			<p class="text-sm font-bold tracking-[0.14em] text-brand uppercase">Última ubicación</p>
			<h1 class="mt-2 text-3xl font-bold tracking-tight text-ink sm:text-4xl">
				Mapa de {patientName}
			</h1>
			<p class="mt-3 max-w-2xl leading-7 text-muted">
				{data.patient.groupName ?? 'Grupo no disponible'} · El mapa se actualiza cuando Senda recibe una
				nueva lectura; no garantiza seguimiento continuo.
			</p>

			{#if data.assignment && data.locationsAvailable}
				{#key data.assignment.id}
					<PatientLocationRealtime
						assignmentId={data.assignment.id}
						patientId={data.patient.id}
						onLocation={handleRealtimeLocation}
						onAlertEpisode={handleRealtimeAlertEpisode}
						onStateChange={handleRealtimeState}
					/>
				{/key}

				<div
					class="mt-5 inline-flex items-center gap-2 rounded-full border border-ink/10 bg-white px-4 py-2 text-sm font-semibold text-muted shadow-sm"
					role="status"
					aria-live="polite"
					aria-atomic="true"
				>
					<span
						class={[
							'size-2.5 shrink-0 rounded-full',
							realtimeState === 'CONNECTED'
								? 'bg-brand'
								: realtimeState === 'ERROR'
									? 'bg-amber-700'
									: 'animate-pulse bg-muted motion-reduce:animate-none'
						]}
						aria-hidden="true"
					></span>
					{#if realtimeState === 'CONNECTED'}
						Actualizaciones automáticas activas
					{:else if realtimeState === 'ERROR'}
						Actualizaciones automáticas no disponibles
					{:else}
						Conectando actualizaciones automáticas…
					{/if}
				</div>
			{/if}

			{#if !data.assignment}
				<div class="mt-8 rounded-3xl border border-white/80 bg-white p-6 shadow-lg shadow-brand/5">
					<h2 class="text-xl font-bold text-ink">Sin dispositivo configurado</h2>
					<p class="mt-2 max-w-2xl leading-7 text-muted">
						Todavía no existe una asignación activa que pueda enviar ubicaciones para este paciente.
					</p>
					{#if data.patient.accessRole === 'ADMIN'}
						<a
							href={resolve('/patients/[id]/device', { id: data.patient.id })}
							class="mt-5 inline-flex min-h-12 items-center justify-center rounded-xl bg-brand px-5 font-bold text-white shadow-sm transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none"
						>
							Configurar dispositivo
						</a>
					{/if}
				</div>
			{:else if !data.locationsAvailable}
				<div
					class="mt-8 rounded-3xl border border-amber-700/25 bg-amber-50 p-6 text-amber-950"
					role="alert"
				>
					<h2 class="text-xl font-bold">No pudimos consultar la ubicación</h2>
					<p class="mt-2 max-w-2xl leading-7">
						El paciente y su dispositivo siguen disponibles. Inténtalo nuevamente en unos minutos.
					</p>
					<a
						href={resolve('/patients/[id]/map', { id: data.patient.id })}
						class="mt-5 inline-flex min-h-12 items-center justify-center rounded-xl bg-amber-950 px-5 font-bold text-white focus:ring-4 focus:ring-amber-900/30 focus:outline-none"
					>
						Reintentar
					</a>
				</div>
			{:else if !latestLocation && !data.manualLocationSimulatorEnabled && data.safeZones.length === 0}
				<div class="mt-8 rounded-3xl border border-white/80 bg-white p-6 shadow-lg shadow-brand/5">
					<h2 class="text-xl font-bold text-ink">Aún no hay ubicaciones</h2>
					<p class="mt-2 max-w-2xl leading-7 text-muted">
						El dispositivo {data.assignment.device.serialNumber} está configurado, pero todavía no ha
						enviado una posición. Esta pantalla la mostrará cuando llegue la primera lectura.
					</p>
				</div>
			{:else}
				<div class="mt-8 grid items-start gap-6 lg:grid-cols-[minmax(0,1fr)_20rem]">
					<div class="min-w-0 space-y-6">
						{#key data.assignment.id}
							<PatientLocationMap
								latitude={mapCenter.latitude}
								longitude={mapCenter.longitude}
								accuracyM={latestLocation?.accuracyM ?? null}
								{patientName}
								{historySegments}
								safeZones={data.safeZones}
								hasLocation={latestLocation !== null}
								manualSimulationEnabled={data.manualLocationSimulatorEnabled}
								onSimulationPointChange={handleSimulationPointChange}
								onReady={handleMapReady}
							/>
						{/key}

						<section
							class="rounded-2xl border border-ink/10 bg-white p-4 shadow-sm"
							aria-labelledby="map-safe-zones-title"
						>
							<div class="flex flex-wrap items-center justify-between gap-3">
								<div>
									<h2 id="map-safe-zones-title" class="font-bold text-ink">Geocercas activas</h2>
									{#if !data.safeZonesAvailable}
										<p class="mt-1 text-sm leading-6 text-amber-900" role="alert">
											No pudimos consultar las geocercas. La ubicación sigue disponible.
										</p>
									{:else if data.safeZones.length === 0}
										<p class="mt-1 text-sm leading-6 text-muted">
											No hay zonas activas para mostrar. Esto no significa que el paciente esté en
											una zona segura.
										</p>
									{:else}
										<p class="mt-1 flex items-center gap-2 text-sm leading-6 text-muted">
											<span
												class="size-3 shrink-0 rounded-full border-2 border-brand bg-brand/25"
												aria-hidden="true"
											></span>
											{data.safeZones.length}
											{data.safeZones.length === 1
												? 'zona permitida visible'
												: 'zonas permitidas visibles'}
										</p>
									{/if}
								</div>
								<a
									href={resolve('/patients/[id]/safe-zones', { id: data.patient.id })}
									class="inline-flex min-h-11 items-center rounded-xl px-3 font-bold text-brand transition hover:bg-surface-muted focus:ring-4 focus:ring-focus/30 focus:outline-none"
								>
									Configurar geocercas
								</a>
							</div>
							{#if data.safeZones.length > 0}
								<ul class="mt-3 flex flex-wrap gap-2" aria-label="Geocercas visibles en el mapa">
									{#each data.safeZones as zone (zone.id)}
										<li
											class="rounded-full border border-brand/20 bg-surface-muted px-3 py-1.5 text-sm font-semibold text-ink"
										>
											{zone.name} · {zone.radiusM.toLocaleString('es-DO')} m
										</li>
									{/each}
								</ul>
							{/if}
						</section>

						{#if data.manualLocationSimulatorEnabled}
							<section
								class="rounded-3xl border border-amber-700/25 bg-amber-50 p-5 shadow-lg shadow-amber-900/5 sm:p-6"
								aria-labelledby="manual-simulator-title"
							>
								<p class="text-sm font-bold tracking-[0.12em] text-amber-900 uppercase">
									Modo de prueba
								</p>
								<h2 id="manual-simulator-title" class="mt-1 text-xl font-bold text-amber-950">
									Simular una ubicación manual
								</h2>
								<p class="mt-2 max-w-2xl text-sm leading-6 text-amber-950">
									La ubicación se guardará como una lectura real de prueba. El marcador amarillo
									solo representa el punto pendiente de confirmar.
								</p>

								{#if !simulationMode}
									<button
										type="button"
										onclick={activateSimulationMode}
										disabled={!mapController}
										class="mt-5 min-h-12 cursor-pointer rounded-xl bg-amber-950 px-5 font-bold text-white shadow-sm transition hover:bg-amber-900 focus:ring-4 focus:ring-amber-900/30 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
									>
										{mapController ? 'Elegir punto en el mapa' : 'Esperando el mapa…'}
									</button>
								{:else}
									<form
										method="POST"
										action="?/simulateLocation"
										use:enhance={enhanceSimulation}
										class="mt-5"
									>
										<p class="text-sm leading-6 font-semibold text-amber-950">
											Haz clic o toca el mapa para elegir el punto. También puedes escribir las
											coordenadas.
										</p>
										<div class="mt-4 grid gap-4 sm:grid-cols-2">
											<div>
												<label for="simulation-latitude" class="text-sm font-bold text-amber-950">
													Latitud
												</label>
												<input
													id="simulation-latitude"
													name="latitude"
													type="number"
													min="-90"
													max="90"
													step="any"
													required
													value={latitudeInput ?? ''}
													oninput={handleLatitudeInput}
													class="mt-2 min-h-12 w-full rounded-xl border border-amber-900/25 bg-white px-4 font-mono text-base text-ink outline-none focus:border-amber-900 focus:ring-4 focus:ring-amber-900/15"
												/>
											</div>
											<div>
												<label for="simulation-longitude" class="text-sm font-bold text-amber-950">
													Longitud
												</label>
												<input
													id="simulation-longitude"
													name="longitude"
													type="number"
													min="-180"
													max="180"
													step="any"
													required
													value={longitudeInput ?? ''}
													oninput={handleLongitudeInput}
													class="mt-2 min-h-12 w-full rounded-xl border border-amber-900/25 bg-white px-4 font-mono text-base text-ink outline-none focus:border-amber-900 focus:ring-4 focus:ring-amber-900/15"
												/>
											</div>
										</div>

										<div class="mt-5 flex flex-col gap-3 sm:flex-row">
											<button
												type="submit"
												disabled={simulatorSubmitting || !selectedSimulationPoint}
												class="min-h-12 cursor-pointer rounded-xl bg-amber-950 px-5 font-bold text-white shadow-sm transition hover:bg-amber-900 focus:ring-4 focus:ring-amber-900/30 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
											>
												{simulatorSubmitting ? 'Enviando ubicación…' : 'Confirmar ubicación'}
											</button>
											<button
												type="button"
												onclick={cancelSimulation}
												disabled={simulatorSubmitting}
												class="min-h-12 cursor-pointer rounded-xl border border-amber-900/25 bg-white px-5 font-bold text-amber-950 transition hover:bg-amber-100 focus:ring-4 focus:ring-amber-900/20 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
											>
												Cancelar
											</button>
										</div>
									</form>
								{/if}

								{#if simulatorFeedback}
									<div
										class={[
											'mt-5 rounded-2xl border p-4 text-sm leading-6 font-semibold',
											simulatorFeedback.kind === 'success'
												? 'border-brand/25 bg-white text-ink'
												: 'border-red-700/25 bg-red-50 text-red-950'
										]}
										role={simulatorFeedback.kind === 'error' ? 'alert' : 'status'}
										aria-live="polite"
									>
										{simulatorFeedback.message}
									</div>
								{/if}
							</section>
						{/if}
					</div>

					<aside class="rounded-3xl border border-white/80 bg-white p-6 shadow-lg shadow-brand/5">
						{#if !latestLocation}
							<div class="rounded-2xl border border-amber-700/25 bg-amber-50 p-4">
								<p class="font-bold text-amber-950">Aún no hay ubicaciones</p>
								<p class="mt-1 text-sm leading-6 text-amber-950">
									{#if data.manualLocationSimulatorEnabled}
										El dispositivo está listo. Usa el modo de prueba para enviar la primera lectura.
									{:else}
										El mapa muestra las geocercas activas, pero todavía no existe una lectura de
										ubicación.
									{/if}
								</p>
							</div>
						{:else if latestLocation.freshness === 'FRESH'}
							<div class="rounded-2xl border border-brand/20 bg-surface-muted p-4">
								<p class="font-bold text-ink">Ubicación reciente</p>
								<p class="mt-1 text-sm leading-6 text-muted">
									Última lectura {latestLocation.ageLabel}.
								</p>
							</div>
						{:else}
							<div class="rounded-2xl border border-amber-700/25 bg-amber-50 p-4">
								<p class="font-bold text-amber-950">Ubicación desactualizada</p>
								<p class="mt-1 text-sm leading-6 text-amber-950">
									La última lectura fue {latestLocation.ageLabel}. No representa una posición en
									vivo.
								</p>
							</div>
						{/if}

						<section
							class={[
								'mt-6 rounded-2xl border p-4',
								!data.alertEpisodesAvailable || activeAlertEpisode
									? 'border-amber-700/25 bg-amber-50'
									: 'border-brand/20 bg-surface-muted'
							]}
							aria-labelledby="alert-episode-title"
							role={!data.alertEpisodesAvailable ? 'alert' : 'status'}
							aria-live="polite"
							aria-atomic="true"
						>
							<p class="text-xs font-bold tracking-[0.12em] text-muted uppercase">
								Episodio de salida
							</p>
							{#if !data.alertEpisodesAvailable}
								<h2 id="alert-episode-title" class="mt-1 font-bold text-amber-950">
									No pudimos consultar los episodios
								</h2>
								<p class="mt-1 text-sm leading-6 text-amber-950">
									La ubicación sigue disponible, pero el estado de salida no pudo verificarse.
								</p>
							{:else if activeAlertEpisode}
								<h2 id="alert-episode-title" class="mt-1 font-bold text-amber-950">
									Salida confirmada activa
								</h2>
								<p class="mt-1 text-sm leading-6 text-amber-950">
									Dos lecturas confiables consecutivas quedaron fuera de las zonas permitidas. El
									episodio se confirmó el {presentDateTime(activeAlertEpisode.confirmedAt)}.
								</p>
							{:else}
								<h2 id="alert-episode-title" class="mt-1 font-bold text-ink">
									Sin episodio de salida activo
								</h2>
								<p class="mt-1 text-sm leading-6 text-muted">
									No existe una salida confirmada activa. La ubicación y su vigencia se muestran por
									separado.
								</p>
							{/if}
						</section>

						{#if latestLocation && geofencePresentation}
							<section
								class={[
									'mt-6 rounded-2xl border p-4',
									geofencePresentation.tone === 'positive'
										? 'border-brand/20 bg-surface-muted'
										: geofencePresentation.tone === 'warning'
											? 'border-amber-700/25 bg-amber-50'
											: 'border-ink/10 bg-white'
								]}
								aria-labelledby="geofence-relation-title"
								role="status"
								aria-live="polite"
								aria-atomic="true"
							>
								<p class="text-xs font-bold tracking-[0.12em] text-muted uppercase">
									Relación con geocercas
								</p>
								<h2
									id="geofence-relation-title"
									class={[
										'mt-1 font-bold',
										geofencePresentation.tone === 'warning' ? 'text-amber-950' : 'text-ink'
									]}
								>
									{geofencePresentation.title}
								</h2>
								<p
									class={[
										'mt-1 text-sm leading-6',
										geofencePresentation.tone === 'warning' ? 'text-amber-950' : 'text-muted'
									]}
								>
									{geofencePresentation.description}
								</p>
							</section>
						{/if}

						<section class="mt-6 border-t border-ink/10 pt-5" aria-labelledby="episodes-title">
							<h2 id="episodes-title" class="font-bold text-ink">Episodios recientes</h2>
							{#if !data.alertEpisodesAvailable}
								<p class="mt-2 text-sm leading-6 text-amber-900">
									El historial no está disponible en este momento.
								</p>
							{:else if alertEpisodes.length === 0}
								<p class="mt-2 text-sm leading-6 text-muted">
									Todavía no se ha confirmado ninguna salida de las zonas permitidas.
								</p>
							{:else}
								<ul class="mt-3 space-y-3">
									{#each alertEpisodes as episode (episode.id)}
										<li class="rounded-xl border border-ink/10 bg-white p-3 text-sm">
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
						</section>

						{#if latestLocation}
							<dl class="mt-6 space-y-5 text-sm">
								<div>
									<dt class="font-semibold text-muted">Coordenadas</dt>
									<dd class="mt-1 font-mono text-ink">
										{latestLocation.latitude.toFixed(5)},
										{latestLocation.longitude.toFixed(5)}
									</dd>
								</div>
								<div>
									<dt class="font-semibold text-muted">Registrada</dt>
									<dd class="mt-1 leading-6 text-ink">
										<time datetime={latestLocation.recordedAt}>
											{latestLocation.recordedAtLabel}
										</time>
									</dd>
								</div>
								<div>
									<dt class="font-semibold text-muted">Dispositivo</dt>
									<dd class="mt-1 font-mono break-all text-ink">
										{data.assignment.device.serialNumber}
									</dd>
								</div>
								{#if latestLocation.accuracyM !== null}
									<div>
										<dt class="font-semibold text-muted">Precisión informada</dt>
										<dd class="mt-1 text-ink">
											{latestLocation.accuracyM.toFixed(1)} m
										</dd>
									</div>
								{/if}
							</dl>

							{#if latestLocation.accuracyM !== null && latestLocation.accuracyM > 0}
								<p class="mt-6 border-t border-ink/10 pt-5 text-sm leading-6 text-muted">
									El círculo azul representa la precisión GPS informada. No es una zona segura.
								</p>
							{/if}
						{/if}

						<section class="mt-6 border-t border-ink/10 pt-5" aria-labelledby="history-title">
							<h2 id="history-title" class="font-bold text-ink">Recorrido reciente</h2>
							{#if !data.historyAvailable}
								<p class="mt-2 text-sm leading-6 text-amber-900" role="alert">
									No pudimos consultar el historial. La última ubicación sigue disponible.
								</p>
							{:else if locationHistory.length === 0}
								<p class="mt-2 text-sm leading-6 text-muted">Aún no hay lecturas para trazar.</p>
							{:else}
								<p class="mt-2 text-sm leading-6 text-muted">
									{locationHistory.length}
									{locationHistory.length === 1 ? 'lectura mostrada' : 'lecturas mostradas'} (máximo 200).
								</p>
								<dl class="mt-4 grid gap-4 text-sm sm:grid-cols-2 lg:grid-cols-1">
									<div>
										<dt class="font-semibold text-muted">Desde</dt>
										<dd class="mt-1 text-ink">
											<time datetime={locationHistory[0].recordedAt}>
												{locationHistory[0].recordedAtLabel}
											</time>
										</dd>
									</div>
									<div>
										<dt class="font-semibold text-muted">Hasta</dt>
										<dd class="mt-1 text-ink">
											<time datetime={locationHistory.at(-1)?.recordedAt}>
												{locationHistory.at(-1)?.recordedAtLabel}
											</time>
										</dd>
									</div>
								</dl>
								{#if locationHistory.length === 1}
									<p class="mt-4 text-sm leading-6 text-muted">
										Se necesita otra lectura para dibujar el recorrido.
									</p>
								{:else}
									<p class="mt-4 flex gap-2 text-sm leading-6 text-muted">
										<span
											class="mt-2.5 h-1 w-7 shrink-0 rounded-full bg-[#1f6f8b]"
											aria-hidden="true"
										></span>
										<span>
											La línea une lecturas consecutivas de una misma asignación; no representa una
											conexión continua.
										</span>
									</p>
								{/if}
							{/if}
						</section>
					</aside>
				</div>
			{/if}
		</section>
	</div>
</main>
