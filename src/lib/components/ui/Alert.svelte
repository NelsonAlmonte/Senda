<script lang="ts">
	import type { UiIcon, UiTone } from '#lib/types/ui.js';

	const colorClasses = {
		neutral: {
			container: 'bg-canvas',
			icon: 'bg-white text-ink',
			title: 'text-ink',
			subtitle: 'text-muted'
		},
		positive: {
			container: 'bg-surface-muted',
			icon: 'bg-white text-brand',
			title: 'text-ink',
			subtitle: 'text-muted'
		},
		warning: {
			container: 'bg-amber-50',
			icon: 'bg-white text-amber-800',
			title: 'text-amber-950',
			subtitle: 'text-amber-900'
		},
		danger: {
			container: 'bg-red-50',
			icon: 'bg-white text-red-800',
			title: 'text-red-950',
			subtitle: 'text-red-900'
		}
	} as const;

	interface Props {
		title: string;
		subtitle: string;
		icon: UiIcon;
		color?: UiTone;
	}

	let { title, subtitle, icon: Icon, color = 'neutral' }: Props = $props();
	let colors = $derived(colorClasses[color]);
	let role = $derived(color === 'warning' || color === 'danger' ? 'alert' : 'status');
</script>

<div class={['flex items-start gap-3 rounded-2xl p-4', colors.container]} {role} aria-atomic="true">
	<div class={['flex size-10 shrink-0 items-center justify-center rounded-full', colors.icon]}>
		<Icon aria-hidden="true" size={20} strokeWidth={2} />
	</div>
	<div class="min-w-0">
		<p class={['font-bold wrap-break-word', colors.title]}>{title}</p>
		<p class={['mt-1 text-sm leading-6 wrap-break-word', colors.subtitle]}>{subtitle}</p>
	</div>
</div>
