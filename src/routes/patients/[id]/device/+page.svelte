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
	<title>Configurar dispositivo | Senda</title>
	<meta
		name="description"
		content="Asigna un dispositivo simulado de Senda a un paciente autorizado."
	/>
</svelte:head>

<main id="contenido-principal" class="min-h-dvh px-5 py-6 sm:px-8 lg:px-0">
	<div class="w-full max-w-4xl">
		<section class="py-4 sm:py-8">
			<div class="rounded-3xl border border-white/80 bg-white p-6 sm:p-8">
				{#if data.assignment}
					<div class="mt-7 rounded-2xl border border-brand/20 bg-surface-muted p-5" role="status">
						<p class="font-bold text-ink">Dispositivo configurado</p>
						<p class="mt-2 font-mono text-sm break-all text-ink">
							{data.assignment.device.serialNumber}
						</p>
						<p class="mt-2 text-sm leading-6 text-muted">
							La asignación está activa y puede recibir ubicaciones simuladas.
						</p>
					</div>

					<div class="mt-6 flex flex-col gap-3 sm:flex-row">
						<a
							href={resolve('/patients/[id]/map', { id: data.patient.id })}
							class="inline-flex min-h-12 items-center justify-center rounded-xl bg-brand px-5 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none"
						>
							Ver mapa
						</a>
						<a
							href={resolve('/patients')}
							class="inline-flex min-h-12 items-center justify-center rounded-xl border border-ink/15 bg-white px-5 font-bold text-ink transition hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none"
						>
							Ir a pacientes
						</a>
					</div>
				{:else}
					{#if data.onboarding}
						<div class="mt-6 rounded-2xl bg-canvas p-4 text-sm leading-6 text-ink">
							El grupo y el paciente ya están creados. Puedes configurar el dispositivo ahora o
							continuar al panel y hacerlo después.
						</div>
					{/if}

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

					<form method="POST" use:enhance={enhanceForm} class="mt-7">
						<label for="serialNumber" class="text-sm font-bold text-ink">
							Serial del dispositivo
						</label>
						<p id="serial-help" class="mt-1 max-w-2xl text-sm leading-6 text-muted">
							En esta simulación usa SENDA-DEMO-001, SENDA-DEMO-002 o SENDA-DEMO-003. No introduzcas
							espacios.
						</p>
						<input
							id="serialNumber"
							name="serialNumber"
							type="text"
							autocomplete="off"
							spellcheck="false"
							inputmode="text"
							minlength="8"
							maxlength="64"
							required
							placeholder="SENDA-DEMO-001"
							value={form?.values?.serialNumber ?? ''}
							aria-invalid={errors.serialNumber ? 'true' : undefined}
							aria-describedby={errors.serialNumber ? 'serial-help serial-error' : 'serial-help'}
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
								href={resolve('/patients')}
								class="inline-flex min-h-12 items-center justify-center rounded-xl border border-ink/15 bg-white px-5 font-bold text-ink transition hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none"
							>
								Configurar después
							</a>
						</div>
					</form>
				{/if}
			</div>
		</section>
	</div>
</main>
