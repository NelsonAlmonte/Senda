<script lang="ts">
	import { enhance, type SubmitFunction } from '$app/forms';
	import { resolve } from '$app/paths';
	import type { PageProps } from './$types';

	let { data, form }: PageProps = $props();
	let submitting = $state(false);
	let errors = $derived((form?.errors ?? {}) as Record<string, string>);

	const enhanceForm: SubmitFunction = () => {
		submitting = true;

		return async ({ result, update }) => {
			await update({ reset: result.type === 'success' });
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
	<title>Grupos y pacientes | Senda</title>
	<meta
		name="description"
		content="Crea el contexto familiar o de cuidado y registra el primer paciente autorizado."
	/>
</svelte:head>

<main id="contenido-principal" class="min-h-dvh px-5 py-6 sm:px-8 lg:px-12">
	<div class="mx-auto w-full max-w-6xl">
		<header class="flex flex-wrap items-center justify-between gap-4 border-b border-ink/10 pb-5">
			<a
				href={resolve('/dashboard')}
				class="inline-flex min-h-12 items-center rounded-xl font-bold text-brand focus:ring-4 focus:ring-focus/30 focus:outline-none"
			>
				<span aria-hidden="true">←</span><span class="ml-2">Volver al panel</span>
			</a>
			<p class="text-sm font-semibold text-muted">Alta inicial</p>
		</header>

		<div class="grid gap-8 py-8 lg:grid-cols-[minmax(0,1.15fr)_minmax(18rem,0.85fr)] lg:py-12">
			<section
				class="rounded-3xl border border-white/80 bg-white p-6 shadow-xl shadow-brand/8 sm:p-8"
			>
				<p class="text-sm font-bold tracking-[0.14em] text-brand uppercase">Grupo y paciente</p>
				<h1 class="mt-2 text-3xl font-bold tracking-tight text-ink">Configura el primer cuidado</h1>
				<p class="mt-3 max-w-2xl leading-7 text-muted">
					El grupo solo organiza el contexto. La autorización para consultar al paciente se guardará
					por separado y recibirás el rol de administrador.
				</p>

				{#if !data.groupsAvailable}
					<div
						class="mt-6 rounded-2xl border border-amber-700/25 bg-amber-50 p-4 text-sm leading-6 text-amber-950"
						role="status"
					>
						La estructura de grupos y pacientes aún no está disponible en Supabase. Aplica la
						migración de desarrollo antes de usar este formulario.
					</div>
				{/if}

				{#if Object.keys(errors).length > 0}
					<div
						data-form-error
						tabindex="-1"
						class="mt-6 rounded-2xl border border-red-700/25 bg-red-50 p-4 text-sm leading-6 text-red-950 focus:ring-4 focus:ring-red-700/20 focus:outline-none"
						role="alert"
					>
						<p class="font-bold">Revisa los datos del formulario.</p>
						{#if errors.form}<p class="mt-1">{errors.form}</p>{/if}
					</div>
				{/if}

				<form method="POST" use:enhance={enhanceForm} class="mt-7 space-y-7">
					<div>
						<label for="groupName" class="text-sm font-bold text-ink">Nombre del grupo</label>
						<p id="group-name-help" class="mt-1 text-sm leading-6 text-muted">
							Por ejemplo, “Familia Pérez” o “Centro Amanecer”.
						</p>
						<input
							id="groupName"
							name="groupName"
							type="text"
							autocomplete="organization"
							maxlength="120"
							required
							value={form?.values?.groupName ?? ''}
							aria-invalid={errors.groupName ? 'true' : undefined}
							aria-describedby={errors.groupName
								? 'group-name-help group-name-error'
								: 'group-name-help'}
							class="mt-2 min-h-12 w-full rounded-xl border border-ink/20 bg-white px-4 text-base text-ink transition outline-none focus:border-focus focus:ring-4 focus:ring-focus/20"
						/>
						{#if errors.groupName}
							<p id="group-name-error" class="mt-2 text-sm font-semibold text-red-800">
								{errors.groupName}
							</p>
						{/if}
					</div>

					<fieldset>
						<legend class="text-sm font-bold text-ink">Tipo de grupo</legend>
						<div class="mt-3 grid gap-3 sm:grid-cols-2">
							<label
								class="flex min-h-24 cursor-pointer gap-3 rounded-2xl border border-ink/15 bg-canvas p-4 transition has-checked:border-brand has-checked:ring-2 has-checked:ring-brand/20"
							>
								<input
									type="radio"
									name="groupType"
									value="FAMILY"
									required
									checked={(form?.values?.groupType ?? 'FAMILY') === 'FAMILY'}
									aria-describedby={errors.groupType ? 'group-type-error' : undefined}
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
								class="flex min-h-24 cursor-pointer gap-3 rounded-2xl border border-ink/15 bg-canvas p-4 transition has-checked:border-brand has-checked:ring-2 has-checked:ring-brand/20"
							>
								<input
									type="radio"
									name="groupType"
									value="CARE_CENTER"
									required
									checked={form?.values?.groupType === 'CARE_CENTER'}
									aria-describedby={errors.groupType ? 'group-type-error' : undefined}
									class="mt-1 size-5 shrink-0 accent-brand"
								/>
								<span>
									<span class="block font-bold text-ink">Centro de cuidado</span>
									<span class="mt-1 block text-sm leading-5 text-muted"
										>Solo como contexto administrativo ligero.</span
									>
								</span>
							</label>
						</div>
						{#if errors.groupType}
							<p id="group-type-error" class="mt-2 text-sm font-semibold text-red-800">
								{errors.groupType}
							</p>
						{/if}
					</fieldset>

					<fieldset class="space-y-5 border-t border-ink/10 pt-7">
						<legend class="px-2 text-lg font-bold text-ink">Datos mínimos del paciente</legend>
						<div class="grid gap-5 sm:grid-cols-2">
							<div>
								<label for="patientFirstName" class="text-sm font-bold text-ink">Nombre</label>
								<input
									id="patientFirstName"
									name="patientFirstName"
									type="text"
									autocomplete="off"
									maxlength="80"
									required
									value={form?.values?.patientFirstName ?? ''}
									aria-invalid={errors.patientFirstName ? 'true' : undefined}
									aria-describedby={errors.patientFirstName
										? 'patient-first-name-error'
										: undefined}
									class="mt-2 min-h-12 w-full rounded-xl border border-ink/20 bg-white px-4 text-base text-ink transition outline-none focus:border-focus focus:ring-4 focus:ring-focus/20"
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
									autocomplete="off"
									maxlength="80"
									required
									value={form?.values?.patientLastName ?? ''}
									aria-invalid={errors.patientLastName ? 'true' : undefined}
									aria-describedby={errors.patientLastName ? 'patient-last-name-error' : undefined}
									class="mt-2 min-h-12 w-full rounded-xl border border-ink/20 bg-white px-4 text-base text-ink transition outline-none focus:border-focus focus:ring-4 focus:ring-focus/20"
								/>
								{#if errors.patientLastName}
									<p id="patient-last-name-error" class="mt-2 text-sm font-semibold text-red-800">
										{errors.patientLastName}
									</p>
								{/if}
							</div>
						</div>
					</fieldset>

					<button
						type="submit"
						disabled={submitting || !data.groupsAvailable}
						class="min-h-12 w-full cursor-pointer rounded-xl bg-brand px-5 font-bold text-white shadow-sm transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50 sm:w-auto"
					>
						{submitting ? 'Creando acceso…' : 'Crear y continuar'}
					</button>
					<p class="mt-3 text-sm leading-6 text-muted">
						En el siguiente paso podrás configurar un dispositivo o dejarlo para después.
					</p>
				</form>
			</section>

			<aside class="min-w-0">
				<div class="rounded-3xl bg-surface-muted p-6 sm:p-7">
					<h2 class="text-xl font-bold text-ink">Tus grupos administrados</h2>
					{#if data.groups.length > 0}
						<ul class="mt-5 space-y-3">
							{#each data.groups as group (group.id)}
								<li class="rounded-2xl bg-white p-4 shadow-sm">
									<p class="font-bold break-words text-ink">{group.name}</p>
									<p class="mt-1 text-sm text-muted">
										{group.type === 'FAMILY' ? 'Familia' : 'Centro de cuidado'}
									</p>
								</li>
							{/each}
						</ul>
					{:else}
						<p class="mt-3 leading-7 text-muted">
							Aún no administras grupos. El primero aparecerá aquí después de completar el alta.
						</p>
					{/if}
				</div>

				<div class="mt-5 rounded-3xl border border-sky-soft bg-white p-6">
					<h2 class="font-bold text-ink">Privacidad desde el inicio</h2>
					<p class="mt-2 text-sm leading-6 text-muted">
						No se solicitan diagnósticos, fotografías ni historia clínica. El grupo tampoco concede
						acceso automático a otros usuarios.
					</p>
				</div>
			</aside>
		</div>
	</div>
</main>
