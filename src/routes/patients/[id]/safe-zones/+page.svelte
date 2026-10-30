<script lang="ts">
	import { enhance, type SubmitFunction } from '$app/forms';
	import Alert from '#lib/components/ui/Alert.svelte';
	import Heading from '#lib/components/ui/Heading.svelte';
	import SafeZoneEditorMap, {
		type SafeZoneDraft,
		type SafeZoneEditorMapController,
		type SafeZoneMapItem
	} from '#lib/maps/SafeZoneEditorMap.svelte';
	import Archive from '@lucide/svelte/icons/archive';
	import CircleAlert from '@lucide/svelte/icons/circle-alert';
	import CircleCheck from '@lucide/svelte/icons/circle-check';
	import CircleOff from '@lucide/svelte/icons/circle-off';
	import MapPinned from '@lucide/svelte/icons/map-pinned';
	import Pencil from '@lucide/svelte/icons/pencil';
	import Plus from '@lucide/svelte/icons/plus';
	import ShieldCheck from '@lucide/svelte/icons/shield-check';
	import type { PageProps } from './$types';

	type EditorMode = 'NONE' | 'CREATE' | 'EDIT';

	let { data, form }: PageProps = $props();
	let editorMode = $state<EditorMode>('NONE');
	let selectedZoneId = $state<string | null>(null);
	let name = $state('');
	let centerLatitude = $state<number | undefined>(undefined);
	let centerLongitude = $state<number | undefined>(undefined);
	let radiusM = $state(250);
	let isActive = $state(true);
	let selectionMode = $state(false);
	let submitting = $state(false);
	let zoneToArchiveId = $state<string | null>(null);
	let mapController = $state.raw<SafeZoneEditorMapController | null>(null);

	const patientName = $derived(`${data.patient.firstName} ${data.patient.lastName}`);
	const selectedZone = $derived(data.safeZones.find((zone) => zone.id === selectedZoneId) ?? null);
	const draft = $derived.by<SafeZoneDraft | null>(() => {
		if (editorMode === 'NONE') return null;

		if (
			centerLatitude === undefined ||
			centerLongitude === undefined ||
			!Number.isFinite(centerLatitude) ||
			!Number.isFinite(centerLongitude) ||
			centerLatitude < -90 ||
			centerLatitude > 90 ||
			centerLongitude < -180 ||
			centerLongitude > 180 ||
			!Number.isFinite(radiusM) ||
			radiusM < 50 ||
			radiusM > 5000
		) {
			return null;
		}

		return { centerLatitude, centerLongitude, radiusM };
	});

	function setMapDraft(fit = false) {
		mapController?.setDraft(draft);
		if (fit && draft) mapController?.fitDraft();
	}

	function startCreate() {
		editorMode = 'CREATE';
		selectedZoneId = null;
		name = '';
		centerLatitude = undefined;
		centerLongitude = undefined;
		radiusM = 250;
		isActive = true;
		selectionMode = true;
		mapController?.setDraft(null);
		mapController?.setSelectionMode(true);
	}

	function startEdit(zone: SafeZoneMapItem) {
		editorMode = 'EDIT';
		selectedZoneId = zone.id;
		name = zone.name;
		centerLatitude = zone.centerLatitude;
		centerLongitude = zone.centerLongitude;
		radiusM = zone.radiusM;
		isActive = zone.isActive;
		selectionMode = false;
		mapController?.setSelectionMode(false);
		mapController?.setDraft({
			centerLatitude: zone.centerLatitude,
			centerLongitude: zone.centerLongitude,
			radiusM: zone.radiusM
		});
		mapController?.fitDraft();
	}

	function cancelEditor() {
		editorMode = 'NONE';
		selectionMode = false;
		mapController?.setDraft(null);
		mapController?.setSelectionMode(false);
		if (!selectedZoneId) selectedZoneId = data.safeZones[0]?.id ?? null;
	}

	function chooseCenter() {
		selectionMode = true;
		mapController?.setSelectionMode(true);
	}

	function handleCenterSelected(point: { latitude: number; longitude: number }) {
		centerLatitude = Number(point.latitude.toFixed(6));
		centerLongitude = Number(point.longitude.toFixed(6));
		selectionMode = false;
		mapController?.setSelectionMode(false);
		mapController?.setDraft({
			centerLatitude,
			centerLongitude,
			radiusM
		});
		mapController?.fitDraft();
	}

	function handleDraftCenterChanged(point: { latitude: number; longitude: number }) {
		centerLatitude = Number(point.latitude.toFixed(6));
		centerLongitude = Number(point.longitude.toFixed(6));
	}

	function handleZoneSelected(zoneId: string) {
		if (editorMode !== 'NONE') return;
		selectedZoneId = zoneId;
	}

	function handleRadiusInput(event: Event & { currentTarget: HTMLInputElement }) {
		const value = event.currentTarget.valueAsNumber;
		if (!Number.isNaN(value)) radiusM = value;
		setMapDraft();
	}

	function handleRadiusChange() {
		setMapDraft(true);
	}

	function handleMapReady(controller: SafeZoneEditorMapController | null) {
		mapController = controller;
	}

	const enhanceForm: SubmitFunction = () => {
		submitting = true;

		return async ({ result, update }) => {
			submitting = false;
			await update({ reset: false });

			if (result.type !== 'success') return;
			const resultData = result.data as { action?: string } | undefined;
			if (resultData?.action === 'save' || resultData?.action === 'archive') {
				editorMode = 'NONE';
				selectionMode = false;
				selectedZoneId = null;
				zoneToArchiveId = null;
				mapController?.setDraft(null);
				mapController?.setSelectionMode(false);
			}
		};
	};
</script>

<svelte:head>
	<title>Geocercas de {patientName} | Senda</title>
	<meta
		name="description"
		content={`Configura las zonas permitidas de ${patientName} mediante geocercas circulares.`}
	/>
</svelte:head>

<main id="contenido-principal" class="px-5 py-8 sm:px-8 lg:px-0">
	<div class="w-full">
		<div class="mb-8 flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
			<h2 class="text-2xl font-bold text-ink">Zonas permitidas</h2>
			{#if data.safeZonesAvailable && editorMode === 'NONE'}
				<button
					type="button"
					onclick={startCreate}
					class="inline-flex min-h-12 cursor-pointer items-center justify-center gap-2 rounded-full bg-brand px-5 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none"
				>
					<Plus aria-hidden="true" size={18} strokeWidth={2} />
					Agregar geocerca
				</button>
			{/if}
		</div>

		{#if !data.safeZonesAvailable}
			<div class="max-w-3xl">
				<Alert
					icon={CircleAlert}
					title="No pudimos consultar las geocercas"
					subtitle="La información del paciente sigue disponible. Inténtalo nuevamente en unos minutos."
					color="warning"
				/>
			</div>
		{:else}
			{#if form?.message}
				<div class="mb-6 max-w-3xl">
					<Alert
						icon={form.success ? CircleCheck : CircleAlert}
						title={form.success ? 'Geocerca actualizada' : 'No pudimos completar la acción'}
						subtitle={form.message}
						color={form.success ? 'positive' : 'danger'}
					/>
				</div>
			{/if}

			<div class="grid items-start gap-6 xl:grid-cols-12">
				<div class="min-w-0 xl:col-span-8">
					<SafeZoneEditorMap
						latitude={data.mapCenter.latitude}
						longitude={data.mapCenter.longitude}
						{patientName}
						zones={data.safeZones}
						{selectedZoneId}
						{draft}
						{selectionMode}
						onCenterSelected={handleCenterSelected}
						onDraftCenterChanged={handleDraftCenterChanged}
						onZoneSelected={handleZoneSelected}
						onReady={handleMapReady}
					/>

					<section
						class="mt-4 rounded-2xl bg-white p-4 shadow-sm"
						aria-label="Ayuda y leyenda del mapa"
					>
						<div class="flex flex-wrap gap-x-5 gap-y-2 text-sm text-muted">
							<p class="flex items-center gap-2">
								<span
									class="size-3 rounded-full border-2 border-brand bg-brand/25"
									aria-hidden="true"
								></span>
								Zona activa guardada
							</p>
							{#if draft}
								<p class="flex items-center gap-2">
									<span
										class="size-3 rounded-full border-2 border-amber-800 bg-amber-300/40"
										aria-hidden="true"
									></span>
									Zona provisional sin guardar
								</p>
							{/if}
						</div>

						<p
							class="mt-4 border-t border-ink/10 pt-4 text-sm leading-6 text-muted"
							role="status"
							aria-live="polite"
						>
							{#if selectionMode}
								Toca o haz clic en el mapa para definir el centro de la geocerca.
							{:else if draft}
								Arrastra el círculo provisional para ajustar su centro o modifica el radio desde el
								editor.
							{:else if selectedZone}
								Mostrando <strong class="text-ink">{selectedZone.name}</strong>. Las zonas inactivas
								aparecen en el mapa solamente cuando las seleccionas.
							{:else}
								Selecciona una geocerca guardada para resaltarla en el mapa.
							{/if}
						</p>
					</section>
				</div>

				<aside class="xl:col-span-4">
					{#if editorMode !== 'NONE'}
						<section
							class="overflow-hidden rounded-2xl bg-white shadow-sm"
							aria-label={editorMode === 'CREATE' ? 'Nueva geocerca' : 'Editar geocerca'}
						>
							<form method="POST" action="?/save" use:enhance={enhanceForm}>
								<div class="p-6">
									<div>
										<Heading
											icon={ShieldCheck}
											title={editorMode === 'CREATE' ? 'Nueva geocerca' : 'Editar geocerca'}
											subtitle="Define la zona directamente sobre el mapa y ajusta su alcance."
										/>
									</div>

									<ol class="mt-6 space-y-3" aria-label="Pasos para configurar la geocerca">
										<li class="flex gap-3 rounded-2xl bg-canvas p-4">
											<span
												class="flex size-8 shrink-0 items-center justify-center rounded-full bg-white text-sm font-bold text-ink"
												aria-hidden="true">1</span
											>
											<div>
												<p class="font-bold text-ink">Ubica el centro</p>
												<p class="mt-1 text-sm leading-6 text-muted">
													Toca el mapa o arrastra el círculo provisional.
												</p>
											</div>
										</li>
										<li class="flex gap-3 rounded-2xl bg-canvas p-4">
											<span
												class="flex size-8 shrink-0 items-center justify-center rounded-full bg-white text-sm font-bold text-ink"
												aria-hidden="true">2</span
											>
											<div>
												<p class="font-bold text-ink">Ajusta el alcance</p>
												<p class="mt-1 text-sm leading-6 text-muted">
													Usa el control de radio y comprueba el círculo en el mapa.
												</p>
											</div>
										</li>
									</ol>

									<input
										type="hidden"
										name="zoneId"
										value={editorMode === 'EDIT' ? (selectedZoneId ?? '') : ''}
									/>
									<input type="hidden" name="centerLatitude" value={centerLatitude ?? ''} />
									<input type="hidden" name="centerLongitude" value={centerLongitude ?? ''} />

									<div class="mt-6 border-t border-ink/10 pt-6">
										<label for="zone-name" class="text-sm font-bold text-ink">Nombre</label>
										<input
											id="zone-name"
											name="name"
											type="text"
											maxlength="60"
											required
											bind:value={name}
											placeholder="Ej. Casa"
											class="mt-2 min-h-12 w-full rounded-xl border border-ink/15 bg-white px-4 text-base text-ink outline-none focus:border-brand focus:ring-4 focus:ring-focus/25"
										/>
									</div>

									<div class="mt-6">
										<div class="flex flex-wrap items-start justify-between gap-3">
											<div>
												<p class="text-sm font-bold text-ink">Centro de la zona</p>
												<p class="mt-1 text-sm leading-6 text-muted">
													Se define visualmente sobre el mapa.
												</p>
											</div>
											<button
												type="button"
												onclick={chooseCenter}
												class="inline-flex min-h-11 cursor-pointer items-center gap-2 rounded-full bg-canvas px-4 font-bold text-brand transition hover:bg-surface-muted focus:ring-4 focus:ring-focus/30 focus:outline-none"
											>
												<MapPinned aria-hidden="true" size={18} strokeWidth={2} />
												{draft ? 'Cambiar centro' : 'Elegir en el mapa'}
											</button>
										</div>
										{#if selectionMode}
											<p class="mt-3 text-sm leading-6 font-semibold text-brand">
												Toca o haz clic en el mapa para colocar el centro.
											</p>
										{:else if draft}
											<p class="mt-3 text-sm leading-6 text-muted">
												Centro definido. Puedes arrastrar el círculo para afinarlo.
											</p>
										{/if}
									</div>

									<fieldset class="mt-6">
										<legend class="text-sm font-bold text-ink">Radio</legend>
										<p class="mt-1 text-sm text-muted">Entre 50 y 5,000 metros.</p>
										<label for="zone-radius-slider" class="sr-only">Radio mediante deslizador</label
										>
										<input
											id="zone-radius-slider"
											type="range"
											min="50"
											max="5000"
											step="50"
											value={radiusM}
											oninput={handleRadiusInput}
											onchange={handleRadiusChange}
											class="mt-4 h-8 w-full cursor-pointer accent-brand"
										/>
										<div class="mt-2 flex items-center gap-3">
											<label for="zone-radius" class="shrink-0 text-sm font-semibold text-muted"
												>Radio exacto</label
											>
											<input
												id="zone-radius"
												name="radiusM"
												type="number"
												min="50"
												max="5000"
												step="50"
												required
												value={radiusM}
												oninput={handleRadiusInput}
												onchange={handleRadiusChange}
												class="min-h-12 min-w-0 flex-1 rounded-xl border border-ink/15 bg-white px-3 text-base text-ink outline-none focus:border-brand focus:ring-4 focus:ring-focus/25"
											/>
											<span class="text-sm text-muted">m</span>
										</div>
									</fieldset>

									<label
										class="mt-6 flex min-h-12 cursor-pointer items-center gap-3 rounded-2xl bg-surface-muted px-4 py-3 font-semibold text-ink"
									>
										<input
											name="isActive"
											type="checkbox"
											bind:checked={isActive}
											class="size-5 accent-brand"
										/>
										Zona activa
									</label>
								</div>

								<div
									class="grid gap-2 border-t border-ink/10 p-4 sm:grid-cols-2 xl:grid-cols-1 2xl:grid-cols-2"
								>
									<button
										type="submit"
										disabled={submitting || !draft}
										class="min-h-12 cursor-pointer rounded-full bg-brand px-4 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
									>
										{submitting ? 'Guardando…' : 'Guardar geocerca'}
									</button>
									<button
										type="button"
										onclick={cancelEditor}
										disabled={submitting}
										class="min-h-12 cursor-pointer rounded-full px-4 font-bold text-ink transition hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
									>
										Cancelar
									</button>
								</div>
							</form>
						</section>
					{:else}
						<section
							class="overflow-hidden rounded-2xl bg-white shadow-sm"
							aria-label="Geocercas guardadas"
						>
							<div class="p-6">
								<Heading
									icon={ShieldCheck}
									title="Geocercas guardadas"
									subtitle={data.safeZones.length === 1
										? '1 zona configurada para este paciente.'
										: `${data.safeZones.length} zonas configuradas para este paciente.`}
								/>

								{#if data.safeZones.length === 0}
									<div class="mt-6 rounded-2xl bg-canvas p-4">
										<p class="font-bold text-ink">Aún no hay geocercas</p>
										<p class="mt-1 text-sm leading-6 text-muted">
											La ausencia de zonas permitidas no se interpreta como un estado seguro.
										</p>
									</div>
								{:else}
									<ul class="mt-6 space-y-3">
										{#each data.safeZones as zone (zone.id)}
											<li
												class={[
													'overflow-hidden rounded-2xl',
													selectedZoneId === zone.id ? 'bg-surface-muted' : 'bg-canvas'
												]}
											>
												<button
													type="button"
													onclick={() => handleZoneSelected(zone.id)}
													aria-pressed={selectedZoneId === zone.id}
													class="flex min-h-16 w-full cursor-pointer items-start gap-3 p-4 text-left"
												>
													<span
														class="flex size-10 shrink-0 items-center justify-center rounded-full bg-white text-brand"
													>
														<MapPinned aria-hidden="true" size={20} strokeWidth={2} />
													</span>
													<span class="min-w-0 flex-1">
														<span class="block font-bold wrap-break-word text-ink">{zone.name}</span
														>
														<span class="mt-1 flex items-center gap-2 text-sm text-muted">
															{#if zone.isActive}
																<CircleCheck aria-hidden="true" size={16} strokeWidth={2} />
																Activa
															{:else}
																<CircleOff aria-hidden="true" size={16} strokeWidth={2} />
																Inactiva
															{/if}
															<span aria-hidden="true">·</span>
															{zone.radiusM.toLocaleString('es-DO')} m
														</span>
													</span>
												</button>

												<div class="border-t border-ink/10 p-3">
													{#if zoneToArchiveId === zone.id}
														<form method="POST" action="?/archive" use:enhance={enhanceForm}>
															<input type="hidden" name="zoneId" value={zone.id} />
															<div class="rounded-2xl bg-red-50 p-4">
																<p class="text-sm leading-6 font-semibold text-red-950">
																	Se conservará el registro, pero dejará de participar en la
																	evaluación.
																</p>
																<div class="mt-3 flex flex-wrap gap-2">
																	<button
																		type="submit"
																		disabled={submitting}
																		class="min-h-11 cursor-pointer rounded-full bg-red-800 px-4 font-bold text-white focus:ring-4 focus:ring-red-700/20 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
																	>
																		{submitting ? 'Archivando…' : 'Confirmar archivo'}
																	</button>
																	<button
																		type="button"
																		onclick={() => (zoneToArchiveId = null)}
																		disabled={submitting}
																		class="min-h-11 cursor-pointer rounded-full px-4 font-bold text-red-950 focus:ring-4 focus:ring-red-700/20 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
																	>
																		Cancelar
																	</button>
																</div>
															</div>
														</form>
													{:else}
														<div class="flex flex-wrap gap-2">
															<button
																type="button"
																onclick={() => startEdit(zone)}
																class="inline-flex min-h-11 cursor-pointer items-center gap-2 rounded-full px-4 font-bold text-brand transition hover:bg-white focus:ring-4 focus:ring-focus/30 focus:outline-none"
															>
																<Pencil aria-hidden="true" size={17} strokeWidth={2} />
																Editar
															</button>
															<button
																type="button"
																onclick={() => (zoneToArchiveId = zone.id)}
																disabled={submitting}
																class="inline-flex min-h-11 cursor-pointer items-center gap-2 rounded-full px-4 font-bold text-red-800 transition hover:bg-red-50 focus:ring-4 focus:ring-red-700/20 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
															>
																<Archive aria-hidden="true" size={17} strokeWidth={2} />
																Archivar
															</button>
														</div>
													{/if}
												</div>
											</li>
										{/each}
									</ul>
								{/if}
							</div>
						</section>
					{/if}
				</aside>
			</div>
		{/if}
	</div>
</main>
