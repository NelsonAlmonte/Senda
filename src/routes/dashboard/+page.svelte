<script lang="ts">
	import { invalidate } from '$app/navigation';
	import { resolve } from '$app/paths';
	import { createBrowserSupabaseClient } from '#lib';
	import Alert from '#lib/components/ui/Alert.svelte';
	import { presentDateTime, presentLocationTime } from '#lib/utils/location-presentation.js';
	import ArrowUpRight from '@lucide/svelte/icons/arrow-up-right';
	import CircleAlert from '@lucide/svelte/icons/circle-alert';
	import CircleCheck from '@lucide/svelte/icons/circle-check';
	import Clock3 from '@lucide/svelte/icons/clock-3';
	import HeartHandshake from '@lucide/svelte/icons/heart-handshake';
	import KeyRound from '@lucide/svelte/icons/key-round';
	import MapPinOff from '@lucide/svelte/icons/map-pin-off';
	import MapPinned from '@lucide/svelte/icons/map-pinned';
	import Siren from '@lucide/svelte/icons/siren';
	import Smartphone from '@lucide/svelte/icons/smartphone';
	import UserPlus from '@lucide/svelte/icons/user-plus';
	import { onMount, untrack } from 'svelte';
	import type { PageProps } from './$types';

	type Patient = PageProps['data']['patients'][number];
	type AttentionKind = 'ALERT' | 'STALE' | 'NO_LOCATION' | 'NO_DEVICE';
	type AttentionItem = {
		kind: AttentionKind;
		patient: Patient;
		detail: string;
	};

	let { data }: PageProps = $props();
	let now = $state(untrack(() => data.loadedAt));
	let displayName = $derived(data.profile?.full_name || data.user.email || 'Usuario de Senda');
	let allStatesAvailable = $derived(
		data.patientsAvailable &&
			data.devicesAvailable &&
			data.alertsAvailable &&
			data.locationsAvailable
	);
	let attentionItems = $derived.by(() => {
		const activeAlerts: AttentionItem[] = [];
		const staleLocations: AttentionItem[] = [];
		const missingLocations: AttentionItem[] = [];
		const missingDevices: AttentionItem[] = [];

		for (const patient of data.patients) {
			if (patient.activeAlert) {
				activeAlerts.push({
					kind: 'ALERT',
					patient,
					detail: `Confirmada el ${presentDateTime(patient.activeAlert.confirmedAt)}.`
				});
				continue;
			}

			if (data.devicesAvailable && !patient.assignmentId) {
				missingDevices.push({
					kind: 'NO_DEVICE',
					patient,
					detail: 'El monitoreo de ubicación todavía no está activo.'
				});
				continue;
			}

			if (!patient.assignmentId || !data.locationsAvailable) continue;

			if (!patient.latestLocationRecordedAt) {
				missingLocations.push({
					kind: 'NO_LOCATION',
					patient,
					detail: 'El dispositivo todavía no ha enviado una ubicación.'
				});
				continue;
			}

			const locationTime = presentLocationTime(patient.latestLocationRecordedAt, now);
			if (locationTime.freshness === 'STALE') {
				staleLocations.push({
					kind: 'STALE',
					patient,
					detail: `Última ubicación ${locationTime.ageLabel}.`
				});
			}
		}

		return [...activeAlerts, ...staleLocations, ...missingLocations, ...missingDevices];
	});
	let attentionSummary = $derived.by(() => {
		if (!data.patientsAvailable) return 'No pudimos revisar tus pacientes.';
		if (!allStatesAvailable && attentionItems.length === 0) {
			return 'Algunos estados de pacientes no están disponibles.';
		}
		if (attentionItems.length === 0) return 'No hay asuntos pendientes comprobados.';
		if (attentionItems.length === 1) return '1 paciente requiere tu atención.';
		return `${attentionItems.length} pacientes requieren tu atención.`;
	});

	function patientName(patient: Patient) {
		return `${patient.firstName} ${patient.lastName}`.trim();
	}

	function attentionTitle(kind: AttentionKind) {
		switch (kind) {
			case 'ALERT':
				return 'Salida confirmada activa';
			case 'STALE':
				return 'Ubicación desactualizada';
			case 'NO_LOCATION':
				return 'Sin ubicaciones recibidas';
			case 'NO_DEVICE':
				return 'Sin dispositivo configurado';
		}
	}

	function attentionHref(item: AttentionItem) {
		if (item.kind === 'NO_DEVICE') {
			return item.patient.accessRole === 'ADMIN'
				? resolve('/patients/[id]/device', { id: item.patient.id })
				: resolve('/patients/[id]', { id: item.patient.id });
		}

		return resolve('/patients/[id]/map', { id: item.patient.id });
	}

	function attentionAction(item: AttentionItem) {
		if (item.kind === 'NO_DEVICE') {
			return item.patient.accessRole === 'ADMIN' ? 'Configurar dispositivo' : 'Ver paciente';
		}

		return item.kind === 'ALERT' || item.kind === 'STALE' ? 'Revisar ubicación' : 'Abrir mapa';
	}

	onMount(() => {
		const timeInterval = setInterval(() => {
			now = Date.now();
		}, 30_000);

		let supabase;
		try {
			supabase = createBrowserSupabaseClient();
		} catch {
			return () => clearInterval(timeInterval);
		}

		const channel = supabase
			.channel('dashboard-location-attention', {
				config: { postgres_changes_options: { wait: true } }
			})
			.on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'locations' }, () => {
				void invalidate('senda:dashboard-attention');
			})
			.subscribe();

		return () => {
			clearInterval(timeInterval);
			void supabase.removeChannel(channel);
		};
	});
</script>

<svelte:head><title>Inicio | Senda</title></svelte:head>

<main id="contenido-principal" class="px-5 py-8 sm:px-8 lg:px-0">
	<div class="w-full">
		<section class="rounded-2xl bg-white p-6 shadow-sm" aria-labelledby="dashboard-welcome">
			<div
				class="flex size-12 items-center justify-center rounded-full bg-surface-muted text-brand"
			>
				<HeartHandshake aria-hidden="true" size={23} strokeWidth={2} />
			</div>
			<h2 id="dashboard-welcome" class="mt-5 text-2xl font-bold text-ink">
				Hola, {displayName}.
			</h2>
			<p class="mt-2 leading-7 text-muted">
				Aquí tienes lo más importante de las personas a tu cuidado. Accede rápidamente a las tareas
				más frecuentes.
			</p>

			<nav class="mt-3 grid gap-3 sm:grid-cols-2 xl:grid-cols-4" aria-label="Acciones rápidas">
				<a
					href={resolve('/groups?mode=patient')}
					class="inline-flex min-h-12 items-center justify-center gap-2 rounded-full px-4 font-bold text-brand transition-colors hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none"
				>
					<UserPlus aria-hidden="true" size={18} strokeWidth={2} />
					Agregar paciente
				</a>
				<a
					href={resolve('/access-code')}
					class="inline-flex min-h-12 items-center justify-center gap-2 rounded-full px-4 font-bold text-brand transition-colors hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none"
				>
					<KeyRound aria-hidden="true" size={18} strokeWidth={2} />
					Ingresar código
				</a>
				<a
					href={resolve('/patients')}
					class="inline-flex min-h-12 items-center justify-center gap-2 rounded-full px-4 font-bold text-brand transition-colors hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none"
				>
					<HeartHandshake aria-hidden="true" size={18} strokeWidth={2} />
					Ver pacientes
				</a>
				<a
					href={resolve('/alerts')}
					class="inline-flex min-h-12 items-center justify-center gap-2 rounded-full px-4 font-bold text-brand transition-colors hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none"
				>
					<Siren aria-hidden="true" size={18} strokeWidth={2} />
					Ver alertas
				</a>
			</nav>
		</section>

		<section class="mt-12" aria-labelledby="attention-title">
			<h2 id="attention-title" class="mb-8 text-2xl font-bold text-ink">Requiere tu atención</h2>

			<p class="sr-only" role="status" aria-live="polite" aria-atomic="true">
				{attentionSummary}
			</p>

			{#if !data.patientsAvailable}
				<div class="max-w-2xl">
					<Alert
						icon={CircleAlert}
						title="No pudimos revisar tus pacientes"
						subtitle="Inténtalo nuevamente en unos minutos."
						color="warning"
					/>
				</div>
			{:else}
				{#if !allStatesAvailable}
					<div class="mb-8 max-w-2xl">
						<Alert
							icon={CircleAlert}
							title="Algunos estados no están disponibles"
							subtitle="Mostramos solamente la información que pudimos comprobar."
							color="warning"
						/>
					</div>
				{/if}

				{#if attentionItems.length > 0}
					<ul class="grid gap-5 md:grid-cols-2 xl:grid-cols-3">
						{#each attentionItems as item (`${item.kind}:${item.patient.id}`)}
							<li class="flex h-full flex-col overflow-hidden rounded-2xl bg-white shadow-sm">
								<div class="flex flex-1 items-start gap-4 p-6">
									<div
										class={[
											'flex size-12 shrink-0 items-center justify-center rounded-full',
											item.kind === 'ALERT'
												? 'bg-red-50 text-red-800'
												: item.kind === 'STALE' || item.kind === 'NO_LOCATION'
													? 'bg-amber-50 text-amber-800'
													: 'bg-surface-muted text-brand'
										]}
									>
										{#if item.kind === 'ALERT'}
											<Siren aria-hidden="true" size={22} strokeWidth={2} />
										{:else if item.kind === 'STALE'}
											<Clock3 aria-hidden="true" size={22} strokeWidth={2} />
										{:else if item.kind === 'NO_LOCATION'}
											<MapPinOff aria-hidden="true" size={22} strokeWidth={2} />
										{:else}
											<Smartphone aria-hidden="true" size={22} strokeWidth={2} />
										{/if}
									</div>

									<div class="min-w-0">
										<p
											class={[
												'text-sm font-bold',
												item.kind === 'ALERT'
													? 'text-red-900'
													: item.kind === 'STALE' || item.kind === 'NO_LOCATION'
														? 'text-amber-900'
														: 'text-muted'
											]}
										>
											{attentionTitle(item.kind)}
										</p>
										<h3 class="mt-1 text-xl font-bold wrap-break-word text-ink">
											{patientName(item.patient)}
										</h3>
										<p class="mt-2 leading-6 text-muted">{item.detail}</p>
									</div>
								</div>

								<div class="border-t border-ink/10 p-4">
									<a
										href={attentionHref(item)}
										class="inline-flex min-h-12 w-full items-center justify-center gap-2 rounded-full bg-brand px-5 font-bold text-white transition-colors hover:bg-brand/90 focus:ring-4 focus:ring-focus/30 focus:outline-none"
									>
										{#if item.kind === 'NO_DEVICE' && item.patient.accessRole === 'ADMIN'}
											<Smartphone aria-hidden="true" size={18} strokeWidth={2} />
										{:else if item.kind === 'NO_DEVICE'}
											<ArrowUpRight aria-hidden="true" size={18} strokeWidth={2} />
										{:else}
											<MapPinned aria-hidden="true" size={18} strokeWidth={2} />
										{/if}
										{attentionAction(item)}
									</a>
								</div>
							</li>
						{/each}
					</ul>
				{:else if allStatesAvailable}
					<div class="rounded-2xl bg-white p-6 shadow-sm">
						<div
							class="flex size-12 items-center justify-center rounded-full bg-surface-muted text-brand"
						>
							<CircleCheck aria-hidden="true" size={22} strokeWidth={2} />
						</div>
						{#if data.patients.length > 0}
							<h3 class="mt-5 text-xl font-bold text-ink">No hay asuntos pendientes</h3>
							<p class="mt-2 max-w-2xl leading-7 text-muted">
								No hay alertas abiertas, ubicaciones desactualizadas ni configuraciones incompletas.
							</p>
						{:else}
							<h3 class="mt-5 text-xl font-bold text-ink">Aún no tienes pacientes</h3>
							<p class="mt-2 max-w-2xl leading-7 text-muted">
								Agrega un paciente o ingresa un código de acceso para comenzar.
							</p>
						{/if}
					</div>
				{/if}
			{/if}
		</section>
	</div>
</main>
