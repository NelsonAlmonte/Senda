<script lang="ts">
	import { resolve } from '$app/paths';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();

	const foundations = [
		{
			title: 'PWA desde la base',
			description: 'Manifest, iconos y service worker preparados para una instalación progresiva.'
		},
		{
			title: 'Datos bajo control',
			description: 'Las credenciales privadas permanecen fuera del navegador y del repositorio.'
		},
		{
			title: 'Acceso protegido',
			description:
				'El registro, las sesiones SSR y los perfiles ya cuentan con una base segura y verificable.'
		}
	] as const;
</script>

<svelte:head>
	<title>Senda | Monitoreo preventivo</title>
	<meta
		name="description"
		content="Base técnica de Senda, una plataforma de apoyo para monitoreo preventivo y alerta temprana."
	/>
</svelte:head>

<main id="contenido-principal" class="relative isolate min-h-dvh overflow-hidden">
	<div class="pointer-events-none absolute inset-0 -z-10" aria-hidden="true">
		<div class="absolute -top-24 -right-24 h-72 w-72 rounded-full bg-sky-soft/55 blur-3xl"></div>
		<div class="absolute bottom-0 -left-24 h-80 w-80 rounded-full bg-lavender/55 blur-3xl"></div>
	</div>

	<div class="mx-auto flex min-h-dvh w-full max-w-6xl flex-col px-5 py-6 sm:px-8 sm:py-8 lg:px-12">
		<header class="flex items-center justify-between" aria-label="Encabezado principal">
			<a
				href={resolve('/')}
				class="inline-flex min-h-12 items-center gap-3 rounded-xl pr-3 text-ink focus:ring-4 focus:ring-focus/30 focus:outline-none"
				aria-label="Senda, inicio"
			>
				<span class="grid size-11 place-items-center rounded-2xl bg-brand text-white shadow-sm">
					<svg viewBox="0 0 24 24" class="size-6" aria-hidden="true">
						<path
							d="M12 21s6-4.35 6-11a6 6 0 1 0-12 0c0 6.65 6 11 6 11Z"
							fill="none"
							stroke="currentColor"
							stroke-width="1.8"
						/>
						<path
							d="M9.4 10.2c.8.15 1.35-.24 1.66-1.14.54 1.42 1.47 2.04 2.83 1.72-.5 1.63-1.58 2.54-3.25 2.72"
							fill="none"
							stroke="currentColor"
							stroke-linecap="round"
							stroke-linejoin="round"
							stroke-width="1.6"
						/>
					</svg>
				</span>
				<span class="text-xl font-bold tracking-tight">Senda</span>
			</a>

			{#if data.user}
				<a
					href={resolve('/dashboard')}
					class="inline-flex min-h-12 shrink-0 items-center rounded-xl bg-white px-4 text-sm font-bold text-brand shadow-sm focus:ring-4 focus:ring-focus/30 focus:outline-none"
				>
					Ir al panel
				</a>
			{:else}
				<a
					href={resolve('/auth/login')}
					class="inline-flex min-h-12 shrink-0 items-center rounded-xl bg-white px-4 text-sm font-bold text-brand shadow-sm focus:ring-4 focus:ring-focus/30 focus:outline-none"
				>
					Iniciar sesión
				</a>
			{/if}
		</header>

		<section
			class="grid min-w-0 flex-1 grid-cols-1 items-center gap-12 py-16 lg:grid-cols-[minmax(0,1.15fr)_minmax(0,0.85fr)] lg:py-20"
		>
			<div class="max-w-3xl min-w-0">
				<p class="mb-4 text-sm font-bold tracking-[0.16em] text-brand uppercase">
					Monitoreo preventivo y alerta temprana
				</p>
				<h1
					class="max-w-2xl text-4xl leading-tight font-bold tracking-tight text-balance text-ink sm:text-5xl lg:text-6xl"
				>
					Tecnología que acompaña el cuidado sin perder de vista a la persona.
				</h1>
				<p class="mt-6 max-w-2xl text-lg leading-8 text-muted sm:text-xl">
					Senda prepara una experiencia clara para familiares y cuidadores. El acceso seguro ya está
					disponible; los pacientes y las ubicaciones se incorporarán de forma incremental.
				</p>

				{#if !data.user}
					<div class="mt-8 flex flex-wrap gap-3">
						<a
							href={resolve('/auth/register')}
							class="inline-flex min-h-12 items-center justify-center rounded-xl bg-brand px-5 font-bold text-white shadow-sm transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none"
						>
							Crear cuenta
						</a>
						<a
							href={resolve('/auth/login')}
							class="inline-flex min-h-12 items-center justify-center rounded-xl border border-ink/15 bg-white px-5 font-bold text-ink shadow-sm focus:ring-4 focus:ring-focus/30 focus:outline-none"
						>
							Ya tengo cuenta
						</a>
					</div>
				{/if}

				<div
					class="mt-8 inline-flex items-center gap-3 rounded-2xl border border-brand/20 bg-white px-4 py-3 text-sm font-semibold text-ink shadow-sm"
				>
					<span class="relative flex size-3" aria-hidden="true">
						<span
							class="absolute inline-flex size-full animate-ping rounded-full bg-brand opacity-30"
						></span>
						<span class="relative inline-flex size-3 rounded-full bg-brand"></span>
					</span>
					Fase de autenticación preparada
				</div>
			</div>

			<div
				class="min-w-0 rounded-3xl border border-white/80 bg-white/85 p-5 shadow-xl shadow-brand/8 backdrop-blur-sm sm:p-7"
			>
				<h2 class="text-xl font-bold text-ink">Fundamentos de esta fase</h2>
				<p class="mt-2 leading-7 text-muted">
					Configuración verificable antes de incorporar datos sensibles.
				</p>

				<ul class="mt-6 space-y-4">
					{#each foundations as foundation (foundation.title)}
						<li class="flex gap-4 rounded-2xl bg-surface-muted p-4">
							<span
								class="mt-0.5 grid size-9 shrink-0 place-items-center rounded-xl bg-brand/12 text-brand"
								aria-hidden="true"
							>
								<svg viewBox="0 0 20 20" class="size-5">
									<path
										d="m5 10 3 3 7-7"
										fill="none"
										stroke="currentColor"
										stroke-linecap="round"
										stroke-linejoin="round"
										stroke-width="2"
									/>
								</svg>
							</span>
							<div>
								<h3 class="font-bold text-ink">{foundation.title}</h3>
								<p class="mt-1 leading-6 text-muted">{foundation.description}</p>
							</div>
						</li>
					{/each}
				</ul>
			</div>
		</section>

		<footer class="border-t border-ink/10 pt-5 text-sm leading-6 text-muted">
			<p>
				Herramienta de apoyo para un prototipo académico. No sustituye supervisión ni atención
				profesional.
			</p>
		</footer>
	</div>
</main>
