<script lang="ts">
	import { resolve } from '$app/paths';
	import Alert from '#lib/components/ui/Alert.svelte';
	import Initials from '#lib/components/ui/Initials.svelte';
	import Archive from '@lucide/svelte/icons/archive';
	import ArchiveRestore from '@lucide/svelte/icons/archive-restore';
	import CircleAlert from '@lucide/svelte/icons/circle-alert';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();

	type ArchivedPatient = PageProps['data']['archivedPatients'][number];
	const archiveDateFormatter = new Intl.DateTimeFormat('es-DO', {
		dateStyle: 'medium',
		timeZone: 'America/Santo_Domingo'
	});

	function patientName(patient: ArchivedPatient) {
		return `${patient.firstName} ${patient.lastName}`.trim();
	}
</script>

<svelte:head>
	<title>Pacientes archivados | Senda</title>
	<meta
		name="description"
		content="Consulta los pacientes archivados y accede a su historial conservado."
	/>
</svelte:head>

<main id="contenido-principal" class="px-5 py-8 sm:px-8 lg:px-0">
	<div class="w-full">
		<div class="mb-8 flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
			<h2 id="pacientes-archivados" class="text-2xl font-bold text-ink">Pacientes archivados</h2>

			<a
				href={resolve('/patients')}
				class="inline-flex min-h-12 items-center justify-center gap-2 self-start rounded-full bg-brand px-5 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none lg:self-auto"
			>
				<ArchiveRestore aria-hidden="true" size={18} strokeWidth={2} />
				Ver pacientes activos
			</a>
		</div>

		{#if data.patientArchived}
			<div class="mb-8 max-w-2xl">
				<Alert
					icon={Archive}
					title="Paciente archivado"
					subtitle="Su información, sus accesos y su historial permanecen conservados."
					color="neutral"
				/>
			</div>
		{/if}

		{#if !data.patientsAvailable}
			<div class="max-w-2xl">
				<Alert
					icon={CircleAlert}
					title="No pudimos consultar los pacientes archivados"
					subtitle="Inténtalo nuevamente en unos minutos."
					color="warning"
				/>
			</div>
		{:else if data.archivedPatients.length > 0}
			<section aria-labelledby="pacientes-archivados">
				<ul class="grid gap-5 md:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4">
					{#each data.archivedPatients as patient (patient.id)}
						<li class="flex h-full flex-col overflow-hidden rounded-2xl bg-white shadow-sm">
							<div class="flex-1 p-6">
								<div class="flex items-start gap-4">
									<Initials text={patientName(patient)} />
									<div class="min-w-0 flex-1">
										<h3 class="text-xl font-bold wrap-break-word text-ink">
											{patientName(patient)}
										</h3>
										<p class="mt-1 text-sm wrap-break-word text-muted">
											{patient.group?.name ?? 'Grupo no disponible'}
										</p>
									</div>
								</div>

								<div class="mt-5 flex min-h-14 items-center gap-3 rounded-2xl bg-surface-muted p-3">
									<div
										class="flex size-10 shrink-0 items-center justify-center rounded-full bg-white text-ink"
									>
										<Archive aria-hidden="true" size={20} strokeWidth={2} />
									</div>
									<div class="min-w-0 flex-1">
										<p class="font-bold text-ink">Paciente archivado</p>
										<p class="mt-1 text-sm leading-5 text-muted">
											{archiveDateFormatter.format(new Date(patient.archivedAt))}
										</p>
									</div>
								</div>
							</div>

							<div class="border-t border-ink/10 p-4">
								<a
									href={resolve('/patients/archived/[id]', { id: patient.id })}
									class="inline-flex min-h-12 w-full items-center justify-center gap-2 rounded-full bg-brand px-5 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/30 focus:outline-none"
								>
									<ArchiveRestore aria-hidden="true" size={18} strokeWidth={2} />
									{patient.accessRole === 'ADMIN' ? 'Administrar archivo' : 'Ver historial'}
								</a>
							</div>
						</li>
					{/each}
				</ul>
			</section>
		{:else}
			<div class="rounded-2xl bg-white p-6 shadow-sm">
				<div
					class="flex size-12 items-center justify-center rounded-full bg-surface-muted text-ink"
				>
					<Archive aria-hidden="true" size={22} strokeWidth={1.75} />
				</div>
				<h3 class="mt-5 text-xl font-bold text-ink">No hay pacientes archivados</h3>
				<p class="mt-2 max-w-2xl leading-7 text-muted">
					Los pacientes que archives aparecerán aquí con su historial conservado.
				</p>
			</div>
		{/if}
	</div>
</main>
