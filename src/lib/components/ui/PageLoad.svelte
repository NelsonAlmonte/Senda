<script lang="ts">
	import { onNavigate } from '$app/navigation';
	import { onMount } from 'svelte';
	import { cubicOut } from 'svelte/easing';
	import { on } from 'svelte/events';
	import { prefersReducedMotion, Tween } from 'svelte/motion';
	import { fade } from 'svelte/transition';

	const MINIMUM_VISIBLE_MS = 300;
	const LINK_INTENT_TIMEOUT_MS = 1200;
	const INITIAL_PROGRESS = 0.08;
	const progress = new Tween(0, {
		duration: 1600,
		easing: cubicOut
	});

	let isVisible = $state(false);
	let navigationSequence = 0;
	let navigationInProgress = false;
	let startedAt: number | null = null;
	let linkIntentSequence = 0;

	onMount(() =>
		on(document, 'pointerdown', handleLinkIntent, {
			capture: true,
			passive: true
		})
	);

	onNavigate(() => {
		const currentSequence = ++navigationSequence;
		navigationInProgress = true;
		linkIntentSequence += 1;
		const navigationStartedAt = showProgress();

		return () => {
			void completeNavigation(currentSequence, navigationStartedAt);
		};
	});

	function handleLinkIntent(event: PointerEvent) {
		if (!isInternalNavigationLink(event)) return;

		const currentIntent = ++linkIntentSequence;
		showProgress();

		window.setTimeout(() => {
			if (currentIntent !== linkIntentSequence || navigationInProgress) return;
			isVisible = false;
			startedAt = null;
		}, LINK_INTENT_TIMEOUT_MS);
	}

	function isInternalNavigationLink(event: PointerEvent): boolean {
		if (
			event.button !== 0 ||
			event.altKey ||
			event.ctrlKey ||
			event.metaKey ||
			event.shiftKey ||
			!(event.target instanceof Element)
		) {
			return false;
		}

		const link = event.target.closest<HTMLAnchorElement>('a[href]');
		if (!link || link.hasAttribute('download') || (link.target && link.target !== '_self')) {
			return false;
		}

		const destination = new URL(link.href, window.location.href);
		if (destination.origin !== window.location.origin) return false;

		return !(
			destination.pathname === window.location.pathname &&
			destination.search === window.location.search
		);
	}

	function showProgress(): number {
		if (isVisible && startedAt !== null) return startedAt;

		startedAt = performance.now();
		void progress.set(INITIAL_PROGRESS, { duration: 0 });
		isVisible = true;
		void progress.set(0.75, {
			duration: prefersReducedMotion.current ? 0 : 1600
		});

		return startedAt;
	}

	async function completeNavigation(sequence: number, navigationStartedAt: number) {
		if (sequence !== navigationSequence) return;

		const remainingTime = MINIMUM_VISIBLE_MS - (performance.now() - navigationStartedAt);

		if (remainingTime > 0) {
			await new Promise((resolve) => setTimeout(resolve, remainingTime));
		}

		if (sequence !== navigationSequence) return;

		await progress.set(1, {
			duration: prefersReducedMotion.current ? 0 : 160
		});

		if (sequence === navigationSequence) {
			isVisible = false;
			navigationInProgress = false;
			startedAt = null;
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
			style:transform={`scaleX(${Math.max(progress.current, INITIAL_PROGRESS)})`}
		></div>
	</div>
{/if}
