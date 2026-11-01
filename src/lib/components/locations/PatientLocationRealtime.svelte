<script lang="ts">
	import { createBrowserSupabaseClient } from '#lib';
	import type {
		LocationAlertEpisodeRealtimeRow,
		LocationRealtimeRow,
		LocationRealtimeState
	} from '#lib/types/locations.js';
	import { onMount } from 'svelte';

	type Props = {
		assignmentId: string;
		patientId: string;
		onLocation: (location: LocationRealtimeRow) => void;
		onAlertEpisode: (episode: LocationAlertEpisodeRealtimeRow) => void;
		onStateChange?: (state: LocationRealtimeState) => void;
	};

	let {
		assignmentId,
		patientId,
		onLocation,
		onAlertEpisode,
		onStateChange = () => undefined
	}: Props = $props();

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
			.on<LocationAlertEpisodeRealtimeRow>(
				'postgres_changes',
				{
					event: 'INSERT',
					schema: 'public',
					table: 'alert_episodes',
					filter: `patient_id=eq.${patientId}`
				},
				(payload) => {
					if (!disposed) onAlertEpisode(payload.new);
				}
			)
			.on<LocationAlertEpisodeRealtimeRow>(
				'postgres_changes',
				{
					event: 'UPDATE',
					schema: 'public',
					table: 'alert_episodes',
					filter: `patient_id=eq.${patientId}`
				},
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
