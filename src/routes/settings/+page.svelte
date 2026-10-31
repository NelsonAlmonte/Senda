<script lang="ts">
	import { enhance, type SubmitFunction } from '$app/forms';
	import { resolve } from '$app/paths';
	import {
		CalendarDays,
		CircleAlert,
		CircleCheck,
		LogOut,
		Mail,
		PencilLine,
		UserRound
	} from '@lucide/svelte';
	import Alert from '#lib/components/ui/Alert.svelte';
	import Heading from '#lib/components/ui/Heading.svelte';
	import InfoItem from '#lib/components/ui/InfoItem.svelte';
	import Initials from '#lib/components/ui/Initials.svelte';
	import { presentDateTime } from '#lib/locations/presentation.js';
	import PushNotificationSettings from '#lib/push/PushNotificationSettings.svelte';
	import type { PageProps } from './$types';

	let { data, form }: PageProps = $props();
	let submitting = $state(false);
	let displayName = $derived(
		data.profile?.full_name?.trim() || data.user.email?.split('@')[0] || 'Usuario de Senda'
	);

	const enhanceForm: SubmitFunction = () => {
		submitting = true;

		return async ({ result, update }) => {
			await update({ reset: false });
			submitting = false;

			if (result.type === 'failure') {
				requestAnimationFrame(() => {
					document.querySelector<HTMLElement>('[data-profile-form-error]')?.focus();
				});
			}
		};
	};
</script>

<svelte:head>
	<title>Mi perfil | Senda</title>
	<meta name="description" content="Datos de perfil, notificaciones y sesión de Senda." />
</svelte:head>

<main id="contenido-principal" class="px-5 py-8 sm:px-8 lg:px-0">
	<div class="w-full">
		<section aria-labelledby="profile-data-title">
			<h2 id="profile-data-title" class="mb-8 text-2xl font-bold text-ink">Datos de perfil</h2>

			<div class="grid gap-6 xl:grid-cols-12">
				<article class="overflow-hidden rounded-2xl bg-white shadow-sm xl:col-span-8">
					<div class="p-6">
						<Heading
							icon={PencilLine}
							title="Información personal"
							subtitle="Actualiza el nombre que identifica tu cuenta en Senda."
						/>

						{#if !data.profile}
							<div class="mt-6">
								<Alert
									icon={CircleAlert}
									title="Perfil no disponible"
									subtitle="No pudimos consultar los datos de tu perfil en este momento."
									color="warning"
								/>
							</div>
						{/if}

						{#if form?.success}
							<div class="mt-6">
								<Alert
									icon={CircleCheck}
									title="Perfil actualizado"
									subtitle={form.message ?? 'Tus cambios fueron guardados.'}
									color="positive"
								/>
							</div>
						{:else if form?.error}
							<div
								data-profile-form-error
								tabindex="-1"
								class="mt-6 rounded-2xl focus:ring-4 focus:ring-red-700/20 focus:outline-none"
							>
								<Alert
									icon={CircleAlert}
									title="Revisa los datos del perfil"
									subtitle={form.error}
									color="danger"
								/>
							</div>
						{/if}

						<form
							id="profile-form"
							method="POST"
							use:enhance={enhanceForm}
							aria-busy={submitting}
							class="mt-8"
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
									value={form?.fullName ?? data.profile?.full_name ?? ''}
									aria-invalid={form?.error ? 'true' : undefined}
									aria-describedby={form?.error ? 'profile-name-error' : undefined}
									class="mt-2 min-h-12 w-full rounded-xl border border-ink/20 bg-white px-4 text-base text-ink transition outline-none focus:border-focus focus:ring-4 focus:ring-focus/20"
								/>
								{#if form?.error}
									<p id="profile-name-error" class="mt-2 text-sm font-semibold text-red-800">
										{form.error}
									</p>
								{/if}
							</div>
						</form>
					</div>

					<div class="border-t border-ink/10 p-4">
						<button
							type="submit"
							form="profile-form"
							disabled={submitting || !data.profile}
							class="min-h-12 cursor-pointer rounded-full bg-brand px-6 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
						>
							{submitting ? 'Guardando…' : 'Guardar cambios'}
						</button>
					</div>
				</article>

				<aside class="rounded-2xl bg-white p-6 shadow-sm xl:col-span-4">
					<div class="flex items-center gap-4">
						<Initials text={displayName} />
						<div class="min-w-0">
							<h3 class="text-xl font-bold wrap-break-word text-ink">{displayName}</h3>
							<p class="mt-1 leading-6 wrap-break-word text-muted">
								{data.user.email ?? 'Correo no disponible'}
							</p>
						</div>
					</div>

					<div class="mt-8 grid gap-4">
						<InfoItem
							icon={Mail}
							title="Correo electrónico"
							info={data.user.email ?? 'No disponible'}
						/>
						<InfoItem
							icon={CalendarDays}
							title="Cuenta creada"
							info={data.profile?.created_at
								? presentDateTime(data.profile.created_at)
								: 'No disponible'}
						/>
					</div>
				</aside>
			</div>
		</section>

		<section aria-labelledby="notifications-title" class="mt-12 max-w-3xl">
			<h2 id="notifications-title" class="mb-8 text-2xl font-bold text-ink">Notificaciones</h2>
			<PushNotificationSettings />
		</section>

		<section aria-labelledby="session-title" class="mt-12">
			<h2 id="session-title" class="mb-8 text-2xl font-bold text-ink">Sesión</h2>

			<article class="max-w-3xl overflow-hidden rounded-2xl bg-white shadow-sm">
				<div class="p-6">
					<Heading
						icon={UserRound}
						title="Cerrar sesión"
						subtitle="Finaliza tu sesión actual en este dispositivo."
					/>
				</div>

				<div class="border-t border-ink/10 p-4">
					<form method="POST" action={resolve('/auth/logout')}>
						<button
							type="submit"
							class="inline-flex min-h-12 cursor-pointer items-center justify-center gap-2 rounded-full bg-red-800 px-6 font-bold text-white transition hover:bg-red-900 focus:ring-4 focus:ring-red-700/25 focus:outline-none"
						>
							<LogOut aria-hidden="true" size={19} strokeWidth={2} />
							Cerrar sesión
						</button>
					</form>
				</div>
			</article>
		</section>
	</div>
</main>
