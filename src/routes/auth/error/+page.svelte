<script lang="ts">
	import { resolve } from '$app/paths';
	import CircleAlert from '@lucide/svelte/icons/circle-alert';
	import LogIn from '@lucide/svelte/icons/log-in';
	import Alert from '#lib/components/ui/Alert.svelte';
	import AuthShell from '#lib/components/ui/AuthShell.svelte';
</script>

<svelte:head><title>No pudimos confirmar el acceso | Senda</title></svelte:head>

<AuthShell
	icon={CircleAlert}
	eyebrow="Enlace no disponible"
	title="No pudimos confirmar tu acceso."
	description="Puedes volver a iniciar sesión o crear una cuenta nueva si todavía no tienes una."
	alternatePrompt="¿Necesitas una cuenta nueva?"
	alternateHref="/auth/register"
	alternateLabel="Regístrate"
>
	<div class="space-y-6">
		<Alert
			title="El enlace ya no es válido"
			subtitle="Puede haber caducado o haber sido utilizado anteriormente."
			icon={CircleAlert}
			color="danger"
		/>
		<a
			href={resolve('/auth/login')}
			class="inline-flex min-h-12 w-full items-center justify-center gap-2 rounded-xl bg-brand px-5 font-bold text-white transition hover:bg-brand/90 focus:ring-4 focus:ring-focus/35 focus:outline-none"
		>
			<LogIn aria-hidden="true" size={19} strokeWidth={2} />
			Ir a iniciar sesión
		</a>
	</div>
</AuthShell>
