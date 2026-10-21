# 08 — Implementación incremental y pruebas

## Regla de trabajo

Cada fase se entrega con: funcionalidad visible, cambios SQL en migraciones, permisos adecuados, casos de prueba y reporte de resultados reales. Codex no debe empezar fases posteriores sin solicitud. Esta secuencia prioriza un MVP tangible, pero sin abrir datos sensibles durante el desarrollo.

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

### Fase 2 — Dispositivo simulado e ingestión

- `devices`, `device_assignments`, `locations` con referencia **histórica** a la asignación.
- Endpoint/RPC autorizada para simulación de posiciones.
- Click en Google Maps y script Node.js con rutas; ambos usan procesamiento compartido.

**Aceptación:** movimientos se guardan, se ven en mapa y no pueden falsificarse por usuarios no autorizados.

### Fase 3 — Mapa e historial

- Último punto válido, horario de última actualización, trazado histórico y Realtime.
- Estados sin dispositivo, sin datos y datos obsoletos.

**Aceptación:** segundo navegador autorizado ve coordenadas nuevas sin recargar; dispositivo reutilizado no filtra recorridos anteriores.

### Fase 4 — Geocercas y motor de alertas

- `safe_zones`, episodios `alert_episodes`, validación de lecturas, confirmación de salida y reingreso.
- Severidad y conectividad separadas; cron/funciones SQL donde se necesiten.
- Escenarios automáticos con tiempo de simulación controlado.

**Aceptación:** superar casos R01–R19 aplicables, tras ratificar umbrales abiertos.

### Fase 5 — Compartición e invitaciones

- `invitations`, invitación PENDING, aceptar/rechazar y revocación de `patient_access`.
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
