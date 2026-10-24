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
				Consulta las personas que tienes autorizadas y crea el primer contexto de cuidado cuando lo
				necesites.
			</p>

			{#if data.patientCreated}
				<div
					class="mt-7 max-w-2xl rounded-2xl border border-brand/25 bg-surface-muted p-4 text-sm leading-6 text-ink"
					role="status"
				>
					Grupo y paciente creados correctamente. Ya tienes acceso de administrador.
				</div>
			{/if}

			{#if !data.profileAvailable}
				<div
					class="mt-7 max-w-2xl rounded-2xl border border-amber-700/25 bg-amber-50 p-4 text-sm leading-6 text-amber-950"
					role="status"
				>
					El perfil todavía no está disponible. Aplica la migración local al proyecto Supabase de
					desarrollo cuando sea autorizada.
				</div>
			{/if}

			<div class="mt-9 flex flex-wrap items-end justify-between gap-4">
				<div>
					<h2 class="text-2xl font-bold text-ink">Pacientes autorizados</h2>
					<p class="mt-2 leading-7 text-muted">Solo aparecen pacientes con un acceso activo.</p>
				</div>
				<a
					href={resolve('/groups')}
					class="inline-flex min-h-12 items-center justify-center rounded-xl bg-brand px-5 font-bold text-white shadow-sm transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none"
				>
					Crear grupo y paciente
				</a>
			</div>

			{#if !data.patientsAvailable}
				<div
					class="mt-6 rounded-2xl border border-amber-700/25 bg-amber-50 p-4 text-sm leading-6 text-amber-950"
					role="status"
				>
					Los datos de pacientes aún no están disponibles. Aplica la migración de esta historia al
					proyecto Supabase de desarrollo.
				</div>
			{:else if data.patients.length > 0}
				<ul class="mt-6 grid gap-5 md:grid-cols-2">
					{#each data.patients as patient (patient.id)}
						<li class="rounded-3xl border border-white/80 bg-white p-6 shadow-lg shadow-brand/5">
							<div class="flex flex-wrap items-start justify-between gap-3">
								<div class="min-w-0">
									<h3 class="text-xl font-bold break-words text-ink">
										{patient.firstName}
										{patient.lastName}
									</h3>
									<p class="mt-1 text-sm break-words text-muted">
										{patient.group?.name ?? 'Grupo no disponible'}
									</p>
								</div>
								<span class="rounded-full bg-lavender px-3 py-1 text-xs font-bold text-ink">
									{patient.accessRole === 'ADMIN' ? 'Administrador' : 'Monitor'}
								</span>
							</div>
							<div class="mt-5 rounded-2xl bg-canvas p-4">
								<p class="font-bold text-ink">Sin monitoreo todavía</p>
								<p class="mt-1 text-sm leading-6 text-muted">
									No hay dispositivo ni ubicación registrados en esta fase.
								</p>
							</div>
						</li>
					{/each}
				</ul>
			{:else}
				<div class="mt-6 rounded-3xl border border-white/80 bg-white p-6 shadow-lg shadow-brand/5">
					<h3 class="text-xl font-bold text-ink">Aún no tienes pacientes</h3>
					<p class="mt-2 max-w-2xl leading-7 text-muted">
						Crea un grupo familiar o de cuidado y registra los datos mínimos de la primera persona.
					</p>
				</div>
			{/if}

			<article
				class="mt-8 rounded-3xl border border-white/80 bg-white p-6 shadow-lg shadow-brand/5"
			>
				<h2 class="text-lg font-bold text-ink">Cuenta activa</h2>
				<p class="mt-2 leading-7 break-words text-muted">
					{data.user.email ?? 'Correo no disponible'}
				</p>
			</article>
		</section>
	</div>
</main>
