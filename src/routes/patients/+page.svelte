<script lang="ts">
	import { resolve } from '$app/paths';
	import Initials from '#lib/components/ui/Initials.svelte';
	import ArrowUpRight from '@lucide/svelte/icons/arrow-up-right';
	import BellOff from '@lucide/svelte/icons/bell-off';
	import BellRing from '@lucide/svelte/icons/bell-ring';
	import CircleHelp from '@lucide/svelte/icons/circle-help';
	import KeyRound from '@lucide/svelte/icons/key-round';
	import MapPinned from '@lucide/svelte/icons/map-pinned';
	import ShieldCheck from '@lucide/svelte/icons/shield-check';
	import Smartphone from '@lucide/svelte/icons/smartphone';
	import UserPlus from '@lucide/svelte/icons/user-plus';
	import UsersRound from '@lucide/svelte/icons/users-round';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();
	let patients = $derived(data.patients);

	type Patient = PageProps['data']['patients'][number];

	function patientName(patient: Patient) {
		return `${patient.firstName} ${patient.lastName}`.trim();
	}
</script>

<svelte:head><title>Pacientes | Senda</title></svelte:head>

<main id="contenido-principal" class="px-5 py-8 sm:px-8 lg:px-0">
	<div class="w-full max-w-6xl">
		<nav class="mb-8 flex flex-wrap gap-3" aria-label="Acciones de pacientes">
			<a
				href={resolve('/groups?mode=patient')}
				class="inline-flex min-h-12 items-center justify-center gap-2 rounded-full bg-ink px-5 font-bold text-white transition hover:bg-ink/90 focus:ring-4 focus:ring-focus/35 focus:outline-none"
			>
				<UserPlus aria-hidden="true" size={18} strokeWidth={2} />
				Agregar paciente
			</a>
			<a
				href={resolve('/groups?mode=new')}
				class="inline-flex min-h-12 items-center justify-center gap-2 rounded-full border border-ink/15 bg-white px-5 font-bold text-ink transition hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none"
			>
				<UsersRound aria-hidden="true" size={18} strokeWidth={2} />
				Crear grupo
			</a>
			<a
				href={resolve('/access-code')}
				class="inline-flex min-h-12 items-center justify-center gap-2 rounded-full px-4 font-bold text-brand transition hover:bg-white/60 focus:ring-4 focus:ring-focus/30 focus:outline-none"
			>
				<KeyRound aria-hidden="true" size={18} strokeWidth={2} />
				Ingresar código
			</a>
		</nav>

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
			<section class="mt-6" aria-labelledby="personas-cuidado">
				<div class="max-w-2xl">
					<h2 id="personas-cuidado" class="mb-8 text-2xl font-bold text-ink">
						Personas a tu cuidado
					</h2>
				</div>

				<ul class="grid gap-5 md:grid-cols-2 xl:grid-cols-3">
					{#each patients as patient (patient.id)}
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

								<div class="mt-6 flex items-center gap-3">
									{#if !data.alertsAvailable}
										<div
											class="flex size-10 shrink-0 items-center justify-center rounded-full bg-amber-50 text-amber-950"
										>
											<CircleHelp aria-hidden="true" size={20} strokeWidth={2} />
										</div>
										<div>
											<p class="font-bold text-ink">Estado de alertas no disponible</p>
											<p class="mt-1 text-sm leading-5 text-muted">Inténtalo nuevamente.</p>
										</div>
									{:else if patient.hasActiveAlert}
										<div
											class="flex size-10 shrink-0 items-center justify-center rounded-full bg-amber-100 text-amber-950"
										>
											<BellRing aria-hidden="true" size={20} strokeWidth={2} />
										</div>
										<div>
											<p class="font-bold text-amber-950">Alerta activa</p>
											<p class="mt-1 text-sm leading-5 text-amber-950">Salida confirmada.</p>
										</div>
									{:else if !patient.assignment}
										<div
											class="flex size-10 shrink-0 items-center justify-center rounded-full bg-surface-muted text-ink"
										>
											<Smartphone aria-hidden="true" size={20} strokeWidth={2} />
										</div>
										<div>
											<p class="font-bold text-ink">Sin dispositivo configurado</p>
											<p class="mt-1 text-sm leading-5 text-muted">El monitoreo no está activo.</p>
										</div>
									{:else}
										<div
											class="flex size-10 shrink-0 items-center justify-center rounded-full bg-surface-muted text-brand"
										>
											<BellOff aria-hidden="true" size={20} strokeWidth={2} />
										</div>
										<div>
											<p class="font-bold text-ink">Sin alertas activas</p>
											<p class="mt-1 text-sm leading-5 text-muted">No hay episodios abiertos.</p>
										</div>
									{/if}
								</div>
							</div>

							<div class="border-t border-ink/10 p-4">
								<a
									href={resolve('/patients/[id]', { id: patient.id })}
									class="inline-flex min-h-12 w-full items-center justify-center gap-2 rounded-full bg-ink px-5 font-bold text-white transition hover:bg-ink/90 focus:ring-4 focus:ring-focus/30 focus:outline-none"
								>
									{patient.accessRole === 'ADMIN' ? 'Administrar paciente' : 'Ver paciente'}
									<ArrowUpRight aria-hidden="true" size={18} strokeWidth={2} />
								</a>
								<div class="mt-2 flex flex-wrap justify-center gap-2">
									{#if patient.assignment}
										<a
											href={resolve('/patients/[id]/map', { id: patient.id })}
											class="inline-flex min-h-12 flex-1 items-center justify-center gap-2 rounded-full px-4 font-bold text-brand transition hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none"
										>
											<MapPinned aria-hidden="true" size={18} strokeWidth={2} />
											Ver mapa
										</a>
									{:else if patient.accessRole === 'ADMIN'}
										<a
											href={resolve('/patients/[id]/device', { id: patient.id })}
											class="inline-flex min-h-12 flex-1 items-center justify-center gap-2 rounded-full px-4 font-bold text-brand transition hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none"
										>
											<Smartphone aria-hidden="true" size={18} strokeWidth={2} />
											Configurar
										</a>
									{/if}
									<a
										href={resolve('/patients/[id]/safe-zones', { id: patient.id })}
										class="inline-flex min-h-12 flex-1 items-center justify-center gap-2 rounded-full px-4 font-bold text-brand transition hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none"
									>
										<ShieldCheck aria-hidden="true" size={18} strokeWidth={2} />
										Geocercas
									</a>
								</div>
							</div>
						</li>
					{/each}
				</ul>
			</section>
		{:else}
			<div class="mt-6 rounded-2xl bg-white p-6 shadow-sm">
				<div
					class="flex size-12 items-center justify-center rounded-full bg-surface-muted text-ink"
				>
					<UserPlus aria-hidden="true" size={22} strokeWidth={1.75} />
				</div>
				<h2 class="mt-5 text-xl font-bold text-ink">Aún no tienes pacientes</h2>
				<p class="mt-2 max-w-2xl leading-7 text-muted">
					Agrega un paciente o ingresa un código de acceso para comenzar.
				</p>
			</div>
		{/if}
	</div>
</main>
