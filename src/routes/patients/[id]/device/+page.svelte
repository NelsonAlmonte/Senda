<script lang="ts">
	import { enhance, type SubmitFunction } from '$app/forms';
	import { resolve } from '$app/paths';
	import Heading from '#lib/components/ui/Heading.svelte';
	import CalendarDays from '@lucide/svelte/icons/calendar-days';
	import CircleCheck from '@lucide/svelte/icons/circle-check';
	import MapPinned from '@lucide/svelte/icons/map-pinned';
	import Smartphone from '@lucide/svelte/icons/smartphone';
	import UsersRound from '@lucide/svelte/icons/users-round';
	import type { PageProps } from './$types';

	let { data, form }: PageProps = $props();
	let submitting = $state(false);
	let errors = $derived((form?.errors ?? {}) as Record<string, string>);
	const dateFormatter = new Intl.DateTimeFormat('es-DO', {
		dateStyle: 'medium',
		timeZone: 'America/Santo_Domingo'
	});

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
	<title>{data.assignment ? 'Dispositivo configurado' : 'Configurar dispositivo'} | Senda</title>
	<meta name="description" content="Asigna un dispositivo de Senda a un paciente autorizado." />
</svelte:head>

<main id="contenido-principal" class="px-5 py-8 sm:px-8 lg:px-0">
	<div class="w-full max-w-4xl">
		<h2 class="mb-8 text-2xl font-bold text-ink">
			{data.assignment ? 'Dispositivo configurado' : 'Configurar dispositivo'}
		</h2>

		{#if data.assignment}
			<section class="overflow-hidden rounded-2xl bg-white shadow-sm">
				<div class="p-6">
					<Heading
						icon={Smartphone}
						title="Dispositivo asignado"
						subtitle="Dispositivo asignado al paciente."
					/>

					<div class="mt-6 grid gap-3 sm:grid-cols-2" role="status">
						<div class="flex items-start gap-3 rounded-2xl bg-surface-muted p-4">
							<CircleCheck
								class="mt-1 shrink-0 text-brand"
								aria-hidden="true"
								size={20}
								strokeWidth={2}
							/>
							<div>
								<p class="font-bold text-ink">Asignación activa</p>
								<p class="mt-1 text-sm leading-6 text-muted">Puede recibir ubicaciones.</p>
							</div>
						</div>
						<div class="flex items-start gap-3 rounded-2xl bg-surface-muted p-4">
							<CalendarDays
								class="mt-1 shrink-0 text-brand"
								aria-hidden="true"
								size={20}
								strokeWidth={2}
							/>
							<div>
								<p class="font-bold text-ink">Asignado desde</p>
								<time
									datetime={data.assignment.assignedAt}
									class="mt-1 block text-sm leading-6 text-muted"
								>
									{dateFormatter.format(new Date(data.assignment.assignedAt))}
								</time>
							</div>
						</div>
					</div>
				</div>

				<div class="flex flex-col gap-2 border-t border-ink/10 p-4 sm:flex-row">
					<a
						href={resolve('/patients/[id]/map', { id: data.patient.id })}
						class="inline-flex min-h-12 items-center justify-center gap-2 rounded-full bg-brand px-5 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none"
					>
						<MapPinned aria-hidden="true" size={18} strokeWidth={2} />
						Ver mapa
					</a>
					<a
						href={resolve('/patients')}
						class="inline-flex min-h-12 items-center justify-center gap-2 rounded-full px-5 font-bold text-brand transition hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none"
					>
						<UsersRound aria-hidden="true" size={18} strokeWidth={2} />
						Ver pacientes
					</a>
				</div>
			</section>
		{:else}
			<section class="overflow-hidden rounded-2xl bg-white shadow-sm">
				<form method="POST" use:enhance={enhanceForm} aria-busy={submitting}>
					<div class="p-6">
						<Heading
							icon={Smartphone}
							title="Dispositivo Senda"
							subtitle="Asigna uno de los dispositivos disponibles para comenzar a recibir ubicaciones."
						/>

						{#if data.onboarding}
							<div class="mt-6 rounded-2xl bg-surface-muted p-4 text-sm leading-6 text-ink">
								El grupo y el paciente ya están creados. Puedes configurar el dispositivo ahora o
								continuar y hacerlo después.
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

						<div class="mt-6">
							<label for="serialNumber" class="text-sm font-bold text-ink">
								Serial del dispositivo
							</label>
							<p id="serial-help" class="mt-1 max-w-2xl text-sm leading-6 text-muted">
								Introduce el serial indicado en el dispositivo. No introduzcas espacios.
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
						</div>
					</div>

					<div class="flex flex-col gap-2 border-t border-ink/10 p-4 sm:flex-row sm:items-center">
						<button
							type="submit"
							disabled={submitting}
							class="min-h-12 cursor-pointer rounded-full bg-brand px-5 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
						>
							{submitting ? 'Configurando…' : 'Configurar dispositivo'}
						</button>
						<a
							href={resolve('/patients')}
							class="inline-flex min-h-12 items-center justify-center rounded-full px-5 font-bold text-brand transition hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none"
						>
							Configurar después
						</a>
					</div>
				</form>
			</section>
		{/if}
	</div>
</main>
