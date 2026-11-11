<script lang="ts">
	import { enhance, type SubmitFunction } from '$app/forms';
	import { resolve } from '$app/paths';
	import Alert from '#lib/components/ui/Alert.svelte';
	import Heading from '#lib/components/ui/Heading.svelte';
	import InfoItem from '#lib/components/ui/InfoItem.svelte';
	import Modal from '#lib/components/ui/Modal.svelte';
	import Archive from '@lucide/svelte/icons/archive';
	import ArchiveRestore from '@lucide/svelte/icons/archive-restore';
	import ArrowUpRight from '@lucide/svelte/icons/arrow-up-right';
	import BellRing from '@lucide/svelte/icons/bell-ring';
	import CircleAlert from '@lucide/svelte/icons/circle-alert';
	import HeartHandshake from '@lucide/svelte/icons/heart-handshake';
	import Smartphone from '@lucide/svelte/icons/smartphone';
	import UserRound from '@lucide/svelte/icons/user-round';
	import UsersRound from '@lucide/svelte/icons/users-round';
	import type { PageProps } from './$types';

	let { data, form }: PageProps = $props();
	let restoreSubmitting = $state(false);
	let restoreModalOpen = $state(false);
	let restoreResult = $derived(form?.action === 'restore' ? form : null);
	let restoreErrors = $derived((restoreResult?.errors ?? {}) as Record<string, string>);
	const archiveDateFormatter = new Intl.DateTimeFormat('es-DO', {
		dateStyle: 'long',
		timeStyle: 'short',
		timeZone: 'America/Santo_Domingo'
	});

	const enhanceRestore: SubmitFunction = () => {
		restoreSubmitting = true;

		return async ({ result, update }) => {
			await update({ reset: false });
			restoreSubmitting = false;

			if (result.type === 'failure') {
				requestAnimationFrame(() => {
					document.querySelector<HTMLElement>('[data-restore-error]')?.focus();
				});
			}
		};
	};

	function closeRestoreModal() {
		if (!restoreSubmitting) restoreModalOpen = false;
	}
</script>

{#snippet restoreModalContent()}
	<p class="leading-7 text-muted">
		El paciente volverá a la lista activa, pero continuará sin dispositivo y sin monitoreo hasta que
		un administrador configure uno.
	</p>
	<div class="mt-4 rounded-2xl bg-surface-muted p-4">
		<p class="font-bold text-ink">Los códigos anteriores seguirán inactivos</p>
		<p class="mt-1 text-sm leading-6 text-muted">
			Si necesitas compartir el acceso después de restaurarlo, deberás generar un código nuevo.
		</p>
	</div>
	{#if restoreErrors.restore}
		<div
			data-restore-error
			tabindex="-1"
			class="mt-4 rounded-2xl focus:ring-4 focus:ring-red-700/20 focus:outline-none"
		>
			<Alert
				icon={CircleAlert}
				title="No pudimos restaurar el paciente"
				subtitle={restoreErrors.restore}
				color="danger"
			/>
		</div>
	{/if}
{/snippet}

{#snippet restoreModalFooter()}
	<form
		method="POST"
		action="?/restore"
		use:enhance={enhanceRestore}
		aria-busy={restoreSubmitting}
		class="flex flex-col gap-2 sm:flex-row sm:justify-end"
	>
		<button
			type="button"
			onclick={closeRestoreModal}
			disabled={restoreSubmitting}
			class="min-h-12 cursor-pointer rounded-full px-5 font-bold text-ink transition hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
		>
			Volver
		</button>
		<button
			type="submit"
			disabled={restoreSubmitting}
			class="inline-flex min-h-12 cursor-pointer items-center justify-center gap-2 rounded-full bg-brand px-5 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
		>
			<ArchiveRestore aria-hidden="true" size={18} strokeWidth={2} />
			{restoreSubmitting ? 'Restaurando…' : 'Restaurar paciente'}
		</button>
	</form>
{/snippet}

<svelte:head>
	<title>{data.patient.firstName} {data.patient.lastName} — Archivo | Senda</title>
	<meta name="description" content="Información e historial conservado del paciente en Senda." />
</svelte:head>

<main id="contenido-principal" class="px-5 py-8 sm:px-8 lg:px-0">
	<div class="w-full">
		{#if restoreErrors.restore && !restoreModalOpen}
			<div class="mb-8 max-w-3xl">
				<Alert
					icon={CircleAlert}
					title="No pudimos completar la acción"
					subtitle={restoreErrors.restore}
					color="danger"
				/>
			</div>
		{/if}

		<h2 class="mb-8 text-2xl font-bold text-ink">Datos del paciente</h2>

		<div class="grid gap-6 xl:grid-cols-12">
			<section class="rounded-2xl bg-white p-6 shadow-sm xl:col-span-7">
				<Heading
					icon={Archive}
					title="Datos conservados"
					subtitle="Información identificativa disponible en el archivo."
				/>

				<dl class="mt-8 grid gap-4 sm:grid-cols-2">
					<div class="rounded-2xl bg-surface-muted p-4">
						<dt class="text-sm font-semibold text-muted">Nombre</dt>
						<dd class="font-bold text-ink">{data.patient.firstName}</dd>
					</div>
					<div class="rounded-2xl bg-surface-muted p-4">
						<dt class="text-sm font-semibold text-muted">Apellido</dt>
						<dd class="font-bold text-ink">{data.patient.lastName}</dd>
					</div>
				</dl>
			</section>

			<aside class="rounded-2xl bg-white p-6 shadow-sm xl:col-span-5">
				<Heading
					icon={HeartHandshake}
					title="Resumen del paciente"
					subtitle="Contexto administrativo conservado."
				/>

				<div class="mt-8 grid gap-4 sm:grid-cols-2">
					<div class="sm:col-span-2">
						<InfoItem
							icon={Archive}
							title="Paciente archivado"
							info={`Archivado el ${archiveDateFormatter.format(new Date(data.patient.archivedAt))}. Su historial permanece conservado.`}
							tone="positive"
						/>
					</div>

					<InfoItem
						icon={UsersRound}
						title="Grupo"
						info={data.patient.group?.name ?? 'Sin grupo visible'}
						tone="positive"
					/>

					<InfoItem icon={Smartphone} title="Dispositivo" info="Sin dispositivo" tone="neutral" />
				</div>
			</aside>
		</div>

		<section aria-labelledby="archive-sections-title" class="mt-8">
			<h2 id="archive-sections-title" class="mb-8 text-2xl font-bold text-ink">
				Archivo del paciente
			</h2>

			<div class="grid gap-6 lg:grid-cols-2">
				<article class={['rounded-2xl bg-white p-6 shadow-sm', !data.isAdmin && 'lg:col-span-2']}>
					<Heading
						icon={BellRing}
						title="Historial conservado"
						subtitle="Consulta los episodios registrados antes de archivar al paciente."
					/>

					<a
						href={resolve('/patients/[id]/episodes', { id: data.patient.id })}
						class="group mt-6 flex min-h-24 items-center gap-4 rounded-2xl bg-surface-muted p-4 transition-colors hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none"
					>
						<div
							class="flex size-11 shrink-0 items-center justify-center rounded-full bg-white text-brand"
						>
							<BellRing aria-hidden="true" size={20} strokeWidth={2} />
						</div>
						<div class="min-w-0 flex-1">
							<h3 class="font-bold text-ink">Historial de episodios</h3>
							<p class="text-sm leading-5 text-muted">Salidas confirmadas y resueltas.</p>
						</div>
						<ArrowUpRight
							aria-hidden="true"
							class="shrink-0 text-brand transition-transform group-hover:translate-x-0.5 group-hover:-translate-y-0.5"
							size={19}
							strokeWidth={2}
						/>
					</a>
				</article>

				{#if data.isAdmin}
					<article class="rounded-2xl bg-white p-6 shadow-sm">
						<Heading
							icon={UserRound}
							title="Administración"
							subtitle="Restaura al paciente cuando sea necesario reanudar su gestión."
						/>

						<button
							type="button"
							onclick={() => (restoreModalOpen = true)}
							class="mt-6 flex min-h-24 w-full cursor-pointer items-center gap-4 rounded-2xl bg-surface-muted p-4 text-left transition-colors hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none"
						>
							<div
								class="flex size-11 shrink-0 items-center justify-center rounded-full bg-white text-brand"
							>
								<ArchiveRestore aria-hidden="true" size={20} strokeWidth={2} />
							</div>
							<div class="min-w-0 flex-1">
								<h3 class="font-bold text-ink">Restaurar paciente</h3>
								<p class="text-sm leading-5 text-muted">
									Devuélvelo a la gestión activa sin reactivar códigos anteriores.
								</p>
							</div>
						</button>
					</article>
				{/if}
			</div>
		</section>
	</div>
</main>

<Modal
	id="restore-archived-patient-modal"
	open={restoreModalOpen && data.isAdmin}
	title="Restaurar paciente"
	subtitle={`Confirma la restauración de ${data.patient.firstName} ${data.patient.lastName}.`}
	icon={ArchiveRestore}
	children={restoreModalContent}
	footer={restoreModalFooter}
	onclose={closeRestoreModal}
/>
