import {
	acceptPatientAccessCode,
	previewPatientAccessCode
} from '#lib/server/patient-access-code.js';
import { redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';

export const load: PageServerLoad = ({ locals, url }) => {
	if (!locals.user || !locals.supabase) {
		redirect(303, `/auth/login?next=${encodeURIComponent(url.pathname)}`);
	}
	return {};
};

export const actions: Actions = {
	preview: previewPatientAccessCode,
	accept: (event) =>
		acceptPatientAccessCode(event, {
			outcome: 'redirect',
			redirectTo: '/patients?access=accepted'
		})
};
