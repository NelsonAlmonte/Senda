# 02 — Arquitectura y límites de responsabilidad

## Componentes

```text
                  ┌───────────────────────────┐
                  │ SvelteKit 3.1.0 PWA       │
                  │ TypeScript + Tailwind      │
                  │ Google Maps + PWA plugin   │
                  └─────────────┬─────────────┘
                                │ Auth / consultas permitidas / Realtime
                                ▼
┌──────────────────────────────────────────────────────────────────┐
│ Supabase                                                         │
│                                                                  │
│ Auth       PostgreSQL + RLS       Realtime                        │
│              ├── RPC / funciones SQL                             │
│              ├── triggers (cuando aporten valor)                 │
│              └── cron para inactividad                           │
│                                                                  │
│ Edge Functions solo para necesidades concretas de backend        │
│ (p. ej., secretos, push/correo o entrada IoT externa)             │
└──────────────────────────────────────────────────────────────────┘
                                ▲
                                │ HTTPS
                  ┌─────────────┴──────────────┐
                  │ Simulación MVP            │
                  │ • Click en Google Maps     │
                  │ • Script Node.js de rutas  │
                  │ Hardware físico: posterior │
                  └────────────────────────────┘
```

## Frontend: lo que se resuelve en SvelteKit

- Formularios, navegación, layouts, estados vacíos, carga y errores.
- Prevalidaciones (email válido, radio positivo, coordenadas completas, límites de campo).
- Inicialización y actualización de Google Maps; dibujo y previsualización de geocercas.
- Visualización de indicadores, nivel de riesgo calculado por backend y última transmisión.
- Realtime y manejo del ciclo de suscripciones mientras el usuario navega.
- Interacción del modo simulación manual **solo si está expresamente habilitado** para pruebas.

## Backend: lo que necesita autoridad o funcionamiento sin PWA abierta

- Integridad referencial, operaciones atómicas e invariantes de asignaciones.
- Comprobación final de acceso a pacientes, geocercas, invitaciones y ubicación mediante RLS/RPC.
- Recepción autorizada de posiciones y asignación de la posición al dispositivo/asignación válida.
- Clasificación canónica de cada lectura contra geocercas; posteriormente, confirmación de episodios de riesgo, persistencia y anti-duplicación.
- Detección programada de ubicación obsoleta.
- Envío de Web Push y manejo de secretos necesarios para integraciones.

**No duplicar como autoridad de negocio** las reglas de alerta en el frontend. El frontend puede calcular valores visuales aproximados sin convertirlos en datos oficiales.

## Flujo normal de posiciones

```text
Emisor autorizado → ingestión → verificar contexto/asignación
       ↓
Persistir ubicación (con recorded_at y received_at)
       ↓
Clasificar la lectura contra geocercas activas con su precisión
       ↓
Persistir relación INSIDE / OUTSIDE / UNCERTAIN / NO_ACTIVE_ZONE
       ↓
Confirmar o actualizar episodio de riesgo (historia posterior)
       ↓
Supabase Realtime → clientes con permisos
       ↓
Google Maps / dashboard
```

La ingestión puede ser una RPC protegida para simuladores autenticados en entorno de pruebas. Para un equipo celular real, diseñar después una Edge Function que autentique la credencial del dispositivo y reutilice el **mismo motor de persistencia y riesgo**.

## Eventos asíncronos

- Web Push sale del backend cuando se crea o escala un episodio de alerta, mediante integración aislada del motor de BD.
- Si el envío push falla, **la ubicación y la alerta permanecen guardadas**; usar una cola/outbox o mecanismo idempotente cuando se implemente.
- Supabase Cron puede verificar ubicaciones sin actualización cada minuto (parámetro ajustable); no usar temporizadores del navegador como fuente única para alertas de pérdida de señal.

## Realtime y confidencialidad

- El cliente se suscribe a cambios de los pacientes que puede consultar. La autorización se exige en el origen de datos, no solo ocultando elementos de interfaz.
- No publicar un canal global con geolocalizaciones privadas.
- Revisar comportamiento de revocación en conexiones ya abiertas y forzar desuscripción/refresco de sesión cuando corresponda; no asumir corte instantáneo universal sin pruebas.

## Despliegue confirmado y recomendaciones aún no cerradas

- La aplicación usa SSR con `@sveltejs/adapter-netlify@7.0.1`, función Node (`edge: false`) y salida pública `build`. Validar en Netlify autenticación por cookies, rutas profundas, service worker, Google Maps y Push.
- Estrategia `generateSW` vs `injectManifest`: elegir al implementar Web Push, probando eventos push con el plugin elegido.
- Cálculo de distancias mediante Haversine/PostGIS: comenzar por la opción correcta más simple y verificable; activar PostGIS si simplifica consultas y filtros.
- Biblioteca de UI y tipografía: recomendaciones en `07-UI-UX.md`; no confundir con decisiones cerradas.

## Referencias técnicas para validación

- SvelteKit SPA: https://svelte.dev/docs/kit/single-page-apps
- Plugin PWA SvelteKit: https://vite-pwa-org.netlify.app/frameworks/sveltekit.html
- Google Maps loader: https://developers.google.com/maps/documentation/javascript/load-maps-js-api
- Supabase PostgreSQL y RLS: https://supabase.com/docs/guides/database/overview
- Supabase Functions vs Edge: https://supabase.com/docs/guides/database/functions
