<script lang="ts">
	import { resolve } from '$app/paths';
	import { page } from '$app/state';
	import CircleAlert from '@lucide/svelte/icons/circle-alert';
	import House from '@lucide/svelte/icons/house';
	import RotateCw from '@lucide/svelte/icons/rotate-cw';
	import SendaMark from '#lib/components/ui/SendaMark.svelte';

	let status = $derived(page.status);
	let notFound = $derived(status === 404);
	let forbidden = $derived(status === 403);

	let title = $derived(
		notFound
			? 'No encontramos esta página.'
			: forbidden
				? 'No tienes acceso a esta página.'
				: 'Algo salió mal de nuestro lado.'
	);
	let description = $derived(
		notFound
			? 'Puede que el enlace esté incompleto o que el contenido ya no exista.'
			: forbidden
				? 'Si crees que deberías tenerlo, pide al administrador del paciente que revise tus permisos.'
				: 'No pudimos completar la acción. Inténtalo de nuevo en unos segundos.'
	);
</script>

<svelte:head><title>{title} | Senda</title></svelte:head>

<main
	id="contenido-principal"
	class="mx-auto flex min-h-[70dvh] w-full max-w-xl flex-col items-center justify-center px-5 py-12 text-center"
>
	<SendaMark class="size-14" />
	<div
		class="mt-8 inline-flex items-center gap-2 rounded-full bg-surface-muted px-4 py-2 text-sm font-bold text-ink"
	>
		<CircleAlert aria-hidden="true" size={18} strokeWidth={2} />
		<span>Error {status}</span>
	</div>
	<h1 class="mt-5 text-3xl leading-tight font-bold text-ink">{title}</h1>
	<p class="mt-3 text-base leading-7 text-muted">{description}</p>

	<div class="mt-8 flex w-full flex-col gap-3 sm:w-auto sm:flex-row">
		<a
			href={resolve('/dashboard')}
			class="inline-flex min-h-12 items-center justify-center gap-2 rounded-xl bg-brand px-6 font-bold text-white transition hover:bg-brand/90"
		>
			<House aria-hidden="true" size={19} strokeWidth={2} />
			Volver al inicio
		</a>
		{#if !notFound && !forbidden}
			<button
				type="button"
				onclick={() => location.reload()}
				class="inline-flex min-h-12 cursor-pointer items-center justify-center gap-2 rounded-xl border border-field bg-white px-6 font-bold text-ink transition hover:bg-surface-muted"
			>
				<RotateCw aria-hidden="true" size={19} strokeWidth={2} />
				Reintentar
			</button>
		{/if}
	</div>
</main>
