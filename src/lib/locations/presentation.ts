const staleAfterMilliseconds = 3 * 60 * 1000;
const locationDateFormatter = new Intl.DateTimeFormat('es-DO', {
	dateStyle: 'medium',
	timeStyle: 'short',
	timeZone: 'America/Santo_Domingo'
});

export type LocationGeofenceRelation =
	'NOT_EVALUATED' | 'NO_ACTIVE_ZONE' | 'INSIDE' | 'OUTSIDE' | 'UNCERTAIN';

type GeofenceRelationPresentation = {
	title: string;
	description: string;
	tone: 'positive' | 'warning' | 'neutral';
};

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

export function presentGeofenceRelation(
	relation: LocationGeofenceRelation,
	matchedZoneName: string | null,
	effectiveToleranceM: number | null
): GeofenceRelationPresentation {
	const zoneReference = matchedZoneName
		? `“${matchedZoneName}”`
		: 'una zona que estaba activa al recibir la lectura';
	const toleranceLabel =
		effectiveToleranceM === null
			? null
			: effectiveToleranceM.toLocaleString('es-DO', { maximumFractionDigits: 1 });

	switch (relation) {
		case 'INSIDE':
			return {
				title: 'Dentro de una zona permitida',
				description: `La lectura se clasificó dentro de ${zoneReference}.`,
				tone: 'positive'
			};
		case 'OUTSIDE':
			return {
				title: 'Fuera de las zonas permitidas',
				description:
					'Esta lectura aislada quedó fuera de todas las geocercas activas. Todavía no constituye una alerta confirmada.',
				tone: 'warning'
			};
		case 'UNCERTAIN':
			return {
				title: 'Ubicación cerca del límite',
				description: toleranceLabel
					? `La precisión disponible no permite confirmar si la lectura está dentro o fuera. Margen aplicado: ${toleranceLabel} m.`
					: 'La precisión disponible no permite confirmar si la lectura está dentro o fuera.',
				tone: 'warning'
			};
		case 'NO_ACTIVE_ZONE':
			return {
				title: 'Sin geocerca activa',
				description: 'No había una zona activa que evaluar cuando Senda recibió esta lectura.',
				tone: 'neutral'
			};
		case 'NOT_EVALUATED':
			return {
				title: 'Evaluación no disponible',
				description:
					'Esta lectura es anterior al clasificador de geocercas. Envía una lectura nueva para obtener el estado.',
				tone: 'neutral'
			};
	}
}
