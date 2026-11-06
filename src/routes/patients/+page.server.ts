import { redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ depends, locals, url }) => {
	if (!locals.user || !locals.supabase) {
		redirect(303, `/auth/login?next=${encodeURIComponent(url.pathname)}`);
	}

	depends('senda:patient-alerts');
	depends('senda:patient-transfers');

	const accessResult = await locals.supabase
		.from('patient_access')
		.select(
			'access_role, patient:patients!inner(id, first_name, last_name, created_at, group:groups!inner(id, name, type))'
		)
		.eq('user_id', locals.user.id)
		.is('revoked_at', null)
		.order('created_at', { referencedTable: 'patients', ascending: false });

	const authorizedPatients = (accessResult.data ?? []).flatMap((access) => {
		const patient = Array.isArray(access.patient) ? access.patient[0] : access.patient;
		if (!patient) return [];

		const group = Array.isArray(patient.group) ? patient.group[0] : patient.group;

		return [
			{
				id: patient.id,
				firstName: patient.first_name,
				lastName: patient.last_name,
				accessRole: access.access_role,
				group: group
					? {
							id: group.id,
							name: group.name,
							type: group.type
						}
					: null
			}
		];
	});

	const patientIds = authorizedPatients.map((patient) => patient.id);
	const assignmentsByPatient = new Map<
		string,
		{
			id: string;
			assignedAt: string;
			device: { id: string; serialNumber: string; kind: string };
		}
	>();
	const activeAlertsByPatient = new Map<string, { id: string; confirmedAt: string }>();
	const activeTransfersByPatient = new Map<
		string,
		{ id: string; startsAt: string; endsAt: string; note: string }
	>();
	let devicesAvailable = true;
	let alertsAvailable = true;
	let transfersAvailable = true;
	let nextTransferBoundary: string | null = null;

	if (patientIds.length > 0) {
		const now = Date.now();
		const nowIso = new Date(now).toISOString();
		const [assignmentResult, alertResult, transferResult] = await Promise.all([
			locals.supabase
				.from('device_assignments')
				.select('id, patient_id, assigned_at, device:devices!inner(id, serial_number, device_kind)')
				.in('patient_id', patientIds)
				.is('unassigned_at', null),
			locals.supabase
				.from('alert_episodes')
				.select('id, patient_id, confirmed_at')
				.in('patient_id', patientIds)
				.eq('status', 'OPEN')
				.order('confirmed_at', { ascending: false }),
			locals.supabase
				.from('planned_transfers')
				.select('id, patient_id, starts_at, ends_at, note')
				.in('patient_id', patientIds)
				.is('ended_at', null)
				.is('cancelled_at', null)
				.gt('ends_at', nowIso)
				.order('starts_at', { ascending: true })
				.limit(100)
		]);

		devicesAvailable = !assignmentResult.error;
		alertsAvailable = !alertResult.error;
		transfersAvailable = !transferResult.error;

		for (const assignment of assignmentResult.data ?? []) {
			const device = Array.isArray(assignment.device) ? assignment.device[0] : assignment.device;
			if (!device) continue;

			assignmentsByPatient.set(assignment.patient_id, {
				id: assignment.id,
				assignedAt: assignment.assigned_at,
				device: {
					id: device.id,
					serialNumber: device.serial_number,
					kind: device.device_kind
				}
			});
		}

		for (const alert of alertResult.data ?? []) {
			if (activeAlertsByPatient.has(alert.patient_id)) continue;
			activeAlertsByPatient.set(alert.patient_id, {
				id: alert.id,
				confirmedAt: alert.confirmed_at
			});
		}

		let nextBoundaryTime = Number.POSITIVE_INFINITY;
		for (const transfer of transferResult.data ?? []) {
			const startsAt = Date.parse(transfer.starts_at);
			const endsAt = Date.parse(transfer.ends_at);
			if (!Number.isFinite(startsAt) || !Number.isFinite(endsAt)) continue;

			if (startsAt <= now && now < endsAt) {
				activeTransfersByPatient.set(transfer.patient_id, {
					id: transfer.id,
					startsAt: transfer.starts_at,
					endsAt: transfer.ends_at,
					note: transfer.note
				});
			}

			const boundaryTime = startsAt > now ? startsAt : endsAt;
			if (boundaryTime < nextBoundaryTime) {
				nextBoundaryTime = boundaryTime;
				nextTransferBoundary = new Date(boundaryTime).toISOString();
			}
		}
	}

	const patients = authorizedPatients.map((patient) => ({
		...patient,
		assignment: assignmentsByPatient.get(patient.id) ?? null,
		activeAlert: activeAlertsByPatient.get(patient.id) ?? null,
		activeTransfer: activeTransfersByPatient.get(patient.id) ?? null
	}));

	return {
		patients,
		patientsAvailable: !accessResult.error,
		devicesAvailable,
		alertsAvailable,
		transfersAvailable,
		nextTransferBoundary,
		patientCreated: url.searchParams.get('created') === 'patient',
		deviceConfigured: url.searchParams.get('configured') === 'device',
		accessAccepted: url.searchParams.get('access') === 'accepted'
	};
};
