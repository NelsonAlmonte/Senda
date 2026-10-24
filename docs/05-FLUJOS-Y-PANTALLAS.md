# 05 — Flujos y pantallas funcionales

**Estado:** rutas aprobadas a nivel general. El contenido detallado, composición visual y microinteracciones se definen al implementar cada pantalla.

## Rutas previstas

```text
/auth/login
/auth/register
/onboarding
/access-code
/dashboard
/groups
/groups/:id
/patients/:id
/patients/:id/map
/patients/:id/history
/patients/:id/alerts
/patients/:id/safe-zones
/patients/:id/access
/invitations
/settings
```

SvelteKit puede organizar rutas en grupos de layouts o prefijos internos cuando convenga sin cambiar el significado de estas URLs.

**Estado implementado (2026-10-24):** después del registro se redirige a `/onboarding`, donde se elige entre registrar un dispositivo o monitorear mediante código. El registro usa un asistente de tres pasos en `/groups`; `/access-code` permite revisar el paciente y aceptar el acceso `MONITOR`; un `ADMIN` genera el código desde `/patients/:id/access`.

## Flujo A — Registro e inicio de sesión

```text
Registro → Supabase Auth → sesión → elegir acción inicial
    ├── Configurar un dispositivo
    └── Ingresar un código de acceso
```

- Estas opciones son acciones disponibles también después del onboarding; no convierten la cuenta en un tipo fijo de propietario o monitor.
- Si el usuario llega por enlace de invitación, conservar el contexto de destino sin aceptar automáticamente antes de autenticar.
- Tratar estados de carga/error y correos aún no verificados.

## Flujo B — Grupo y paciente

```text
Usuario autenticado → crear o seleccionar grupo (nombre, FAMILY o CARE_CENTER)
  → alta paciente → crear patient_access ADMIN para creador autorizado
  → decidir “Configurar dispositivo ahora” o “Configurar después”
  → si eligió ahora: introducir un serial simulado preexistente y crear la asignación
  → si eligió después: dashboard con paciente y estado SIN DISPOSITIVO
```

La interfaz presenta este recorrido en una sola página con tres pasos visibles: **Grupo**, **Paciente** y **Dispositivo**, y permite volver del segundo al primero. Para un centro: `type=CARE_CENTER`; para hogar: `type=FAMILY`. No añadir administración hospitalaria. Con la alternativa simple aprobada, un grupo nuevo se persiste atómicamente junto con su primer paciente; los pacientes siguientes pueden reutilizar un grupo existente. Un paciente forma parte de un contexto grupal, pero sus permisos no son heredados de todos los miembros del grupo.

En el dashboard, **Agregar paciente** abre el asistente priorizando un grupo existente, mientras **Crear grupo** prioriza un contexto nuevo. Ambas acciones conservan el alta del paciente dentro del mismo recorrido, porque el MVP no mantiene grupos vacíos. **Ingresar código** permanece como una acción independiente.

Posponer el dispositivo no revierte el alta del grupo ni del paciente. El dashboard debe mostrar un aviso pequeño y accionable bajo el paciente: **Sin dispositivo configurado** + **Configurar ahora**. No presentar ubicación, riesgo `NORMAL` ni monitoreo activo hasta que exista una asignación y datos válidos.

## Flujo C — Dispositivo simulado y mapa

```text
ADMIN elige configurar ahora durante el onboarding o retoma “Configurar ahora” desde Juan
    → introduce el serial de una unidad simulada preexistente
    → asigna el dispositivo simulado a Juan
    → Juan tiene asignación activa
    → usuario autorizado abre /patients/:id/map
    → mapa con última posición y antigüedad
    → en entorno prueba: click autorizado o reproducción Node.js
    → backend guarda coordenada y evalúa riesgo
    → Realtime actualiza posición + indicadores
```

No mover el marcador como única prueba: el click debe producir un evento persistido y pasar por el mismo motor de riesgo que el simulador automático.

## Flujo D — Configurar geocerca

```text
ADMIN/MONITOR → /patients/:id/safe-zones
    → dibuja un círculo en Google Maps
    → ve el radio / coordenadas aproximadas
    → frontend valida formulario
    → Supabase verifica autorización + radio válido
    → guarda y muestra resultado
```

Si hay varias zonas activas, evaluar la unión lógica de las permitidas. Confirmar comportamiento al implementar la historia si se opta por restringir el MVP a una sola zona.

## Flujo E — Código de acceso e invitación

```text
ADMIN → /patients/:id/access → generar código MONITOR para ese paciente
    → invitación PENDING → compartir código fuera de la aplicación
    → destinatario crea cuenta o inicia sesión
    → “Ingresar un código de acceso” → revisar información mínima
    → ACCEPTED
    → crear patient_access MONITOR solo para ese paciente
```

No usar el mero código como autorización definitiva ni como membresía del grupo. En el UI, revelar solo información mínima antes de la aceptación. La invitación por email/enlace y la acción explícita `DECLINED` se conservan como ampliaciones posteriores sin cambiar el vocabulario aprobado.

## Flujo F — Consulta de alertas

```text
Nueva posición → motor de riesgo → episodio OPEN / escalado
    → actualización en /patients/:id/alerts
    → Web Push según nivel y permisos
    → vuelta segura → episodio RESOLVED
```

Alertas abiertas deben mostrar nivel, última lectura válida, cuándo comenzó el evento, hora de última actualización y si hay conexión reciente.

## Información mínima sugerida por pantalla (no UI final)

| Ruta | Contenido imprescindible |
|---|---|
| `/onboarding` | Elección inicial entre registrar dispositivo o monitorear con un código; ambas acciones siguen disponibles después |
| `/access-code` | Entrada, vista previa mínima y aceptación de un código de acceso `MONITOR` |
| `/dashboard` | Pacientes autorizados, riesgo conocido, conectividad, última actualización, acciones separadas de alta y aviso accionable cuando falta dispositivo |
| `/groups` | Asistente de grupo nuevo/existente, paciente y configuración opcional del dispositivo |
| `/groups/:id` | Datos básicos del grupo y pacientes del contexto que el usuario está autorizado a administrar/ver |
| `/patients/:id` | Ficha mínima, últimos indicadores y accesos a módulos |
| `/patients/:id/device` | Estado de asignación y formulario de serial simulado; solo para `ADMIN` |
| `/patients/:id/map` | Posición, timestamp, radio/zonas, modo simulación controlado |
| `/patients/:id/history` | Recorrido consultable en intervalo, origen de datos |
| `/patients/:id/alerts` | Episodios, severidad, inicio, actualización y resolución |
| `/patients/:id/safe-zones` | Geocercas circulares y edición por ADMIN/MONITOR |
| `/patients/:id/access` | Personas autorizadas; invitar/revocar solo ADMIN |
| `/invitations` | Invitaciones propias PENDING y acciones de aceptar/declinar |
| `/settings` | Perfil y activación de Web Push; información básica |

## UX indispensable

- No etiquetar una ubicación antigua como "en vivo".
- Diferenciar `NORMAL`, riesgo activo y `UBICACIÓN DESACTUALIZADA`.
- Manejar falta de geocerca, sin asignación, sin ubicación y ausencia de permisos como estados explícitos.
- La invitación a MONITOR no debe habilitar acciones de ADMIN aunque aparezcan por error controles gráficos.
- Los flujos de varios pasos deben mostrar progreso y permitir volver. La decisión de configurar después debe terminar en un estado vacío útil, nunca en un dashboard en blanco.
