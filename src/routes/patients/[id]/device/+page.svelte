<script lang="ts">
	import { enhance, type SubmitFunction } from '$app/forms';
	import { resolve } from '$app/paths';
	import Alert from '#lib/components/ui/Alert.svelte';
	import Heading from '#lib/components/ui/Heading.svelte';
	import InfoItem from '#lib/components/ui/InfoItem.svelte';
	import Modal from '#lib/components/ui/Modal.svelte';
	import CalendarDays from '@lucide/svelte/icons/calendar-days';
	import CircleAlert from '@lucide/svelte/icons/circle-alert';
	import CircleCheck from '@lucide/svelte/icons/circle-check';
	import Clock3 from '@lucide/svelte/icons/clock-3';
	import MapPinned from '@lucide/svelte/icons/map-pinned';
	import ScanBarcode from '@lucide/svelte/icons/scan-barcode';
	import Smartphone from '@lucide/svelte/icons/smartphone';
	import Unplug from '@lucide/svelte/icons/unplug';
	import UsersRound from '@lucide/svelte/icons/users-round';
	import type { PageProps } from './$types';

	let { data, form }: PageProps = $props();
	let assigning = $state(false);
	let unassigning = $state(false);
	let unassignModalOpen = $state(false);
	let errors = $derived((form?.errors ?? {}) as Record<string, string>);
	let actionIntent = $derived((form as { intent?: string } | null)?.intent);
	const dateFormatter = new Intl.DateTimeFormat('es-DO', {
		dateStyle: 'medium',
		timeZone: 'America/Santo_Domingo'
	});

	const enhanceAssignmentForm: SubmitFunction = () => {
		assigning = true;

		return async ({ result, update }) => {
			await update({ reset: result.type === 'success' });
			assigning = false;

			if (result.type === 'failure') {
				requestAnimationFrame(() => {
					document.querySelector<HTMLElement>('[data-form-error]')?.focus();
				});
			}
		};
	};

	const enhanceUnassignmentForm: SubmitFunction = () => {
		unassigning = true;

		return async ({ result, update }) => {
			await update({ reset: false });
			unassigning = false;

			if (result.type === 'success') {
				unassignModalOpen = false;
				return;
			}

			requestAnimationFrame(() => {
				document.querySelector<HTMLElement>('[data-unassign-error]')?.focus();
			});
		};
	};

	function closeUnassignModal() {
		if (!unassigning) unassignModalOpen = false;
	}
</script>

{#snippet unassignModalContent()}
	<p class="leading-7 text-muted">
		El dispositivo <strong class="text-ink">{data.assignment?.serialNumber}</strong> quedará disponible
		para asignarlo a otra persona.
	</p>

	<div class="mt-4 rounded-2xl bg-surface-muted p-4">
		<p class="font-bold text-ink">El historial se conservará</p>
		<p class="mt-1 text-sm leading-6 text-muted">
			Las ubicaciones y los episodios anteriores seguirán vinculados a
			{data.patient.firstName}. El monitoreo se detendrá hasta configurar otro dispositivo.
		</p>
	</div>

	{#if actionIntent === 'unassign' && errors.unassign}
		<div
			data-unassign-error
			tabindex="-1"
			class="mt-4 rounded-2xl focus:ring-4 focus:ring-red-700/20 focus:outline-none"
		>
			<Alert
				icon={CircleAlert}
				title="No se puede desvincular todavía"
				subtitle={errors.unassign}
				color="danger"
			/>
		</div>
	{/if}
{/snippet}

{#snippet unassignModalFooter()}
	{#if data.assignment}
		<form
			method="POST"
			action="?/unassign"
			use:enhance={enhanceUnassignmentForm}
			aria-busy={unassigning}
			class="flex flex-col gap-2 sm:flex-row sm:justify-end"
		>
			<input type="hidden" name="assignmentId" value={data.assignment.id} />
			<button
				type="button"
				onclick={closeUnassignModal}
				disabled={unassigning}
				class="min-h-12 cursor-pointer rounded-full px-5 font-bold text-ink transition hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
			>
				Volver
			</button>
			<button
				type="submit"
				disabled={unassigning}
				class="inline-flex min-h-12 cursor-pointer items-center justify-center gap-2 rounded-full bg-red-800 px-5 font-bold text-white transition hover:bg-red-900 focus:ring-4 focus:ring-red-700/20 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
			>
				<Unplug aria-hidden="true" size={18} strokeWidth={2} />
				{unassigning ? 'Desvinculando…' : 'Confirmar desvinculación'}
			</button>
		</form>
	{/if}
{/snippet}

<svelte:head>
	<title>{data.assignment ? 'Dispositivo configurado' : 'Configurar dispositivo'} | Senda</title>
	<meta
		name="description"
		content="Administra el dispositivo de Senda asignado a un paciente autorizado."
	/>
</svelte:head>

<main id="contenido-principal" class="px-5 py-8 sm:px-8 lg:px-0">
	<div class="w-full max-w-4xl">
		<h2 class="mb-8 text-2xl font-bold text-ink">
			{data.assignment ? 'Dispositivo configurado' : 'Configurar dispositivo'}
		</h2>

		{#if actionIntent === 'unassign' && form?.success}
			<div class="mb-8">
				<Alert
					icon={CircleCheck}
					title="Dispositivo desvinculado"
					subtitle={`El historial de ${data.patient.firstName} se conservó y el dispositivo ya puede asignarse a otra persona.`}
					color="positive"
				/>
			</div>
		{/if}

		{#if data.assignment}
			<section class="overflow-hidden rounded-2xl bg-white shadow-sm">
				<div class="p-6">
					<Heading
						icon={Smartphone}
						title="Dispositivo asignado"
						subtitle="Este equipo recibe las ubicaciones del paciente."
					/>

					<div class="mt-6 grid gap-3 sm:grid-cols-2" role="status">
						<InfoItem
							icon={ScanBarcode}
							title="Serial"
							info={data.assignment.serialNumber}
							tone="positive"
						/>
						<InfoItem
							icon={CalendarDays}
							title="Asignado desde"
							info={dateFormatter.format(new Date(data.assignment.assignedAt))}
							tone="positive"
						/>
					</div>
				</div>

				<div class="flex flex-col gap-2 border-t border-ink/10 p-4 sm:flex-row">
					<a
						href={resolve('/patients/[id]/map', { id: data.patient.id })}
						class="inline-flex min-h-12 items-center justify-center gap-2 rounded-full bg-brand px-5 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none"
					>
						<MapPinned aria-hidden="true" size={18} strokeWidth={2} />
						Ver mapa
					</a>
					<a
						href={resolve('/patients')}
						class="inline-flex min-h-12 items-center justify-center gap-2 rounded-full px-5 font-bold text-brand transition hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none"
					>
						<UsersRound aria-hidden="true" size={18} strokeWidth={2} />
						Ver pacientes
					</a>
					<button
						type="button"
						onclick={() => (unassignModalOpen = true)}
						class="inline-flex min-h-12 cursor-pointer items-center justify-center gap-2 rounded-full px-5 font-bold text-red-800 transition hover:bg-red-50 focus:ring-4 focus:ring-red-700/20 focus:outline-none sm:ml-auto"
					>
						<Unplug aria-hidden="true" size={18} strokeWidth={2} />
						Desvincular dispositivo
					</button>
				</div>
			</section>
		{:else}
			<section class="overflow-hidden rounded-2xl bg-white shadow-sm">
				<form
					method="POST"
					action="?/assign"
					use:enhance={enhanceAssignmentForm}
					aria-busy={assigning}
				>
					<div class="p-6">
						<Heading
							icon={Smartphone}
							title="Dispositivo Senda"
							subtitle="Asigna uno de los dispositivos disponibles para comenzar a recibir ubicaciones."
						/>

						{#if data.onboarding}
							<div class="mt-6 rounded-2xl bg-surface-muted p-4 text-sm leading-6 text-ink">
								El grupo y el paciente ya están creados. Puedes configurar el dispositivo ahora o
								continuar y hacerlo después.
							</div>
						{/if}

						{#if Object.keys(errors).length > 0}
							<div
								data-form-error
								tabindex="-1"
								class="mt-6 rounded-2xl focus:ring-4 focus:ring-red-700/20 focus:outline-none"
							>
								<Alert
									icon={CircleAlert}
									title="Revisa el serial del dispositivo"
									subtitle={errors.form ?? 'Corrige el campo indicado e inténtalo nuevamente.'}
									color="danger"
								/>
							</div>
						{/if}

						<div class="mt-6">
							<label for="serialNumber" class="text-sm font-bold text-ink">
								Serial del dispositivo
							</label>
							<p id="serial-help" class="mt-1 max-w-2xl text-sm leading-6 text-muted">
								Introduce el serial indicado en el dispositivo. No introduzcas espacios.
							</p>
							<input
								id="serialNumber"
								name="serialNumber"
								type="text"
								autocomplete="off"
								spellcheck="false"
								inputmode="text"
								minlength="8"
								maxlength="64"
								required
								value={form?.values?.serialNumber ?? ''}
								aria-invalid={errors.serialNumber ? 'true' : undefined}
								aria-describedby={errors.serialNumber ? 'serial-help serial-error' : 'serial-help'}
								class="mt-2 min-h-12 w-full rounded-xl border border-ink/20 bg-white px-4 font-mono text-base text-ink uppercase transition outline-none focus:border-focus focus:ring-4 focus:ring-focus/20"
							/>
							{#if errors.serialNumber}
								<p id="serial-error" class="mt-2 text-sm font-semibold text-red-800">
									{errors.serialNumber}
								</p>
							{/if}
						</div>
					</div>

					<div class="flex flex-col gap-2 border-t border-ink/10 p-4 sm:flex-row sm:items-center">
						<button
							type="submit"
							disabled={assigning}
							class="inline-flex min-h-12 cursor-pointer items-center justify-center gap-2 rounded-full bg-brand px-5 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
						>
							<Smartphone aria-hidden="true" size={19} strokeWidth={2} />
							{assigning ? 'Configurando…' : 'Configurar dispositivo'}
						</button>
						<a
							href={resolve('/patients')}
							class="inline-flex min-h-12 items-center justify-center gap-2 rounded-full px-5 font-bold text-brand transition hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none"
						>
							<Clock3 aria-hidden="true" size={19} strokeWidth={2} />
							Configurar después
						</a>
					</div>
				</form>
			</section>
		{/if}
	</div>
</main>

<Modal
	id="unassign-device-modal"
	open={unassignModalOpen && data.assignment !== null}
	title="Desvincular dispositivo"
	subtitle={`Confirma el cambio para ${data.patient.firstName} ${data.patient.lastName}.`}
	icon={Unplug}
	children={unassignModalContent}
	footer={unassignModalFooter}
	onclose={closeUnassignModal}
/>
