<script lang="ts">
	import { enhance, type SubmitFunction } from '$app/forms';
	import Alert from '#lib/components/ui/Alert.svelte';
	import Heading from '#lib/components/ui/Heading.svelte';
	import InfoItem from '#lib/components/ui/InfoItem.svelte';
	import Modal from '#lib/components/ui/Modal.svelte';
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
	import type { UiIcon, UiTone } from '#lib/types/ui.js';
	import type { PageProps } from './$types';

	type Transfer = PageProps['data']['currentTransfers'][number];
	type TransferStatus = Transfer['status'];
	type StatusPresentation = { label: string; tone: UiTone };
	type TransferModal = {
		transferId: string;
		type: 'edit' | 'extend' | 'cancel' | 'finish';
	};
	type ModalPresentation = { title: string; subtitle: string; icon: UiIcon };

	let { data, form }: PageProps = $props();
	let submitting = $state(false);
	let saveResult = $derived(form?.action === 'save' ? form : null);
	let saveErrors = $derived((saveResult?.errors ?? {}) as Record<string, string>);
	let transferModal = $state<TransferModal | null>(null);
	let selectedTransfer = $derived(
		transferModal
			? (data.currentTransfers.find((transfer) => transfer.id === transferModal?.transferId) ??
					null)
			: null
	);
	let modalPresentation = $derived(transferModalPresentation(transferModal?.type ?? 'edit'));

	const dateFormatter = new Intl.DateTimeFormat('es-DO', {
		dateStyle: 'medium',
		timeStyle: 'short',
		timeZone: 'America/Santo_Domingo'
	});

	const enhanceForm: SubmitFunction = () => {
		submitting = true;

		return async ({ result, update }) => {
			await update({ reset: result.type === 'success' });
			if (result.type === 'success') transferModal = null;
			submitting = false;
		};
	};

	function openTransferModal(transferId: string, type: TransferModal['type']) {
		transferModal = { transferId, type };
	}

	function closeTransferModal() {
		transferModal = null;
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

	function transferModalPresentation(type: TransferModal['type']): ModalPresentation {
		switch (type) {
			case 'edit':
				return {
					title: 'Editar traslado',
					subtitle: 'Ajusta el horario o la nota antes de que comience el traslado.',
					icon: PencilLine
				};
			case 'extend':
				return {
					title: 'Extender traslado',
					subtitle: 'Ajusta la hora de finalización sin interrumpir el registro de ubicaciones.',
					icon: Clock3
				};
			case 'cancel':
				return {
					title: 'Cancelar traslado',
					subtitle: 'Confirma que este traslado programado ya no debe activarse.',
					icon: X
				};
			case 'finish':
				return {
					title: 'Finalizar traslado',
					subtitle: 'Confirma el regreso al monitoreo habitual antes de continuar.',
					icon: Flag
				};
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

{#snippet transferModalContent()}
	{#if selectedTransfer}
		{@const values = editValues(selectedTransfer)}
		{@const modalErrors = saveResult?.values?.transferId === selectedTransfer.id ? saveErrors : {}}
		{#if transferModal?.type === 'edit'}
			{#if Object.keys(modalErrors).length > 0}
				<div class="mb-6">
					<Alert
						icon={CircleAlert}
						title="Revisa el traslado"
						subtitle={modalErrors.form ?? 'Corrige los campos indicados.'}
						color="danger"
					/>
				</div>
			{/if}

			<form
				id="edit-scheduled-transfer-form"
				method="POST"
				action="?/save"
				use:enhance={enhanceForm}
			>
				<input type="hidden" name="transferId" value={selectedTransfer.id} />

				<div class="grid gap-5 sm:grid-cols-2">
					<div>
						<label for="scheduled-transfer-starts-at" class="text-sm font-bold text-ink"
							>Desde</label
						>
						<input
							id="scheduled-transfer-starts-at"
							name="startsAt"
							type="datetime-local"
							min={data.nowInput}
							required
							value={values.startsAt}
							aria-invalid={modalErrors.startsAt ? 'true' : undefined}
							aria-describedby={modalErrors.startsAt ? 'scheduled-transfer-start-error' : undefined}
							class="mt-2 min-h-12 w-full rounded-xl border border-ink/20 bg-white px-4 text-base text-ink outline-none focus:border-focus focus:ring-4 focus:ring-focus/20"
						/>
						{#if modalErrors.startsAt}
							<p
								id="scheduled-transfer-start-error"
								class="mt-2 text-sm font-semibold text-red-800"
							>
								{modalErrors.startsAt}
							</p>
						{/if}
					</div>

					<div>
						<label for="scheduled-transfer-ends-at" class="text-sm font-bold text-ink">Hasta</label>
						<input
							id="scheduled-transfer-ends-at"
							name="endsAt"
							type="datetime-local"
							min={data.nowInput}
							required
							value={values.endsAt}
							aria-invalid={modalErrors.endsAt ? 'true' : undefined}
							aria-describedby={modalErrors.endsAt
								? 'scheduled-transfer-end-error'
								: 'scheduled-transfer-time-help'}
							class="mt-2 min-h-12 w-full rounded-xl border border-ink/20 bg-white px-4 text-base text-ink outline-none focus:border-focus focus:ring-4 focus:ring-focus/20"
						/>
						{#if modalErrors.endsAt}
							<p id="scheduled-transfer-end-error" class="mt-2 text-sm font-semibold text-red-800">
								{modalErrors.endsAt}
							</p>
						{/if}
					</div>
				</div>

				<p id="scheduled-transfer-time-help" class="mt-3 text-sm leading-5 text-muted">
					La duración total no puede superar 24 horas.
				</p>

				<div class="mt-5">
					<label for="scheduled-transfer-note" class="text-sm font-bold text-ink">Nota</label>
					<textarea
						id="scheduled-transfer-note"
						name="note"
						rows="3"
						maxlength="500"
						required
						aria-invalid={modalErrors.note ? 'true' : undefined}
						aria-describedby={modalErrors.note ? 'scheduled-transfer-note-error' : undefined}
						class="mt-2 w-full resize-y rounded-xl border border-ink/20 bg-white px-4 py-3 text-base text-ink outline-none focus:border-focus focus:ring-4 focus:ring-focus/20"
						>{values.note}</textarea
					>
					{#if modalErrors.note}
						<p id="scheduled-transfer-note-error" class="mt-2 text-sm font-semibold text-red-800">
							{modalErrors.note}
						</p>
					{/if}
				</div>
			</form>
		{:else if transferModal?.type === 'extend'}
			{#if Object.keys(modalErrors).length > 0}
				<div class="mb-6">
					<Alert
						icon={CircleAlert}
						title="Revisa la extensión"
						subtitle={modalErrors.form ?? 'Corrige los campos indicados.'}
						color="danger"
					/>
				</div>
			{/if}

			<div class="grid gap-3 rounded-2xl bg-canvas p-4 sm:grid-cols-2">
				<div>
					<p class="text-sm font-semibold text-muted">Inició</p>
					<p class="mt-1 font-bold text-ink">{presentDate(selectedTransfer.startsAt)}</p>
				</div>
				<div>
					<p class="text-sm font-semibold text-muted">Finaliza actualmente</p>
					<p class="mt-1 font-bold text-ink">{presentDate(selectedTransfer.endsAt)}</p>
				</div>
			</div>

			<form
				id="extend-active-transfer-form"
				method="POST"
				action="?/save"
				use:enhance={enhanceForm}
				class="mt-6"
			>
				<input type="hidden" name="transferId" value={selectedTransfer.id} />
				<input type="hidden" name="startsAt" value={values.startsAt} />

				<div>
					<label for="active-transfer-ends-at" class="text-sm font-bold text-ink"
						>Nueva finalización</label
					>
					<input
						id="active-transfer-ends-at"
						name="endsAt"
						type="datetime-local"
						min={selectedTransfer.endsAtInput}
						required
						value={values.endsAt}
						aria-invalid={modalErrors.endsAt ? 'true' : undefined}
						aria-describedby={modalErrors.endsAt
							? 'active-transfer-end-error'
							: 'active-transfer-end-help'}
						class="mt-2 min-h-12 w-full rounded-xl border border-ink/20 bg-white px-4 text-base text-ink outline-none focus:border-focus focus:ring-4 focus:ring-focus/20"
					/>
					{#if modalErrors.endsAt}
						<p id="active-transfer-end-error" class="mt-2 text-sm font-semibold text-red-800">
							{modalErrors.endsAt}
						</p>
					{:else}
						<p id="active-transfer-end-help" class="mt-2 text-sm leading-5 text-muted">
							Puedes extenderlo sin superar 24 horas desde el inicio.
						</p>
					{/if}
				</div>

				<div class="mt-5">
					<label for="active-transfer-note" class="text-sm font-bold text-ink">Nota</label>
					<textarea
						id="active-transfer-note"
						name="note"
						rows="3"
						maxlength="500"
						required
						aria-invalid={modalErrors.note ? 'true' : undefined}
						aria-describedby={modalErrors.note ? 'active-transfer-note-error' : undefined}
						class="mt-2 w-full resize-y rounded-xl border border-ink/20 bg-white px-4 py-3 text-base text-ink outline-none focus:border-focus focus:ring-4 focus:ring-focus/20"
						>{values.note}</textarea
					>
					{#if modalErrors.note}
						<p id="active-transfer-note-error" class="mt-2 text-sm font-semibold text-red-800">
							{modalErrors.note}
						</p>
					{/if}
				</div>
			</form>
		{:else}
			{@const cancelling = transferModal?.type === 'cancel'}
			{#if form?.action === (cancelling ? 'cancel' : 'end') && form.message}
				<div class="mb-6">
					<Alert
						icon={CircleAlert}
						title={cancelling
							? 'No pudimos cancelar el traslado'
							: 'No pudimos finalizar el traslado'}
						subtitle={form.message}
						color="danger"
					/>
				</div>
			{/if}

			<div class="rounded-2xl bg-red-50 p-4">
				<div class="flex items-start gap-3">
					<span
						class="flex size-10 shrink-0 items-center justify-center rounded-full bg-white text-red-800"
					>
						{#if cancelling}
							<X aria-hidden="true" size={19} strokeWidth={2} />
						{:else}
							<Flag aria-hidden="true" size={19} strokeWidth={2} />
						{/if}
					</span>
					<div class="min-w-0">
						<p class="font-bold text-red-950">{selectedTransfer.note}</p>
						<p class="mt-1 text-sm leading-6 text-red-950/80">
							{cancelling
								? 'Quedará en el historial como cancelado y no llegará a activarse. Esta acción no se puede deshacer.'
								: 'Las próximas lecturas volverán a participar en la confirmación de salidas. Esta acción no se puede deshacer.'}
						</p>
					</div>
				</div>
			</div>
		{/if}
	{/if}
{/snippet}

{#snippet transferModalFooter()}
	{#if selectedTransfer}
		{#if transferModal?.type === 'edit' || transferModal?.type === 'extend'}
			{@const editing = transferModal.type === 'edit'}
			<div class="flex flex-col gap-2 sm:flex-row sm:justify-end">
				<button
					type="button"
					onclick={closeTransferModal}
					disabled={submitting}
					class="min-h-12 cursor-pointer rounded-full px-5 font-bold text-ink transition hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
				>
					Volver
				</button>
				<button
					type="submit"
					form={editing ? 'edit-scheduled-transfer-form' : 'extend-active-transfer-form'}
					disabled={submitting}
					class="inline-flex min-h-12 cursor-pointer items-center justify-center gap-2 rounded-full bg-brand px-5 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/30 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
				>
					<Save aria-hidden="true" size={18} strokeWidth={2} />
					{submitting ? 'Guardando…' : editing ? 'Guardar cambios' : 'Guardar extensión'}
				</button>
			</div>
		{:else}
			{@const cancelling = transferModal?.type === 'cancel'}
			<form
				method="POST"
				action={cancelling ? '?/cancel' : '?/end'}
				use:enhance={enhanceForm}
				class="flex flex-col gap-2 sm:flex-row sm:justify-end"
			>
				<input type="hidden" name="transferId" value={selectedTransfer.id} />
				<button
					type="button"
					onclick={closeTransferModal}
					disabled={submitting}
					class="min-h-12 cursor-pointer rounded-full px-5 font-bold text-ink transition hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
				>
					Volver
				</button>
				<button
					type="submit"
					disabled={submitting}
					class="inline-flex min-h-12 cursor-pointer items-center justify-center gap-2 rounded-full bg-red-800 px-5 font-bold text-white transition hover:bg-red-900 focus:ring-4 focus:ring-red-700/20 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
				>
					{#if cancelling}
						<X aria-hidden="true" size={18} strokeWidth={2} />
						{submitting ? 'Cancelando…' : 'Confirmar cancelación'}
					{:else}
						<Flag aria-hidden="true" size={18} strokeWidth={2} />
						{submitting ? 'Finalizando…' : 'Confirmar finalización'}
					{/if}
				</button>
			</form>
		{/if}
	{/if}
{/snippet}

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

		<div class={['grid gap-6', data.canManageTransfers && 'xl:grid-cols-12']}>
			{#if data.canManageTransfers}
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

			<section
				class={['rounded-2xl bg-white p-6 shadow-sm', data.canManageTransfers && 'xl:col-span-7']}
			>
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
							subtitle="Puedes programar uno cuando el paciente deba desplazarse fuera de sus zonas permitidas."
						/>
					</div>
				{:else}
					<ul class="mt-8 space-y-3">
						{#each data.currentTransfers as transfer (transfer.id)}
							{@const presentation = statusPresentation(transfer.status)}
							<li
								class={[
									'overflow-hidden rounded-2xl',
									transfer.status === 'ACTIVE' ? 'bg-amber-50' : 'bg-canvas'
								]}
							>
								<div class="flex min-h-16 items-start gap-3 p-4">
									<span
										class={[
											'flex size-10 shrink-0 items-center justify-center rounded-full',
											presentation.tone === 'warning'
												? 'bg-white text-amber-800'
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

								{#if data.canManageTransfers}
									<div
										class={[
											'flex flex-wrap gap-2 border-t p-3',
											transfer.status === 'ACTIVE' ? 'border-amber-900/10' : 'border-ink/10'
										]}
									>
										<button
											type="button"
											onclick={() =>
												openTransferModal(
													transfer.id,
													transfer.status === 'ACTIVE' ? 'extend' : 'edit'
												)}
											aria-haspopup="dialog"
											aria-controls="transfer-modal"
											class={[
												'inline-flex min-h-11 cursor-pointer items-center gap-2 rounded-full px-4 font-bold transition focus:ring-4 focus:outline-none',
												transfer.status === 'ACTIVE'
													? 'text-amber-900 hover:bg-white focus:ring-amber-700/20'
													: 'text-brand hover:bg-white focus:ring-focus/30'
											]}
										>
											<PencilLine aria-hidden="true" size={18} strokeWidth={2} />
											{transfer.status === 'ACTIVE' ? 'Extender traslado' : 'Editar traslado'}
										</button>

										<button
											type="button"
											onclick={() =>
												openTransferModal(
													transfer.id,
													transfer.status === 'ACTIVE' ? 'finish' : 'cancel'
												)}
											aria-haspopup="dialog"
											aria-controls="transfer-modal"
											class="inline-flex min-h-11 cursor-pointer items-center gap-2 rounded-full px-4 font-bold text-red-800 transition hover:bg-red-50 focus:ring-4 focus:ring-red-700/20 focus:outline-none"
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

<Modal
	id="transfer-modal"
	open={selectedTransfer !== null}
	title={modalPresentation.title}
	subtitle={modalPresentation.subtitle}
	icon={modalPresentation.icon}
	children={transferModalContent}
	footer={transferModalFooter}
	onclose={closeTransferModal}
/>
