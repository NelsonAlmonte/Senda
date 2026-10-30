<script lang="ts">
	import { enhance, type SubmitFunction } from '$app/forms';
	import { resolve } from '$app/paths';
	import {
		BellRing,
		CircleAlert,
		CircleCheckBig,
		Clock3,
		MapPin,
		MapPinPlus,
		MapPinned,
		ShieldCheck,
		Siren
	} from '@lucide/svelte';
	import Alert from '#lib/components/ui/Alert.svelte';
	import Heading from '#lib/components/ui/Heading.svelte';
	import InfoItem from '#lib/components/ui/InfoItem.svelte';
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
	import type { UiTone } from '#lib/types/ui.js';
	import type { PageProps } from './$types';

	type LatestLocation = NonNullable<PageProps['data']['latestLocation']>;
	type HistoryLocation = PageProps['data']['locationHistory'][number];
	type AlertEpisode = PageProps['data']['alertEpisodes'][number];
	type ManualLocationFeedback = { kind: 'success' | 'error'; message: string };
	type StatusPresentation = { title: string; info: string; tone: UiTone };

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
	let alertStatus = $derived(
		presentAlertStatus(data.alertEpisodesAvailable, activeAlertEpisode, latestLocation)
	);
	let freshnessStatus = $derived(
		presentFreshnessStatus(latestLocation, data.manualLocationEnabled)
	);
	let readingStatus = $derived(
		presentReadingStatus(latestLocation, geofencePresentation, activeAlertEpisode !== null)
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

	function presentEpisodeInfo(episode: AlertEpisode): string {
		const confirmed = `Confirmada el ${presentDateTime(episode.confirmedAt)}.`;
		return episode.resolvedAt
			? `${confirmed} Resuelta el ${presentDateTime(episode.resolvedAt)}.`
			: confirmed;
	}

	function presentAlertStatus(
		available: boolean,
		activeEpisode: AlertEpisode | null,
		location: LatestLocation | null
	): StatusPresentation {
		if (!available) {
			return {
				title: 'Estado de alertas no disponible',
				info: 'No pudimos verificar si existe una salida activa en este momento.',
				tone: 'warning'
			};
		}

		if (activeEpisode) {
			let context = '';
			switch (location?.geofenceRelation) {
				case 'OUTSIDE':
					context = ' La última lectura continúa fuera de las zonas permitidas.';
					break;
				case 'INSIDE':
					context =
						' Se recibió una lectura dentro de una zona; hace falta otra lectura confiable consecutiva para resolver la salida.';
					break;
				case 'UNCERTAIN':
					context = ' La última lectura no permite confirmar el reingreso.';
					break;
				case 'NO_ACTIVE_ZONE':
					context = ' La última lectura no pudo compararse con una geocerca activa.';
					break;
				case 'NOT_EVALUATED':
					context = ' La última lectura no tiene una evaluación de geocerca disponible.';
					break;
			}

			return {
				title: 'Salida confirmada activa',
				info: `Confirmada el ${presentDateTime(activeEpisode.confirmedAt)}.${context}`,
				tone: 'danger'
			};
		}

		if (location?.geofenceRelation === 'OUTSIDE') {
			return {
				title: 'Salida todavía no confirmada',
				info: 'La última lectura quedó fuera de las zonas permitidas, pero no existe un episodio confirmado activo.',
				tone: 'warning'
			};
		}

		if (location?.geofenceRelation === 'UNCERTAIN') {
			return {
				title: 'Ubicación por confirmar',
				info: 'La última lectura no permite determinar si el paciente está dentro o fuera.',
				tone: 'warning'
			};
		}

		return {
			title: 'Sin salida confirmada',
			info: 'No existe un episodio de salida activo.',
			tone: 'positive'
		};
	}

	function presentFreshnessStatus(
		location: LatestLocation | null,
		manualLocationEnabled: boolean
	): StatusPresentation {
		if (!location) {
			return {
				title: 'Última actualización',
				info: manualLocationEnabled
					? 'Aún no hay ubicaciones. Puedes registrar la primera desde el mapa.'
					: 'Aún no hay ubicaciones. El mapa se actualizará al recibir la primera lectura.',
				tone: 'neutral'
			};
		}

		if (location.freshness === 'STALE') {
			return {
				title: 'Ubicación desactualizada',
				info: `La última lectura fue ${location.ageLabel}. No representa una posición en vivo.`,
				tone: 'warning'
			};
		}

		return {
			title: 'Última actualización',
			info: `Lectura recibida ${location.ageLabel}.`,
			tone: 'neutral'
		};
	}

	function presentReadingStatus(
		location: LatestLocation | null,
		presentation: typeof geofencePresentation,
		hasActiveEpisode: boolean
	): StatusPresentation {
		if (!location || !presentation) {
			return {
				title: 'Última lectura',
				info: 'Pendiente de una ubicación para evaluar las zonas permitidas.',
				tone: 'neutral'
			};
		}

		return {
			title: 'Última lectura',
			info: presentation.title,
			tone:
				location.geofenceRelation === 'OUTSIDE' && hasActiveEpisode ? 'danger' : presentation.tone
		};
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
		content={`Consulta la última ubicación y las geocercas activas de ${patientName} en Senda.`}
	/>
</svelte:head>

<main id="contenido-principal" class="px-5 py-8 sm:px-8 lg:px-0">
	<div class="w-full">
		<div class="max-w-3xl">
			<h2 id="patient-map-title" class="mb-8 text-2xl font-bold text-ink">
				Ubicación del paciente
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
				<div class="max-w-3xl rounded-2xl bg-white p-6 shadow-sm">
					<Alert
						icon={CircleAlert}
						title="No pudimos consultar la ubicación"
						subtitle="El paciente y su dispositivo siguen disponibles. Inténtalo nuevamente en unos minutos."
						color="warning"
					/>
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
								subtitle="Estado de la salida, vigencia y relación de la última lectura con las zonas permitidas."
							/>
							<div class="mt-6 space-y-4">
								<div role={!data.alertEpisodesAvailable ? 'alert' : 'status'} aria-live="polite">
									<InfoItem
										icon={activeAlertEpisode
											? Siren
											: alertStatus.tone === 'warning'
												? CircleAlert
												: BellRing}
										title={alertStatus.title}
										info={alertStatus.info}
										tone={alertStatus.tone}
									/>
								</div>

								<div class="grid gap-4 sm:grid-cols-2">
									<InfoItem
										icon={Clock3}
										title={freshnessStatus.title}
										info={freshnessStatus.info}
										tone={freshnessStatus.tone}
									/>
									<InfoItem
										icon={MapPin}
										title={readingStatus.title}
										info={readingStatus.info}
										tone={readingStatus.tone}
									/>
								</div>
							</div>
							{#if latestLocation?.accuracyM !== null && latestLocation?.accuracyM !== undefined && latestLocation.accuracyM > 0}
								<p class="mt-6 border-t border-ink/10 pt-4 text-sm leading-6 text-muted">
									El círculo azul representa la precisión informada. No es una zona permitida.
								</p>
							{/if}
						</section>

						<section class="rounded-2xl bg-white p-6 shadow-sm">
							<Heading
								icon={ShieldCheck}
								title="Geocercas activas"
								subtitle="Zonas permitidas visibles sobre el mapa del paciente."
							/>
							<div class="mt-6">
								{#if !data.safeZonesAvailable}
									<Alert
										icon={CircleAlert}
										title="Geocercas no disponibles"
										subtitle="La ubicación sigue disponible. Inténtalo nuevamente en unos minutos."
										color="warning"
									/>
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
									class="inline-flex min-h-12 items-center justify-center rounded-full bg-brand px-5 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none"
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
											class="min-h-12 cursor-pointer rounded-full bg-brand px-5 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
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
											<div class="mt-3">
												<Alert
													icon={MapPin}
													title="Ubicación seleccionada"
													subtitle="Puedes guardarla o elegir otro punto en el mapa."
												/>
											</div>
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
									<div class="mt-5">
										<Alert
											icon={manualLocationFeedback.kind === 'success'
												? CircleCheckBig
												: CircleAlert}
											title={manualLocationFeedback.kind === 'success'
												? 'Ubicación guardada'
												: 'No pudimos guardar la ubicación'}
											subtitle={manualLocationFeedback.message}
											color={manualLocationFeedback.kind === 'success' ? 'positive' : 'danger'}
										/>
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
								<div class="mt-6">
									<Alert
										icon={CircleAlert}
										title="Historial no disponible"
										subtitle="Inténtalo nuevamente en unos minutos."
										color="warning"
									/>
								</div>
							{:else if alertEpisodes.length === 0}
								<p class="mt-6 text-sm leading-6 text-muted">
									Todavía no se ha confirmado ninguna salida de las zonas permitidas.
								</p>
							{:else}
								<ul class="mt-6 space-y-3">
									{#each alertEpisodes as episode (episode.id)}
										<li>
											<InfoItem
												icon={episode.status === 'OPEN' ? Siren : CircleCheckBig}
												title={episode.status === 'OPEN' ? 'Salida activa' : 'Salida resuelta'}
												info={presentEpisodeInfo(episode)}
												tone={episode.status === 'OPEN' ? 'danger' : 'positive'}
											/>
										</li>
									{/each}
								</ul>
							{/if}
							<div class="mt-6 border-t border-ink/10 pt-4">
								<button
									type="button"
									disabled
									title="Historial completo pendiente de implementación"
									class="min-h-12 w-full cursor-not-allowed rounded-full bg-surface-muted px-5 font-bold text-muted opacity-70"
								>
									Ver todos los episodios
								</button>
								<p class="mt-2 text-center text-xs text-muted">Historial completo próximamente.</p>
							</div>
						</section>
					</aside>
				</div>
			{/if}
		</section>
	</div>
</main>
