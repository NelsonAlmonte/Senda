<script lang="ts">
	import { enhance, type SubmitFunction } from '$app/forms';
	import CircleAlert from '@lucide/svelte/icons/circle-alert';
	import CircleCheck from '@lucide/svelte/icons/circle-check';
	import Settings2 from '@lucide/svelte/icons/settings-2';
	import UserPlus from '@lucide/svelte/icons/user-plus';
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
	<title>Crear cuenta | Senda</title>
	<meta name="description" content="Crea una cuenta para comenzar a usar Senda." />
</svelte:head>

<AuthShell
	icon={UserPlus}
	eyebrow="Nueva cuenta"
	title="Empieza a cuidar con más contexto."
	description="Crea tu acceso y después podrás configurar Senda o ingresar el código que recibiste."
	alternatePrompt="¿Ya tienes cuenta?"
	alternateHref="/auth/login"
	alternateLabel="Inicia sesión"
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

		{#if form?.success}
			<Alert title="Cuenta creada" subtitle={form.message} icon={CircleCheck} color="positive" />
		{:else if errors.form}
			<div
				data-form-error
				tabindex="-1"
				class="rounded-2xl focus:ring-4 focus:ring-red-700/20 focus:outline-none"
			>
				<Alert
					title="No pudimos crear la cuenta"
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
			aria-label="Formulario de registro"
		>
			<div>
				<label for="fullName" class="text-sm font-bold text-ink">Nombre completo</label>
				<input
					id="fullName"
					name="fullName"
					type="text"
					autocomplete="name"
					maxlength="120"
					required
					value={form?.values?.fullName ?? ''}
					aria-invalid={errors.fullName ? 'true' : undefined}
					aria-describedby={errors.fullName ? 'full-name-error' : undefined}
					class="mt-2 min-h-12 w-full rounded-xl border border-ink/20 bg-white px-4 text-base text-ink transition outline-none focus:border-focus focus:ring-4 focus:ring-focus/20"
				/>
				{#if errors.fullName}<p
						id="full-name-error"
						class="mt-2 text-sm font-semibold text-red-800"
					>
						{errors.fullName}
					</p>{/if}
			</div>

			<div>
				<label for="email" class="text-sm font-bold text-ink">Correo electrónico</label>
				<input
					id="email"
					name="email"
					type="email"
					autocomplete="email"
					inputmode="email"
					required
					value={form?.values?.email ?? ''}
					aria-invalid={errors.email ? 'true' : undefined}
					aria-describedby={errors.email ? 'register-email-error' : undefined}
					class="mt-2 min-h-12 w-full rounded-xl border border-ink/20 bg-white px-4 text-base text-ink transition outline-none focus:border-focus focus:ring-4 focus:ring-focus/20"
				/>
				{#if errors.email}<p
						id="register-email-error"
						class="mt-2 text-sm font-semibold text-red-800"
					>
						{errors.email}
					</p>{/if}
			</div>

			<PasswordField
				id="password"
				name="password"
				label="Contraseña"
				autocomplete="new-password"
				minlength={8}
				help="Mínimo 8 caracteres. Puedes usar un gestor de contraseñas."
				error={errors.password}
			/>

			<PasswordField
				id="passwordConfirmation"
				name="passwordConfirmation"
				label="Confirma la contraseña"
				autocomplete="new-password"
				minlength={8}
				error={errors.passwordConfirmation}
			/>

			<button
				type="submit"
				disabled={submitting || !data.supabaseConfigured}
				class="inline-flex min-h-12 w-full cursor-pointer items-center justify-center gap-2 rounded-xl bg-brand px-5 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
			>
				<UserPlus aria-hidden="true" size={19} strokeWidth={2} />
				{submitting ? 'Creando cuenta…' : 'Crear cuenta'}
			</button>
		</form>
	</div>
</AuthShell>
