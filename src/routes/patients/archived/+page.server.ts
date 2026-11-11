import { redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ locals, url }) => {
	if (!locals.user || !locals.supabase) {
		redirect(303, `/auth/login?next=${encodeURIComponent(url.pathname)}`);
	}

	const accessResult = await locals.supabase
		.from('patient_access')
		.select(
			'access_role, patient:patients!inner(id, first_name, last_name, archived_at, group:groups!inner(id, name, type))'
		)
		.eq('user_id', locals.user.id)
		.is('revoked_at', null);

	const archivedPatients = (accessResult.data ?? [])
		.flatMap((access) => {
			const patient = Array.isArray(access.patient) ? access.patient[0] : access.patient;
			if (!patient?.archived_at) return [];

			const group = Array.isArray(patient.group) ? patient.group[0] : patient.group;

			return [
				{
					id: patient.id,
					firstName: patient.first_name,
					lastName: patient.last_name,
					archivedAt: patient.archived_at,
					accessRole: access.access_role,
					group: group
						? {
								id: group.id,
								name: group.name,
								type: group.type
							}
						: null
				}
			];
		})
		.sort((left, right) => Date.parse(right.archivedAt) - Date.parse(left.archivedAt));

	return {
		archivedPatients,
		patientsAvailable: !accessResult.error,
		patientArchived: url.searchParams.get('archived') === 'patient',
		patientDeleted: url.searchParams.get('deleted') === 'patient'
	};
};
