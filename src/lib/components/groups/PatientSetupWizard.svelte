<script lang="ts">
	import type { SubmitFunction } from '$app/forms';
	import type { ResolvedPathname } from '$app/types';
	import DeviceStep from './DeviceStep.svelte';
	import GroupStep from './GroupStep.svelte';
	import PatientStep from './PatientStep.svelte';
	import SetupProgress from './SetupProgress.svelte';
	import type {
		GroupMode,
		GroupType,
		PatientSetupData,
		PatientSetupFormState,
		SetupErrors,
		SetupFormValues
	} from '#lib/types/groups.js';

	interface Props {
		data: PatientSetupData;
		form?: unknown;
		deferHref: ResolvedPathname;
		finishHref: ResolvedPathname;
	}

	let { data, form, deferHref, finishHref }: Props = $props();

	function readFormState(value: unknown): PatientSetupFormState {
		return value && typeof value === 'object' ? (value as PatientSetupFormState) : {};
	}

	function getInitialState() {
		const formState = readFormState(form);
		const submittedValues = formState.values ?? ({} as SetupFormValues);
		const hasGroups = data.groups.length > 0;
		const defaultGroupType: GroupType =
			submittedValues.groupType === 'CARE_CENTER' ? 'CARE_CENTER' : 'FAMILY';
		const defaultMode: GroupMode =
			submittedValues.groupMode === 'new' || submittedValues.groupMode === 'existing'
				? submittedValues.groupMode
				: data.initialMode === 'new'
					? 'new'
					: hasGroups
						? 'existing'
						: 'new';

		return {
			step: formState.stage === 'patient' ? 2 : 1,
			groupMode: defaultMode,
			groupId: submittedValues.groupId ?? data.groups[0]?.id ?? '',
			groupName: submittedValues.groupName ?? '',
			groupType: defaultGroupType,
			patientFirstName: submittedValues.patientFirstName ?? '',
			patientLastName: submittedValues.patientLastName ?? '',
			serialNumber: submittedValues.serialNumber ?? ''
		};
	}

	const initialState = getInitialState();
	let currentStep = $state(initialState.step);
	let step = $derived(data.onboardingPatient ? 3 : currentStep);
	let groupMode = $state<GroupMode>(initialState.groupMode);
	let groupId = $state(initialState.groupId);
	let groupName = $state(initialState.groupName);
	let groupType = $state<GroupType>(initialState.groupType);
	let patientFirstName = $state(initialState.patientFirstName);
	let patientLastName = $state(initialState.patientLastName);
	let serialNumber = $state(initialState.serialNumber);
	let submitting = $state(false);
	let stepOneError = $state('');
	let formState = $derived(readFormState(form));
	let errors = $derived(formState.errors ?? ({} as SetupErrors));
	let selectedGroup = $derived(data.groups.find((group) => group.id === groupId));
	let selectedGroupName = $derived(
		groupMode === 'existing' ? (selectedGroup?.name ?? 'Grupo seleccionado') : groupName
	);
	let selectedGroupType = $derived<GroupType>(
		groupMode === 'existing' ? (selectedGroup?.type ?? 'FAMILY') : groupType
	);
	let patientFormSummary = $derived(
		errors.form ??
			errors.groupId ??
			errors.groupName ??
			errors.groupType ??
			'Corrige los campos indicados para continuar.'
	);

	function focusStep() {
		requestAnimationFrame(() => {
			document.querySelector<HTMLElement>('[data-step-heading]')?.focus();
		});
	}

	function continueToPatient() {
		stepOneError = '';
		if (groupMode === 'existing' && !groupId) {
			stepOneError = 'Selecciona uno de tus grupos para continuar.';
			return;
		}
		if (groupMode === 'new' && !groupName.trim()) {
			stepOneError = 'Introduce el nombre del grupo para continuar.';
			return;
		}

		currentStep = 2;
		focusStep();
	}

	function returnToGroup() {
		currentStep = 1;
		focusStep();
	}

	const enhanceCreate: SubmitFunction = () => {
		submitting = true;
		return async ({ result, update }) => {
			await update({ reset: false });
			submitting = false;
			if (result.type === 'failure') {
				currentStep = 2;
				requestAnimationFrame(() => {
					document.querySelector<HTMLElement>('[data-form-error]')?.focus();
				});
			}
		};
	};

	const enhanceDevice: SubmitFunction = () => {
		submitting = true;
		return async ({ result, update }) => {
			await update({ reset: false });
			submitting = false;
			if (result.type === 'failure') {
				requestAnimationFrame(() => {
					document.querySelector<HTMLElement>('[data-form-error]')?.focus();
				});
			}
		};
	};
</script>

<div class="grid items-start gap-6 xl:grid-cols-12">
	<SetupProgress currentStep={step} />

	<article class="overflow-hidden rounded-2xl bg-white shadow-sm xl:order-first xl:col-span-8">
		{#if step === 1}
			<GroupStep
				groups={data.groups}
				groupsAvailable={data.groupsAvailable}
				bind:groupMode
				bind:groupId
				bind:groupName
				bind:groupType
				stepError={stepOneError}
				oncontinue={continueToPatient}
			/>
		{:else if step === 2}
			<PatientStep
				{groupMode}
				{groupId}
				{groupName}
				{groupType}
				{selectedGroupName}
				{selectedGroupType}
				bind:patientFirstName
				bind:patientLastName
				{errors}
				errorSummary={patientFormSummary}
				{submitting}
				{enhanceCreate}
				onback={returnToGroup}
			/>
		{:else if data.onboardingPatient}
			<DeviceStep
				patient={data.onboardingPatient}
				bind:serialNumber
				{errors}
				{submitting}
				{enhanceDevice}
				{deferHref}
				{finishHref}
			/>
		{/if}
	</article>
</div>
