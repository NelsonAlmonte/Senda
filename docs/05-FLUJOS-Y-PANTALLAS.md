# 05 — Flujos y pantallas funcionales

**Estado:** rutas aprobadas a nivel general. El contenido detallado, composición visual y microinteracciones se definen al implementar cada pantalla.

## Rutas previstas

```text
/auth/login
/auth/register
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
  → decidir “Configurar dispositivo ahora” o “Configurar después”
  → alta paciente → crear patient_access ADMIN para creador autorizado
  → si eligió ahora: continuar a registro simulado y asignación
  → si eligió después: dashboard con paciente y estado SIN DISPOSITIVO
```

Para un centro: `type=CARE_CENTER`; para hogar: `type=FAMILY`. No añadir administración hospitalaria. El primer paciente puede crear el contexto; los dispositivos o pacientes siguientes deben poder reutilizar un grupo existente. Un paciente forma parte de un contexto grupal, pero sus permisos no son heredados de todos los miembros del grupo.

Posponer el dispositivo no revierte el alta del grupo ni del paciente. El dashboard debe mostrar un aviso pequeño y accionable bajo el paciente: **Sin dispositivo configurado** + **Configurar ahora**. No presentar ubicación, riesgo `NORMAL` ni monitoreo activo hasta que exista una asignación y datos válidos.

## Flujo C — Dispositivo simulado y mapa

```text
ADMIN elige configurar ahora durante el onboarding o retoma “Configurar ahora” desde Juan
    → registra/activa una unidad simulada
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
    → ACCEPTED / DECLINED
    → si ACCEPTED, crear patient_access MONITOR solo para ese paciente
```

No usar el mero código como autorización definitiva ni como membresía del grupo. En el UI, revelar solo información mínima antes de la aceptación. La invitación por email y enlace se conserva como ampliación posterior.

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
| `/dashboard` | Pacientes autorizados, riesgo conocido, conectividad, última actualización y aviso accionable cuando falta dispositivo |
| `/groups` | Lista/creación de contextos FAMILY o CARE_CENTER |
| `/groups/:id` | Datos básicos del grupo y pacientes del contexto que el usuario está autorizado a administrar/ver |
| `/patients/:id` | Ficha mínima, últimos indicadores y accesos a módulos |
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
