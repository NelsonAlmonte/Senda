<script lang="ts">
	import Eye from '@lucide/svelte/icons/eye';
	import EyeOff from '@lucide/svelte/icons/eye-off';

	interface Props {
		id: string;
		name: string;
		label: string;
		autocomplete: 'current-password' | 'new-password';
		error?: string;
		help?: string;
		minlength?: number;
	}

	let { id, name, label, autocomplete, error, help, minlength }: Props = $props();
	let visible = $state(false);
	let helpId = $derived(help ? `${id}-help` : undefined);
	let errorId = $derived(error ? `${id}-error` : undefined);
	let describedBy = $derived([helpId, errorId].filter(Boolean).join(' ') || undefined);
</script>

<div>
	<label for={id} class="text-sm font-bold text-ink">{label}</label>
	{#if help}<p id={helpId} class="mt-1 text-sm leading-6 text-muted">{help}</p>{/if}
	<div class="relative mt-2">
		<input
			{id}
			{name}
			type={visible ? 'text' : 'password'}
			{autocomplete}
			{minlength}
			required
			spellcheck="false"
			aria-invalid={error ? 'true' : undefined}
			aria-describedby={describedBy}
			class="min-h-12 w-full rounded-xl border border-ink/20 bg-white px-4 pe-14 text-base text-ink transition outline-none focus:border-focus focus:ring-4 focus:ring-focus/20"
		/>
		<button
			type="button"
			onclick={() => (visible = !visible)}
			aria-label={visible ? `Ocultar ${label.toLowerCase()}` : `Mostrar ${label.toLowerCase()}`}
			aria-pressed={visible}
			class="absolute inset-y-0 right-1 my-auto grid size-10 cursor-pointer place-items-center rounded-full text-muted transition hover:bg-surface-muted hover:text-ink focus:ring-4 focus:ring-focus/30 focus:outline-none"
		>
			{#if visible}
				<EyeOff aria-hidden="true" size={20} strokeWidth={2} />
			{:else}
				<Eye aria-hidden="true" size={20} strokeWidth={2} />
			{/if}
		</button>
	</div>
	{#if error}<p id={errorId} class="mt-2 text-sm font-semibold text-red-800">{error}</p>{/if}
</div>
