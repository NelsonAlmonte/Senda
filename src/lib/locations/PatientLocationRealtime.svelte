<script module lang="ts">
	export type LocationRealtimeRow = {
		id: number;
		device_assignment_id: string;
		event_id: string;
		latitude: number;
		longitude: number;
		accuracy_m: number | null;
		recorded_at: string;
		received_at: string;
		source: string;
	};

	export type LocationRealtimeState = 'CONNECTING' | 'CONNECTED' | 'ERROR';
</script>

<script lang="ts">
	import { createBrowserSupabaseClient } from '#lib';
	import { onMount } from 'svelte';

	type Props = {
		assignmentId: string;
		onLocation: (location: LocationRealtimeRow) => void;
		onStateChange: (state: LocationRealtimeState) => void;
	};

	let { assignmentId, onLocation, onStateChange }: Props = $props();

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
			.channel(`patient-location:${assignmentId}`, {
				config: { postgres_changes_options: { wait: true } }
			})
			.on<LocationRealtimeRow>(
				'postgres_changes',
				{
					event: 'INSERT',
					schema: 'public',
					table: 'locations',
					filter: `device_assignment_id=eq.${assignmentId}`
				},
				(payload) => {
					if (!disposed) onLocation(payload.new);
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
