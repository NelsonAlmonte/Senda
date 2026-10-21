import { defineEnvVars } from '@sveltejs/kit/env';

function optionalTrimmedString(value: string | undefined): string {
	return value?.trim() ?? '';
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
	}
});
