<script lang="ts">
	import { resolve } from '$app/paths';
	import PatientSetupWizard from '#lib/components/groups/PatientSetupWizard.svelte';
	import type { PatientSetupData } from '#lib/types/groups.js';
	import type { PageProps } from './$types';

	let { data, form }: PageProps = $props();
</script>

<svelte:head>
	<title>Registrar paciente y dispositivo | Senda</title>
	<meta
		name="description"
		content="Selecciona el grupo, registra al paciente y configura su dispositivo en tres pasos."
	/>
</svelte:head>

<main id="contenido-principal" class="px-5 py-8 sm:px-8 lg:px-0">
	<section class="w-full" aria-labelledby="groups-title">
		<h2 id="groups-title" class="mb-8 text-2xl font-bold text-ink">Nuevo paciente y dispositivo</h2>

		<PatientSetupWizard
			data={data as PatientSetupData}
			{form}
			deferHref={resolve('/patients?created=patient')}
			finishHref={resolve('/patients')}
		/>
	</section>
</main>
