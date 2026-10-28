import type { LayoutServerLoad } from './$types';

export const load: LayoutServerLoad = async ({ depends, locals }) => {
	let hasActiveAlert = false;

	if (locals.user && locals.supabase) {
		depends('senda:active-alert-indicator');
		const result = await locals.supabase
			.from('alert_episodes')
			.select('id')
			.eq('status', 'OPEN')
			.limit(1);

		hasActiveAlert = !result.error && (result.data?.length ?? 0) > 0;
	}

	return {
		hasActiveAlert,
		supabaseConfigured: locals.supabaseConfigured,
		user: locals.user
	};
};
