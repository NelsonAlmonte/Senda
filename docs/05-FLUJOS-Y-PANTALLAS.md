# 05 — Flujos y pantallas funcionales

**Estado:** rutas aprobadas a nivel general. El contenido detallado, composición visual y microinteracciones se definen al implementar cada pantalla.

## Rutas previstas

```text
/auth/login
/auth/register
/onboarding
/access-code
/dashboard
/patients
/alerts
/groups
/groups/:id
/patients/:id
/patients/:id/map
/patients/:id/episodes
/patients/:id/history
/patients/:id/safe-zones
/patients/:id/access
/invitations
/settings
```

SvelteKit puede organizar rutas en grupos de layouts o prefijos internos cuando convenga sin cambiar el significado de estas URLs.

**Estado reorganizado (2026-10-28; ajustado hasta el 2026-10-31):** después del registro se redirige a `/onboarding`, donde se elige entre registrar un dispositivo o monitorear mediante código. El registro usa un asistente de tres pasos en `/groups`; `/access-code` separa la entrada del código de la confirmación mínima del paciente y del alcance `MONITOR`; un `ADMIN` genera el código desde `/patients/:id/access`. El área autenticada usa tres módulos persistentes: **Pacientes**, **Alertas** y **Perfil**. `/dashboard` queda como bienvenida mínima; `/patients` concentra la lista autorizada y sus acciones; `/alerts` reúne episodios de todos los pacientes, con los `OPEN` primero y el historial resuelto después. `/patients/:id/map` mantiene la vista detallada autorizada y `/patients/:id/episodes` ofrece el historial paginado del paciente concreto. Esta reorganización está implementada localmente y pendiente de validación manual responsive y de datos reales.

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
  → si eligió después: módulo Pacientes con estado SIN DISPOSITIVO
```

La interfaz presenta este recorrido en una sola página con tres pasos visibles: **Grupo**, **Paciente** y **Dispositivo**, y permite volver del segundo al primero. Para un centro: `type=CARE_CENTER`; para hogar: `type=FAMILY`. No añadir administración hospitalaria. Con la alternativa simple aprobada, un grupo nuevo se persiste atómicamente junto con su primer paciente; los pacientes siguientes pueden reutilizar un grupo existente. Un paciente forma parte de un contexto grupal, pero sus permisos no son heredados de todos los miembros del grupo.

En `/patients`, **Agregar paciente** abre el asistente priorizando un grupo existente, mientras **Crear grupo** prioriza un contexto nuevo. Ambas acciones conservan el alta del paciente dentro del mismo recorrido, porque el MVP no mantiene grupos vacíos. **Ingresar código** permanece como una acción independiente.

Posponer el dispositivo no revierte el alta del grupo ni del paciente. El módulo Pacientes debe mostrar un aviso pequeño y accionable bajo el paciente: **Sin dispositivo configurado** + **Configurar ahora**. No presentar ubicación, riesgo `NORMAL` ni monitoreo activo hasta que exista una asignación y datos válidos.

## Flujo C — Dispositivo simulado y mapa

```text
ADMIN elige configurar ahora durante el onboarding o retoma “Configurar ahora” desde Juan
    → introduce el serial de una unidad simulada preexistente
    → asigna el dispositivo simulado a Juan
    → Juan tiene asignación activa
    → usuario autorizado abre /patients/:id/map
    → mapa con última posición, antigüedad, geocercas activas y cinco episodios recientes
    → en entorno prueba: click autorizado o reproducción Node.js
    → backend guarda coordenada y clasifica su relación con las geocercas activas
    → Realtime actualiza posición + clasificación textual
```

No mover el marcador como única prueba: el click debe producir un evento persistido y pasar por el mismo motor de riesgo que el simulador automático.

Las geocercas activas autorizadas se dibujan como círculos no interactivos y se acompañan de nombre y radio; las inactivas o archivadas no aparecen en el monitoreo. El recorrido permanece dibujado sobre el mapa con hasta 200 lecturas, agrupadas por `device_assignment_id` para no unir asignaciones distintas. Realtime incorpora cada lectura nueva al marcador, al resumen y a la línea sin recargar. El 2026-10-30 se retiró solamente la tarjeta textual “Recorrido reciente”; la retención permanente continúa abierta en `09-DECISIONES-PENDIENTES.md`.

**Estado completado (2026-10-25; presentación ajustada el 2026-10-30):** el mapa, sus estados y la actualización automática por Postgres Changes están implementados con carga dinámica de Google Maps. Una lectura nueva y autorizada actualiza marcador, timestamp, precisión y clasificación sin reconstruir el mapa. El mapa usa interacción directa sin exigir `Ctrl`, muestra las geocercas activas y mantiene los círculos sin interacción para no bloquear la selección de una ubicación manual. El usuario validó manualmente la recepción simultánea con cuentas `ADMIN` y `MONITOR` en dos navegadores. El simulador Node reproduce una ruta ficticia de una sola pasada, con intervalo configurable y persistencia mediante la RPC común; el usuario validó su recorrido completo. La simulación manual en mapa solo aparece para `ADMIN` con dispositivo simulado y una bandera privada de entorno: permite seleccionar por click, exige confirmación, persiste mediante la RPC común con origen `MANUAL` y espera Realtime para actualizar el marcador oficial. El usuario validó este flujo completo. La ruta declara la dependencia `senda:patient-alerts`, compartida con la invalidación global de episodios, para no mostrar primero un estado SSR obsoleto al navegar hacia un paciente con salida activa.

**Historia 4B completada (2026-10-25):** una lectura nueva muestra además **Dentro de una zona permitida**, **Fuera de las zonas permitidas**, **Ubicación cerca del límite** o **Sin geocerca activa**. El estado usa texto completo y no depende solo del color. `OUTSIDE` advierte expresamente que una lectura aislada todavía no constituye una alerta confirmada; `NOT_EVALUATED` explica que la lectura antecede al clasificador. La actualización Realtime transporta la misma clasificación persistida por PostgreSQL. La migración está aplicada en Supabase de desarrollo, sus 36 pruebas pgTAP pasan y el usuario validó manualmente todos los estados y Realtime.

## Flujo D — Configurar geocerca

```text
ADMIN/MONITOR → /patients/:id/safe-zones
    → crea o selecciona una geocerca guardada
    → escribe un nombre corto
    → activa el modo de selección y toca el centro en Google Maps
    → ajusta el radio con slider o valor numérico exacto
    → frontend valida formulario
    → Supabase verifica patient_access + nombre/coordenadas/radio
    → guarda y muestra resultado
```

Se permiten varias zonas activas y superpuestas. La evaluación futura usa la unión lógica: basta estar dentro de una zona activa para permanecer en un área permitida. No existe máximo artificial en la base de datos; la demostración habitual usará entre dos y cinco.

El radio comienza en 250 m, admite 50–5,000 m e incrementos de 50 m. El círculo cambia durante el ajuste y, al terminar, el mapa adapta el encuadre con margen. Después de colocar el centro, el círculo provisional se puede arrastrar tanto al crear como al editar. **Cambiar centro** mantiene una alternativa por toque/click y permite elegir cualquier punto, incluso dentro de la misma geocerca o de otra existente; durante esa selección, los círculos no interceptan el toque. Latitud, longitud y radio tienen entradas numéricas como alternativa de teclado.

El editor usa interacción directa con el mapa: la rueda amplía sin exigir `Ctrl` en escritorio y los gestos iniciados sobre el mapa lo manipulan en móvil. El resto de la página conserva el desplazamiento normal fuera del área del mapa.

La zona seleccionada se destaca; las demás activas se presentan con menor énfasis; la provisional usa una apariencia ámbar y texto explícito; una zona inactiva permanece oculta salvo al seleccionarla en la lista. Crear, editar, activar, desactivar y archivar están disponibles para `ADMIN` y `MONITOR`. Archivar no elimina físicamente la fila.

**Estado completado (2026-10-25):** la ruta, el editor gráfico, la lista accesible, las acciones SSR y el enlace desde cada paciente están implementados. La migración está aplicada en Supabase de desarrollo y su suite pgTAP pasa 29 casos. El usuario validó manualmente el flujo completo, incluidos el zoom directo, el arrastre del círculo, la selección de centros superpuestos, la limpieza del estado provisional y la visualización de las zonas activas en el mapa de monitoreo. Desde el 2026-10-28, ese enlace parte del módulo `/patients`.

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
Nueva posición → motor de episodios → episodio OPEN
    → actualización en /patients/:id/map
    → aparición prioritaria en /alerts
    → Web Push opcional al abrir el episodio
    → vuelta segura → episodio RESOLVED
```

Los episodios abiertos deben mostrar cuándo comenzó y se confirmó la salida, junto con la ubicación y conectividad presentadas por separado. El MVP no usa niveles de severidad ni necesita una pantalla adicional para explicar escaladas.

**Historia 4C completada (2026-10-25):** `/patients/:id/map` separa la clasificación de la última lectura del episodio confirmado. Dos lecturas `OUTSIDE` confiables y consecutivas abren un episodio `OPEN`; dos `INSIDE` lo resuelven. La tarjeta actual y el historial breve se actualizan por Realtime y usan estado textual además de color. La migración está aplicada en desarrollo, sus 55 pruebas pgTAP pasan y el usuario validó el recorrido extremo a extremo. Los niveles y escaladas quedan fuera del MVP.

**Historia 4D completada y validada (2026-10-26):** `/dashboard` consulta por SSR el episodio `OPEN` de cada paciente autorizado y lo presenta antes del estado del dispositivo. La tarjeta indica **Salida confirmada activa**, muestra cuándo se confirmó y ofrece **Ver ubicación y detalles**. Una sola suscripción a `alert_episodes` procesa aperturas y resoluciones para todos los pacientes visibles; RLS continúa siendo la autorización efectiva. Los cambios se anuncian mediante una región de estado contextual sin mover el foco. Si falla la consulta o Realtime, la interfaz no supone que el paciente está seguro y ofrece una recuperación explícita. El usuario confirmó la aparición y desaparición automática de la tarjeta y el acceso correcto al mapa.

**Reorganización de módulos (2026-10-28):** la capacidad validada en 4D se trasladó a `/alerts`. La pantalla consulta hasta 100 episodios autorizados, coloca todos los `OPEN` arriba con el nombre del paciente destacado y muestra los `RESOLVED` como historial. Una suscripción Realtime invalida la carga SSR ante aperturas o resoluciones; la consulta y los eventos siguen filtrados por RLS. `/dashboard` ya no presenta pacientes ni alertas. La nueva composición queda pendiente de validación manual extremo a extremo.

## Información mínima sugerida por pantalla (no UI final)

| Ruta | Contenido imprescindible |
|---|---|
| `/onboarding` | Elección inicial entre registrar dispositivo o monitorear con un código; ambas acciones siguen disponibles después |
| `/access-code` | Entrada con ayuda y errores accesibles, vista previa mínima y aceptación explícita de un código `MONITOR` de un solo uso |
| `/dashboard` | Bienvenida mínima con el nombre del usuario |
| `/patients` | Pacientes autorizados, estado de dispositivo/ubicación, acciones de alta y navegación a sus operaciones |
| `/alerts` | Episodios autorizados globales: alertas `OPEN` primero e historial `RESOLVED` después |
| `/groups` | Asistente de grupo nuevo/existente, paciente y configuración opcional del dispositivo |
| `/groups/:id` | Datos básicos del grupo y pacientes del contexto que el usuario está autorizado a administrar/ver |
| `/patients/:id` | Ficha mínima, últimos indicadores y accesos a módulos |
| `/patients/:id/device` | Estado de asignación y formulario de serial simulado; solo para `ADMIN` |
| `/patients/:id/map` | Posición, timestamp, radio/zonas, episodio actual e historial breve, modo simulación controlado |
| `/patients/:id/episodes` | Alerta activa separada e historial autorizado del paciente, con episodios finalizados paginados de doce en doce |
| `/patients/:id/history` | Recorrido consultable en intervalo, origen de datos |
| `/patients/:id/safe-zones` | Geocercas circulares y edición por ADMIN/MONITOR |
| `/patients/:id/access` | Personas autorizadas; invitar/revocar solo ADMIN |
| `/invitations` | Invitaciones propias PENDING y acciones de aceptar/declinar |
| `/settings` | Perfil, activación de Web Push y cierre de sesión; en escritorio, la misma acción también permanece en el pie del sidebar |

En `/settings`, Web Push distingue **activadas**, **desactivadas**, **bloqueadas**, **no compatibles**, **configuración pendiente** y **error de comprobación**. El permiso del navegador por sí solo no significa que el dispositivo esté activo: también deben existir una suscripción de `PushManager` y su fila propia en `push_subscriptions`. La activación y desactivación se realizan por dispositivo.

Antes de solicitar el permiso del sistema, la PWA valida la sesión remota de Supabase. Al regresar del diálogo del sistema la comprueba nuevamente antes de crear o reutilizar la suscripción del navegador. Si la sesión dejó de ser válida, redirige al inicio de sesión conservando `/settings` como destino y no deja una suscripción incompleta. Este ajuste responde al caso observado en Chrome para Android donde el permiso se concedía, pero Supabase devolvía `session_not_found` al intentar persistirlo.

El estado y los controles de Web Push se consultan desde `/settings`; la navegación persistente y el acceso directo del header mantienen **Perfil** accesible sin añadir recordatorios al inicio. Navegadores no compatibles y errores técnicos no se presentan como si el usuario hubiera decidido desactivar las notificaciones. En escritorio, **Cerrar sesión** se separa de los módulos y queda al fondo del sidebar; Perfil también presenta esa acción como su última sección en todos los anchos para que la gestión de la cuenta sea autosuficiente.

El header autenticado incluye el título contextual de la ruta, una campana que conduce a `/alerts` y un acceso a `/settings`. En rutas anidadas de paciente, el título incorpora su nombre y una flecha accesible regresa a la pantalla padre; por ello las páginas no repiten encabezados de ubicación dentro del contenido. En rutas principales el título recibe un margen inicial pequeño; en subrutas ese margen desaparece y se muestra la flecha. La carga SSR consulta únicamente si existe al menos un episodio `OPEN` visible por RLS y muestra un punto rojo en la campana cuando corresponde; el nombre accesible del control expresa también ese estado, por lo que no depende solo del color. Una suscripción Realtime global invalida esa consulta ante aperturas o resoluciones. El sidebar mantiene la columna general en escritorio, el header añade padding interno para separar sus controles de los bordes y la barra inferior móvil flota con márgenes y radio equivalentes.

Al abrirse un episodio, cada navegador suscrito de un usuario autorizado recibe como máximo una notificación titulada **Alerta de zona segura** con el texto **Posible salida de una zona segura. Abre Senda para revisar de inmediato.** El mensaje evita nombres, coordenadas y datos clínicos. Al pulsarlo abre `/alerts`, donde la sesión y RLS determinan qué episodios puede consultar la persona. El 2026-10-28 se desplegó en Supabase de desarrollo la versión 2 de `send-geofence-alert` con ese destino y se comprobó que inicia y responde; queda pendiente repetir el flujo extremo a extremo con una alerta real y el clic de la notificación.

Cuando un navegador Chromium determina que la PWA es instalable, Senda muestra una acción global y descartable **Instalar Senda**. La acción conserva el evento `beforeinstallprompt` y abre el diálogo nativo únicamente como respuesta al toque o clic del usuario; se oculta al recibir `appinstalled`, después de consumir el evento o durante la navegación actual si la persona elige **Ahora no**. Una recarga completa permite que la promoción vuelva a aparecer; la elección no se guarda como rechazo permanente. En iPhone/iPad se presenta una guía para abrir la página en Safari y usar **Compartir → Añadir a pantalla de inicio**, además de **Abrir como app** cuando la opción esté disponible; en Safari para macOS Sonoma 14 o posterior se indica **Archivo → Añadir al Dock**. La guía tampoco aparece al ejecutar Senda como PWA instalada.

## UX indispensable

- No etiquetar una ubicación antigua como "en vivo".
- Diferenciar `NORMAL`, riesgo activo y `UBICACIÓN DESACTUALIZADA`.
- Manejar falta de geocerca, sin asignación, sin ubicación y ausencia de permisos como estados explícitos.
- La invitación a MONITOR no debe habilitar acciones de ADMIN aunque aparezcan por error controles gráficos.
- Los flujos de varios pasos deben mostrar progreso y permitir volver. La decisión de configurar después debe terminar en un estado vacío útil en `/patients`, nunca en una pantalla en blanco.
