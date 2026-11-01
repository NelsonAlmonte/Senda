import {
	assignSetupDevice,
	createSetupPatient,
	loadPatientSetup,
	type PatientSetupActionOptions
} from '#lib/server/patient-setup.js';
import type { Actions, PageServerLoad } from './$types';

const actionOptions: PatientSetupActionOptions = {
	afterPatientCreated: (patientId) =>
		`/groups?step=device&patient=${encodeURIComponent(patientId)}`,
	afterDeviceAssigned: () => '/patients?configured=device'
};

export const load: PageServerLoad = loadPatientSetup;

export const actions: Actions = {
	createPatient: (event) => createSetupPatient(event, actionOptions),
	assignDevice: (event) => assignSetupDevice(event, actionOptions)
};
