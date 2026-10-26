<script module lang="ts">
	export type DashboardAlertEpisodeRealtimeState = 'CONNECTING' | 'CONNECTED' | 'ERROR';

	export type DashboardAlertEpisodeRealtimeRow = {
		id: string;
		patient_id: string;
		status: 'OPEN' | 'RESOLVED';
		confirmed_at: string;
		resolved_at: string | null;
		updated_at: string;
	};
</script>

<script lang="ts">
	import { createBrowserSupabaseClient } from '#lib';
	import { onMount } from 'svelte';

	type Props = {
		onAlertEpisode: (episode: DashboardAlertEpisodeRealtimeRow) => void;
		onStateChange: (state: DashboardAlertEpisodeRealtimeState) => void;
	};

	let { onAlertEpisode, onStateChange }: Props = $props();

	onMount(() => {
		let disposed = false;
		let supabase;

		try {
			supabase = createBrowserSupabaseClient();
		} catch {
			onStateChange('ERROR');
			return;
		}

		onStateChange('CONNECTING');
		const channel = supabase
			.channel('dashboard-alert-episodes', {
				config: { postgres_changes_options: { wait: true } }
			})
			.on<DashboardAlertEpisodeRealtimeRow>(
				'postgres_changes',
				{ event: 'INSERT', schema: 'public', table: 'alert_episodes' },
				(payload) => {
					if (!disposed) onAlertEpisode(payload.new);
				}
			)
			.on<DashboardAlertEpisodeRealtimeRow>(
				'postgres_changes',
				{ event: 'UPDATE', schema: 'public', table: 'alert_episodes' },
				(payload) => {
					if (!disposed) onAlertEpisode(payload.new);
				}
			)
			.subscribe((status) => {
				if (disposed) return;

				if (status === 'SUBSCRIBED') {
					onStateChange('CONNECTED');
				} else if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT') {
					onStateChange('ERROR');
				} else if (status === 'CLOSED') {
					onStateChange('CONNECTING');
				}
			});

		return () => {
			disposed = true;
			void supabase.removeChannel(channel);
		};
	});
</script>
