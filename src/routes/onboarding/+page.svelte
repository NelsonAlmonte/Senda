<script lang="ts">
	import { resolve } from '$app/paths';
	import ArrowRight from '@lucide/svelte/icons/arrow-right';
	import KeyRound from '@lucide/svelte/icons/key-round';
	import Repeat2 from '@lucide/svelte/icons/repeat-2';
	import Smartphone from '@lucide/svelte/icons/smartphone';
	import SendaMark from '#lib/components/ui/SendaMark.svelte';
</script>

<svelte:head>
	<title>Bienvenido a Senda</title>
	<meta name="description" content="Elige cómo deseas comenzar a cuidar y monitorear con Senda." />
</svelte:head>

<main
	id="contenido-principal"
	class="grid min-h-dvh place-items-center px-5 py-10 sm:px-8 sm:py-14"
>
	<div class="w-full max-w-5xl">
		<header class="mx-auto max-w-2xl text-center">
			<div class="inline-flex items-center gap-3">
				<SendaMark class="size-11" />
				<span class="text-2xl font-bold text-ink">Senda</span>
			</div>

			<p class="mt-8 text-sm font-bold tracking-wide text-brand uppercase">
				Te damos la bienvenida
			</p>
			<h1 class="mt-3 text-3xl font-bold text-balance text-ink sm:text-4xl">
				¿Cómo llegaste hasta aquí?
			</h1>
			<p class="mx-auto mt-5 max-w-xl text-lg leading-8 text-muted">
				Elige la opción que mejor describe tu situación. Te guiaremos paso a paso y podrás usar la
				otra opción más adelante.
			</p>
		</header>

		<section class="mt-10 grid items-stretch gap-6 md:grid-cols-2" aria-label="Formas de comenzar">
			<article class="flex flex-col overflow-hidden rounded-2xl bg-white text-left shadow-sm">
				<div class="flex-1 p-6 sm:p-8">
					<div
						class="flex size-12 items-center justify-center rounded-full bg-surface-muted text-ink"
					>
						<Smartphone aria-hidden="true" size={23} strokeWidth={2} />
					</div>

					<p class="mt-6 text-sm font-bold text-brand">Si compraste Senda</p>
					<h2 class="mt-2 text-2xl font-bold text-ink">Tengo un dispositivo Senda</h2>
					<p class="mt-4 leading-7 text-muted">
						Te ayudaremos a crear el espacio de cuidado, registrar a la persona que acompañarás y
						configurar su dispositivo.
					</p>

					<div class="mt-6 rounded-2xl bg-canvas p-4">
						<p class="leading-6 font-semibold text-ink">
							Puedes dejar la configuración del dispositivo para más adelante.
						</p>
					</div>
				</div>

				<div class="border-t border-ink/10 p-4">
					<a
						href={resolve('/onboarding/groups')}
						class="inline-flex min-h-12 w-full items-center justify-center gap-2 rounded-full bg-brand px-6 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none sm:w-auto"
					>
						Configurar Senda
						<ArrowRight aria-hidden="true" size={19} strokeWidth={2} />
					</a>
				</div>
			</article>

			<article class="flex flex-col overflow-hidden rounded-2xl bg-white text-left shadow-sm">
				<div class="flex-1 p-6 sm:p-8">
					<div
						class="flex size-12 items-center justify-center rounded-full bg-surface-muted text-ink"
					>
						<KeyRound aria-hidden="true" size={23} strokeWidth={2} />
					</div>

					<p class="mt-6 text-sm font-bold text-brand">Si alguien te invitó</p>
					<h2 class="mt-2 text-2xl font-bold text-ink">Recibí un código de acceso</h2>
					<p class="mt-4 leading-7 text-muted">
						Ingresa el código que te compartieron para comenzar a monitorear a una persona que ya
						está registrada en Senda.
					</p>

					<div class="mt-6 rounded-2xl bg-canvas p-4">
						<p class="leading-6 font-semibold text-ink">
							El código te dará acceso únicamente a la persona indicada.
						</p>
					</div>
				</div>

				<div class="border-t border-ink/10 p-4">
					<a
						href={resolve('/onboarding/access-code')}
						class="inline-flex min-h-12 w-full items-center justify-center gap-2 rounded-full bg-brand px-6 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none sm:w-auto"
					>
						Ingresar código
						<ArrowRight aria-hidden="true" size={19} strokeWidth={2} />
					</a>
				</div>
			</article>
		</section>

		<div
			class="mt-8 flex items-center justify-center gap-3 text-center text-sm leading-6 text-muted"
		>
			<Repeat2 aria-hidden="true" class="shrink-0 text-brand" size={20} strokeWidth={2} />
			<p>Esta elección no define tu cuenta. Ambas opciones seguirán disponibles más adelante.</p>
		</div>
	</div>
</main>
