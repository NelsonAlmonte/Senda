<script lang="ts">
	import LoaderCircle from '@lucide/svelte/icons/loader-circle';
	import LogOut from '@lucide/svelte/icons/log-out';
	import AuthShell from '#lib/components/ui/AuthShell.svelte';
</script>

<svelte:head><title>Cerrando sesión | Senda</title></svelte:head>

<AuthShell
	icon={LogOut}
	eyebrow="Sesión segura"
	title="Cerrando sesión…"
	description="Estamos retirando el acceso de este navegador."
>
	<div class="flex items-center gap-3 rounded-2xl bg-canvas p-4 text-muted" role="status">
		<LoaderCircle aria-hidden="true" class="animate-spin text-brand" size={22} strokeWidth={2} />
		<p>Espera un momento.</p>
	</div>
</AuthShell>
