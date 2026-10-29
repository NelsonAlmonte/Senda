<script lang="ts">
	import { enhance, type SubmitFunction } from '$app/forms';
	import { resolve } from '$app/paths';
	import Heading from '#lib/components/ui/Heading.svelte';
	import Initials from '#lib/components/ui/Initials.svelte';
	import ArrowUpRight from '@lucide/svelte/icons/arrow-up-right';
	import KeyRound from '@lucide/svelte/icons/key-round';
	import MapPinned from '@lucide/svelte/icons/map-pinned';
	import PencilLine from '@lucide/svelte/icons/pencil-line';
	import ShieldCheck from '@lucide/svelte/icons/shield-check';
	import Smartphone from '@lucide/svelte/icons/smartphone';
	import UserRound from '@lucide/svelte/icons/user-round';
	import UsersRound from '@lucide/svelte/icons/users-round';
	import type { PageProps } from './$types';

	let { data, form }: PageProps = $props();
	let submitting = $state(false);
	let updateResult = $derived(form?.action === 'update' ? form : null);
	let errors = $derived((updateResult?.errors ?? {}) as Record<string, string>);
	let patientName = $derived(`${data.patient.firstName} ${data.patient.lastName}`.trim());

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

<main id="contenido-principal" class="px-5 py-8 sm:px-8 lg:px-0">
	<div class="w-full">
		{#if updateResult?.successMessage}
			<div
				class="mt-6 rounded-2xl border border-brand/20 bg-surface-muted p-4 text-sm font-semibold text-ink"
				role="status"
			>
				{updateResult.successMessage}
			</div>
		{/if}

		<div class="max-w-3xl">
			<h2 id="patient-data-title" class="mb-8 text-2xl font-bold text-ink">Datos del paciente</h2>
		</div>
		<div class="grid gap-6 xl:grid-cols-12">
			<section class="overflow-hidden rounded-2xl bg-white shadow-sm xl:col-span-7">
				<div class="p-6">
					<Heading
						icon={PencilLine}
						title="Datos del paciente"
						subtitle="Datos identificativos del paciente."
					/>

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

						<div class="mt-8">
							<form
								id="patient-data-form"
								method="POST"
								action="?/update"
								use:enhance={enhanceUpdate}
								aria-busy={submitting}
							>
								<div class="grid gap-5 sm:grid-cols-2">
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
								</div>
							</form>
						</div>
					{:else}
						<dl class="mt-8 grid gap-4 sm:grid-cols-2">
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
				</div>

				{#if data.isAdmin}
					<div class="border-t border-ink/10 p-4">
						<button
							type="submit"
							form="patient-data-form"
							disabled={submitting}
							class="min-h-12 cursor-pointer rounded-full bg-brand px-6 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
						>
							{submitting ? 'Guardando…' : 'Guardar cambios'}
						</button>
					</div>
				{/if}
			</section>

			<aside class="rounded-2xl bg-white p-6 shadow-sm xl:col-span-5">
				<div class="flex items-center gap-4">
					<Initials text={patientName} />
					<div class="min-w-0">
						<h3 class="text-xl font-bold text-ink">Resumen del paciente</h3>
						<p class="mt-1 leading-6 text-muted">Contexto administrativo y elementos vinculados.</p>
					</div>
				</div>

				<dl class="mt-8 grid gap-4 sm:grid-cols-2">
					<div class="flex items-start gap-3 rounded-2xl bg-canvas p-4 sm:col-span-2">
						<div
							class="flex size-10 shrink-0 items-center justify-center rounded-full bg-white text-brand"
						>
							<UsersRound aria-hidden="true" size={20} strokeWidth={2} />
						</div>
						<div class="min-w-0">
							<dt class="text-sm font-semibold text-muted">Grupo</dt>
							<dd class="mt-1 text-sm font-bold wrap-break-word text-ink">
								{data.patient.group?.name ?? 'Sin grupo visible'}
							</dd>
						</div>
					</div>

					<div class="flex items-start gap-3 rounded-2xl bg-canvas p-4">
						<div
							class="flex size-10 shrink-0 items-center justify-center rounded-full bg-white text-brand"
						>
							<Smartphone aria-hidden="true" size={20} strokeWidth={2} />
						</div>
						<div class="min-w-0">
							<dt class="text-sm font-semibold text-muted">Dispositivo</dt>
							<dd class="mt-1 text-sm font-bold wrap-break-word text-ink">
								{data.assignment ? data.assignment.device.serialNumber : 'Sin configurar'}
							</dd>
						</div>
					</div>

					{#if data.isAdmin}
						<div class="flex items-start gap-3 rounded-2xl bg-canvas p-4">
							<div
								class="flex size-10 shrink-0 items-center justify-center rounded-full bg-white text-brand"
							>
								<KeyRound aria-hidden="true" size={20} strokeWidth={2} />
							</div>
							<div>
								<dt class="text-sm font-semibold text-muted">Accesos activos</dt>
								<dd class="mt-1 text-sm font-bold text-ink">{data.activeAccessCount}</dd>
							</div>
						</div>
					{/if}
				</dl>
			</aside>
		</div>

		<section aria-labelledby="patient-sections-title" class="mt-8">
			<div class="max-w-3xl">
				<h2 id="patient-sections-title" class="mb-8 text-2xl font-bold text-ink">
					Operaciones y monitoreo
				</h2>
			</div>

			<div class="grid gap-6 lg:grid-cols-2">
				<article class={['rounded-2xl bg-white p-6 shadow-sm', !data.isAdmin && 'lg:col-span-2']}>
					<Heading
						icon={MapPinned}
						title="Monitoreo"
						subtitle="Consulta el recorrido y configura las zonas permitidas."
					/>

					<nav
						class={['mt-6 grid gap-3', !data.isAdmin && 'sm:grid-cols-2']}
						aria-label="Operaciones de monitoreo"
					>
						{#if data.assignment}
							<a
								href={resolve('/patients/[id]/map', { id: data.patient.id })}
								class="group flex min-h-24 items-center gap-4 rounded-2xl bg-canvas p-4 transition-colors hover:bg-surface-muted focus:ring-4 focus:ring-focus/30 focus:outline-none"
							>
								<div
									class="flex size-11 shrink-0 items-center justify-center rounded-full bg-white text-brand"
								>
									<MapPinned aria-hidden="true" size={20} strokeWidth={2} />
								</div>
								<div class="min-w-0 flex-1">
									<h4 class="font-bold text-ink">Mapa e historial</h4>
									<p class="mt-1 text-sm leading-5 text-muted">
										Ubicación en mapa y recorrido reciente.
									</p>
								</div>
								<ArrowUpRight
									aria-hidden="true"
									class="shrink-0 text-brand transition-transform group-hover:translate-x-0.5 group-hover:-translate-y-0.5"
									size={19}
									strokeWidth={2}
								/>
							</a>
						{/if}

						<a
							href={resolve('/patients/[id]/safe-zones', { id: data.patient.id })}
							class="group flex min-h-24 items-center gap-4 rounded-2xl bg-canvas p-4 transition-colors hover:bg-surface-muted focus:ring-4 focus:ring-focus/30 focus:outline-none"
						>
							<div
								class="flex size-11 shrink-0 items-center justify-center rounded-full bg-white text-brand"
							>
								<ShieldCheck aria-hidden="true" size={20} strokeWidth={2} />
							</div>
							<div class="min-w-0 flex-1">
								<h4 class="font-bold text-ink">Geocercas</h4>
								<p class="mt-1 text-sm leading-5 text-muted">Zonas circulares permitidas.</p>
							</div>
							<ArrowUpRight
								aria-hidden="true"
								class="shrink-0 text-brand transition-transform group-hover:translate-x-0.5 group-hover:-translate-y-0.5"
								size={19}
								strokeWidth={2}
							/>
						</a>
					</nav>
				</article>

				{#if data.isAdmin}
					<article class="rounded-2xl bg-white p-6 shadow-sm">
						<Heading
							icon={UserRound}
							title="Administración"
							subtitle="Gestiona las personas autorizadas y el dispositivo asignado."
						/>

						<nav class="mt-6 grid gap-3" aria-label="Operaciones administrativas">
							<a
								href={resolve('/patients/[id]/access', { id: data.patient.id })}
								class="group flex min-h-24 items-center gap-4 rounded-2xl bg-canvas p-4 transition-colors hover:bg-surface-muted focus:ring-4 focus:ring-focus/30 focus:outline-none"
							>
								<div
									class="flex size-11 shrink-0 items-center justify-center rounded-full bg-white text-brand"
								>
									<KeyRound aria-hidden="true" size={20} strokeWidth={2} />
								</div>
								<div class="min-w-0 flex-1">
									<h4 class="font-bold text-ink">Personas con acceso</h4>
									<p class="mt-1 text-sm leading-5 text-muted">
										{data.activeAccessCount}
										{data.activeAccessCount === 1 ? 'acceso activo' : 'accesos activos'}
									</p>
								</div>
								<ArrowUpRight
									aria-hidden="true"
									class="shrink-0 text-brand transition-transform group-hover:translate-x-0.5 group-hover:-translate-y-0.5"
									size={19}
									strokeWidth={2}
								/>
							</a>

							<a
								href={resolve('/patients/[id]/device', { id: data.patient.id })}
								class="group flex min-h-24 items-center gap-4 rounded-2xl bg-canvas p-4 transition-colors hover:bg-surface-muted focus:ring-4 focus:ring-focus/30 focus:outline-none"
							>
								<div
									class="flex size-11 shrink-0 items-center justify-center rounded-full bg-white text-brand"
								>
									<Smartphone aria-hidden="true" size={20} strokeWidth={2} />
								</div>
								<div class="min-w-0 flex-1">
									<h4 class="font-bold text-ink">Dispositivo</h4>
									<p class="mt-1 text-sm leading-5 text-muted">
										{data.assignment
											? 'Consulta el dispositivo asignado.'
											: 'Configura un dispositivo.'}
									</p>
								</div>
								<ArrowUpRight
									aria-hidden="true"
									class="shrink-0 text-brand transition-transform group-hover:translate-x-0.5 group-hover:-translate-y-0.5"
									size={19}
									strokeWidth={2}
								/>
							</a>
						</nav>
					</article>
				{/if}
			</div>
		</section>
	</div>
</main>
