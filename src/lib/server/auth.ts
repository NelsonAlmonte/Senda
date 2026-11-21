export function normalizeEmail(value: FormDataEntryValue | null): string {
	return typeof value === 'string' ? value.trim().toLowerCase() : '';
}

export function readText(value: FormDataEntryValue | null): string {
	return typeof value === 'string' ? value.trim() : '';
}

export function isValidEmail(email: string): boolean {
	return email.length <= 254 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

const REDIRECT_PROBE_ORIGIN = 'http://senda.invalid';

export function safeRedirectPath(value: string | null, fallback = '/dashboard'): string {
	if (!value || !value.startsWith('/') || value.startsWith('//') || value.includes('\\')) {
		return fallback;
	}

	// Los navegadores descartan tabuladores y saltos de línea al interpretar una URL,
	// de modo que "/\t/host" se convierte en "//host". Se rechazan los caracteres de control
	// y se comprueba que el destino siga resolviéndose dentro del mismo origen.
	// eslint-disable-next-line no-control-regex
	if (/[\u0000-\u001f\u007f]/.test(value)) return fallback;

	try {
		if (new URL(value, REDIRECT_PROBE_ORIGIN).origin !== REDIRECT_PROBE_ORIGIN) return fallback;
	} catch {
		return fallback;
	}

	return value;
}
