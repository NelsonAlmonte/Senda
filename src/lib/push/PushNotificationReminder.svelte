<script lang="ts">
	import { resolve } from '$app/paths';
	import { onMount } from 'svelte';
	import { readPushNotificationStatus, type PushNotificationStatus } from './subscriptions.js';

	const DISMISSED_KEY = 'senda:push-reminder-dismissed';

	let status = $state<PushNotificationStatus>({ state: 'CHECKING' });
	let dismissed = $state(true);
	let shouldShow = $derived(
		!dismissed && (status.state === 'INACTIVE' || status.state === 'BLOCKED')
	);

	onMount(() => {
		dismissed = sessionStorage.getItem(DISMISSED_KEY) === 'true';
		void readPushNotificationStatus().then((result) => {
			status = result;
		});
	});

	function dismiss() {
		sessionStorage.setItem(DISMISSED_KEY, 'true');
		dismissed = true;
	}
</script>

{#if shouldShow}
	<aside
		class="mt-7 max-w-2xl rounded-2xl border border-amber-700/25 bg-amber-50 p-4 text-amber-950"
		aria-labelledby="push-reminder-heading"
		role="status"
	>
		<h2 id="push-reminder-heading" class="font-bold">Notificaciones recomendadas</h2>
		<p class="mt-1 text-sm leading-6">
			Actívalas para recibir un aviso si se confirma que un paciente salió de una zona segura,
			incluso cuando Senda esté cerrada.
		</p>
		<div class="mt-3 flex flex-wrap gap-3">
			<a
				href={resolve('/settings')}
				class="inline-flex min-h-12 items-center rounded-xl font-bold underline decoration-2 underline-offset-4 focus:ring-4 focus:ring-focus/30 focus:outline-none"
			>
				Configurar notificaciones
			</a>
			<button
				type="button"
				onclick={dismiss}
				class="min-h-12 cursor-pointer rounded-xl px-3 font-bold focus:ring-4 focus:ring-focus/30 focus:outline-none"
			>
				Ocultar por ahora
			</button>
		</div>
	</aside>
{/if}
