export type GroupMode = 'new' | 'existing';
export type GroupType = 'FAMILY' | 'CARE_CENTER';

export interface GroupOption {
	id: string;
	name: string;
	type: GroupType;
	created_at?: string;
}

export interface SetupPatient {
	id: string;
	firstName: string;
	lastName: string;
	groupName: string;
	groupType: GroupType;
	serialNumber: string | null;
}

export interface PatientSetupData {
	groups: GroupOption[];
	groupsAvailable: boolean;
	initialMode: 'new' | 'patient' | null;
	onboardingPatient: SetupPatient | null;
}

export type SetupErrors = Record<string, string>;

export type SetupFormValues = Partial<{
	groupMode: string;
	groupId: string;
	groupName: string;
	groupType: string;
	patientFirstName: string;
	patientLastName: string;
	serialNumber: string;
}>;

export interface PatientSetupFormState {
	stage?: string;
	errors?: SetupErrors;
	values?: SetupFormValues;
}
