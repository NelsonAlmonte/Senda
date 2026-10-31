import { resolve } from '$app/paths';
import { error as httpError, redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

const PAGE_SIZE = 12;

function pagePath(patientId: string, page: number): string {
	const path = resolve('/patients/[id]/episodes', { id: patientId });
	return page === 1 ? path : `${path}?page=${page}`;
}

function parsePage(value: string | null): number | null {
	if (value === null) return 1;
	if (!/^\d+$/.test(value)) return null;

	const page = Number(value);
	return Number.isSafeInteger(page) && page >= 1 ? page : null;
}

export const load: PageServerLoad = async ({ depends, locals, params, url }) => {
	if (!locals.user || !locals.supabase) {
		redirect(303, `/auth/login?next=${encodeURIComponent(url.pathname + url.search)}`);
	}

	const requestedPage = parsePage(url.searchParams.get('page'));
	if (requestedPage === null) redirect(303, pagePath(params.id, 1));

	depends('senda:patient-alerts');

	const { data: access, error: accessError } = await locals.supabase
		.from('patient_access')
		.select('access_role, patient:patients!inner(id, first_name, last_name)')
		.eq('patient_id', params.id)
		.eq('user_id', locals.user.id)
		.is('revoked_at', null)
		.maybeSingle();

	if (accessError) httpError(500, 'No pudimos verificar tu acceso al paciente.');
	if (!access) httpError(404, 'Paciente no encontrado.');

	const patient = Array.isArray(access.patient) ? access.patient[0] : access.patient;
	if (!patient) httpError(404, 'Paciente no encontrado.');

	const from = (requestedPage - 1) * PAGE_SIZE;
	const to = from + PAGE_SIZE - 1;
	const [activeResult, historyResult] = await Promise.all([
		locals.supabase
			.from('alert_episodes')
			.select('id, patient_id, status, started_at, confirmed_at, resolved_at, updated_at')
			.eq('patient_id', params.id)
			.eq('status', 'OPEN')
			.order('confirmed_at', { ascending: false })
			.order('id', { ascending: false })
			.limit(1)
			.maybeSingle(),
		locals.supabase
			.from('alert_episodes')
			.select('id, patient_id, status, started_at, confirmed_at, resolved_at, updated_at', {
				count: 'exact'
			})
			.eq('patient_id', params.id)
			.eq('status', 'RESOLVED')
			.order('confirmed_at', { ascending: false })
			.order('id', { ascending: false })
			.range(from, to)
	]);

	const totalCount = historyResult.count ?? 0;
	const totalPages = Math.max(1, Math.ceil(totalCount / PAGE_SIZE));
	if (!historyResult.error && requestedPage > totalPages) {
		redirect(303, pagePath(params.id, totalPages));
	}

	return {
		patient: {
			id: patient.id,
			firstName: patient.first_name,
			lastName: patient.last_name,
			accessRole: access.access_role as 'ADMIN' | 'MONITOR'
		},
		activeEpisode: activeResult.data
			? {
					id: activeResult.data.id,
					patientId: activeResult.data.patient_id,
					status: activeResult.data.status as 'OPEN',
					startedAt: activeResult.data.started_at,
					confirmedAt: activeResult.data.confirmed_at,
					resolvedAt: activeResult.data.resolved_at,
					updatedAt: activeResult.data.updated_at
				}
			: null,
		activeEpisodeAvailable: !activeResult.error,
		resolvedEpisodes: (historyResult.data ?? []).map((episode) => ({
			id: episode.id,
			patientId: episode.patient_id,
			status: episode.status as 'RESOLVED',
			startedAt: episode.started_at,
			confirmedAt: episode.confirmed_at,
			resolvedAt: episode.resolved_at,
			updatedAt: episode.updated_at
		})),
		historyAvailable: !historyResult.error,
		pagination: {
			page: requestedPage,
			pageSize: PAGE_SIZE,
			totalCount,
			totalPages,
			hasPrevious: requestedPage > 1,
			hasNext: requestedPage < totalPages
		}
	};
};
