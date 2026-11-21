<!-- Marcador de posición mientras carga la siguiente pantalla. Aparece solo si la carga se demora. -->
<div
	class="px-5 py-8 sm:px-8 lg:px-0"
	role="status"
	aria-live="polite"
	aria-busy="true"
	aria-label="Cargando la pantalla"
>
	<span class="sr-only">Cargando…</span>

	<div class="skeleton h-8 w-56 max-w-full rounded-lg" aria-hidden="true"></div>

	<div class="mt-8 grid gap-5 md:grid-cols-2 xl:grid-cols-3" aria-hidden="true">
		{#each [0, 1, 2] as card (card)}
			<div class="rounded-2xl bg-white p-6 shadow-sm">
				<div class="flex items-start gap-4">
					<div class="skeleton size-12 shrink-0 rounded-full"></div>
					<div class="min-w-0 flex-1 space-y-3">
						<div class="skeleton h-4 w-2/5 rounded"></div>
						<div class="skeleton h-5 w-4/5 rounded"></div>
					</div>
				</div>
				<div class="mt-6 space-y-3">
					<div class="skeleton h-4 w-full rounded"></div>
					<div class="skeleton h-4 w-3/4 rounded"></div>
				</div>
				<div class="skeleton mt-6 h-12 w-full rounded-full"></div>
			</div>
		{/each}
	</div>
</div>
