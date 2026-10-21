import type { SupabaseClient } from '@supabase/supabase-js';

declare global {
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
