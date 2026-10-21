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
				document.querySelector<HTMLElement>('[data-form-error]')?.focus();
			}
		};
	};
</script>

<svelte:head>
	<title>Iniciar sesión | Senda</title>
	<meta name="description" content="Accede de forma segura a tu cuenta de Senda." />
</svelte:head>

<main id="contenido-principal" class="grid min-h-dvh place-items-center px-5 py-10 sm:px-8">
	<section
		class="w-full max-w-md rounded-3xl border border-white/80 bg-white p-6 shadow-xl shadow-brand/8 sm:p-8"
	>
		<a
			href={resolve('/')}
			class="inline-flex min-h-12 items-center rounded-xl font-bold text-brand focus:ring-4 focus:ring-focus/30 focus:outline-none"
		>
			<span aria-hidden="true">←</span><span class="ml-2">Volver a Senda</span>
		</a>

		<p class="mt-7 text-sm font-bold tracking-[0.14em] text-brand uppercase">Acceso seguro</p>
		<h1 class="mt-2 text-3xl font-bold tracking-tight text-ink">Inicia sesión</h1>
		<p class="mt-3 leading-7 text-muted">
			Consulta únicamente los pacientes para los que tengas autorización.
		</p>

		{#if !data.supabaseConfigured}
			<div
				class="mt-6 rounded-2xl border border-amber-700/25 bg-amber-50 p-4 text-sm leading-6 text-amber-950"
				role="status"
			>
				Este entorno aún no tiene configuradas las variables públicas de Supabase.
			</div>
		{/if}

		{#if errors.form}
			<div
				data-form-error
				tabindex="-1"
				class="mt-6 rounded-2xl border border-red-700/25 bg-red-50 p-4 text-sm leading-6 text-red-950 focus:ring-4 focus:ring-red-700/20 focus:outline-none"
				role="alert"
			>
				{errors.form}
			</div>
		{/if}

		<form
			method="POST"
			use:enhance={enhanceForm}
			class="mt-7 space-y-5"
			aria-label="Formulario de inicio de sesión"
		>
			<div>
				<label for="email" class="text-sm font-bold text-ink">Correo electrónico</label>
				<input
					id="email"
					name="email"
					type="email"
					autocomplete="email"
					inputmode="email"
					required
					value={form?.email ?? ''}
					aria-invalid={errors.email ? 'true' : undefined}
					aria-describedby={errors.email ? 'email-error' : undefined}
					class="mt-2 min-h-12 w-full rounded-xl border border-ink/20 bg-white px-4 text-base text-ink transition outline-none focus:border-focus focus:ring-4 focus:ring-focus/20"
				/>
				{#if errors.email}<p id="email-error" class="mt-2 text-sm font-semibold text-red-800">
						{errors.email}
					</p>{/if}
			</div>

			<div>
				<label for="password" class="text-sm font-bold text-ink">Contraseña</label>
				<input
					id="password"
					name="password"
					type="password"
					autocomplete="current-password"
					required
					aria-invalid={errors.password ? 'true' : undefined}
					aria-describedby={errors.password ? 'password-error' : undefined}
					class="mt-2 min-h-12 w-full rounded-xl border border-ink/20 bg-white px-4 text-base text-ink transition outline-none focus:border-focus focus:ring-4 focus:ring-focus/20"
				/>
				{#if errors.password}<p id="password-error" class="mt-2 text-sm font-semibold text-red-800">
						{errors.password}
					</p>{/if}
			</div>

			<button
				type="submit"
				disabled={submitting || !data.supabaseConfigured}
				class="min-h-12 w-full cursor-pointer rounded-xl bg-brand px-5 font-bold text-white shadow-sm transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
			>
				{submitting ? 'Iniciando sesión…' : 'Iniciar sesión'}
			</button>
		</form>

		<p class="mt-7 text-center leading-7 text-muted">
			¿Aún no tienes cuenta?
			<a
				href={resolve('/auth/register')}
				class="rounded font-bold text-brand underline decoration-brand/30 underline-offset-4 focus:ring-4 focus:ring-focus/30 focus:outline-none"
				>Regístrate</a
			>
		</p>
	</section>
</main>
