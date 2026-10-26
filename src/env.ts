import { defineEnvVars } from '@sveltejs/kit/env';

function optionalTrimmedString(value: string | undefined): string {
	return value?.trim() ?? '';
}

function optionalBooleanFlag(value: string | undefined): boolean {
	return value?.trim().toLowerCase() === 'true';
}

export const variables = defineEnvVars({
	PUBLIC_SUPABASE_URL: {
		public: true,
		static: true,
		schema: optionalTrimmedString
	},
	PUBLIC_SUPABASE_PUBLISHABLE_KEY: {
		public: true,
		static: true,
		schema: optionalTrimmedString
	},
	PUBLIC_GOOGLE_MAPS_API_KEY: {
		public: true,
		static: true,
		schema: optionalTrimmedString
	},
	PUBLIC_VAPID_PUBLIC_KEY: {
		public: true,
		static: true,
		schema: optionalTrimmedString
	},
	SENDA_ENABLE_MANUAL_LOCATION_SIMULATOR: {
		description: 'Enables the development-only manual location simulator on patient maps.',
		schema: optionalBooleanFlag
	}
});
