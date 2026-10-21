# 06 — Geofencing, riesgo, conectividad y pruebas de alerta

> **No son reglas médicas.** Los intervalos de transmisión, confirmación de salida y tolerancia inicial están acordados como punto de partida técnico. Los umbrales numéricos de severidad que siguen son **propuestas configurables**, aún no ratificadas definitivamente por el equipo.

## Parámetros iniciales acordados

- Intervalo nominal de ubicación del **simulador**: **30 segundos**, configurable.
- Considerar ubicación **desactualizada** tras **3 minutos** sin nueva ubicación válida, inicialmente.
- Confirmar salida por **dos lecturas consecutivas válidas fuera**, considerando `accuracy_m` y tolerancia alrededor del radio.
- Geocercas circulares.
- La ubicación se clasifica desde backend; frontend representa estado y permite simular solo bajo autorización.

## Separar dos dimensiones

**Riesgo**: `NORMAL`, `LOW`, `MEDIUM`, `HIGH`, `CRITICAL`.

**Conectividad / frescura**: `FRESH`, `STALE`, `NO_DATA` (terminología de implementación propuesta, se puede ajustar).

Si no hay coordenadas recientes, no afirmar que el paciente se encuentra a salvo. Si no hay geocerca configurada o la lectura GPS es inválida, no clasificar forzosamente `NORMAL`.

## Modelo de episodios

```text
SIN EVENTO (ubicación válida dentro)
    ↓ dos lecturas válidas confirman salida
OPEN / LOW
    ↓ tiempo acumulado
OPEN / MEDIUM
    ↓ distancia y tiempo, o distancia excepcional
OPEN / HIGH
    ↓ tiempo prolongado
OPEN / CRITICAL
    ↓ regreso confirmado a zona segura
RESOLVED
```

Un episodio se **actualiza** cuando cambia de nivel. No crear un nuevo episodio por cada lectura. El regreso abre un periodo NORMAL, pero conserva el historial de alerta como `RESOLVED`.

## Umbrales propuestos para discutir

| Estado | Regla orientativa |
|---|---|
| `NORMAL` | Coordenada válida reciente, dentro de alguna zona activa |
| `LOW` | Salida confirmada y menos de 5 minutos fuera |
| `MEDIUM` | Fuera durante >= 5 minutos |
| `HIGH` | Fuera >= 15 min **y** >= 500 m más allá del perímetro, **o** alejamiento >= 1000 m |
| `CRITICAL` | Fuera >= 30 minutos, sin importar distancia |

Evaluar de `CRITICAL` a `HIGH`, `MEDIUM`, `LOW` para evitar solapamientos. Tiempo medido desde el primer punto fiable de la salida confirmada, con política consistente ante datos atrasados. **La distancia debe especificar siempre si es desde el centro o más allá del límite**; aquí se propone distancia **fuera del perímetro**.

## Resistencia a lecturas ruidosas

- `accuracy_m` influye en si la lectura sirve para confirmar una salida. No utilizar una sola lectura de gran error como prueba suficiente.
- Configurar un **margen/histeresis** al perímetro para evitar flapping (entrada/salida en segundos). El valor exacto queda pendiente de validación con simulador y hardware.
- No crear eventos duplicados al reintentar enviar la misma posición; estrategia de idempotencia requerida al implementar.
- `recorded_at`: cuando se capturó; `received_at`: cuando llegó. No inferir la posición actual de un punto recibido fuera de orden.
- Varias geocercas: si el paciente está dentro de **cualquiera** de las zonas activas válidas, no está fuera de zona permitida. Si se decide limitar a una zona en MVP, simplificar en ese momento.
- Calcular un reingreso confiable antes de resolver episodio. Una sola lectura momentánea dentro del borde puede ser insuficiente; concretar este criterio con las pruebas.

## Envío de notificaciones

- Registrar el evento dentro de la aplicación para todos los niveles activos.
- En principio, Web Push para `MEDIUM`, `HIGH`, `CRITICAL`; LOW solo in-app para evitar fatiga de notificaciones. **Esta política es recomendada, no decisión ratificada.**
- No repetir Web Push cada 30 segundos si el episodio permanece en el mismo nivel.
- Notificar escalada real y/o eventos importantes definidos; no incluir datos personales innecesarios en el cuerpo del push.

## Casos de prueba prioritarios

| ID | Dato de entrada / situación | Resultado esperado |
|---|---|---|
| R01 | Punto reciente y válido dentro de zona | NORMAL |
| R02 | Un único punto fuera, segundo dentro | Sin salida confirmada |
| R03 | Dos puntos válidos consecutivos fuera con margen | OPEN / LOW |
| R04 | Fuera 5 minutos | OPEN / MEDIUM (según propuesta) |
| R05 | Fuera 16 min y +650 m del perímetro | OPEN / HIGH (según propuesta) |
| R06 | Fuera 30 min | OPEN / CRITICAL (según propuesta) |
| R07 | Fuera 2 min pero +1.2 km | OPEN / HIGH (según propuesta) |
| R08 | Regresa y se confirma reingreso | RESOLVED |
| R09 | Lectura aislada imprecisa fuera | No escalar sin confirmar |
| R10 | Sin ubicación durante >3 min | STALE, sin inventar ubicación |
| R11 | Reaparece conectividad, puntos llegan desordenados | Estado actual no retrocede incorrectamente |
| R12 | Dos zonas seguras superpuestas, dentro de una | No alertar por salida parcial |
| R13 | Coordenada duplicada/reintento HTTP | No duplicar registro/alerta innecesariamente |
| R14 | No hay geocerca activa | Mostrar configuración ausente, no afirmar NORMAL |
| R15 | Cambio de geocerca durante episodio | Reevaluación consistente y evento auditable |
| R16 | Paciente sin asignación de dispositivo | Estado sin datos, sin falsas alertas |
| R17 | Usuario revocado mantiene pestaña abierta | Sin lectura futura ni acceso persistente autorizado |
| R18 | Simulación acelera el reloj | Cambios de nivel correctos sin dormir minutos reales |
| R19 | Dos posiciones con salto físicamente implausible | Marcar sospechosa/descartar según política definida |

## Métricas a registrar para la tesis

- Latencia entre recepción y actualización de interfaz.
- Latencia entre segunda lectura confirmatoria y creación de alerta.
- Proporción de pruebas funcionales satisfactorias.
- Tasa de alertas duplicadas e incidentes falsos en escenarios controlados.
- Exactitud de la clasificación ante escenarios R01–R19.
- Éxito y tiempo de entrega del Web Push según navegador/dispositivo donde esté soportado.

## Pendientes antes del motor de alertas

1. Validar o modificar tiempos 5/15/30 minutos y distancias 500/1000 metros.
2. Fijar margen/histeresis y precisión GPS aceptable.
3. Decidir confirmación de reingreso y gestión de escaladas con datos tardíos.
4. Elegir si una o varias geocercas activas son permitidas inicialmente.
5. Formalizar umbral de rapidez imposible/saltos espurios e idempotencia.
