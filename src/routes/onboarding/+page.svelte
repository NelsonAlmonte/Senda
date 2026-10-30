<script lang="ts">
	import { resolve } from '$app/paths';
</script>

<svelte:head>
	<title>¿Qué deseas hacer? | Senda</title>
	<meta name="description" content="Elige cómo comenzar a usar Senda." />
</svelte:head>

<main id="contenido-principal" class="px-5 py-8 sm:px-8 lg:px-0">
	<section class="w-full max-w-4xl py-4 sm:py-8">
		<p class="max-w-2xl text-lg leading-8 text-muted">
			No estás eligiendo un tipo permanente de cuenta. Podrás usar ambas opciones más adelante.
		</p>

		<div class="mt-8 grid gap-5 md:grid-cols-2">
			<a
				href={resolve('/groups')}
				class="group rounded-3xl border border-white/80 bg-white p-6 transition hover:border-brand/30 focus:ring-4 focus:ring-focus/35 focus:outline-none"
			>
				<p class="text-sm font-bold text-brand">Opción 1</p>
				<h2 class="mt-2 text-2xl font-bold text-ink">Registrar dispositivo</h2>
				<p class="mt-3 leading-7 text-muted">
					Elige o crea una familia o centro, registra al paciente y asigna el serial simulado.
				</p>
				<span class="mt-6 inline-flex min-h-12 items-center font-bold text-brand">Continuar →</span>
			</a>

			<a
				href={resolve('/access-code')}
				class="group rounded-3xl border border-white/80 bg-white p-6 transition hover:border-brand/30 focus:ring-4 focus:ring-focus/35 focus:outline-none"
			>
				<p class="text-sm font-bold text-brand">Opción 2</p>
				<h2 class="mt-2 text-2xl font-bold text-ink">Monitorear dispositivo</h2>
				<p class="mt-3 leading-7 text-muted">
					Introduce el código que te compartió un familiar o administrador del paciente.
				</p>
				<span class="mt-6 inline-flex min-h-12 items-center font-bold text-brand"
					>Introducir código →</span
				>
			</a>
		</div>

		<a
			href={resolve('/patients')}
			class="mt-7 inline-flex min-h-12 items-center rounded-xl font-bold text-muted underline decoration-ink/20 underline-offset-4 focus:ring-4 focus:ring-focus/30 focus:outline-none"
		>
			Ir a pacientes por ahora
		</a>
	</section>
</main>
