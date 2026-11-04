<script lang="ts">
	import { asset } from '$app/paths';
	import type { ClassValue } from 'svelte/elements';

	interface Props {
		alt?: string;
		class?: ClassValue;
	}

	let { alt = '', class: className }: Props = $props();
</script>

<img
	src={asset('pwa-192x192.png')}
	{alt}
	width="192"
	height="192"
	decoding="async"
	class={['shrink-0 object-contain', className]}
/>
