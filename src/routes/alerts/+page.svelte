<script lang="ts">
	import { invalidate } from '$app/navigation';
	import { resolve } from '$app/paths';
	import AlertEpisodesRealtime, {
		type AlertEpisodeRealtimeRow,
		type AlertEpisodeRealtimeState
	} from '#lib/alerts/AlertEpisodesRealtime.svelte';
	import { presentDateTime } from '#lib/locations/presentation.js';
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

<main id="contenido-principal" class="min-h-dvh px-5 py-8 sm:px-8 lg:px-0">
	<div class="w-full max-w-5xl">
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
			<div
				class="mt-6 rounded-2xl border border-amber-700/25 bg-amber-50 p-4 text-sm leading-6 text-amber-950"
				role="status"
			>
				No pudimos consultar las alertas. Inténtalo nuevamente en unos minutos.
			</div>
		{:else if realtimeState === 'ERROR'}
			<div
				class="mt-6 rounded-2xl border border-amber-700/25 bg-amber-50 p-4 text-sm leading-6 text-amber-950"
				role="status"
			>
				La actualización automática no está disponible. Recarga para obtener el estado más reciente.
			</div>
		{/if}

		{#if activeEpisodes.length > 0}
			<section aria-labelledby="active-alerts-title">
				<h2 id="active-alerts-title" class="text-2xl font-bold text-ink">Alertas activas</h2>
				<ul class="mt-4 grid gap-4">
					{#each activeEpisodes as episode (episode.id)}
						<li class="rounded-3xl border border-amber-700/30 bg-amber-50 p-5 sm:p-6">
							<p class="text-sm font-bold tracking-widest text-amber-950 uppercase">
								Salida confirmada activa
							</p>
							<h3 class="mt-2 text-xl font-bold text-amber-950">{episode.patientName}</h3>
							<p class="mt-2 leading-7 text-amber-950">
								Confirmada el <time datetime={episode.confirmedAt}
									>{presentDateTime(episode.confirmedAt)}</time
								>.
							</p>
							<div class="mt-4 flex flex-wrap gap-3">
								<a
									href={resolve('/patients/[id]/map', { id: episode.patientId })}
									class="inline-flex min-h-12 items-center rounded-xl bg-amber-950 px-4 font-bold text-white focus:ring-4 focus:ring-amber-900/30 focus:outline-none"
								>
									Ver ubicación y detalles
								</a>
								<a
									href={resolve('/patients/[id]', { id: episode.patientId })}
									class="inline-flex min-h-12 items-center rounded-xl px-3 font-bold text-amber-950 underline decoration-2 underline-offset-4 focus:ring-4 focus:ring-amber-900/30 focus:outline-none"
								>
									Ver paciente
								</a>
							</div>
						</li>
					{/each}
				</ul>
			</section>
		{/if}

		<section class="mt-8" aria-labelledby="alert-history-title">
			<h2 id="alert-history-title" class="text-2xl font-bold text-ink">Historial</h2>
			{#if resolvedEpisodes.length > 0}
				<ul class="mt-4 grid gap-3">
					{#each resolvedEpisodes as episode (episode.id)}
						<li class="rounded-2xl border border-white/80 bg-white p-5">
							<div class="flex flex-wrap items-start justify-between gap-3">
								<div>
									<h3 class="text-lg font-bold text-ink">{episode.patientName}</h3>
									<p class="mt-1 text-sm leading-6 text-muted">Episodio resuelto</p>
								</div>
								<time class="text-sm text-muted" datetime={episode.confirmedAt}>
									{presentDateTime(episode.confirmedAt)}
								</time>
							</div>
							<a
								href={resolve('/patients/[id]/map', { id: episode.patientId })}
								class="mt-3 inline-flex min-h-12 items-center rounded-xl font-bold text-brand focus:ring-4 focus:ring-focus/30 focus:outline-none"
							>
								Ver detalles
							</a>
						</li>
					{/each}
				</ul>
			{:else}
				<div class="mt-4 rounded-3xl border border-white/80 bg-white p-6">
					<p class="font-bold text-ink">
						{activeEpisodes.length > 0 ? 'Todavía no hay alertas resueltas' : 'No hay alertas'}
					</p>
					<p class="mt-2 leading-7 text-muted">
						Los episodios aparecerán aquí cuando el sistema confirme una salida.
					</p>
				</div>
			{/if}
		</section>
	</div>
</main>
