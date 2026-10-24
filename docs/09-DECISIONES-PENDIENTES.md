# 09 — Registro de decisiones confirmadas y abiertas

Esta página distingue **acuerdos explícitos** de **recomendaciones** y evita que Codex interprete ejemplos como requisitos definitivos.

## A. Confirmado por el equipo

| Tema                       | Acuerdo                                                                                                                                                                                                                                    |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| UI                         | **SvelteKit `@sveltejs/kit@3.1.0` exactamente**, Svelte 5 + TypeScript + Tailwind CSS                                                                                                                                                      |
| PWA                        | Integración PWA desde el inicio; no cambiar la versión decidida de SvelteKit                                                                                                                                                               |
| Excepción PWA Fase 0       | El 2026-10-21 se aprobó usar `vite-plugin-pwa@1.3.0` directamente porque `@vite-pwa/sveltekit@1.1.0` no declara compatibilidad con SvelteKit 3.1.0. La integración debe validarse con build, manifest y service worker, sin ignorar peers. |
| Renderizado y despliegue   | El 2026-10-21 se confirmó SSR en Netlify y se fijó `@sveltejs/adapter-netlify@7.0.1`, con función Node (`edge: false`) y salida pública `build`. Probar cookies de Auth, rutas profundas, manifest y service worker.           |
| Herramientas Codex VS Code | MCP/skills oficiales de Svelte y de Supabase, y skill `ui-ux-pro-max`: el usuario las instalará aparte y Codex debe utilizarlas cuando estén accesibles, sin gestionar su instalación                                                      |
| Skill de UI                | `ui-ux-pro-max` al diseñar/implementar UI y UX                                                                                                                                                                                             |
| Identidad visual           | Pasteles sobrios, calma, accesibilidad y claridad; mobile-first                                                                                                                                                                            |
| Mapas                      | Google Maps JS API mediante `@googlemaps/js-api-loader`                                                                                                                                                                                    |
| Backend                    | Supabase Auth/PostgreSQL/Realtime/RLS; Edge Functions solo si hacen falta                                                                                                                                                                  |
| Red IoT                    | HTTPS, no MQTT, para la implementación prevista                                                                                                                                                                                            |
| Hardware                   | Compra e integración física posterior; pairing físico pospuesto                                                                                                                                                                            |
| Simulación                 | Click en mapa + script Node.js; persistir/validar en backend, no solo animar                                                                                                                                                               |
| Datos                      | Paciente central; grupos FAMILY/CARE_CENTER como contexto ligero                                                                                                                                                                           |
| Administración de grupos  | Para el MVP cada grupo tendrá un único `owner_user_id`. `group_members` queda aplazado hasta que se apruebe una necesidad real de varios administradores; nunca sustituirá `patient_access`.                                                |
| Permisos                   | `patient_access` por paciente; `ADMIN` y `MONITOR` pueden configurar geocercas                                                                                                                                                             |
| Onboarding                 | Tras crear la cuenta se ofrecen las acciones de configurar dispositivo o ingresar código; no son tipos permanentes de cuenta. El grupo puede ser nuevo o existente y el dispositivo puede configurarse ahora o después.                    |
| Código de acceso           | Código de un solo uso asociado a un paciente concreto; el flujo inicial concede `MONITOR` y no crea membresía general del grupo.                                                                                                         |
| Invitación                 | PENDING → ACCEPTED o DECLINED; sin estado EXPIRED                                                                                                                                                                                          |
| Geofencing                 | Círculos; confirmar salida con dos lecturas válidas y tolerancia de GPS                                                                                                                                                                    |
| Ubicación                  | Cada 30 s inicialmente, configurable; tras 3 min sin datos válidos, STALE                                                                                                                                                                  |
| Notificaciones             | In-app y Web Push, exclusivamente para alertas                                                                                                                                                                                             |
| Seguridad                  | RLS mínimo desde el comienzo; hardening extendido después                                                                                                                                                                                  |
| Fases                      | Implementación incremental por Codex, sin generar módulos no solicitados                                                                                                                                                                   |

## B. Abierto: requiere validación antes de su fase

1. **Compatibilidad de integraciones PWA:** **SvelteKit 3.1.0 ya está decidido y no debe sustituirse unilateralmente**. Se verificó que `@vite-pwa/sveltekit@1.1.0` solo declara peers para SvelteKit 1/2; por aprobación del equipo, Fase 0 usa `vite-plugin-pwa@1.3.0` directamente. Revisar futuras versiones del wrapper antes de reconsiderarlo; no cambiar a SvelteKit 2 ni forzar dependencias.
2. **Alertas:** todavía no se han ratificado umbrales 5/15/30 min, 500/1000 m, precisión GPS aceptable ni margen/histeresis exacto. Solo es seguro afirmar que habrá niveles y reglas basadas en tiempo/distancia.
3. **Geocercas:** una o varias zonas activas por paciente; la propuesta actual soporta múltiples con regla de unión.
4. **Lecturas:** idempotencia, datos retrasados/futuros, saltos físicamente imposibles y confirmación de reingreso.
5. **Invitaciones por email:** el acceso inicial por código ya está definido. Queda decidir cómo enviar correos personalizados con Supabase + Gmail y cómo un ADMIN invalida una invitación PENDING; no crear estado EXPIRED.
6. **Notificaciones:** nivel mínimo de envío Web Push, estrategia antispam/reintento y mecanismo de envío de servidor.
7. **Aspecto visual:** colores definitivos, tipografía y componentes (shadcn-svelte/Lucide son recomendaciones, no confirmaciones explícitas).
8. **Privacidad:** retención de historial, exportación/eliminación de datos y procedimiento de consentimiento/autorización para uso real (en simulaciones, trabajar con datos ficticios).
9. **Hardware real:** modelo exacto comprado, alimentación, modem, SIM, provisioning, autenticación de dispositivo, claim y asignación física.
10. **Métricas objetivo:** fijar criterios cuantitativos para latencia de alertas, errores tolerables y rendimiento con pruebas controladas.

## C. Divergencia con el texto de tesis — requiere conciliación

En la versión aportada de `Proyecto Final.pdf`, el objetivo general y apartados de arquitectura/base teórica mencionan **MQTT**. El equipo posteriormente eligió **HTTPS** para comunicarse con Supabase. Ambos no deben presentarse como si fueran el mismo protocolo, ni se debe declarar haber implementado MQTT sin hacerlo.

**Acción documental pendiente:** al actualizar la tesis, ajustar objetivos y justificación tecnológica con la supervisión académica para reflejar el protocolo realmente implementado; no modificar el archivo del trabajo por cuenta propia.

## D. Fuente de requisitos y evidencia

- `Proyecto Final.pdf`: capítulos I–III; objetivos específicos (1.7), limitaciones (1.5), seguridad/privacidad (2.2.13 y 2.3), delimitación (3.4) y pruebas de funcionalidad (3.2/3.4.4).
- `Desarrollo del MVP.docx`: no basta un mockup; debe haber versión funcional, tecnología real, base de datos y demo ante jurado.
- Acuerdos posteriores de arquitectura: elección Supabase/SvelteKit/HTTPS, modelado paciente-céntrico, notificaciones y simulador.

Estos documentos `.md` son un **punto de partida operativo**, no un sustituto del documento académico ni una decisión unilateral sobre los pendientes.

## E. Estado temporal del entorno de desarrollo

- **Confirmación de correo:** el 2026-10-24 se desactivó temporalmente en Supabase de desarrollo porque el enlace de confirmación no funcionó. El registro sin confirmación se validó manualmente, pero esto no modifica el requisito de usar correo verificado para invitaciones. Resolver y volver a probar la confirmación antes de Fase 5 y antes de considerar Auth validado para despliegue.
- **Flujo Git:** cada historia se desarrolla en una rama `feat/`, `fix/`, `docs/`, `refactor/`, `test/` o `chore/`; los commits siguen Conventional Commits y las operaciones de commit/push/pull/merge/rebase se coordinan con el responsable del repositorio. El detalle operativo está en `AGENTS.md` y `docs/08-PLAN-Y-PRUEBAS.md`.
- **Supabase de desarrollo:** el 2026-10-24 se aplicaron las migraciones de perfiles y onboarding de pacientes. La suite RLS pasa 22 casos y la creación de grupo + paciente fue validada manualmente desde la PWA. El hardening adicional del asesor de seguridad queda como trabajo posterior y no bloquea el MVP.
