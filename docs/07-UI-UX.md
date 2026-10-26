# 07 — UI/UX, identidad visual y PWA

## Obligatorio

- Framework: **SvelteKit `@sveltejs/kit@3.1.0` + Svelte 5 + TypeScript**.
- Estilos: **Tailwind CSS**.
- PWA: **`vite-plugin-pwa@1.3.0` integrado directamente desde Fase 0**, con manifest, iconografía adecuada y pruebas de instalación/actualización. Es la excepción aprobada por incompatibilidad de peers de `@vite-pwa/sveltekit@1.1.0` con SvelteKit 3.1.0.
- En etapas de diseño e implementación de UI/UX, **utilizar la skill `ui-ux-pro-max`** prevista para Codex en VS Code. Consultar sus instrucciones y documentar criterios aplicados. El equipo se encarga de instalarla fuera de esta tarea; si no es accesible, informar el bloqueo y no fingir su uso.
- **Mobile-first**, con adaptación a tablet y escritorio.
- La interfaz debe transmitir **calma, confianza, claridad y protección**, sin ocultar urgencias.

## Estética orientativa (no paleta definitiva)

- Pasteles sobrios: verde salvia, azul suave, lavanda pálida, blanco cálido.
- Texto neutro oscuro con contraste legible.
- Alertas HIGH/CRITICAL con jerarquía visible; no suavizar su gravedad por mantener estética pastel.
- Evitar saturación visual, gradientes chillones, transiciones largas, neumorfismo de bajo contraste o "dashboard de flota".
- Tarjetas sencillas, suficiente espacio, buen agrupamiento de información y encabezados entendibles.

Colores de referencia **propuestos**: verde salvia `#A8CBB7`, azul `#BDD8E9`, blanco cálido `#F6F8F5`, lavanda `#E7E5F4`, texto `#344B52`. Ajustar contrastes con herramientas WCAG antes de adoptarlos como tokens.

## Bibliotecas y tipografía (recomendaciones, no acuerdos obligatorios)

- Componentes: **shadcn-svelte**, compatible con Tailwind, evaluar integración/versión.
- Iconos: **Lucide** (una familia consistente).
- Tipografía: **Inter** o **Nunito Sans**, preferencia provisional por Inter.
- Modo claro como enfoque inicial; no implementar tematización múltiple/dark mode sin necesidad.

## Jerarquía de información

1. ¿Quién es el paciente?
2. ¿Qué riesgo **conocido** presenta?
3. ¿Cuándo se actualizó por última vez su ubicación?
4. ¿En qué lugar está la última ubicación registrada?
5. ¿Qué acción concreta puede realizar el cuidador?

Ejemplo textual, no maqueta visual:

```text
Juan Pérez
Dentro de zona segura
Última posición: hace 30 segundos
[Ver mapa]

Rosa Martínez
Riesgo alto: fuera de zona segura
Última posición: hace 1 minuto
[Ver mapa] [Ver alerta]
```

No usar únicamente un punto verde/rojo para comunicar estado; incluir texto. El estado `UBICACIÓN DESACTUALIZADA` tiene prioridad incluso si el riesgo anterior era `NORMAL`.

## Onboarding y estados incompletos

- Después del registro, presentar dos acciones claras: configurar un dispositivo o ingresar un código de acceso. No tratarlas como roles permanentes de la cuenta.
- Aplicar divulgación progresiva: contexto `FAMILY`/`CARE_CENTER`, paciente y dispositivo en pasos separados, con indicador de progreso y navegación hacia atrás.
- Permitir **Configurar dispositivo después**. El dashboard mostrará **Sin dispositivo configurado**, una explicación breve y el botón **Configurar ahora** junto al paciente correspondiente.
- Un paciente sin dispositivo no debe mostrarse como seguro, conectado ni monitoreado. Usar un estado informativo neutral, no una alerta clínica.
- Al canjear un código, mostrar antes de aceptar únicamente el nombre mínimo del paciente y su contexto; dejar claro que el acceso será `MONITOR` sobre ese paciente, no sobre todo el grupo.

**Estado implementado (2026-10-24):** `/onboarding` presenta las dos acciones como opciones equivalentes y no permanentes; `/groups` separa Grupo, Paciente y Dispositivo en un asistente con progreso y retorno; `/access-code` usa divulgación progresiva para revisar la información mínima antes de aceptar. En las tarjetas del dashboard, el permiso se expresa como **Tu acceso: Administrador/Monitor** y se separa de la identidad del paciente para no atribuirle ese rol por error.

El mapa de última ubicación reserva su espacio durante la carga para evitar saltos, ofrece recuperación ante error y conserva estados útiles sin dispositivo o sin lecturas. La frescura se comunica con texto además de color. Cuando existe precisión GPS, el círculo azul se identifica expresamente como precisión y no como geocerca o zona segura. Las geocercas activas se muestran con círculos verdes no interactivos y una lista textual de nombres y radios; el mapa de monitoreo usa la misma interacción directa sin `Ctrl` que el editor.

La relación de la lectura con las geocercas se presenta en una tarjeta separada de la frescura y de las futuras alertas. Sus estados usan encabezados completos —**Dentro de una zona permitida**, **Fuera de las zonas permitidas**, **Ubicación cerca del límite**, **Sin geocerca activa** o **Evaluación no disponible**— para no depender del color. El estado fuera de zona aclara que una lectura aislada aún no constituye una alerta confirmada; los cambios recibidos por Realtime se anuncian de forma cortés sin mover el foco.

## Editor de geocercas

- En móvil, el mapa aparece antes de la lista y del formulario. Los controles mantienen objetivos táctiles cómodos y separación suficiente.
- El centro se elige en un modo explícito por toque/click y el círculo provisional también se puede arrastrar. Latitud, longitud y radio numéricos permiten completar la misma tarea con teclado, por lo que el arrastre nunca es obligatorio.
- El slider actualiza el círculo provisional de inmediato. El ajuste de zoom se realiza al terminar el cambio para evitar que el mapa pelee con el usuario durante cada movimiento.
- La zona seleccionada, las demás activas, la provisional y las inactivas tienen distinta jerarquía visual, acompañada siempre de nombre y estado textual; el color nunca es la única señal.
- Guardar, error y carga producen feedback accesible. Desactivar y archivar son acciones diferentes; archivar requiere confirmación y conserva la información.

**Criterios aplicados mediante UI UX Pro Max (2026-10-25):** el círculo provisional admite arrastre, pero el gesto no es obligatorio: **Cambiar centro**, el toque/click sobre cualquier área y las coordenadas numéricas ofrecen alternativas de un solo puntero y teclado. El editor captura directamente los gestos iniciados sobre el mapa para evitar la exigencia de `Ctrl`; el desplazamiento de la página sigue disponible fuera del mapa. También se mantienen foco visible, etiquetas asociadas, controles táctiles amplios, estados dinámicos anunciados y feedback de envío.

## Experiencia PWA

- Compatibilidad de instalación según capacidades reales del navegador/OS.
- Web Push requiere consentimiento. En iOS, verificar funcionamiento como app añadida a pantalla de inicio.
- Service worker: **no cachear respuestas de Supabase con ubicaciones/personas/historial por defecto**. Cachear recursos estáticos con política segura; evitar filtraciones entre usuarios al cambiar de sesión.
- Cuando haya versión nueva, manejar actualización/reload de forma visible y sin pérdida silenciosa de acciones.
- Mapas Google requieren red; evitar prometer posiciones nuevas offline.
- En caso de sesión expirada o revocación, limpiar datos privados de la vista y cerrar suscripciones.

## Accesibilidad

- Contraste de texto y controles según WCAG AA, foco visible, navegación teclado y etiquetas de formulario.
- Botones y áreas táctiles cómodos; estados de carga, sin datos, error, desconexión y permiso denegado.
- Respetar `prefers-reduced-motion` y dimensionamiento de texto.
- Lenguaje claro para personas no técnicas: "Última ubicación hace 4 min", no "socket disconnected".
- Alertas y botones importantes deben verse sin zoom ni scroll innecesario en móviles habituales.

## Hecho = verificado

No declarar lista una pantalla por verse bien en escritorio. Verificar ancho móvil, foco, errores, acciones reales, permissions y lectura de estados; usar la skill UI UX Pro Max en revisiones de interfaz, no solo para escoger colores.

## Referencias

- Skill UI UX Pro Max: https://github.com/nextlevelbuilder/ui-ux-pro-max-skill
- Plugin Vite PWA para SvelteKit: https://vite-pwa-org.netlify.app/frameworks/sveltekit.html
