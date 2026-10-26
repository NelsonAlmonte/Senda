<script lang="ts">
	import { resolve } from '$app/paths';
	import DashboardAlertEpisodesRealtime, {
		type DashboardAlertEpisodeRealtimeRow,
		type DashboardAlertEpisodeRealtimeState
	} from '#lib/alerts/DashboardAlertEpisodesRealtime.svelte';
	import { presentDateTime } from '#lib/locations/presentation.js';
	import PushNotificationReminder from '#lib/push/PushNotificationReminder.svelte';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();
	let displayName = $derived(data.profile?.full_name || data.user.email || 'Usuario de Senda');
	let patients = $derived(data.patients);
	let alertRealtimeState = $state<'IDLE' | DashboardAlertEpisodeRealtimeState>('IDLE');
	let alertAnnouncement = $state('');

	function handleAlertEpisode(row: DashboardAlertEpisodeRealtimeRow) {
		const patient = patients.find((candidate) => candidate.id === row.patient_id);
		if (!patient) return;

		patients = patients.map((candidate) =>
			candidate.id === row.patient_id
				? {
						...candidate,
						activeAlertEpisode:
							row.status === 'OPEN' ? { id: row.id, confirmedAt: row.confirmed_at } : null
					}
				: candidate
		);

		const patientName = `${patient.firstName} ${patient.lastName}`;
		alertAnnouncement =
			row.status === 'OPEN'
				? `Salida confirmada activa para ${patientName}.`
				: `El episodio de salida de ${patientName} fue resuelto.`;
	}
</script>

<svelte:head><title>Panel | Senda</title></svelte:head>

<main id="contenido-principal" class="min-h-dvh px-5 py-6 sm:px-8 lg:px-12">
	<div class="mx-auto w-full max-w-6xl">
		<header class="flex flex-wrap items-center justify-between gap-4 border-b border-ink/10 pb-5">
			<a
				href={resolve('/dashboard')}
				class="rounded-xl text-xl font-bold text-ink focus:ring-4 focus:ring-focus/30 focus:outline-none"
				>Senda</a
			>
			<nav class="flex flex-wrap items-center gap-3" aria-label="Navegación de cuenta">
				<a
					href={resolve('/settings')}
					class="inline-flex min-h-12 items-center rounded-xl px-4 font-bold text-brand focus:ring-4 focus:ring-focus/30 focus:outline-none"
					>Mi perfil</a
				>
				<form method="POST" action="/auth/logout">
					<button
						type="submit"
						class="min-h-12 cursor-pointer rounded-xl border border-ink/15 bg-white px-4 font-bold text-ink focus:ring-4 focus:ring-focus/30 focus:outline-none"
						>Cerrar sesión</button
					>
				</form>
			</nav>
		</header>

		<section class="py-10 sm:py-14">
			{#if data.alertEpisodesAvailable && patients.length > 0}
				<DashboardAlertEpisodesRealtime
					onAlertEpisode={handleAlertEpisode}
					onStateChange={(state) => (alertRealtimeState = state)}
				/>
				<p class="sr-only" role="status" aria-live="polite" aria-atomic="true">
					{alertAnnouncement}
				</p>
			{/if}

			<p class="text-sm font-bold tracking-[0.14em] text-brand uppercase">Panel protegido</p>
			<h1 class="mt-3 max-w-3xl text-3xl font-bold tracking-tight text-ink sm:text-4xl">
				Hola, {displayName}
			</h1>
			<p class="mt-4 max-w-2xl text-lg leading-8 text-muted">
				Consulta las personas que tienes autorizadas y crea el primer contexto de cuidado cuando lo
				necesites.
			</p>

			<PushNotificationReminder />

			{#if data.patientCreated}
				<div
					class="mt-7 max-w-2xl rounded-2xl border border-brand/25 bg-surface-muted p-4 text-sm leading-6 text-ink"
					role="status"
				>
					Paciente registrado correctamente. Ya tienes acceso de administrador sobre este paciente.
				</div>
			{/if}

			{#if data.deviceConfigured}
				<div
					class="mt-7 max-w-2xl rounded-2xl border border-brand/25 bg-surface-muted p-4 text-sm leading-6 text-ink"
					role="status"
				>
					Dispositivo configurado correctamente. Ya puedes continuar con el panel.
				</div>
			{/if}

			{#if data.accessAccepted}
				<div
					class="mt-7 max-w-2xl rounded-2xl border border-brand/25 bg-surface-muted p-4 text-sm leading-6 text-ink"
					role="status"
				>
					Código aceptado. Ya puedes monitorear al paciente autorizado.
				</div>
			{/if}

			{#if !data.profileAvailable}
				<div
					class="mt-7 max-w-2xl rounded-2xl border border-amber-700/25 bg-amber-50 p-4 text-sm leading-6 text-amber-950"
					role="status"
				>
					El perfil todavía no está disponible. Aplica la migración local al proyecto Supabase de
					desarrollo cuando sea autorizada.
				</div>
			{/if}

			{#if data.devicesAvailable && !data.locationsAvailable}
				<div
					class="mt-7 max-w-2xl rounded-2xl border border-amber-700/25 bg-amber-50 p-4 text-sm leading-6 text-amber-950"
					role="status"
				>
					No pudimos consultar las ubicaciones. Los pacientes y dispositivos siguen disponibles,
					pero su última lectura no puede mostrarse ahora.
				</div>
			{/if}

			{#if !data.alertEpisodesAvailable}
				<div
					class="mt-7 max-w-2xl rounded-2xl border border-amber-700/25 bg-amber-50 p-4 text-sm leading-6 text-amber-950"
					role="status"
				>
					No pudimos consultar los episodios de salida. Las ubicaciones siguen disponibles, pero
					debes abrir el mapa para comprobar su estado.
				</div>
			{:else if alertRealtimeState === 'ERROR'}
				<div
					class="mt-7 max-w-2xl rounded-2xl border border-amber-700/25 bg-amber-50 p-4 text-sm leading-6 text-amber-950"
					role="status"
				>
					La actualización automática de episodios no está disponible. Recarga el panel para obtener
					el estado más reciente.
				</div>
			{/if}

			<div class="mt-9 flex flex-wrap items-end justify-between gap-4">
				<div>
					<h2 class="text-2xl font-bold text-ink">Pacientes autorizados</h2>
					<p class="mt-2 leading-7 text-muted">Solo aparecen pacientes con un acceso activo.</p>
				</div>
				<div class="flex flex-wrap gap-3" aria-label="Acciones de pacientes y grupos">
					<a
						href={resolve('/groups?mode=patient')}
						class="inline-flex min-h-12 items-center justify-center rounded-xl bg-brand px-5 font-bold text-white shadow-sm transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none"
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
			</div>

			{#if !data.patientsAvailable}
				<div
					class="mt-6 rounded-2xl border border-amber-700/25 bg-amber-50 p-4 text-sm leading-6 text-amber-950"
					role="status"
				>
					Los datos de pacientes aún no están disponibles. Aplica la migración de esta historia al
					proyecto Supabase de desarrollo.
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
						<li
							class={[
								'rounded-3xl border bg-white p-6 shadow-lg shadow-brand/5',
								patient.activeAlertEpisode ? 'border-amber-700/30' : 'border-white/80'
							]}
						>
							<div class="min-w-0">
								<h3 class="text-xl font-bold break-words text-ink">
									{patient.firstName}
									{patient.lastName}
								</h3>
								<p class="mt-1 text-sm break-words text-muted">
									{patient.group?.name ?? 'Grupo no disponible'}
								</p>
								<p class="mt-3 text-sm font-semibold text-ink">
									<span class="text-muted">Tu acceso:</span>
									{patient.accessRole === 'ADMIN' ? 'Administrador' : 'Monitor'}
								</p>
							</div>
							{#if patient.activeAlertEpisode}
								<section
									class="mt-5 rounded-2xl border border-amber-700/25 bg-amber-50 p-4"
									aria-labelledby={`active-alert-${patient.id}`}
								>
									<p class="text-xs font-bold tracking-[0.12em] text-amber-950 uppercase">
										Episodio de salida
									</p>
									<h4 id={`active-alert-${patient.id}`} class="mt-1 font-bold text-amber-950">
										Salida confirmada activa
									</h4>
									<p class="mt-1 text-sm leading-6 text-amber-950">
										Confirmada el
										<time datetime={patient.activeAlertEpisode.confirmedAt}>
											{presentDateTime(patient.activeAlertEpisode.confirmedAt)}
										</time>.
									</p>
									{#if patient.assignment}
										<a
											href={resolve('/patients/[id]/map', { id: patient.id })}
											class="mt-3 inline-flex min-h-12 items-center rounded-xl font-bold text-amber-950 underline decoration-2 underline-offset-4 focus:ring-4 focus:ring-focus/30 focus:outline-none"
										>
											Ver ubicación y detalles
										</a>
									{/if}
								</section>
							{/if}
							{#if patient.assignment}
								<div class="mt-5 rounded-2xl border border-brand/15 bg-surface-muted p-4">
									<p class="font-bold text-ink">Dispositivo configurado</p>
									<p class="mt-1 font-mono text-sm break-all text-ink">
										{patient.assignment.device.serialNumber}
									</p>

									{#if !data.locationsAvailable}
										<p class="mt-3 text-sm leading-6 text-muted">
											La última ubicación no está disponible temporalmente.
										</p>
									{:else if patient.assignment.latestLocation}
										{#if patient.assignment.latestLocation.freshness === 'FRESH'}
											<div class="mt-4 rounded-xl border border-brand/20 bg-white/70 p-3">
												<p class="font-bold text-ink">Ubicación reciente</p>
												<p class="mt-1 text-sm leading-6 text-muted">
													Última lectura {patient.assignment.latestLocation.ageLabel}.
												</p>
											</div>
										{:else}
											<div class="mt-4 rounded-xl border border-amber-700/25 bg-amber-50 p-3">
												<p class="font-bold text-amber-950">Ubicación desactualizada</p>
												<p class="mt-1 text-sm leading-6 text-amber-950">
													No se ha recibido una posición reciente. La última lectura fue
													{patient.assignment.latestLocation.ageLabel}.
												</p>
											</div>
										{/if}

										<dl class="mt-4 grid gap-3 text-sm sm:grid-cols-2">
											<div>
												<dt class="font-semibold text-muted">Coordenadas</dt>
												<dd class="mt-1 font-mono text-ink">
													{patient.assignment.latestLocation.latitude.toFixed(5)},
													{patient.assignment.latestLocation.longitude.toFixed(5)}
												</dd>
											</div>
											<div>
												<dt class="font-semibold text-muted">Registrada</dt>
												<dd class="mt-1 text-ink">
													<time datetime={patient.assignment.latestLocation.recordedAt}>
														{patient.assignment.latestLocation.recordedAtLabel}
													</time>
												</dd>
											</div>
											{#if patient.assignment.latestLocation.accuracyM !== null}
												<div>
													<dt class="font-semibold text-muted">Precisión informada</dt>
													<dd class="mt-1 text-ink">
														{patient.assignment.latestLocation.accuracyM.toFixed(1)} m
													</dd>
												</div>
											{/if}
										</dl>
									{:else}
										<p class="mt-3 text-sm leading-6 text-muted">
											Aún no hay ubicaciones recibidas para este dispositivo.
										</p>
									{/if}
								</div>
							{:else}
								<div class="mt-5 rounded-2xl bg-canvas p-4">
									<p class="font-bold text-ink">Sin dispositivo configurado</p>
									<p class="mt-1 text-sm leading-6 text-muted">
										{patient.accessRole === 'ADMIN'
											? 'Puedes asignar un serial simulado ahora o hacerlo más adelante.'
											: 'Un administrador del paciente debe configurar el dispositivo.'}
									</p>
									{#if patient.accessRole === 'ADMIN'}
										<a
											href={resolve('/patients/[id]/device', { id: patient.id })}
											class="mt-3 inline-flex min-h-12 items-center rounded-xl font-bold text-brand focus:ring-4 focus:ring-focus/30 focus:outline-none"
										>
											Configurar ahora
										</a>
									{/if}
								</div>
							{/if}
							<div class="mt-4 flex flex-wrap gap-x-5 gap-y-2">
								{#if patient.accessRole === 'ADMIN'}
									<a
										href={resolve('/patients/[id]/access', { id: patient.id })}
										class="inline-flex min-h-12 items-center rounded-xl font-bold text-brand focus:ring-4 focus:ring-focus/30 focus:outline-none"
									>
										Compartir acceso
									</a>
								{/if}
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
									Configurar geocercas
								</a>
							</div>
						</li>
					{/each}
				</ul>
			{:else}
				<div class="mt-6 rounded-3xl border border-white/80 bg-white p-6 shadow-lg shadow-brand/5">
					<h3 class="text-xl font-bold text-ink">Aún no tienes pacientes</h3>
					<p class="mt-2 max-w-2xl leading-7 text-muted">
						Crea un grupo familiar o de cuidado y registra los datos mínimos de la primera persona.
					</p>
				</div>
			{/if}

			<article
				class="mt-8 rounded-3xl border border-white/80 bg-white p-6 shadow-lg shadow-brand/5"
			>
				<h2 class="text-lg font-bold text-ink">Cuenta activa</h2>
				<p class="mt-2 leading-7 break-words text-muted">
					{data.user.email ?? 'Correo no disponible'}
				</p>
			</article>
		</section>
	</div>
</main>
