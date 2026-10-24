<script lang="ts">
	import { enhance } from '$app/forms';
	import { resolve } from '$app/paths';
	import type { PageProps } from './$types';

	let { form }: PageProps = $props();
	let errors = $derived((form?.errors ?? {}) as Record<string, string>);
	let submittedCode = $derived(form && 'code' in form ? (form.code as string) : '');
</script>

<svelte:head>
	<title>Ingresar código | Senda</title>
	<meta name="description" content="Acepta acceso para monitorear un paciente en Senda." />
</svelte:head>

<main id="contenido-principal" class="min-h-dvh px-5 py-8 sm:px-8 lg:px-12">
	<section class="mx-auto w-full max-w-2xl py-8 sm:py-12">
		<a
			href={resolve('/onboarding')}
			class="inline-flex min-h-12 items-center rounded-xl font-bold text-brand focus:ring-4 focus:ring-focus/30 focus:outline-none"
		>
			<span aria-hidden="true">←</span><span class="ml-2">Volver a las opciones</span>
		</a>

		<div
			class="mt-5 rounded-3xl border border-white/80 bg-white p-6 shadow-xl shadow-brand/8 sm:p-8"
		>
			<p class="text-sm font-bold tracking-[0.14em] text-brand uppercase">Acceso compartido</p>
			<h1 class="mt-2 text-3xl font-bold tracking-tight text-ink">Monitorea a un familiar</h1>
			<p class="mt-3 leading-7 text-muted">
				Introduce el código que te dio la persona administradora. Obtendrás acceso únicamente al
				paciente indicado, no a todo su grupo.
			</p>

			{#if errors.form}
				<div
					class="mt-6 rounded-2xl border border-red-700/25 bg-red-50 p-4 text-sm text-red-950"
					role="alert"
				>
					{errors.form}
				</div>
			{/if}

			{#if form?.stage === 'preview' && form.preview}
				<div class="mt-7 rounded-2xl bg-surface-muted p-5">
					<p class="text-sm font-bold text-brand">Confirma el acceso</p>
					<h2 class="mt-2 text-xl font-bold text-ink">
						{form.preview.firstName}
						{form.preview.lastName}
					</h2>
					<p class="mt-1 text-sm text-muted">{form.preview.groupName}</p>
					<p class="mt-3 text-sm leading-6 text-muted">
						Tu rol será Monitor para este paciente. No podrás gestionar sus accesos administrativos.
					</p>
				</div>

				<form method="POST" action="?/accept" use:enhance class="mt-6">
					<input type="hidden" name="code" value={form.code} />
					<button
						class="min-h-12 w-full cursor-pointer rounded-xl bg-brand px-5 font-bold text-white focus:ring-4 focus:ring-focus/35 focus:outline-none"
					>
						Aceptar y monitorear
					</button>
				</form>
			{:else}
				<form method="POST" action="?/preview" use:enhance class="mt-7">
					<label for="code" class="text-sm font-bold text-ink">Código de acceso</label>
					<p id="code-help" class="mt-1 text-sm leading-6 text-muted">Formato: XXXX-XXXX-XXXX.</p>
					<input
						id="code"
						name="code"
						type="text"
						autocomplete="one-time-code"
						spellcheck="false"
						maxlength="14"
						required
						value={submittedCode}
						aria-invalid={errors.code ? 'true' : undefined}
						aria-describedby={errors.code ? 'code-help code-error' : 'code-help'}
						class="mt-2 min-h-12 w-full rounded-xl border border-ink/20 px-4 font-mono text-base tracking-wider uppercase outline-none focus:border-focus focus:ring-4 focus:ring-focus/20"
					/>
					{#if errors.code}
						<p id="code-error" class="mt-2 text-sm font-semibold text-red-800">
							{errors.code}
						</p>
					{/if}
					<button
						class="mt-6 min-h-12 w-full cursor-pointer rounded-xl bg-brand px-5 font-bold text-white focus:ring-4 focus:ring-focus/35 focus:outline-none"
					>
						Revisar código
					</button>
				</form>
			{/if}
		</div>
	</section>
</main>
