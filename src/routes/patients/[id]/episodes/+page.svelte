<script lang="ts">
	import { resolve } from '$app/paths';
	import {
		ChevronLeft,
		ChevronRight,
		CircleAlert,
		CircleCheckBig,
		Clock3,
		MapPinned
	} from '@lucide/svelte';
	import AlertEpisodeCard from '#lib/components/alerts/AlertEpisodeCard.svelte';
	import Alert from '#lib/components/ui/Alert.svelte';
	import type { PageProps } from './$types';

	type PatientEpisodesRoute = '/patients/[id]/episodes' | `/patients/[id]/episodes?page=${number}`;

	let { data }: PageProps = $props();

	function pageRoute(page: number): PatientEpisodesRoute {
		return page === 1 ? '/patients/[id]/episodes' : `/patients/[id]/episodes?page=${page}`;
	}
</script>

<svelte:head>
	<title>Episodios de {data.patient.firstName} {data.patient.lastName} | Senda</title>
	<meta
		name="description"
		content="Historial de salidas confirmadas y resueltas del paciente en Senda."
	/>
</svelte:head>

{#snippet openEpisodeActions()}
	<a
		href={resolve('/patients/[id]/map', { id: data.patient.id })}
		class="inline-flex min-h-12 w-full items-center justify-center gap-2 rounded-full bg-brand px-5 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/30 focus:outline-none"
	>
		<MapPinned aria-hidden="true" size={18} strokeWidth={2} />
		Revisar ubicación actual
	</a>
{/snippet}

<main id="contenido-principal" class="px-5 py-8 sm:px-8 lg:px-0">
	<div class="w-full">
		<section aria-labelledby="active-alert-title">
			<h2 id="active-alert-title" class="text-2xl font-bold text-ink">Alerta activa</h2>

			{#if !data.activeEpisodeAvailable}
				<div class="mt-6 max-w-2xl">
					<Alert
						icon={CircleAlert}
						title="No pudimos consultar la alerta activa"
						subtitle="Inténtalo nuevamente en unos minutos."
						color="warning"
					/>
				</div>
			{:else if data.activeEpisode}
				<ul class="mt-6 grid gap-5 xl:grid-cols-2">
					<li class="h-full">
						<AlertEpisodeCard
							status={data.activeEpisode.status}
							confirmedAt={data.activeEpisode.confirmedAt}
							resolvedAt={data.activeEpisode.resolvedAt}
							actions={openEpisodeActions}
						/>
					</li>
				</ul>
			{:else}
				<div class="mt-6 max-w-2xl">
					<Alert
						icon={CircleCheckBig}
						title="No hay una alerta activa"
						subtitle="No existe un episodio abierto para este paciente en este momento."
						color="positive"
					/>
				</div>
			{/if}
		</section>

		<section aria-labelledby="episode-history-title" class="mt-12">
			<div>
				<h2 id="episode-history-title" class="text-2xl font-bold text-ink">Historial</h2>
			</div>

			{#if !data.historyAvailable}
				<div class="mt-6 max-w-2xl">
					<Alert
						icon={CircleAlert}
						title="No pudimos consultar el historial"
						subtitle="Inténtalo nuevamente en unos minutos."
						color="warning"
					/>
				</div>
			{:else if data.resolvedEpisodes.length === 0}
				<div class="mt-6 max-w-2xl">
					<Alert
						icon={Clock3}
						title="Aún no hay episodios finalizados"
						subtitle="El historial aparecerá aquí cuando una salida confirmada se resuelva."
					/>
				</div>
			{:else}
				<ul class="mt-6 grid gap-5 md:grid-cols-2 xl:grid-cols-3">
					{#each data.resolvedEpisodes as episode (episode.id)}
						<li class="h-full">
							<AlertEpisodeCard
								status={episode.status}
								confirmedAt={episode.confirmedAt}
								resolvedAt={episode.resolvedAt}
							/>
						</li>
					{/each}
				</ul>

				{#if data.pagination.totalPages > 1}
					<nav
						aria-label="Paginación del historial de episodios"
						class="mt-8 flex flex-col items-center justify-between gap-4 rounded-2xl bg-white p-4 shadow-sm sm:flex-row"
					>
						{#if data.pagination.hasPrevious}
							<a
								href={resolve(pageRoute(data.pagination.page - 1), { id: data.patient.id })}
								rel="prev"
								class="inline-flex min-h-12 w-full items-center justify-center gap-2 rounded-full px-5 font-bold text-brand transition hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none sm:w-auto"
							>
								<ChevronLeft aria-hidden="true" size={19} strokeWidth={2} />
								Anterior
							</a>
						{:else}
							<span
								aria-disabled="true"
								class="inline-flex min-h-12 w-full items-center justify-center gap-2 rounded-full px-5 font-bold text-muted opacity-50 sm:w-auto"
							>
								<ChevronLeft aria-hidden="true" size={19} strokeWidth={2} />
								Anterior
							</span>
						{/if}

						<p class="text-sm font-semibold text-muted">
							Página {data.pagination.page} de {data.pagination.totalPages}
						</p>

						{#if data.pagination.hasNext}
							<a
								href={resolve(pageRoute(data.pagination.page + 1), { id: data.patient.id })}
								rel="next"
								class="inline-flex min-h-12 w-full items-center justify-center gap-2 rounded-full px-5 font-bold text-brand transition hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none sm:w-auto"
							>
								Siguiente
								<ChevronRight aria-hidden="true" size={19} strokeWidth={2} />
							</a>
						{:else}
							<span
								aria-disabled="true"
								class="inline-flex min-h-12 w-full items-center justify-center gap-2 rounded-full px-5 font-bold text-muted opacity-50 sm:w-auto"
							>
								Siguiente
								<ChevronRight aria-hidden="true" size={19} strokeWidth={2} />
							</span>
						{/if}
					</nav>
				{/if}
			{/if}
		</section>
	</div>
</main>
