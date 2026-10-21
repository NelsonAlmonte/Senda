import tailwindcss from '@tailwindcss/vite';
import adapter from '@sveltejs/adapter-netlify';
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';
import { VitePWA } from 'vite-plugin-pwa';

function createSvelteKitPwaPlugins() {
	const plugins = VitePWA({
		outDir: '.svelte-kit/output/client',
		registerType: 'autoUpdate',
		injectRegister: null,
		devOptions: {
			enabled: true
		},
		includeAssets: [
			'favicon.ico',
			'pwa-source.svg',
			'pwa-64x64.png',
			'pwa-192x192.png',
			'pwa-512x512.png',
			'maskable-icon-512x512.png',
			'apple-touch-icon-180x180.png'
		],
		manifest: {
			name: 'Senda — Monitoreo preventivo',
			short_name: 'Senda',
			description:
				'Plataforma de apoyo para geolocalización, monitoreo preventivo y alertas tempranas.',
			start_url: '/',
			scope: '/',
			display: 'standalone',
			background_color: '#f6f8f5',
			theme_color: '#355f55',
			lang: 'es',
			icons: [
				{
					src: '/pwa-64x64.png',
					sizes: '64x64',
					type: 'image/png'
				},
				{
					src: '/pwa-192x192.png',
					sizes: '192x192',
					type: 'image/png'
				},
				{
					src: '/pwa-512x512.png',
					sizes: '512x512',
					type: 'image/png'
				},
				{
					src: '/maskable-icon-512x512.png',
					sizes: '512x512',
					type: 'image/png',
					purpose: 'maskable'
				}
			]
		},
		workbox: {
			globDirectory: '.svelte-kit/output/client',
			globPatterns: ['**/*.{js,css,html,ico,png,svg,webmanifest,woff2}'],
			cleanupOutdatedCaches: true,
			clientsClaim: true,
			skipWaiting: true,
			navigateFallback: undefined,
			runtimeCaching: []
		}
	});

	// SvelteKit 3 does not expose Vite's transformIndexHtml hook. The layout adds the
	// manifest link and registers the service worker, so these hooks are unnecessary.
	for (const plugin of plugins) {
		plugin.applyToEnvironment = (environment) => environment.name === 'client';
		delete plugin.transformIndexHtml;
	}

	return plugins;
}

export default defineConfig({
	plugins: [
		tailwindcss(),
		sveltekit({
			compilerOptions: {
				runes: ({ filename }) =>
					filename.split(/[/\\]/).includes('node_modules') ? undefined : true
			},
			adapter: adapter({
				edge: false,
				split: false,
				publish: 'build'
			})
		}),
		...createSvelteKitPwaPlugins()
	]
});
