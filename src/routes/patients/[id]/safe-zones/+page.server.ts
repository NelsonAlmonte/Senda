import { error as httpError, fail, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';

const DEFAULT_MAP_CENTER = { latitude: 18.4861, longitude: -69.9312 };

function parseNumber(value: FormDataEntryValue | null): number | null {
	if (typeof value !== 'string' || value.trim() === '') return null;

	const parsed = Number(value);
	return Number.isFinite(parsed) ? parsed : null;
}

function parseZoneId(value: FormDataEntryValue | null): string | null {
	if (typeof value !== 'string' || value.trim() === '') return null;
	return value.trim();
}

export const load: PageServerLoad = async ({ locals, params, url }) => {
	if (!locals.user || !locals.supabase) {
		redirect(303, `/auth/login?next=${encodeURIComponent(url.pathname)}`);
	}

	const { data: access, error: accessError } = await locals.supabase
		.from('patient_access')
		.select(
			'access_role, patient:patients!inner(id, first_name, last_name, group:groups!inner(id, name, type))'
		)
		.eq('patient_id', params.id)
		.eq('user_id', locals.user.id)
		.is('revoked_at', null)
		.maybeSingle();

	if (accessError || !access) httpError(404, 'Paciente no encontrado.');

	const patient = Array.isArray(access.patient) ? access.patient[0] : access.patient;
	if (!patient) httpError(404, 'Paciente no encontrado.');

	const group = Array.isArray(patient.group) ? patient.group[0] : patient.group;
	const [safeZonesResult, assignmentResult] = await Promise.all([
		locals.supabase
			.from('safe_zones')
			.select(
				'id, name, center_latitude, center_longitude, radius_m, is_active, created_at, updated_at'
			)
			.eq('patient_id', params.id)
			.is('archived_at', null)
			.order('name', { ascending: true }),
		locals.supabase
			.from('device_assignments')
			.select('id')
			.eq('patient_id', params.id)
			.is('unassigned_at', null)
			.maybeSingle()
	]);

	let mapCenter = DEFAULT_MAP_CENTER;
	if (assignmentResult.data) {
		const latestLocationResult = await locals.supabase
			.from('latest_locations')
			.select('latitude, longitude')
			.eq('device_assignment_id', assignmentResult.data.id)
			.maybeSingle();

		if (latestLocationResult.data) {
			mapCenter = {
				latitude: latestLocationResult.data.latitude,
				longitude: latestLocationResult.data.longitude
			};
		}
	}

	const safeZones = (safeZonesResult.data ?? []).map((zone) => ({
		id: zone.id,
		name: zone.name,
		centerLatitude: zone.center_latitude,
		centerLongitude: zone.center_longitude,
		radiusM: zone.radius_m,
		isActive: zone.is_active,
		createdAt: zone.created_at,
		updatedAt: zone.updated_at
	}));

	if (safeZones[0]) {
		mapCenter = {
			latitude: safeZones[0].centerLatitude,
			longitude: safeZones[0].centerLongitude
		};
	}

	return {
		patient: {
			id: patient.id,
			firstName: patient.first_name,
			lastName: patient.last_name,
			groupName: group?.name ?? null,
			groupType: group?.type ?? null,
			accessRole: access.access_role
		},
		safeZones,
		safeZonesAvailable: !safeZonesResult.error,
		mapCenter
	};
};

export const actions: Actions = {
	save: async ({ locals, params, request }) => {
		if (!locals.user || !locals.supabase) {
			redirect(303, `/auth/login?next=/patients/${params.id}/safe-zones`);
		}

		const formData = await request.formData();
		const zoneId = parseZoneId(formData.get('zoneId'));
		const name =
			typeof formData.get('name') === 'string' ? String(formData.get('name')).trim() : '';
		const centerLatitude = parseNumber(formData.get('centerLatitude'));
		const centerLongitude = parseNumber(formData.get('centerLongitude'));
		const radiusM = parseNumber(formData.get('radiusM'));
		const isActive = formData.has('isActive');
		const values = { zoneId, name, centerLatitude, centerLongitude, radiusM, isActive };

		if (name.length < 1 || name.length > 60) {
			return fail(400, {
				action: 'save',
				message: 'Escribe un nombre de entre 1 y 60 caracteres.',
				values
			});
		}

		if (centerLatitude === null || centerLatitude < -90 || centerLatitude > 90) {
			return fail(400, {
				action: 'save',
				message: 'La latitud debe estar entre -90 y 90.',
				values
			});
		}

		if (centerLongitude === null || centerLongitude < -180 || centerLongitude > 180) {
			return fail(400, {
				action: 'save',
				message: 'La longitud debe estar entre -180 y 180.',
				values
			});
		}

		if (radiusM === null || radiusM < 50 || radiusM > 5000) {
			return fail(400, {
				action: 'save',
				message: 'El radio debe estar entre 50 y 5,000 metros.',
				values
			});
		}

		const { error } = await locals.supabase.rpc('save_patient_safe_zone', {
			p_zone_id: zoneId,
			p_patient_id: params.id,
			p_name: name,
			p_center_latitude: centerLatitude,
			p_center_longitude: centerLongitude,
			p_radius_m: radiusM,
			p_is_active: isActive
		});

		if (error) {
			if (error.code === '42501') {
				httpError(403, 'No tienes permiso para configurar geocercas de este paciente.');
			}

			if (error.code === '23505') {
				return fail(409, {
					action: 'save',
					message: 'Ya existe una geocerca activa o inactiva con ese nombre.',
					values
				});
			}

			if (error.code === 'PGRST202' || error.code === '42P01') {
				return fail(503, {
					action: 'save',
					message: 'La migración de geocercas todavía no está aplicada en Supabase.',
					values
				});
			}

			return fail(400, {
				action: 'save',
				message: 'No pudimos guardar la geocerca. Revisa los datos e inténtalo nuevamente.',
				values
			});
		}

		return {
			action: 'save',
			success: true,
			message: zoneId ? 'Geocerca actualizada correctamente.' : 'Geocerca creada correctamente.'
		};
	},

	archive: async ({ locals, params, request }) => {
		if (!locals.user || !locals.supabase) {
			redirect(303, `/auth/login?next=/patients/${params.id}/safe-zones`);
		}

		const formData = await request.formData();
		const zoneId = parseZoneId(formData.get('zoneId'));
		if (!zoneId) {
			return fail(400, {
				action: 'archive',
				message: 'Selecciona una geocerca válida para archivarla.'
			});
		}

		const { error } = await locals.supabase.rpc('archive_patient_safe_zone', {
			p_zone_id: zoneId,
			p_patient_id: params.id
		});

		if (error) {
			if (error.code === '42501') {
				httpError(403, 'No tienes permiso para archivar geocercas de este paciente.');
			}

			return fail(400, {
				action: 'archive',
				message: 'No pudimos archivar la geocerca. Inténtalo nuevamente.'
			});
		}

		return {
			action: 'archive',
			success: true,
			message: 'Geocerca archivada. Ya no participará en la evaluación de seguridad.'
		};
	}
};
