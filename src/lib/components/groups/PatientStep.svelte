<script lang="ts">
	import { enhance, type SubmitFunction } from '$app/forms';
	import Building2 from '@lucide/svelte/icons/building-2';
	import CircleAlert from '@lucide/svelte/icons/circle-alert';
	import House from '@lucide/svelte/icons/house';
	import UserRound from '@lucide/svelte/icons/user-round';
	import Alert from '#lib/components/ui/Alert.svelte';
	import InfoItem from '#lib/components/ui/InfoItem.svelte';
	import type { GroupMode, GroupType, SetupErrors } from '#lib/types/groups.js';

	interface Props {
		groupMode: GroupMode;
		groupId: string;
		groupName: string;
		groupType: GroupType;
		selectedGroupName: string;
		selectedGroupType: GroupType;
		patientFirstName: string;
		patientLastName: string;
		errors: SetupErrors;
		errorSummary: string;
		submitting: boolean;
		enhanceCreate: SubmitFunction;
		onback: () => void;
	}

	let {
		groupMode,
		groupId,
		groupName,
		groupType,
		selectedGroupName,
		selectedGroupType,
		patientFirstName = $bindable(),
		patientLastName = $bindable(),
		errors,
		errorSummary,
		submitting,
		enhanceCreate,
		onback
	}: Props = $props();

	let selectedGroupIcon = $derived(selectedGroupType === 'CARE_CENTER' ? Building2 : House);
</script>

<form method="POST" action="?/createPatient" use:enhance={enhanceCreate} aria-busy={submitting}>
	<div class="p-6">
		<div data-step-heading tabindex="-1" class="flex items-start gap-4 focus:outline-none">
			<div
				class="flex size-11 shrink-0 items-center justify-center rounded-full bg-surface-muted text-brand"
			>
				<UserRound aria-hidden="true" size={22} strokeWidth={2} />
			</div>
			<div class="min-w-0">
				<p class="text-sm font-bold text-muted">Paso 2 de 3</p>
				<h2 class="mt-1 text-xl font-bold text-ink">Datos del paciente</h2>
				<p class="mt-2 leading-7 text-muted">
					Registra los datos básicos de la persona que utilizará el dispositivo.
				</p>
			</div>
		</div>

		<div class="mt-8">
			<InfoItem
				icon={selectedGroupIcon}
				title={selectedGroupType === 'CARE_CENTER' ? 'Centro seleccionado' : 'Familia seleccionada'}
				info={selectedGroupName || 'Nuevo grupo'}
				tone="positive"
			/>
		</div>

		{#if Object.keys(errors).length > 0}
			<div
				data-form-error
				tabindex="-1"
				class="mt-6 rounded-2xl focus:ring-4 focus:ring-red-700/20 focus:outline-none"
			>
				<Alert
					icon={CircleAlert}
					title="Revisa los datos del formulario"
					subtitle={errorSummary}
					color="danger"
				/>
			</div>
		{/if}

		<input type="hidden" name="groupMode" value={groupMode} />
		<input type="hidden" name="groupId" value={groupId} />
		<input type="hidden" name="groupName" value={groupName} />
		<input type="hidden" name="groupType" value={groupType} />

		<div class="mt-8 grid gap-5 sm:grid-cols-2">
			<div>
				<label for="patientFirstName" class="text-sm font-bold text-ink">Nombre</label>
				<input
					id="patientFirstName"
					name="patientFirstName"
					type="text"
					bind:value={patientFirstName}
					autocomplete="off"
					maxlength="80"
					required
					aria-invalid={errors.patientFirstName ? 'true' : undefined}
					aria-describedby={errors.patientFirstName ? 'patient-first-name-error' : undefined}
					class={[
						'mt-2 min-h-12 w-full rounded-xl border bg-white px-4 text-base text-ink transition outline-none focus:border-focus focus:ring-4 focus:ring-focus/20',
						errors.patientFirstName ? 'border-red-700/60' : 'border-ink/20'
					]}
				/>
				{#if errors.patientFirstName}
					<p id="patient-first-name-error" class="mt-2 text-sm font-semibold text-red-800">
						{errors.patientFirstName}
					</p>
				{/if}
			</div>
			<div>
				<label for="patientLastName" class="text-sm font-bold text-ink">Apellido</label>
				<input
					id="patientLastName"
					name="patientLastName"
					type="text"
					bind:value={patientLastName}
					autocomplete="off"
					maxlength="80"
					required
					aria-invalid={errors.patientLastName ? 'true' : undefined}
					aria-describedby={errors.patientLastName ? 'patient-last-name-error' : undefined}
					class={[
						'mt-2 min-h-12 w-full rounded-xl border bg-white px-4 text-base text-ink transition outline-none focus:border-focus focus:ring-4 focus:ring-focus/20',
						errors.patientLastName ? 'border-red-700/60' : 'border-ink/20'
					]}
				/>
				{#if errors.patientLastName}
					<p id="patient-last-name-error" class="mt-2 text-sm font-semibold text-red-800">
						{errors.patientLastName}
					</p>
				{/if}
			</div>
		</div>
	</div>

	<div class="flex flex-col-reverse gap-3 border-t border-ink/10 p-4 sm:flex-row sm:items-center">
		<button
			type="button"
			onclick={onback}
			class="min-h-12 cursor-pointer rounded-full px-5 font-bold text-brand transition hover:bg-surface-muted focus:ring-4 focus:ring-focus/25 focus:outline-none"
		>
			Volver al grupo
		</button>
		<button
			type="submit"
			disabled={submitting}
			class="min-h-12 cursor-pointer rounded-full bg-brand px-6 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
		>
			{submitting ? 'Guardando…' : 'Guardar paciente'}
		</button>
	</div>
</form>
