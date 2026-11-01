<script lang="ts">
	import { resolve } from '$app/paths';
	import ArrowLeft from '@lucide/svelte/icons/arrow-left';
	import ArrowRight from '@lucide/svelte/icons/arrow-right';
	import Building2 from '@lucide/svelte/icons/building-2';
	import CircleCheckBig from '@lucide/svelte/icons/circle-check-big';
	import House from '@lucide/svelte/icons/house';
	import Smartphone from '@lucide/svelte/icons/smartphone';
	import PatientSetupWizard from '#lib/components/groups/PatientSetupWizard.svelte';
	import type { PatientSetupData } from '#lib/types/groups.js';
	import InfoItem from '#lib/components/ui/InfoItem.svelte';
	import Initials from '#lib/components/ui/Initials.svelte';
	import type { PageProps } from './$types';

	let { data, form }: PageProps = $props();
	let isComplete = $derived(Boolean(data.completion && data.onboardingPatient));
	let patientName = $derived(
		data.onboardingPatient
			? `${data.onboardingPatient.firstName} ${data.onboardingPatient.lastName}`.trim()
			: ''
	);
	let deferHref = $derived(
		data.onboardingPatient
			? resolve(
					`/onboarding/groups?completed=deferred&patient=${encodeURIComponent(data.onboardingPatient.id)}`
				)
			: resolve('/onboarding/groups')
	);
</script>

<svelte:head>
	<title>Configurar Senda | Primeros pasos</title>
	<meta
		name="description"
		content="Crea el espacio de cuidado, registra al paciente y configura su dispositivo Senda."
	/>
</svelte:head>

<main id="contenido-principal" class="min-h-dvh px-5 py-8 sm:px-8 sm:py-12">
	<div class="mx-auto w-full max-w-6xl">
		<header class="mx-auto max-w-3xl text-center">
			<div class="inline-flex items-center gap-3">
				<span
					class="grid size-11 place-items-center rounded-xl bg-ink text-lg font-bold text-white"
					aria-hidden="true">S</span
				>
				<span class="text-2xl font-bold text-ink">Senda</span>
			</div>

			<p class="mt-8 text-sm font-bold tracking-wide text-brand uppercase">
				Primeros pasos · Configura Senda
			</p>
			<h1 class="mx-auto mt-3 max-w-3xl text-3xl font-bold text-balance text-ink sm:text-4xl">
				{isComplete
					? data.completion === 'configured'
						? 'Senda está lista para comenzar'
						: 'El registro quedó preparado'
					: 'Preparemos Senda'}
			</h1>
			<p class="mx-auto mt-5 max-w-2xl text-lg leading-8 text-muted">
				{isComplete
					? data.completion === 'configured'
						? 'El paciente y su dispositivo quedaron vinculados. Ya puedes entrar para comenzar a configurar su monitoreo.'
						: 'El paciente quedó guardado. Podrás configurar su dispositivo cuando estés listo desde la sección Pacientes.'
					: 'Te acompañaremos para crear su espacio de cuidado, registrar sus datos y decidir si configuras el dispositivo ahora o después.'}
			</p>
		</header>

		{#if isComplete && data.onboardingPatient}
			<section class="mx-auto mt-10 max-w-2xl" aria-labelledby="setup-success-title">
				<article class="overflow-hidden rounded-2xl bg-white shadow-sm">
					<div class="p-6 text-center sm:p-8">
						<div
							class="mx-auto flex size-14 items-center justify-center rounded-full bg-surface-muted text-brand"
						>
							<CircleCheckBig aria-hidden="true" size={28} strokeWidth={2} />
						</div>
						<h2
							id="setup-success-title"
							tabindex="-1"
							class="mt-6 text-2xl font-bold text-ink focus:outline-none"
						>
							{data.completion === 'configured'
								? 'Configuración completada'
								: 'Paciente registrado'}
						</h2>

						<div class="mt-8 flex min-w-0 items-center justify-center gap-4 text-left">
							<Initials text={patientName} />
							<div class="min-w-0">
								<p class="text-sm font-bold text-muted">Paciente</p>
								<p class="mt-1 text-xl font-bold wrap-break-word text-ink">{patientName}</p>
							</div>
						</div>

						<div class="mt-8 grid gap-4 text-left sm:grid-cols-2">
							<InfoItem
								icon={data.onboardingPatient.groupType === 'CARE_CENTER' ? Building2 : House}
								title={data.onboardingPatient.groupType === 'CARE_CENTER' ? 'Centro' : 'Familia'}
								info={data.onboardingPatient.groupName}
							/>
							<InfoItem
								icon={Smartphone}
								title="Dispositivo"
								info={data.completion === 'configured'
									? 'Configurado y asignado'
									: 'Pendiente de configuración'}
								tone={data.completion === 'configured' ? 'positive' : 'neutral'}
							/>
						</div>
					</div>

					<div class="border-t border-ink/10 p-4">
						<a
							href={resolve('/patients')}
							class="inline-flex min-h-12 w-full items-center justify-center gap-2 rounded-full bg-brand px-6 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none sm:w-auto"
						>
							Ver mis pacientes
							<ArrowRight aria-hidden="true" size={19} strokeWidth={2} />
						</a>
					</div>
				</article>
			</section>
		{:else}
			<section class="mt-10" aria-label="Configuración inicial de Senda">
				<PatientSetupWizard
					data={data as PatientSetupData}
					{form}
					{deferHref}
					finishHref={resolve('/patients')}
				/>
			</section>

			<div class="mt-6 flex justify-center">
				<a
					href={resolve('/onboarding')}
					class="inline-flex min-h-12 items-center gap-2 rounded-full px-4 font-bold text-brand transition hover:bg-white focus:ring-4 focus:ring-focus/25 focus:outline-none"
				>
					<ArrowLeft aria-hidden="true" size={19} strokeWidth={2} />
					Volver a las opciones
				</a>
			</div>
		{/if}
	</div>
</main>
