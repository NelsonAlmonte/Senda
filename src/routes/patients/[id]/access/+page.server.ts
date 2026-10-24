import { error as httpError, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';

async function requireAdmin(locals: App.Locals, patientId: string) {
	if (!locals.user || !locals.supabase) redirect(303, '/auth/login');
	const { data } = await locals.supabase
		.from('patient_access')
		.select('access_role, patient:patients!inner(first_name, last_name)')
		.eq('patient_id', patientId)
		.eq('user_id', locals.user.id)
		.is('revoked_at', null)
		.maybeSingle();
	if (!data) httpError(404, 'Paciente no encontrado.');
	if (data.access_role !== 'ADMIN') httpError(403, 'Solo un administrador puede compartir acceso.');
	const patient = Array.isArray(data.patient) ? data.patient[0] : data.patient;
	return { supabase: locals.supabase, patient };
}

export const load: PageServerLoad = async ({ locals, params }) => {
	const { patient } = await requireAdmin(locals, params.id);
	return { patient };
};

export const actions: Actions = {
	default: async ({ locals, params }) => {
		const { supabase } = await requireAdmin(locals, params.id);
		const { data, error } = await supabase.rpc('create_patient_access_code', {
			p_patient_id: params.id
		});
		if (error || !data?.[0]) httpError(400, 'No pudimos generar el código.');
		return { accessCode: data[0].access_code };
	}
};
