# 01 — Visión, alcance y criterios del MVP

**Estado:** alcance funcional acordado, salvo los asuntos expresamente marcados como pendientes.

## Problema

Las personas con Alzheimer y deterioro cognitivo pueden desorientarse y abandonar un entorno seguro. El seguimiento reactivo puede retrasar la detección del extravío. El MVP integra ubicación en un mapa, geocercas, historial y alertas comprensibles para facilitar la intervención de familiares y cuidadores.

## Marco académico

El documento `Proyecto Final.pdf` comprende capítulos I–III en la versión revisada. En particular, los **objetivos específicos del apartado 1.7** exigen: arquitectura IoT, PWA con localización e historial, gestión de pacientes y cuidadores, geofencing, alertas y priorización de riesgo; evaluación funcional y usabilidad. La **delimitación 3.4** define un prototipo académico, no un servicio clínico ni una implantación comercial. `Desarrollo del MVP.docx` exige una versión funcional, con tecnologías reales y base de datos, que pueda demostrarse al jurado.

## Incluido en el MVP

1. Registro, inicio/cierre de sesión y perfiles básicos con Supabase Auth.
2. Grupo ligero de tipo `FAMILY` o `CARE_CENTER`, con pacientes asociados; **sin módulo institucional**.
3. Alta, consulta y edición de pacientes por persona autorizada.
4. Acceso de múltiples usuarios a un paciente mediante `patient_access` con roles `ADMIN` y `MONITOR`.
5. Invitaciones a monitorear un paciente por email y enlace seguro; aceptar o rechazar.
6. Dispositivos **simulados** asignables a pacientes en la base de datos.
7. Envío HTTPS de ubicaciones por dos métodos de prueba: click en Google Maps y simulador Node.js con rutas.
8. Visualización de la última ubicación, antigüedad de datos e historial de posiciones.
9. Geocercas **circulares** configurables por `ADMIN` y `MONITOR`.
10. Clasificación de riesgo normal/bajo/medio/alto/crítico, episodios de alerta y estado de conexión independiente.
11. Alertas in-app y notificaciones Web Push en escenarios soportados por el navegador.
12. Pruebas reproducibles, incluyendo excepciones, latencia, regresión y autorización.

## Fuera del alcance inicial

- Firmware, provisioning, credenciales reales de IoT, QR, botón físico, claim, pairing y dispositivo en producción; se integrarán cuando el equipo físico esté disponible.
- Gestión de nómina, turnos, camas, habitaciones, facturación, historias clínicas, inventario institucional y módulos B2B.
- Diagnóstico de Alzheimer, toma de decisiones médicas, aprendizaje automático clínico o vigilancia invasiva.
- Modelos predictivos de IA complejos, GPS interior de alta precisión, rutas de rescate automáticas y conexión directa con emergencias.
- Aplicación nativa iOS/Android; se desarrolla una PWA.
- SMS y correo como canales de alerta (el correo sí se usa para Auth/invitaciones).
- Soporte offline de geolocalización en vivo: sin red se muestra último dato fiable y su antigüedad, no posición inventada.

## Escenario demostrable ante jurado

```text
ADMIN crea grupo FAMILY, paciente Juan y dispositivo simulado.
    ↓
ADMIN define geocerca circular y concede a MONITOR acceso a Juan.
    ↓
Simulador emite coordenadas dentro y fuera de la zona.
    ↓
Supabase almacena ubicaciones y calcula riesgo.
    ↓
PWA actualiza Google Maps, historial y alerta in-app.
    ↓
Web Push informa del evento pertinente con la PWA cerrada, si el
navegador permite notificaciones y el usuario concedió permiso.
    ↓
El paciente simulado regresa → episodio resuelto.
```

## Criterios de éxito del MVP

- Se pueden demostrar todos los pasos anteriores con datos simulados **persistidos**, no solamente con animaciones locales.
- Los cambios de ubicación generan efectos visibles en el mapa y registros en BD.
- Usuarios sin acceso no pueden leer posiciones ni modificar geocercas de ese paciente.
- El sistema detecta estados de ubicación desactualizada y no los presenta como seguridad confirmada.
- Los resultados se documentan con matrices de prueba y evidencia reproducible.
- La aplicación es usable en dispositivos móviles y permite instalación PWA cuando el entorno lo admite.

## Nota de coherencia documental

La tesis original especifica MQTT en varios apartados. La implementación acordada posteriormente usa HTTPS. No presentar MQTT como implementado si no lo está. Corregir los objetivos/arquitectura escritos con la asesoría académica cuando se actualice la tesis; véase `09-DECISIONES-PENDIENTES.md`.
