<script lang="ts">
	import { invalidate } from '$app/navigation';
	import { resolve } from '$app/paths';
	import { createBrowserSupabaseClient } from '#lib';
	import Alert from '#lib/components/ui/Alert.svelte';
	import Initials from '#lib/components/ui/Initials.svelte';
	import type { PatientStatusKind } from '#lib/types/patient-status.js';
	import { presentLocationTime } from '#lib/utils/location-presentation.js';
	import {
		classifyPatientStatus,
		needsAttention,
		rankPatientStatus
	} from '#lib/utils/patient-status.js';
	import ArrowUpRight from '@lucide/svelte/icons/arrow-up-right';
	import ChevronDown from '@lucide/svelte/icons/chevron-down';
	import CircleAlert from '@lucide/svelte/icons/circle-alert';
	import CircleCheck from '@lucide/svelte/icons/circle-check';
	import Clock3 from '@lucide/svelte/icons/clock-3';
	import HeartHandshake from '@lucide/svelte/icons/heart-handshake';
	import KeyRound from '@lucide/svelte/icons/key-round';
	import MapPinOff from '@lucide/svelte/icons/map-pin-off';
	import MapPinned from '@lucide/svelte/icons/map-pinned';
	import Route from '@lucide/svelte/icons/route';
	import ShieldCheck from '@lucide/svelte/icons/shield-check';
	import Siren from '@lucide/svelte/icons/siren';
	import Smartphone from '@lucide/svelte/icons/smartphone';
	import UserPlus from '@lucide/svelte/icons/user-plus';
	import { onMount, untrack } from 'svelte';
	import type { PageProps } from './$types';

	type Patient = PageProps['data']['patients'][number];
	type Row = {
		kind: PatientStatusKind;
		patient: Patient;
		title: string;
		detail: string;
		/** Lo que el usuario debe hacer a continuación. */
		action: {
			label: string;
			route: 'map' | 'zones' | 'device' | 'patient';
			icon: 'map' | 'device' | 'zones' | 'open';
		};
	};

	const timeFormatter = new Intl.DateTimeFormat('es-DO', {
		hour: '2-digit',
		minute: '2-digit',
		timeZone: 'America/Santo_Domingo'
	});

	let { data }: PageProps = $props();
	let now = $state(untrack(() => data.loadedAt));
	let clock = $derived(Math.max(now, data.loadedAt));
	let displayName = $derived(data.profile?.full_name || data.user.email || 'Usuario de Senda');
	let allStatesAvailable = $derived(
		data.patientsAvailable &&
			data.devicesAvailable &&
			data.alertsAvailable &&
			data.locationsAvailable &&
			data.transfersAvailable
	);

	function patientName(patient: Patient) {
		return `${patient.firstName} ${patient.lastName}`.trim();
	}

	function hrefOf(row: Row) {
		const params = { id: row.patient.id };
		switch (row.action.route) {
			case 'zones':
				return resolve('/patients/[id]/safe-zones', params);
			case 'device':
				return resolve('/patients/[id]/device', params);
			case 'patient':
				return resolve('/patients/[id]', params);
			default:
				return resolve('/patients/[id]/map', params);
		}
	}

	function buildRow(patient: Patient): Row {
		const time = patient.latestLocationRecordedAt
			? presentLocationTime(patient.latestLocationRecordedAt, clock)
			: null;
		const kind = classifyPatientStatus({
			hasAlert: patient.activeAlert !== null,
			hasDevice: patient.assignmentId !== null,
			hasActiveTransfer: patient.activeTransferEndsAt !== null,
			freshness: time?.freshness ?? null,
			relation: patient.latestGeofenceRelation,
			dataComplete: allStatesAvailable
		});
		const openMap = { label: 'Abrir mapa', route: 'map' as const, icon: 'map' as const };
		const lastReading = time ? ` Última lectura ${time.ageLabel}.` : '';

		switch (kind) {
			case 'ALERT': {
				const confirmed = patient.activeAlert
					? presentLocationTime(patient.activeAlert.confirmedAt, clock).ageLabel
					: '';
				return {
					kind,
					patient,
					title: 'Salida confirmada activa',
					detail: `Salida confirmada ${confirmed}.${lastReading}`,
					action: { ...openMap, label: 'Ver ubicación ahora' }
				};
			}
			case 'REVIEW': {
				const relation = patient.latestGeofenceRelation;
				if (relation === 'OUTSIDE') {
					return {
						kind,
						patient,
						title: 'Fuera de zona, por confirmar',
						detail: `La lectura quedó fuera de las zonas permitidas y aún no se confirma una salida.${lastReading}`,
						action: { ...openMap, label: 'Revisar ubicación' }
					};
				}
				if (relation === 'UNCERTAIN') {
					return {
						kind,
						patient,
						title: 'Ubicación por confirmar',
						detail: `La precisión no permite saber si está dentro o fuera.${lastReading}`,
						action: { ...openMap, label: 'Revisar ubicación' }
					};
				}
				return {
					kind,
					patient,
					title: 'Sin zona permitida que evaluar',
					detail: 'No hay una geocerca activa con la que comparar la ubicación.',
					action: {
						label: 'Configurar geocercas',
						route: 'zones',
						icon: 'zones'
					}
				};
			}
			case 'STALE':
				return {
					kind,
					patient,
					title: 'Ubicación desactualizada',
					detail: `Última ubicación ${time?.ageLabel ?? ''}. No representa una posición en vivo.`,
					action: { ...openMap, label: 'Revisar ubicación' }
				};
			case 'NO_LOCATION':
				return {
					kind,
					patient,
					title: 'Sin ubicaciones recibidas',
					detail: 'El dispositivo todavía no ha enviado una ubicación.',
					action: openMap
				};
			case 'NO_DEVICE':
				return {
					kind,
					patient,
					title: 'Sin dispositivo configurado',
					detail: 'El monitoreo de ubicación todavía no está activo.',
					action:
						patient.accessRole === 'ADMIN'
							? {
									label: 'Configurar dispositivo',
									route: 'device',
									icon: 'device'
								}
							: {
									label: 'Ver paciente',
									route: 'patient' as const,
									icon: 'open'
								}
				};
			case 'TRANSFER':
				return {
					kind,
					patient,
					title: 'En traslado planificado',
					detail: `Autorizado hasta las ${timeFormatter.format(new Date(patient.activeTransferEndsAt ?? clock))}.${lastReading}`,
					action: openMap
				};
			case 'OK':
				return {
					kind,
					patient,
					title: 'Dentro de una zona permitida',
					detail: `Última ubicación ${time?.ageLabel ?? ''}.`,
					action: openMap
				};
			default:
				return {
					kind,
					patient,
					title: 'Estado no disponible',
					detail: 'No pudimos comprobar todos los datos de este paciente.',
					action: {
						label: 'Ver paciente',
						route: 'patient' as const,
						icon: 'open'
					}
				};
		}
	}

	// Ordenado por urgencia y, a igualdad, por nombre: lo primero que se ve es lo que pide acción.
	let rows = $derived(
		data.patients
			.map(buildRow)
			.sort(
				(a, b) =>
					rankPatientStatus(a.kind) - rankPatientStatus(b.kind) ||
					patientName(a.patient).localeCompare(patientName(b.patient), 'es')
			)
	);
	let attentionRows = $derived(rows.filter((row) => needsAttention(row.kind)));
	let calmRows = $derived(rows.filter((row) => row.kind === 'OK' || row.kind === 'TRANSFER'));
	let counts = $derived({
		alerts: rows.filter((row) => row.kind === 'ALERT').length,
		review: rows.filter((row) => row.kind === 'REVIEW' || row.kind === 'STALE').length,
		setup: rows.filter((row) => row.kind === 'NO_LOCATION' || row.kind === 'NO_DEVICE').length,
		calm: calmRows.length
	});
	let attentionSummary = $derived.by(() => {
		if (!data.patientsAvailable) return 'No pudimos revisar tus pacientes.';
		if (!allStatesAvailable && attentionRows.length === 0) {
			return 'Algunos estados de pacientes no están disponibles.';
		}
		if (attentionRows.length === 0) return 'No hay asuntos pendientes comprobados.';
		if (attentionRows.length === 1) return '1 paciente requiere tu atención.';
		return `${attentionRows.length} pacientes requieren tu atención.`;
	});
	let summaryItems = $derived([
		{ key: 'alerts', label: 'Alertas activas', value: counts.alerts, tone: 'danger', icon: Siren },
		{ key: 'review', label: 'Por revisar', value: counts.review, tone: 'warning', icon: Clock3 },
		{
			key: 'setup',
			label: 'Sin configurar',
			value: counts.setup,
			tone: 'neutral',
			icon: Smartphone
		},
		{ key: 'calm', label: 'Sin novedad', value: counts.calm, tone: 'calm', icon: CircleCheck }
	] as const);

	const toneClasses = {
		danger: { chip: 'bg-red-50 text-red-800', title: 'text-red-900' },
		warning: { chip: 'bg-amber-50 text-amber-800', title: 'text-amber-900' },
		neutral: { chip: 'bg-surface-muted text-brand', title: 'text-muted' },
		calm: { chip: 'bg-surface-muted text-brand', title: 'text-muted' }
	} as const;

	function toneOf(kind: PatientStatusKind) {
		if (kind === 'ALERT') return toneClasses.danger;
		if (kind === 'REVIEW' || kind === 'STALE' || kind === 'NO_LOCATION') return toneClasses.warning;
		return toneClasses.neutral;
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

		// Este canal escucha las lecturas de todos los pacientes. Se agrupan en una sola recarga
		// por ventana para no lanzar una consulta SSR por cada lectura entrante.
		let refreshTimer: ReturnType<typeof setTimeout> | null = null;
		function scheduleRefresh() {
			if (refreshTimer) return;
			refreshTimer = setTimeout(() => {
				refreshTimer = null;
				void invalidate('senda:dashboard-attention');
			}, 5_000);
		}

		const channel = supabase
			.channel('dashboard-location-attention', {
				config: { postgres_changes_options: { wait: true } }
			})
			.on(
				'postgres_changes',
				{ event: 'INSERT', schema: 'public', table: 'locations' },
				scheduleRefresh
			)
			.subscribe();

		return () => {
			clearInterval(timeInterval);
			if (refreshTimer) clearTimeout(refreshTimer);
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

			<nav class="mt-6 grid gap-3 sm:grid-cols-2 xl:grid-cols-4" aria-label="Acciones rápidas">
				<a
					href={resolve('/groups?mode=patient')}
					class="inline-flex min-h-12 items-center justify-center gap-2 rounded-full border border-field bg-white px-4 font-bold text-ink transition-colors hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none"
				>
					<UserPlus aria-hidden="true" class="text-brand" size={18} strokeWidth={2} />
					Agregar paciente
				</a>
				<a
					href={resolve('/access-code')}
					class="inline-flex min-h-12 items-center justify-center gap-2 rounded-full border border-field bg-white px-4 font-bold text-ink transition-colors hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none"
				>
					<KeyRound aria-hidden="true" class="text-brand" size={18} strokeWidth={2} />
					Ingresar código
				</a>
				<a
					href={resolve('/patients')}
					class="inline-flex min-h-12 items-center justify-center gap-2 rounded-full border border-field bg-white px-4 font-bold text-ink transition-colors hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none"
				>
					<HeartHandshake aria-hidden="true" class="text-brand" size={18} strokeWidth={2} />
					Ver pacientes
				</a>
				<a
					href={resolve('/alerts')}
					class="inline-flex min-h-12 items-center justify-center gap-2 rounded-full border border-field bg-white px-4 font-bold text-ink transition-colors hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none"
				>
					<Siren aria-hidden="true" class="text-brand" size={18} strokeWidth={2} />
					Ver alertas
				</a>
			</nav>
		</section>

		{#if data.patientsAvailable && data.patients.length > 0}
			<section class="mt-8" aria-labelledby="summary-title">
				<h2 id="summary-title" class="sr-only">Resumen del estado de tus pacientes</h2>
				<ul class="grid grid-cols-2 gap-3 2xl:grid-cols-4">
					{#each summaryItems as item (item.key)}
						{@const Icon = item.icon}
						<li
							class="flex items-center gap-3 rounded-2xl bg-white p-4 shadow-sm"
							aria-label={`${item.label}: ${item.value}`}
						>
							<div
								class={[
									'flex size-11 shrink-0 items-center justify-center rounded-full',
									item.value > 0 ? toneClasses[item.tone].chip : 'bg-canvas text-muted'
								]}
							>
								<Icon aria-hidden="true" size={20} strokeWidth={2} />
							</div>
							<div class="min-w-0">
								<p class="text-2xl leading-7 font-bold text-ink">{item.value}</p>
								<p class="text-sm leading-5 text-muted">{item.label}</p>
							</div>
						</li>
					{/each}
				</ul>
			</section>
		{/if}

		<section class="mt-10" aria-labelledby="attention-title">
			<h2 id="attention-title" class="mb-6 text-2xl font-bold text-ink">Requiere tu atención</h2>

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

				{#if attentionRows.length > 0}
					<ul class="grid gap-5 md:grid-cols-2 xl:grid-cols-3">
						{#each attentionRows as row (`${row.kind}:${row.patient.id}`)}
							{@const tone = toneOf(row.kind)}
							<li class="flex h-full flex-col overflow-hidden rounded-2xl bg-white shadow-sm">
								<div class="flex flex-1 items-start gap-4 p-6">
									<div
										class={[
											'flex size-12 shrink-0 items-center justify-center rounded-full',
											tone.chip
										]}
									>
										{#if row.kind === 'ALERT'}
											<Siren aria-hidden="true" size={22} strokeWidth={2} />
										{:else if row.kind === 'REVIEW'}
											<CircleAlert aria-hidden="true" size={22} strokeWidth={2} />
										{:else if row.kind === 'STALE'}
											<Clock3 aria-hidden="true" size={22} strokeWidth={2} />
										{:else if row.kind === 'NO_LOCATION'}
											<MapPinOff aria-hidden="true" size={22} strokeWidth={2} />
										{:else}
											<Smartphone aria-hidden="true" size={22} strokeWidth={2} />
										{/if}
									</div>

									<div class="min-w-0">
										<p class={['text-sm font-bold', tone.title]}>{row.title}</p>
										<h3 class="mt-1 text-xl font-bold wrap-break-word text-ink">
											{patientName(row.patient)}
										</h3>
										<p class="mt-2 leading-6 text-muted">{row.detail}</p>
									</div>
								</div>

								<div class="border-t border-ink/10 p-4">
									<a
										href={hrefOf(row)}
										class="inline-flex min-h-12 w-full items-center justify-center gap-2 rounded-full bg-brand px-5 font-bold text-white transition-colors hover:bg-brand/90 focus:ring-4 focus:ring-focus/30 focus:outline-none"
									>
										{#if row.action.icon === 'device'}
											<Smartphone aria-hidden="true" size={18} strokeWidth={2} />
										{:else if row.action.icon === 'zones'}
											<ShieldCheck aria-hidden="true" size={18} strokeWidth={2} />
										{:else if row.action.icon === 'open'}
											<ArrowUpRight aria-hidden="true" size={18} strokeWidth={2} />
										{:else}
											<MapPinned aria-hidden="true" size={18} strokeWidth={2} />
										{/if}
										{row.action.label}
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

		{#if data.patientsAvailable && calmRows.length > 0}
			<section class="mt-10" aria-labelledby="calm-title">
				<details class="group rounded-2xl bg-white shadow-sm">
					<summary
						class="flex min-h-14 cursor-pointer list-none items-center justify-between gap-3 rounded-2xl px-6 py-4 [&::-webkit-details-marker]:hidden"
					>
						<h2 id="calm-title" class="text-lg font-bold text-ink">
							Sin novedad ({calmRows.length})
						</h2>
						<ChevronDown
							aria-hidden="true"
							size={20}
							strokeWidth={2}
							class="shrink-0 text-muted transition-transform group-open:rotate-180 motion-reduce:transition-none"
						/>
					</summary>
					<ul class="divide-y divide-ink/10 border-t border-ink/10">
						{#each calmRows as row (row.patient.id)}
							<li>
								<a
									href={hrefOf(row)}
									class="flex min-h-16 items-center gap-4 px-6 py-3 transition-colors hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none focus:ring-inset"
								>
									<Initials text={patientName(row.patient)} />
									<div class="min-w-0 flex-1">
										<p class="font-bold wrap-break-word text-ink">{patientName(row.patient)}</p>
										<p class="flex items-center gap-2 text-sm leading-5 text-muted">
											{#if row.kind === 'TRANSFER'}
												<Route aria-hidden="true" size={16} strokeWidth={2} class="shrink-0" />
											{:else}
												<CircleCheck
													aria-hidden="true"
													size={16}
													strokeWidth={2}
													class="shrink-0"
												/>
											{/if}
											<span>{row.title}. {row.detail}</span>
										</p>
									</div>
									<ArrowUpRight
										aria-hidden="true"
										size={18}
										strokeWidth={2}
										class="shrink-0 text-muted"
									/>
								</a>
							</li>
						{/each}
					</ul>
				</details>
			</section>
		{/if}
	</div>
</main>
