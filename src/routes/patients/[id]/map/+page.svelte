<script lang="ts">
	import { resolve } from '$app/paths';
	import PatientLocationMap from '#lib/maps/PatientLocationMap.svelte';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();
	let patientName = $derived(`${data.patient.firstName} ${data.patient.lastName}`);
</script>

<svelte:head>
	<title>Mapa de {patientName} | Senda</title>
	<meta
		name="description"
		content={`Consulta la última ubicación registrada de ${patientName} en Senda.`}
	/>
</svelte:head>

<main id="contenido-principal" class="min-h-dvh px-5 py-6 sm:px-8 lg:px-12">
	<div class="mx-auto w-full max-w-6xl">
		<header class="flex flex-wrap items-center justify-between gap-4 border-b border-ink/10 pb-5">
			<a
				href={resolve('/dashboard')}
				class="inline-flex min-h-12 items-center rounded-xl font-bold text-brand focus:ring-4 focus:ring-focus/30 focus:outline-none"
			>
				<span aria-hidden="true">←</span><span class="ml-2">Volver al panel</span>
			</a>
			<p class="text-sm font-semibold text-muted">
				Tu acceso: {data.patient.accessRole === 'ADMIN' ? 'Administrador' : 'Monitor'}
			</p>
		</header>

		<section class="py-8 sm:py-12">
			<p class="text-sm font-bold tracking-[0.14em] text-brand uppercase">Última ubicación</p>
			<h1 class="mt-2 text-3xl font-bold tracking-tight text-ink sm:text-4xl">
				Mapa de {patientName}
			</h1>
			<p class="mt-3 max-w-2xl leading-7 text-muted">
				{data.patient.groupName ?? 'Grupo no disponible'} · Esta pantalla muestra la última posición registrada,
				no seguimiento en vivo.
			</p>

			{#if !data.assignment}
				<div class="mt-8 rounded-3xl border border-white/80 bg-white p-6 shadow-lg shadow-brand/5">
					<h2 class="text-xl font-bold text-ink">Sin dispositivo configurado</h2>
					<p class="mt-2 max-w-2xl leading-7 text-muted">
						Todavía no existe una asignación activa que pueda enviar ubicaciones para este paciente.
					</p>
					{#if data.patient.accessRole === 'ADMIN'}
						<a
							href={resolve('/patients/[id]/device', { id: data.patient.id })}
							class="mt-5 inline-flex min-h-12 items-center justify-center rounded-xl bg-brand px-5 font-bold text-white shadow-sm transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none"
						>
							Configurar dispositivo
						</a>
					{/if}
				</div>
			{:else if !data.locationsAvailable}
				<div
					class="mt-8 rounded-3xl border border-amber-700/25 bg-amber-50 p-6 text-amber-950"
					role="alert"
				>
					<h2 class="text-xl font-bold">No pudimos consultar la ubicación</h2>
					<p class="mt-2 max-w-2xl leading-7">
						El paciente y su dispositivo siguen disponibles. Inténtalo nuevamente en unos minutos.
					</p>
					<a
						href={resolve('/patients/[id]/map', { id: data.patient.id })}
						class="mt-5 inline-flex min-h-12 items-center justify-center rounded-xl bg-amber-950 px-5 font-bold text-white focus:ring-4 focus:ring-amber-900/30 focus:outline-none"
					>
						Reintentar
					</a>
				</div>
			{:else if !data.latestLocation}
				<div class="mt-8 rounded-3xl border border-white/80 bg-white p-6 shadow-lg shadow-brand/5">
					<h2 class="text-xl font-bold text-ink">Aún no hay ubicaciones</h2>
					<p class="mt-2 max-w-2xl leading-7 text-muted">
						El dispositivo {data.assignment.device.serialNumber} está configurado, pero todavía no ha
						enviado una posición.
					</p>
				</div>
			{:else}
				<div class="mt-8 grid items-start gap-6 lg:grid-cols-[minmax(0,1fr)_20rem]">
					<PatientLocationMap
						latitude={data.latestLocation.latitude}
						longitude={data.latestLocation.longitude}
						accuracyM={data.latestLocation.accuracyM}
						{patientName}
					/>

					<aside class="rounded-3xl border border-white/80 bg-white p-6 shadow-lg shadow-brand/5">
						{#if data.latestLocation.freshness === 'FRESH'}
							<div class="rounded-2xl border border-brand/20 bg-surface-muted p-4">
								<p class="font-bold text-ink">Ubicación reciente</p>
								<p class="mt-1 text-sm leading-6 text-muted">
									Última lectura {data.latestLocation.ageLabel}.
								</p>
							</div>
						{:else}
							<div class="rounded-2xl border border-amber-700/25 bg-amber-50 p-4">
								<p class="font-bold text-amber-950">Ubicación desactualizada</p>
								<p class="mt-1 text-sm leading-6 text-amber-950">
									La última lectura fue {data.latestLocation.ageLabel}. No representa una posición
									en vivo.
								</p>
							</div>
						{/if}

						<dl class="mt-6 space-y-5 text-sm">
							<div>
								<dt class="font-semibold text-muted">Coordenadas</dt>
								<dd class="mt-1 font-mono text-ink">
									{data.latestLocation.latitude.toFixed(5)},
									{data.latestLocation.longitude.toFixed(5)}
								</dd>
							</div>
							<div>
								<dt class="font-semibold text-muted">Registrada</dt>
								<dd class="mt-1 leading-6 text-ink">
									<time datetime={data.latestLocation.recordedAt}>
										{data.latestLocation.recordedAtLabel}
									</time>
								</dd>
							</div>
							<div>
								<dt class="font-semibold text-muted">Dispositivo</dt>
								<dd class="mt-1 font-mono break-all text-ink">
									{data.assignment.device.serialNumber}
								</dd>
							</div>
							{#if data.latestLocation.accuracyM !== null}
								<div>
									<dt class="font-semibold text-muted">Precisión informada</dt>
									<dd class="mt-1 text-ink">
										{data.latestLocation.accuracyM.toFixed(1)} m
									</dd>
								</div>
							{/if}
						</dl>

						{#if data.latestLocation.accuracyM !== null && data.latestLocation.accuracyM > 0}
							<p class="mt-6 border-t border-ink/10 pt-5 text-sm leading-6 text-muted">
								El círculo azul representa la precisión GPS informada. No es una zona segura.
							</p>
						{/if}
					</aside>
				</div>
			{/if}
		</section>
	</div>
</main>
