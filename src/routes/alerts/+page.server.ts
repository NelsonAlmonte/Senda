import { redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ depends, locals, url }) => {
	if (!locals.user || !locals.supabase) {
		redirect(303, `/auth/login?next=${encodeURIComponent(url.pathname)}`);
	}

	depends('senda:alert-episodes');

	const result = await locals.supabase
		.from('alert_episodes')
		.select(
			'id, patient_id, status, started_at, confirmed_at, resolved_at, updated_at, patient:patients!inner(id, first_name, last_name)'
		)
		.order('confirmed_at', { ascending: false })
		.limit(100);

	const episodes = (result.data ?? [])
		.flatMap((episode) => {
			const patient = Array.isArray(episode.patient) ? episode.patient[0] : episode.patient;
			if (!patient) return [];

			return [
				{
					id: episode.id,
					patientId: episode.patient_id,
					patientName: `${patient.first_name} ${patient.last_name}`,
					status: episode.status as 'OPEN' | 'RESOLVED',
					startedAt: episode.started_at,
					confirmedAt: episode.confirmed_at,
					resolvedAt: episode.resolved_at,
					updatedAt: episode.updated_at
				}
			];
		})
		.sort((a, b) => {
			if (a.status !== b.status) return a.status === 'OPEN' ? -1 : 1;
			return Date.parse(b.confirmedAt) - Date.parse(a.confirmedAt);
		});

	return {
		episodes,
		episodesAvailable: !result.error
	};
};
