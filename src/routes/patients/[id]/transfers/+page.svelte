<script lang="ts">
	import { enhance, type SubmitFunction } from '$app/forms';
	import Alert from '#lib/components/ui/Alert.svelte';
	import Heading from '#lib/components/ui/Heading.svelte';
	import InfoItem from '#lib/components/ui/InfoItem.svelte';
	import {
		CalendarClock,
		CalendarPlus,
		CircleAlert,
		CircleCheck,
		Clock3,
		Flag,
		History,
		PencilLine,
		Route,
		Save,
		X
	} from '@lucide/svelte';
	import type { UiTone } from '#lib/types/ui.js';
	import type { PageProps } from './$types';

	type Transfer = PageProps['data']['currentTransfers'][number];
	type TransferStatus = Transfer['status'];
	type StatusPresentation = { label: string; tone: UiTone };
	type TransferPanel = { transferId: string; type: 'edit' | 'terminal' };

	let { data, form }: PageProps = $props();
	let submitting = $state(false);
	let saveResult = $derived(form?.action === 'save' ? form : null);
	let saveErrors = $derived((saveResult?.errors ?? {}) as Record<string, string>);
	let selectedTransferPanel = $state<TransferPanel | null | undefined>(undefined);
	let openTransferPanel = $derived<TransferPanel | null>(
		selectedTransferPanel === undefined
			? saveResult?.values?.transferId
				? { transferId: saveResult.values.transferId, type: 'edit' }
				: null
			: selectedTransferPanel
	);

	const dateFormatter = new Intl.DateTimeFormat('es-DO', {
		dateStyle: 'medium',
		timeStyle: 'short',
		timeZone: 'America/Santo_Domingo'
	});

	const enhanceForm: SubmitFunction = () => {
		submitting = true;

		return async ({ result, update }) => {
			await update({ reset: result.type === 'success' });
			if (result.type === 'success') selectedTransferPanel = null;
			submitting = false;
		};
	};

	function toggleTransferPanel(transferId: string, type: TransferPanel['type']) {
		selectedTransferPanel =
			openTransferPanel?.transferId === transferId && openTransferPanel.type === type
				? null
				: { transferId, type };
	}

	function presentDate(value: string): string {
		return dateFormatter.format(new Date(value));
	}

	function statusPresentation(status: TransferStatus): StatusPresentation {
		switch (status) {
			case 'ACTIVE':
				return { label: 'En curso', tone: 'warning' };
			case 'SCHEDULED':
				return { label: 'Programado', tone: 'neutral' };
			case 'COMPLETED':
				return { label: 'Finalizado', tone: 'positive' };
			case 'CANCELLED':
				return { label: 'Cancelado', tone: 'neutral' };
		}
	}

	function editValues(transfer: Transfer) {
		const failedValues = saveResult?.values;
		if (!failedValues || failedValues.transferId !== transfer.id) {
			return {
				startsAt: transfer.startsAtInput,
				endsAt: transfer.endsAtInput,
				note: transfer.note
			};
		}

		return {
			startsAt: failedValues.startsAt,
			endsAt: failedValues.endsAt,
			note: failedValues.note
		};
	}
</script>

<svelte:head>
	<title>Traslados de {data.patient.firstName} {data.patient.lastName} | Senda</title>
	<meta
		name="description"
		content="Programa y consulta los traslados autorizados del paciente en Senda."
	/>
</svelte:head>

<main id="contenido-principal" class="px-5 py-8 sm:px-8 lg:px-0">
	<div class="w-full">
		<h2 class="mb-8 text-2xl font-bold text-ink">Traslados planificados</h2>

		{#if form?.successMessage}
			<div class="mb-8 max-w-3xl">
				<Alert
					icon={CircleCheck}
					title="Traslado actualizado"
					subtitle={form.successMessage}
					color="positive"
				/>
			</div>
		{:else if form?.message}
			<div class="mb-8 max-w-3xl">
				<Alert
					icon={CircleAlert}
					title="No pudimos completar la acción"
					subtitle={form.message}
					color="danger"
				/>
			</div>
		{/if}

		<div class={['grid gap-6', data.isAdmin && 'xl:grid-cols-12']}>
			{#if data.isAdmin}
				<section class="rounded-2xl bg-white p-6 shadow-sm xl:col-span-5">
					<Heading
						icon={CalendarPlus}
						title="Programar traslado"
						subtitle="Define el tiempo necesario para llegar al destino. La ubicación seguirá actualizándose."
					/>

					{#if saveResult && !saveResult.values?.transferId && Object.keys(saveErrors).length > 0}
						<div class="mt-6">
							<Alert
								icon={CircleAlert}
								title="Revisa el traslado"
								subtitle={saveErrors.form ?? 'Corrige los campos indicados e inténtalo nuevamente.'}
								color="danger"
							/>
						</div>
					{/if}

					<form method="POST" action="?/save" use:enhance={enhanceForm} class="mt-8">
						<div class="grid gap-5 sm:grid-cols-2 xl:grid-cols-1 2xl:grid-cols-2">
							<div>
								<label for="new-starts-at" class="text-sm font-bold text-ink">Desde</label>
								<input
									id="new-starts-at"
									name="startsAt"
									type="datetime-local"
									min={data.nowInput}
									required
									value={saveResult?.values?.transferId ? '' : (saveResult?.values?.startsAt ?? '')}
									aria-invalid={!saveResult?.values?.transferId && saveErrors.startsAt
										? 'true'
										: undefined}
									aria-describedby={!saveResult?.values?.transferId && saveErrors.startsAt
										? 'new-start-error'
										: undefined}
									class="mt-2 min-h-12 w-full rounded-xl border border-ink/20 bg-white px-4 text-base text-ink outline-none focus:border-focus focus:ring-4 focus:ring-focus/20"
								/>
								{#if !saveResult?.values?.transferId && saveErrors.startsAt}
									<p id="new-start-error" class="mt-2 text-sm font-semibold text-red-800">
										{saveErrors.startsAt}
									</p>
								{/if}
							</div>

							<div>
								<label for="new-ends-at" class="text-sm font-bold text-ink">Hasta</label>
								<input
									id="new-ends-at"
									name="endsAt"
									type="datetime-local"
									min={data.nowInput}
									required
									value={saveResult?.values?.transferId ? '' : (saveResult?.values?.endsAt ?? '')}
									aria-invalid={!saveResult?.values?.transferId && saveErrors.endsAt
										? 'true'
										: undefined}
									aria-describedby={!saveResult?.values?.transferId && saveErrors.endsAt
										? 'new-end-error'
										: undefined}
									class="mt-2 min-h-12 w-full rounded-xl border border-ink/20 bg-white px-4 text-base text-ink outline-none focus:border-focus focus:ring-4 focus:ring-focus/20"
								/>
								{#if !saveResult?.values?.transferId && saveErrors.endsAt}
									<p id="new-end-error" class="mt-2 text-sm font-semibold text-red-800">
										{saveErrors.endsAt}
									</p>
								{/if}
							</div>
						</div>

						<div class="mt-5">
							<label for="new-note" class="text-sm font-bold text-ink">Nota</label>
							<textarea
								id="new-note"
								name="note"
								rows="4"
								maxlength="500"
								required
								aria-invalid={!saveResult?.values?.transferId && saveErrors.note
									? 'true'
									: undefined}
								aria-describedby={!saveResult?.values?.transferId && saveErrors.note
									? 'new-note-error'
									: 'new-note-help'}
								class="mt-2 w-full resize-y rounded-xl border border-ink/20 bg-white px-4 py-3 text-base text-ink outline-none focus:border-focus focus:ring-4 focus:ring-focus/20"
								>{saveResult?.values?.transferId ? '' : (saveResult?.values?.note ?? '')}</textarea
							>
							{#if !saveResult?.values?.transferId && saveErrors.note}
								<p id="new-note-error" class="mt-2 text-sm font-semibold text-red-800">
									{saveErrors.note}
								</p>
							{:else}
								<p id="new-note-help" class="mt-2 text-sm leading-5 text-muted">
									Explica el destino o el motivo sin incluir información sensible innecesaria.
								</p>
							{/if}
						</div>

						<p class="mt-4 text-sm leading-5 text-muted">
							Duración máxima: 24 horas. Las horas se interpretan en el horario de República
							Dominicana.
						</p>

						<button
							type="submit"
							disabled={submitting}
							class="mt-6 inline-flex min-h-12 w-full cursor-pointer items-center justify-center gap-2 rounded-full bg-brand px-6 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
						>
							<CalendarPlus aria-hidden="true" size={19} strokeWidth={2} />
							{submitting ? 'Guardando…' : 'Programar traslado'}
						</button>
					</form>
				</section>
			{/if}

			<section class={['rounded-2xl bg-white p-6 shadow-sm', data.isAdmin && 'xl:col-span-7']}>
				<Heading
					icon={Route}
					title="Traslados actuales"
					subtitle="En curso y próximos, visibles para todas las personas autorizadas."
				/>

				{#if data.currentTransfers.length === 0}
					<div class="mt-8">
						<Alert
							icon={CalendarClock}
							title="No hay traslados pendientes"
							subtitle={data.isAdmin
								? 'Puedes programar uno cuando el paciente deba desplazarse fuera de sus zonas permitidas.'
								: 'Un administrador puede programar un traslado cuando sea necesario.'}
						/>
					</div>
				{:else}
					<ul class="mt-8 space-y-3">
						{#each data.currentTransfers as transfer (transfer.id)}
							{@const presentation = statusPresentation(transfer.status)}
							{@const values = editValues(transfer)}
							<li class="overflow-hidden rounded-2xl bg-canvas">
								<div class="flex min-h-16 items-start gap-3 p-4">
									<span
										class={[
											'flex size-10 shrink-0 items-center justify-center rounded-full',
											presentation.tone === 'warning'
												? 'bg-amber-50 text-amber-800'
												: 'bg-white text-brand'
										]}
									>
										{#if transfer.status === 'ACTIVE'}
											<Clock3 aria-hidden="true" size={20} strokeWidth={2} />
										{:else}
											<CalendarClock aria-hidden="true" size={20} strokeWidth={2} />
										{/if}
									</span>

									<div class="min-w-0 flex-1">
										<p class="font-bold wrap-break-word text-ink">{transfer.note}</p>
										<div
											class="mt-1 flex flex-wrap items-center gap-x-2 gap-y-1 text-sm text-muted"
										>
											<span class="inline-flex items-center gap-2">
												<CircleCheck aria-hidden="true" size={16} strokeWidth={2} />
												<span
													class={[
														presentation.tone === 'warning' ? 'text-amber-900' : 'text-muted'
													]}>{presentation.label}</span
												>
											</span>
											<span aria-hidden="true">·</span>
											<span>{presentDate(transfer.startsAt)} — {presentDate(transfer.endsAt)}</span>
										</div>
									</div>
								</div>

								{#if data.isAdmin}
									<div class="flex flex-wrap gap-2 border-t border-ink/10 p-3">
										<button
											type="button"
											onclick={() => toggleTransferPanel(transfer.id, 'edit')}
											aria-expanded={openTransferPanel?.transferId === transfer.id &&
												openTransferPanel?.type === 'edit'}
											aria-controls={`edit-transfer-${transfer.id}`}
											class={[
												'inline-flex min-h-11 cursor-pointer items-center gap-2 rounded-full px-4 font-bold text-brand transition hover:bg-white focus:ring-4 focus:ring-focus/30 focus:outline-none',
												openTransferPanel?.transferId === transfer.id &&
													openTransferPanel?.type === 'edit' &&
													'bg-white'
											]}
										>
											<PencilLine aria-hidden="true" size={18} strokeWidth={2} />
											{transfer.status === 'ACTIVE' ? 'Extender traslado' : 'Editar traslado'}
										</button>

										<button
											type="button"
											onclick={() => toggleTransferPanel(transfer.id, 'terminal')}
											aria-expanded={openTransferPanel?.transferId === transfer.id &&
												openTransferPanel?.type === 'terminal'}
											aria-controls={`terminal-transfer-${transfer.id}`}
											class={[
												'inline-flex min-h-11 cursor-pointer items-center gap-2 rounded-full px-4 font-bold text-red-800 transition hover:bg-red-50 focus:ring-4 focus:ring-red-700/20 focus:outline-none',
												openTransferPanel?.transferId === transfer.id &&
													openTransferPanel?.type === 'terminal' &&
													'bg-red-50'
											]}
										>
											{#if transfer.status === 'ACTIVE'}
												<Flag aria-hidden="true" size={18} strokeWidth={2} />
												Finalizar ahora
											{:else}
												<X aria-hidden="true" size={18} strokeWidth={2} />
												Cancelar traslado
											{/if}
										</button>
									</div>

									{#if openTransferPanel?.transferId === transfer.id && openTransferPanel?.type === 'edit'}
										<div id={`edit-transfer-${transfer.id}`} class="border-t border-ink/10 p-3">
											<div class="rounded-2xl bg-white p-5">
												{#if saveResult?.values?.transferId === transfer.id && Object.keys(saveErrors).length > 0}
													<div class="mb-5">
														<Alert
															icon={CircleAlert}
															title="Revisa el traslado"
															subtitle={saveErrors.form ?? 'Corrige los campos indicados.'}
															color="danger"
														/>
													</div>
												{/if}

												<form method="POST" action="?/save" use:enhance={enhanceForm}>
													<input type="hidden" name="transferId" value={transfer.id} />

													<div class="grid gap-4 sm:grid-cols-2">
														<div>
															<label
																for={`starts-at-${transfer.id}`}
																class="text-sm font-bold text-ink">Desde</label
															>
															<input
																id={`starts-at-${transfer.id}`}
																name="startsAt"
																type="datetime-local"
																min={transfer.status === 'SCHEDULED' ? data.nowInput : undefined}
																readonly={transfer.status === 'ACTIVE'}
																required
																value={values.startsAt}
																class="mt-2 min-h-12 w-full rounded-xl border border-ink/20 bg-white px-4 text-base text-ink outline-none read-only:bg-canvas focus:border-focus focus:ring-4 focus:ring-focus/20"
															/>
														</div>
														<div>
															<label
																for={`ends-at-${transfer.id}`}
																class="text-sm font-bold text-ink">Hasta</label
															>
															<input
																id={`ends-at-${transfer.id}`}
																name="endsAt"
																type="datetime-local"
																min={transfer.status === 'ACTIVE'
																	? transfer.endsAtInput
																	: data.nowInput}
																required
																value={values.endsAt}
																class="mt-2 min-h-12 w-full rounded-xl border border-ink/20 bg-white px-4 text-base text-ink outline-none focus:border-focus focus:ring-4 focus:ring-focus/20"
															/>
														</div>
													</div>

													<div class="mt-4">
														<label for={`note-${transfer.id}`} class="text-sm font-bold text-ink"
															>Nota</label
														>
														<textarea
															id={`note-${transfer.id}`}
															name="note"
															rows="3"
															maxlength="500"
															required
															class="mt-2 w-full resize-y rounded-xl border border-ink/20 bg-white px-4 py-3 text-base text-ink outline-none focus:border-focus focus:ring-4 focus:ring-focus/20"
															>{values.note}</textarea
														>
													</div>

													<button
														type="submit"
														disabled={submitting}
														class="mt-5 inline-flex min-h-12 items-center justify-center gap-2 rounded-full bg-brand px-5 font-bold text-white hover:bg-brand/90 focus:ring-4 focus:ring-focus/30 focus:outline-none disabled:opacity-50"
													>
														<Save aria-hidden="true" size={18} strokeWidth={2} />
														Guardar cambios
													</button>
												</form>
											</div>
										</div>
									{:else if openTransferPanel?.transferId === transfer.id && openTransferPanel?.type === 'terminal'}
										<div id={`terminal-transfer-${transfer.id}`} class="border-t border-ink/10 p-3">
											<div class="rounded-2xl bg-red-50 p-5">
												<div class="flex items-start gap-3">
													<span
														class="flex size-10 shrink-0 items-center justify-center rounded-full bg-white text-red-800"
													>
														{#if transfer.status === 'ACTIVE'}
															<Flag aria-hidden="true" size={19} strokeWidth={2} />
														{:else}
															<X aria-hidden="true" size={19} strokeWidth={2} />
														{/if}
													</span>
													<div class="min-w-0 flex-1">
														<p class="font-bold text-red-950">
															{transfer.status === 'ACTIVE'
																? '¿Finalizar este traslado ahora?'
																: '¿Cancelar este traslado programado?'}
														</p>
														<p class="mt-1 text-sm leading-6 text-red-950/80">
															{transfer.status === 'ACTIVE'
																? 'Las próximas lecturas volverán a participar en la confirmación de salidas.'
																: 'Quedará en el historial como cancelado y no llegará a activarse.'}
														</p>
													</div>
												</div>
												<form
													method="POST"
													action={transfer.status === 'ACTIVE' ? '?/end' : '?/cancel'}
													use:enhance={enhanceForm}
													class="mt-4 flex flex-wrap gap-2"
												>
													<input type="hidden" name="transferId" value={transfer.id} />
													<button
														type="submit"
														disabled={submitting}
														class="inline-flex min-h-11 cursor-pointer items-center justify-center gap-2 rounded-full bg-red-800 px-5 font-bold text-white transition hover:bg-red-900 focus:ring-4 focus:ring-red-700/20 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
													>
														{#if transfer.status === 'ACTIVE'}
															<Flag aria-hidden="true" size={17} strokeWidth={2} />
														{:else}
															<X aria-hidden="true" size={17} strokeWidth={2} />
														{/if}
														{transfer.status === 'ACTIVE'
															? 'Confirmar finalización'
															: 'Confirmar cancelación'}
													</button>
													<button
														type="button"
														onclick={() => toggleTransferPanel(transfer.id, 'terminal')}
														disabled={submitting}
														class="min-h-11 cursor-pointer rounded-full px-4 font-bold text-red-950 transition hover:bg-white focus:ring-4 focus:ring-red-700/20 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
													>
														Volver
													</button>
												</form>
											</div>
										</div>
									{/if}
								{/if}
							</li>
						{/each}
					</ul>
				{/if}
			</section>
		</div>

		<section class="mt-8 rounded-2xl bg-white p-6 shadow-sm">
			<Heading
				icon={History}
				title="Historial reciente"
				subtitle="Traslados finalizados o cancelados, sin eliminar su contexto."
			/>

			{#if data.history.length === 0}
				<div class="mt-8 max-w-2xl">
					<Alert
						icon={Clock3}
						title="Aún no hay traslados anteriores"
						subtitle="El historial aparecerá aquí cuando finalice o se cancele un traslado."
					/>
				</div>
			{:else}
				<ul class="mt-8 grid gap-4 md:grid-cols-2 xl:grid-cols-3">
					{#each data.history as transfer (transfer.id)}
						{@const presentation = statusPresentation(transfer.status)}
						<li>
							<InfoItem
								icon={transfer.status === 'COMPLETED' ? CircleCheck : X}
								title={`${presentation.label}: ${transfer.note}`}
								info={`${presentDate(transfer.startsAt)} — ${presentDate(transfer.endedAt ?? transfer.endsAt)}`}
								tone={presentation.tone}
							/>
						</li>
					{/each}
				</ul>
			{/if}
		</section>
	</div>
</main>
