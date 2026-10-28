<script lang="ts">
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();
	let displayName = $derived(data.profile?.full_name || data.user.email || 'Usuario de Senda');
</script>

<svelte:head><title>Inicio | Senda</title></svelte:head>

<main id="contenido-principal" class="min-h-dvh px-5 py-10 sm:px-8 sm:py-14 lg:px-0">
	<div class="w-full max-w-6xl">
		<p class="text-3xl font-bold tracking-tight text-ink sm:text-4xl">
			Hola, {displayName}.
		</p>
	</div>
</main>
