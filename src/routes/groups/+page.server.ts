import { readText } from '#lib/server/auth.js';
import { fail, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';

const groupTypes = ['FAMILY', 'CARE_CENTER'] as const;
type GroupType = (typeof groupTypes)[number];

function isGroupType(value: string): value is GroupType {
	return groupTypes.includes(value as GroupType);
}

export const load: PageServerLoad = async ({ locals, url }) => {
	if (!locals.user || !locals.supabase) {
		redirect(303, `/auth/login?next=${encodeURIComponent(url.pathname)}`);
	}

	const { data: groups, error } = await locals.supabase
		.from('groups')
		.select('id, name, type, created_at')
		.eq('owner_user_id', locals.user.id)
		.order('created_at', { ascending: false });

	return {
		groups: error ? [] : groups,
		groupsAvailable: !error
	};
};

export const actions: Actions = {
	default: async ({ locals, request }) => {
		if (!locals.user || !locals.supabase) redirect(303, '/auth/login?next=/groups');

		const formData = await request.formData();
		const groupName = readText(formData.get('groupName'));
		const groupType = readText(formData.get('groupType'));
		const patientFirstName = readText(formData.get('patientFirstName'));
		const patientLastName = readText(formData.get('patientLastName'));
		const errors: Record<string, string> = {};

		if (!groupName) errors.groupName = 'Introduce el nombre del grupo.';
		else if (groupName.length > 120)
			errors.groupName = 'El nombre del grupo no puede superar 120 caracteres.';

		if (!isGroupType(groupType)) errors.groupType = 'Selecciona un tipo de grupo válido.';

		if (!patientFirstName) errors.patientFirstName = 'Introduce el nombre del paciente.';
		else if (patientFirstName.length > 80)
			errors.patientFirstName = 'El nombre no puede superar 80 caracteres.';

		if (!patientLastName) errors.patientLastName = 'Introduce el apellido del paciente.';
		else if (patientLastName.length > 80)
			errors.patientLastName = 'El apellido no puede superar 80 caracteres.';

		const values = { groupName, groupType, patientFirstName, patientLastName };

		if (Object.keys(errors).length > 0) return fail(400, { errors, values });

		const { data, error } = await locals.supabase.rpc('create_patient_onboarding', {
			p_group_name: groupName,
			p_group_type: groupType,
			p_patient_first_name: patientFirstName,
			p_patient_last_name: patientLastName
		});
		const createdPatientId = data?.[0]?.created_patient_id;

		if (error || !createdPatientId) {
			return fail(400, {
				errors: {
					form: 'No pudimos crear el grupo y el paciente. Revisa los datos e inténtalo nuevamente.'
				},
				values
			});
		}

		redirect(303, `/patients/${createdPatientId}/device?onboarding=1`);
	}
};
