<script lang="ts">
	import { enhance, type SubmitFunction } from '$app/forms';
	import SafeZoneEditorMap, {
		type SafeZoneDraft,
		type SafeZoneEditorMapController,
		type SafeZoneMapItem
	} from '#lib/maps/SafeZoneEditorMap.svelte';
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

	function handleCoordinateInput(
		event: Event & { currentTarget: HTMLInputElement },
		coordinate: 'latitude' | 'longitude'
	) {
		const value = event.currentTarget.valueAsNumber;
		const nextValue = Number.isNaN(value) ? undefined : value;
		if (coordinate === 'latitude') centerLatitude = nextValue;
		else centerLongitude = nextValue;
		setMapDraft();
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

<main id="contenido-principal" class="min-h-dvh px-5 py-6 sm:px-8 lg:px-0">
	<div class="w-full max-w-6xl">
		<section class="py-4 sm:py-8">
			<div class="flex justify-end">
				{#if data.safeZonesAvailable && editorMode === 'NONE'}
					<button
						type="button"
						onclick={startCreate}
						class="min-h-12 cursor-pointer rounded-xl bg-brand px-5 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none"
					>
						Agregar geocerca
					</button>
				{/if}
			</div>

			{#if !data.safeZonesAvailable}
				<div
					class="mt-7 rounded-2xl border border-amber-700/25 bg-amber-50 p-5 text-amber-950"
					role="alert"
				>
					<p class="font-bold">La configuración de geocercas aún no está disponible</p>
					<p class="mt-1 text-sm leading-6">
						Aplica la migración de esta historia al proyecto Supabase de desarrollo y vuelve a
						cargar.
					</p>
				</div>
			{:else}
				{#if form?.message}
					<div
						class={[
							'mt-7 rounded-2xl border p-4 text-sm leading-6 font-semibold',
							form.success
								? 'border-brand/25 bg-surface-muted text-ink'
								: 'border-red-700/25 bg-red-50 text-red-950'
						]}
						role={form.success ? 'status' : 'alert'}
						aria-live="polite"
					>
						{form.message}
					</div>
				{/if}

				<div class="mt-8 grid items-start gap-6 lg:grid-cols-3">
					<div class="min-w-0 lg:col-span-2">
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

						<div
							class="mt-4 flex flex-wrap gap-x-5 gap-y-2 text-sm text-muted"
							aria-label="Leyenda del mapa"
						>
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
					</div>

					<aside class="space-y-6">
						{#if editorMode !== 'NONE'}
							<section
								class="rounded-3xl border border-white/80 bg-white p-5 sm:p-6"
								aria-labelledby="zone-editor-title"
							>
								<h2 id="zone-editor-title" class="text-xl font-bold text-ink">
									{editorMode === 'CREATE' ? 'Nueva geocerca' : 'Editar geocerca'}
								</h2>
								<p class="mt-2 text-sm leading-6 text-muted">
									Elige el centro en el mapa, arrastra el círculo provisional o escribe las
									coordenadas. Ajusta después el radio.
								</p>

								<form method="POST" action="?/save" use:enhance={enhanceForm} class="mt-5">
									<input
										type="hidden"
										name="zoneId"
										value={editorMode === 'EDIT' ? (selectedZoneId ?? '') : ''}
									/>

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

									<div class="mt-5 flex flex-wrap items-center justify-between gap-3">
										<p class="text-sm font-bold text-ink">Centro del círculo</p>
										<button
											type="button"
											onclick={chooseCenter}
											class="min-h-11 cursor-pointer rounded-xl px-3 font-bold text-brand transition hover:bg-surface-muted focus:ring-4 focus:ring-focus/30 focus:outline-none"
										>
											{draft ? 'Cambiar centro' : 'Elegir en el mapa'}
										</button>
									</div>
									{#if selectionMode}
										<p
											class="mt-2 rounded-xl bg-amber-50 p-3 text-sm leading-6 font-semibold text-amber-950"
											role="status"
										>
											Toca o haz clic en el mapa para colocar el centro.
										</p>
									{/if}

									<div class="mt-3 grid gap-3 sm:grid-cols-2 lg:grid-cols-1 xl:grid-cols-2">
										<div>
											<label for="zone-latitude" class="text-sm font-semibold text-muted"
												>Latitud</label
											>
											<input
												id="zone-latitude"
												name="centerLatitude"
												type="number"
												min="-90"
												max="90"
												step="any"
												required
												value={centerLatitude ?? ''}
												oninput={(event) => handleCoordinateInput(event, 'latitude')}
												onchange={() => setMapDraft(true)}
												class="mt-2 min-h-12 w-full rounded-xl border border-ink/15 bg-white px-3 font-mono text-base text-ink outline-none focus:border-brand focus:ring-4 focus:ring-focus/25"
											/>
										</div>
										<div>
											<label for="zone-longitude" class="text-sm font-semibold text-muted"
												>Longitud</label
											>
											<input
												id="zone-longitude"
												name="centerLongitude"
												type="number"
												min="-180"
												max="180"
												step="any"
												required
												value={centerLongitude ?? ''}
												oninput={(event) => handleCoordinateInput(event, 'longitude')}
												onchange={() => setMapDraft(true)}
												class="mt-2 min-h-12 w-full rounded-xl border border-ink/15 bg-white px-3 font-mono text-base text-ink outline-none focus:border-brand focus:ring-4 focus:ring-focus/25"
											/>
										</div>
									</div>

									<fieldset class="mt-5">
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
										class="mt-5 flex min-h-12 cursor-pointer items-center gap-3 rounded-xl bg-surface-muted px-4 py-3 font-semibold text-ink"
									>
										<input
											name="isActive"
											type="checkbox"
											bind:checked={isActive}
											class="size-5 accent-brand"
										/>
										Zona activa
									</label>

									<div class="mt-5 grid gap-3 sm:grid-cols-2 lg:grid-cols-1 xl:grid-cols-2">
										<button
											type="submit"
											disabled={submitting || !draft}
											class="min-h-12 cursor-pointer rounded-xl bg-brand px-4 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
										>
											{submitting ? 'Guardando…' : 'Guardar geocerca'}
										</button>
										<button
											type="button"
											onclick={cancelEditor}
											disabled={submitting}
											class="min-h-12 cursor-pointer rounded-xl border border-ink/15 bg-white px-4 font-bold text-ink transition hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
										>
											Cancelar
										</button>
									</div>
								</form>
							</section>
						{/if}

						<section
							class="rounded-3xl border border-white/80 bg-white p-5 sm:p-6"
							aria-labelledby="saved-zones-title"
						>
							<div class="flex items-center justify-between gap-3">
								<h2 id="saved-zones-title" class="text-xl font-bold text-ink">
									Geocercas guardadas
								</h2>
								<span class="text-sm font-semibold text-muted">{data.safeZones.length}</span>
							</div>

							{#if data.safeZones.length === 0}
								<p class="mt-3 text-sm leading-6 text-muted">
									Aún no hay zonas. El sistema no debe interpretar esta ausencia como un estado
									seguro.
								</p>
							{:else}
								<ul class="mt-4 space-y-3">
									{#each data.safeZones as zone (zone.id)}
										<li
											class={[
												'rounded-2xl border p-4',
												selectedZoneId === zone.id
													? 'border-brand/45 bg-surface-muted'
													: 'border-ink/10 bg-white'
											]}
										>
											<button
												type="button"
												onclick={() => handleZoneSelected(zone.id)}
												aria-pressed={selectedZoneId === zone.id}
												class="min-h-11 w-full cursor-pointer text-left focus:ring-4 focus:ring-focus/30 focus:outline-none"
											>
												<span class="block font-bold text-ink">{zone.name}</span>
												<span class="mt-1 block text-sm text-muted">
													{zone.isActive ? 'Activa' : 'Inactiva'} · {zone.radiusM.toLocaleString(
														'es-DO'
													)} m
												</span>
											</button>
											<div class="mt-3 flex flex-wrap gap-3 border-t border-ink/10 pt-3">
												<button
													type="button"
													onclick={() => startEdit(zone)}
													disabled={editorMode !== 'NONE'}
													class="min-h-11 cursor-pointer rounded-xl px-3 font-bold text-brand focus:ring-4 focus:ring-focus/30 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
												>
													Editar
												</button>
												{#if zoneToArchiveId === zone.id}
													<form
														method="POST"
														action="?/archive"
														use:enhance={enhanceForm}
														class="w-full rounded-xl border border-red-700/20 bg-red-50 p-3"
													>
														<input type="hidden" name="zoneId" value={zone.id} />
														<p class="text-sm leading-6 font-semibold text-red-950">
															Se conservará el registro, pero dejará de participar en la evaluación.
														</p>
														<div class="mt-2 flex flex-wrap gap-2">
															<button
																type="submit"
																disabled={submitting}
																class="min-h-11 cursor-pointer rounded-xl bg-red-800 px-3 font-bold text-white focus:ring-4 focus:ring-red-700/20 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
															>
																{submitting ? 'Archivando…' : 'Confirmar archivo'}
															</button>
															<button
																type="button"
																onclick={() => (zoneToArchiveId = null)}
																disabled={submitting}
																class="min-h-11 cursor-pointer rounded-xl px-3 font-bold text-red-950 focus:ring-4 focus:ring-red-700/20 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
															>
																Cancelar
															</button>
														</div>
													</form>
												{:else}
													<button
														type="button"
														onclick={() => (zoneToArchiveId = zone.id)}
														disabled={submitting || editorMode !== 'NONE'}
														class="min-h-11 cursor-pointer rounded-xl px-3 font-bold text-red-800 focus:ring-4 focus:ring-red-700/20 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
													>
														Archivar
													</button>
												{/if}
											</div>
										</li>
									{/each}
								</ul>
							{/if}

							{#if editorMode === 'NONE' && data.safeZones.length > 0}
								<button
									type="button"
									onclick={startCreate}
									class="mt-4 min-h-12 w-full cursor-pointer rounded-xl border border-brand/25 bg-white px-4 font-bold text-brand transition hover:bg-surface-muted focus:ring-4 focus:ring-focus/30 focus:outline-none"
								>
									Agregar otra geocerca
								</button>
							{/if}
						</section>
					</aside>
				</div>

				{#if selectedZone && editorMode === 'NONE'}
					<p class="mt-5 text-sm leading-6 text-muted">
						Seleccionada: <strong class="text-ink">{selectedZone.name}</strong>. Las zonas inactivas
						se ocultan del mapa salvo cuando se seleccionan en la lista.
					</p>
				{/if}
			{/if}
		</section>
	</div>
</main>
