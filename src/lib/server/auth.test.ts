import assert from 'node:assert/strict';
import { test } from 'node:test';
import { safeRedirectPath } from './auth.ts';

const FALLBACK = '/dashboard';

test('conserva rutas internas válidas, con consulta y ancla', () => {
	assert.equal(safeRedirectPath('/patients'), '/patients');
	assert.equal(safeRedirectPath('/patients/abc/map?x=1#y'), '/patients/abc/map?x=1#y');
});

test('usa la ruta por defecto cuando no hay destino', () => {
	assert.equal(safeRedirectPath(null), FALLBACK);
	assert.equal(safeRedirectPath(''), FALLBACK);
	assert.equal(safeRedirectPath('patients'), FALLBACK);
});

test('rechaza URLs absolutas y de mismo protocolo', () => {
	assert.equal(safeRedirectPath('https://evil.com'), FALLBACK);
	assert.equal(safeRedirectPath('//evil.com'), FALLBACK);
	assert.equal(safeRedirectPath('/\\evil.com'), FALLBACK);
});

test('rechaza caracteres de control que el navegador elimina al interpretar la URL', () => {
	// "/\t/evil.com" se interpreta como "//evil.com" y sale del sitio.
	assert.equal(safeRedirectPath('/\t/evil.com'), FALLBACK);
	assert.equal(safeRedirectPath('/\n/evil.com'), FALLBACK);
	assert.equal(safeRedirectPath('/\r/evil.com'), FALLBACK);
	assert.equal(safeRedirectPath('/\u0000/evil.com'), FALLBACK);
});

test('ninguna ruta aceptada puede resolverse fuera del origen', () => {
	for (const candidate of ['/a', '/a/b?c=d', '/%2F/evil.com', '/%09/evil.com', '/.//evil.com']) {
		const result = safeRedirectPath(candidate);
		assert.equal(new URL(result, 'https://senda.example').origin, 'https://senda.example');
	}
});

test('usa la ruta de reserva indicada', () => {
	assert.equal(safeRedirectPath('//evil.com', '/patients'), '/patients');
});
