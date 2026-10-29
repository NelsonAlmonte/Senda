<script lang="ts">
	import { enhance, type SubmitFunction } from '$app/forms';
	import { resolve } from '$app/paths';
	import type { PageProps } from './$types';

	type GroupMode = 'new' | 'existing';
	type FormValues = Partial<{
		groupMode: string;
		groupId: string;
		groupName: string;
		groupType: string;
		patientFirstName: string;
		patientLastName: string;
		serialNumber: string;
	}>;

	let { data, form }: PageProps = $props();

	function getInitialState() {
		const submittedValues =
			(form && 'values' in form ? (form.values as FormValues | undefined) : undefined) ?? {};
		const submittedStage = form && 'stage' in form ? form.stage : undefined;
		const hasGroups = data.groups.length > 0;
		const defaultMode: GroupMode =
			submittedValues.groupMode === 'new' || submittedValues.groupMode === 'existing'
				? submittedValues.groupMode
				: data.initialMode === 'new'
					? 'new'
					: hasGroups
						? 'existing'
						: 'new';

		return {
			step: submittedStage === 'patient' ? 2 : 1,
			groupMode: defaultMode,
			groupId: submittedValues.groupId ?? data.groups[0]?.id ?? '',
			groupName: submittedValues.groupName ?? '',
			groupType: submittedValues.groupType ?? 'FAMILY',
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
	let groupType = $state(initialState.groupType);
	let patientFirstName = $state(initialState.patientFirstName);
	let patientLastName = $state(initialState.patientLastName);
	let serialNumber = $state(initialState.serialNumber);
	let submitting = $state(false);
	let stepOneError = $state('');
	let hasOwnedGroups = $derived(data.groups.length > 0);
	let errors = $derived(
		form && 'errors' in form
			? (form.errors as Record<string, string>)
			: ({} as Record<string, string>)
	);
	let selectedGroup = $derived(data.groups.find((group) => group.id === groupId));

	const steps = [
		{ number: 1, label: 'Grupo' },
		{ number: 2, label: 'Paciente' },
		{ number: 3, label: 'Dispositivo' }
	];

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

<svelte:head>
	<title>Registrar paciente y dispositivo | Senda</title>
	<meta
		name="description"
		content="Selecciona el grupo, registra al paciente y configura su dispositivo en tres pasos."
	/>
</svelte:head>

<main id="contenido-principal" class="px-5 py-6 sm:px-8 lg:px-0">
	<div class="w-full max-w-4xl">
		<section class="py-4 sm:py-8">
			<div class="rounded-3xl border border-white/80 bg-white p-6 sm:p-8">
				<p class="max-w-2xl leading-7 text-muted">
					Primero elige su contexto de cuidado. El grupo nuevo se guardará junto con el primer
					paciente para evitar configuraciones incompletas.
				</p>

				<ol class="mt-7 grid grid-cols-3 gap-2" aria-label="Progreso del registro">
					{#each steps as item (item.number)}
						<li
							aria-current={step === item.number ? 'step' : undefined}
							class={[
								'rounded-2xl border px-2 py-3 text-center text-xs font-bold sm:px-4 sm:text-sm',
								step >= item.number
									? 'border-brand/25 bg-surface-muted text-ink'
									: 'border-ink/10 bg-white text-muted'
							]}
						>
							<span class="block text-xs font-semibold text-muted">Paso {item.number}</span>
							<span class="mt-1 block">{item.label}</span>
						</li>
					{/each}
				</ol>

				{#if !data.groupsAvailable}
					<div
						class="mt-6 rounded-2xl border border-amber-700/25 bg-amber-50 p-4 text-sm leading-6 text-amber-950"
						role="status"
					>
						No pudimos consultar tus grupos. Inténtalo nuevamente antes de continuar.
					</div>
				{/if}

				{#if step === 1}
					<div class="mt-8">
						<h2
							data-step-heading
							tabindex="-1"
							class="text-2xl font-bold text-ink focus:outline-none"
						>
							1. Elige el grupo
						</h2>
						<p class="mt-2 leading-7 text-muted">
							Puedes usar un grupo que ya administras o crear uno nuevo.
						</p>

						<fieldset class="mt-6">
							<legend class="sr-only">Cómo agregar el paciente</legend>
							<div class="grid gap-3 sm:grid-cols-2">
								{#if hasOwnedGroups}
									<label
										class="flex min-h-24 cursor-pointer gap-3 rounded-2xl border border-ink/15 bg-canvas p-4 transition has-checked:border-brand has-checked:ring-2 has-checked:ring-brand/20"
									>
										<input
											type="radio"
											bind:group={groupMode}
											value="existing"
											class="mt-1 size-5 shrink-0 accent-brand"
										/>
										<span>
											<span class="block font-bold text-ink">Usar un grupo existente</span>
											<span class="mt-1 block text-sm leading-5 text-muted"
												>Agrega el paciente a una familia o centro que administras.</span
											>
										</span>
									</label>
								{/if}
								<label
									class="flex min-h-24 cursor-pointer gap-3 rounded-2xl border border-ink/15 bg-canvas p-4 transition has-checked:border-brand has-checked:ring-2 has-checked:ring-brand/20"
								>
									<input
										type="radio"
										bind:group={groupMode}
										value="new"
										class="mt-1 size-5 shrink-0 accent-brand"
									/>
									<span>
										<span class="block font-bold text-ink">Crear un grupo nuevo</span>
										<span class="mt-1 block text-sm leading-5 text-muted"
											>Crea una familia o centro junto con su primer paciente.</span
										>
									</span>
								</label>
							</div>
						</fieldset>

						{#if groupMode === 'existing'}
							<fieldset class="mt-7">
								<legend class="text-sm font-bold text-ink">Grupo administrado</legend>
								<div class="mt-3 grid gap-3 sm:grid-cols-2">
									{#each data.groups as group (group.id)}
										<label
											class="flex min-h-20 cursor-pointer gap-3 rounded-2xl border border-ink/15 bg-white p-4 transition has-checked:border-brand has-checked:bg-surface-muted has-checked:ring-2 has-checked:ring-brand/20"
										>
											<input
												type="radio"
												bind:group={groupId}
												value={group.id}
												class="mt-1 size-5 shrink-0 accent-brand"
											/>
											<span class="min-w-0">
												<span class="block font-bold break-words text-ink">{group.name}</span>
												<span class="mt-1 block text-sm text-muted">
													{group.type === 'FAMILY' ? 'Familia' : 'Centro de cuidado'}
												</span>
											</span>
										</label>
									{/each}
								</div>
							</fieldset>
						{:else}
							<div class="mt-7 space-y-6">
								<div>
									<label for="groupName" class="text-sm font-bold text-ink">Nombre del grupo</label>
									<p id="group-name-help" class="mt-1 text-sm leading-6 text-muted">
										Por ejemplo, “Familia Pérez” o “Centro Amanecer”.
									</p>
									<input
										id="groupName"
										type="text"
										bind:value={groupName}
										autocomplete="organization"
										maxlength="120"
										aria-describedby="group-name-help"
										class="mt-2 min-h-12 w-full rounded-xl border border-ink/20 bg-white px-4 text-base text-ink transition outline-none focus:border-focus focus:ring-4 focus:ring-focus/20"
									/>
								</div>
								<fieldset>
									<legend class="text-sm font-bold text-ink">Tipo de grupo</legend>
									<div class="mt-3 grid gap-3 sm:grid-cols-2">
										<label
											class="flex min-h-20 cursor-pointer gap-3 rounded-2xl border border-ink/15 bg-canvas p-4 transition has-checked:border-brand has-checked:ring-2 has-checked:ring-brand/20"
										>
											<input
												type="radio"
												bind:group={groupType}
												value="FAMILY"
												class="mt-1 size-5 shrink-0 accent-brand"
											/>
											<span>
												<span class="block font-bold text-ink">Familia</span>
												<span class="mt-1 block text-sm leading-5 text-muted"
													>Para cuidado familiar o doméstico.</span
												>
											</span>
										</label>
										<label
											class="flex min-h-20 cursor-pointer gap-3 rounded-2xl border border-ink/15 bg-canvas p-4 transition has-checked:border-brand has-checked:ring-2 has-checked:ring-brand/20"
										>
											<input
												type="radio"
												bind:group={groupType}
												value="CARE_CENTER"
												class="mt-1 size-5 shrink-0 accent-brand"
											/>
											<span>
												<span class="block font-bold text-ink">Centro de cuidado</span>
												<span class="mt-1 block text-sm leading-5 text-muted"
													>Contexto administrativo ligero.</span
												>
											</span>
										</label>
									</div>
								</fieldset>
							</div>
						{/if}

						{#if stepOneError}
							<p class="mt-5 text-sm font-semibold text-red-800" role="alert">{stepOneError}</p>
						{/if}

						<button
							type="button"
							onclick={continueToPatient}
							disabled={!data.groupsAvailable}
							class="mt-7 min-h-12 w-full cursor-pointer rounded-xl bg-brand px-5 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50 sm:w-auto"
						>
							Siguiente: datos del paciente
						</button>
					</div>
				{:else if step === 2}
					<div class="mt-8">
						<h2
							data-step-heading
							tabindex="-1"
							class="text-2xl font-bold text-ink focus:outline-none"
						>
							2. Datos del paciente
						</h2>
						<p class="mt-2 leading-7 text-muted">
							{groupMode === 'existing'
								? `Se agregará a ${selectedGroup?.name ?? 'el grupo seleccionado'}.`
								: `Se creará junto con ${groupName || 'el nuevo grupo'}.`}
						</p>

						{#if Object.keys(errors).length > 0}
							<div
								data-form-error
								tabindex="-1"
								class="mt-6 rounded-2xl border border-red-700/25 bg-red-50 p-4 text-sm leading-6 text-red-950 focus:ring-4 focus:ring-red-700/20 focus:outline-none"
								role="alert"
							>
								<p class="font-bold">Revisa los datos del formulario.</p>
								{#if errors.form}<p class="mt-1">{errors.form}</p>{/if}
								{#if errors.groupId}<p class="mt-1">{errors.groupId}</p>{/if}
								{#if errors.groupName}<p class="mt-1">{errors.groupName}</p>{/if}
								{#if errors.groupType}<p class="mt-1">{errors.groupType}</p>{/if}
							</div>
						{/if}

						<form method="POST" action="?/createPatient" use:enhance={enhanceCreate} class="mt-7">
							<input type="hidden" name="groupMode" value={groupMode} />
							<input type="hidden" name="groupId" value={groupId} />
							<input type="hidden" name="groupName" value={groupName} />
							<input type="hidden" name="groupType" value={groupType} />

							<div class="grid gap-5 sm:grid-cols-2">
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
										aria-describedby={errors.patientFirstName
											? 'patient-first-name-error'
											: undefined}
										class="mt-2 min-h-12 w-full rounded-xl border border-ink/20 bg-white px-4 text-base text-ink transition outline-none focus:border-focus focus:ring-4 focus:ring-focus/20"
									/>
									{#if errors.patientFirstName}
										<p
											id="patient-first-name-error"
											class="mt-2 text-sm font-semibold text-red-800"
										>
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
										aria-describedby={errors.patientLastName
											? 'patient-last-name-error'
											: undefined}
										class="mt-2 min-h-12 w-full rounded-xl border border-ink/20 bg-white px-4 text-base text-ink transition outline-none focus:border-focus focus:ring-4 focus:ring-focus/20"
									/>
									{#if errors.patientLastName}
										<p id="patient-last-name-error" class="mt-2 text-sm font-semibold text-red-800">
											{errors.patientLastName}
										</p>
									{/if}
								</div>
							</div>

							<div class="mt-7 flex flex-col-reverse gap-3 sm:flex-row sm:items-center">
								<button
									type="button"
									onclick={returnToGroup}
									class="min-h-12 cursor-pointer rounded-xl border border-ink/15 bg-white px-5 font-bold text-ink transition hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none"
								>
									Atrás
								</button>
								<button
									type="submit"
									disabled={submitting}
									class="min-h-12 cursor-pointer rounded-xl bg-brand px-5 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
								>
									{submitting ? 'Guardando…' : 'Guardar y continuar'}
								</button>
							</div>
						</form>
					</div>
				{:else if data.onboardingPatient}
					<div class="mt-8">
						<h2
							data-step-heading
							tabindex="-1"
							class="text-2xl font-bold text-ink focus:outline-none"
						>
							3. Configura el dispositivo
						</h2>
						<p class="mt-2 leading-7 text-muted">
							{data.onboardingPatient.groupName} · {data.onboardingPatient.firstName}
							{data.onboardingPatient.lastName}
						</p>

						<div class="mt-6 rounded-2xl bg-canvas p-4 text-sm leading-6 text-ink">
							El grupo y el paciente ya están guardados. Puedes asignar el serial simulado ahora o
							continuar al panel y hacerlo después.
						</div>

						{#if data.onboardingPatient.serialNumber}
							<div
								class="mt-6 rounded-2xl border border-brand/20 bg-surface-muted p-5"
								role="status"
							>
								<p class="font-bold text-ink">Dispositivo configurado</p>
								<p class="mt-2 font-mono text-sm break-all text-ink">
									{data.onboardingPatient.serialNumber}
								</p>
							</div>
							<a
								href={resolve('/patients')}
								class="mt-6 inline-flex min-h-12 items-center justify-center rounded-xl bg-brand px-5 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none"
							>
								Ir a pacientes
							</a>
						{:else}
							{#if Object.keys(errors).length > 0}
								<div
									data-form-error
									tabindex="-1"
									class="mt-6 rounded-2xl border border-red-700/25 bg-red-50 p-4 text-sm leading-6 text-red-950 focus:ring-4 focus:ring-red-700/20 focus:outline-none"
									role="alert"
								>
									<p class="font-bold">Revisa el serial del dispositivo.</p>
									{#if errors.form}<p class="mt-1">{errors.form}</p>{/if}
								</div>
							{/if}

							<form
								method="POST"
								action={`?step=device&patient=${encodeURIComponent(data.onboardingPatient.id)}&/assignDevice`}
								use:enhance={enhanceDevice}
								class="mt-7"
							>
								<input type="hidden" name="patientId" value={data.onboardingPatient.id} />
								<label for="serialNumber" class="text-sm font-bold text-ink">
									Serial del dispositivo
								</label>
								<p id="serial-help" class="mt-1 max-w-2xl text-sm leading-6 text-muted">
									En esta simulación usa SENDA-DEMO-001, SENDA-DEMO-002 o SENDA-DEMO-003.
								</p>
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
									aria-describedby={errors.serialNumber
										? 'serial-help serial-error'
										: 'serial-help'}
									class="mt-2 min-h-12 w-full rounded-xl border border-ink/20 bg-white px-4 font-mono text-base text-ink uppercase transition outline-none focus:border-focus focus:ring-4 focus:ring-focus/20"
								/>
								{#if errors.serialNumber}
									<p id="serial-error" class="mt-2 text-sm font-semibold text-red-800">
										{errors.serialNumber}
									</p>
								{/if}

								<div class="mt-7 flex flex-col gap-3 sm:flex-row sm:items-center">
									<button
										type="submit"
										disabled={submitting}
										class="min-h-12 cursor-pointer rounded-xl bg-brand px-5 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
									>
										{submitting ? 'Configurando…' : 'Configurar dispositivo'}
									</button>
									<a
										href={resolve('/patients?created=patient')}
										class="inline-flex min-h-12 items-center justify-center rounded-xl border border-ink/15 bg-white px-5 font-bold text-ink transition hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none"
									>
										Configurar después
									</a>
								</div>
							</form>
						{/if}
					</div>
				{/if}
			</div>
		</section>
	</div>
</main>
