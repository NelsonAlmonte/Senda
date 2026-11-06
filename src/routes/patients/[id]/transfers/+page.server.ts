import { readText } from '#lib/server/auth.js';
import { error as httpError, fail, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';

const MAX_NOTE_LENGTH = 500;
const MAX_TRANSFER_DURATION_MS = 24 * 60 * 60 * 1000;
const DOMINICAN_TIME_OFFSET = '-04:00';

type TransferStatus = 'SCHEDULED' | 'ACTIVE' | 'COMPLETED' | 'CANCELLED';

function parseLocalDateTime(value: string): Date | null {
	if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2})?$/.test(value)) return null;

	const normalized = value.length === 16 ? `${value}:00` : value;
	const parsed = new Date(`${normalized}${DOMINICAN_TIME_OFFSET}`);
	return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function formatDateTimeInput(value: string | Date): string {
	const date = typeof value === 'string' ? new Date(value) : value;
	const parts = new Intl.DateTimeFormat('en-CA', {
		timeZone: 'America/Santo_Domingo',
		year: 'numeric',
		month: '2-digit',
		day: '2-digit',
		hour: '2-digit',
		minute: '2-digit',
		hourCycle: 'h23'
	}).formatToParts(date);
	const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));

	return `${values.year}-${values.month}-${values.day}T${values.hour}:${values.minute}`;
}

function statusForTransfer(
	transfer: {
		starts_at: string;
		ends_at: string;
		ended_at: string | null;
		cancelled_at: string | null;
	},
	now: number
): TransferStatus {
	if (transfer.cancelled_at) return 'CANCELLED';
	if (transfer.ended_at || Date.parse(transfer.ends_at) <= now) return 'COMPLETED';
	if (Date.parse(transfer.starts_at) <= now) return 'ACTIVE';
	return 'SCHEDULED';
}

async function requirePatientAccess(locals: App.Locals, patientId: string) {
	if (!locals.user || !locals.supabase) redirect(303, '/auth/login');

	const { data: access, error } = await locals.supabase
		.from('patient_access')
		.select('access_role, patient:patients!inner(id, first_name, last_name)')
		.eq('patient_id', patientId)
		.eq('user_id', locals.user.id)
		.is('revoked_at', null)
		.maybeSingle();

	if (error) httpError(500, 'No pudimos verificar tu acceso al paciente.');
	if (!access) httpError(404, 'Paciente no encontrado.');

	const patient = Array.isArray(access.patient) ? access.patient[0] : access.patient;
	if (!patient) httpError(404, 'Paciente no encontrado.');

	return {
		supabase: locals.supabase,
		accessRole: access.access_role as 'ADMIN' | 'MONITOR',
		patient
	};
}

async function requirePatientAdmin(locals: App.Locals, patientId: string) {
	const access = await requirePatientAccess(locals, patientId);
	if (access.accessRole !== 'ADMIN') {
		httpError(403, 'Solo un administrador puede gestionar los traslados.');
	}

	return access;
}

function reportRpcError(operation: string, rpcError: unknown) {
	const error = rpcError as {
		code?: string;
		message?: string;
		details?: string;
		hint?: string;
	} | null;
	console.error(`${operation} failed`, {
		code: error?.code,
		message: error?.message,
		details: error?.details,
		hint: error?.hint
	});
}

export const load: PageServerLoad = async ({ depends, locals, params, url }) => {
	if (!locals.user || !locals.supabase) {
		redirect(303, `/auth/login?next=${encodeURIComponent(url.pathname)}`);
	}

	depends('senda:patient-transfers');
	const { supabase, accessRole, patient } = await requirePatientAccess(locals, params.id);
	const { data: rows, error } = await supabase
		.from('planned_transfers')
		.select(
			'id, patient_id, starts_at, ends_at, note, ended_at, cancelled_at, created_at, updated_at'
		)
		.eq('patient_id', params.id)
		.order('starts_at', { ascending: false })
		.limit(100);

	if (error) {
		reportRpcError('planned_transfers select', error);
		httpError(500, 'No pudimos consultar los traslados del paciente.');
	}

	const now = Date.now();
	const transfers = (rows ?? []).map((transfer) => {
		const status = statusForTransfer(transfer, now);
		return {
			id: transfer.id,
			patientId: transfer.patient_id,
			startsAt: transfer.starts_at,
			endsAt: transfer.ends_at,
			note: transfer.note,
			endedAt: transfer.ended_at,
			cancelledAt: transfer.cancelled_at,
			createdAt: transfer.created_at,
			updatedAt: transfer.updated_at,
			status,
			startsAtInput: formatDateTimeInput(transfer.starts_at),
			endsAtInput: formatDateTimeInput(transfer.ends_at)
		};
	});
	const currentTransfers = transfers
		.filter((transfer) => transfer.status === 'ACTIVE' || transfer.status === 'SCHEDULED')
		.sort((left, right) => {
			if (left.status !== right.status) return left.status === 'ACTIVE' ? -1 : 1;
			return Date.parse(left.startsAt) - Date.parse(right.startsAt);
		});
	const history = transfers
		.filter((transfer) => transfer.status === 'COMPLETED' || transfer.status === 'CANCELLED')
		.sort((left, right) => Date.parse(right.startsAt) - Date.parse(left.startsAt))
		.slice(0, 12);

	return {
		patient: {
			id: patient.id,
			firstName: patient.first_name,
			lastName: patient.last_name,
			accessRole
		},
		isAdmin: accessRole === 'ADMIN',
		currentTransfers,
		history,
		nowInput: formatDateTimeInput(new Date())
	};
};

export const actions: Actions = {
	save: async ({ locals, params, request }) => {
		const { supabase } = await requirePatientAdmin(locals, params.id);
		const formData = await request.formData();
		const transferId = readText(formData.get('transferId')) || null;
		const startsAtValue = readText(formData.get('startsAt'));
		const endsAtValue = readText(formData.get('endsAt'));
		const note = readText(formData.get('note'));
		const values = { transferId, startsAt: startsAtValue, endsAt: endsAtValue, note };
		const errors: Record<string, string> = {};
		const startsAt = parseLocalDateTime(startsAtValue);
		const endsAt = parseLocalDateTime(endsAtValue);

		if (!startsAt) errors.startsAt = 'Selecciona una fecha y hora de inicio válidas.';
		if (!endsAt) errors.endsAt = 'Selecciona una fecha y hora de finalización válidas.';
		if (note.length < 1 || note.length > MAX_NOTE_LENGTH) {
			errors.note = `Escribe una nota de 1 a ${MAX_NOTE_LENGTH} caracteres.`;
		}

		if (startsAt && endsAt) {
			const duration = endsAt.getTime() - startsAt.getTime();
			if (duration <= 0) errors.endsAt = 'La finalización debe ser posterior al inicio.';
			if (duration > MAX_TRANSFER_DURATION_MS) {
				errors.endsAt = 'El traslado no puede durar más de 24 horas.';
			}
		}

		if (Object.keys(errors).length > 0 || !startsAt || !endsAt) {
			return fail(400, { action: 'save' as const, errors, values });
		}

		const { error } = await supabase.rpc('save_patient_planned_transfer', {
			p_transfer_id: transferId,
			p_patient_id: params.id,
			p_starts_at: startsAt.toISOString(),
			p_ends_at: endsAt.toISOString(),
			p_note: note
		});

		if (error) {
			reportRpcError('save_patient_planned_transfer', error);
			if (error.code === '42501') httpError(403, 'No tienes permiso para gestionar traslados.');
			if (error.code === 'P0002') httpError(404, 'El traslado ya no está disponible.');

			return fail(error.code === '23P01' ? 409 : 400, {
				action: 'save' as const,
				errors: {
					form:
						error.code === '23P01'
							? 'Este horario se superpone con otro traslado del paciente.'
							: 'No pudimos guardar el traslado. Revisa las fechas e inténtalo nuevamente.'
				},
				values
			});
		}

		return {
			action: 'save' as const,
			successMessage: transferId
				? 'El traslado se actualizó correctamente.'
				: 'El traslado se programó correctamente.'
		};
	},

	cancel: async ({ locals, params, request }) => {
		const { supabase } = await requirePatientAdmin(locals, params.id);
		const transferId = readText((await request.formData()).get('transferId'));
		if (!transferId) return fail(400, { action: 'cancel' as const, message: 'Traslado inválido.' });

		const { error } = await supabase.rpc('cancel_patient_planned_transfer', {
			p_transfer_id: transferId,
			p_patient_id: params.id
		});

		if (error) {
			reportRpcError('cancel_patient_planned_transfer', error);
			if (error.code === '42501') httpError(403, 'No tienes permiso para cancelar traslados.');
			return fail(400, {
				action: 'cancel' as const,
				message: 'No pudimos cancelar el traslado. Actualiza la página e inténtalo nuevamente.'
			});
		}

		return { action: 'cancel' as const, successMessage: 'El traslado programado se canceló.' };
	},

	end: async ({ locals, params, request }) => {
		const { supabase } = await requirePatientAdmin(locals, params.id);
		const transferId = readText((await request.formData()).get('transferId'));
		if (!transferId) return fail(400, { action: 'end' as const, message: 'Traslado inválido.' });

		const { error } = await supabase.rpc('end_patient_planned_transfer', {
			p_transfer_id: transferId,
			p_patient_id: params.id
		});

		if (error) {
			reportRpcError('end_patient_planned_transfer', error);
			if (error.code === '42501') httpError(403, 'No tienes permiso para finalizar traslados.');
			return fail(400, {
				action: 'end' as const,
				message: 'No pudimos finalizar el traslado. Actualiza la página e inténtalo nuevamente.'
			});
		}

		return { action: 'end' as const, successMessage: 'El traslado terminó antes de lo previsto.' };
	}
};
