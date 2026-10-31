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
- Episodios activos con jerarquía visible y texto directo; no depender del color ni introducir niveles que el MVP no calcula.
- Evitar saturación visual, gradientes chillones, transiciones largas, neumorfismo de bajo contraste o "dashboard de flota".
- Tarjetas sencillas, suficiente espacio, buen agrupamiento de información y encabezados entendibles. Las tarjetas de contenido usan `rounded-2xl` y no usan borde exterior: la superficie y `shadow-sm` definen su contorno. Los separadores internos solo se conservan cuando distinguen familias de contenido o acciones.
- Usar una escala de elevación breve y consistente: `shadow-sm` en header, barra inferior y tarjetas principales, y `shadow-md` únicamente en el sidebar flotante de escritorio. Los botones, campos, estados y paneles internos permanecen sin sombra; evitar neumorfismo y elevaciones arbitrarias.
- Mantener respiración entre familias de componentes. Los controles de una misma familia pueden usar espacios compactos (`gap-2`/`gap-3`), pero un grupo de botones, un encabezado, una cuadrícula de tarjetas y un bloque de estado deben separarse con un escalón mayor de la escala estándar de Tailwind (`6`, `8` o `10`, según jerarquía). No compensar una agrupación deficiente con valores arbitrarios.
- Usar la escala estándar de Tailwind para radios, espaciado, tipografía, tracking, tamaños y rejillas. Las utilidades arbitrarias `[...]` se reservan únicamente para una restricción técnica sin equivalente estándar y deben justificarse en el código o la documentación.

Colores de referencia **propuestos**: verde salvia `#A8CBB7`, azul `#BDD8E9`, blanco cálido `#F6F8F5`, lavanda `#E7E5F4`, texto `#344B52`. Ajustar contrastes con herramientas WCAG antes de adoptarlos como tokens.

## Bibliotecas y tipografía

- Componentes: **shadcn-svelte** continúa como opción futura; no se incorpora al shell inicial porque la navegación no necesita componentes complejos y añadirla ampliaría dependencias y estilos sin beneficio proporcional.
- Iconos: **`@lucide/svelte@1.63.0`**, confirmado el 2026-10-28 para la navegación. Importar cada icono por subruta, acompañarlo siempre con etiqueta textual y ocultar el SVG redundante a tecnologías de asistencia.
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

## Navegación modular

- El área autenticada tiene tres módulos funcionales de primer nivel: **Pacientes**, **Alertas** y **Perfil**, además de **Inicio** como bienvenida mínima.
- En móvil se presentan en una barra inferior fija inspirada en Material 3: icono arriba, etiqueta abajo e indicador ovalado únicamente detrás del icono activo. La barra flota con separación lateral e inferior, borde redondeado y sin borde superior aislado. Desde `lg` se convierte en un sidebar oscuro flotante, separado 16 px de los bordes izquierdo, superior e inferior. Es una única navegación semántica adaptativa, no dos menús duplicados.
- Cada destino usa icono Lucide más etiqueta visible. El estado activo combina texto, color, fondo y `aria-current`; nunca depende solo del icono o del color.
- Los objetivos táctiles miden al menos 48 px, el foco de teclado es visible y la barra móvil conserva separación respecto del borde inferior del viewport. El contenido y la promoción de instalación dejan espacio para no quedar tapados; la safe area debe comprobarse manualmente en iPhone instalado.
- **Pacientes** permanece activo también en sus operaciones auxiliares (`/groups`, `/access-code`, `/onboarding` y rutas de paciente); **Perfil** incluye `/settings`.
- **Pacientes** usa `HeartHandshake` para representar cuidado, en lugar de un icono de grupo. El header opaco usa `Bell` y `CircleUserRound` como accesos directos a Alertas y Perfil; no aplica transparencia ni `backdrop-blur`.
- El header es la única fuente del título contextual dentro del área autenticada. Las pantallas no repiten un `h1` y una descripción de ubicación; las rutas de paciente muestran allí su nombre dinámico. Cuando se puede regresar, el header presenta una flecha con nombre accesible y comportamiento predecible hacia la pantalla padre.
- El sidebar determina la columna general del área autenticada y el header añade padding horizontal propio para que título e iconos respiren dentro de su superficie. El título usa una escala compacta: en rutas principales recibe `ms-2`; en subrutas ese margen desaparece y su lugar lo ocupa la flecha real de retorno. Los botones de icono del header son circulares y mantienen objetivos táctiles de 48 px.
- Si existe una alerta `OPEN` autorizada, la campana muestra un punto rojo y cambia su nombre accesible a **Alertas: hay una alerta activa**. La carga inicial es SSR y una suscripción Realtime mantiene el indicador actualizado; el color no es el único significado.
- **Cerrar sesión** se mantiene separado de la navegación principal: al fondo del sidebar en escritorio y dentro de Perfil en móvil. No se añade una cuarta opción de navegación sin una necesidad real.
- `/dashboard` es únicamente la bienvenida **Hola, USUARIO.**; no repite módulos, acciones, pacientes ni cierre de sesión.

### Estructura superior de las pantallas autenticadas

- El shell autenticado, no cada pantalla, aporta `min-h-dvh`. Así la altura del header y el padding inferior de navegación no se suman a otro viewport completo ni producen scroll en páginas cortas. Después del header, cada pantalla usa `px-5 py-8 sm:px-8 lg:px-0`; el sidebar define la columna de escritorio y la pantalla no añade un desplazamiento lateral que rompa la alineación con el header.
- El primer heading de contenido usa `text-2xl font-bold text-ink` y `mb-8`. El grupo de componentes comienza inmediatamente después, sin un `mt-*` adicional que acumule espacio. Las secciones posteriores se separan de la anterior con `mt-8` y repiten el mismo heading con `mb-8` cuando mantienen esa jerarquía.
- Las tarjetas y superficies principales usan `rounded-2xl`. `rounded-full` se reserva para avatares, indicadores circulares y controles cuya forma sea deliberadamente circular o de píldora; no usar `rounded-3xl` en nuevas tarjetas.
- El contenido principal de las tarjetas usa `p-6` en todos los anchos; no aumentar a `p-8` en escritorio. Cuando una tarjeta separa operaciones mediante un divisor, el pie de acciones usa `p-4`.
- Los avatares de texto usan el componente compartido `Initials`: recibe el nombre completo como un `string`, calcula hasta dos iniciales y conserva el mismo tamaño, tipografía y superficie neutral en listas y detalles. Es decorativo cuando el nombre ya está visible junto al avatar.
- Los encabezados internos de tarjetas que combinan icono Lucide, `h3` y descripción usan el componente compartido `Heading`. Sus tres propiedades son `icon`, `title` y `subtitle`; el componente mantiene el círculo neutral, el tamaño del icono, la jerarquía tipográfica y el espaciado. No sustituye cabeceras de identidad que usan `Initials` ni headings de página `h2`.
- Los resultados de acciones y los fallos recuperables de consulta usan el componente compartido `Alert`, con las props `title`, `subtitle`, `icon` y `color`. `positive` confirma una acción, `warning` comunica disponibilidad parcial, `danger` identifica un fallo y `neutral` aporta información contextual. El componente centraliza color, icono y región accesible; no sustituye estados de dominio, confirmaciones destructivas, resultados que requieren una presentación propia ni errores específicos junto a cada campo.
- Los contratos que tienen al menos tres consumidores se ubican en `src/lib/types`; `ui.ts` centraliza `UiIcon` y `UiTone` para `Heading`, `InfoItem`, `Alert` y las presentaciones de ruta. Los tipos o interfaces usados por uno o dos archivos permanecen junto a su implementación para evitar abstracciones prematuras.
- No alternar tonos decorativos entre tarjetas o iconos. Usar `surface-muted` como tratamiento neutral común. Los colores de alerta, error, éxito o foco siguen permitidos únicamente cuando comunican un estado real y deben acompañarse de texto o iconografía; no cuentan como multitono decorativo.

**Criterios aplicados mediante UI UX Pro Max (2026-10-28; ajustados el 2026-10-29):** navegación persistente con etiqueta e icono, estado activo inequívoco, foco visible, objetivos táctiles amplios, compensación del contenido para elementos fijos, soporte de área segura y adaptación bottom navigation/sidebar sin duplicar la estructura. La segunda iteración añade jerarquía Material 3 en móvil, sidebar flotante con separación espacial, acción destructiva aislada y controles de header de 48 px con nombres accesibles. La tercera iteración mantiene la columna general definida por el sidebar, centraliza títulos y retorno en el header y hace flotar también la barra móvil. El ajuste posterior compacta el título, usa margen inicial condicional en rutas principales y aumenta el padding interno del header. La dirección serena incorpora una escala de elevación controlada: `shadow-sm` separa superficies principales y `shadow-md` se reserva al sidebar; no se aplican sombras a botones ni paneles anidados. El header pasa a una superficie blanca opaca porque el blur decorativo no aporta contexto modal. La búsqueda UX específica confirmó que el retorno debe ser predecible y preservar el modelo de navegación; Senda enlaza a la pantalla padre conocida sin reemplazar el botón del navegador. La validación visual manual en móvil y escritorio continúa pendiente.

### Dirección visual de Pacientes

El 2026-10-29 el equipo eligió la dirección **serena/editorial** para `/patients` después de comparar dos composiciones. La lista usa tarjetas espaciosas que priorizan identidad, estado de alerta y operaciones claramente separadas; el selector comparativo y la alternativa expresiva/bento fueron retirados. La cuadrícula ocupa todo el ancho de la columna definida por el shell y presenta una columna en móvil, dos desde `md`, tres desde `xl` y cuatro desde `2xl`. El heading **Personas a tu cuidado** queda a la izquierda y las acciones a la derecha en escritorio; en móvil, las acciones pasan debajo del heading y conservan su orden.

Las referencias visuales externas influyen únicamente en composición, ritmo, bordes redondeados y jerarquía. La pantalla usa los tokens actuales de Senda sin copiar la paleta de las imágenes ni introducir datos ficticios. Las superficies decorativas no alternan colores: `surface-muted` es el tratamiento neutral común y el color se reserva para estados semánticos reales. Se mantienen etiquetas visibles, foco, estados expresados con texto y objetivos táctiles de al menos 48 px. Las tarjetas principales usan `rounded-2xl`, no tienen borde exterior y aplican `shadow-sm`; sus paneles internos y botones permanecen planos. Los grupos de acciones, encabezados y tarjetas se separan mediante la escala estándar de espaciado para conservar aire visual. La aplicación de esta dirección al resto de los módulos continúa pendiente de validación visual en móvil y escritorio.

La tarjeta de la lista no muestra coordenadas, frescura de ubicación ni el permiso del usuario. Su indicador prioritario expresa **Alerta activa**, **Sin alertas activas**, **Sin dispositivo configurado** o **Estado de alertas no disponible** mediante icono y texto; no afirma que el paciente esté seguro. Las acciones continúan al final y el mapa presenta la ubicación en su contexto visual cuando el usuario decide abrirlo. La carga inicial es SSR y la suscripción Realtime global invalida este estado cuando se abre o resuelve un episodio autorizado.

La vista `/patients/:id` usa todo el ancho disponible de la columna de contenido. La edición y el resumen del paciente forman una cuadrícula asimétrica de doce columnas en escritorio y se apilan en móvil. El resumen reemplaza la lista dispersa de “Estado actual” por identidad visual y bloques compactos para grupo, dispositivo y accesos activos. `InfoItem` encapsula esos bloques con las props `icon`, `title`, `info` y el tono semántico opcional `tone`; este último admite `neutral`, `positive`, `warning` o `danger` y centraliza las clases visuales para no aceptar utilidades arbitrarias desde cada consumidor. **Operaciones y monitoreo** se divide en dos tarjetas principales: Monitoreo reúne ubicación y geocercas; Administración reúne personas autorizadas y dispositivo. Las acciones internas son superficies planas, mientras las tarjetas principales usan `shadow-sm` y ningún borde exterior.

La vista `/patients/:id/access` presenta cada persona autorizada en una tarjeta independiente con la misma estructura vertical de `/patients`: identidad y metadatos arriba, y acciones separadas debajo por un divisor. Cada tarjeta muestra rol y fecha de concesión; omite `relationship` porque los flujos actuales no capturan ese dato. La revocación permanece visible solo para `MONITOR`, ocupa el pie de la tarjeta, usa color destructivo con texto e icono y despliega la confirmación en esa misma zona antes del envío. La tarjeta para generar códigos se mantiene a la derecha en escritorio y aparece antes que la lista de personas en móvil, donde compartir acceso es la acción prioritaria.

La vista `/patients/:id/device` conserva dos estados explícitos dentro de una tarjeta principal y usa `Heading` con el icono `Smartphone` en ambos. Sin asignación, presenta la explicación y el campo de serial en el contenido `p-6`, con feedback accesible mediante `Alert`, errores específicos junto al campo y las acciones separadas en el pie. Con una asignación activa, prioriza el estado de la asignación, comunica mediante texto que puede recibir ubicaciones, muestra la fecha y mantiene **Ver mapa** como acción principal; el serial técnico no se expone en la tarjeta. La interfaz usa lenguaje de producto y deja la naturaleza simulada del MVP en la documentación técnica; no pretende que exista provisioning físico. Los enlaces con apariencia de acción primaria usan el mismo `bg-brand` que los botones de envío. Ninguno de los estados interpreta la falta de lecturas como seguridad o conectividad.

## Onboarding y estados incompletos

- Después del registro, presentar dos acciones claras: configurar un dispositivo o ingresar un código de acceso. No tratarlas como roles permanentes de la cuenta.
- Aplicar divulgación progresiva: contexto `FAMILY`/`CARE_CENTER`, paciente y dispositivo en pasos separados, con indicador de progreso y navegación hacia atrás.
- Permitir **Configurar dispositivo después**. `/patients` mostrará **Sin dispositivo configurado**, una explicación breve y el botón **Configurar ahora** junto al paciente correspondiente.
- Un paciente sin dispositivo no debe mostrarse como seguro, conectado ni monitoreado. Usar un estado informativo neutral, no una alerta clínica.
- Al canjear un código, mostrar antes de aceptar únicamente el nombre mínimo del paciente y su contexto; dejar claro que el acceso será `MONITOR` sobre ese paciente, no sobre todo el grupo.

**Estado implementado (2026-10-24; reorganizado el 2026-10-29):** `/onboarding` presenta las dos acciones como opciones equivalentes y no permanentes; `/groups` separa Grupo, Paciente y Dispositivo en un asistente con progreso y retorno; `/access-code` usa divulgación progresiva para revisar la información mínima antes de aceptar. En las tarjetas de `/patients`, la acción principal distingue entre administrar y consultar; el permiso no ocupa espacio como metadato independiente.

El mapa de última ubicación reserva su espacio durante la carga para evitar saltos, ofrece recuperación ante error y conserva estados útiles sin dispositivo o sin lecturas. En `/patients/:id/map` ocupa todo el ancho disponible y una altura mayor antes de los resúmenes, para mantener la ubicación como contenido principal; el inicio de la página usa el mismo padding, heading `text-2xl` y separación `mb-8` que `/patients/:id`. La interfaz no expone coordenadas ni seriales técnicos. El recorrido reciente permanece como línea sobre el mapa, pero no repite cantidad ni rango temporal en una tarjeta secundaria. La frescura se comunica con texto además de color. Cuando existe precisión, el círculo azul se identifica expresamente como precisión y no como geocerca o zona segura. Las geocercas activas se muestran con círculos verdes no interactivos y una lista textual de nombres y radios; el mapa de monitoreo usa la misma interacción directa sin `Ctrl` que el editor.

El estado de ubicación prioriza una sola narrativa sobre la alerta: **Salida confirmada activa**, **Salida todavía no confirmada**, **Ubicación por confirmar**, **Sin salida confirmada** o error de consulta. Debajo aparecen dos datos de apoyo: vigencia y clasificación de la última lectura. Esto evita que una lectura individual contradiga el episodio confirmado por el backend. Los estados usan texto completo y tonos semánticos: `danger` para una salida activa, `warning` para incertidumbre o lectura aislada fuera, `positive` solamente para resultados favorables confirmados y `neutral` para metadatos o ausencia de una alerta confirmada; el color nunca sustituye el texto.

El historial local se limita a los cinco episodios más recientes y reutiliza `InfoItem`: una salida `OPEN` usa `danger` y una salida resuelta usa `positive`. Realtime actualiza la región de estado sin mover el foco. La vista completa por paciente y su ruta siguen pendientes, por lo que **Ver todos los episodios** permanece deshabilitado y explicado hasta implementarlas.

La ubicación manual se conserva para `ADMIN`, pero se presenta como una operación del producto: el usuario selecciona el punto directamente en el mapa y lo guarda sin ver ni editar valores numéricos. La UI no usa textos de prueba o simulación; los límites técnicos del dispositivo y del entorno permanecen documentados en los apartados de arquitectura y pruebas.

En `/alerts`, los episodios activos aparecen antes del historial en una cuadrícula responsiva de tarjetas principales `rounded-2xl`, sin borde exterior y con `shadow-sm`. Cada tarjeta combina icono, texto **Alerta activa**, nombre del paciente y el mensaje **Posible abandono de una zona segura**; dos `InfoItem` separan la hora confirmada y la acción recomendada. El rojo comunica urgencia, pero el significado siempre permanece escrito. **Revisar ubicación** es la acción principal y **Ver paciente** queda subordinada en el pie separado de la tarjeta.

Los episodios resueltos usan `Initials` para identificar al paciente e `InfoItem` con tono `positive` para mostrar tanto la confirmación como la resolución. Se distribuyen en una, dos o tres columnas según el ancho disponible, conservan una única acción contextual hacia el mapa y no presentan cada registro como una franja excesivamente ancha. `AlertEpisodeCard`, ubicado en `src/lib/components/alerts`, comparte esta presentación entre el feed global y el futuro historial por paciente: recibe estado y fechas, permite omitir el nombre cuando el contexto ya identifica al paciente y expone las acciones como contenido configurable. No recibe ubicaciones porque el recorrido histórico de un episodio aún no está definido. La pantalla usa todo el ancho del área autenticada, mantiene estados vacíos explícitos y reutiliza `Alert` para errores de consulta o Realtime. Aperturas y resoluciones continúan anunciándose en una única región `status` sin mover el foco.

## Editor de geocercas

- En móvil, el mapa aparece antes de la lista o del formulario. En escritorio ocupa ocho de doce columnas y una altura mayor para mantener la tarea espacial como contenido principal. Los controles mantienen objetivos táctiles cómodos y separación suficiente.
- La columna lateral muestra un único contexto: la lista de zonas durante la consulta o el editor durante la creación y modificación. El editor reemplaza temporalmente la lista en vez de apilarse sobre ella; cancelar o guardar devuelve la lista.
- El centro se elige en un modo explícito tocando o haciendo clic directamente sobre el mapa; el círculo provisional también se puede arrastrar después de colocarlo. La interfaz no expone latitud ni longitud y conserva esos valores como campos internos.
- El slider actualiza el círculo provisional de inmediato. El ajuste de zoom se realiza al terminar el cambio para evitar que el mapa pelee con el usuario durante cada movimiento.
- La zona seleccionada, las demás activas, la provisional y las inactivas tienen distinta jerarquía visual, acompañada siempre de nombre y estado textual; el color nunca es la única señal.
- Las tarjetas principales y los elementos de la lista no usan contornos; se separan mediante superficie, espacio y `shadow-sm`. `border-top` queda reservado para dividir información y acciones. Guardar, error y carga producen feedback accesible. Desactivar y archivar son acciones diferentes; archivar requiere confirmación y conserva la información.

**Criterios aplicados mediante UI UX Pro Max (2026-10-25; presentación ajustada el 2026-10-30):** **Cambiar centro** activa la selección y el toque/click sobre cualquier área coloca el círculo sin presentar coordenadas técnicas. Una vez creado, el círculo provisional admite arrastre. El editor captura directamente los gestos iniciados sobre el mapa para evitar la exigencia de `Ctrl`; el desplazamiento de la página sigue disponible fuera del mapa. La composición usa divulgación progresiva, una sola acción primaria y un contexto lateral por vez. También se mantienen foco visible, etiquetas asociadas, controles táctiles amplios, estados dinámicos anunciados y feedback de envío.

## Experiencia PWA

- Compatibilidad de instalación según capacidades reales del navegador/OS.
- Web Push requiere consentimiento. En iOS, verificar funcionamiento como app añadida a pantalla de inicio.
- El estado de Web Push debe expresarse con texto y no solo con color. `/settings` ofrece una acción clara para activar, desactivar o volver a comprobar; **Perfil** permanece visible en la navegación principal y no se añade otro recordatorio al dashboard mínimo.
- Pedir permiso solo como consecuencia de la acción explícita **Activar notificaciones**. Si el navegador lo bloqueó, explicar que Senda no puede cambiar ese permiso y orientar hacia la configuración del sitio.
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
