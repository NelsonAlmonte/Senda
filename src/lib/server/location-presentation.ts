const staleAfterMilliseconds = 3 * 60 * 1000;
const locationDateFormatter = new Intl.DateTimeFormat('es-DO', {
	dateStyle: 'medium',
	timeStyle: 'short',
	timeZone: 'America/Santo_Domingo'
});

function formatLocationAge(recordedAt: string, now: number): string {
	const ageMilliseconds = Math.max(0, now - Date.parse(recordedAt));
	if (ageMilliseconds < 60_000) return 'hace menos de 1 minuto';

	const minutes = Math.floor(ageMilliseconds / 60_000);
	if (minutes < 60) return `hace ${minutes} ${minutes === 1 ? 'minuto' : 'minutos'}`;

	const hours = Math.floor(minutes / 60);
	if (hours < 24) return `hace ${hours} ${hours === 1 ? 'hora' : 'horas'}`;

	const days = Math.floor(hours / 24);
	return `hace ${days} ${days === 1 ? 'día' : 'días'}`;
}

export function presentLocationTime(recordedAt: string, now = Date.now()) {
	return {
		freshness:
			now - Date.parse(recordedAt) <= staleAfterMilliseconds
				? ('FRESH' as const)
				: ('STALE' as const),
		ageLabel: formatLocationAge(recordedAt, now),
		recordedAtLabel: locationDateFormatter.format(new Date(recordedAt))
	};
}
