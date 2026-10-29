<script lang="ts">
	interface Props {
		text: string;
	}

	let { text }: Props = $props();
	let initials = $derived(
		text
			.trim()
			.split(/\s+/)
			.filter(Boolean)
			.slice(0, 2)
			.map((part) => part.charAt(0))
			.join('')
			.toUpperCase()
	);
</script>

<div
	class="flex size-12 shrink-0 items-center justify-center rounded-full bg-surface-muted text-lg font-bold text-ink"
	aria-hidden="true"
>
	{initials}
</div>
