<script lang="ts">
	import { enhance, type SubmitFunction } from '$app/forms';
	import { resolve } from '$app/paths';
	import PatientLocationRealtime, {
		type LocationRealtimeRow,
		type LocationRealtimeState
	} from '#lib/locations/PatientLocationRealtime.svelte';
	import { presentLocationTime } from '#lib/locations/presentation.js';
	import PatientLocationMap, {
		type MapHistorySegment,
		type MapSimulationPoint,
		type PatientLocationMapController
	} from '#lib/maps/PatientLocationMap.svelte';
	import type { PageProps } from './$types';

	type LatestLocation = NonNullable<PageProps['data']['latestLocation']>;
	type HistoryLocation = PageProps['data']['locationHistory'][number];
	type RealtimeState = 'IDLE' | LocationRealtimeState;
	type SimulatorFeedback = { kind: 'success' | 'error'; message: string };

	const defaultMapCenter = { latitude: 18.4861, longitude: -69.9312 };

	let { data }: PageProps = $props();
	let patientName = $derived(`${data.patient.firstName} ${data.patient.lastName}`);
	let latestLocation = $derived(data.latestLocation);
	let locationHistory = $derived(data.locationHistory);
	let historySegments = $derived(buildHistorySegments(locationHistory));
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
						onLocation={handleRealtimeLocation}
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
			{:else if !latestLocation && !data.manualLocationSimulatorEnabled}
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
								hasLocation={latestLocation !== null}
								manualSimulationEnabled={data.manualLocationSimulatorEnabled}
								onSimulationPointChange={handleSimulationPointChange}
								onReady={handleMapReady}
							/>
						{/key}

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
									El dispositivo está listo. Usa el modo de prueba para enviar la primera lectura.
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
