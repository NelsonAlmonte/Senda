<script lang="ts">
	import { resolve } from '$app/paths';
</script>

<svelte:head><title>No pudimos confirmar el acceso | Senda</title></svelte:head>

<main id="contenido-principal" class="grid min-h-dvh place-items-center px-5 py-10">
	<section class="w-full max-w-md rounded-3xl border border-white/80 bg-white p-7 text-center">
		<div
			class="mx-auto grid size-12 place-items-center rounded-2xl bg-red-50 text-xl font-bold text-red-800"
			aria-hidden="true"
		>
			!
		</div>
		<h1 class="mt-5 text-2xl font-bold text-ink">No pudimos confirmar el enlace</h1>
		<p class="mt-3 leading-7 text-muted">
			El enlace puede haber caducado o ya fue utilizado. Solicita un nuevo registro o vuelve a
			iniciar sesión.
		</p>
		<a
			href={resolve('/auth/login')}
			class="mt-7 inline-flex min-h-12 items-center justify-center rounded-xl bg-brand px-5 font-bold text-white focus:ring-4 focus:ring-focus/35 focus:outline-none"
			>Volver al inicio de sesión</a
		>
	</section>
</main>
