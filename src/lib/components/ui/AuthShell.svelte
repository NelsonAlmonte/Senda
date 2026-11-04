<script lang="ts">
	import type { UiIcon } from '#lib/types/ui.ts';
	import { resolve } from '$app/paths';
	import ArrowLeft from '@lucide/svelte/icons/arrow-left';
	import BellRing from '@lucide/svelte/icons/bell-ring';
	import MapPinned from '@lucide/svelte/icons/map-pinned';
	import ShieldCheck from '@lucide/svelte/icons/shield-check';
	import type { Snippet } from 'svelte';
	import SendaMark from './SendaMark.svelte';

	interface Props {
		icon: UiIcon;
		eyebrow: string;
		title: string;
		description: string;
		children: Snippet;
		alternatePrompt?: string;
		alternateHref?: '/auth/login' | '/auth/register';
		alternateLabel?: string;
	}

	let {
		icon: Icon,
		eyebrow,
		title,
		description,
		children,
		alternatePrompt,
		alternateHref,
		alternateLabel
	}: Props = $props();
</script>

<main id="contenido-principal" class="min-h-dvh bg-canvas">
	<div class="mx-auto flex min-h-dvh w-full max-w-7xl flex-col px-5 sm:px-8 lg:px-12">
		<header class="flex items-center justify-between gap-4 py-6 sm:py-8">
			<a
				href={resolve('/')}
				class="inline-flex min-h-12 items-center gap-3 rounded-xl pe-3 text-ink focus:ring-4 focus:ring-focus/30 focus:outline-none"
				aria-label="Senda, inicio"
			>
				<SendaMark class="size-11" />
				<span class="text-2xl font-bold tracking-tight">Senda</span>
			</a>

			<a
				href={resolve('/')}
				class="inline-flex min-h-12 items-center justify-center gap-2 rounded-full px-4 font-bold text-brand transition hover:bg-white focus:ring-4 focus:ring-focus/30 focus:outline-none"
			>
				<ArrowLeft aria-hidden="true" size={19} strokeWidth={2} />
				<span class="hidden sm:inline">Volver al inicio</span>
				<span class="sm:hidden">Volver</span>
			</a>
		</header>

		<div class="grid flex-1 items-center py-6 sm:py-10">
			<div class="grid overflow-hidden rounded-2xl bg-white shadow-sm lg:grid-cols-12">
				<aside
					class="relative hidden overflow-hidden bg-ink p-6 text-white lg:col-span-6 lg:flex lg:flex-col lg:justify-between"
					aria-label="Resumen de Senda"
				>
					<div
						class="absolute -top-16 -right-16 size-56 rounded-full bg-sky-soft/15"
						aria-hidden="true"
					></div>
					<div
						class="absolute -bottom-20 -left-20 size-64 rounded-full bg-lavender/10"
						aria-hidden="true"
					></div>

					<div class="relative">
						<p class="text-sm font-bold tracking-widest text-sky-soft uppercase">
							Cuidado con contexto
						</p>
						<h2 class="mt-5 max-w-md text-4xl leading-tight font-bold tracking-tight text-balance">
							Un espacio claro para acompañar a distancia.
						</h2>
						<p class="mt-6 max-w-md text-lg leading-8 text-white/80">
							Ubicación, zonas permitidas y episodios confirmados reunidos sin perder de vista a la
							persona.
						</p>
					</div>

					<div class="relative my-12" aria-hidden="true">
						<svg viewBox="0 0 420 210" class="w-full text-sky-soft/70">
							<path
								d="M24 172 C 92 128, 122 168, 174 112 S 266 44, 318 88 S 374 76, 398 28"
								fill="none"
								stroke="currentColor"
								stroke-linecap="round"
								stroke-width="6"
							/>
							<circle
								cx="174"
								cy="112"
								r="58"
								class="fill-sky-soft/10 stroke-sky-soft"
								stroke-width="2"
							/>
							<circle
								cx="318"
								cy="88"
								r="72"
								class="fill-white/5 stroke-white/50"
								stroke-width="2"
							/>
							<circle cx="24" cy="172" r="10" class="fill-sky-soft" />
							<circle cx="398" cy="28" r="11" class="fill-white" />
						</svg>
					</div>

					<div class="relative space-y-4">
						<div class="flex items-start gap-3 rounded-2xl bg-white/10 p-4">
							<span
								class="grid size-10 shrink-0 place-items-center rounded-full bg-white/10 text-sky-soft"
							>
								<ShieldCheck aria-hidden="true" size={20} strokeWidth={2} />
							</span>
							<div>
								<p class="font-bold">Acceso por persona</p>
								<p class="mt-1 text-sm leading-6 text-white/80">
									Cada persona puede supervisar exclusivamente a los pacientes que tiene bajo su
									responsabilidad.
								</p>
							</div>
						</div>
						<div class="grid grid-cols-2 gap-4">
							<div class="rounded-2xl bg-white/10 p-4">
								<MapPinned aria-hidden="true" class="text-sky-soft" size={21} strokeWidth={2} />
								<p class="mt-3 font-bold">Ubicación</p>
							</div>
							<div class="rounded-2xl bg-white/10 p-4">
								<BellRing aria-hidden="true" class="text-sky-soft" size={21} strokeWidth={2} />
								<p class="mt-3 font-bold">Alertas con contexto</p>
							</div>
						</div>
					</div>
				</aside>

				<section class="flex items-center p-6 lg:col-span-6" aria-labelledby="auth-title">
					<div class="mx-auto w-full max-w-lg">
						<span
							class="mb-4 grid size-14 place-items-center rounded-full bg-surface-muted text-brand"
						>
							<Icon aria-hidden="true" size={26} strokeWidth={2} />
						</span>
						<p class="text-sm font-bold tracking-widest text-brand uppercase">{eyebrow}</p>
						<h1
							id="auth-title"
							class="mt-3 text-4xl leading-tight font-bold tracking-tight text-balance text-ink"
						>
							{title}
						</h1>
						<p class="mt-4 max-w-md leading-7 text-muted">{description}</p>

						<div class="mt-8">{@render children()}</div>

						{#if alternatePrompt && alternateHref && alternateLabel}
							<p class="mt-8 text-center leading-7 text-muted">
								{alternatePrompt}
								<a
									href={resolve(alternateHref)}
									class="rounded font-bold text-brand underline decoration-brand/30 underline-offset-4 focus:ring-4 focus:ring-focus/30 focus:outline-none"
								>
									{alternateLabel}
								</a>
							</p>
						{/if}
					</div>
				</section>
			</div>
		</div>

		<footer class="py-6 text-center text-sm leading-6 text-muted sm:py-8">
			Senda es una herramienta de apoyo y no sustituye supervisión ni atención profesional.
		</footer>
	</div>
</main>
