<script lang="ts">
	import { resolve } from '$app/paths';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();
	let displayName = $derived(data.profile?.full_name || data.user.email || 'Usuario de Senda');
</script>

<svelte:head><title>Panel | Senda</title></svelte:head>

<main id="contenido-principal" class="min-h-dvh px-5 py-6 sm:px-8 lg:px-12">
	<div class="mx-auto w-full max-w-6xl">
		<header class="flex flex-wrap items-center justify-between gap-4 border-b border-ink/10 pb-5">
			<a
				href={resolve('/dashboard')}
				class="rounded-xl text-xl font-bold text-ink focus:ring-4 focus:ring-focus/30 focus:outline-none"
				>Senda</a
			>
			<nav class="flex flex-wrap items-center gap-3" aria-label="Navegación de cuenta">
				<a
					href={resolve('/settings')}
					class="inline-flex min-h-12 items-center rounded-xl px-4 font-bold text-brand focus:ring-4 focus:ring-focus/30 focus:outline-none"
					>Mi perfil</a
				>
				<form method="POST" action="/auth/logout">
					<button
						type="submit"
						class="min-h-12 cursor-pointer rounded-xl border border-ink/15 bg-white px-4 font-bold text-ink focus:ring-4 focus:ring-focus/30 focus:outline-none"
						>Cerrar sesión</button
					>
				</form>
			</nav>
		</header>

		<section class="py-10 sm:py-14">
			<p class="text-sm font-bold tracking-[0.14em] text-brand uppercase">Panel protegido</p>
			<h1 class="mt-3 max-w-3xl text-3xl font-bold tracking-tight text-ink sm:text-4xl">
				Hola, {displayName}
			</h1>
			<p class="mt-4 max-w-2xl text-lg leading-8 text-muted">
				Tu sesión está activa. Los pacientes y grupos se incorporarán en la siguiente historia de la
				Fase 1.
			</p>

			{#if !data.profileAvailable}
				<div
					class="mt-7 max-w-2xl rounded-2xl border border-amber-700/25 bg-amber-50 p-4 text-sm leading-6 text-amber-950"
					role="status"
				>
					El perfil todavía no está disponible. Aplica la migración local al proyecto Supabase de
					desarrollo cuando sea autorizada.
				</div>
			{/if}

			<div class="mt-9 grid gap-5 md:grid-cols-2">
				<article class="rounded-3xl border border-white/80 bg-white p-6 shadow-lg shadow-brand/5">
					<h2 class="text-xl font-bold text-ink">Acceso verificado</h2>
					<p class="mt-2 leading-7 break-words text-muted">
						{data.user.email ?? 'Correo no disponible'}
					</p>
				</article>
				<article class="rounded-3xl border border-white/80 bg-white p-6 shadow-lg shadow-brand/5">
					<h2 class="text-xl font-bold text-ink">Sin pacientes todavía</h2>
					<p class="mt-2 leading-7 text-muted">
						Este estado vacío es esperado hasta implementar grupos, pacientes y accesos.
					</p>
				</article>
			</div>
		</section>
	</div>
</main>
