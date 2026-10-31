# 08 — Implementación incremental y pruebas

## Regla de trabajo

Cada fase se entrega con: funcionalidad visible, cambios SQL en migraciones, permisos adecuados, casos de prueba y reporte de resultados reales. Codex no debe empezar fases posteriores sin solicitud. Esta secuencia prioriza un MVP tangible, pero sin abrir datos sensibles durante el desarrollo.

### Flujo Git por historia

1. Revisar que `main` esté actualizado y que cualquier cambio previo del árbol de trabajo esté identificado.
2. Crear una rama por historia con prefijo semántico (`feat/`, `fix/`, `docs/`, `refactor/`, `test/` o `chore/`) y nombre kebab-case.
3. Mantener la rama limitada a una historia o corrección; no incorporar cambios ajenos accidentalmente.
4. Ejecutar las verificaciones disponibles y revisar `git diff` antes de cerrar el trabajo.
5. Usar Conventional Commits en inglés, con alcance cuando aporte contexto.
6. No ejecutar `git add`, commit, push, pull, merge, rebase ni cambios de rama hasta que el usuario lo indique explícitamente. Cuando lo indique, Codex puede usar la consola normal. El cierre predeterminado es merge directo en `main` y push de `main`; usar pull request solo por petición expresa.
7. Si colaboran varios desarrolladores o agentes, usar ramas/historias separadas y acordar previamente cambios sobre migraciones o archivos compartidos.

## Fases

### Fase 0 — Preparación y prueba del stack

- Crear estructura mínima con **`@sveltejs/kit@3.1.0` exactamente**, Svelte 5, TypeScript y Tailwind CSS. Configurar Google Maps y Supabase con `.env.example`, sin solicitar ni incrustar secretos reales.
- Integrar PWA **desde el comienzo** mediante `vite-plugin-pwa@1.3.0`, excepción aprobada tras comprobar que `@vite-pwa/sveltekit@1.1.0` no admite el peer de SvelteKit 3.1.0. Comprobar Vite/adaptador, typecheck, manifest, service worker y build sin cambiar SvelteKit ni forzar peers.
- Probar instalación de PWA, rutas profundas, manifest y funcionamiento básico del service worker, si las pruebas son viables con el entorno disponible.
- Mantener SSR con `@sveltejs/adapter-netlify@7.0.1` y validar en Netlify las rutas profundas, cookies de Auth, manifest y service worker.
- **Utilizar** las herramientas Svelte/Supabase y la skill UI UX Pro Max disponibles en Codex VS Code; no instalarlas dentro del proyecto ni como parte de esta fase.

**Aceptación:** `dev`, `typecheck` y `build` funcionan; la aplicación carga y las configuraciones públicas/privadas están separadas.

### Fase 1 — Autenticación y datos mínimos

- Supabase Auth, registro/login/logout, perfil.
- `groups`, `patients`, `patient_access` + constraints + RLS inicial.
- Crear grupo FAMILY/CARE_CENTER, agregar paciente y otorgar ADMIN al creador autorizado.

**Aceptación:** se puede crear paciente con cuenta A; cuenta B no accede sin `patient_access`.

**Estado de implementación (2026-10-24):** la historia 1A cubre Auth y perfil. Las migraciones de `feat/patient-onboarding` están aplicadas en Supabase de desarrollo. La suite pgTAP pasa 25 casos, incluido el aislamiento entre dos cuentas, el rechazo de inserciones en grupos ajenos y el alta de otro paciente en un grupo propio existente. La creación de grupo + paciente también fue validada manualmente desde la PWA.

**Historia 1B completada y validada (2026-10-27) — administración de pacientes:** `/patients/:id` centraliza el resumen autorizado del paciente y la navegación a accesos, dispositivo, mapa y geocercas. Un `ADMIN` puede editar únicamente nombre y apellido, consultar las personas con acceso y revocar accesos `MONITOR`; un `MONITOR` conserva una vista de solo lectura y las operaciones de monitoreo permitidas. La revocación establece `revoked_at`, conserva la fila para auditoría y hace que la RLS existente retire la visibilidad del paciente. Supabase MCP confirmó aplicada en desarrollo la migración `20261027154308_patient_administration.sql`, que concentra listado, edición y revocación en RPC con autorización por paciente. Sus 32 casos pgTAP positivos y negativos pasan con rollback, sin dejar datos ficticios, y el usuario validó manualmente el recorrido completo.

### Fase 2 — Dispositivo simulado e ingestión

- `devices`, `device_assignments`, `locations` con referencia **histórica** a la asignación.
- Onboarding con dos acciones no excluyentes: configurar un dispositivo o ingresar un código de acceso a un paciente.
- Permitir configurar el dispositivo ahora o después del alta. El módulo Pacientes debe mostrar el estado **Sin dispositivo configurado** y permitir retomar la asignación.
- Reutilizar un grupo existente al registrar pacientes o dispositivos adicionales; no crear un nuevo centro/familia obligatoriamente.
- Código de un solo uso asociado a un paciente y rol `MONITOR`; no crear `group_members` ni heredar acceso al grupo.
- Endpoint/RPC autorizada para simulación de posiciones.
- Click en Google Maps y script Node.js con rutas; ambos usan procesamiento compartido.

**Aceptación:** un paciente puede quedar sin dispositivo y retomar la configuración; un código concede acceso únicamente al paciente correcto; los movimientos se guardan y no pueden falsificarse por usuarios no autorizados.

**Estado completado (2026-10-25, historias 2A–2E):** implementados `devices`, `device_assignments`, la regla de un dispositivo activo por paciente, tres seriales demo preexistentes y la RPC de asignación restringida a `ADMIN`. El alta guiada separa grupo, paciente y dispositivo; permite crear un grupo con su primer paciente, reutilizar un grupo propio, configurar ahora o después y retomar la configuración desde la lista de pacientes. El registro redirige al selector entre registrar y monitorear; un `ADMIN` puede generar un código manual de un solo uso y otra cuenta puede revisarlo y obtener `MONITOR` exclusivamente sobre ese paciente. La ingestión idempotente de ubicaciones vinculadas a la asignación histórica ya está aplicada en Supabase de desarrollo, con lectura para `ADMIN`/`MONITOR` y escritura simulada limitada a `ADMIN`. Existen un emisor Node de una lectura, una ruta ficticia determinista de 12 puntos y simulación manual desde el mapa. Esta última requiere una bandera privada de entorno, muestra una selección provisional y persiste con origen `MANUAL` por la misma RPC antes de que Realtime actualice la ubicación oficial. El usuario validó los tres mecanismos de simulación contra Supabase de desarrollo; la suite pgTAP pasa 39 casos y las suites anteriores continúan pasando 25, 23 y 17 casos. La Fase 2 queda completada.

### Fase 3 — Mapa e historial

- Último punto válido, horario de última actualización, trazado histórico y Realtime.
- Estados sin dispositivo, sin datos y datos obsoletos.

**Aceptación:** segundo navegador autorizado ve coordenadas nuevas sin recargar; dispositivo reutilizado no filtra recorridos anteriores.

**Estado completado (2026-10-25, historias 3A–3C; presentación actualizada el 2026-10-30):** `/patients/:id/map` presenta la última posición autorizada mediante Google Maps, con marcador, precisión opcional, timestamp y estados sin dispositivo, sin lectura, desactualizado y error. El mapa ocupa el ancho principal y precede a los resúmenes; la UI no expone coordenadas, seriales ni un indicador redundante de conexión. Postgres Changes continúa habilitado sobre `locations`; la PWA reutiliza la sesión SSR, filtra por la asignación histórica y actualiza el punto más reciente sin recargar. La historia 3C mantiene la consulta y el dibujo de hasta 200 lecturas separadas por `device_assignment_id`; Realtime añade lecturas nuevas al recorrido sin reconstruir el mapa. El 2026-10-30 se retiró únicamente la tarjeta textual con cantidad y rango temporal del recorrido. La política RLS continúa autorizando por paciente y la suite pgTAP de ubicaciones pasa 39 casos. El usuario validó manualmente Realtime con cuentas `ADMIN` y `MONITOR`, el historial persistente y el movimiento del marcador; el aislamiento al reutilizar dispositivos está cubierto por pgTAP. La Fase 3 queda completada.

### Fase 4 — Geocercas y motor de alertas

- `safe_zones`, episodios `alert_episodes`, validación de lecturas, confirmación de salida y reingreso.
- Episodio de salida y conectividad separados; sin niveles de severidad ni cron de escalado en el MVP.
- Escenarios automáticos con tiempo de simulación controlado.

**Aceptación:** superar casos R01–R19 aplicables, tras ratificar umbrales abiertos.

**Estado completado (2026-10-25, historia 4A; presentación ajustada el 2026-10-30):** se implementó la configuración de múltiples geocercas circulares en `/patients/:id/safe-zones`, con radio 50–5,000 m, selección y arrastre del centro en Google Maps, activación/desactivación y archivo sin borrado. La interfaz actual oculta latitud y longitud y define el centro mediante toque/click directo sobre el mapa. El mapa ocupa la columna principal y la columna lateral alterna entre la lista y el editor. La migración `20261025183035_patient_safe_zones.sql` está aplicada en Supabase de desarrollo y añade `safe_zones`, RLS por paciente y RPC para `ADMIN`/`MONITOR`. La suite pgTAP pasa 29 casos: permisos negativos, nombres únicos, más de cinco zonas y conservación al archivar, entre otros. El usuario validó manualmente la funcionalidad original y la visualización de las zonas activas en el mapa de monitoreo; el ajuste visual del 2026-10-30 queda pendiente de validación manual. El motor de riesgo, episodios, salida/reingreso y alertas no forman parte de 4A.

**Estado completado (2026-10-25, historia 4B; presentación ajustada el 2026-10-30):** PostgreSQL clasifica cada lectura como `INSIDE`, `OUTSIDE`, `UNCERTAIN` o `NO_ACTIVE_ZONE`, con `NOT_EVALUATED` para el historial anterior. La tolerancia efectiva es el mayor valor entre la precisión informada y 25 m. La PWA presenta la relación en `/patients/:id/map`; cuando existe un episodio `OPEN`, este tiene prioridad narrativa y una lectura `OUTSIDE` se muestra como contexto de la salida ya confirmada. Sin episodio activo, una lectura aislada fuera se comunica como advertencia todavía no confirmada. La migración `20261026000952_geofence_location_evaluation.sql` está aplicada en Supabase de desarrollo y sus 36 casos pgTAP pasan; la transacción de prueba no dejó registros ficticios. El usuario validó manualmente todos los estados y la actualización Realtime en la PWA. La confirmación con dos lecturas, los episodios y el reingreso se implementaron después en 4C; las notificaciones permanecen en una fase posterior.

**Estado completado (2026-10-25, historia 4C; límite visual actualizado el 2026-10-29):** `alert_episodes` conserva un único episodio `OPEN` por paciente, vinculado a la asignación histórica y a las lecturas confirmatorias. Dos `OUTSIDE` consecutivas con precisión nula o de hasta 100 m lo abren; dos `INSIDE` lo resuelven. Lecturas inciertas, sin zona, imprecisas o atrasadas no alteran indebidamente el estado. La PWA muestra estado e historial breve por SSR y Realtime; el mapa consulta y presenta solamente los cinco episodios más recientes. La vista completa `/patients/:id/episodes`, pospuesta en esta historia, se implementó posteriormente en 7D. Las migraciones `20261026010952_geofence_alert_episodes.sql` y `20261026012835_remove_alert_episode_severity.sql` están aplicadas en desarrollo; sus 55 casos pgTAP pasan sin dejar datos ficticios y el usuario validó manualmente el flujo. La segunda elimina la columna redundante `severity`; el equipo decidió no implementar niveles, escaladas ni cron en el MVP. La Fase 4 queda completada.

**Estado completado (2026-10-26, historia 4D):** el dashboard incorpora el episodio `OPEN` a la carga SSR de cada paciente autorizado y mantiene las tarjetas sincronizadas mediante una sola suscripción Postgres Changes sobre `alert_episodes`. La presentación usa texto, fecha, enlace al mapa y una región accesible para anunciar apertura o resolución. No añade tablas, severidades ni permisos; reutiliza la publicación y RLS validadas en 4C. El usuario validó manualmente la apertura, resolución y navegación contextual sin recargar el dashboard.

### Fase 5 — Compartición e invitaciones

- Extender el código inicial con invitación por email y enlace, manteniendo `PENDING`, aceptar/rechazar y revocación de `patient_access`.
- Integración de correo con configuración Supabase Auth/Gmail y mecanismo específico de emails de paciente.
- Esta invitación sirve para conceder acceso al paciente; no participa en las notificaciones Web Push, que usan suscripciones del navegador en la Fase 6.

**Aceptación:** email y token correctos permiten acceso; email erróneo/token reutilizado/usuario sin permiso no.

### Fase 6 — Notificaciones Web Push y PWA completa

- Pedir permiso, guardar suscripciones, enviar push desde backend ante cambio de episodio.
- Usar la estrategia confirmada `injectManifest` con service worker propio para eventos `push` y `notificationclick`, conservando únicamente el precache estático.
- Probar en navegadores/OS de interés, incluido iPhone instalado en pantalla de inicio cuando haya acceso al dispositivo.

**Aceptación:** alerta llega a usuarios autorizados incluso con PWA cerrada en entorno compatible; fallo de push no borra alerta.

**Historia 6A completada (2026-10-26; UI reorganizada el 2026-10-28):** suscripción por navegador y activación/desactivación desde `/settings`, con RLS por propietario. El estado combina permiso del navegador, `PushSubscription` local y fila propia en Supabase. La migración está aplicada en Supabase de desarrollo y sus 29 pruebas pgTAP pasan con rollback, sin dejar suscripciones de prueba. El usuario validó manualmente la activación, desactivación y los estados asociados en el navegador. El recordatorio previo del dashboard se retiró al dejar esa pantalla como bienvenida mínima; **Perfil** mantiene `/settings` siempre accesible desde la navegación principal.

**Historia 6B completada y validada (2026-10-26; destino actualizado el 2026-10-28):** un trigger `AFTER INSERT` en `alert_episodes` encola mediante `pg_net` una llamada a la Edge Function activa `send-geofence-alert`. La función valida un secreto compartido, obtiene las suscripciones pertenecientes a usuarios con acceso activo, envía un payload genérico y elimina endpoints `404/410`. El recorrido validado originalmente abría `/dashboard`. El service worker, handler y prueba versionados apuntan ahora a `/alerts`; la Edge Function versión 2 fue desplegada en Supabase de desarrollo y su endpoint respondió correctamente a la prueba de arranque. Falta repetir la prueba extremo a extremo con una alerta real y pulsar la notificación antes de considerar validado el nuevo destino. No envía al resolver, no reintenta persistentemente y no revierte el episodio si falla. Chrome continúa como navegador Chromium de referencia para la demostración del MVP.

**Historia 6C implementada y pendiente de validación manual (actualizada el 2026-10-28) — instalación visible de la PWA:** el layout raíz captura `beforeinstallprompt` y muestra una acción global, pequeña y descartable **Instalar Senda** únicamente cuando Chromium declara la aplicación instalable. El diálogo se abre por acción explícita y el evento se consume una sola vez. En iPhone/iPad se muestra la ruta manual de Safari **Compartir → Añadir a pantalla de inicio** y **Abrir como app** cuando esté disponible; en Safari para macOS Sonoma 14 o posterior, **Archivo → Añadir al Dock**. La promoción se oculta con `appinstalled`, no aparece en modo instalado y **Ahora no** la descarta durante la navegación actual; puede volver tras una recarga completa. Antes de cerrar la historia se debe validar en Chrome de escritorio y Android, tanto sin instalar como después de instalar, y comprobar la guía en Safari/iPhone cuando haya acceso a esos entornos.

### Fase 7 — Calidad, evidencia y demo

**Historia 7A implementada localmente y pendiente de validación manual (2026-10-28; ajustada el 2026-10-29) — navegación modular:** `/dashboard` queda como saludo mínimo; `/patients` concentra la lista, estados y operaciones; `/alerts` presenta episodios globales con `OPEN` primero e historial resuelto. Una navegación semántica única usa una barra Material 3 flotante y redondeada en móvil y un sidebar oscuro flotante desde `lg`, con iconos `@lucide/svelte@1.63.0`, etiquetas visibles, `aria-current`, foco y áreas táctiles amplias. El header opaco, sin blur, centraliza el título contextual, los retornos de rutas anidadas y los accesos a Alertas y Perfil; las rutas de paciente muestran allí su nombre. Sus botones son circulares y el título compacto usa margen inicial en rutas principales, sustituido por la flecha real en subrutas. La campana consulta por SSR la existencia de un episodio `OPEN` visible por RLS y se actualiza por Realtime. El sidebar define la columna general y usa `shadow-md`; el header y la barra inferior usan `shadow-sm`. **Cerrar sesión** queda al fondo del sidebar en escritorio y dentro de Perfil en móvil. No se añadió shadcn-svelte porque el shell no requiere componentes complejos. Debe validarse en móvil y escritorio: títulos dinámicos, retornos, rutas activas, safe area, navegación con teclado, alineación, contenido no oculto por las barras, consulta real del indicador, apertura/resolución Realtime y cierre de sesión en ambos anchos.

**Historia 7B implementada localmente y pendiente de validación manual (2026-10-29) — dirección visual de Pacientes:** después del piloto comparativo, el equipo eligió la composición serena/editorial. `/patients` conserva únicamente tarjetas amplias con identidad, estado y operaciones separadas; se retiraron el selector, las métricas bento y la alternativa expresiva. La cuadrícula adapta una, dos y tres columnas en móvil, tablet y escritorio amplio respectivamente. Las tarjetas principales usan `rounded-2xl`, no tienen borde exterior y aplican `shadow-sm`, sin trasladar elevación a botones ni paneles internos; su contenido usa `p-6` sin ampliarse en escritorio y los pies de acciones separados usan `p-4`. Las familias de acciones, encabezados y tarjetas usan separación vertical diferenciada. La estructura superior comparte el mismo padding, headings `text-2xl` y `mb-8` exacto antes de los componentes, sin márgenes acumulados. El shell autenticado centraliza `min-h-dvh` para evitar scroll artificial en páginas cortas. Los tratamientos decorativos usan `surface-muted` como tono neutral único y el color queda reservado para estados semánticos. La vista preserva acciones y permisos, usa iconos Lucide y no modifica el esquema de Supabase. El componente compartido `Initials` centraliza el cálculo y la presentación de avatares textuales en lista, detalle y accesos; `Heading` unifica los encabezados internos con iconos, incluido el dispositivo. Cada tarjeta omite coordenadas, frescura de ubicación y la etiqueta de acceso; prioriza el episodio `OPEN` autorizado por RLS y distingue con texto **Alerta activa**, **Sin alertas activas**, **Sin dispositivo configurado** y error de consulta. La suscripción Realtime global invalida la carga SSR de este indicador al abrirse o resolverse un episodio. `/patients/:id` utiliza el ancho completo con edición y resumen en una cuadrícula asimétrica; reemplaza “Estado actual” por bloques compactos y agrupa las acciones en tarjetas de Monitoreo y Administración. `/patients/:id/access` separa la generación de códigos de las tarjetas individuales de personas autorizadas, elimina la etiqueta vacía de relación y mantiene la acción y confirmación de revocación en el pie de cada acceso `MONITOR`; compartir acceso permanece a la derecha en escritorio y precede a la lista en móvil. `/patients/:id/device` aplica la misma estructura a sus estados sin asignación y configurado, conserva feedback de formulario y muestra serial, estado y fecha sin confundir asignación con conectividad; su interfaz omite nomenclatura de prueba y unifica el color de enlaces y botones primarios. El sidebar y la barra inferior usan superficies opacas sin `backdrop-filter`. Las referencias se aplican solo a estructura y ritmo; los colores provienen de los tokens vigentes de Senda. Deben verificarse en móvil y escritorio esos cuatro estados, `ADMIN`/`MONITOR`, vacío, acciones, formularios, actualización Realtime, generación de código, revocación y ambas composiciones de detalle antes de extender el estilo al resto de módulos.

**Historia 7C implementada localmente y pendiente de validación manual (2026-10-30) — rediseño de Alertas:** `/alerts` adopta la dirección serena/editorial ya aplicada en Pacientes sin modificar consultas, RLS ni Realtime. Las salidas activas usan tarjetas blancas con estado urgente textual, icono y superficies `danger`/`warning`; muestran la hora confirmada, una recomendación clara y separan **Revisar ubicación** de **Ver paciente**. El historial usa una cuadrícula de tarjetas compactas con `Initials`, `InfoItem`, fecha de confirmación y fecha de resolución, evitando filas de ancho excesivo. `AlertEpisodeCard` centraliza ambos estados, acepta identidad opcional y acciones configurables para poder reutilizar la misma UI en el futuro historial de un paciente sin repetir su nombre. El enlace de un episodio resuelto se describe como acceso al mapa del paciente mientras el recorrido histórico exacto permanezca pendiente. Los errores reutilizan `Alert`, los estados vacíos permanecen explícitos y el color nunca es la única señal. Debe validarse en móvil y escritorio con cero, uno y varios episodios, nombres largos, error de consulta y apertura/resolución Realtime.

**Historia 7D implementada localmente y pendiente de validación manual (2026-10-30) — historial de episodios por paciente:** `/patients/:id/episodes` consulta mediante SSR únicamente el paciente autorizado y aplica la RLS existente sobre `patient_access` y `alert_episodes`. La alternativa aprobada consulta el episodio `OPEN` por separado para mantenerlo visible y pagina doce episodios `RESOLVED` mediante `count: 'exact'`, orden estable por confirmación e identificador y `range()` inclusivo. La ficha y el mapa del paciente enlazan la ruta; el header conserva retorno predecible a la ficha. La cuadrícula reutiliza `AlertEpisodeCard` sin repetir la identidad del paciente, añade subtítulos contextuales, muestra estados vacíos y errores de consulta independientes y ofrece navegación semántica **Anterior/Siguiente** con URL canónica. La dependencia `senda:patient-alerts` permite que la suscripción global invalide la carga al abrir o resolver un episodio. No se añadieron migraciones ni permisos. Debe validarse con `ADMIN` y `MONITOR`, cero, menos de doce, exactamente doce y más de doce episodios resueltos, páginas inválidas, revocación de acceso y apertura/resolución Realtime.

- Pruebas integrales de permisos y casos límite; UX y accesibilidad; registro de métricas y documentación.
- Preparar demo con ruta dentro/fuera, apertura del episodio, retorno, historial, cambios de geocerca e invitación.
- Documentar limitaciones, resultados medidos y tecnología realmente utilizada.

**Aceptación:** el MVP funciona de extremo a extremo y puede presentarse al jurado como producto funcional con simulación permitida.

## Estructura sugerida del repositorio

```text
/
├── AGENTS.md
├── README.md
├── docs/
│   ├── 01-ALCANCE-MVP.md
│   ├── 02-ARQUITECTURA.md
│   ├── 03-MODELO-DATOS.md
│   ├── 04-PERMISOS-Y-SEGURIDAD.md
│   ├── 05-FLUJOS-Y-PANTALLAS.md
│   ├── 06-MONITOREO-Y-ALERTAS.md
│   ├── 07-UI-UX.md
│   ├── 08-PLAN-Y-PRUEBAS.md
│   └── 09-DECISIONES-PENDIENTES.md
├── src/                        # SvelteKit
├── static/                     # iconos/manifest/assets PWA
├── supabase/
│   ├── migrations/
│   ├── functions/              # solo si la operación lo requiere
│   └── seed.sql
├── simulator/                  # Node.js / rutas de prueba
└── tests/
```

No construir monorepo ni `apps/` de forma preventiva. Con una PWA, Supabase y un simulador, una única raíz mantiene el sistema manejable.

## Herramientas de prueba (propuestas)

- Typecheck SvelteKit, ESLint y build de producción.
- Vitest para reglas puras y lógica de frontend (si se incorpora).
- Playwright para recorridos críticos y pantallas (si aporta a la etapa).
- Pruebas PostgreSQL/RLS de usuarios autorizados y no autorizados.
- Script determinista de trayectos con coordenadas y tiempo controlado.

## Evidencia para tesis

Registrar en una matriz: código de prueba, objetivo, datos de entrada, resultado esperado, resultado obtenido, duración, fecha, captura/log apropiado y estado. Evitar exponer información real sensible en capturas.
