import type { SupabaseClient } from '@supabase/supabase-js';

declare global {
	interface SendaBeforeInstallPromptEvent extends Event {
		prompt(): Promise<{ outcome: 'accepted' | 'dismissed'; platform: string }>;
	}

	interface WindowEventMap {
		beforeinstallprompt: SendaBeforeInstallPromptEvent;
		appinstalled: Event;
	}

	namespace App {
		interface AuthUser {
			id: string;
			email: string | null;
		}

		interface Locals {
			supabase: SupabaseClient | null;
			supabaseConfigured: boolean;
			user: AuthUser | null;
		}
	}
}

export {};
