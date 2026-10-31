<script lang="ts">
	import { invalidate } from '$app/navigation';
	import { resolve } from '$app/paths';
	import { CircleAlert, CircleCheckBig, Clock3, MapPinned, UserRound } from '@lucide/svelte';
	import AlertEpisodesRealtime, {
		type AlertEpisodeRealtimeRow,
		type AlertEpisodeRealtimeState
	} from '#lib/alerts/AlertEpisodesRealtime.svelte';
	import AlertEpisodeCard from '#lib/components/alerts/AlertEpisodeCard.svelte';
	import Alert from '#lib/components/ui/Alert.svelte';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();
	let realtimeState = $state<'IDLE' | AlertEpisodeRealtimeState>('IDLE');
	let announcement = $state('');
	let episodes = $derived(data.episodes);
	let activeEpisodes = $derived(episodes.filter((episode) => episode.status === 'OPEN'));
	let resolvedEpisodes = $derived(episodes.filter((episode) => episode.status === 'RESOLVED'));

	function handleAlertEpisode(row: AlertEpisodeRealtimeRow) {
		const episode = episodes.find((candidate) => candidate.patientId === row.patient_id);
		announcement = episode
			? row.status === 'OPEN'
				? `Nueva alerta activa para ${episode.patientName}.`
				: `La alerta de ${episode.patientName} fue resuelta.`
			: 'La lista de alertas se actualizó.';
		void invalidate('senda:alert-episodes');
		void invalidate('senda:active-alert-indicator');
	}
</script>

<svelte:head><title>Alertas | Senda</title></svelte:head>

<main id="contenido-principal" class="px-5 py-8 sm:px-8 lg:px-0">
	<div class="w-full">
		{#if data.episodesAvailable}
			<AlertEpisodesRealtime
				onAlertEpisode={handleAlertEpisode}
				onStateChange={(state) => (realtimeState = state)}
			/>
			<p class="sr-only" role="status" aria-live="polite" aria-atomic="true">
				{announcement}
			</p>
		{/if}

		{#if !data.episodesAvailable}
			<div class="mb-8 max-w-2xl">
				<Alert
					icon={CircleAlert}
					title="No pudimos consultar las alertas"
					subtitle="Inténtalo nuevamente en unos minutos."
					color="warning"
				/>
			</div>
		{:else if realtimeState === 'ERROR'}
			<div class="mb-8 max-w-2xl">
				<Alert
					icon={CircleAlert}
					title="Actualización automática no disponible"
					subtitle="Recarga la página para obtener el estado más reciente."
					color="warning"
				/>
			</div>
		{/if}

		<section aria-labelledby="active-alerts-title">
			<div>
				<h2 id="active-alerts-title" class="text-2xl font-bold text-ink">Alertas activas</h2>
			</div>

			{#if activeEpisodes.length > 0}
				<ul class="mt-6 grid gap-5 xl:grid-cols-2">
					{#each activeEpisodes as episode (episode.id)}
						<li class="h-full">
							<AlertEpisodeCard
								status={episode.status}
								confirmedAt={episode.confirmedAt}
								resolvedAt={episode.resolvedAt}
								patientName={episode.patientName}
							>
								{#snippet actions()}
									<div class="flex flex-col gap-2 sm:flex-row">
										<a
											href={resolve('/patients/[id]/map', { id: episode.patientId })}
											class="inline-flex min-h-12 flex-1 items-center justify-center gap-2 rounded-full bg-brand px-5 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/30 focus:outline-none"
										>
											<MapPinned aria-hidden="true" size={18} strokeWidth={2} />
											Revisar ubicación
										</a>
										<a
											href={resolve('/patients/[id]', { id: episode.patientId })}
											class="inline-flex min-h-12 flex-1 items-center justify-center gap-2 rounded-full px-5 font-bold text-brand transition hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none"
										>
											<UserRound aria-hidden="true" size={18} strokeWidth={2} />
											Ver paciente
										</a>
									</div>
								{/snippet}
							</AlertEpisodeCard>
						</li>
					{/each}
				</ul>
			{:else if data.episodesAvailable}
				<div class="mt-6 max-w-2xl rounded-2xl bg-white p-6 shadow-sm">
					<div class="flex items-start gap-4">
						<div
							class="flex size-12 shrink-0 items-center justify-center rounded-full bg-surface-muted text-brand"
						>
							<CircleCheckBig aria-hidden="true" size={22} strokeWidth={2} />
						</div>
						<div class="min-w-0">
							<h3 class="text-xl font-bold text-ink">No hay alertas activas</h3>
							<p class="mt-2 leading-7 text-muted">
								No existen episodios abiertos en este momento.
							</p>
						</div>
					</div>
				</div>
			{/if}
		</section>

		<section class="mt-12" aria-labelledby="alert-history-title">
			<div>
				<h2 id="alert-history-title" class="text-2xl font-bold text-ink">Historial</h2>
			</div>

			{#if resolvedEpisodes.length > 0}
				<ul class="mt-6 grid gap-5 md:grid-cols-2 xl:grid-cols-3">
					{#each resolvedEpisodes as episode (episode.id)}
						<li class="h-full">
							<AlertEpisodeCard
								status={episode.status}
								confirmedAt={episode.confirmedAt}
								resolvedAt={episode.resolvedAt}
								patientName={episode.patientName}
							>
								{#snippet actions()}
									<a
										href={resolve('/patients/[id]/map', { id: episode.patientId })}
										class="inline-flex min-h-12 w-full items-center justify-center gap-2 rounded-full px-5 font-bold text-brand transition hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none"
									>
										<MapPinned aria-hidden="true" size={18} strokeWidth={2} />
										Ver mapa del paciente
									</a>
								{/snippet}
							</AlertEpisodeCard>
						</li>
					{/each}
				</ul>
			{:else if data.episodesAvailable}
				<div class="mt-6 max-w-2xl">
					<Alert
						icon={Clock3}
						title={activeEpisodes.length > 0
							? 'Todavía no hay alertas resueltas'
							: 'Aún no hay historial'}
						subtitle="Los episodios aparecerán aquí cuando el sistema confirme una salida y su posterior reingreso."
					/>
				</div>
			{/if}
		</section>
	</div>
</main>
