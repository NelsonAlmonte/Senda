<script lang="ts">
	import { goto } from '$app/navigation';
	import { resolve } from '$app/paths';
	import {
		BellOff,
		BellRing,
		CircleAlert,
		CircleCheckBig,
		LoaderCircle,
		ShieldAlert,
		Wrench
	} from '@lucide/svelte';
	import { onMount } from 'svelte';
	import Alert from '#lib/components/ui/Alert.svelte';
	import Heading from '#lib/components/ui/Heading.svelte';
	import type { UiIcon, UiTone } from '#lib/types/ui.js';
	import {
		disablePushNotifications,
		enablePushNotifications,
		PushNotificationSessionError,
		readPushNotificationStatus,
		type PushNotificationStatus
	} from './subscriptions.js';

	interface StatusPresentation {
		icon: UiIcon;
		title: string;
		subtitle: string;
		color: UiTone;
	}

	let status = $state<PushNotificationStatus>({ state: 'CHECKING' });
	let action = $state<'ENABLE' | 'DISABLE' | null>(null);
	let feedback = $state('');

	let isBusy = $derived(status.state === 'CHECKING' || action !== null);
	let statusPresentation: StatusPresentation = $derived.by(() => {
		switch (status.state) {
			case 'CHECKING':
				return {
					icon: LoaderCircle,
					title: 'Comprobando estado…',
					subtitle: 'Estamos verificando la configuración de este navegador.',
					color: 'neutral'
				};
			case 'ACTIVE':
				return {
					icon: CircleCheckBig,
					title: 'Activadas en este dispositivo',
					subtitle: 'Este navegador puede recibir las alertas Web Push de tu cuenta.',
					color: 'positive'
				};
			case 'INACTIVE':
				return {
					icon: BellOff,
					title: 'Desactivadas en este dispositivo',
					subtitle:
						'Puedes seguir viendo los episodios dentro de Senda, pero no recibirás avisos con la PWA cerrada.',
					color: 'warning'
				};
			case 'BLOCKED':
				return {
					icon: ShieldAlert,
					title: 'Bloqueadas por el navegador',
					subtitle:
						'Habilita las notificaciones para este sitio desde la configuración del navegador y vuelve a comprobarlas.',
					color: 'warning'
				};
			case 'UNSUPPORTED':
				return {
					icon: CircleAlert,
					title: 'No disponibles en este navegador',
					subtitle: status.detail ?? 'Este navegador no admite notificaciones Web Push.',
					color: 'neutral'
				};
			case 'UNCONFIGURED':
				return {
					icon: Wrench,
					title: 'Configuración pendiente',
					subtitle: status.detail ?? 'Falta completar la configuración de Web Push.',
					color: 'warning'
				};
			case 'ERROR':
				return {
					icon: CircleAlert,
					title: 'No pudimos comprobarlas',
					subtitle: status.detail ?? 'Inténtalo nuevamente en unos minutos.',
					color: 'danger'
				};
		}
	});

	onMount(() => {
		void refreshStatus();
	});

	async function refreshStatus() {
		status = { state: 'CHECKING' };
		status = await readPushNotificationStatus();
	}

	async function enable() {
		action = 'ENABLE';
		feedback = '';

		try {
			await enablePushNotifications();
			status = await readPushNotificationStatus();
			feedback =
				status.state === 'ACTIVE'
					? 'Notificaciones activadas en este dispositivo.'
					: status.detail || 'No pudimos confirmar que las notificaciones estén activas.';
		} catch (error) {
			if (error instanceof PushNotificationSessionError) {
				feedback = error.message;
				await goto(resolve('/auth/login?next=%2Fsettings'));
				return;
			}

			status = await readPushNotificationStatus();
			feedback = error instanceof Error ? error.message : 'No pudimos activar las notificaciones.';
		} finally {
			action = null;
		}
	}

	async function disable() {
		action = 'DISABLE';
		feedback = '';

		try {
			await disablePushNotifications();
			status = await readPushNotificationStatus();
			feedback = 'Notificaciones desactivadas en este dispositivo.';
		} catch (error) {
			status = await readPushNotificationStatus();
			feedback =
				error instanceof Error ? error.message : 'No pudimos desactivar las notificaciones.';
		} finally {
			action = null;
		}
	}
</script>

<article class="overflow-hidden rounded-2xl bg-white shadow-sm">
	<div class="p-6">
		<Heading
			icon={BellRing}
			title="Alertas en este dispositivo"
			subtitle="Recibe un aviso cuando se confirme que un paciente salió de una zona segura."
		/>

		<div class="mt-6">
			<Alert
				icon={statusPresentation.icon}
				title={statusPresentation.title}
				subtitle={statusPresentation.subtitle}
				color={statusPresentation.color}
			/>
		</div>

		{#if feedback}
			<p class="mt-4 text-sm leading-6 font-semibold text-ink">
				{feedback}
			</p>
		{/if}

		<p class="mt-5 text-sm leading-6 text-muted">
			La configuración se aplica solo a este navegador. Puedes activarla también en tus otros
			dispositivos.
		</p>
	</div>

	{#if status.state === 'ACTIVE' || status.state === 'INACTIVE' || status.state === 'BLOCKED' || status.state === 'ERROR'}
		<div class="border-t border-ink/10 p-4">
			{#if status.state === 'ACTIVE'}
				<button
					type="button"
					disabled={isBusy}
					onclick={disable}
					class="min-h-12 cursor-pointer rounded-full px-6 font-bold text-brand transition hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
				>
					{action === 'DISABLE' ? 'Desactivando…' : 'Desactivar notificaciones'}
				</button>
			{:else if status.state === 'INACTIVE'}
				<button
					type="button"
					disabled={isBusy}
					onclick={enable}
					class="min-h-12 cursor-pointer rounded-full bg-brand px-6 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
				>
					{action === 'ENABLE' ? 'Activando…' : 'Activar notificaciones'}
				</button>
			{:else}
				<button
					type="button"
					disabled={isBusy}
					onclick={refreshStatus}
					class="min-h-12 cursor-pointer rounded-full px-6 font-bold text-brand transition hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
				>
					Comprobar nuevamente
				</button>
			{/if}
		</div>
	{/if}
</article>
