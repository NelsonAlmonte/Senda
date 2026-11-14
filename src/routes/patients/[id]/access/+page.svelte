<script lang="ts">
	import { enhance, type SubmitFunction } from '$app/forms';
	import Alert from '#lib/components/ui/Alert.svelte';
	import Heading from '#lib/components/ui/Heading.svelte';
	import Initials from '#lib/components/ui/Initials.svelte';
	import Modal from '#lib/components/ui/Modal.svelte';
	import CalendarDays from '@lucide/svelte/icons/calendar-days';
	import CircleAlert from '@lucide/svelte/icons/circle-alert';
	import CircleCheck from '@lucide/svelte/icons/circle-check';
	import Eye from '@lucide/svelte/icons/eye';
	import KeyRound from '@lucide/svelte/icons/key-round';
	import ShieldCheck from '@lucide/svelte/icons/shield-check';
	import UserMinus from '@lucide/svelte/icons/user-minus';
	import type { PageProps } from './$types';

	let { data, form }: PageProps = $props();
	let accessToRevoke = $state<PageProps['data']['accessRoster'][number] | null>(null);
	let revoking = $state(false);
	const dateFormatter = new Intl.DateTimeFormat('es-DO', {
		dateStyle: 'medium',
		timeZone: 'America/Santo_Domingo'
	});

	const enhanceRevoke: SubmitFunction = () => {
		revoking = true;

		return async ({ result, update }) => {
			await update({ reset: false });
			revoking = false;

			if (result.type === 'success') accessToRevoke = null;
		};
	};

	function closeRevokeModal() {
		if (!revoking) accessToRevoke = null;
	}
</script>

{#snippet revokeModalContent()}
	{#if accessToRevoke}
		{#if form?.error}
			<div class="mb-5">
				<Alert
					icon={CircleAlert}
					title="No pudimos revocar el acceso"
					subtitle={form.error}
					color="danger"
				/>
			</div>
		{/if}

		<p class="leading-7 text-muted">
			<strong class="text-ink">{accessToRevoke.displayName}</strong> perderá inmediatamente el acceso
			al paciente, su dispositivo y sus ubicaciones.
		</p>

		<div class="mt-4 rounded-2xl bg-surface-muted p-4">
			<p class="font-bold text-ink">El acceso deberá compartirse nuevamente</p>
			<p class="mt-1 text-sm leading-6 text-muted">
				Si esta persona necesita volver a monitorear al paciente, tendrás que generar un código
				nuevo.
			</p>
		</div>
	{/if}
{/snippet}

{#snippet revokeModalFooter()}
	{#if accessToRevoke}
		<form
			method="POST"
			action="?/revoke"
			use:enhance={enhanceRevoke}
			aria-busy={revoking}
			class="flex flex-col gap-2 sm:flex-row sm:justify-end"
		>
			<input type="hidden" name="accessId" value={accessToRevoke.id} />
			<button
				type="button"
				onclick={closeRevokeModal}
				disabled={revoking}
				class="min-h-12 cursor-pointer rounded-full px-5 font-bold text-ink transition hover:bg-canvas focus:ring-4 focus:ring-focus/30 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
			>
				Volver
			</button>
			<button
				type="submit"
				disabled={revoking}
				class="inline-flex min-h-12 cursor-pointer items-center justify-center gap-2 rounded-full bg-red-800 px-5 font-bold text-white transition hover:bg-red-900 focus:ring-4 focus:ring-red-700/20 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
			>
				<UserMinus aria-hidden="true" size={18} strokeWidth={2} />
				{revoking ? 'Revocando…' : 'Confirmar revocación'}
			</button>
		</form>
	{/if}
{/snippet}

<svelte:head>
	<title>Personas con acceso | Senda</title>
	<meta name="description" content="Consulta y administra los accesos activos de un paciente." />
</svelte:head>

<main id="contenido-principal" class="px-5 py-8 sm:px-8 lg:px-0">
	<div class="w-full">
		<h2 class="mb-8 text-2xl font-bold text-ink">Personas autorizadas</h2>

		{#if form?.error}
			<div class="mb-8 max-w-3xl">
				<Alert
					icon={CircleAlert}
					title="No pudimos completar la acción"
					subtitle={form.error}
					color="danger"
				/>
			</div>
		{:else if form?.successMessage}
			<div class="mb-8 max-w-3xl">
				<Alert
					icon={CircleCheck}
					title="Acceso actualizado"
					subtitle={form.successMessage}
					color="positive"
				/>
			</div>
		{/if}

		<div class="grid gap-6 xl:grid-cols-12">
			<section class="order-2 lg:order-1 xl:col-span-7">
				<ul class="grid items-start gap-5 sm:grid-cols-2">
					{#each data.accessRoster as access (access.id)}
						<li class="flex flex-col overflow-hidden rounded-2xl bg-white shadow-sm">
							<div class="flex-1 p-6">
								<div class="flex min-w-0 items-start gap-4">
									<Initials text={access.displayName} />
									<div class="min-w-0">
										<div class="flex flex-wrap items-center gap-2">
											<h4 class="text-lg font-bold wrap-break-word text-ink">
												{access.displayName}
											</h4>
											{#if access.isCurrentUser}
												<span
													class="rounded-full bg-surface-muted px-3 py-1 text-xs font-bold text-brand"
													>Tu acceso</span
												>
											{/if}
										</div>

										<div class="mt-3 flex flex-wrap gap-x-5 gap-y-2 text-sm text-muted">
											<span class="inline-flex items-center gap-2">
												{#if access.role === 'ADMIN'}
													<ShieldCheck aria-hidden="true" size={18} strokeWidth={2} />
													Administrador
												{:else}
													<Eye aria-hidden="true" size={18} strokeWidth={2} />
													Monitor
												{/if}
											</span>
											<span class="inline-flex items-center gap-2">
												<CalendarDays aria-hidden="true" size={18} strokeWidth={2} />
												Desde
												<time datetime={access.grantedAt}>
													{dateFormatter.format(new Date(access.grantedAt))}
												</time>
											</span>
										</div>
									</div>
								</div>
							</div>

							{#if access.role === 'MONITOR'}
								<div class="border-t border-ink/10 p-4">
									<button
										type="button"
										onclick={() => (accessToRevoke = access)}
										aria-haspopup="dialog"
										aria-controls="revoke-access-modal"
										class="flex min-h-12 w-full cursor-pointer items-center justify-center gap-2 rounded-full border border-red-800/25 px-5 font-bold text-red-800 transition-colors hover:bg-red-50 focus:ring-4 focus:ring-red-700/20 focus:outline-none"
									>
										<UserMinus aria-hidden="true" size={19} strokeWidth={2} />
										Revocar acceso
									</button>
								</div>
							{/if}
						</li>
					{/each}
				</ul>
			</section>

			<aside class="order-1 self-start rounded-2xl bg-white p-6 shadow-sm lg:order-2 xl:col-span-5">
				<Heading
					icon={KeyRound}
					title="Compartir acceso"
					subtitle="Genera un código de un solo uso. La otra persona obtendrá acceso Monitor únicamente a este paciente."
				/>

				{#if form?.accessCode}
					<div class="mt-6 rounded-2xl bg-surface-muted p-5 text-center" role="status">
						<p class="text-sm font-bold text-ink">Código generado</p>
						<p class="mt-3 font-mono text-2xl font-bold tracking-widest break-all text-brand">
							{form.accessCode}
						</p>
						<p class="mt-3 text-sm leading-6 text-muted">
							Cópialo ahora. Senda no vuelve a mostrar el código completo.
						</p>
					</div>
				{/if}

				<form method="POST" action="?/createCode" class="mt-6">
					<button
						type="submit"
						class="inline-flex min-h-12 w-full cursor-pointer items-center justify-center gap-2 rounded-full bg-brand px-5 font-bold text-white transition-colors hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none"
					>
						<KeyRound aria-hidden="true" size={19} strokeWidth={2} />
						{form?.accessCode ? 'Generar otro código' : 'Generar código de acceso'}
					</button>
				</form>
			</aside>
		</div>
	</div>
</main>

<Modal
	id="revoke-access-modal"
	open={accessToRevoke !== null}
	title="Revocar acceso"
	subtitle={accessToRevoke ? `Confirma la revocación de ${accessToRevoke.displayName}.` : undefined}
	icon={UserMinus}
	children={revokeModalContent}
	footer={revokeModalFooter}
	onclose={closeRevokeModal}
/>
