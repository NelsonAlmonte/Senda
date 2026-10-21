import { createRequestSupabase, supabaseConfigured } from '#lib/server/supabase.js';
import type { Handle } from '@sveltejs/kit/hooks';

export const handle: Handle = async ({ event, resolve }) => {
	event.locals.supabaseConfigured = supabaseConfigured;
	event.locals.supabase = createRequestSupabase(event);
	event.locals.user = null;

	if (event.locals.supabase) {
		const { data, error } = await event.locals.supabase.auth.getClaims();
		const claims = data?.claims;
		const subject = claims?.sub;

		if (!error && claims && typeof subject === 'string') {
			event.locals.user = {
				id: subject,
				email: typeof claims.email === 'string' ? claims.email : null
			};
		}
	}

	return resolve(event, {
		filterSerializedResponseHeaders: (name) =>
			name === 'content-range' || name === 'x-supabase-api-version'
	});
};
