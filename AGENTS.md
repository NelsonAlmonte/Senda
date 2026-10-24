# Instrucciones para Codex — tesis IoT / PWA

## 0. Alcance de tu trabajo

Trabaja como ingeniero de software responsable de un **MVP académico funcional**, no como diseñador de un ERP para centros geriátricos. Lee `README.md`, los documentos de `docs/` relevantes y, en especial, `docs/09-DECISIONES-PENDIENTES.md` antes de desarrollar.

Implementa **una fase / historia pequeña por solicitud**. No anticipes otros módulos, no agregues dependencias sin justificación y no rediseñes la arquitectura silenciosamente. Si una decisión está marcada como pendiente y **afecta materialmente requisitos, comportamiento, arquitectura, seguridad, costos o dependencias críticas**, presenta alternativas y **espera aprobación antes de implementar esa parte**. Para verificaciones técnicas rutinarias, consulta documentación y realiza pruebas sin interrumpir innecesariamente.

## 1. Stack y límites

- **SvelteKit `@sveltejs/kit@3.1.0` exactamente**, con Svelte 5, TypeScript y Tailwind CSS. Esta versión de SvelteKit es una decisión del equipo, no una opción abierta ni una autorización para retroceder de versión.
- PWA desde el inicio. **Excepción aprobada el 2026-10-21:** usar `vite-plugin-pwa@1.3.0` directamente, porque `@vite-pwa/sveltekit@1.1.0` no declara compatibilidad con SvelteKit 3.1.0. Mantener el adaptador local documentado y probado; no usar `--force`/`--legacy-peer-deps` ni cambiar SvelteKit sin aprobación.
- Renderizado **SSR con `@sveltejs/adapter-netlify@7.0.1`**. Netlify es el destino confirmado; usar funciones Node (`edge: false`) y validar allí la PWA, las cookies, las rutas profundas y el service worker.
- Google Maps JS API con `@googlemaps/js-api-loader`, usando carga dinámica moderna.
- Supabase: Auth, PostgreSQL, Realtime, RLS, funciones SQL/RPC, triggers y cron cuando convenga.
- IoT y simulador por HTTPS; no implementar MQTT por defecto.
- In-app + Web Push únicamente para las notificaciones de alerta.
- Para UI/UX, **usar la skill `ui-ux-pro-max` antes de diseñar interfaces**. Forma parte de las herramientas previstas del entorno Codex en VS Code. Leer sus instrucciones y aplicarlas; si la herramienta no puede invocarse realmente, comunicar el bloqueo sin fingir que se utilizó. Referencia: https://github.com/nextlevelbuilder/ui-ux-pro-max-skill

## 1.1. Herramientas de agente en VS Code (previstas como instaladas)

El desarrollador configura **por su cuenta**, fuera de esta tarea y del repositorio, los MCP/skills de:

- **Svelte oficial** (`sveltejs/ai-tools` / documentación, análisis y recomendaciones de Svelte/SvelteKit).
- **Supabase** (MCP/skills de Supabase para documentación, esquema, SQL, migraciones, Auth y RLS).
- **UI UX Pro Max** (`ui-ux-pro-max`) en tareas de interfaz y UX.

**No intentes instalar, configurar ni actualizar estos MCP/skills por tu cuenta**; úsalos directamente en Codex dentro de VS Code cuando la tarea lo requiera. No añadas su configuración global al repositorio ni secretos de MCP. Si algún servidor o skill no aparece en la sesión, informa exactamente cuál falta y qué parte de la tarea depende de él. No inventes resultados, no afirmes haber usado herramientas inexistentes y no sustituyas silenciosamente esas verificaciones. Puedes seguir con trabajo independiente que no dependa de la herramienta faltante.

Supabase MCP debe estar restringido al proyecto/entorno de **desarrollo**. Distinguir consultas de lectura de operaciones que escriben; **no aplicar SQL remoto, migraciones, cambios de Auth ni despliegues por MCP sin autorización explícita para esa operación y destino**. Preferir migraciones SQL versionadas dentro del repositorio.

## 1.2. Puerta de verificación previa (obligatoria)

Antes de iniciar cada funcionalidad, revisa si requiere **una decisión todavía abierta**, una integración externa o una verificación que afecte el diseño. Resuelve por cuenta propia las comprobaciones documentales/rutinarias con fuentes oficiales, MCP y pruebas locales. Si quedan **alternativas materialmente distintas**, presenta al usuario lo siguiente y detente respecto de esa funcionalidad:

```text
VERIFICACIÓN PREVIA — [funcionalidad]
- Qué se implementará:
- Qué se verificó y qué permanece incierto:
- Alternativa A: ventajas / desventajas
- Alternativa B: ventajas / desventajas
- Recomendación y motivo:
- Impacto en código, seguridad, costo o mantenimiento:
- Decisión concreta que debe tomar el usuario:
```

No pidas aprobación para decisiones triviales ya resueltas en la documentación. No permitas que una verificación de un módulo bloquee innecesariamente tareas independientes. El usuario decidirá las opciones que cambien requisitos, arquitectura, seguridad, costos o compromisos esenciales. Nunca presentar supuestos como decisiones confirmadas.

## 2. Invariantes de dominio

1. `PATIENT` es la entidad central del sistema.
2. `GROUP` solo distingue un contexto administrativo `FAMILY` o `CARE_CENTER`; no construir gestión de turnos, camas, nóminas, habitaciones o facturación.
   Para el MVP inicial, cada grupo usa un único `owner_user_id`; no introducir `group_members` hasta que exista una necesidad aprobada de administración compartida.
3. Un cuidador/familiar ve exclusivamente pacientes autorizados por `patient_access`, aunque pertenezca a un grupo.
4. `ADMIN` y `MONITOR` ven ubicaciones e historial; ambos pueden configurar geocercas. Solo `ADMIN` gestiona invitaciones, accesos y los datos administrativos del paciente.
5. Cada ubicación debe vincularse **a la asignación histórica del dispositivo** para no filtrar recorridos de pacientes anteriores si se reutiliza un equipo.
6. El MVP usa dispositivos simulados y permite representar su registro y asignación dentro del onboarding. El provisioning/claiming/pairing **físico** está aplazado, no eliminado del diseño futuro.
7. Las invitaciones de paciente pasan de `PENDING` a `ACCEPTED` o `DECLINED`; no introducir estado `EXPIRED` contra lo acordado.
8. Geocercas circulares; riesgo y conectividad son estados diferentes; no asumir `NORMAL` sin datos recientes válidos.
9. El motor de alertas se ejecuta del lado confiable del backend para funcionar con la PWA cerrada. El frontend realiza renderizado y validaciones de UX, sin convertirse en fuente autorizada de alertas.
10. Las opciones iniciales de configurar un dispositivo o ingresar un código son acciones, no tipos permanentes de cuenta. Un paciente puede registrarse sin dispositivo y configurarlo después.
11. El código de acceso inicial concede `MONITOR` sobre un paciente concreto. No crea membresía general del grupo ni acceso a otros pacientes.

## 3. Seguridad mínima desde el primer día

- Habilitar RLS sobre las tablas expuestas a la PWA y escribir políticas por usuario/paciente desde sus primeras migraciones.
- Nunca exponer `service_role`, claves VAPID privadas, contraseñas SMTP o secretos de simulación al navegador, al repositorio o a los logs.
- La API key de Google Maps del frontend no es un secreto; debe restringirse por origen y APIs autorizadas.
- No confiar en `patient_id`, `user_id`, `device_id`, coordenadas ni roles enviados desde el cliente como prueba de autorización. Validar en el servidor lo sensible.
- Los formularios validan en cliente por UX; los constraints/RLS y las operaciones sensibles se validan también en backend.
- La simulación manual por click o script debe estar **limitada a un entorno de prueba o usuarios autorizados**. Nunca dejar una ruta pública para falsificar la ubicación de pacientes reales.
- No almacenar ubicación/historial de pacientes en caché PWA indiscriminadamente. No poner información identificable del paciente en payloads de push por defecto.
- Los códigos de acceso compartidos manualmente deben ser de un solo uso, estar asociados a un paciente concreto y validarse en backend. Las invitaciones enviadas por email deben validar además el mismo email verificado, la autorización del invitador y el contexto del paciente.

## 4. Distribución de responsabilidades

- **Frontend:** navegación, UX, formularios, prevalidación, visualización de Google Maps, edición gráfica de geocercas y panel de pruebas.
- **Base de datos/RPC:** integridad, transacciones, autorización de filas, cambios de acceso, procesamiento consistente de posiciones y reglas de alerta cuando resulte apropiado.
- **Edge Function:** solo cuando haga falta ingreso autenticado desde fuera de Supabase, secreto de servidor, integración HTTP externa o envío de Web Push/correos personalizados.
- **Realtime:** refrescar estado del mapa y alertas; los suscriptores siguen sujetos a autorización.

No generar una Edge Function nueva para cada CRUD. Tampoco reemplazar verificaciones server-side con comprobaciones visuales.

## 5. Desarrollo por fases

Seguir `docs/08-PLAN-Y-PRUEBAS.md`. Por cada historia:

1. Resumir las entidades y reglas afectadas.
2. Comprobar decisiones pendientes y evitar trabajo fuera de fase.
3. Implementar cambios mínimos, legibles y compatibles con arquitectura establecida.
4. Añadir migraciones y pruebas pertinentes (incluidas negativas de permisos).
5. Ejecutar lint, typecheck, pruebas y build disponibles; reportar resultados reales.
6. Enumerar archivos modificados, comportamiento verificado y limitaciones.

No declarar una funcionalidad "terminada" si no se probó su flujo de extremo a extremo. No simular resultados de test.

## 6. UI/UX

Aplicar `docs/07-UI-UX.md`: pastel sereno, legibilidad por encima de decoración, mobile-first, accesibilidad, información clínica mínima, mensajes claros, estados vacíos y errores. No usar colores únicamente como significado de riesgo. Tailwind es obligatorio; biblioteca de componentes, tipografía y tokens definitivos pueden ajustarse en la etapa visual.

## 7. Coherencia académica

Las directrices del MVP exigen una demostración **funcional**, no un mockup. La tesis anterior menciona MQTT, mientras la decisión técnica actual es HTTPS. Registrar esa divergencia en `docs/09-DECISIONES-PENDIENTES.md`; no afirmar que se usó una tecnología que no se implementó y no modificar el contenido académico sin petición expresa.

## 8. Flujo Git colaborativo

- Trabajar una historia pequeña por rama, partiendo de `main` actualizado y con el árbol de trabajo revisado.
- Nombrar ramas con un prefijo coherente con el cambio: `feat/`, `fix/`, `docs/`, `refactor/`, `test/` o `chore/`, seguido de una descripción breve en kebab-case.
- No mezclar cambios previos o ajenos con la historia activa. Revisar `git status` y `git diff` antes de editar y antes de cerrar la rama.
- Usar Conventional Commits en inglés con la forma `type(optional-scope): description`; por ejemplo, `feat(patients): add group and patient onboarding`.
- Al terminar la historia, ejecutar las verificaciones disponibles e informar resultados reales. Avisar antes de commit, push, pull, merge, rebase o cambio de rama; Codex puede ejecutar estas operaciones directamente por consola sin pedir una confirmación conversacional adicional. Las autorizaciones técnicas que imponga el entorno no pueden omitirse.
- Preferir un pull request para revisar y fusionar la rama. Después del merge, actualizar `main` antes de crear la siguiente rama.
- Si otra persona o agente trabaja en paralelo, asignar ramas e historias distintas y coordinar explícitamente cualquier archivo compartido o migración para evitar solapamientos.

# La siguiente sección es boilerplate de sveltekit

## Project Configuration

- **Language**: TypeScript
- **Package Manager**: npm
- **Add-ons**: prettier, eslint, tailwindcss, ai-tools

---

You are able to use the Svelte MCP server, where you have access to comprehensive Svelte 5 and SvelteKit documentation. Here's how to use the available tools effectively:

## Available Svelte MCP Tools:

### 1. list-sections

Use this FIRST to discover all available documentation sections. Returns a structured list with titles, use_cases, and paths.
When asked about Svelte or SvelteKit topics, ALWAYS use this tool at the start of the chat to find relevant sections.

### 2. get-documentation

Retrieves full documentation content for specific sections. Accepts single or multiple sections.
After calling the list-sections tool, you MUST analyze the returned documentation sections (especially the use_cases field) and then use the get-documentation tool to fetch ALL documentation sections that are relevant for the user's task.

### 3. svelte-autofixer

Analyzes Svelte code and returns issues and suggestions.
You MUST use this tool whenever writing Svelte code before sending it to the user. Keep calling it until no issues or suggestions are returned.
