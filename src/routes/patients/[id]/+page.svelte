<script lang="ts">
	import { enhance, type SubmitFunction } from '$app/forms';
	import { resolve } from '$app/paths';
	import type { PageProps } from './$types';

	let { data, form }: PageProps = $props();
	let submitting = $state(false);
	let updateResult = $derived(form?.action === 'update' ? form : null);
	let errors = $derived((updateResult?.errors ?? {}) as Record<string, string>);

	const enhanceUpdate: SubmitFunction = () => {
		submitting = true;

		return async ({ result, update }) => {
			await update({ reset: false });
			submitting = false;

			if (result.type === 'failure') {
				requestAnimationFrame(() => {
					document.querySelector<HTMLElement>('[data-patient-form-error]')?.focus();
				});
			}
		};
	};
</script>

<svelte:head>
	<title>{data.patient.firstName} {data.patient.lastName} | Senda</title>
	<meta name="description" content="Resumen y operaciones autorizadas del paciente en Senda." />
</svelte:head>

<main id="contenido-principal" class="min-h-dvh px-5 py-6 sm:px-8 lg:px-0">
	<div class="w-full max-w-5xl">
		{#if updateResult?.successMessage}
			<div
				class="mt-6 rounded-2xl border border-brand/20 bg-surface-muted p-4 text-sm font-semibold text-ink"
				role="status"
			>
				{updateResult.successMessage}
			</div>
		{/if}

		<div class="grid gap-6 py-8 lg:grid-cols-5">
			<section class="rounded-3xl border border-white/80 bg-white p-6 sm:p-8 lg:col-span-3">
				<h2 class="text-2xl font-bold text-ink">Datos del paciente</h2>
				<p class="mt-2 leading-7 text-muted">
					Senda conserva solamente los datos administrativos mínimos para identificar a la persona.
				</p>

				{#if data.isAdmin}
					{#if Object.keys(errors).length > 0}
						<div
							data-patient-form-error
							tabindex="-1"
							class="mt-6 rounded-2xl border border-red-700/25 bg-red-50 p-4 text-sm leading-6 text-red-950 focus:ring-4 focus:ring-red-700/20 focus:outline-none"
							role="alert"
						>
							<p class="font-bold">Revisa los datos del paciente.</p>
							{#if errors.form}<p class="mt-1">{errors.form}</p>{/if}
						</div>
					{/if}

					<form method="POST" action="?/update" use:enhance={enhanceUpdate} class="mt-7 space-y-5">
						<div>
							<label for="firstName" class="text-sm font-bold text-ink">Nombre</label>
							<input
								id="firstName"
								name="firstName"
								type="text"
								autocomplete="off"
								minlength="1"
								maxlength="80"
								required
								value={updateResult?.values?.firstName ?? data.patient.firstName}
								aria-invalid={errors.firstName ? 'true' : undefined}
								aria-describedby={errors.firstName ? 'first-name-error' : undefined}
								class="mt-2 min-h-12 w-full rounded-xl border border-ink/20 bg-white px-4 text-base text-ink outline-none focus:border-focus focus:ring-4 focus:ring-focus/20"
							/>
							{#if errors.firstName}
								<p id="first-name-error" class="mt-2 text-sm font-semibold text-red-800">
									{errors.firstName}
								</p>
							{/if}
						</div>

						<div>
							<label for="lastName" class="text-sm font-bold text-ink">Apellido</label>
							<input
								id="lastName"
								name="lastName"
								type="text"
								autocomplete="off"
								minlength="1"
								maxlength="80"
								required
								value={updateResult?.values?.lastName ?? data.patient.lastName}
								aria-invalid={errors.lastName ? 'true' : undefined}
								aria-describedby={errors.lastName ? 'last-name-error' : undefined}
								class="mt-2 min-h-12 w-full rounded-xl border border-ink/20 bg-white px-4 text-base text-ink outline-none focus:border-focus focus:ring-4 focus:ring-focus/20"
							/>
							{#if errors.lastName}
								<p id="last-name-error" class="mt-2 text-sm font-semibold text-red-800">
									{errors.lastName}
								</p>
							{/if}
						</div>

						<button
							type="submit"
							disabled={submitting}
							class="min-h-12 cursor-pointer rounded-xl bg-brand px-5 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
						>
							{submitting ? 'Guardando…' : 'Guardar cambios'}
						</button>
					</form>
				{:else}
					<dl class="mt-7 grid gap-4 sm:grid-cols-2">
						<div class="rounded-2xl bg-canvas p-4">
							<dt class="text-sm font-semibold text-muted">Nombre</dt>
							<dd class="mt-1 font-bold text-ink">{data.patient.firstName}</dd>
						</div>
						<div class="rounded-2xl bg-canvas p-4">
							<dt class="text-sm font-semibold text-muted">Apellido</dt>
							<dd class="mt-1 font-bold text-ink">{data.patient.lastName}</dd>
						</div>
					</dl>
				{/if}
			</section>

			<aside class="rounded-3xl border border-white/80 bg-white p-6 sm:p-8 lg:col-span-2">
				<h2 class="text-xl font-bold text-ink">Estado actual</h2>
				<dl class="mt-5 space-y-4">
					<div>
						<dt class="text-sm font-semibold text-muted">Grupo</dt>
						<dd class="mt-1 font-bold text-ink">
							{data.patient.group?.name ?? 'Sin grupo visible'}
						</dd>
					</div>
					<div>
						<dt class="text-sm font-semibold text-muted">Dispositivo</dt>
						<dd class="mt-1 font-bold text-ink">
							{data.assignment
								? data.assignment.device.serialNumber
								: 'Sin dispositivo configurado'}
						</dd>
					</div>
					{#if data.isAdmin}
						<div>
							<dt class="text-sm font-semibold text-muted">Accesos activos</dt>
							<dd class="mt-1 font-bold text-ink">{data.activeAccessCount}</dd>
						</div>
					{/if}
				</dl>
			</aside>
		</div>

		<section aria-labelledby="patient-sections-title" class="pb-12">
			<h2 id="patient-sections-title" class="text-2xl font-bold text-ink">
				Operaciones y monitoreo
			</h2>
			<p class="mt-2 max-w-3xl leading-7 text-muted">
				Accede a cada función sin mezclar la gestión administrativa con el seguimiento diario.
			</p>

			<div class="mt-6 grid gap-4 sm:grid-cols-2">
				{#if data.isAdmin}
					<a
						href={resolve('/patients/[id]/access', { id: data.patient.id })}
						class="rounded-2xl border border-brand/15 bg-white p-5 transition hover:border-brand/35 focus:ring-4 focus:ring-focus/30 focus:outline-none"
					>
						<h3 class="text-lg font-bold text-ink">Personas con acceso</h3>
						<p class="mt-2 leading-6 text-muted">
							Consulta {data.activeAccessCount}
							{data.activeAccessCount === 1 ? 'acceso activo' : 'accesos activos'}, genera códigos y
							revoca monitores.
						</p>
						<span class="mt-4 inline-flex min-h-11 items-center font-bold text-brand"
							>Administrar accesos →</span
						>
					</a>

					<a
						href={resolve('/patients/[id]/device', { id: data.patient.id })}
						class="rounded-2xl border border-brand/15 bg-white p-5 transition hover:border-brand/35 focus:ring-4 focus:ring-focus/30 focus:outline-none"
					>
						<h3 class="text-lg font-bold text-ink">Dispositivo</h3>
						<p class="mt-2 leading-6 text-muted">
							{data.assignment
								? 'Consulta el dispositivo simulado actualmente asignado.'
								: 'Configura un dispositivo simulado para comenzar a recibir ubicaciones.'}
						</p>
						<span class="mt-4 inline-flex min-h-11 items-center font-bold text-brand"
							>Ver dispositivo →</span
						>
					</a>
				{/if}

				{#if data.assignment}
					<a
						href={resolve('/patients/[id]/map', { id: data.patient.id })}
						class="rounded-2xl border border-brand/15 bg-white p-5 transition hover:border-brand/35 focus:ring-4 focus:ring-focus/30 focus:outline-none"
					>
						<h3 class="text-lg font-bold text-ink">Mapa e historial</h3>
						<p class="mt-2 leading-6 text-muted">
							Consulta la última ubicación, el recorrido y las alertas del paciente.
						</p>
						<span class="mt-4 inline-flex min-h-11 items-center font-bold text-brand"
							>Abrir mapa →</span
						>
					</a>
				{/if}

				<a
					href={resolve('/patients/[id]/safe-zones', { id: data.patient.id })}
					class="rounded-2xl border border-brand/15 bg-white p-5 transition hover:border-brand/35 focus:ring-4 focus:ring-focus/30 focus:outline-none"
				>
					<h3 class="text-lg font-bold text-ink">Geocercas</h3>
					<p class="mt-2 leading-6 text-muted">
						Crea y ajusta las zonas circulares permitidas para este paciente.
					</p>
					<span class="mt-4 inline-flex min-h-11 items-center font-bold text-brand"
						>Configurar geocercas →</span
					>
				</a>
			</div>
		</section>
	</div>
</main>
