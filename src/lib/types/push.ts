export type PushNotificationState =
	'CHECKING' | 'ACTIVE' | 'INACTIVE' | 'BLOCKED' | 'UNSUPPORTED' | 'UNCONFIGURED' | 'ERROR';

export interface PushNotificationStatus {
	detail?: string;
	state: PushNotificationState;
}
