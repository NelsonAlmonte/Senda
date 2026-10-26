<script module lang="ts">
	import type { GeofenceAlertEpisodeStatus, LocationGeofenceRelation } from './presentation.js';

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
		geofence_relation: LocationGeofenceRelation;
		matched_safe_zone_id: string | null;
		distance_to_boundary_m: number | null;
		effective_tolerance_m: number | null;
		geofence_evaluated_at: string | null;
	};

	export type LocationRealtimeState = 'CONNECTING' | 'CONNECTED' | 'ERROR';

	export type AlertEpisodeRealtimeRow = {
		id: string;
		patient_id: string;
		device_assignment_id: string;
		status: GeofenceAlertEpisodeStatus;
		started_at: string;
		confirmed_at: string;
		resolved_at: string | null;
		first_outside_location_id: number;
		confirmed_by_location_id: number;
		resolved_by_location_id: number | null;
		created_at: string;
		updated_at: string;
	};
</script>

<script lang="ts">
	import { createBrowserSupabaseClient } from '#lib';
	import { onMount } from 'svelte';

	type Props = {
		assignmentId: string;
		patientId: string;
		onLocation: (location: LocationRealtimeRow) => void;
		onAlertEpisode: (episode: AlertEpisodeRealtimeRow) => void;
		onStateChange: (state: LocationRealtimeState) => void;
	};

	let { assignmentId, patientId, onLocation, onAlertEpisode, onStateChange }: Props = $props();

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
			.on<AlertEpisodeRealtimeRow>(
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
			.on<AlertEpisodeRealtimeRow>(
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
