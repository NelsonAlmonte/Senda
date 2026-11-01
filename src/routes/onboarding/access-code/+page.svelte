<script lang="ts">
	import { enhance, type SubmitFunction } from '$app/forms';
	import { resolve } from '$app/paths';
	import ArrowLeft from '@lucide/svelte/icons/arrow-left';
	import ArrowRight from '@lucide/svelte/icons/arrow-right';
	import Building2 from '@lucide/svelte/icons/building-2';
	import CheckCircle2 from '@lucide/svelte/icons/circle-check-big';
	import CircleAlert from '@lucide/svelte/icons/circle-alert';
	import Eye from '@lucide/svelte/icons/eye';
	import House from '@lucide/svelte/icons/house';
	import KeyRound from '@lucide/svelte/icons/key-round';
	import MapPinned from '@lucide/svelte/icons/map-pinned';
	import RotateCcw from '@lucide/svelte/icons/rotate-ccw';
	import ShieldCheck from '@lucide/svelte/icons/shield-check';
	import UserRound from '@lucide/svelte/icons/user-round';
	import Alert from '#lib/components/ui/Alert.svelte';
	import InfoItem from '#lib/components/ui/InfoItem.svelte';
	import Initials from '#lib/components/ui/Initials.svelte';
	import type { PageProps } from './$types';

	let { form }: PageProps = $props();
	let submitting = $state<'preview' | 'accept' | null>(null);
	let errors = $derived((form?.errors ?? {}) as Record<string, string>);
	let submittedCode = $derived(form && 'code' in form ? (form.code as string) : '');
	let isPreview = $derived(form?.stage === 'preview' && Boolean(form.preview));
	let isSuccess = $derived(form?.stage === 'success');
	let patientName = $derived(
		form?.preview ? `${form.preview.firstName} ${form.preview.lastName}`.trim() : ''
	);
	let successPatientName = $derived(
		form && 'patientName' in form && typeof form.patientName === 'string' ? form.patientName : ''
	);
	let groupLabel = $derived(form?.preview?.groupType === 'CARE_CENTER' ? 'Centro' : 'Familia');

	function enhanceFor(stage: 'preview' | 'accept'): SubmitFunction {
		return () => {
			submitting = stage;

			return async ({ result, update }) => {
				await update({ reset: false });
				submitting = null;

				requestAnimationFrame(() => {
					if (result.type === 'failure') {
						const errorSummary = document.querySelector<HTMLElement>('[data-access-code-error]');
						if (errorSummary) {
							errorSummary.focus();
							return;
						}

						document.querySelector<HTMLInputElement>('#onboarding-code')?.focus();
						return;
					}

					if (stage === 'accept') {
						document.querySelector<HTMLElement>('[data-access-code-success]')?.focus();
					}
				});
			};
		};
	}

	const enhancePreview = enhanceFor('preview');
	const enhanceAccept = enhanceFor('accept');
</script>

<svelte:head>
	<title>Código de acceso | Primeros pasos | Senda</title>
	<meta
		name="description"
		content="Usa un código de acceso para comenzar a monitorear a una persona en Senda."
	/>
</svelte:head>

<main
	id="contenido-principal"
	class="grid min-h-dvh place-items-center px-5 py-10 sm:px-8 sm:py-14"
>
	<div class="w-full max-w-3xl">
		<header class="text-center">
			<div class="mt-6 inline-flex items-center gap-3">
				<span
					class="grid size-11 place-items-center rounded-xl bg-ink text-lg font-bold text-white"
					aria-hidden="true">S</span
				>
				<span class="text-2xl font-bold text-ink">Senda</span>
			</div>

			<p class="mt-8 text-sm font-bold tracking-wide text-brand uppercase">
				Primeros pasos · Acceso por código
			</p>
			<h1 class="mx-auto mt-3 max-w-2xl text-3xl font-bold text-balance text-ink sm:text-4xl">
				{isSuccess
					? 'Ya puedes acompañar desde Senda'
					: isPreview
						? 'Confirma a quién vas a monitorear'
						: 'Ingresa el código que recibiste'}
			</h1>
			<p class="mx-auto mt-5 max-w-2xl text-lg leading-8 text-muted">
				{isSuccess
					? 'El acceso quedó guardado en tu cuenta y está listo para usarse.'
					: isPreview
						? 'Revisa estos datos antes de aceptar. El código se utilizará solamente cuando confirmes.'
						: 'La persona administradora debe compartirte un código de un solo uso. Con él tendrás acceso únicamente al paciente indicado.'}
			</p>
		</header>

		<section class="mx-auto mt-10 max-w-2xl" aria-label="Acceso para monitorear">
			{#if isSuccess}
				<article class="overflow-hidden rounded-2xl bg-white shadow-sm">
					<div class="p-6 text-center sm:p-8">
						<div
							class="mx-auto flex size-14 items-center justify-center rounded-full bg-surface-muted text-brand"
						>
							<CheckCircle2 aria-hidden="true" size={28} strokeWidth={2} />
						</div>
						<h2
							data-access-code-success
							tabindex="-1"
							class="mt-6 text-2xl font-bold text-ink focus:outline-none"
						>
							Acceso activado
						</h2>
						<p class="mx-auto mt-3 max-w-lg leading-7 text-muted">
							{successPatientName
								? `Ahora puedes monitorear a ${successPatientName} desde tu lista de pacientes.`
								: 'Ahora puedes consultar a la persona autorizada desde tu lista de pacientes.'}
						</p>

						<div class="mt-8 grid gap-4 text-left sm:grid-cols-2">
							<InfoItem
								icon={Eye}
								title="Acceso Monitor"
								info="Podrás revisar su ubicación, alertas y zonas seguras."
								tone="positive"
							/>
							<InfoItem
								icon={ShieldCheck}
								title="Acceso individual"
								info="El permiso corresponde únicamente a este paciente."
							/>
						</div>
					</div>

					<div class="border-t border-ink/10 p-4">
						<a
							href={resolve('/patients')}
							class="inline-flex min-h-12 w-full items-center justify-center gap-2 rounded-full bg-brand px-6 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none sm:w-auto"
						>
							Ver mis pacientes
							<ArrowRight aria-hidden="true" size={19} strokeWidth={2} />
						</a>
					</div>
				</article>
			{:else}
				<article class="overflow-hidden rounded-2xl bg-white text-left shadow-sm">
					<div class="p-6 sm:p-8">
						{#if isPreview && form?.preview}
							<div class="flex items-start gap-4">
								<div
									class="flex size-12 shrink-0 items-center justify-center rounded-full bg-surface-muted text-ink"
								>
									<UserRound aria-hidden="true" size={23} strokeWidth={2} />
								</div>
								<div>
									<h2 class="text-xl font-bold text-ink">Paciente encontrado</h2>
									<p class="mt-2 leading-7 text-muted">
										Comprueba que reconoces a esta persona y su espacio de cuidado.
									</p>
								</div>
							</div>

							<div class="mt-8 flex min-w-0 items-center gap-4">
								<Initials text={patientName} />
								<div class="min-w-0">
									<p class="text-sm font-bold text-muted">Paciente</p>
									<h3 class="mt-1 text-xl font-bold wrap-break-word text-ink">{patientName}</h3>
								</div>
							</div>

							<div class="mt-8 grid gap-4 sm:grid-cols-2">
								<InfoItem
									icon={form.preview.groupType === 'CARE_CENTER' ? Building2 : House}
									title={groupLabel}
									info={form.preview.groupName}
								/>
								<InfoItem
									icon={Eye}
									title="Permiso que recibirás"
									info="Monitor de este paciente"
									tone="positive"
								/>
							</div>
						{:else}
							<div class="flex items-start gap-4">
								<div
									class="flex size-12 shrink-0 items-center justify-center rounded-full bg-surface-muted text-ink"
								>
									<KeyRound aria-hidden="true" size={23} strokeWidth={2} />
								</div>
								<div>
									<h2 class="text-xl font-bold text-ink">Tu código de acceso</h2>
									<p class="mt-2 leading-7 text-muted">
										Puedes escribirlo con o sin guiones. No distingue entre mayúsculas y minúsculas.
									</p>
								</div>
							</div>

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
								id="onboarding-access-code-form"
								method="POST"
								action="?/preview"
								use:enhance={enhancePreview}
								aria-busy={submitting === 'preview'}
								class="mt-8"
							>
								<label for="onboarding-code" class="text-sm font-bold text-ink">
									Código de acceso
								</label>
								<input
									id="onboarding-code"
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
									aria-describedby={errors.code
										? 'onboarding-code-help onboarding-code-error'
										: 'onboarding-code-help'}
									class={[
										'mt-2 min-h-12 w-full rounded-xl border bg-white px-4 font-mono text-base tracking-wider text-ink uppercase transition outline-none placeholder:text-muted/60 focus:border-focus focus:ring-4 focus:ring-focus/20',
										errors.code ? 'border-red-700/60' : 'border-ink/20'
									]}
								/>
								<p id="onboarding-code-help" class="mt-2 text-sm leading-6 text-muted">
									Formato: 12 caracteres. Los guiones son opcionales.
								</p>
								{#if errors.code}
									<p id="onboarding-code-error" class="mt-2 text-sm font-semibold text-red-800">
										{errors.code}
									</p>
								{/if}
							</form>

							<div class="mt-8 grid gap-3 rounded-2xl bg-canvas p-4 sm:grid-cols-2">
								<div class="flex gap-3">
									<ShieldCheck
										aria-hidden="true"
										class="mt-0.5 shrink-0 text-brand"
										size={20}
										strokeWidth={2}
									/>
									<p class="text-sm leading-6 text-ink">El código es de un solo uso.</p>
								</div>
								<div class="flex gap-3">
									<MapPinned
										aria-hidden="true"
										class="mt-0.5 shrink-0 text-brand"
										size={20}
										strokeWidth={2}
									/>
									<p class="text-sm leading-6 text-ink">No da acceso a todo el grupo.</p>
								</div>
							</div>
						{/if}
					</div>

					<div
						class="flex flex-col gap-3 border-t border-ink/10 p-4 sm:flex-row sm:items-center sm:justify-end"
					>
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
										class="inline-flex min-h-12 w-full cursor-pointer items-center justify-center gap-2 rounded-full bg-brand px-6 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50 sm:w-auto"
									>
										<ShieldCheck aria-hidden="true" size={19} strokeWidth={2} />
										{submitting === 'accept' ? 'Activando acceso…' : 'Aceptar y monitorear'}
									</button>
								</form>
								<a
									href={resolve('/onboarding/access-code')}
									class="inline-flex min-h-12 items-center justify-center gap-2 rounded-full px-5 font-bold text-brand transition hover:bg-surface-muted focus:ring-4 focus:ring-focus/25 focus:outline-none"
								>
									<RotateCcw aria-hidden="true" size={19} strokeWidth={2} />
									Usar otro código
								</a>
							</div>
						{:else}
							<button
								type="submit"
								form="onboarding-access-code-form"
								disabled={submitting !== null}
								class="inline-flex min-h-12 w-full cursor-pointer items-center justify-center gap-2 rounded-full bg-brand px-6 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50 sm:w-auto"
							>
								<Eye aria-hidden="true" size={19} strokeWidth={2} />
								{submitting === 'preview' ? 'Revisando código…' : 'Revisar código'}
							</button>
						{/if}
					</div>
				</article>
			{/if}
		</section>

		{#if !isSuccess}
			<div class="mt-6 flex justify-center">
				<a
					href={resolve('/onboarding')}
					class="inline-flex min-h-12 items-center gap-2 rounded-full px-4 font-bold text-brand transition hover:bg-white focus:ring-4 focus:ring-focus/25 focus:outline-none"
				>
					<ArrowLeft aria-hidden="true" size={19} strokeWidth={2} />
					Volver a las opciones
				</a>
			</div>
		{/if}
	</div>
</main>
