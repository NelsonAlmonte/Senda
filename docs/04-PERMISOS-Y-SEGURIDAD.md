# 04 — Acceso, permisos y seguridad inicial

## Roles de paciente

| Operación | ADMIN | MONITOR |
|---|:---:|:---:|
| Ver detalles mínimos del paciente | Sí | Sí |
| Ver ubicación e historial | Sí | Sí |
| Ver alertas y sus estados | Sí | Sí |
| Crear/editar/desactivar geocercas | Sí | Sí |
| Editar datos del paciente | Sí | No |
| Invitar usuarios | Sí | No |
| Revocar accesos | Sí | No |
| Asignar o retirar dispositivo simulado | Sí | No |

`relationship` es información descriptiva y no condiciona permisos. El usuario puede ser cuidador profesional, pariente o externo al centro; el permiso reside en `patient_access`.

## Grupo ≠ permiso para ubicar pacientes

Ejemplo: un empleado perteneciente a `Centro ABC` no puede consultar a Rosa si solo dispone de acceso explícito a Juan. La creación inicial de pacientes puede requerir la autoridad administrativa del propietario del grupo, pero el acceso de lectura se controla siempre a nivel paciente.

La tabla `group_members` **no es obligatoria en la fase inicial**. Si aparece después, los roles de grupo nunca deben reemplazar el control `patient_access` para datos de ubicación.

## Políticas RLS mínimas

1. **`patients SELECT`**: usuarios con un `patient_access` activo para ese paciente; incluir flujo controlado de creación administrativa sin abrir lecturas globales.
2. **`devices` y `device_assignments SELECT`**: solo si la asignación apunta a un paciente con `patient_access` activo. El inventario sin asignar no se expone.
3. **Asignación de dispositivo**: RPC autenticada que exige `ADMIN`; el cliente no recibe permisos directos de inserción o actualización sobre inventario/asignaciones.
4. **`locations SELECT`**: solo si la asignación histórica apunta a un paciente con acceso activo del usuario. La relación con geocercas, zona coincidente, tolerancia y distancia firmada forman parte de la misma fila y heredan exactamente este aislamiento.
5. **`safe_zones SELECT`**: usuarios con acceso al paciente.
6. **`safe_zones INSERT/UPDATE/DELETE`**: `ADMIN` o `MONITOR` autorizado.
7. **`alert_episodes SELECT`**: usuarios con acceso activo al paciente; `ADMIN` y `MONITOR` pueden leer el mismo episodio. El cliente no recibe permisos directos de inserción, actualización o eliminación: el trigger backend es la única autoridad de escritura.
8. **`patient_access SELECT`**: según necesidad de interfaz; limitar exposición de correos de terceros.
9. **`patient_access INSERT/UPDATE/DELETE`**: prohibir CRUD abierto desde cliente; usar operación atómica autorizada.
10. **`devices` / `device_assignments`**: vistas/operaciones específicas, no listado completo de inventario ajeno.
9. **`push_subscriptions`**: cada usuario gestiona únicamente sus propias suscripciones mediante `SELECT`, `INSERT`, `UPDATE` y `DELETE` sujetos a `user_id = auth.uid()`. El endpoint es único para no registrar el mismo navegador bajo varias cuentas. La Edge Function autorizada consulta destinatarios por acceso activo y elimina únicamente endpoints que el proveedor reporte como permanentemente inválidos.
10. **Entrega Web Push**: `anon`, `authenticated` y `service_role` no pueden ejecutar directamente la función de trigger. La Edge Function acepta solicitudes sin JWT de usuario porque provienen de Postgres, pero exige `SENDA_WEBHOOK_SECRET`; luego usa una clave privada de servidor para seleccionar exclusivamente usuarios con `patient_access.revoked_at is null`. Los valores VAPID privados y el secreto compartido se almacenan en Edge Function Secrets; la base de datos conserva solo el URL público del proyecto y el secreto del webhook dentro de Vault.

Preferir RLS y constraints sobre una proliferación de Edge Functions. Las funciones SQL sensibles deben asegurar permisos de ejecución y seguridad del `search_path`; revisar especialmente cualquier `SECURITY DEFINER`.

## Ingestión simulada: evitar falsificación pública

El botón/click de simulación no puede aceptar coordenadas de un paciente ajeno desde un usuario cualquiera.

- Activar simulación solo en **entorno de pruebas** o para cuentas de prueba explícitamente autorizadas.
- Verificar identidad y privilegios en Supabase antes de guardar.
- Validar el identificador de asignación activa del dispositivo simulado en servidor.
- El script Node.js usa credenciales de prueba en variables de entorno, no en el repositorio; no utilizar `service_role` dentro de la PWA.
- Producción futura con hardware utilizará autenticación de dispositivo separada de Supabase Auth de los familiares.

**Decisión MVP (2026-10-24):** la ingestión simulada inicial usa una RPC autenticada que exige acceso `ADMIN` activo al paciente y una asignación simulada vigente. `authenticated` solo recibe `SELECT` sobre `locations`; no puede insertar directamente. `MONITOR` puede leer las ubicaciones autorizadas, pero no simularlas. La autenticación independiente del hardware permanece aplazada.

## Invitaciones de acceso

```text
ADMIN del paciente genera un código de acceso MONITOR
              ↓
Servidor verifica ADMIN y guarda token_hash asociado al paciente
              ↓
Destinatario crea su cuenta o inicia sesión e introduce el código
              ↓
Backend valida token, estado, paciente y vigencia del permiso del invitador
              ↓
En transacción crea patient_access MONITOR y marca ACCEPTED
```

No confiar únicamente en la presencia del código o en el estado visual de un botón. Una invitación se acepta **una sola vez**; no permitir reuso ni que un usuario invitado a Juan obtenga por error permiso sobre Rosa. El código no concede acceso al grupo ni a sus demás pacientes. El flujo `DECLINED` no concede acceso.

La entrega por email y enlace seguro permanece como ampliación posterior. En ese flujo se valida además que la cuenta use el mismo email verificado de la invitación.

**Estado implementado (2026-10-24):** las RPC de generación, vista previa y aceptación validan la sesión y los permisos en PostgreSQL. Solo se guarda el hash del código, la vista previa revela nombre mínimo del paciente y contexto, y la aceptación crea `patient_access MONITOR` y marca la invitación `ACCEPTED` en una misma transacción.

## Revocación

- Revocar `patient_access` impide lecturas futuras y operaciones del paciente.
- La PWA debe actualizar su lista de pacientes y desuscribirse de canales no permitidos.
- Probar reconexiones y suscripciones abiertas. Evitar mostrar datos privados residuales de sesiones revocadas.
- No permitir dejar a un paciente sin ningún `ADMIN` activo.

## Protección básica de información

- HTTPS, credenciales protegidas, secretos solo en variables de entorno/almacén de secretos del backend.
- Configurar y restringir la API key pública de Google Maps por HTTP referrers y servicios habilitados.
- No guardar ubicaciones personales en caché del service worker de forma persistente por defecto.
- Evitar logs con tokens, coordenadas sensibles o nombres de pacientes.
- No mostrar fotos/condiciones médicas en notificaciones push salvo necesidad explícita y autorizada.
- Controlar permisos de push individualmente: permisos de notificación del navegador no sustituyen `patient_access`.

## Pruebas negativas obligatorias

- Usuario A no lee mapa/historial de paciente de usuario B.
- MONITOR no invita ni asigna dispositivo.
- MONITOR sí edita geocerca de un paciente autorizado; usuario externo no.
- Invitación destinada a un correo no se acepta desde otro correo.
- Token aceptado no puede reutilizarse.
- Revocado no continúa consultando historial ni actualizaciones.
- Una reasignación de dispositivo no expone ubicaciones antiguas del paciente anterior.
