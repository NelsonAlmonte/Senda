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

### Fase 2 — Dispositivo simulado e ingestión

- `devices`, `device_assignments`, `locations` con referencia **histórica** a la asignación.
- Onboarding con dos acciones no excluyentes: configurar un dispositivo o ingresar un código de acceso a un paciente.
- Permitir configurar el dispositivo ahora o después del alta. El dashboard debe mostrar el estado **Sin dispositivo configurado** y permitir retomar la asignación.
- Reutilizar un grupo existente al registrar pacientes o dispositivos adicionales; no crear un nuevo centro/familia obligatoriamente.
- Código de un solo uso asociado a un paciente y rol `MONITOR`; no crear `group_members` ni heredar acceso al grupo.
- Endpoint/RPC autorizada para simulación de posiciones.
- Click en Google Maps y script Node.js con rutas; ambos usan procesamiento compartido.

**Aceptación:** un paciente puede quedar sin dispositivo y retomar la configuración; un código concede acceso únicamente al paciente correcto; los movimientos se guardan y no pueden falsificarse por usuarios no autorizados.

**Estado completado (2026-10-25, historias 2A–2E):** implementados `devices`, `device_assignments`, la regla de un dispositivo activo por paciente, tres seriales demo preexistentes y la RPC de asignación restringida a `ADMIN`. El alta guiada separa grupo, paciente y dispositivo; permite crear un grupo con su primer paciente, reutilizar un grupo propio, configurar ahora o después y retomar la configuración desde el dashboard. El registro redirige al selector entre registrar y monitorear; un `ADMIN` puede generar un código manual de un solo uso y otra cuenta puede revisarlo y obtener `MONITOR` exclusivamente sobre ese paciente. La ingestión idempotente de ubicaciones vinculadas a la asignación histórica ya está aplicada en Supabase de desarrollo, con lectura para `ADMIN`/`MONITOR` y escritura simulada limitada a `ADMIN`. Existen un emisor Node de una lectura, una ruta ficticia determinista de 12 puntos y simulación manual desde el mapa. Esta última requiere una bandera privada de entorno, muestra una selección provisional y persiste con origen `MANUAL` por la misma RPC antes de que Realtime actualice la ubicación oficial. El usuario validó los tres mecanismos de simulación contra Supabase de desarrollo; la suite pgTAP pasa 39 casos y las suites anteriores continúan pasando 25, 23 y 17 casos. La Fase 2 queda completada.

### Fase 3 — Mapa e historial

- Último punto válido, horario de última actualización, trazado histórico y Realtime.
- Estados sin dispositivo, sin datos y datos obsoletos.

**Aceptación:** segundo navegador autorizado ve coordenadas nuevas sin recargar; dispositivo reutilizado no filtra recorridos anteriores.

**Estado completado (2026-10-25, historias 3A–3C):** `/patients/:id/map` presenta la última posición autorizada mediante Google Maps, con marcador, precisión opcional, timestamp y estados sin dispositivo, sin lectura, desactualizado y error. Postgres Changes está habilitado sobre `locations`; la PWA reutiliza la sesión SSR, filtra por la asignación histórica y actualiza el punto más reciente sin recargar, con estado visible de conexión. La historia 3C añade la consulta de las 200 lecturas más recientes del paciente, un resumen textual y trazos separados por `device_assignment_id`; Realtime añade lecturas nuevas al recorrido sin reconstruir el mapa. La política RLS continúa autorizando por paciente y la suite pgTAP de ubicaciones pasa 39 casos. El usuario validó manualmente Realtime con cuentas `ADMIN` y `MONITOR`, el historial persistente y el movimiento del marcador; el aislamiento al reutilizar dispositivos está cubierto por pgTAP. La Fase 3 queda completada.

### Fase 4 — Geocercas y motor de alertas

- `safe_zones`, episodios `alert_episodes`, validación de lecturas, confirmación de salida y reingreso.
- Severidad y conectividad separadas; cron/funciones SQL donde se necesiten.
- Escenarios automáticos con tiempo de simulación controlado.

**Aceptación:** superar casos R01–R19 aplicables, tras ratificar umbrales abiertos.

### Fase 5 — Compartición e invitaciones

- Extender el código inicial con invitación por email y enlace, manteniendo `PENDING`, aceptar/rechazar y revocación de `patient_access`.
- Integración de correo con configuración Supabase Auth/Gmail y mecanismo específico de emails de paciente.

**Aceptación:** email y token correctos permiten acceso; email erróneo/token reutilizado/usuario sin permiso no.

### Fase 6 — Notificaciones Web Push y PWA completa

- Pedir permiso, guardar suscripciones, enviar push desde backend ante cambio de episodio.
- Validar plugin PWA con `injectManifest`/custom SW si se requiere para evento push.
- Probar en navegadores/OS de interés, incluido iPhone instalado en pantalla de inicio cuando haya acceso al dispositivo.

**Aceptación:** alerta llega a usuarios autorizados incluso con PWA cerrada en entorno compatible; fallo de push no borra alerta.

### Fase 7 — Calidad, evidencia y demo

- Pruebas integrales de permisos y casos límite; UX y accesibilidad; registro de métricas y documentación.
- Preparar demo con ruta dentro/fuera, escaladas, retorno, historial, cambios de geocerca e invitación.
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
