export type AlertEpisodeRealtimeState = 'CONNECTING' | 'CONNECTED' | 'ERROR';

export type AlertEpisodeRealtimeRow = {
	id: string;
	patient_id: string;
	status: 'OPEN' | 'RESOLVED';
	confirmed_at: string;
	resolved_at: string | null;
	updated_at: string;
};
