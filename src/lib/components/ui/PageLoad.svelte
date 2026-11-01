<script lang="ts">
	import { onNavigate } from '$app/navigation';
	import { cubicOut } from 'svelte/easing';
	import { prefersReducedMotion, Tween } from 'svelte/motion';
	import { fade } from 'svelte/transition';

	const MINIMUM_VISIBLE_MS = 300;
	const progress = new Tween(0, {
		duration: 1600,
		easing: cubicOut
	});

	let isVisible = $state(false);
	let navigationSequence = 0;

	onNavigate(() => {
		const currentSequence = ++navigationSequence;
		const startedAt = performance.now();

		void progress.set(0, { duration: 0 });
		isVisible = true;
		void progress.set(0.75, {
			duration: prefersReducedMotion.current ? 0 : 1600
		});

		return () => {
			void completeNavigation(currentSequence, startedAt);
		};
	});

	async function completeNavigation(sequence: number, startedAt: number) {
		if (sequence !== navigationSequence) return;

		const remainingTime = MINIMUM_VISIBLE_MS - (performance.now() - startedAt);

		if (remainingTime > 0) {
			await new Promise((resolve) => setTimeout(resolve, remainingTime));
		}

		if (sequence !== navigationSequence) return;

		await progress.set(1, {
			duration: prefersReducedMotion.current ? 0 : 160
		});

		if (sequence === navigationSequence) {
			isVisible = false;
		}
	}
</script>

{#if isVisible}
	<div
		class="pointer-events-none fixed inset-x-0 top-0 z-50 h-1 overflow-hidden"
		aria-hidden="true"
		out:fade={{ duration: prefersReducedMotion.current ? 0 : 160 }}
	>
		<div
			class="h-full w-full origin-left bg-brand"
			style:transform={`scaleX(${progress.current})`}
		></div>
	</div>
{/if}
