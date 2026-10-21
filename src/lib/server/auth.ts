export function normalizeEmail(value: FormDataEntryValue | null): string {
	return typeof value === 'string' ? value.trim().toLowerCase() : '';
}

export function readText(value: FormDataEntryValue | null): string {
	return typeof value === 'string' ? value.trim() : '';
}

export function isValidEmail(email: string): boolean {
	return email.length <= 254 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

export function safeRedirectPath(value: string | null, fallback = '/dashboard'): string {
	if (!value || !value.startsWith('/') || value.startsWith('//') || value.includes('\\')) {
		return fallback;
	}

	return value;
}
