import { PUBLIC_SUPABASE_PUBLISHABLE_KEY, PUBLIC_SUPABASE_URL } from '$app/env/public';
import { createServerClient } from '@supabase/ssr';
import type { RequestEvent } from '@sveltejs/kit';

function hasValidPublicConfiguration(): boolean {
	if (
		!PUBLIC_SUPABASE_URL ||
		!PUBLIC_SUPABASE_PUBLISHABLE_KEY ||
		PUBLIC_SUPABASE_URL.includes('your-project-ref') ||
		PUBLIC_SUPABASE_PUBLISHABLE_KEY.includes('your-publishable-key')
	) {
		return false;
	}

	try {
		return new URL(PUBLIC_SUPABASE_URL).protocol === 'https:';
	} catch {
		return false;
	}
}

export const supabaseConfigured = hasValidPublicConfiguration();

export function createRequestSupabase(event: RequestEvent) {
	if (!supabaseConfigured) return null;

	return createServerClient(PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_PUBLISHABLE_KEY, {
		cookies: {
			getAll: () => event.cookies.getAll(),
			setAll: (cookiesToSet, headers) => {
				for (const { name, value, options } of cookiesToSet) {
					event.cookies.set(name, value, { ...options, path: '/' });
				}

				if (Object.keys(headers).length > 0) {
					event.setHeaders(headers);
				}
			}
		}
	});
}
