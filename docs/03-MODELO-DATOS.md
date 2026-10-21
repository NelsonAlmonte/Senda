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
owner_user_id  uuid FK -> auth.users (propuesta mínima para administrar)
created_at     timestamptz
```

`GROUP` es **contexto organizativo**, no autorización de todas las ubicaciones. `owner_user_id` solo resuelve la creación/administración inicial; no concede lectura indiscriminada de datos de pacientes. Si el equipo necesita varios administradores del grupo, considerar `group_members` mínimo en otra fase.

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
kind           SIMULATED | PHYSICAL (PHYSICAL reservado para futuro)
created_at     timestamptz
```

**No implementar aún** hardware_id, claim, estados `UNCLAIMED/CLAIMED/ASSIGNED` ni credenciales de hardware. Esas piezas siguen concebidas para integración posterior, pero no deben bloquear el MVP.

### 6. `device_assignments`

```text
id             uuid PK
device_id      uuid FK -> devices.id
patient_id     uuid FK -> patients.id
assigned_at    timestamptz
unassigned_at  timestamptz null
```

- Un dispositivo no puede tener dos asignaciones activas: índice único parcial por `device_id WHERE unassigned_at IS NULL`.
- Para el MVP, si se adopta un dispositivo por paciente, índice único parcial por `patient_id WHERE unassigned_at IS NULL`.
- `unassigned_at` es la fuente de verdad de activación; **no añadir `is_active` redundante** salvo necesidad demostrada.

### 7. `locations`

```text
id                    bigint identity PK
device_assignment_id  uuid FK -> device_assignments.id
latitude              double precision CHECK [-90, 90]
longitude             double precision CHECK [-180, 180]
accuracy_m            double precision null (>=0)
recorded_at           timestamptz
received_at           timestamptz DEFAULT now()
source                SIMULATOR | MANUAL | DEVICE
```

**Corrección importante respecto al esquema preliminar:** no autorizar una ubicación antigua uniéndola al **paciente actualmente asignado** al dispositivo. Una unidad física puede pasar de Juan a Rosa. Al usar `device_assignment_id` inmutable, las ubicaciones históricas de Juan continúan siendo de Juan, y no pasan a Rosa accidentalmente.

Índices sugeridos: `(device_assignment_id, recorded_at DESC)`. El procesamiento debe rechazar/fijar como sospechosas coordenadas fuera de rango, datos demasiado antiguos/futuros y lecturas duplicadas. La política de idempotencia exacta queda por cerrar.

### 8. `safe_zones`

```text
id             uuid PK
patient_id     uuid FK -> patients.id
name           text
center_lat     double precision
center_lng     double precision
radius_m       double precision CHECK (radius_m > 0)
is_active      boolean DEFAULT true
created_at     timestamptz
updated_at     timestamptz
updated_by     uuid FK -> auth.users.id
```

Solo círculos para el MVP. Si hay varias zonas activas, **estar dentro de cualquiera de ellas significa estar en una zona permitida** (comportamiento propuesto, validar si se decide limitar a una sola zona).

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
email        citext o text normalizado
access_role  ADMIN | MONITOR
status       PENDING | ACCEPTED | DECLINED
token_hash   text UNIQUE
invited_by   uuid FK -> auth.users.id
created_at   timestamptz
accepted_at  timestamptz null
declined_at  timestamptz null
```

No agregar estado `EXPIRED`. El token se entrega en el enlace y solo se almacena su hash. Para cancelar una invitación pendiente sin alterar el vocabulario de estados, definir más adelante una invalidación controlada de token o eliminación autorizada (ver `09-DECISIONES-PENDIENTES.md`).

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
