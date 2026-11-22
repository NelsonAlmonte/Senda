import type { SupabaseClient } from '@supabase/supabase-js';

/**
 * Asigna un dispositivo a un paciente por su serial.
 *
 * Los seriales son únicos en todo el inventario, así que un serial que el flujo simulado no
 * conoce puede ser un rastreador físico registrado por un servicio. Cualquier otro error del
 * flujo simulado (paciente o dispositivo ya ocupados, permisos) se devuelve tal cual: el flujo
 * físico no se intenta, para no ocultar la causa real.
 */
export async function assignDeviceBySerial(
	supabase: SupabaseClient,
	patientId: string,
	serialNumber: string
) {
	const assignment = { p_patient_id: patientId, p_serial_number: serialNumber };
	let { error } = await supabase.rpc('assign_simulated_device', assignment);

	if (error?.message.includes('Serial is not registered.')) {
		({ error } = await supabase.rpc('assign_physical_device', assignment));
	}

	return error;
}
