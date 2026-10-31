# 06 — Geofencing, riesgo, conectividad y pruebas de alerta

> **No son reglas médicas.** Los intervalos de transmisión, confirmación de salida y tolerancia inicial son decisiones técnicas del prototipo. El MVP comunica episodios activos o resueltos y no clasifica su gravedad clínica.

## Parámetros iniciales acordados

- Intervalo nominal de ubicación del **simulador**: **30 segundos**, configurable.
- Considerar ubicación **desactualizada** tras **3 minutos** sin nueva ubicación válida, inicialmente.
- Confirmar salida por **dos lecturas consecutivas válidas fuera**, considerando `accuracy_m` y tolerancia alrededor del radio.
- Geocercas circulares.
- La ubicación se clasifica desde backend; frontend representa estado y permite simular solo bajo autorización.
- La clasificación básica usa una incertidumbre mínima de **25 m**; si `accuracy_m` es mayor, se usa ese valor.

## Clasificación básica por lectura — historia 4B

Esta etapa todavía no crea episodios ni alertas. Al insertar una ubicación, PostgreSQL calcula la distancia Haversine entre la lectura y cada geocerca activa no archivada del paciente. Para cada círculo:

```text
tolerancia_efectiva = max(accuracy_m o 0, 25 m)
distancia_al_perímetro = distancia_al_centro - radio
```

- `INSIDE`: la lectura y su margen completo caben dentro de al menos una zona (`distancia_al_perímetro <= -tolerancia_efectiva`).
- `UNCERTAIN`: no está confirmada dentro de ninguna zona y su margen alcanza al menos un perímetro (`abs(distancia_al_perímetro) <= tolerancia_efectiva`).
- `OUTSIDE`: queda fuera de todas las zonas por más que el margen efectivo.
- `NO_ACTIVE_ZONE`: no existe una geocerca activa y no archivada contra la cual evaluar.
- `NOT_EVALUATED`: lectura histórica anterior al clasificador; no se reinterpreta usando zonas creadas o modificadas después.

La prioridad al evaluar múltiples zonas es `INSIDE` → `UNCERTAIN` → `OUTSIDE`: estar inequívocamente dentro de cualquiera basta para `INSIDE`. La fila conserva la zona determinante, la distancia firmada al perímetro, la tolerancia aplicada y el momento de evaluación. La interfaz puede representar esa relación, pero **una lectura `OUTSIDE` no equivale a una salida confirmada ni a una alerta**.

**Estado completado (2026-10-25):** migración, trigger y UI implementados. La migración está aplicada en Supabase de desarrollo y los 36 casos pgTAP pasan sin dejar datos ficticios. El usuario validó manualmente `INSIDE`, `OUTSIDE`, `UNCERTAIN`, `NO_ACTIVE_ZONE` y la actualización Realtime en la PWA.

## Separar dos dimensiones

**Episodio de salida**: sin episodio activo, `OPEN` o `RESOLVED` en el historial.

**Conectividad / frescura**: `FRESH`, `STALE`, `NO_DATA` (terminología de implementación propuesta, se puede ajustar).

Si no hay coordenadas recientes, no afirmar que el paciente se encuentra a salvo. Si no hay geocerca configurada o la lectura GPS es inválida, no clasificar forzosamente `NORMAL`.

## Modelo de episodios

```text
SIN EPISODIO ACTIVO
    ↓ dos lecturas válidas confirman salida
OPEN
    ↓ regreso confirmado a zona segura
RESOLVED
```

No se crea un episodio por cada lectura. El mismo registro permanece `OPEN` durante la salida y cambia a `RESOLVED` al confirmarse el reingreso. La conectividad y la relación de la última lectura con las geocercas continúan mostrándose por separado.

### Historia 4C — episodio básico confirmado

- Dos lecturas `OUTSIDE` confiables y consecutivas abren un único episodio `OPEN`.
- Dos lecturas `INSIDE` confiables y consecutivas resuelven el episodio.
- Para esta confirmación, una lectura es confiable si `accuracy_m` es nulo o no supera 100 m; el clasificador sigue aplicando su tolerancia efectiva mínima de 25 m.
- `UNCERTAIN`, `NO_ACTIVE_ZONE`, `NOT_EVALUATED` o una precisión peor de 100 m no abren ni resuelven un episodio e interrumpen la pareja consecutiva.
- El orden actual usa `recorded_at` y `id` dentro de la misma asignación. Una lectura atrasada se conserva, pero no retrocede ni confirma el estado actual.
- El episodio guarda las lecturas que iniciaron y confirmaron la salida y la que confirmó el reingreso.
- Los episodios no almacenan ni presentan niveles de severidad.

**Estado completado (2026-10-25):** migración, prueba pgTAP, consulta SSR, tarjeta textual, historial breve y actualización Realtime implementados. `20261026010952_geofence_alert_episodes.sql` está aplicada en Supabase de desarrollo y sus 55 casos pasan sin dejar datos ficticios. El usuario validó manualmente apertura, Realtime y resolución. El equipo decidió cerrar este motor como alcance suficiente del MVP.

## Decisión de simplicidad del MVP

El prototipo no cambia el episodio según minutos transcurridos ni distancia adicional fuera del perímetro. Los niveles `MEDIUM`, `HIGH` y `CRITICAL`, junto con umbrales como 5/15/30 minutos o 500/1000 metros, quedan explícitamente fuera del alcance. Pueden estudiarse después del MVP si pruebas con hardware real justifican esa complejidad.

## Resistencia a lecturas ruidosas

- `accuracy_m` influye en si la lectura sirve para confirmar una salida. La historia 4C acepta hasta 100 m y exige dos lecturas consecutivas; una lectura con peor precisión interrumpe la confirmación.
- La banda básica de incertidumbre usa 25 m como mínimo y la pareja de lecturas evita reaccionar a un único punto ruidoso. Una histéresis adicional solo se reconsiderará con evidencia de hardware real.
- No crear eventos duplicados al reintentar enviar la misma posición. La ingestión inicial usa un `event_id` UUID único por asignación; el mismo evento y contenido es idempotente, mientras que reutilizarlo con contenido distinto se rechaza.
- `recorded_at`: cuando se capturó; `received_at`: cuando llegó. No inferir la posición actual de un punto recibido fuera de orden.
- Varias geocercas: si el paciente está dentro de **cualquiera** de las zonas activas válidas, no está fuera de zona permitida. Las zonas pueden superponerse y no existe un máximo artificial en base de datos. Las inactivas o archivadas no participan.
- El reingreso básico requiere dos lecturas `INSIDE` confiables y consecutivas antes de resolver el episodio.

## Envío de notificaciones

- Registrar el episodio dentro de la aplicación al confirmarse la salida.
- Mostrar el episodio `OPEN` en `/alerts` para cada usuario autorizado y actualizar su apertura o resolución por Realtime.
- Consultar todos los episodios de un paciente autorizado en `/patients/:id/episodes`, manteniendo el episodio `OPEN` separado y paginando los `RESOLVED` de doce en doce, sin confundir el mapa actual con el recorrido histórico de un episodio.
- Enviar como máximo una notificación Web Push al abrir el episodio; el MVP no envía otra al resolverlo.
- No repetir Web Push con cada nueva ubicación mientras el episodio siga `OPEN`.
- No incluir datos personales innecesarios en el cuerpo del push.
- Usar **Posible salida de una zona segura. Abre Senda para revisar de inmediato.** para comunicar urgencia sin declarar una emergencia no verificada.

## Casos de prueba prioritarios

| ID | Dato de entrada / situación | Resultado esperado |
|---|---|---|
| R01 | Punto reciente y válido dentro de zona | Sin episodio activo |
| R02 | Un único punto fuera, segundo dentro | Sin salida confirmada |
| R03 | Dos puntos válidos consecutivos fuera con margen | OPEN |
| R04 | Continúan llegando puntos fuera | Mantener el mismo episodio OPEN |
| R05 | Punto mucho más distante del perímetro | Mantener el mismo episodio OPEN, sin nivel adicional |
| R06 | Episodio permanece abierto durante más tiempo | Mantener el mismo episodio OPEN, sin escalada temporal |
| R07 | Punto distante poco después de abrir | Mantener el mismo episodio OPEN, sin nivel adicional |
| R08 | Regresa y se confirma reingreso | RESOLVED |
| R09 | Lectura aislada imprecisa fuera | No abrir episodio sin confirmar |
| R10 | Sin ubicación durante >3 min | STALE, sin inventar ubicación |
| R11 | Reaparece conectividad, puntos llegan desordenados | Estado actual no retrocede incorrectamente |
| R12 | Dos zonas seguras superpuestas, dentro de una | No alertar por salida parcial |
| R13 | Coordenada duplicada/reintento HTTP | No duplicar registro/alerta innecesariamente |
| R14 | No hay geocerca activa | Mostrar configuración ausente, no afirmar NORMAL |
| R15 | Cambio de geocerca durante episodio | Reevaluación consistente y evento auditable |
| R16 | Paciente sin asignación de dispositivo | Estado sin datos, sin falsas alertas |
| R17 | Usuario revocado mantiene pestaña abierta | Sin lectura futura ni acceso persistente autorizado |
| R18 | Simulación acelera el envío | Apertura y resolución correctas sin depender de esperas reales |
| R19 | Dos posiciones con salto físicamente implausible | Marcar sospechosa/descartar según política definida |

## Métricas a registrar para la tesis

- Latencia entre recepción y actualización de interfaz.
- Latencia entre segunda lectura confirmatoria y creación del episodio.
- Proporción de pruebas funcionales satisfactorias.
- Tasa de alertas duplicadas e incidentes falsos en escenarios controlados.
- Exactitud de la clasificación ante escenarios R01–R19.
- Si se implementa Web Push, éxito y tiempo de entrega según navegador/dispositivo donde esté soportado.

## Pendientes fuera del motor básico

1. Evaluar con hardware real si la banda de 25 m, el máximo de precisión de 100 m y las dos lecturas consecutivas necesitan ajustes.
2. Formalizar un umbral de rapidez imposible o saltos espurios si las pruebas reales muestran esa necesidad. La idempotencia básica por `event_id` ya está definida.
3. Evaluar una cola de reintentos persistentes solo si las pruebas posteriores muestran que la entrega asíncrona simple es insuficiente para el alcance real.
