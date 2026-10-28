<script lang="ts">
	import { resolve } from '$app/paths';
	import { page } from '$app/state';
	import HeartHandshake from '@lucide/svelte/icons/heart-handshake';
	import House from '@lucide/svelte/icons/house';
	import LogOut from '@lucide/svelte/icons/log-out';
	import Siren from '@lucide/svelte/icons/siren';
	import UserRound from '@lucide/svelte/icons/user-round';

	type ModuleId = 'dashboard' | 'patients' | 'alerts' | 'profile';

	const items = [
		{
			id: 'dashboard' as const,
			label: 'Inicio',
			href: resolve('/dashboard'),
			icon: House
		},
		{
			id: 'patients' as const,
			label: 'Pacientes',
			href: resolve('/patients'),
			icon: HeartHandshake
		},
		{ id: 'alerts' as const, label: 'Alertas', href: resolve('/alerts'), icon: Siren },
		{ id: 'profile' as const, label: 'Perfil', href: resolve('/settings'), icon: UserRound }
	];

	let pathname = $derived(page.url.pathname);

	function matchesRoute(route: string) {
		return pathname === route || pathname.startsWith(`${route}/`);
	}

	function isActive(moduleId: ModuleId) {
		switch (moduleId) {
			case 'dashboard':
				return matchesRoute(resolve('/dashboard'));
			case 'patients':
				return (
					matchesRoute(resolve('/patients')) ||
					matchesRoute(resolve('/groups')) ||
					matchesRoute(resolve('/access-code')) ||
					matchesRoute(resolve('/onboarding'))
				);
			case 'alerts':
				return matchesRoute(resolve('/alerts'));
			case 'profile':
				return matchesRoute(resolve('/settings'));
		}
	}
</script>

<nav
	aria-label="Módulos principales"
	class="fixed right-2 bottom-2 left-2 z-40 rounded-2xl border border-white/80 bg-white/90 px-2 py-2 shadow-sm backdrop-blur-xl sm:right-4 sm:bottom-4 sm:left-4 lg:inset-y-4 lg:right-auto lg:left-4 lg:flex lg:w-64 lg:flex-col lg:border-white/10 lg:bg-ink lg:px-4 lg:py-5 lg:shadow-none lg:backdrop-blur-none"
>
	<a
		href={resolve('/dashboard')}
		class="hidden min-h-12 items-center gap-3 rounded-2xl px-3 text-2xl font-bold text-white focus:ring-4 focus:ring-white/30 focus:outline-none lg:inline-flex"
	>
		<span
			class="grid size-9 place-items-center rounded-xl bg-white text-base text-ink"
			aria-hidden="true">S</span
		>
		<span>Senda</span>
	</a>

	<ul class="grid grid-cols-4 gap-1 lg:mt-10 lg:flex lg:flex-col lg:gap-2">
		{#each items as item (item.id)}
			{@const Icon = item.icon}
			{@const active = isActive(item.id)}
			<li>
				<a
					href={item.href}
					aria-current={active ? 'page' : undefined}
					class={[
						'group flex min-h-14 flex-col items-center justify-center gap-0.5 rounded-2xl px-1 py-1 text-xs leading-4 font-medium transition-colors focus:ring-4 focus:ring-focus/30 focus:outline-none lg:min-h-12 lg:flex-row lg:justify-start lg:gap-3 lg:px-4 lg:py-2 lg:text-base',
						active
							? 'text-brand lg:bg-white lg:text-ink'
							: 'text-muted hover:bg-ink/5 hover:text-ink lg:text-white/65 lg:hover:bg-white/10 lg:hover:text-white'
					]}
				>
					<span
						class={[
							'grid h-8 w-16 place-items-center rounded-full transition-colors lg:contents',
							active
								? 'bg-surface-muted lg:bg-transparent'
								: 'group-hover:bg-ink/5 lg:bg-transparent'
						]}
					>
						<Icon size={24} strokeWidth={2} aria-hidden="true" />
					</span>
					<span>{item.label}</span>
				</a>
			</li>
		{/each}
	</ul>

	<div class="mt-auto hidden border-t border-white/10 pt-4 lg:block">
		<form method="POST" action={resolve('/auth/logout')}>
			<button
				type="submit"
				class="flex min-h-12 w-full cursor-pointer items-center gap-3 rounded-2xl px-4 text-left font-medium text-white/65 transition-colors hover:bg-white/10 hover:text-white focus:ring-4 focus:ring-white/25 focus:outline-none"
			>
				<LogOut size={22} strokeWidth={2} aria-hidden="true" />
				<span>Cerrar sesión</span>
			</button>
		</form>
	</div>
</nav>
