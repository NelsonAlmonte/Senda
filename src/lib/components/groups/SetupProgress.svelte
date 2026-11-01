<script lang="ts">
	import Check from '@lucide/svelte/icons/check';
	import Smartphone from '@lucide/svelte/icons/smartphone';
	import UsersRound from '@lucide/svelte/icons/users-round';
	import InfoItem from '#lib/components/ui/InfoItem.svelte';

	interface Props {
		currentStep: number;
	}

	let { currentStep }: Props = $props();

	const steps = [
		{ number: 1, label: 'Grupo', description: 'Elige el contexto de cuidado.' },
		{ number: 2, label: 'Paciente', description: 'Registra sus datos básicos.' },
		{ number: 3, label: 'Dispositivo', description: 'Configúralo ahora o después.' }
	];
</script>

<aside class="rounded-2xl bg-white p-6 shadow-sm xl:col-span-4">
	<div class="flex items-center gap-3">
		<div
			class="flex size-11 shrink-0 items-center justify-center rounded-full bg-surface-muted text-brand"
		>
			<UsersRound aria-hidden="true" size={22} strokeWidth={2} />
		</div>
		<div>
			<p class="text-sm font-bold text-muted">Registro guiado</p>
			<h2 class="text-lg font-bold text-ink">Tu progreso</h2>
		</div>
	</div>

	<ol
		class="mt-6 grid grid-cols-3 gap-2 xl:grid-cols-1 xl:gap-3"
		aria-label="Progreso del registro"
	>
		{#each steps as item (item.number)}
			<li
				aria-current={currentStep === item.number ? 'step' : undefined}
				class={[
					'flex min-w-0 flex-col items-center gap-2 rounded-2xl px-2 py-3 text-center xl:flex-row xl:items-start xl:gap-3 xl:px-4 xl:text-left',
					currentStep === item.number
						? 'bg-surface-muted'
						: currentStep > item.number
							? 'bg-canvas'
							: 'bg-white'
				]}
			>
				<span
					class={[
						'flex size-9 shrink-0 items-center justify-center rounded-full text-sm font-bold',
						currentStep === item.number
							? 'bg-brand text-white'
							: currentStep > item.number
								? 'bg-white text-brand'
								: 'bg-canvas text-muted'
					]}
				>
					{#if currentStep > item.number}
						<Check aria-hidden="true" size={18} strokeWidth={2.5} />
					{:else}
						{item.number}
					{/if}
				</span>
				<span class="min-w-0">
					<span class="block text-sm font-bold text-ink">{item.label}</span>
					<span class="mt-1 hidden text-sm leading-5 text-muted xl:block">
						{item.description}
					</span>
				</span>
			</li>
		{/each}
	</ol>

	<div class="mt-6 border-t border-ink/10 pt-6">
		<InfoItem
			icon={Smartphone}
			title="Configuración flexible"
			info="El dispositivo puede configurarse ahora o más adelante desde el paciente."
		/>
	</div>
</aside>
