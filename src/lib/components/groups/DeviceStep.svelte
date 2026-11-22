<script lang="ts">
	import { enhance, type SubmitFunction } from '$app/forms';
	import type { ResolvedPathname } from '$app/types';
	import CircleAlert from '@lucide/svelte/icons/circle-alert';
	import CircleCheckBig from '@lucide/svelte/icons/circle-check-big';
	import Clock3 from '@lucide/svelte/icons/clock-3';
	import Smartphone from '@lucide/svelte/icons/smartphone';
	import UsersRound from '@lucide/svelte/icons/users-round';
	import Alert from '#lib/components/ui/Alert.svelte';
	import InfoItem from '#lib/components/ui/InfoItem.svelte';
	import Initials from '#lib/components/ui/Initials.svelte';
	import type { SetupErrors, SetupPatient } from '#lib/types/groups.js';

	interface Props {
		patient: SetupPatient;
		serialNumber: string;
		errors: SetupErrors;
		submitting: boolean;
		enhanceDevice: SubmitFunction;
		deferHref: ResolvedPathname;
		finishHref: ResolvedPathname;
	}

	let {
		patient,
		serialNumber = $bindable(),
		errors,
		submitting,
		enhanceDevice,
		deferHref,
		finishHref
	}: Props = $props();
</script>

<div class="p-6">
	<div data-step-heading tabindex="-1" class="flex items-start gap-4 focus:outline-none">
		<div
			class="flex size-11 shrink-0 items-center justify-center rounded-full bg-surface-muted text-brand"
		>
			<Smartphone aria-hidden="true" size={22} strokeWidth={2} />
		</div>
		<div class="min-w-0">
			<p class="text-sm font-bold text-muted">Paso 3 de 3</p>
			<h2 class="mt-1 text-xl font-bold text-ink">Configura el dispositivo</h2>
			<p class="mt-2 leading-7 text-muted">
				Asigna el dispositivo que enviará la ubicación de este paciente.
			</p>
		</div>
	</div>

	<div class="mt-8 flex min-w-0 items-center gap-4">
		<Initials text={`${patient.firstName} ${patient.lastName}`} />
		<div class="min-w-0">
			<p class="text-sm font-bold text-muted">Paciente registrado</p>
			<p class="mt-1 text-xl font-bold wrap-break-word text-ink">
				{patient.firstName}
				{patient.lastName}
			</p>
			<p class="mt-1 text-sm text-muted">{patient.groupName}</p>
		</div>
	</div>

	<div class="mt-8">
		<Alert
			icon={CircleCheckBig}
			title="Paciente guardado"
			subtitle="Puedes configurar su dispositivo ahora o hacerlo más adelante desde su perfil."
			color="positive"
		/>
	</div>

	{#if patient.serialNumber}
		<div class="mt-6">
			<InfoItem
				icon={Smartphone}
				title="Dispositivo configurado"
				info={patient.serialNumber}
				tone="positive"
			/>
		</div>
	{:else}
		{#if Object.keys(errors).length > 0}
			<div
				data-form-error
				tabindex="-1"
				class="mt-6 rounded-2xl focus:ring-4 focus:ring-red-700/20 focus:outline-none"
			>
				<Alert
					icon={CircleAlert}
					title="Revisa el serial del dispositivo"
					subtitle={errors.form ?? errors.serialNumber ?? 'Corrige el serial para continuar.'}
					color="danger"
				/>
			</div>
		{/if}

		<form
			id="device-form"
			method="POST"
			action={`?step=device&patient=${encodeURIComponent(patient.id)}&/assignDevice`}
			use:enhance={enhanceDevice}
			aria-busy={submitting}
			class="mt-8"
		>
			<input type="hidden" name="patientId" value={patient.id} />
			<label for="serialNumber" class="text-sm font-bold text-ink">Serial del dispositivo</label>
			<input
				id="serialNumber"
				name="serialNumber"
				type="text"
				bind:value={serialNumber}
				autocomplete="off"
				spellcheck="false"
				minlength="8"
				maxlength="64"
				required
				placeholder="SENDA-DEMO-001"
				aria-invalid={errors.serialNumber ? 'true' : undefined}
				aria-describedby={errors.serialNumber ? 'serial-help serial-error' : 'serial-help'}
				class={[
					'mt-2 min-h-12 w-full rounded-xl border bg-white px-4 font-mono text-base text-ink uppercase transition outline-none placeholder:text-muted/60 focus:border-focus focus:ring-4 focus:ring-focus/20',
					errors.serialNumber ? 'border-red-700/60' : 'border-ink/20'
				]}
			/>
			<p id="serial-help" class="mt-2 text-sm leading-6 text-muted">
				Encontrarás el serial en la etiqueta del dispositivo.
			</p>
			{#if errors.serialNumber}
				<p id="serial-error" class="mt-2 text-sm font-semibold text-red-800">
					{errors.serialNumber}
				</p>
			{/if}
		</form>
	{/if}
</div>

<div class="flex flex-col gap-3 border-t border-ink/10 p-4 sm:flex-row sm:items-center">
	{#if patient.serialNumber}
		<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -->
		<a
			href={finishHref}
			class="inline-flex min-h-12 items-center justify-center gap-2 rounded-full bg-brand px-6 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none"
		>
			<UsersRound aria-hidden="true" size={19} strokeWidth={2} />
			Ir a pacientes
		</a>
	{:else}
		<button
			type="submit"
			form="device-form"
			disabled={submitting}
			class="inline-flex min-h-12 cursor-pointer items-center justify-center gap-2 rounded-full bg-brand px-6 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
		>
			<Smartphone aria-hidden="true" size={19} strokeWidth={2} />
			{submitting ? 'Configurando…' : 'Configurar dispositivo'}
		</button>
		<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -->
		<a
			href={deferHref}
			class="inline-flex min-h-12 items-center justify-center gap-2 rounded-full px-5 font-bold text-brand transition hover:bg-surface-muted focus:ring-4 focus:ring-focus/25 focus:outline-none"
		>
			<Clock3 aria-hidden="true" size={19} strokeWidth={2} />
			Configurar después
		</a>
	{/if}
</div>
