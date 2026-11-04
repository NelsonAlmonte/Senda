import { createContext } from 'svelte';

export type PwaManualGuide = 'ios-safari' | 'ios-other' | 'macos-safari';

function detectManualGuide(): PwaManualGuide | null {
	const userAgent = navigator.userAgent;
	const isIos =
		/iPad|iPhone|iPod/i.test(userAgent) ||
		(navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
	const isSafari =
		/Safari/i.test(userAgent) &&
		!/Chrome|Chromium|CriOS|Edg|EdgiOS|OPR|Firefox|FxiOS|Android/i.test(userAgent);

	if (isIos) return isSafari ? 'ios-safari' : 'ios-other';
	if (isSafari) return 'macos-safari';

	return null;
}

function isRunningInstalled() {
	const navigatorWithStandalone = navigator as Navigator & { standalone?: boolean };

	return (
		window.matchMedia('(display-mode: standalone)').matches ||
		navigatorWithStandalone.standalone === true
	);
}

export function getPwaManualGuideMessage(guide: PwaManualGuide) {
	if (guide === 'ios-safari') {
		return 'Toca Compartir, elige Añadir a pantalla de inicio y, si aparece, activa Abrir como app.';
	}

	if (guide === 'ios-other') {
		return 'Abre esta página en Safari. Luego toca Compartir, elige Añadir a pantalla de inicio y, si aparece, activa Abrir como app.';
	}

	return 'En macOS Sonoma 14 o posterior, abre Archivo y elige Añadir al Dock.';
}

export function createPwaInstallController() {
	let installPrompt = $state<SendaBeforeInstallPromptEvent | null>(null);
	let installing = $state(false);
	let dismissed = $state(false);
	let installed = $state(false);
	let feedback = $state('');
	let manualGuide = $state<PwaManualGuide | null>(null);

	function initialize() {
		installed = isRunningInstalled();

		if (installed) {
			clearInstallPrompt();
			return;
		}

		if (!installPrompt) manualGuide = detectManualGuide();
	}

	function captureInstallPrompt(event: Event) {
		const promptEvent = event as SendaBeforeInstallPromptEvent;
		promptEvent.preventDefault();

		if (dismissed || installed) return;

		installPrompt = promptEvent;
		manualGuide = null;
		feedback = '';
	}

	function clearInstallPrompt() {
		installPrompt = null;
		manualGuide = null;
		installing = false;
		installed = true;
		dismissed = true;
		feedback = '';
	}

	function dismissUntilReload() {
		installPrompt = null;
		manualGuide = null;
		dismissed = true;
		feedback = '';
	}

	function clearFeedback() {
		feedback = '';
		dismissed = true;
	}

	async function requestInstall() {
		const prompt = installPrompt;
		if (!prompt || installing) return;

		installing = true;
		installPrompt = null;

		try {
			const choice = await prompt.prompt();
			feedback =
				choice.outcome === 'accepted'
					? 'Instalación aceptada. Senda aparecerá entre tus aplicaciones.'
					: 'La instalación se canceló. También puedes instalar Senda desde el menú del navegador.';
		} catch {
			feedback =
				'No pudimos abrir el diálogo. Busca “Instalar aplicación” en el menú del navegador.';
		} finally {
			installing = false;
		}
	}

	return {
		get canInstall() {
			return installPrompt !== null;
		},
		get dismissed() {
			return dismissed;
		},
		get feedback() {
			return feedback;
		},
		get installed() {
			return installed;
		},
		get installing() {
			return installing;
		},
		get manualGuide() {
			return manualGuide;
		},
		captureInstallPrompt,
		clearFeedback,
		clearInstallPrompt,
		dismissUntilReload,
		initialize,
		requestInstall
	};
}

type PwaInstallController = ReturnType<typeof createPwaInstallController>;

export const [getPwaInstallContext, setPwaInstallContext] = createContext<PwaInstallController>();
