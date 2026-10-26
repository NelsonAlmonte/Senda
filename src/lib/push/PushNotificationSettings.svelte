<script lang="ts">
	import { onMount } from 'svelte';
	import {
		disablePushNotifications,
		enablePushNotifications,
		readPushNotificationStatus,
		type PushNotificationStatus
	} from './subscriptions.js';

	let status = $state<PushNotificationStatus>({ state: 'CHECKING' });
	let action = $state<'ENABLE' | 'DISABLE' | null>(null);
	let feedback = $state('');

	let isBusy = $derived(status.state === 'CHECKING' || action !== null);

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

<section
	class="mt-6 rounded-3xl border border-white/80 bg-white p-6 shadow-xl shadow-brand/8 sm:p-8"
	aria-labelledby="push-notifications-heading"
>
	<p class="text-sm font-bold tracking-[0.14em] text-brand uppercase">Alertas</p>
	<h2 id="push-notifications-heading" class="mt-2 text-2xl font-bold text-ink">
		Notificaciones en este dispositivo
	</h2>
	<p class="mt-3 max-w-xl leading-7 text-muted">
		Son recomendables para enterarte cuando se confirme que un paciente salió de una zona segura,
		incluso si Senda está cerrada.
	</p>

	<div
		class="mt-6 rounded-2xl border border-ink/10 bg-canvas p-4"
		role="status"
		aria-live="polite"
		aria-atomic="true"
	>
		{#if status.state === 'CHECKING'}
			<p class="font-bold text-ink">Comprobando estado…</p>
		{:else if status.state === 'ACTIVE'}
			<p class="font-bold text-brand">Activadas en este dispositivo</p>
			<p class="mt-1 text-sm leading-6 text-muted">
				Este navegador está registrado para recibir las alertas Web Push de tu cuenta.
			</p>
		{:else if status.state === 'INACTIVE'}
			<p class="font-bold text-amber-950">Desactivadas en este dispositivo</p>
			<p class="mt-1 text-sm leading-6 text-muted">
				Puedes seguir viendo los episodios dentro de Senda, pero no recibirás avisos con la PWA
				cerrada.
			</p>
		{:else if status.state === 'BLOCKED'}
			<p class="font-bold text-amber-950">Bloqueadas por el navegador</p>
			<p class="mt-1 text-sm leading-6 text-muted">
				Habilita las notificaciones para este sitio desde la configuración del navegador y vuelve a
				comprobar el estado.
			</p>
		{:else if status.state === 'UNSUPPORTED'}
			<p class="font-bold text-ink">No disponibles en este navegador</p>
			<p class="mt-1 text-sm leading-6 text-muted">{status.detail}</p>
		{:else if status.state === 'UNCONFIGURED'}
			<p class="font-bold text-amber-950">Configuración pendiente</p>
			<p class="mt-1 text-sm leading-6 text-muted">{status.detail}</p>
		{:else}
			<p class="font-bold text-red-950">No pudimos comprobarlas</p>
			<p class="mt-1 text-sm leading-6 text-muted">{status.detail}</p>
		{/if}
	</div>

	{#if feedback}
		<p class="mt-4 text-sm leading-6 font-semibold text-ink" role="status" aria-live="polite">
			{feedback}
		</p>
	{/if}

	<div class="mt-5 flex flex-wrap gap-3">
		{#if status.state === 'ACTIVE'}
			<button
				type="button"
				disabled={isBusy}
				onclick={disable}
				class="min-h-12 cursor-pointer rounded-xl border border-ink/15 bg-white px-5 font-bold text-ink transition hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
			>
				{action === 'DISABLE' ? 'Desactivando…' : 'Desactivar notificaciones'}
			</button>
		{:else if status.state === 'INACTIVE'}
			<button
				type="button"
				disabled={isBusy}
				onclick={enable}
				class="min-h-12 cursor-pointer rounded-xl bg-brand px-5 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
			>
				{action === 'ENABLE' ? 'Activando…' : 'Activar notificaciones'}
			</button>
		{:else if status.state === 'BLOCKED' || status.state === 'ERROR'}
			<button
				type="button"
				disabled={isBusy}
				onclick={refreshStatus}
				class="min-h-12 cursor-pointer rounded-xl border border-ink/15 bg-white px-5 font-bold text-ink transition hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
			>
				Comprobar nuevamente
			</button>
		{/if}
	</div>

	<p class="mt-5 text-sm leading-6 text-muted">
		La configuración se aplica solo a este navegador. Puedes activarla también en tus otros
		dispositivos.
	</p>
</section>
