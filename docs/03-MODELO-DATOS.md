# 03 — Modelo de datos lógico (antes de migraciones SQL)

> **Importante:** este es un **schema lógico inicial**. Las columnas mínimas, restricciones y relaciones se proponen para orientar a Codex, pero no son todavía migraciones definitivas. No crear campos de negocio adicionales sin necesidad demostrada.

## Relaciones

```text
AUTH.USERS ── PROFILES
    │
    ├── PATIENT_ACCESS ──────────────── PATIENTS ─── GROUPS
    │                                       │
    └── INVITATIONS                         ├── SAFE_ZONES
                                            ├── ALERT_EPISODES
                                            └── DEVICE_ASSIGNMENTS ── DEVICES
                                                       │
                                                       └── LOCATIONS
```

### 1. `groups`

```text
id             uuid PK
name           text not null
type           FAMILY | CARE_CENTER
owner_user_id  uuid FK -> auth.users (administración mínima del MVP)
created_at     timestamptz
```

`GROUP` es **contexto organizativo**, no autorización de todas las ubicaciones. Para el MVP se confirmó un único `owner_user_id`, que resuelve la creación/administración inicial sin conceder lectura indiscriminada de pacientes. Si más adelante se aprueba administración compartida, se podrá añadir `group_members` sin sustituir `patient_access`.

### 2. `patients`

```text
id            uuid PK
group_id      uuid FK -> groups.id
first_name    text
last_name     text
date_of_birth date null          (validar necesidad real)
created_at    timestamptz
```

Minimizar la información sensible; no construir historial clínico. El creador autorizado debe recibir `patient_access ADMIN` en la misma transacción de alta.

### 3. `profiles`

```text
id         uuid PK/FK -> auth.users.id
full_name  text
created_at timestamptz
```

Autenticación y correo verificado corresponden a **Supabase Auth**, no a una segunda tabla de contraseñas.

### 4. `patient_access`

```text
id           uuid PK
patient_id   uuid FK -> patients.id
user_id      uuid FK -> auth.users.id
access_role  ADMIN | MONITOR
relationship FAMILY | CAREGIVER | OTHER | null (solo descriptivo)
created_at   timestamptz
revoked_at   timestamptz null
```

- Índice único parcial para impedir dos accesos **activos** al mismo par `(patient_id,user_id)`; si se conservan filas revocadas, no usar `UNIQUE(patient_id,user_id)` global sin analizar el reotorgamiento.
- Nunca usar `relationship` como permiso.
- Proteger contra eliminación/revocación del último `ADMIN` activo de cada paciente.

### 5. `devices` (MVP simulado)

```text
id             uuid PK
serial_number  text UNIQUE
device_kind    SIMULATED | PHYSICAL (PHYSICAL reservado para futuro)
created_at     timestamptz
```

**No implementar aún** hardware_id, credenciales reales ni el ciclo físico completo de claim/pairing. El onboarding puede simular el registro de una unidad mediante un identificador de prueba y crear su asignación al paciente. Un paciente puede existir sin asignación activa y completar esta configuración más adelante.

### 6. `device_assignments`

```text
id             uuid PK
device_id      uuid FK -> devices.id
patient_id     uuid FK -> patients.id
assigned_at    timestamptz
unassigned_at  timestamptz null
```

- Un dispositivo no puede tener dos asignaciones activas: índice único parcial por `device_id WHERE unassigned_at IS NULL`.
- Para el MVP se confirmó un único dispositivo activo por paciente: índice único parcial por `patient_id WHERE unassigned_at IS NULL`.
- `unassigned_at` es la fuente de verdad de activación; **no añadir `is_active` redundante** salvo necesidad demostrada.

**Estado implementado (2026-10-24):** `devices` y `device_assignments` ya existen en Supabase de desarrollo. El registro inicial selecciona uno de tres seriales simulados preexistentes y crea la asignación mediante una RPC autorizada; no crea inventario desde el navegador.

### 7. `locations`

```text
id                    bigint identity PK
device_assignment_id  uuid FK -> device_assignments.id
event_id              uuid (idempotencia por asignación)
latitude              double precision CHECK [-90, 90]
longitude             double precision CHECK [-180, 180]
accuracy_m            double precision null (>=0)
recorded_at           timestamptz
received_at           timestamptz DEFAULT now()
source                SIMULATOR | MANUAL | DEVICE
```

**Corrección importante respecto al esquema preliminar:** no autorizar una ubicación antigua uniéndola al **paciente actualmente asignado** al dispositivo. Una unidad física puede pasar de Juan a Rosa. Al usar `device_assignment_id` inmutable, las ubicaciones históricas de Juan continúan siendo de Juan, y no pasan a Rosa accidentalmente.

Índice implementado: `(device_assignment_id, recorded_at DESC, id DESC)`. La idempotencia usa `UNIQUE(device_assignment_id,event_id)`: repetir el mismo UUID con los mismos datos devuelve la ubicación existente; reutilizarlo con datos distintos se rechaza. La RPC de simulación valida rangos, precisión finita no negativa, asignación activa, que la captura no anteceda la asignación y que no esté más de un minuto en el futuro.

**Estado implementado (2026-10-25):** `locations`, la vista `latest_locations` y la RPC idempotente limitada a `ADMIN` están aplicadas en Supabase de desarrollo. `locations` pertenece a la publicación `supabase_realtime`; Postgres Changes entrega inserciones únicamente después de evaluar su política RLS por `patient_access`. El mapa consulta bajo la misma RLS un máximo de 200 lecturas recientes del paciente y conserva `device_assignment_id` para dibujar cada asignación como un trazo independiente. La suite pgTAP de ubicaciones pasa 39 casos, incluida publicación Realtime, lectura `MONITOR`, rechazo de escritura directa y aislamiento del historial al reasignar un dispositivo. El usuario validó manualmente la visualización histórica y su actualización sin reconstruir el mapa.

### 8. `safe_zones`

```text
id             uuid PK
patient_id     uuid FK -> patients.id
name           text (1..60; único por paciente mientras no esté archivado)
center_latitude  double precision CHECK (-90..90)
center_longitude double precision CHECK (-180..180)
radius_m       double precision CHECK (50..5000)
is_active      boolean DEFAULT true
created_at     timestamptz
updated_at     timestamptz
created_by     uuid FK -> auth.users.id
updated_by     uuid FK -> auth.users.id
archived_at    timestamptz null
```

Solo círculos para el MVP. Se permiten varias zonas activas sin un máximo artificial en base de datos: **estar dentro de cualquiera de ellas significa estar en una zona permitida**. Las zonas pueden superponerse. Desactivar conserva la zona editable; archivar fija `is_active=false`, conserva la fila como evidencia y permite reutilizar su nombre. Una zona archivada nunca participa en la evaluación.

**Estado de implementación (2026-10-25):** la migración `20261025183035_patient_safe_zones.sql` está aplicada en Supabase de desarrollo. Crea la tabla, el índice parcial de nombres, RLS de lectura por `patient_access` y RPC para crear, editar, activar, desactivar y archivar. Las escrituras directas quedan revocadas; `ADMIN` y `MONITOR` usan las mismas RPC autorizadas. La suite pgTAP pasa 29 casos e incluye permisos negativos, múltiples zonas, validación de límites y archivo sin borrado.

### 9. `alert_episodes`

```text
id                uuid PK
patient_id        uuid FK -> patients.id
device_assignment_id uuid FK -> device_assignments.id
status            OPEN | RESOLVED
severity          LOW | MEDIUM | HIGH | CRITICAL
outside_since     timestamptz
opened_at         timestamptz
updated_at        timestamptz
resolved_at       timestamptz null
```

Un único episodio `OPEN` por paciente/tipo de evento de salida (restricción parcial apropiada). Las escaladas actualizan el episodio existente; no generan una fila nueva en cada lectura. No usar `LOW` para paciente normalmente seguro.

### 10. `invitations`

```text
id           uuid PK
patient_id   uuid FK -> patients.id
email        citext o text normalizado null
access_role  ADMIN | MONITOR
status       PENDING | ACCEPTED | DECLINED
token_hash   text UNIQUE
invited_by   uuid FK -> auth.users.id
created_at   timestamptz
accepted_at  timestamptz null
declined_at  timestamptz null
```

No agregar estado `EXPIRED`. El token puede representarse como código introducido manualmente o entregarse mediante un enlace; solo se almacena su hash y se acepta una vez. El flujo inicial por código concede `MONITOR` exclusivamente sobre `patient_id` y no crea membresía del grupo. `email` es obligatorio cuando el envío sea por correo y puede ser nulo para un código compartido manualmente. Para cancelar una invitación pendiente sin alterar el vocabulario de estados, definir más adelante una invalidación controlada de token o eliminación autorizada (ver `09-DECISIONES-PENDIENTES.md`).

**Implementado el 2026-10-24:** código manual de un solo uso con `email = null`, hash SHA-256 persistido y aceptación transaccional. La tabla no se expone directamente a `anon` ni `authenticated`; las operaciones se realizan mediante RPC con autorización interna. El envío por email, `DECLINED` y la invalidación administrativa permanecen para una historia posterior.

### 11. `push_subscriptions` (cuando se implemente Web Push)

```text
id          uuid PK
user_id     uuid FK -> auth.users.id
endpoint    text
p256dh      text
auth        text
created_at  timestamptz
```

El usuario solo administra sus propias suscripciones. No exponer listado global ni claves privadas VAPID. Diseñar eliminación de endpoints inválidos durante envíos.

### Extensiones opcionales posteriores

`audit_logs` limitado a cambios de geocerca, permisos e invitaciones; `alert_events` para historial de escaladas; `group_members` si se requiere administración compartida del grupo; `notification_outbox` para reintentos idempotentes. Introducirlas cuando la historia las necesite, no por anticipación.

## Integridad / reglas transversales

- FKs, CHECKs, NOT NULL, índices y políticas RLS se crean en las mismas migraciones de sus tablas.
- En transacciones de alto impacto validar pertenencia del paciente al grupo, acceso ADMIN y conflictos de asignación.
- Mantener `created_at`/`updated_at` UTC (`timestamptz`). Convertir a horario local solo al mostrar en la interfaz.
- Solo leer ubicaciones si `locations.device_assignment_id -> device_assignments.patient_id -> patient_access.user_id = auth.uid()`.
- No almacenar una geolocalización de paciente sin saber a qué asignación histórica corresponde.
