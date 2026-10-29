<script lang="ts">
	import type { Component } from 'svelte';

	type IconComponent = Component<{
		'aria-hidden'?: boolean | 'true' | 'false';
		size?: number;
		strokeWidth?: number;
	}>;

	interface Props {
		icon: IconComponent;
		title: string;
		subtitle: string;
	}

	let { icon: Icon, title, subtitle }: Props = $props();
</script>

<div class="flex items-start gap-4">
	<div
		class="flex size-12 shrink-0 items-center justify-center rounded-full bg-surface-muted text-ink"
	>
		<Icon aria-hidden="true" size={22} strokeWidth={2} />
	</div>
	<div class="min-w-0">
		<h3 class="text-xl font-bold text-ink">{title}</h3>
		<p class="mt-1 max-w-2xl leading-6 text-muted">{subtitle}</p>
	</div>
</div>
