<script lang="ts">
	import { resolve } from '$app/paths';
	import type { PageProps } from './$types';

	let { data, form }: PageProps = $props();
	const dateFormatter = new Intl.DateTimeFormat('es-DO', {
		dateStyle: 'medium',
		timeZone: 'America/Santo_Domingo'
	});

	function relationshipLabel(relationship: 'FAMILY' | 'CAREGIVER' | 'OTHER' | null) {
		switch (relationship) {
			case 'FAMILY':
				return 'Familiar';
			case 'CAREGIVER':
				return 'Cuidador';
			case 'OTHER':
				return 'Otra relación';
			default:
				return 'Relación no indicada';
		}
	}
</script>

<svelte:head>
	<title>Personas con acceso | Senda</title>
	<meta name="description" content="Consulta y administra los accesos activos de un paciente." />
</svelte:head>

<main id="contenido-principal" class="min-h-dvh px-5 py-6 sm:px-8 lg:px-12">
	<div class="mx-auto w-full max-w-4xl">
		<header class="border-b border-ink/10 pb-6">
			<a
				href={resolve('/patients/[id]', { id: data.patient.id })}
				class="inline-flex min-h-12 items-center rounded-xl font-bold text-brand focus:ring-4 focus:ring-focus/30 focus:outline-none"
			>
				<span aria-hidden="true">←</span><span class="ml-2">Volver al paciente</span>
			</a>
			<p class="mt-6 text-sm font-bold tracking-[0.14em] text-brand uppercase">Administración</p>
			<h1 class="mt-2 text-3xl font-bold tracking-tight text-ink sm:text-4xl">
				Personas con acceso a {data.patient.first_name}
			</h1>
			<p class="mt-3 max-w-2xl leading-7 text-muted">
				Consulta quién puede ver a este paciente, comparte un código de un solo uso o revoca el
				acceso de un monitor.
			</p>
		</header>

		{#if form?.error}
			<div
				class="mt-6 rounded-2xl border border-red-700/25 bg-red-50 p-4 text-sm font-semibold text-red-950"
				role="alert"
			>
				{form.error}
			</div>
		{:else if form?.successMessage}
			<div
				class="mt-6 rounded-2xl border border-brand/20 bg-surface-muted p-4 text-sm font-semibold text-ink"
				role="status"
			>
				{form.successMessage}
			</div>
		{/if}

		<section
			class="mt-8 rounded-3xl border border-white/80 bg-white p-6 shadow-lg shadow-brand/5 sm:p-8"
		>
			<h2 class="text-2xl font-bold text-ink">Compartir con otra persona</h2>
			<p class="mt-2 max-w-2xl leading-7 text-muted">
				El código funciona una sola vez y concede el rol Monitor únicamente sobre este paciente.
			</p>

			{#if form?.accessCode}
				<div class="mt-6 rounded-2xl bg-surface-muted p-5 text-center" role="status">
					<p class="text-sm font-bold text-ink">Código generado</p>
					<p class="mt-3 font-mono text-2xl font-bold tracking-widest break-all text-brand">
						{form.accessCode}
					</p>
					<p class="mt-3 text-sm leading-6 text-muted">
						Cópialo ahora. Senda no vuelve a mostrar el código completo.
					</p>
				</div>
			{/if}

			<form method="POST" action="?/createCode" class="mt-6">
				<button
					type="submit"
					class="min-h-12 cursor-pointer rounded-xl bg-brand px-5 font-bold text-white shadow-sm transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none"
				>
					{form?.accessCode ? 'Generar otro código' : 'Generar código de acceso'}
				</button>
			</form>
		</section>

		<section aria-labelledby="active-access-title" class="py-8 sm:py-10">
			<div class="flex flex-wrap items-end justify-between gap-3">
				<div>
					<h2 id="active-access-title" class="text-2xl font-bold text-ink">Accesos activos</h2>
					<p class="mt-2 leading-7 text-muted">
						{data.accessRoster.length}
						{data.accessRoster.length === 1 ? 'persona autorizada' : 'personas autorizadas'}.
					</p>
				</div>
			</div>

			<ul class="mt-6 space-y-4">
				{#each data.accessRoster as access (access.id)}
					<li
						class="rounded-2xl border border-white/80 bg-white p-5 shadow-sm shadow-brand/5 sm:p-6"
					>
						<div class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
							<div class="min-w-0">
								<div class="flex flex-wrap items-center gap-2">
									<h3 class="text-lg font-bold break-words text-ink">{access.displayName}</h3>
									{#if access.isCurrentUser}
										<span
											class="rounded-full bg-surface-muted px-3 py-1 text-xs font-bold text-brand"
											>Tú</span
										>
									{/if}
								</div>
								<p class="mt-2 text-sm leading-6 text-muted">
									{access.role === 'ADMIN' ? 'Administrador' : 'Monitor'} · {relationshipLabel(
										access.relationship
									)}
								</p>
								<p class="mt-1 text-sm leading-6 text-muted">
									Acceso concedido el
									<time datetime={access.grantedAt}
										>{dateFormatter.format(new Date(access.grantedAt))}</time
									>.
								</p>
							</div>

							{#if access.role === 'MONITOR'}
								<details class="group w-full sm:w-auto sm:min-w-52">
									<summary
										class="flex min-h-12 cursor-pointer list-none items-center justify-center rounded-xl border border-red-800/25 bg-white px-4 font-bold text-red-800 transition hover:bg-red-50 focus:ring-4 focus:ring-red-700/20 focus:outline-none"
									>
										Revocar acceso
									</summary>
									<div class="mt-3 rounded-2xl border border-red-800/20 bg-red-50 p-4">
										<p class="text-sm leading-6 text-red-950">
											¿Revocar el acceso de <strong>{access.displayName}</strong>? Perderá
											inmediatamente el acceso al paciente, su dispositivo y sus ubicaciones.
										</p>
										<form method="POST" action="?/revoke" class="mt-3">
											<input type="hidden" name="accessId" value={access.id} />
											<button
												type="submit"
												class="min-h-12 w-full cursor-pointer rounded-xl bg-red-800 px-4 font-bold text-white transition hover:bg-red-900 focus:ring-4 focus:ring-red-700/30 focus:outline-none"
											>
												Sí, revocar acceso
											</button>
										</form>
									</div>
								</details>
							{/if}
						</div>
					</li>
				{/each}
			</ul>
		</section>
	</div>
</main>
