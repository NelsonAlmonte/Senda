# Senda — Plataforma IoT de monitoreo y alerta temprana

> **Estado:** Fases 0–3 implementadas y los simuladores de una lectura, ruta y selección manual en mapa validados. La autenticación/perfil, el alta guiada de grupos y pacientes, la asignación de un dispositivo simulado, el acceso `MONITOR` mediante código, la ingestión segura de ubicaciones simuladas y el mapa con historial y actualización Realtime están implementados. El historial presenta hasta 200 lecturas autorizadas separadas por asignación histórica; el usuario validó que el marcador y el recorrido se actualizan sin reconstruir el mapa. El simulador Node reproduce una ruta ficticia persistiendo cada punto y su ejecución completa fue validada manualmente. La simulación manual está limitada a `ADMIN`, se habilita mediante una variable privada de entorno y persiste por la misma RPC; el usuario validó su selección, confirmación, persistencia y actualización en el mapa. Las suites pgTAP pasan 25 casos para pacientes, 23 para dispositivos, 17 para códigos de acceso, 39 para ubicaciones y 29 para geocercas. Las historias 4A–4D están implementadas y validadas manualmente: múltiples geocercas, clasificación backend por lectura, episodios confirmados por salida/reingreso y visualización Realtime de episodios activos en el dashboard. La migración de episodios está aplicada en Supabase de desarrollo y sus 55 pruebas pgTAP pasan. La historia 6A de suscripción Web Push está implementada y validada manualmente; su migración está aplicada en desarrollo y sus 29 pruebas pgTAP pasan. La historia 6B de entrega backend está desplegada y validada de extremo a extremo en Chrome sobre Windows con la PWA cerrada: Database Webhook, Edge Function, notificación genérica urgente y apertura de `/dashboard` al pulsarla. Sus 14 pruebas pgTAP y la integración `pg_net` → Edge Function pasan. Vivaldi mostró la notificación, pero no reabrió la PWA y no se considera navegador de referencia para el MVP. La administración de pacientes está implementada y validada: `/patients/:id` reúne resumen y navegación, `ADMIN` puede editar nombre y apellido, consultar accesos y revocar `MONITOR`, y la revocación conserva auditoría mediante `revoked_at`. La migración está aplicada en Supabase de desarrollo, sus 32 pruebas pgTAP pasan con rollback y el usuario validó manualmente el flujo completo. El MVP no incorporará niveles `MEDIUM/HIGH/CRITICAL`, escaladas temporales ni condiciones combinadas de tiempo y distancia; quedan como ampliación opcional posterior.

> **Reorganización UI local (2026-10-28, pendiente de validación manual):** el área autenticada se divide en **Pacientes**, **Alertas** y **Perfil**. En escritorio usa un sidebar oscuro flotante con separación de los cuatro bordes y cierre de sesión al fondo; en móvil usa una barra inferior flotante inspirada en Material 3, redondeada, con indicador ovalado detrás del icono activo y etiquetas visibles. Un header translúcido centraliza el título compacto de cada ruta, los nombres dinámicos de pacientes y la flecha de retorno; sus botones son circulares y cuenta con padding horizontal propio. En rutas principales el título recibe un margen inicial pequeño; en subrutas ese margen desaparece y se muestra la flecha real. También ofrece accesos directos a Alertas y Perfil: la campana muestra un punto rojo, acompañado por una etiqueta accesible, cuando RLS permite consultar al menos un episodio `OPEN`, y se actualiza mediante Realtime. El contenido no usa sombras; únicamente el header móvil y la barra inferior usan `shadow-sm`, y se prefiere la escala estándar de Tailwind. `/dashboard` solo conserva **Hola, USUARIO.**; `/patients` recibe la lista y operaciones; `/alerts` muestra los episodios globales con activos primero. El service worker y la Edge Function `send-geofence-alert` versión 2 apuntan las notificaciones a `/alerts`. La función fue desplegada en Supabase de desarrollo y respondió correctamente en la prueba de arranque; queda pendiente validar el recorrido extremo a extremo con una alerta real y el clic de la notificación.

## Propósito

Construir y evaluar un MVP funcional de una plataforma de geolocalización, monitoreo preventivo y alerta temprana para personas con Alzheimer y deterioro cognitivo. La PWA es una herramienta de apoyo para familiares y cuidadores, no un dispositivo médico ni una garantía de prevención de incidentes.

El documento académico de referencia es **`Proyecto Final.pdf`** (capítulos I–III en la copia revisada) y las instrucciones de la asignatura son **`Desarrollo del MVP.docx`**. Estas especificaciones reflejan además las decisiones técnicas posteriores tomadas durante la planificación; donde existe divergencia, está documentada en `docs/09-DECISIONES-PENDIENTES.md`.

## Stack elegido

- **PWA:** **SvelteKit `@sveltejs/kit@3.1.0` exactamente**, Svelte 5, TypeScript y Tailwind CSS.
- **PWA plugin:** `vite-plugin-pwa@1.3.0` integrado directamente. Es la excepción aprobada para SvelteKit 3.1.0 porque `@vite-pwa/sveltekit@1.1.0` no declara un peer compatible; consultar `docs/09-DECISIONES-PENDIENTES.md`.
- **Renderizado y despliegue:** SSR con `@sveltejs/adapter-netlify@7.0.1`, funciones Node y directorio público `build`.
- **Herramientas para Codex en VS Code:** MCP/skills de **Svelte oficial** y **Supabase**, y skill **UI UX Pro Max** para interfaz. Se consideran previstas en el entorno de desarrollo; el equipo las instala/configura aparte, no Codex ni la aplicación.
- **Diseño:** usar **UI UX Pro Max** durante trabajos de interfaz y experiencia de usuario; identidad serena, pastel, accesible y mobile-first. La navegación usa `@lucide/svelte@1.63.0`; shadcn-svelte queda aplazado hasta que exista un componente que justifique incorporarlo.
- **Mapa:** Google Maps JavaScript API mediante `@googlemaps/js-api-loader`.
- **Backend:** Supabase Auth, PostgreSQL, Realtime, políticas RLS y recursos nativos de BD (funciones RPC, triggers y cron cuando aporten valor).
- **IoT / simulación:** ingreso de ubicaciones por **HTTPS**. El hardware y el pairing físico quedan para una fase posterior.
- **Alertas al usuario:** dentro de la app y Web Push.
- **Correo:** Supabase Auth con SMTP Gmail configurado por el equipo; el mecanismo de envío de emails personalizados de acceso a pacientes se define en su etapa.

## Lectura recomendada para Codex

1. `AGENTS.md` — instrucciones de trabajo y prohibiciones.
2. `docs/01-ALCANCE-MVP.md` — qué se construye y qué no.
3. `docs/02-ARQUITECTURA.md` — responsabilidades y flujos técnicos.
4. `docs/03-MODELO-DATOS.md` — entidades, asociaciones y restricciones.
5. `docs/04-PERMISOS-Y-SEGURIDAD.md` — autorización y RLS.
6. `docs/05-FLUJOS-Y-PANTALLAS.md` — recorridos de usuario y rutas.
7. `docs/06-MONITOREO-Y-ALERTAS.md` — funcionamiento y casos límite.
8. `docs/07-UI-UX.md` — lineamientos de interfaz.
9. `docs/08-PLAN-Y-PRUEBAS.md` — fases y criterios de aceptación.
10. `docs/09-DECISIONES-PENDIENTES.md` — supuestos y asuntos sin cerrar.

## Principio del sistema

```text
GROUP (FAMILY | CARE_CENTER)
   └── PATIENT
         ├── DEVICE_ASSIGNMENT ── DEVICE
         │        └── LOCATIONS (asociadas a la asignación histórica)
         ├── PATIENT_ACCESS ────── USER
         ├── SAFE_ZONES
         └── ALERT_EPISODES
```

**La pertenencia a un grupo NO autoriza automáticamente a ver las ubicaciones de todos sus pacientes.** La visibilidad privada se obtiene por `patient_access`.

## Flujo de producto acordado

Después de crear su cuenta, el usuario puede iniciar dos acciones sin quedar limitado a un tipo permanente de cuenta:

1. **Configurar un dispositivo:** recorre una sola pantalla guiada en tres pasos: crear o seleccionar un contexto `FAMILY`/`CARE_CENTER`, registrar al paciente y configurar el dispositivo simulado ahora o después. Con la alternativa simple aprobada, un grupo nuevo se guarda junto con su primer paciente, no como registro vacío independiente. Si el dispositivo se aplaza, el paciente queda disponible en `/patients` con el estado explícito **Sin dispositivo configurado** y una acción **Configurar ahora**.
2. **Ingresar un código de acceso:** canjea un código de un solo uso que concede `MONITOR` exclusivamente sobre el paciente asociado. No convierte al usuario en miembro general del grupo.

Un grupo puede contener varios pacientes. El módulo `/patients` ofrece acciones separadas para **Agregar paciente**, **Crear grupo** e **Ingresar código**; las dos primeras abren el mismo registro guiado con el modo correspondiente preseleccionado. Al registrar pacientes adicionales se puede reutilizar un grupo existente. Trabajar o colaborar con un centro nunca concede por sí solo acceso a todos sus pacientes.

La historia inicial de dispositivos usa un único equipo activo por paciente y seriales simulados preexistentes (`SENDA-DEMO-001` a `SENDA-DEMO-003`). Estos seriales son datos públicos de demostración, no credenciales. Solo un `ADMIN` del paciente puede realizar la asignación.

La configuración de geocercas usa `/patients/:id/safe-zones`. `ADMIN` y `MONITOR` pueden mantener múltiples círculos activos: estar dentro de cualquiera equivale a estar dentro de un área permitida. El radio permitido es 50–5,000 m, con 250 m iniciales. Las zonas activas se muestran también en `/patients/:id/map` como contexto del monitoreo; las inactivas y archivadas no aparecen allí. Las zonas se pueden desactivar o archivar, pero no se borran físicamente.

Cada ubicación nueva se clasifica en backend contra las zonas activas del momento como `INSIDE`, `OUTSIDE`, `UNCERTAIN` o `NO_ACTIVE_ZONE`. El margen efectivo es el mayor entre `accuracy_m` y 25 m; una lectura cuenta como `INSIDE` si su incertidumbre cabe dentro de al menos una zona, y como `UNCERTAIN` si alcanza un perímetro. Esta clasificación aislada se muestra con texto en el mapa y **no equivale a una alerta confirmada**. Las lecturas anteriores a la migración permanecen `NOT_EVALUATED`; los episodios y la regla de dos lecturas fuera corresponden a la siguiente historia.

El motor básico de episodios procesa lecturas en orden cronológico por asignación. Dos `OUTSIDE` consecutivas con `accuracy_m` nulo o de hasta 100 m abren un único episodio `OPEN`; dos `INSIDE` con el mismo criterio lo cambian a `RESOLVED`. `UNCERTAIN`, `NO_ACTIVE_ZONE` y una precisión peor de 100 m interrumpen la pareja confirmatoria. Las lecturas atrasadas se guardan, pero no retroceden el estado actual. Los episodios no almacenan ni presentan niveles de riesgo dentro del MVP.

## Desarrollo local

Requisitos: Node.js 22.17 o superior y npm.

```sh
npm install
cp .env.example .env
npm run dev
```

La portada y el build funcionan sin credenciales reales. Sin Supabase configurado, las pantallas de acceso se muestran deshabilitadas y las acciones rechazan solicitudes con `503`. `PUBLIC_VAPID_PUBLIC_KEY` contiene únicamente la clave pública URL-safe necesaria para registrar Web Push en el navegador. Nunca colocar `service_role`, contraseñas, claves VAPID privadas ni secretos de simulación en variables `PUBLIC_*`.

Para generar un par VAPID de desarrollo sin guardarlo automáticamente, ejecuta `npm run generate:vapid-keys`. Copia `PUBLIC_VAPID_PUBLIC_KEY` a `.env` y conserva `SENDA_VAPID_PRIVATE_KEY` únicamente como variable privada del backend. `SENDA_VAPID_SUBJECT` identifica al responsable mediante una URL `https:` o un correo `mailto:`. No publiques ninguna clave privada en Git.

La entrega backend usa además un secreto compartido aleatorio. Genéralo con `npm run generate:webhook-secret`; el valor de `SENDA_WEBHOOK_SECRET` debe coincidir en Supabase Vault y Edge Function Secrets. La Edge Function también recibe allí las variables VAPID. El archivo `supabase/functions/.env` se usa solo para desarrollo local y está ignorado por Git; `supabase/functions/.env.example` documenta sus nombres.

### Configuración de Supabase Auth

Esta historia utiliza exclusivamente la URL y la publishable key públicas del proyecto de **desarrollo**:

```dotenv
PUBLIC_SUPABASE_URL=https://<project-ref>.supabase.co
PUBLIC_SUPABASE_PUBLISHABLE_KEY=<publishable-key>
```

Antes de probar el flujo integral:

1. Revisar y aplicar al proyecto de desarrollo `supabase/migrations/20261021171855_auth_profiles.sql`. Codex no aplica SQL remoto sin autorización explícita.
2. En Supabase Auth, configurar el `Site URL` y las Redirect URLs para el origen local y el de Netlify.
3. Cambiar el enlace de la plantilla **Confirm signup** por:

   ```text
   {{ .SiteURL }}/auth/confirm?token_hash={{ .TokenHash }}&type=email
   ```

El alta crea el perfil mínimo mediante un trigger; RLS permite a cada usuario autenticado leer y actualizar únicamente su propia fila. Las sesiones se gestionan en SSR mediante cookies HTTP y las rutas `/dashboard`, `/patients`, `/alerts` y `/settings` exigen una identidad validada.

> **Estado temporal de desarrollo (2026-10-24):** la confirmación de correo está desactivada en Supabase porque el enlace de confirmación todavía no funciona en el entorno actual. Esto permite probar el alta inicial y el código compartido manualmente, pero no elimina el requisito de correo verificado: debe resolverse antes de implementar invitaciones por email o preparar una demostración/despliegue definitivo.

### Flujo Git del equipo

Cada historia se desarrolla en una rama independiente con nombres como `feat/patient-onboarding` o `fix/auth-redirect`. Antes de empezar se revisan `git status` y los cambios existentes para evitar mezclar trabajo ajeno. Los commits siguen Conventional Commits, por ejemplo:

```text
feat(patients): add group and patient onboarding
```

Después de verificar la historia se realiza commit y push de su rama. Codex no ejecuta `git add`, commit, push, pull, merge, rebase ni cambios de rama hasta que el usuario lo indique explícitamente; cuando lo indique, puede hacerlo directamente por consola. El cierre predeterminado es actualizar `main`, fusionar directamente la rama terminada y publicar `main`; usar pull request solo si el usuario lo pide. Una autorización técnica del entorno puede seguir apareciendo si la plataforma la exige. No iniciar otra historia en la misma rama ni mezclar cambios ajenos.

Comandos de verificación:

```sh
npm run check
npm run lint
npm run build
npm run preview
```

El proyecto usa SSR con el adaptador oficial de Netlify. El build genera los activos públicos en `build` y la función SSR en `.netlify/functions-internal`; en el despliegue se validarán las rutas profundas, la sesión por cookies, el manifest y el service worker.

### Instalación de la PWA

En Chrome y otros navegadores Chromium compatibles, Senda muestra **Instalar Senda** cuando el navegador confirma que la aplicación cumple sus criterios de instalación. El botón abre el diálogo nativo; no instala automáticamente ni puede evitar la confirmación del usuario. En iPhone/iPad, Senda muestra una guía para abrir la página en Safari y usar **Compartir → Añadir a pantalla de inicio** y **Abrir como app** cuando la opción esté disponible; en Safari para macOS Sonoma 14 o posterior indica **Archivo → Añadir al Dock**. La promoción no aparece al ejecutar Senda como PWA instalada. **Ahora no** oculta el aviso durante la navegación actual, pero permite que vuelva a aparecer después de una recarga completa; no guarda un rechazo permanente.

### Simulador de ubicaciones

Tras aplicar la migración de ingestión en Supabase de desarrollo, configura en `.env` una cuenta ficticia que tenga acceso `ADMIN` al paciente:

```dotenv
SENDA_SIMULATOR_EMAIL=simulator-admin@example.test
SENDA_SIMULATOR_PASSWORD=development-only-password
SENDA_ENABLE_MANUAL_LOCATION_SIMULATOR=true
```

Envía una lectura indicando el UUID del paciente, coordenadas y precisión opcional en metros:

```sh
npm run simulate:location -- <patient-id> 18.4861 -69.9312 8.5
```

El script inicia sesión con Supabase Auth y llama la RPC autorizada. No usa `service_role`; una cuenta `MONITOR`, un paciente ajeno o un paciente sin dispositivo simulado activo son rechazados.

Reproduce la ruta ficticia incluida enviando una lectura cada 30 segundos:

```sh
npm run simulate:route -- <patient-id>
```

Para una demostración acelerada, indica el intervalo en milisegundos:

```sh
npm run simulate:route -- <patient-id> 2000
```

La ruta contiene 12 puntos y se ejecuta una sola vez. Cada punto pasa por la misma RPC y queda persistido; usa `Ctrl+C` para detener la reproducción de forma controlada.

Para comprobar Realtime, abre `/patients/<patient-id>/map` con una cuenta autorizada y espera el estado **Actualizaciones automáticas activas**. Ejecuta de nuevo el simulador con coordenadas distintas sin recargar la página. El marcador, las coordenadas, la hora y la precisión deben actualizarse automáticamente. Un segundo navegador autenticado como `MONITOR` del mismo paciente debe recibir la misma lectura; un usuario sin `patient_access` no puede abrir el mapa ni recibir sus filas por Postgres Changes.

El historial del mapa consulta como máximo las 200 lecturas más recientes del paciente y las ordena por fecha de captura. Las lecturas de asignaciones distintas se dibujan como trazos separados para no crear un recorrido falso al cambiar de dispositivo. Una lectura nueva recibida por Realtime se añade al resumen y al trazo sin recargar la página.

Con `SENDA_ENABLE_MANUAL_LOCATION_SIMULATOR=true`, una cuenta con acceso `ADMIN` y un dispositivo simulado activo verá **Modo de prueba** en `/patients/<patient-id>/map`. Activa la selección, toca o haz clic en el mapa —o escribe coordenadas válidas— y confirma. El marcador amarillo es únicamente una vista previa; el punto oficial cambia cuando la RPC persiste la lectura `MANUAL` y Realtime la entrega. `MONITOR` no ve este control. Mantén la variable en `false` o sin definir fuera de entornos de prueba.
