<script lang="ts">
	import { resolve } from '$app/paths';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();
	let patients = $derived(data.patients);
</script>

<svelte:head><title>Pacientes | Senda</title></svelte:head>

<main id="contenido-principal" class="min-h-dvh px-5 py-8 sm:px-8 lg:px-0">
	<div class="w-full max-w-6xl">
		<div class="flex flex-wrap justify-end gap-3" aria-label="Acciones de pacientes">
			<a
				href={resolve('/groups?mode=patient')}
				class="inline-flex min-h-12 items-center justify-center rounded-xl bg-brand px-5 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none"
			>
				Agregar paciente
			</a>
			<a
				href={resolve('/groups?mode=new')}
				class="inline-flex min-h-12 items-center justify-center rounded-xl border border-ink/15 bg-white px-5 font-bold text-ink transition hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none"
			>
				Crear grupo
			</a>
			<a
				href={resolve('/access-code')}
				class="inline-flex min-h-12 items-center justify-center rounded-xl px-3 font-bold text-brand transition hover:bg-white/60 focus:ring-4 focus:ring-focus/30 focus:outline-none"
			>
				Ingresar código
			</a>
		</div>

		{#if data.patientCreated}
			<div
				class="mt-6 max-w-2xl rounded-2xl border border-brand/25 bg-surface-muted p-4 text-sm leading-6 text-ink"
				role="status"
			>
				Paciente registrado correctamente. Ya tienes acceso de administrador.
			</div>
		{/if}

		{#if data.deviceConfigured}
			<div
				class="mt-6 max-w-2xl rounded-2xl border border-brand/25 bg-surface-muted p-4 text-sm leading-6 text-ink"
				role="status"
			>
				Dispositivo configurado correctamente.
			</div>
		{/if}

		{#if data.accessAccepted}
			<div
				class="mt-6 max-w-2xl rounded-2xl border border-brand/25 bg-surface-muted p-4 text-sm leading-6 text-ink"
				role="status"
			>
				Código aceptado. Ya puedes monitorear al paciente autorizado.
			</div>
		{/if}

		{#if data.devicesAvailable && !data.locationsAvailable}
			<div
				class="mt-6 max-w-2xl rounded-2xl border border-amber-700/25 bg-amber-50 p-4 text-sm leading-6 text-amber-950"
				role="status"
			>
				No pudimos consultar las ubicaciones. Los pacientes y dispositivos siguen disponibles.
			</div>
		{/if}

		{#if !data.patientsAvailable}
			<div
				class="mt-6 rounded-2xl border border-amber-700/25 bg-amber-50 p-4 text-sm leading-6 text-amber-950"
				role="status"
			>
				No pudimos consultar tus pacientes. Inténtalo nuevamente en unos minutos.
			</div>
		{:else if !data.devicesAvailable}
			<div
				class="mt-6 rounded-2xl border border-amber-700/25 bg-amber-50 p-4 text-sm leading-6 text-amber-950"
				role="status"
			>
				No pudimos consultar el estado de los dispositivos. Inténtalo nuevamente en unos minutos.
			</div>
		{:else if patients.length > 0}
			<ul class="mt-6 grid gap-5 md:grid-cols-2">
				{#each patients as patient (patient.id)}
					<li class="rounded-3xl border border-white/80 bg-white p-6">
						<h2 class="text-xl font-bold break-words text-ink">
							{patient.firstName}
							{patient.lastName}
						</h2>
						<p class="mt-1 text-sm break-words text-muted">
							{patient.group?.name ?? 'Grupo no disponible'}
						</p>
						<p class="mt-3 text-sm font-semibold text-ink">
							<span class="text-muted">Tu acceso:</span>
							{patient.accessRole === 'ADMIN' ? 'Administrador' : 'Monitor'}
						</p>

						<div class="mt-5 rounded-2xl bg-surface-muted p-4">
							{#if patient.assignment}
								<p class="font-bold text-ink">Dispositivo configurado</p>
								{#if !data.locationsAvailable}
									<p class="mt-1 text-sm leading-6 text-muted">Ubicación no disponible.</p>
								{:else if patient.assignment.latestLocation}
									<p class="mt-1 text-sm leading-6 text-muted">
										{patient.assignment.latestLocation.freshness === 'FRESH'
											? 'Ubicación reciente'
											: 'Ubicación desactualizada'}:
										{patient.assignment.latestLocation.ageLabel}.
									</p>
								{:else}
									<p class="mt-1 text-sm leading-6 text-muted">Aún no hay ubicaciones recibidas.</p>
								{/if}
							{:else}
								<p class="font-bold text-ink">Sin dispositivo configurado</p>
								<p class="mt-1 text-sm leading-6 text-muted">
									{patient.accessRole === 'ADMIN'
										? 'Puedes configurarlo ahora o hacerlo más adelante.'
										: 'Un administrador debe configurar el dispositivo.'}
								</p>
								{#if patient.accessRole === 'ADMIN'}
									<a
										href={resolve('/patients/[id]/device', { id: patient.id })}
										class="mt-3 inline-flex min-h-12 items-center rounded-xl font-bold text-brand focus:ring-4 focus:ring-focus/30 focus:outline-none"
									>
										Configurar ahora
									</a>
								{/if}
							{/if}
						</div>

						<div class="mt-4 flex flex-wrap gap-x-5 gap-y-2">
							<a
								href={resolve('/patients/[id]', { id: patient.id })}
								class="inline-flex min-h-12 items-center rounded-xl font-bold text-brand focus:ring-4 focus:ring-focus/30 focus:outline-none"
							>
								{patient.accessRole === 'ADMIN' ? 'Administrar paciente' : 'Ver paciente'}
							</a>
							{#if patient.assignment}
								<a
									href={resolve('/patients/[id]/map', { id: patient.id })}
									class="inline-flex min-h-12 items-center rounded-xl font-bold text-brand focus:ring-4 focus:ring-focus/30 focus:outline-none"
								>
									Ver mapa
								</a>
							{/if}
							<a
								href={resolve('/patients/[id]/safe-zones', { id: patient.id })}
								class="inline-flex min-h-12 items-center rounded-xl font-bold text-brand focus:ring-4 focus:ring-focus/30 focus:outline-none"
							>
								Geocercas
							</a>
						</div>
					</li>
				{/each}
			</ul>
		{:else}
			<div class="mt-6 rounded-3xl border border-white/80 bg-white p-6">
				<h2 class="text-xl font-bold text-ink">Aún no tienes pacientes</h2>
				<p class="mt-2 max-w-2xl leading-7 text-muted">
					Agrega un paciente o ingresa un código de acceso para comenzar.
				</p>
			</div>
		{/if}
	</div>
</main>
