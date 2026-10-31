<script lang="ts">
	import { CircleCheckBig, Clock3, MapPinned, Siren } from '@lucide/svelte';
	import type { Snippet } from 'svelte';
	import InfoItem from '#lib/components/ui/InfoItem.svelte';
	import Initials from '#lib/components/ui/Initials.svelte';
	import { presentDateTime } from '#lib/locations/presentation.js';

	type AlertEpisodeStatus = 'OPEN' | 'RESOLVED';

	interface Props {
		status: AlertEpisodeStatus;
		confirmedAt: string;
		resolvedAt?: string | null;
		patientName?: string;
		actions?: Snippet;
	}

	let { status, confirmedAt, resolvedAt = null, patientName, actions }: Props = $props();

	let isOpen = $derived(status === 'OPEN');
	let resolvedEpisodeInfo = $derived.by(() => {
		const confirmed = `Confirmada el ${presentDateTime(confirmedAt)}.`;
		return resolvedAt ? `${confirmed} Resuelta el ${presentDateTime(resolvedAt)}.` : confirmed;
	});
</script>

<article class="flex h-full flex-col overflow-hidden rounded-2xl bg-white shadow-sm">
	<div class="flex-1 p-6">
		<div class="flex items-start gap-4">
			{#if patientName && !isOpen}
				<Initials text={patientName} />
			{:else}
				<div
					class={[
						'flex size-12 shrink-0 items-center justify-center rounded-full',
						isOpen ? 'bg-red-50 text-red-800' : 'bg-green-50 text-green-800'
					]}
				>
					{#if isOpen}
						<Siren aria-hidden="true" size={22} strokeWidth={2} />
					{:else}
						<CircleCheckBig aria-hidden="true" size={22} strokeWidth={2} />
					{/if}
				</div>
			{/if}

			<div class="min-w-0">
				{#if patientName}
					<h3 class="text-xl font-bold wrap-break-word text-ink">{patientName}</h3>
					<p class={['mt-1 text-sm leading-6', isOpen ? 'text-red-950' : 'text-muted']}>
						{isOpen ? 'Alerta activa' : 'Episodio finalizado'}
					</p>
				{:else}
					<h3 class="text-xl font-bold text-ink">
						{isOpen ? 'Alerta activa' : 'Episodio finalizado'}
					</h3>
				{/if}
			</div>
		</div>

		{#if isOpen}
			<div class="mt-6 grid gap-3 sm:grid-cols-2">
				<InfoItem
					icon={Clock3}
					title="Salida confirmada"
					info={presentDateTime(confirmedAt)}
					tone="danger"
				/>
				<InfoItem
					icon={MapPinned}
					title="Acción recomendada"
					info="Revisa la ubicación y el estado más reciente."
					tone="warning"
				/>
			</div>
		{:else}
			<div class="mt-6">
				<InfoItem
					icon={CircleCheckBig}
					title="Salida resuelta"
					info={resolvedEpisodeInfo}
					tone="positive"
				/>
			</div>
		{/if}
	</div>

	{#if actions}
		<div class="border-t border-ink/10 p-4">
			{@render actions()}
		</div>
	{/if}
</article>
