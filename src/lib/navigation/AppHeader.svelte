<script lang="ts">
	import { invalidate } from '$app/navigation';
	import { resolve } from '$app/paths';
	import { page } from '$app/state';
	import { createBrowserSupabaseClient } from '#lib';
	import ArrowLeft from '@lucide/svelte/icons/arrow-left';
	import Bell from '@lucide/svelte/icons/bell';
	import CircleUserRound from '@lucide/svelte/icons/circle-user-round';
	import { onMount } from 'svelte';

	type Props = { hasActiveAlert: boolean };
	type BackTarget = { kind: 'patients' } | { kind: 'onboarding' } | { kind: 'patient'; id: string };
	type HeaderConfig = { title: string; back?: BackTarget };

	let { hasActiveAlert }: Props = $props();
	let pathname = $derived(page.url.pathname);
	let header = $derived.by(() => getHeaderConfig(page.route.id, page.data));

	function getPatientData(data: App.PageData) {
		const patient = (data as unknown as Record<string, unknown>).patient as
			| {
					id?: string;
					firstName?: string;
					lastName?: string;
					first_name?: string;
					last_name?: string;
			  }
			| undefined;
		const firstName = patient?.firstName ?? patient?.first_name ?? '';
		const lastName = patient?.lastName ?? patient?.last_name ?? '';

		return {
			id: patient?.id,
			firstName,
			fullName: `${firstName} ${lastName}`.trim()
		};
	}

	function getHeaderConfig(routeId: string | null, data: App.PageData): HeaderConfig {
		const patient = getPatientData(data);
		const patientBack: BackTarget = patient.id
			? { kind: 'patient', id: patient.id }
			: { kind: 'patients' };

		switch (routeId) {
			case '/dashboard':
				return { title: 'Inicio' };
			case '/patients':
				return { title: 'Pacientes' };
			case '/alerts':
				return { title: 'Alertas' };
			case '/settings':
				return { title: 'Perfil' };
			case '/onboarding':
				return { title: 'Primeros pasos', back: { kind: 'patients' } };
			case '/access-code':
				return { title: 'Código de acceso', back: { kind: 'onboarding' } };
			case '/groups':
				return { title: 'Nuevo paciente y dispositivo', back: { kind: 'patients' } };
			case '/patients/[id]':
				return { title: patient.fullName || 'Paciente', back: { kind: 'patients' } };
			case '/patients/[id]/device':
				return {
					title: patient.firstName ? `Dispositivo de ${patient.firstName}` : 'Dispositivo',
					back: patientBack
				};
			case '/patients/[id]/map':
				return {
					title: patient.fullName ? `Mapa de ${patient.fullName}` : 'Mapa del paciente',
					back: patientBack
				};
			case '/patients/[id]/access':
				return {
					title: patient.firstName ? `Accesos de ${patient.firstName}` : 'Accesos del paciente',
					back: patientBack
				};
			case '/patients/[id]/safe-zones':
				return {
					title: patient.fullName ? `Geocercas de ${patient.fullName}` : 'Geocercas',
					back: patientBack
				};
			default:
				return { title: 'Senda' };
		}
	}

	onMount(() => {
		let supabase;
		try {
			supabase = createBrowserSupabaseClient();
		} catch {
			return;
		}

		const refreshAlerts = () => {
			void invalidate('senda:active-alert-indicator');
			void invalidate('senda:patient-alerts');
		};
		const channel = supabase
			.channel('app-header-active-alert', {
				config: { postgres_changes_options: { wait: true } }
			})
			.on(
				'postgres_changes',
				{ event: 'INSERT', schema: 'public', table: 'alert_episodes' },
				refreshAlerts
			)
			.on(
				'postgres_changes',
				{ event: 'UPDATE', schema: 'public', table: 'alert_episodes' },
				refreshAlerts
			)
			.subscribe();

		return () => {
			void supabase.removeChannel(channel);
		};
	});
</script>

<header
	class="sticky top-2 z-30 mx-2 mb-2 rounded-2xl bg-white shadow-md sm:top-4 sm:mx-4 sm:mb-0 lg:mx-0"
>
	<div class="flex min-h-16 w-full items-center gap-2 px-4 sm:px-6 lg:px-4">
		{#if header.back}
			<a
				href={header.back.kind === 'patients'
					? resolve('/patients')
					: header.back.kind === 'onboarding'
						? resolve('/onboarding')
						: resolve('/patients/[id]', { id: header.back.id })}
				aria-label="Regresar"
				class="grid size-12 shrink-0 place-items-center rounded-full text-ink transition-colors hover:bg-surface-muted focus:ring-4 focus:ring-focus/30 focus:outline-none"
			>
				<ArrowLeft size={24} strokeWidth={2} aria-hidden="true" />
			</a>
		{/if}

		<h1
			class={[
				'min-w-0 flex-1 truncate text-lg font-bold text-ink sm:text-xl',
				!header.back && 'ms-2'
			]}
		>
			{header.title}
		</h1>

		<div class="ml-auto flex shrink-0 items-center gap-2">
			<a
				href={resolve('/alerts')}
				aria-label={hasActiveAlert ? 'Alertas: hay una alerta activa' : 'Ver alertas'}
				class={[
					'relative grid size-12 place-items-center rounded-full transition-colors focus:ring-4 focus:ring-focus/30 focus:outline-none',
					pathname.startsWith(resolve('/alerts'))
						? 'bg-ink text-white'
						: 'text-ink hover:bg-surface-muted'
				]}
			>
				<Bell size={23} strokeWidth={2} aria-hidden="true" />
				{#if hasActiveAlert}
					<span
						class="absolute top-2.5 right-2.5 size-2.5 rounded-full bg-rose-600 ring-2 ring-white"
						aria-hidden="true"
					></span>
				{/if}
			</a>

			<a
				href={resolve('/settings')}
				aria-label="Abrir mi perfil"
				class={[
					'grid size-12 place-items-center rounded-full transition-colors focus:ring-4 focus:ring-focus/30 focus:outline-none',
					pathname.startsWith(resolve('/settings'))
						? 'bg-ink text-white'
						: 'text-ink hover:bg-surface-muted'
				]}
			>
				<CircleUserRound size={24} strokeWidth={2} aria-hidden="true" />
			</a>
		</div>
	</div>
</header>
