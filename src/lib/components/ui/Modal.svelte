<script lang="ts">
	import type { Snippet } from 'svelte';
	import type { Attachment } from 'svelte/attachments';
	import { X } from '@lucide/svelte';
	import type { UiIcon } from '#lib/types/ui.js';

	interface Props {
		id: string;
		open: boolean;
		title: string;
		subtitle?: string;
		icon?: UiIcon;
		children: Snippet;
		footer?: Snippet;
		onclose: () => void;
	}

	let { id, open, title, subtitle, icon: Icon, children, footer, onclose }: Props = $props();
	function manageDialog(isOpen: boolean): Attachment<HTMLDialogElement> {
		return (dialog) => {
			if (isOpen && !dialog.open) dialog.showModal();

			return () => {
				if (dialog.open) dialog.close();
			};
		};
	}

	function requestClose() {
		if (open) onclose();
	}

	function handleCancel(event: Event) {
		event.preventDefault();
		requestClose();
	}

	function handleBackdropClick(event: MouseEvent) {
		if (event.target === event.currentTarget) requestClose();
	}
</script>

<dialog
	{@attach manageDialog(open)}
	{id}
	aria-labelledby={`${id}-title`}
	aria-describedby={subtitle ? `${id}-subtitle` : undefined}
	oncancel={handleCancel}
	onclose={requestClose}
	onclick={handleBackdropClick}
	class="m-auto max-h-dvh w-11/12 max-w-xl overflow-hidden rounded-2xl border-0 bg-white p-0 text-ink shadow-sm backdrop:bg-ink/50"
>
	<div class="flex max-h-dvh flex-col">
		<header class="flex items-start gap-4 p-6">
			{#if Icon}
				<span
					class="flex size-12 shrink-0 items-center justify-center rounded-full bg-surface-muted text-ink"
				>
					<Icon aria-hidden="true" size={22} strokeWidth={2} />
				</span>
			{/if}

			<div class="min-w-0 flex-1">
				<h2 id={`${id}-title`} class="text-xl font-bold text-ink">{title}</h2>
				{#if subtitle}
					<p id={`${id}-subtitle`} class="mt-1 leading-6 text-muted">{subtitle}</p>
				{/if}
			</div>

			<button
				type="button"
				onclick={requestClose}
				aria-label={`Cerrar ${title.toLowerCase()}`}
				class="flex size-12 shrink-0 cursor-pointer items-center justify-center rounded-full text-ink transition hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none"
			>
				<X aria-hidden="true" size={21} strokeWidth={2} />
			</button>
		</header>

		<div class="overflow-y-auto px-6 pb-6">
			{@render children()}
		</div>

		{#if footer}
			<footer class="border-t border-ink/10 p-4">
				{@render footer()}
			</footer>
		{/if}
	</div>
</dialog>
