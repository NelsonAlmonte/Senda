<script lang="ts">
	import { afterNavigate, goto } from '$app/navigation';
	import { resolve } from '$app/paths';
	import { page } from '$app/state';
	import BellRing from '@lucide/svelte/icons/bell-ring';
	import CircleCheckBig from '@lucide/svelte/icons/circle-check-big';
	import LoaderCircle from '@lucide/svelte/icons/loader-circle';
	import Settings from '@lucide/svelte/icons/settings';
	import ShieldAlert from '@lucide/svelte/icons/shield-alert';
	import type { PushNotificationPromptState, PushNotificationStatus } from '#lib/types/push.js';
	import type { UiIcon } from '#lib/types/ui.js';
	import {
		enablePushNotifications,
		PushNotificationSessionError,
		readPushNotificationStatus
	} from '#lib/utils/push-subscriptions.js';

	interface Props {
		onstatechange?: (state: PushNotificationPromptState) => void;
		suppressed?: boolean;
	}

	interface PromptPresentation {
		icon: UiIcon;
		subtitle: string;
		title: string;
		tone: 'neutral' | 'positive' | 'warning';
	}

	let { onstatechange, suppressed = false }: Props = $props();
	let status = $state<PushNotificationStatus>({ state: 'CHECKING' });
	let action = $state<'ENABLE' | null>(null);
	let dismissed = $state(false);
	let confirmation = $state(false);
	let feedback = $state('');
	let checked = false;
	let refreshInProgress = false;

	let needsAttention = $derived(
		!dismissed &&
			(confirmation ||
				status.state === 'INACTIVE' ||
				status.state === 'BLOCKED' ||
				feedback.length > 0)
	);
	let isVisible = $derived(!suppressed && needsAttention);
	let presentation: PromptPresentation = $derived.by(() => {
		if (confirmation) {
			return {
				icon: CircleCheckBig,
				title: 'Notificaciones activadas',
				subtitle: 'Este dispositivo ya puede avisarte cuando se confirme una salida.',
				tone: 'positive'
			};
		}

		if (status.state === 'BLOCKED') {
			return {
				icon: ShieldAlert,
				title: 'Las notificaciones están bloqueadas',
				subtitle:
					'Senda no puede volver a pedir este permiso. Habilítalo desde los permisos del sitio y compruébalo en Perfil.',
				tone: 'warning'
			};
		}

		if (feedback) {
			return {
				icon: ShieldAlert,
				title: 'No pudimos activar las notificaciones',
				subtitle: feedback,
				tone: 'warning'
			};
		}

		return {
			icon: BellRing,
			title: 'Activa las alertas en este dispositivo',
			subtitle:
				'Recibe un aviso aunque Senda esté cerrada cuando se confirme que un paciente salió de una zona segura.',
			tone: 'neutral'
		};
	});

	afterNavigate(() => {
		if (!dismissed) void refreshStatus();
	});

	function publishState() {
		onstatechange?.({ checked, needsAttention });
	}

	async function refreshStatus() {
		if (refreshInProgress || action !== null) return;

		refreshInProgress = true;
		try {
			status = await readPushNotificationStatus();
			checked = true;
			if (status.state !== 'ACTIVE') confirmation = false;
			publishState();
		} finally {
			refreshInProgress = false;
		}
	}

	async function enable() {
		action = 'ENABLE';
		feedback = '';
		confirmation = false;

		try {
			await enablePushNotifications();
			status = await readPushNotificationStatus();
			checked = true;
			confirmation = status.state === 'ACTIVE';

			if (!confirmation) {
				feedback = status.detail ?? 'No pudimos confirmar que las notificaciones estén activas.';
			}
		} catch (error) {
			if (error instanceof PushNotificationSessionError) {
				await goto(resolve(`/auth/login?next=${encodeURIComponent(page.url.pathname)}`));
				return;
			}

			status = await readPushNotificationStatus();
			checked = true;
			feedback = error instanceof Error ? error.message : 'No pudimos activar las notificaciones.';
		} finally {
			action = null;
			publishState();
		}
	}

	function dismiss() {
		dismissed = true;
		confirmation = false;
		feedback = '';
		publishState();
	}

	function refreshWhenVisible() {
		if (!dismissed && document.visibilityState === 'visible') void refreshStatus();
	}
</script>

<svelte:document onvisibilitychange={refreshWhenVisible} />
<svelte:window onfocus={refreshWhenVisible} />

{#if isVisible}
	<aside
		class="fixed right-4 bottom-24 left-4 z-50 mx-auto max-w-xl rounded-2xl border border-brand/20 bg-white p-4 sm:right-6 sm:left-auto sm:w-112 lg:bottom-6"
		aria-labelledby="push-notification-prompt-title"
		aria-live={confirmation || feedback ? 'polite' : undefined}
	>
		<div class="flex items-start gap-3">
			<span
				class={[
					'grid size-11 shrink-0 place-items-center rounded-full',
					presentation.tone === 'positive' && 'bg-emerald-50 text-emerald-700',
					presentation.tone === 'warning' && 'bg-amber-50 text-amber-800',
					presentation.tone === 'neutral' && 'bg-surface-muted text-brand'
				]}
			>
				<presentation.icon aria-hidden="true" size={22} strokeWidth={2} />
			</span>
			<div class="min-w-0">
				<p id="push-notification-prompt-title" class="font-bold text-ink">
					{presentation.title}
				</p>
				<p class="mt-1 text-sm leading-6 text-muted">{presentation.subtitle}</p>
			</div>
		</div>

		<div class="mt-4 flex flex-wrap gap-3">
			{#if confirmation}
				<button
					type="button"
					onclick={dismiss}
					class="min-h-12 cursor-pointer rounded-xl bg-brand px-4 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none"
				>
					Entendido
				</button>
			{:else if status.state === 'BLOCKED'}
				<a
					href={resolve('/settings')}
					class="inline-flex min-h-12 items-center justify-center gap-2 rounded-xl bg-brand px-4 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none"
				>
					<Settings aria-hidden="true" size={19} strokeWidth={2} />
					Ver cómo activarlas
				</a>
				<button
					type="button"
					onclick={dismiss}
					class="min-h-12 cursor-pointer rounded-xl border border-ink/15 bg-white px-4 font-bold text-ink transition hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none"
				>
					Ahora no
				</button>
			{:else}
				<button
					type="button"
					onclick={enable}
					disabled={action !== null}
					class="inline-flex min-h-12 cursor-pointer items-center justify-center gap-2 rounded-xl bg-brand px-4 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none disabled:cursor-wait disabled:opacity-60"
				>
					{#if action === 'ENABLE'}
						<LoaderCircle class="animate-spin" aria-hidden="true" size={19} strokeWidth={2} />
						Activando…
					{:else}
						<BellRing aria-hidden="true" size={19} strokeWidth={2} />
						{feedback ? 'Intentar nuevamente' : 'Activar notificaciones'}
					{/if}
				</button>
				<button
					type="button"
					onclick={dismiss}
					class="min-h-12 cursor-pointer rounded-xl border border-ink/15 bg-white px-4 font-bold text-ink transition hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none"
				>
					Ahora no
				</button>
			{/if}
		</div>
	</aside>
{/if}
