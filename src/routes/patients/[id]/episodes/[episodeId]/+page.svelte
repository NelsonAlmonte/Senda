<script lang="ts">
	import { invalidate } from '$app/navigation';
	import { CircleAlert, CircleCheckBig, Clock3, MapPinned, Route, Siren } from '@lucide/svelte';
	import EpisodeRouteMap from '#lib/components/maps/EpisodeRouteMap.svelte';
	import PatientLocationRealtime from '#lib/components/locations/PatientLocationRealtime.svelte';
	import Alert from '#lib/components/ui/Alert.svelte';
	import Heading from '#lib/components/ui/Heading.svelte';
	import InfoItem from '#lib/components/ui/InfoItem.svelte';
	import type { LocationRealtimeState } from '#lib/types/locations.js';
	import { presentDateTime } from '#lib/utils/location-presentation.js';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();
	let realtimeState = $state<'IDLE' | LocationRealtimeState>('IDLE');
	let refreshPending = false;
	let patientName = $derived(`${data.patient.firstName} ${data.patient.lastName}`.trim());
	let routeVersion = $derived(
		[
			data.episode.status,
			data.episode.updatedAt,
			data.displayedPointCount,
			...data.routeSegments.map((segment) => segment.at(-1)?.id ?? 0)
		].join(':')
	);
	let latestPoint = $derived(data.routeSegments.at(-1)?.at(-1) ?? null);

	function refreshEpisodeRoute() {
		if (refreshPending) return;
		refreshPending = true;
		void invalidate('senda:episode-route').finally(() => {
			refreshPending = false;
		});
	}
</script>

<svelte:head>
	<title>Recorrido del episodio de {patientName} | Senda</title>
	<meta
		name="description"
		content="Recorrido de ubicaciones registrado durante un episodio de salida en Senda."
	/>
</svelte:head>

<main id="contenido-principal" class="px-5 py-8 sm:px-8 lg:px-0">
	<div class="w-full">
		<h2 class="mb-8 text-2xl font-bold text-ink">Recorrido del episodio</h2>

		{#if data.episode.status === 'OPEN'}
			<PatientLocationRealtime
				assignmentId={data.episode.deviceAssignmentId}
				patientId={data.patient.id}
				onLocation={refreshEpisodeRoute}
				onAlertEpisode={(episode) => {
					if (episode.id === data.episode.id) refreshEpisodeRoute();
				}}
				onStateChange={(state) => (realtimeState = state)}
			/>
		{/if}

		{#if realtimeState === 'ERROR'}
			<div class="mb-6 max-w-2xl">
				<Alert
					icon={CircleAlert}
					title="Actualización automática no disponible"
					subtitle="Recarga la página para consultar las ubicaciones más recientes del episodio."
					color="warning"
				/>
			</div>
		{/if}

		<div class="grid gap-6 xl:grid-cols-12 xl:items-start">
			<div class="xl:col-span-8">
				{#if data.routeSegments.length > 0}
					{#key routeVersion}
						<EpisodeRouteMap
							{patientName}
							segments={data.routeSegments}
							firstOutsideLocationId={data.episode.firstOutsideLocationId}
							confirmedByLocationId={data.episode.confirmedByLocationId}
							resolvedByLocationId={data.episode.resolvedByLocationId}
							status={data.episode.status}
						/>
					{/key}
				{:else}
					<Alert
						icon={CircleAlert}
						title="No hay ubicaciones disponibles"
						subtitle="El episodio existe, pero no pudimos representar sus lecturas en el mapa."
						color="warning"
					/>
				{/if}
			</div>

			<section
				class="rounded-2xl bg-white p-6 shadow-sm xl:col-span-4"
				aria-label="Hitos del episodio"
			>
				<Heading
					icon={Route}
					title="Hitos del episodio"
					subtitle="Las lecturas que iniciaron, confirmaron y cerraron esta salida."
				/>

				<div class="mt-6 grid gap-3">
					<InfoItem
						icon={Clock3}
						title="Primera lectura fuera"
						info={presentDateTime(data.episode.startedAt)}
						tone="warning"
					/>
					<InfoItem
						icon={Siren}
						title="Salida confirmada"
						info={presentDateTime(data.episode.confirmedAt)}
						tone="danger"
					/>
					{#if data.episode.status === 'RESOLVED' && data.episode.resolvedAt}
						<InfoItem
							icon={CircleCheckBig}
							title="Regreso confirmado"
							info={presentDateTime(data.episode.resolvedAt)}
							tone="positive"
						/>
					{:else}
						<InfoItem
							icon={MapPinned}
							title="Episodio activo"
							info={latestPoint
								? `Última lectura: ${presentDateTime(latestPoint.recordedAt)}`
								: 'Esperando una nueva lectura.'}
							tone="danger"
						/>
					{/if}
				</div>
			</section>
		</div>

		{#if data.routeTruncated}
			<div class="mt-6 max-w-3xl">
				<Alert
					icon={CircleAlert}
					title="Recorrido extenso"
					subtitle="El mapa muestra las 250 primeras y las 250 últimas lecturas en dos tramos separados. No se dibuja una línea sobre las ubicaciones omitidas."
					color="warning"
				/>
			</div>
		{/if}
	</div>
</main>
