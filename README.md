# Senda — Plataforma IoT de monitoreo y alerta temprana

> **Estado:** Fase 0 implementada el 2026-10-21. La base técnica y la PWA mínima están disponibles; autenticación, pacientes, mapas, alertas y demás fases funcionales aún no están implementados.

## Propósito

Construir y evaluar un MVP funcional de una plataforma de geolocalización, monitoreo preventivo y alerta temprana para personas con Alzheimer y deterioro cognitivo. La PWA es una herramienta de apoyo para familiares y cuidadores, no un dispositivo médico ni una garantía de prevención de incidentes.

El documento académico de referencia es **`Proyecto Final.pdf`** (capítulos I–III en la copia revisada) y las instrucciones de la asignatura son **`Desarrollo del MVP.docx`**. Estas especificaciones reflejan además las decisiones técnicas posteriores tomadas durante la planificación; donde existe divergencia, está documentada en `docs/09-DECISIONES-PENDIENTES.md`.

## Stack elegido

- **PWA:** **SvelteKit `@sveltejs/kit@3.1.0` exactamente**, Svelte 5, TypeScript y Tailwind CSS.
- **PWA plugin:** `vite-plugin-pwa@1.3.0` integrado directamente. Es la excepción aprobada para SvelteKit 3.1.0 porque `@vite-pwa/sveltekit@1.1.0` no declara un peer compatible; consultar `docs/09-DECISIONES-PENDIENTES.md`.
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

## Desarrollo local

Requisitos: Node.js 22.17 o superior y npm.

```sh
npm install
cp .env.example .env
npm run dev
```

La portada y el build funcionan sin credenciales reales. Las variables públicas de Supabase y Google Maps se validarán cuando sus funcionalidades se incorporen. Nunca colocar `service_role`, contraseñas, claves VAPID privadas ni secretos de simulación en variables `PUBLIC_*`.

Comandos de verificación:

```sh
npm run check
npm run lint
npm run build
npm run preview
```

El adaptador permanece en `adapter-auto`; Netlify es un destino probable, pero la elección definitiva entre SSR y SPA estática continúa abierta y debe validarse antes del despliegue.
