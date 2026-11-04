<script lang="ts">
	import { resolve } from '$app/paths';
	import BellRing from '@lucide/svelte/icons/bell-ring';
	import HeartHandshake from '@lucide/svelte/icons/heart-handshake';
	import LayoutDashboard from '@lucide/svelte/icons/layout-dashboard';
	import LogIn from '@lucide/svelte/icons/log-in';
	import MapPinned from '@lucide/svelte/icons/map-pinned';
	import Route from '@lucide/svelte/icons/route';
	import ShieldCheck from '@lucide/svelte/icons/shield-check';
	import UserPlus from '@lucide/svelte/icons/user-plus';
	import PwaInstallAction from '#lib/components/pwa/PwaInstallAction.svelte';
	import SendaMark from '#lib/components/ui/SendaMark.svelte';
	import type { UiIcon } from '#lib/types/ui.js';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();

	type LandingItem = {
		icon: UiIcon;
		title: string;
		description: string;
	};

	const journey: readonly LandingItem[] = [
		{
			icon: MapPinned,
			title: 'Ubica',
			description: 'Consulta la última posición disponible y el recorrido reciente de la persona.'
		},
		{
			icon: ShieldCheck,
			title: 'Comprende',
			description: 'Interpreta cada lectura junto a las zonas permitidas y su vigencia.'
		},
		{
			icon: BellRing,
			title: 'Actúa',
			description: 'Recibe una alerta cuando el sistema confirma una salida y revisa su recorrido.'
		}
	] as const;

	const capabilities: readonly LandingItem[] = [
		{
			icon: Route,
			title: 'Recorridos con contexto',
			description:
				'Las ubicaciones se conservan junto a la asignación del dispositivo para no mezclar historiales.'
		},
		{
			icon: HeartHandshake,
			title: 'Acceso centrado en la persona',
			description:
				'Cada familiar o cuidador consulta únicamente a las personas que tiene autorizadas.'
		}
	] as const;
</script>

<svelte:head>
	<title>Senda | Cuidado conectado y alerta temprana</title>
	<meta
		name="description"
		content="Senda reúne ubicación, zonas permitidas y alertas confirmadas para apoyar el cuidado de personas con deterioro cognitivo."
	/>
</svelte:head>

<main id="contenido-principal" class="min-h-dvh overflow-hidden bg-canvas">
	<div class="mx-auto w-full max-w-7xl px-5 sm:px-8 lg:px-12">
		<header
			class="flex flex-col gap-4 py-6 sm:flex-row sm:items-center sm:justify-between sm:py-8"
			aria-label="Encabezado principal"
		>
			<a
				href={resolve('/')}
				class="inline-flex min-h-12 w-fit items-center gap-3 rounded-xl pe-3 text-ink focus:ring-4 focus:ring-focus/30 focus:outline-none"
				aria-label="Senda, inicio"
			>
				<SendaMark class="size-11" />
				<span class="text-2xl font-bold tracking-tight">Senda</span>
			</a>

			{#if data.user}
				<a
					href={resolve('/dashboard')}
					class="inline-flex min-h-12 items-center justify-center gap-2 rounded-full bg-brand px-5 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none"
				>
					<LayoutDashboard aria-hidden="true" size={19} strokeWidth={2} />
					Ir al panel
				</a>
			{:else}
				<div class="flex flex-col gap-3 sm:flex-row">
					<a
						href={resolve('/auth/login')}
						class="inline-flex min-h-12 items-center justify-center gap-2 rounded-full px-5 font-bold text-ink transition hover:bg-white focus:ring-4 focus:ring-focus/30 focus:outline-none"
					>
						<LogIn aria-hidden="true" size={19} strokeWidth={2} />
						Iniciar sesión
					</a>
					<a
						href={resolve('/auth/register')}
						class="inline-flex min-h-12 items-center justify-center gap-2 rounded-full bg-brand px-5 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none"
					>
						<UserPlus aria-hidden="true" size={19} strokeWidth={2} />
						Registrarse
					</a>
				</div>
			{/if}
		</header>

		<section class="grid items-center gap-10 py-12 lg:grid-cols-12 lg:py-20">
			<div class="min-w-0 lg:col-span-7">
				<p class="mb-5 text-sm font-bold tracking-widest text-brand uppercase">
					Cuidado conectado · Alertas con contexto
				</p>
				<h1
					class="max-w-4xl text-5xl leading-none font-bold tracking-tight text-balance text-ink sm:text-6xl lg:text-7xl"
				>
					Cuidar a distancia sin sentirse lejos.
				</h1>
				<p class="mt-8 max-w-2xl text-lg leading-8 text-muted sm:text-xl">
					Senda reúne ubicación, zonas permitidas y episodios de salida en una experiencia clara
					para familiares y cuidadores.
				</p>

				<PwaInstallAction />

				<div class="mt-8 flex max-w-xl items-start gap-3 text-sm leading-6 text-muted">
					<ShieldCheck
						aria-hidden="true"
						class="mt-0.5 shrink-0 text-brand"
						size={20}
						strokeWidth={2}
					/>
					<p>
						El acceso se concede por paciente. Pertenecer a un grupo no revela otros historiales.
					</p>
				</div>
			</div>

			<div class="min-w-0 lg:col-span-5">
				<div class="relative overflow-hidden rounded-2xl bg-brand p-6 shadow-sm">
					<div
						class="absolute -top-16 -right-12 size-48 rounded-full bg-sky-soft/25"
						aria-hidden="true"
					></div>
					<div
						class="absolute -bottom-20 -left-12 size-56 rounded-full bg-lavender/20"
						aria-hidden="true"
					></div>

					<div class="relative flex items-center justify-start gap-4 text-white">
						<span class="grid size-11 shrink-0 place-items-center rounded-full bg-white/15">
							<MapPinned aria-hidden="true" size={22} strokeWidth={2} />
						</span>
						<div>
							<p class="text-sm font-semibold text-white/70">Una lectura más clara</p>
							<h2 class="mt-1 text-xl font-bold">Todo el contexto, en un mismo lugar</h2>
						</div>
					</div>

					<div class="relative mt-6 overflow-hidden rounded-2xl bg-canvas p-4 sm:p-5">
						<svg viewBox="0 0 520 280" class="h-64 w-full text-focus sm:h-72" aria-hidden="true">
							<path
								d="M34 238 C 96 180, 130 218, 184 160 S 266 86, 332 128 S 430 116, 486 38"
								fill="none"
								stroke="currentColor"
								stroke-linecap="round"
								stroke-width="8"
							/>
							<circle
								cx="184"
								cy="160"
								r="66"
								class="fill-sky-soft/40 stroke-brand"
								stroke-width="3"
							/>
							<circle
								cx="332"
								cy="128"
								r="84"
								class="fill-surface-muted/70 stroke-brand"
								stroke-width="3"
							/>
							<circle cx="34" cy="238" r="12" class="fill-brand" />
							<circle cx="486" cy="38" r="14" class="fill-focus" />
						</svg>

						<div class="absolute top-4 left-4 rounded-2xl bg-white p-4 sm:top-5 sm:left-5">
							<div class="flex items-center gap-3">
								<span
									class="grid size-10 place-items-center rounded-full bg-surface-muted text-brand"
								>
									<ShieldCheck aria-hidden="true" size={20} strokeWidth={2} />
								</span>
								<div>
									<p class="font-bold text-ink">Contexto visible</p>
									<p class="text-sm text-muted">Zonas permitidas.</p>
								</div>
							</div>
						</div>

						<div
							class="absolute right-4 bottom-4 max-w-64 rounded-2xl bg-white p-4 sm:right-5 sm:bottom-5"
						>
							<div class="flex items-start gap-3">
								<span
									class="grid size-10 shrink-0 place-items-center rounded-full bg-surface-muted text-ink"
								>
									<BellRing aria-hidden="true" size={20} strokeWidth={2} />
								</span>
								<div>
									<p class="font-bold text-ink">Salida confirmada</p>
									<p class="mt-1 text-sm leading-5 text-muted">Revisa su recorrido.</p>
								</div>
							</div>
						</div>
					</div>
				</div>
			</div>
		</section>
	</div>

	<section class="bg-ink py-20 text-white sm:py-28" aria-labelledby="journey-title">
		<div class="mx-auto grid w-full max-w-7xl gap-14 px-5 sm:px-8 lg:grid-cols-12 lg:px-12">
			<div class="lg:col-span-5">
				<p class="text-sm font-bold tracking-widest text-sky-soft uppercase">
					Del dato a la decisión
				</p>
				<h2
					id="journey-title"
					class="mt-5 text-4xl leading-tight font-bold tracking-tight text-balance sm:text-5xl"
				>
					Una ubicación no es una alarma.
				</h2>
				<p class="mt-6 max-w-lg text-lg leading-8 text-white/70">
					Senda reúne contexto antes de pedir atención: dónde está la persona, cómo se relaciona con
					sus zonas permitidas y si existe una salida realmente confirmada.
				</p>

				<div class="mt-10 hidden lg:block" aria-hidden="true">
					<svg viewBox="0 0 360 180" class="w-full max-w-sm text-sky-soft/70">
						<path
							d="M16 146 C 74 146, 76 52, 142 52 S 216 140, 274 100 S 318 38, 344 38"
							fill="none"
							stroke="currentColor"
							stroke-linecap="round"
							stroke-width="5"
						/>
						<circle cx="16" cy="146" r="8" class="fill-sky-soft" />
						<circle cx="344" cy="38" r="8" class="fill-white" />
					</svg>
				</div>
			</div>

			<ol class="min-w-0 space-y-4 lg:col-span-7">
				{#each journey as item, index (item.title)}
					{@const Icon = item.icon}
					<li
						class={[
							'flex items-start gap-5 rounded-2xl bg-white/10 p-6',
							index === 1 && 'lg:ms-12',
							index === 2 && 'lg:ms-24'
						]}
					>
						<div class="shrink-0">
							<span class="grid size-12 place-items-center rounded-full bg-white/10 text-sky-soft">
								<Icon aria-hidden="true" size={22} strokeWidth={2} />
							</span>
							<span class="mt-5 block text-sm font-bold tracking-widest text-white/45">
								0{index + 1}
							</span>
						</div>
						<div>
							<h3 class="text-3xl font-bold">{item.title}</h3>
							<p class="mt-3 max-w-xl text-lg leading-8 text-white/70">{item.description}</p>
						</div>
					</li>
				{/each}
			</ol>
		</div>
	</section>

	<section class="bg-white py-20 sm:py-28" aria-labelledby="care-title">
		<div class="mx-auto grid w-full max-w-7xl gap-12 px-5 sm:px-8 lg:grid-cols-12 lg:px-12">
			<div class="lg:col-span-7">
				<span class="mb-8 grid size-14 place-items-center rounded-full bg-surface-muted text-brand">
					<HeartHandshake aria-hidden="true" size={26} strokeWidth={2} />
				</span>
				<p class="text-sm font-bold tracking-widest text-brand uppercase">Privacidad por diseño</p>
				<h2
					id="care-title"
					class="mt-5 max-w-3xl text-4xl leading-tight font-bold tracking-tight text-balance text-ink sm:text-5xl"
				>
					Quién puede mirar importa tanto como qué se mira.
				</h2>
				<p class="mt-6 max-w-2xl text-lg leading-8 text-muted">
					Senda separa el contexto familiar o institucional del permiso real para consultar a cada
					persona.
				</p>
			</div>

			<div class="space-y-4 lg:col-span-5 lg:pt-16">
				{#each capabilities as capability (capability.title)}
					{@const Icon = capability.icon}
					<article class="flex items-start gap-5 rounded-2xl bg-canvas p-6 shadow-sm">
						<span
							class="grid size-12 shrink-0 place-items-center rounded-full bg-surface-muted text-brand"
						>
							<Icon aria-hidden="true" size={22} strokeWidth={2} />
						</span>
						<div>
							<h3 class="text-2xl font-bold text-ink">{capability.title}</h3>
							<p class="mt-3 leading-7 text-muted">{capability.description}</p>
						</div>
					</article>
				{/each}
			</div>
		</div>
	</section>

	<footer class="border-t border-ink/10 bg-white">
		<div
			class="mx-auto flex w-full max-w-7xl flex-col gap-4 px-5 py-8 text-sm leading-6 text-muted sm:px-8 lg:flex-row lg:items-center lg:justify-between lg:px-12"
		>
			<p class="font-bold text-ink">Senda</p>
			<p>Prototipo académico de apoyo. No sustituye supervisión ni atención profesional.</p>
		</div>
	</footer>
</main>
