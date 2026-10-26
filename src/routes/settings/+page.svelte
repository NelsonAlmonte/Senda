<script lang="ts">
	import { enhance, type SubmitFunction } from '$app/forms';
	import { resolve } from '$app/paths';
	import PushNotificationSettings from '#lib/push/PushNotificationSettings.svelte';
	import type { PageProps } from './$types';

	let { data, form }: PageProps = $props();
	let submitting = $state(false);

	const enhanceForm: SubmitFunction = () => {
		submitting = true;
		return async ({ update }) => {
			await update({ reset: false });
			submitting = false;
		};
	};
</script>

<svelte:head><title>Mi perfil | Senda</title></svelte:head>

<main id="contenido-principal" class="min-h-dvh px-5 py-8 sm:px-8">
	<div class="mx-auto w-full max-w-2xl">
		<a
			href={resolve('/dashboard')}
			class="inline-flex min-h-12 items-center rounded-xl font-bold text-brand focus:ring-4 focus:ring-focus/30 focus:outline-none"
			><span aria-hidden="true">←</span><span class="ml-2">Volver al panel</span></a
		>

		<section
			class="mt-6 rounded-3xl border border-white/80 bg-white p-6 shadow-xl shadow-brand/8 sm:p-8"
		>
			<p class="text-sm font-bold tracking-[0.14em] text-brand uppercase">Configuración</p>
			<h1 class="mt-2 text-3xl font-bold text-ink">Mi perfil</h1>
			<p class="mt-3 leading-7 break-words text-muted">
				Cuenta: {data.user.email ?? 'Correo no disponible'}
			</p>

			{#if !data.profile}
				<div
					class="mt-6 rounded-2xl border border-amber-700/25 bg-amber-50 p-4 text-sm leading-6 text-amber-950"
					role="status"
				>
					El perfil estará disponible después de aplicar la migración de desarrollo.
				</div>
			{/if}

			{#if form?.success}
				<p
					class="mt-6 rounded-2xl bg-surface-muted p-4 text-sm font-semibold text-ink"
					role="status"
				>
					{form.message}
				</p>
			{:else if form?.error}
				<p
					class="mt-6 rounded-2xl border border-red-700/25 bg-red-50 p-4 text-sm font-semibold text-red-950"
					role="alert"
				>
					{form.error}
				</p>
			{/if}

			<form method="POST" use:enhance={enhanceForm} class="mt-7 space-y-5">
				<div>
					<label for="fullName" class="text-sm font-bold text-ink">Nombre completo</label>
					<input
						id="fullName"
						name="fullName"
						type="text"
						autocomplete="name"
						maxlength="120"
						required
						value={form?.fullName ?? data.profile?.full_name ?? ''}
						aria-invalid={form?.error ? 'true' : undefined}
						aria-describedby={form?.error ? 'profile-name-error' : undefined}
						class="mt-2 min-h-12 w-full rounded-xl border border-ink/20 bg-white px-4 text-base text-ink transition outline-none focus:border-focus focus:ring-4 focus:ring-focus/20"
					/>
					{#if form?.error}<span id="profile-name-error" class="sr-only">{form.error}</span>{/if}
				</div>
				<button
					type="submit"
					disabled={submitting || !data.profile}
					class="min-h-12 cursor-pointer rounded-xl bg-brand px-5 font-bold text-white focus:ring-4 focus:ring-focus/35 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
					>{submitting ? 'Guardando…' : 'Guardar perfil'}</button
				>
			</form>
		</section>

		<PushNotificationSettings />
	</div>
</main>
