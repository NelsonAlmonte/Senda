# Senda — Plataforma IoT de monitoreo y alerta temprana

> **Estado:** Fases 0–3 validadas. La autenticación/perfil, el alta guiada de grupos y pacientes, la asignación de un dispositivo simulado, el acceso `MONITOR` mediante código, la ingestión segura de ubicaciones simuladas y el mapa con historial y actualización Realtime están implementados. El historial presenta hasta 200 lecturas autorizadas separadas por asignación histórica; el usuario validó que el marcador y el recorrido se actualizan sin reconstruir el mapa. Las suites pgTAP pasan 25 casos para pacientes, 23 para dispositivos, 17 para códigos de acceso y 39 para ubicaciones. Las geocercas y las alertas aún no están implementadas.

## Propósito

Construir y evaluar un MVP funcional de una plataforma de geolocalización, monitoreo preventivo y alerta temprana para personas con Alzheimer y deterioro cognitivo. La PWA es una herramienta de apoyo para familiares y cuidadores, no un dispositivo médico ni una garantía de prevención de incidentes.

El documento académico de referencia es **`Proyecto Final.pdf`** (capítulos I–III en la copia revisada) y las instrucciones de la asignatura son **`Desarrollo del MVP.docx`**. Estas especificaciones reflejan además las decisiones técnicas posteriores tomadas durante la planificación; donde existe divergencia, está documentada en `docs/09-DECISIONES-PENDIENTES.md`.

## Stack elegido

- **PWA:** **SvelteKit `@sveltejs/kit@3.1.0` exactamente**, Svelte 5, TypeScript y Tailwind CSS.
- **PWA plugin:** `vite-plugin-pwa@1.3.0` integrado directamente. Es la excepción aprobada para SvelteKit 3.1.0 porque `@vite-pwa/sveltekit@1.1.0` no declara un peer compatible; consultar `docs/09-DECISIONES-PENDIENTES.md`.
- **Renderizado y despliegue:** SSR con `@sveltejs/adapter-netlify@7.0.1`, funciones Node y directorio público `build`.
- **Herramientas para Codex en VS Code:** MCP/skills de **Svelte oficial** y **Supabase**, y skill **UI UX Pro Max** para interfaz. Se consideran previstas en el entorno de desarrollo; el equipo las instala/configura aparte, no Codex ni la aplicación.
- **Diseño:** usar **UI UX Pro Max** durante trabajos de interfaz y experiencia de usuario; identidad serena, pastel, accesible y mobile-first.
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

1. **Configurar un dispositivo:** recorre una sola pantalla guiada en tres pasos: crear o seleccionar un contexto `FAMILY`/`CARE_CENTER`, registrar al paciente y configurar el dispositivo simulado ahora o después. Con la alternativa simple aprobada, un grupo nuevo se guarda junto con su primer paciente, no como registro vacío independiente. Si el dispositivo se aplaza, el paciente queda disponible en el dashboard con el estado explícito **Sin dispositivo configurado** y una acción **Configurar ahora**.
2. **Ingresar un código de acceso:** canjea un código de un solo uso que concede `MONITOR` exclusivamente sobre el paciente asociado. No convierte al usuario en miembro general del grupo.

Un grupo puede contener varios pacientes. El dashboard ofrece acciones separadas para **Agregar paciente**, **Crear grupo** e **Ingresar código**; las dos primeras abren el mismo registro guiado con el modo correspondiente preseleccionado. Al registrar pacientes adicionales se puede reutilizar un grupo existente. Trabajar o colaborar con un centro nunca concede por sí solo acceso a todos sus pacientes.

La historia inicial de dispositivos usa un único equipo activo por paciente y seriales simulados preexistentes (`SENDA-DEMO-001` a `SENDA-DEMO-003`). Estos seriales son datos públicos de demostración, no credenciales. Solo un `ADMIN` del paciente puede realizar la asignación.

## Desarrollo local

Requisitos: Node.js 22.17 o superior y npm.

```sh
npm install
cp .env.example .env
npm run dev
```

La portada y el build funcionan sin credenciales reales. Sin Supabase configurado, las pantallas de acceso se muestran deshabilitadas y las acciones rechazan solicitudes con `503`. Nunca colocar `service_role`, contraseñas, claves VAPID privadas ni secretos de simulación en variables `PUBLIC_*`.

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

El alta crea el perfil mínimo mediante un trigger; RLS permite a cada usuario autenticado leer y actualizar únicamente su propia fila. Las sesiones se gestionan en SSR mediante cookies HTTP y las rutas `/dashboard` y `/settings` exigen una identidad validada.

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

### Simulador de ubicaciones

Tras aplicar la migración de ingestión en Supabase de desarrollo, configura en `.env` una cuenta ficticia que tenga acceso `ADMIN` al paciente:

```dotenv
SENDA_SIMULATOR_EMAIL=simulator-admin@example.test
SENDA_SIMULATOR_PASSWORD=development-only-password
```

Envía una lectura indicando el UUID del paciente, coordenadas y precisión opcional en metros:

```sh
npm run simulate:location -- <patient-id> 18.4861 -69.9312 8.5
```

El script inicia sesión con Supabase Auth y llama la RPC autorizada. No usa `service_role`; una cuenta `MONITOR`, un paciente ajeno o un paciente sin dispositivo simulado activo son rechazados.

Para comprobar Realtime, abre `/patients/<patient-id>/map` con una cuenta autorizada y espera el estado **Actualizaciones automáticas activas**. Ejecuta de nuevo el simulador con coordenadas distintas sin recargar la página. El marcador, las coordenadas, la hora y la precisión deben actualizarse automáticamente. Un segundo navegador autenticado como `MONITOR` del mismo paciente debe recibir la misma lectura; un usuario sin `patient_access` no puede abrir el mapa ni recibir sus filas por Postgres Changes.

El historial del mapa consulta como máximo las 200 lecturas más recientes del paciente y las ordena por fecha de captura. Las lecturas de asignaciones distintas se dibujan como trazos separados para no crear un recorrido falso al cambiar de dispositivo. Una lectura nueva recibida por Realtime se añade al resumen y al trazo sin recargar la página.
