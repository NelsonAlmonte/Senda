<script lang="ts">
	import Building2 from '@lucide/svelte/icons/building-2';
	import CircleAlert from '@lucide/svelte/icons/circle-alert';
	import House from '@lucide/svelte/icons/house';
	import UsersRound from '@lucide/svelte/icons/users-round';
	import Alert from '#lib/components/ui/Alert.svelte';
	import type { GroupMode, GroupOption, GroupType } from '#lib/types/groups.js';

	interface Props {
		groups: GroupOption[];
		groupsAvailable: boolean;
		groupMode: GroupMode;
		groupId: string;
		groupName: string;
		groupType: GroupType;
		stepError: string;
		oncontinue: () => void;
	}

	let {
		groups,
		groupsAvailable,
		groupMode = $bindable(),
		groupId = $bindable(),
		groupName = $bindable(),
		groupType = $bindable(),
		stepError,
		oncontinue
	}: Props = $props();

	let hasOwnedGroups = $derived(groups.length > 0);
</script>

<div class="p-6">
	<div data-step-heading tabindex="-1" class="flex items-start gap-4 focus:outline-none">
		<div
			class="flex size-11 shrink-0 items-center justify-center rounded-full bg-surface-muted text-brand"
		>
			<UsersRound aria-hidden="true" size={22} strokeWidth={2} />
		</div>
		<div class="min-w-0">
			<p class="text-sm font-bold text-muted">Paso 1 de 3</p>
			<h2 class="mt-1 text-xl font-bold text-ink">Elige el grupo</h2>
			<p class="mt-2 leading-7 text-muted">
				Usa una familia o centro que ya administras, o crea uno para este paciente.
			</p>
		</div>
	</div>

	{#if !groupsAvailable}
		<div class="mt-6">
			<Alert
				icon={CircleAlert}
				title="No pudimos consultar tus grupos"
				subtitle="Inténtalo nuevamente antes de continuar."
				color="warning"
			/>
		</div>
	{/if}

	<fieldset class="mt-8">
		<legend class="text-sm font-bold text-ink">¿Dónde recibirá cuidado?</legend>
		<div class="mt-3 grid gap-3 sm:grid-cols-2">
			{#if hasOwnedGroups}
				<label
					class="flex min-h-28 cursor-pointer gap-3 rounded-2xl border border-ink/15 bg-canvas p-4 transition has-checked:border-brand has-checked:bg-surface-muted has-checked:ring-2 has-checked:ring-brand/20"
				>
					<input
						type="radio"
						bind:group={groupMode}
						value="existing"
						class="mt-1 size-5 shrink-0 accent-brand"
					/>
					<span>
						<span class="block font-bold text-ink">Grupo existente</span>
						<span class="mt-1 block text-sm leading-6 text-muted">
							Añade al paciente a una familia o centro que ya administras.
						</span>
					</span>
				</label>
			{/if}
			<label
				class="flex min-h-28 cursor-pointer gap-3 rounded-2xl border border-ink/15 bg-canvas p-4 transition has-checked:border-brand has-checked:bg-surface-muted has-checked:ring-2 has-checked:ring-brand/20"
			>
				<input
					type="radio"
					bind:group={groupMode}
					value="new"
					class="mt-1 size-5 shrink-0 accent-brand"
				/>
				<span>
					<span class="block font-bold text-ink">Grupo nuevo</span>
					<span class="mt-1 block text-sm leading-6 text-muted">
						Crea una familia o centro junto con su primer paciente.
					</span>
				</span>
			</label>
		</div>
	</fieldset>

	{#if groupMode === 'existing'}
		<fieldset class="mt-8">
			<legend class="text-sm font-bold text-ink">Selecciona un grupo</legend>
			<div class="mt-3 grid gap-3 sm:grid-cols-2">
				{#each groups as group (group.id)}
					<label
						class="flex min-h-24 cursor-pointer items-start gap-3 rounded-2xl border border-ink/15 bg-white p-4 transition has-checked:border-brand has-checked:bg-surface-muted has-checked:ring-2 has-checked:ring-brand/20"
					>
						<input
							type="radio"
							bind:group={groupId}
							value={group.id}
							class="mt-2 size-5 shrink-0 accent-brand"
						/>
						<span class="flex min-w-0 items-start gap-3">
							<span
								class="flex size-10 shrink-0 items-center justify-center rounded-full bg-canvas text-brand"
							>
								{#if group.type === 'FAMILY'}
									<House aria-hidden="true" size={20} strokeWidth={2} />
								{:else}
									<Building2 aria-hidden="true" size={20} strokeWidth={2} />
								{/if}
							</span>
							<span class="min-w-0">
								<span class="block font-bold wrap-break-word text-ink">{group.name}</span>
								<span class="mt-1 block text-sm text-muted">
									{group.type === 'FAMILY' ? 'Familia' : 'Centro de cuidado'}
								</span>
							</span>
						</span>
					</label>
				{/each}
			</div>
		</fieldset>
	{:else}
		<div class="mt-8 grid gap-6">
			<div>
				<label for="groupName" class="text-sm font-bold text-ink">Nombre del grupo</label>
				<input
					id="groupName"
					type="text"
					bind:value={groupName}
					autocomplete="organization"
					maxlength="120"
					aria-describedby="group-name-help"
					placeholder="Ej. Familia Pérez"
					class="mt-2 min-h-12 w-full rounded-xl border border-ink/20 bg-white px-4 text-base text-ink transition outline-none placeholder:text-muted/60 focus:border-focus focus:ring-4 focus:ring-focus/20"
				/>
				<p id="group-name-help" class="mt-2 text-sm leading-6 text-muted">
					Usa un nombre que puedas reconocer fácilmente.
				</p>
			</div>
			<fieldset>
				<legend class="text-sm font-bold text-ink">Tipo de grupo</legend>
				<div class="mt-3 grid gap-3 sm:grid-cols-2">
					<label
						class="flex min-h-24 cursor-pointer gap-3 rounded-2xl border border-ink/15 bg-canvas p-4 transition has-checked:border-brand has-checked:bg-surface-muted has-checked:ring-2 has-checked:ring-brand/20"
					>
						<input
							type="radio"
							bind:group={groupType}
							value="FAMILY"
							class="mt-1 size-5 shrink-0 accent-brand"
						/>
						<span>
							<span class="block font-bold text-ink">Familia</span>
							<span class="mt-1 block text-sm leading-6 text-muted">
								Para el cuidado dentro del entorno familiar.
							</span>
						</span>
					</label>
					<label
						class="flex min-h-24 cursor-pointer gap-3 rounded-2xl border border-ink/15 bg-canvas p-4 transition has-checked:border-brand has-checked:bg-surface-muted has-checked:ring-2 has-checked:ring-brand/20"
					>
						<input
							type="radio"
							bind:group={groupType}
							value="CARE_CENTER"
							class="mt-1 size-5 shrink-0 accent-brand"
						/>
						<span>
							<span class="block font-bold text-ink">Centro de cuidado</span>
							<span class="mt-1 block text-sm leading-6 text-muted">
								Para organizar pacientes de un centro.
							</span>
						</span>
					</label>
				</div>
			</fieldset>
		</div>
	{/if}

	{#if stepError}
		<div class="mt-6">
			<Alert icon={CircleAlert} title="Falta información" subtitle={stepError} color="danger" />
		</div>
	{/if}
</div>

<div class="border-t border-ink/10 p-4">
	<button
		type="button"
		onclick={oncontinue}
		disabled={!groupsAvailable}
		class="min-h-12 w-full cursor-pointer rounded-full bg-brand px-6 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50 sm:w-auto"
	>
		Continuar con el paciente
	</button>
</div>
