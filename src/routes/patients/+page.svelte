<script lang="ts">
	import { resolve } from '$app/paths';
	import Alert from '#lib/components/ui/Alert.svelte';
	import Initials from '#lib/components/ui/Initials.svelte';
	import ArrowUpRight from '@lucide/svelte/icons/arrow-up-right';
	import BellOff from '@lucide/svelte/icons/bell-off';
	import BellRing from '@lucide/svelte/icons/bell-ring';
	import CircleAlert from '@lucide/svelte/icons/circle-alert';
	import CircleCheck from '@lucide/svelte/icons/circle-check';
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
	<div class="w-full">
		<div class="mb-8 flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
			<h2 id="personas-cuidado" class="text-2xl font-bold text-ink">Personas a tu cuidado</h2>

			<nav class="flex flex-wrap gap-3 lg:justify-end" aria-label="Acciones de pacientes">
				<a
					href={resolve('/groups?mode=patient')}
					class="inline-flex min-h-12 items-center justify-center gap-2 rounded-full bg-brand px-5 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none"
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
		</div>

		{#if data.patientCreated}
			<div class="mb-8 max-w-2xl">
				<Alert
					icon={CircleCheck}
					title="Paciente registrado"
					subtitle="Ya tienes acceso de administrador."
					color="positive"
				/>
			</div>
		{/if}

		{#if data.deviceConfigured}
			<div class="mb-8 max-w-2xl">
				<Alert
					icon={CircleCheck}
					title="Dispositivo configurado"
					subtitle="El dispositivo quedó asignado al paciente."
					color="positive"
				/>
			</div>
		{/if}

		{#if data.accessAccepted}
			<div class="mb-8 max-w-2xl">
				<Alert
					icon={CircleCheck}
					title="Código aceptado"
					subtitle="Ya puedes monitorear al paciente autorizado."
					color="positive"
				/>
			</div>
		{/if}

		{#if !data.patientsAvailable}
			<div class="max-w-2xl">
				<Alert
					icon={CircleAlert}
					title="No pudimos consultar tus pacientes"
					subtitle="Inténtalo nuevamente en unos minutos."
					color="warning"
				/>
			</div>
		{:else if !data.devicesAvailable}
			<div class="max-w-2xl">
				<Alert
					icon={CircleAlert}
					title="Estado de dispositivos no disponible"
					subtitle="Inténtalo nuevamente en unos minutos."
					color="warning"
				/>
			</div>
		{:else if patients.length > 0}
			<section aria-labelledby="personas-cuidado">
				<ul class="grid gap-5 md:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4">
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
									class="inline-flex min-h-12 w-full items-center justify-center gap-2 rounded-full bg-brand px-5 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/30 focus:outline-none"
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
			<div class="rounded-2xl bg-white p-6 shadow-sm">
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
