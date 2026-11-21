<script lang="ts">
	import CircleCheckBig from '@lucide/svelte/icons/circle-check-big';
	import LoaderCircle from '@lucide/svelte/icons/loader-circle';
	import { prefersReducedMotion } from 'svelte/motion';
	import { fade, scale } from 'svelte/transition';

	interface Props {
		/** Hay un envío en curso. */
		active: boolean;
		/** El servidor aceptó el envío y falta terminar la navegación. */
		succeeded?: boolean;
		/** Qué se está haciendo, p. ej. «Creando tu cuenta…». */
		message: string;
		/** Qué se dice al terminar, p. ej. «¡Cuenta creada!». */
		successMessage: string;
	}

	let { active, succeeded = false, message, successMessage }: Props = $props();

	// Los mensajes cambian según el tiempo real transcurrido; no simulan pasos que no existen.
	let stage = $state(0);

	$effect(() => {
		if (!active || succeeded) {
			stage = 0;
			return;
		}

		const slow = setTimeout(() => (stage = 1), 3_000);
		const verySlow = setTimeout(() => (stage = 2), 9_000);

		return () => {
			clearTimeout(slow);
			clearTimeout(verySlow);
		};
	});

	let text = $derived(
		succeeded
			? successMessage
			: stage === 0
				? message
				: stage === 1
					? 'Esto está tardando más de lo normal…'
					: 'Seguimos intentándolo. Si no avanza, revisa tu conexión.'
	);
	let duration = $derived(prefersReducedMotion.current ? 0 : 200);
</script>

{#if active}
	<div
		class="absolute inset-0 z-10 grid place-items-center rounded-2xl bg-white/90 p-6 text-center backdrop-blur-[2px]"
		role="status"
		aria-live="polite"
		transition:fade={{ duration }}
	>
		<div class="max-w-xs">
			{#if succeeded}
				<div
					class="mx-auto grid size-14 place-items-center rounded-full bg-surface-muted text-brand"
					in:scale={{ start: 0.6, duration: prefersReducedMotion.current ? 0 : 280 }}
				>
					<CircleCheckBig aria-hidden="true" size={30} strokeWidth={2} />
				</div>
			{:else}
				<div
					class="mx-auto grid size-14 place-items-center rounded-full bg-surface-muted text-brand"
				>
					<LoaderCircle
						aria-hidden="true"
						size={30}
						strokeWidth={2.25}
						class="animate-spin motion-reduce:animate-none"
					/>
				</div>
			{/if}
			<p class="mt-4 font-bold text-ink">{text}</p>
			{#if !succeeded && stage === 0}
				<p class="mt-1 text-sm leading-6 text-muted">Un momento, por favor.</p>
			{/if}
		</div>
	</div>
{/if}
