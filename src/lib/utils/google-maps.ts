import { PUBLIC_GOOGLE_MAPS_API_KEY } from '$app/env/public';
import { importLibrary, setOptions } from '@googlemaps/js-api-loader';

export const hasGoogleMapsConfig = Boolean(PUBLIC_GOOGLE_MAPS_API_KEY);

let isConfigured = false;

function configureMapsLoader(): void {
	if (!hasGoogleMapsConfig) {
		throw new Error('Falta configurar PUBLIC_GOOGLE_MAPS_API_KEY.');
	}

	if (!isConfigured) {
		setOptions({ key: PUBLIC_GOOGLE_MAPS_API_KEY, v: 'weekly' });
		isConfigured = true;
	}
}

export async function loadMapsLibrary() {
	configureMapsLoader();

	return importLibrary('maps');
}

export async function loadMapDisplayLibraries() {
	configureMapsLoader();

	return Promise.all([importLibrary('maps'), importLibrary('marker'), importLibrary('core')]);
}
