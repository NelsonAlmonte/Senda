<script lang="ts">
	import { enhance, type SubmitFunction } from '$app/forms';
	import { resolve } from '$app/paths';
	import Alert from '#lib/components/ui/Alert.svelte';
	import Heading from '#lib/components/ui/Heading.svelte';
	import InfoItem from '#lib/components/ui/InfoItem.svelte';
	import {
		ArrowUpRight,
		BellRing,
		CircleAlert,
		CircleCheck,
		KeyRound,
		MapPinned,
		PencilLine,
		ShieldCheck,
		Smartphone,
		UserRound,
		UsersRound,
		HeartHandshake,
		Map
	} from '@lucide/svelte';
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

<main id="contenido-principal" class="px-5 py-8 sm:px-8 lg:px-0">
	<div class="w-full">
		{#if updateResult?.successMessage}
			<div class="mb-8 max-w-3xl">
				<Alert
					icon={CircleCheck}
					title="Datos actualizados"
					subtitle={updateResult.successMessage}
					color="positive"
				/>
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
								class="mt-6 rounded-2xl focus:ring-4 focus:ring-red-700/20 focus:outline-none"
							>
								<Alert
									icon={CircleAlert}
									title="Revisa los datos del paciente"
									subtitle={errors.form ?? 'Corrige los campos indicados e inténtalo nuevamente.'}
									color="danger"
								/>
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
							<div class="rounded-2xl bg-surface-muted p-4">
								<dt class="text-sm font-semibold text-muted">Nombre</dt>
								<dd class=" font-bold text-ink">{data.patient.firstName}</dd>
							</div>
							<div class="rounded-2xl bg-surface-muted p-4">
								<dt class="text-sm font-semibold text-muted">Apellido</dt>
								<dd class=" font-bold text-ink">{data.patient.lastName}</dd>
							</div>
						</dl>
					{/if}
				</div>

				{#if data.isAdmin}
					<div class="border-t border-ink/10 px-6 py-4">
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
					<Heading
						icon={HeartHandshake}
						title="Resumen del paciente"
						subtitle="Contexto administrativo y elementos vinculados."
					/>
				</div>

				<div class="mt-8 grid gap-4 sm:grid-cols-2">
					<div class="sm:col-span-2">
						<InfoItem
							icon={UsersRound}
							title="Grupo"
							info={data.patient.group?.name ?? 'Sin grupo visible'}
							tone="positive"
						/>
					</div>

					<InfoItem
						icon={Smartphone}
						title="Dispositivo"
						info={data.assignment ? data.assignment.device.serialNumber : 'Sin configurar'}
						tone={data.assignment ? 'positive' : 'neutral'}
					/>

					{#if data.isAdmin}
						<InfoItem
							icon={KeyRound}
							title="Accesos activos"
							info={String(data.activeAccessCount)}
							tone={data.activeAccessCount > 0 ? 'positive' : 'neutral'}
						/>
					{/if}
				</div>
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
						subtitle="Consulta la ubicación, las zonas permitidas y los episodios."
					/>

					<nav
						class={['mt-6 grid gap-3', !data.isAdmin && 'sm:grid-cols-2']}
						aria-label="Operaciones de monitoreo"
					>
						{#if data.assignment}
							<a
								href={resolve('/patients/[id]/map', { id: data.patient.id })}
								class="group flex min-h-24 items-center gap-4 rounded-2xl bg-surface-muted p-4 transition-colors hover:bg-surface-muted focus:ring-4 focus:ring-focus/30 focus:outline-none"
							>
								<div
									class="flex size-11 shrink-0 items-center justify-center rounded-full bg-white text-brand"
								>
									<Map aria-hidden="true" size={20} strokeWidth={2} />
								</div>
								<div class="min-w-0 flex-1">
									<h4 class="font-bold text-ink">Mapa y ubicación</h4>
									<p class=" text-sm leading-5 text-muted">Última ubicación y geocercas activas.</p>
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
							class="group flex min-h-24 items-center gap-4 rounded-2xl bg-surface-muted p-4 transition-colors hover:bg-surface-muted focus:ring-4 focus:ring-focus/30 focus:outline-none"
						>
							<div
								class="flex size-11 shrink-0 items-center justify-center rounded-full bg-white text-brand"
							>
								<ShieldCheck aria-hidden="true" size={20} strokeWidth={2} />
							</div>
							<div class="min-w-0 flex-1">
								<h4 class="font-bold text-ink">Geocercas</h4>
								<p class=" text-sm leading-5 text-muted">Zonas circulares permitidas.</p>
							</div>
							<ArrowUpRight
								aria-hidden="true"
								class="shrink-0 text-brand transition-transform group-hover:translate-x-0.5 group-hover:-translate-y-0.5"
								size={19}
								strokeWidth={2}
							/>
						</a>

						<a
							href={resolve('/patients/[id]/episodes', { id: data.patient.id })}
							class="group flex min-h-24 items-center gap-4 rounded-2xl bg-surface-muted p-4 transition-colors hover:bg-surface-muted focus:ring-4 focus:ring-focus/30 focus:outline-none"
						>
							<div
								class="flex size-11 shrink-0 items-center justify-center rounded-full bg-white text-brand"
							>
								<BellRing aria-hidden="true" size={20} strokeWidth={2} />
							</div>
							<div class="min-w-0 flex-1">
								<h4 class="font-bold text-ink">Historial de episodios</h4>
								<p class="text-sm leading-5 text-muted">Salidas confirmadas y resueltas.</p>
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
								class="group flex min-h-24 items-center gap-4 rounded-2xl bg-surface-muted p-4 transition-colors hover:bg-surface-muted focus:ring-4 focus:ring-focus/30 focus:outline-none"
							>
								<div
									class="flex size-11 shrink-0 items-center justify-center rounded-full bg-white text-brand"
								>
									<KeyRound aria-hidden="true" size={20} strokeWidth={2} />
								</div>
								<div class="min-w-0 flex-1">
									<h4 class="font-bold text-ink">Personas con acceso</h4>
									<p class=" text-sm leading-5 text-muted">
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
								class="group flex min-h-24 items-center gap-4 rounded-2xl bg-surface-muted p-4 transition-colors hover:bg-surface-muted focus:ring-4 focus:ring-focus/30 focus:outline-none"
							>
								<div
									class="flex size-11 shrink-0 items-center justify-center rounded-full bg-white text-brand"
								>
									<Smartphone aria-hidden="true" size={20} strokeWidth={2} />
								</div>
								<div class="min-w-0 flex-1">
									<h4 class="font-bold text-ink">Dispositivo</h4>
									<p class=" text-sm leading-5 text-muted">
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
