<script lang="ts">
	import { invalidate } from '$app/navigation';
	import { resolve } from '$app/paths';
	import Alert from '#lib/components/ui/Alert.svelte';
	import Initials from '#lib/components/ui/Initials.svelte';
	import Archive from '@lucide/svelte/icons/archive';
	import ArrowUpRight from '@lucide/svelte/icons/arrow-up-right';
	import BellOff from '@lucide/svelte/icons/bell-off';
	import BellRing from '@lucide/svelte/icons/bell-ring';
	import CircleAlert from '@lucide/svelte/icons/circle-alert';
	import CircleCheck from '@lucide/svelte/icons/circle-check';
	import CircleHelp from '@lucide/svelte/icons/circle-help';
	import KeyRound from '@lucide/svelte/icons/key-round';
	import MapPinned from '@lucide/svelte/icons/map-pinned';
	import Route from '@lucide/svelte/icons/route';
	import ShieldCheck from '@lucide/svelte/icons/shield-check';
	import Smartphone from '@lucide/svelte/icons/smartphone';
	import UserPlus from '@lucide/svelte/icons/user-plus';
	import { ContactRound } from '@lucide/svelte';
	import { onMount } from 'svelte';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();
	let patients = $derived(data.patients);

	type Patient = PageProps['data']['patients'][number];

	function patientName(patient: Patient) {
		return `${patient.firstName} ${patient.lastName}`.trim();
	}

	function statusHref(patient: Patient) {
		if (!data.alertsAvailable) {
			return resolve('/patients/[id]', { id: patient.id });
		}

		if (patient.activeAlert) {
			return resolve('/patients/[id]/episodes/[episodeId]', {
				id: patient.id,
				episodeId: patient.activeAlert.id
			});
		}

		if (!patient.assignment) {
			return patient.accessRole === 'ADMIN'
				? resolve('/patients/[id]/device', { id: patient.id })
				: resolve('/patients/[id]', { id: patient.id });
		}

		if (patient.activeTransfer) {
			return resolve('/patients/[id]/transfers', { id: patient.id });
		}

		return resolve('/patients/[id]/map', { id: patient.id });
	}

	onMount(() => {
		let active = true;
		let timeout: number | undefined;

		function scheduleNextBoundary() {
			const boundaryTime = Date.parse(data.nextTransferBoundary ?? '');
			if (!Number.isFinite(boundaryTime)) return;

			const maximumDelay = 2_147_483_647;
			const delay = Math.min(Math.max(boundaryTime - Date.now() + 250, 100), maximumDelay);
			timeout = window.setTimeout(async () => {
				await invalidate('senda:patient-transfers');
				if (active) scheduleNextBoundary();
			}, delay);
		}

		scheduleNextBoundary();

		return () => {
			active = false;
			if (timeout !== undefined) window.clearTimeout(timeout);
		};
	});
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
					href={resolve('/access-code')}
					class="inline-flex min-h-12 items-center justify-center gap-2 rounded-full border border-ink/15 bg-white px-5 font-bold text-ink transition hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none"
				>
					<KeyRound aria-hidden="true" size={18} strokeWidth={2} />
					Ingresar código
				</a>
				{#if data.hasArchivedPatients}
					<a
						href={resolve('/patients/archived')}
						class="inline-flex min-h-12 items-center justify-center gap-2 rounded-full px-5 font-bold text-brand transition hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none"
					>
						<Archive aria-hidden="true" size={18} strokeWidth={2} />
						Archivados
					</a>
				{/if}
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

		{#if !data.transfersAvailable && data.patientsAvailable}
			<div class="mb-8 max-w-2xl">
				<Alert
					icon={CircleAlert}
					title="Estado de traslados no disponible"
					subtitle="Los demás estados comprobados continúan visibles."
					color="warning"
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

								<a
									href={statusHref(patient)}
									class={[
										'group mt-5 flex min-h-14 items-center gap-3 rounded-2xl p-2 transition-colors focus:ring-4 focus:ring-focus/30 focus:outline-none',
										patient.activeAlert || patient.activeTransfer
											? 'hover:bg-amber-50'
											: 'hover:bg-canvas'
									]}
								>
									{#if !data.alertsAvailable}
										<div
											class="flex size-10 shrink-0 items-center justify-center rounded-full bg-amber-50 text-amber-950"
										>
											<CircleHelp aria-hidden="true" size={20} strokeWidth={2} />
										</div>
										<div class="min-w-0 flex-1">
											<p class="font-bold text-ink">Estado de alertas no disponible</p>
											<p class="mt-1 text-sm leading-5 text-muted">Inténtalo nuevamente.</p>
										</div>
									{:else if patient.activeAlert}
										<div
											class="flex size-10 shrink-0 items-center justify-center rounded-full bg-amber-100 text-amber-950"
										>
											<BellRing aria-hidden="true" size={20} strokeWidth={2} />
										</div>
										<div class="min-w-0 flex-1">
											<p class="font-bold text-amber-950">Alerta activa</p>
											<p class="mt-1 text-sm leading-5 text-amber-950">Salida confirmada.</p>
										</div>
									{:else if !patient.assignment}
										<div
											class="flex size-10 shrink-0 items-center justify-center rounded-full bg-surface-muted text-ink"
										>
											<Smartphone aria-hidden="true" size={20} strokeWidth={2} />
										</div>
										<div class="min-w-0 flex-1">
											<p class="font-bold text-ink">Sin dispositivo configurado</p>
											<p class="mt-1 text-sm leading-5 text-muted">
												{patient.accessRole === 'ADMIN'
													? 'Configurar el monitoreo.'
													: 'Un administrador debe configurarlo.'}
											</p>
										</div>
									{:else if patient.activeTransfer}
										<div
											class="flex size-10 shrink-0 items-center justify-center rounded-full bg-amber-50 text-amber-900"
										>
											<Route aria-hidden="true" size={20} strokeWidth={2} />
										</div>
										<div class="min-w-0 flex-1">
											<p class="font-bold text-amber-950">Traslado en curso</p>
											<p class="mt-1 text-sm leading-5 text-amber-950/80">
												Trayecto está autorizado.
											</p>
										</div>
									{:else}
										<div
											class="flex size-10 shrink-0 items-center justify-center rounded-full bg-surface-muted text-brand"
										>
											<BellOff aria-hidden="true" size={20} strokeWidth={2} />
										</div>
										<div class="min-w-0 flex-1">
											<p class="font-bold text-ink">Sin alertas activas</p>
											<p class="mt-1 text-sm leading-5 text-muted">No hay episodios abiertos.</p>
										</div>
									{/if}
									<ArrowUpRight
										aria-hidden="true"
										size={18}
										strokeWidth={2}
										class="shrink-0 text-muted transition-transform group-hover:translate-x-0.5 group-hover:-translate-y-0.5"
									/>
								</a>
							</div>

							<div class="border-t border-ink/10 p-4">
								<a
									href={resolve('/patients/[id]', { id: patient.id })}
									class="inline-flex min-h-12 w-full items-center justify-center gap-2 rounded-full bg-brand px-5 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/30 focus:outline-none"
								>
									<ContactRound aria-hidden="true" size={18} strokeWidth={2} />
									{patient.accessRole === 'ADMIN' ? 'Administrar paciente' : 'Ver paciente'}
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
