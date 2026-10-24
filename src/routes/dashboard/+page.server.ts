import { redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ locals, url }) => {
	if (!locals.user || !locals.supabase) {
		redirect(303, `/auth/login?next=${encodeURIComponent(url.pathname)}`);
	}

	const [profileResult, accessResult] = await Promise.all([
		locals.supabase.from('profiles').select('full_name').eq('id', locals.user.id).maybeSingle(),
		locals.supabase
			.from('patient_access')
			.select(
				'access_role, patient:patients!inner(id, first_name, last_name, created_at, group:groups!inner(id, name, type))'
			)
			.eq('user_id', locals.user.id)
			.is('revoked_at', null)
			.order('created_at', { referencedTable: 'patients', ascending: false })
	]);

	const patients = (accessResult.data ?? []).flatMap((access) => {
		const patient = Array.isArray(access.patient) ? access.patient[0] : access.patient;
		if (!patient) return [];

		const group = Array.isArray(patient.group) ? patient.group[0] : patient.group;

		return [
			{
				id: patient.id,
				firstName: patient.first_name,
				lastName: patient.last_name,
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
	});

	return {
		profile: profileResult.error ? null : profileResult.data,
		profileAvailable: !profileResult.error,
		patients,
		patientsAvailable: !accessResult.error,
		patientCreated: url.searchParams.get('created') === 'patient',
		user: locals.user
	};
};
