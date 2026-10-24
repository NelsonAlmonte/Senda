<script lang="ts">
	import { resolve } from '$app/paths';
	import type { PageProps } from './$types';
	let { data, form }: PageProps = $props();
</script>

<svelte:head><title>Compartir acceso | Senda</title></svelte:head>

<main id="contenido-principal" class="min-h-dvh px-5 py-8 sm:px-8 lg:px-12">
	<section class="mx-auto w-full max-w-2xl py-8 sm:py-12">
		<a
			href={resolve('/dashboard')}
			class="inline-flex min-h-12 items-center rounded-xl font-bold text-brand focus:ring-4 focus:ring-focus/30 focus:outline-none"
			>← Volver al panel</a
		>
		<div
			class="mt-5 rounded-3xl border border-white/80 bg-white p-6 shadow-xl shadow-brand/8 sm:p-8"
		>
			<p class="text-sm font-bold tracking-[0.14em] text-brand uppercase">Acceso al paciente</p>
			<h1 class="mt-2 text-3xl font-bold text-ink">Comparte a {data.patient?.first_name}</h1>
			<p class="mt-3 leading-7 text-muted">
				El código funciona una sola vez y concede el rol Monitor únicamente sobre este paciente.
			</p>
			{#if form?.accessCode}
				<div class="mt-7 rounded-2xl bg-surface-muted p-5 text-center" role="status">
					<p class="text-sm font-bold text-ink">Código generado</p>
					<p class="mt-3 font-mono text-2xl font-bold tracking-widest break-all text-brand">
						{form.accessCode}
					</p>
					<p class="mt-3 text-sm leading-6 text-muted">
						Cópialo ahora. Senda no vuelve a mostrar el código completo.
					</p>
				</div>
			{/if}
			<form method="POST" class="mt-7">
				<button
					class="min-h-12 w-full cursor-pointer rounded-xl bg-brand px-5 font-bold text-white focus:ring-4 focus:ring-focus/35 focus:outline-none"
				>
					{form?.accessCode ? 'Generar otro código' : 'Generar código de acceso'}
				</button>
			</form>
		</div>
	</section>
</main>
