<script lang="ts">
	import { enhance, type SubmitFunction } from '$app/forms';
	import CircleAlert from '@lucide/svelte/icons/circle-alert';
	import LogIn from '@lucide/svelte/icons/log-in';
	import Settings2 from '@lucide/svelte/icons/settings-2';
	import Alert from '#lib/components/ui/Alert.svelte';
	import AuthShell from '#lib/components/ui/AuthShell.svelte';
	import PasswordField from '#lib/components/ui/PasswordField.svelte';
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

<AuthShell
	icon={LogIn}
	eyebrow="Acceso seguro"
	title="Qué bueno tenerte de vuelta."
	description="Entra para consultar las personas, ubicaciones y episodios que tienes autorizados."
	alternatePrompt="¿Aún no tienes cuenta?"
	alternateHref="/auth/register"
	alternateLabel="Regístrate"
>
	<div class="space-y-5">
		{#if !data.supabaseConfigured}
			<Alert
				title="Configuración incompleta"
				subtitle="Este entorno aún no tiene configuradas las variables públicas de Supabase."
				icon={Settings2}
				color="warning"
			/>
		{/if}

		{#if errors.form}
			<div
				data-form-error
				tabindex="-1"
				class="rounded-2xl focus:ring-4 focus:ring-red-700/20 focus:outline-none"
			>
				<Alert
					title="No pudimos iniciar sesión"
					subtitle={errors.form}
					icon={CircleAlert}
					color="danger"
				/>
			</div>
		{/if}

		<form
			method="POST"
			use:enhance={enhanceForm}
			class="space-y-5"
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

			<PasswordField
				id="password"
				name="password"
				label="Contraseña"
				autocomplete="current-password"
				error={errors.password}
			/>

			<button
				type="submit"
				disabled={submitting || !data.supabaseConfigured}
				class="inline-flex min-h-12 w-full cursor-pointer items-center justify-center gap-2 rounded-xl bg-brand px-5 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
			>
				<LogIn aria-hidden="true" size={19} strokeWidth={2} />
				{submitting ? 'Iniciando sesión…' : 'Iniciar sesión'}
			</button>
		</form>
	</div>
</AuthShell>
