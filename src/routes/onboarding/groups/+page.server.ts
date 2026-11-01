import {
	assignSetupDevice,
	createSetupPatient,
	loadPatientSetup,
	type PatientSetupActionOptions
} from '#lib/server/patient-setup.js';
import type { Actions, PageServerLoad } from './$types';

const actionOptions: PatientSetupActionOptions = {
	afterPatientCreated: (patientId) =>
		`/onboarding/groups?step=device&patient=${encodeURIComponent(patientId)}`,
	afterDeviceAssigned: (patientId) =>
		`/onboarding/groups?completed=configured&patient=${encodeURIComponent(patientId)}`
};

export const load: PageServerLoad = async (event) => {
	const data = await loadPatientSetup(event);
	const requestedCompletion = event.url.searchParams.get('completed');
	const completion =
		requestedCompletion === 'configured' && data.onboardingPatient?.serialNumber
			? 'configured'
			: requestedCompletion === 'deferred' && data.onboardingPatient
				? 'deferred'
				: null;

	return { ...data, completion };
};

export const actions: Actions = {
	createPatient: (event) => createSetupPatient(event, actionOptions),
	assignDevice: (event) => assignSetupDevice(event, actionOptions)
};
