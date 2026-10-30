<script lang="ts">
	import type { UiIcon, UiTone } from '#lib/types/ui.js';

	const toneClasses = {
		neutral: {
			container: 'bg-canvas',
			icon: 'bg-white text-ink',
			title: 'text-muted',
			info: 'text-ink'
		},
		positive: {
			container: 'bg-surface-muted',
			icon: 'bg-white text-brand',
			title: 'text-muted',
			info: 'text-ink'
		},
		warning: {
			container: 'bg-amber-50',
			icon: 'bg-white text-amber-800',
			title: 'text-amber-900',
			info: 'text-amber-950'
		},
		danger: {
			container: 'bg-red-50',
			icon: 'bg-white text-red-800',
			title: 'text-red-900',
			info: 'text-red-950'
		}
	} as const;

	interface Props {
		icon: UiIcon;
		title: string;
		info: string;
		tone?: UiTone;
	}

	let { icon: Icon, title, info, tone = 'neutral' }: Props = $props();
	let colors = $derived(toneClasses[tone]);
</script>

<div class={['flex h-full items-start gap-3 rounded-2xl p-4', colors.container]}>
	<div class={['flex size-10 shrink-0 items-center justify-center rounded-full', colors.icon]}>
		<Icon aria-hidden="true" size={20} strokeWidth={2} />
	</div>
	<div class="min-w-0">
		<p class={['text-sm font-bold', colors.title]}>{title}</p>
		<p class={['text-sm leading-6 font-medium wrap-break-word', colors.info]}>{info}</p>
	</div>
</div>
