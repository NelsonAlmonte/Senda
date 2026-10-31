<script lang="ts">
	import { enhance, type SubmitFunction } from '$app/forms';
	import { resolve } from '$app/paths';
	import Building2 from '@lucide/svelte/icons/building-2';
	import CircleAlert from '@lucide/svelte/icons/circle-alert';
	import Eye from '@lucide/svelte/icons/eye';
	import House from '@lucide/svelte/icons/house';
	import KeyRound from '@lucide/svelte/icons/key-round';
	import MapPinned from '@lucide/svelte/icons/map-pinned';
	import ShieldCheck from '@lucide/svelte/icons/shield-check';
	import UserRound from '@lucide/svelte/icons/user-round';
	import Alert from '#lib/components/ui/Alert.svelte';
	import Heading from '#lib/components/ui/Heading.svelte';
	import InfoItem from '#lib/components/ui/InfoItem.svelte';
	import Initials from '#lib/components/ui/Initials.svelte';
	import type { PageProps } from './$types';

	let { form }: PageProps = $props();
	let submitting = $state<'preview' | 'accept' | null>(null);
	let errors = $derived((form?.errors ?? {}) as Record<string, string>);
	let submittedCode = $derived(form && 'code' in form ? (form.code as string) : '');
	let isPreview = $derived(form?.stage === 'preview' && Boolean(form.preview));
	let patientName = $derived(
		form?.preview ? `${form.preview.firstName} ${form.preview.lastName}`.trim() : ''
	);
	let groupLabel = $derived(form?.preview?.groupType === 'CARE_CENTER' ? 'Centro' : 'Familia');
	let groupIcon = $derived(form?.preview?.groupType === 'CARE_CENTER' ? Building2 : House);

	function enhanceFor(stage: 'preview' | 'accept'): SubmitFunction {
		return () => {
			submitting = stage;

			return async ({ result, update }) => {
				await update({ reset: false });
				submitting = null;

				if (result.type === 'failure') {
					requestAnimationFrame(() => {
						const errorSummary = document.querySelector<HTMLElement>('[data-access-code-error]');
						if (errorSummary) {
							errorSummary.focus();
							return;
						}

						document.querySelector<HTMLInputElement>('#code')?.focus();
					});
				}
			};
		};
	}

	const enhancePreview = enhanceFor('preview');
	const enhanceAccept = enhanceFor('accept');
</script>

<svelte:head>
	<title>Ingresar código | Senda</title>
	<meta name="description" content="Acepta acceso para monitorear un paciente en Senda." />
</svelte:head>

<main id="contenido-principal" class="px-5 py-8 sm:px-8 lg:px-0">
	<section class="w-full" aria-labelledby="access-code-title">
		<h2 id="access-code-title" class="mb-8 text-2xl font-bold text-ink">
			{isPreview ? 'Confirmar acceso' : 'Ingresar código'}
		</h2>

		<div class="grid items-start gap-6 xl:grid-cols-12">
			<article class="overflow-hidden rounded-2xl bg-white shadow-sm xl:col-span-8">
				<div class="p-6">
					{#if isPreview && form?.preview}
						<Heading
							icon={UserRound}
							title="Paciente encontrado"
							subtitle="Revisa la información antes de aceptar el acceso."
						/>

						<div class="mt-8 flex min-w-0 items-center gap-4">
							<Initials text={patientName} />
							<div class="min-w-0">
								<p class="text-sm font-bold text-muted">Paciente</p>
								<h3 class="mt-1 text-xl font-bold wrap-break-word text-ink">{patientName}</h3>
							</div>
						</div>

						<div class="mt-8 grid gap-4 sm:grid-cols-2">
							<InfoItem icon={groupIcon} title={groupLabel} info={form.preview.groupName} />
							<InfoItem
								icon={Eye}
								title="Permiso que recibirás"
								info="Monitor de este paciente"
								tone="positive"
							/>
						</div>
					{:else}
						<Heading
							icon={KeyRound}
							title="Código de acceso"
							subtitle="Escribe el código que te compartió la persona administradora del paciente."
						/>

						{#if errors.form}
							<div
								data-access-code-error
								tabindex="-1"
								class="mt-6 rounded-2xl focus:ring-4 focus:ring-red-700/20 focus:outline-none"
							>
								<Alert
									icon={CircleAlert}
									title="No pudimos aceptar el acceso"
									subtitle={errors.form}
									color="danger"
								/>
							</div>
						{/if}

						<form
							id="access-code-form"
							method="POST"
							action="?/preview"
							use:enhance={enhancePreview}
							aria-busy={submitting === 'preview'}
							class="mt-8"
						>
							<label for="code" class="text-sm font-bold text-ink">Código de acceso</label>
							<input
								id="code"
								name="code"
								type="text"
								autocomplete="one-time-code"
								autocapitalize="characters"
								spellcheck="false"
								maxlength="14"
								required
								value={submittedCode}
								placeholder="AB12-CD34-EF56"
								aria-invalid={errors.code ? 'true' : undefined}
								aria-describedby={errors.code ? 'code-help code-error' : 'code-help'}
								class={[
									'mt-2 min-h-12 w-full rounded-xl border bg-white px-4 font-mono text-base tracking-wider text-ink uppercase transition outline-none placeholder:text-muted/60 focus:border-focus focus:ring-4 focus:ring-focus/20',
									errors.code ? 'border-red-700/60' : 'border-ink/20'
								]}
							/>
							<p id="code-help" class="mt-2 text-sm leading-6 text-muted">
								Usa los 12 caracteres. Los guiones son opcionales.
							</p>
							{#if errors.code}
								<p id="code-error" class="mt-2 text-sm font-semibold text-red-800">
									{errors.code}
								</p>
							{/if}
						</form>
					{/if}
				</div>

				<div class="border-t border-ink/10 p-4">
					{#if isPreview && form?.preview}
						<div class="flex flex-col gap-3 sm:flex-row sm:items-center">
							<form
								method="POST"
								action="?/accept"
								use:enhance={enhanceAccept}
								aria-busy={submitting === 'accept'}
							>
								<input type="hidden" name="code" value={form.code} />
								<button
									type="submit"
									disabled={submitting !== null}
									class="min-h-12 w-full cursor-pointer rounded-full bg-brand px-6 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50 sm:w-auto"
								>
									{submitting === 'accept' ? 'Aceptando…' : 'Aceptar y monitorear'}
								</button>
							</form>
							<a
								href={resolve('/access-code')}
								class="inline-flex min-h-12 items-center justify-center rounded-full px-5 font-bold text-brand transition hover:bg-surface-muted focus:ring-4 focus:ring-focus/25 focus:outline-none"
							>
								Usar otro código
							</a>
						</div>
					{:else}
						<button
							type="submit"
							form="access-code-form"
							disabled={submitting !== null}
							class="min-h-12 w-full cursor-pointer rounded-full bg-brand px-6 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50 sm:w-auto"
						>
							{submitting === 'preview' ? 'Revisando…' : 'Revisar código'}
						</button>
					{/if}
				</div>
			</article>

			<aside class="rounded-2xl bg-white p-6 shadow-sm xl:col-span-4">
				<Heading
					icon={ShieldCheck}
					title={isPreview ? 'Al aceptar el acceso' : 'Antes de continuar'}
					subtitle="El código protege el acceso a una sola persona bajo tu cuidado."
				/>

				<div class="mt-8 grid gap-4">
					<InfoItem
						icon={UserRound}
						title="Acceso individual"
						info="No recibirás acceso a los demás pacientes del grupo."
					/>
					<InfoItem
						icon={MapPinned}
						title="Permiso Monitor"
						info="Podrás consultar la ubicación y las alertas, y configurar zonas seguras."
					/>
					<InfoItem
						icon={KeyRound}
						title="Código de un solo uso"
						info="Después de aceptarlo, nadie podrá volver a utilizarlo."
					/>
				</div>
			</aside>
		</div>
	</section>
</main>
