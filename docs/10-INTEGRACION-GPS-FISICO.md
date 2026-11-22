# 10 — Integración del GPS físico Mictrack MT710L-LA

Manual operativo para llevar el rastreador real a Senda y recoger evidencia para la tesis. Describe lo que está **verificado**, lo que **no** y qué hacer en cada paso. Nada de lo marcado como pendiente debe presentarse como validado.

## 1. Arquitectura

```text
MT710L-LA ──4G / TCP──► Traccar (Docker, VPS) ──HTTPS POST──► Edge Function ingest-device-location
 (SIM Claro)            5030 tlt2h · 5191 mictrack            valida secreto, normaliza, event_id estable
                                                                        │ service_role
                                                                        ▼
                                              RPC ingest_device_location → locations (source = DEVICE)
                                                                        │ triggers existentes
                                                                        ▼
                                          geocerca → episodio → Realtime → Web Push → PWA Senda
```

El equipo habla un protocolo de rastreo por TCP; **nunca** se configura la URL de Supabase como servidor del dispositivo.

## 2. Estado real

| Tramo                                                                      | Estado                                                                                                                                       |
| -------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| Función, RPC, geocercas, episodios, `/alerts`                              | Verificado con datos simulados (ver §8)                                                                                                      |
| Formato del reenvío de Traccar 6.17.0                                      | Verificado con un dispositivo de prueba OsmAnd, no con el GPS                                                                                |
| Configuración USB del equipo                                               | Configurado el 2026-11-22: APN `internet.ideasclaro.com.do` (sin usuario ni contraseña, según la guía de Claro RD), servidor del VPS, puerto `5030`, Modo 1 cada 60 s; verificado leyendo el equipo tras reiniciar |
| Decodificación del MT710L-LA en Traccar                                    | **Verificada el 2026-11-22:** Traccar decodifica el equipo con `tlt2h` por el puerto `5030` (41 posiciones en unos 30 minutos, sin errores en su log). El puerto `5191` no se usó |
| GPS con fix, registro en la red 4G, datos por la SIM                       | **Verificado el 2026-11-22:** posiciones válidas (`A`) cada 60 s por la SIM de Claro; el equipo también respondió por SMS a `*RCONF#1##`                              |
| Servidor Traccar público                                                   | **Desplegado el 2026-11-22** en un VPS de DigitalOcean (NYC3) con firewall abierto a SSH, `5030` y `5191`. Es temporal: se destruye al terminar la prueba                  |
| Llegada a Senda y mapa                                                     | Una lectura real llegó a la pantalla de un paciente de prueba por Realtime tras asignar el equipo. **No** se consultó la fila `locations` por SQL y el marcador no se vio porque el mapa de Google no cargó |
| Web Push con la alerta física                                              | **Sin verificar**                                                                                                                            |
| Modelo: el equipo reporta `MDL:MT810`, la compra dice MT710L-LA            | **Pendiente de aclarar con Mictrack**                                                                                                        |

## 3. Pendientes por responsable

**Tú (presencial o con cuentas):**

1. ~~Comprar la SIM de Claro y obtener el APN~~ (hecho, §4).
2. ~~Contratar un VPS y desplegar Traccar~~ (hecho el 2026-11-22, §5). **Destruirlo al terminar la prueba** para no seguir pagando.
3. ~~Cargar el servidor en el equipo y asignarlo~~ (hecho, §6, §7).
4. Cambiar la contraseña de comandos del equipo: sigue siendo la de fábrica `0000` y acepta comandos por SMS (por ejemplo, cambiar el servidor). Está en el protocolo oficial (`777` + nueva + vieja); no se probó.
5. Rotar `SENDA_WEBHOOK_SECRET` (se expuso en una conversación): cambiarlo a la vez en Supabase Vault (`senda_webhook_secret`), en los Edge Function Secrets y en `.env`.
6. Poner la clave de Google Maps (restringida por origen) en `PUBLIC_GOOGLE_MAPS_API_KEY` para ver el recorrido y dibujar geocercas: el 2026-11-22 el mapa seguía sin cargar.
7. Hacer las preguntas a Mictrack (§4) que sigan pendientes.

**Ya hecho:** migración, RPC, Edge Function, 55 casos pgTAP, 16 pruebas unitarias, emulador, verificador de preparación, configuración de Traccar.

## 4. Visita a Claro

**Lleva:** tu documento de identidad, el equipo (para ver el tamaño de la Nano SIM), un teléfono con ranura Nano SIM.

**Pide:**

1. Nano SIM prepago, con **datos activos** y el **PIN desactivado**.
2. El **APN** de datos y si exige usuario y contraseña.
3. Confirmación de que se puede usar en un rastreador GPS, no solo en un teléfono.
4. Bandas LTE y cobertura 4G en la zona de la prueba. El equipo soporta B2, B3, B4, B5, B7, B8, B28 y B66 y **no tiene respaldo 2G**.
5. Un plan de datos pequeño: el equipo envía pocos KB por minuto.

**Verifícalo allí mismo:** inserta la SIM en tu teléfono, configura el APN que te den y abre una página web con datos móviles. Si carga, la SIM y el APN sirven. La configuración del rastreador puede hacerse después en casa por USB; no hace falta llevar el equipo ni el portátil.

**Anota literalmente:** APN, usuario y contraseña si los hay, número de la SIM y fecha de activación.

**Preguntas para Mictrack (en inglés):** (1) `MDL:MT810` frente a MT710L-LA; (2) qué tipo de SIM necesita, su guía pide CAT-M1 o NB-IoT y el equipo es Cat 1 bis; (3) protocolo y puerto para Traccar, y el documento Open Protocol; (4) qué es `UP:0000` y si se cambia; (5) cómo leer el IMEI por USB; (6) intervalo mínimo del Modo 1 y qué hace el Modo 8 de fábrica.

## 5. Servidor Traccar

Sigue `infra/traccar/README.md`. Resumen: VPS con firewall abierto solo a SSH, `5030/tcp` y `5191/tcp`; la interfaz web (`8082`) escucha solo en `127.0.0.1` y se usa por túnel SSH. Cuando esté arriba:

```sh
npm run check:gps-readiness -- --traccar-host <ip-o-dominio>
```

## 6. Configurar el equipo (config.mictrack.com, por USB)

1. Driver Prolific 3.6.81.357 y cable oficial (ver Fase A en `docs/09`). Enciende con el botón **SOS** (LED azul).
2. Con la SIM puesta, abre `config.mictrack.com`, **Scan Ports → Connect**.
3. Rellena:
   - **APN:** el que te dio Claro (nunca `claro.com.br`, que es de Brasil).
   - **Server:** dominio o IP del VPS, **sin** `http://`.
   - **Port:** `5030`. Verificado el 2026-11-22: es el puerto con el que Traccar decodifica este equipo (`tlt2h`).
   - **Modo de trabajo:** Modo 1 (tiempo real), intervalo **30 a 60 s**. Con intervalos mayores la ubicación se marca obsoleta a los 3 minutos y la salida tarda en confirmarse. Para la demostración deja el equipo cargado; el modo 1 consume la batería de 650 mAh en días.
4. **Apply & Reboot.** Guarda una captura de la pantalla con el IMEI oculto.
5. Guarda la lectura `RCONF,1` antes y después como evidencia.

Si el equipo se queda sin posición, sácalo a cielo abierto: dentro de una oficina puede no obtener fix.

## 7. Registrar y asignar el equipo en Senda

El IMEI (en la etiqueta, en la caja o en **Device Info**) se registra en la base mediante una operación de servicio. En el editor SQL de Supabase, sustituyendo los valores:

```sql
begin;
set local role service_role;
select * from public.register_physical_device('SENDA-GPS-001', '<IMEI>');
reset role;
commit;
```

Luego, en la app, un `ADMIN` del paciente asigna `SENDA-GPS-001` desde `/patients/<id>/device` o desde el paso 3 del asistente de alta (ambos prueban primero el inventario simulado y después el físico). Un equipo solo puede tener un paciente activo: si ya está asignado, hay que desasignarlo antes; después crea una geocerca en `/patients/<id>/safe-zones`. Comprueba el estado sin escribir datos:

```sh
npm run check:gps-readiness -- --hardware-id <IMEI>
```

Debe decir "registrado y asignado a un paciente". Usa siempre un paciente de prueba. No pegues el IMEI real en capturas de la tesis sin ocultarlo.

## 8. Resultado del ensayo simulado (2026-11-21, no es del equipo real)

Con el dispositivo ficticio `SENDA-GPS-DEMO-001` y un paciente ficticio, seis `POST` con formato de Traccar recorrieron función → RPC → `locations` → clasificación → episodio. Dos lecturas `OUTSIDE` abrieron el episodio y dos `INSIDE` lo resolvieron. En la compilación de producción, `/alerts` mostró la alerta y su paso al historial sin recargar. Ida y vuelta HTTP entre 387 y 1352 ms. Estos tiempos se midieron con el reloj del emulador y no son latencias del hardware.

## 9. Plan de pruebas con el equipo real

Marca cada caso con fecha, hora y evidencia. No registres un resultado que no se observó.

| Id  | Caso                                                    | Resultado esperado                                                                         | Evidencia                                   |
| --- | ------------------------------------------------------- | ------------------------------------------------------------------------------------------ | ------------------------------------------- |
| R01 | El equipo se conecta a Traccar                          | El dispositivo figura `online` en la interfaz de Traccar                                   | Captura con hora                            |
| R02 | Primera coordenada real a cielo abierto                 | Traccar muestra una posición con `valid = true`                                            | Captura de la posición                      |
| R03 | La posición llega a Senda                               | Fila en `locations` con `source = DEVICE`                                                  | Consulta §10                                |
| R04 | La ubicación aparece en el mapa                         | Marcador en `/patients/<id>/map` sin recargar                                              | Captura con hora                            |
| R05 | Salir de la geocerca caminando                          | Dos lecturas `OUTSIDE` consecutivas                                                        | Consulta §10                                |
| R06 | Episodio abierto                                        | Episodio `OPEN` y alerta en `/alerts`                                                      | Captura y consulta §10                      |
| R07 | Notificación Web Push                                   | Llega con la PWA cerrada, en un navegador con suscripción activa                           | Foto del teléfono con hora                  |
| R08 | Reingreso                                               | Dos lecturas `INSIDE` y episodio `RESOLVED`                                                | Consulta §10                                |
| R09 | Pérdida de conectividad (apagar el equipo o aislarlo)   | La ubicación pasa a obsoleta a los 3 minutos; no se inventa una alerta                     | Captura                                     |
| R10 | Recuperación de conectividad                            | Llegan las lecturas retenidas; no se retrocede el estado                                   | Consulta §10                                |
| R11 | Reasignación a otro paciente                            | La nueva asignación no ve el recorrido anterior                                            | Capturas con dos cuentas                    |
| R12 | `MONITOR` y usuario sin acceso                          | `MONITOR` ve la ubicación; el externo no                                                   | Capturas                                    |

**Resultados observados el 2026-11-22 (no hay evidencia de R04 a R12):**

- **R01:** el equipo se conectó a Traccar a las 17:04:53 UTC, justo después de cargar el servidor, y Traccar lo registró solo. Evidencia: `logs/tracker-server.log` del servidor (no se hizo captura de la interfaz web).
- **R02:** las tramas llegan con estado `A` (válido) cada 60 s, con el equipo a cielo abierto. Evidencia: el mismo log.
- **R03 (parcial):** tras asignar el equipo a un paciente de prueba, la pantalla `/patients/<id>/map` pasó sola de «Aún no hay ubicaciones» a «Lectura recibida hace menos de 1 minuto». No se consultó `locations` por SQL (§10) y no se midió la latencia.
- Las lecturas enviadas antes de asignar el equipo no se guardaron (`UNKNOWN_DEVICE` o `NO_ACTIVE_ASSIGNMENT`), como está previsto.
- **R04 (parcial):** con la clave de Maps puesta, el mapa del paciente mostró el marcador y el recorrido. El mapa se ve con la marca «For development purposes only» y el error `BillingNotEnabledMapError`, porque el proyecto de Google Cloud no tiene la facturación activa.
- **R05, R06 y R08 (observados a escala de minutos):** con una geocerca de 100 m centrada en el equipo, una salida a pie y en vehículo y el regreso, el registro de Traccar mostró la primera lectura a más de 100 m a las 18:19:57 UTC y la segunda a las 18:20:58. La app registró el episodio «Confirmada 2:20 p. m.» (hora local, UTC-4) y lo resolvió a las 2:42 p. m., tras volver dentro de la zona (primera lectura dentro 18:41:06, segunda 18:42:07). El episodio aparece en `/alerts` como «Episodio finalizado». La distancia máxima fue de unos 2,5 km. **No se midió la latencia** entre la lectura y el episodio (no se ejecutó la consulta de §10) y no se vio el episodio abierto en vivo, solo ya resuelto.
- **R07 (Web Push), R09, R10, R11 y R12:** no se probaron. En el navegador usado no había una suscripción de notificaciones activa.

## 10. Consultas de evidencia y latencia (editor SQL, solo lectura)

Lecturas del paciente, con el retraso entre la captura del fix y su guardado:

```sql
select l.id, l.source, l.geofence_relation,
  to_char(l.recorded_at at time zone 'utc', 'HH24:MI:SS.MS') as fix_utc,
  to_char(l.received_at at time zone 'utc', 'HH24:MI:SS.MS') as guardado_utc,
  round(extract(epoch from (l.received_at - l.recorded_at)) * 1000)::int as retraso_ms
from public.locations l
join public.device_assignments a on a.id = l.device_assignment_id
where a.patient_id = '<PATIENT_ID>'
order by l.id desc limit 50;
```

Episodios y el tiempo entre la lectura que confirma y la creación del episodio:

```sql
select e.status,
  to_char(e.confirmed_at at time zone 'utc', 'HH24:MI:SS.MS') as confirmado_utc,
  to_char(e.created_at at time zone 'utc', 'HH24:MI:SS.MS') as creado_utc,
  round(extract(epoch from (e.created_at - e.confirmed_at)) * 1000)::int as confirmacion_a_episodio_ms,
  e.resolved_at
from public.alert_episodes e
where e.patient_id = '<PATIENT_ID>' order by e.created_at;
```

Limitaciones de la medición: `recorded_at` es la hora GPS del equipo y `received_at` la del servidor, así que el retraso incluye la red celular y Traccar. El instante en que suena la notificación no se guarda: anótalo desde el teléfono. No calcules latencias que no mediste.

## 11. Si algo falla

| Síntoma                                                  | Qué revisar                                                                                                                                  |
| -------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| Traccar no ve el equipo                                  | APN, cobertura 4G, SIM con datos, servidor y puerto en el equipo. Lee `logs/tracker-server.log` en el servidor: `docker compose logs` solo muestra el arranque y **no** las conexiones. No uses `ss` ni capturas de inicio de conexión (SYN) para decidir: el equipo mantiene una conexión abierta |
| Llegan bytes pero Traccar no decodifica                  | Protocolo equivocado para ese puerto; usa el otro y consulta a Mictrack por el documento Open Protocol                                       |
| `UNKNOWN_DEVICE`                                         | El IMEI no está registrado en Senda (§7) o hay un error al escribirlo                                                                        |
| `NO_ACTIVE_ASSIGNMENT`                                   | El equipo no está asignado a un paciente                                                                                                     |
| `PREDATES_ASSIGNMENT`                                    | Lectura capturada antes de la asignación; es el comportamiento esperado para proteger el historial                                           |
| `401` en la función                                      | El secreto de Traccar no coincide con `SENDA_INGEST_SECRET`; vuelve a renderizar la configuración                                            |
| La posición no aparece (`valid = false`)                 | Sin fix GPS: la función la ignora con `202 IGNORED`. Sácalo a cielo abierto                                                                  |
| Hay posiciones pero no alerta                            | Revisa que exista una geocerca activa y dos lecturas `OUTSIDE` consecutivas con precisión nula o de hasta 100 m                              |

## 12. Seguridad y reversión

- El secreto de ingestión solo vive en Supabase y en `infra/traccar/.env` del servidor (permisos 600). No lo pegues en chats ni capturas.
- La interfaz web de Traccar no se expone a Internet.
- Para cortar la ingestión sin borrar nada: elimina `SENDA_INGEST_SECRET` de los Secrets (la función responde `503`) o desvincula el equipo desde `/patients/<id>/device`.
- Limitación asumida: un solo secreto compartido protege el endpoint; la autenticación individual por dispositivo queda como trabajo futuro.

## 13. Batería del dispositivo (retirada del alcance, 2026-11-22)

Senda **no muestra ni guarda la batería del rastreador**. Se había escrito una implementación basada en un porcentaje (0 a 100) y se retiró sin aplicarse a Supabase.

- **Por qué:** el protocolo oficial del MT710/MT710L (`Mictrack Communication Protocol for MT710 / MT710L V1.0`) informa la batería como **voltaje de respaldo en milivoltios** (`Backup Voltage`; por ejemplo `3815` significa 3,815 V), no como porcentaje. En las tramas reales recibidas por Traccar el 2026-11-22 el valor estuvo entre 3935 y 4093.
- **Evento disponible:** el protocolo define el estado `BLP` («backup battery low voltage») y los estados de carga `PLUG`, `UNPLUG` y `FULL`. No se comprobó si Traccar los reenvía ni con qué nombre de atributo.
- **Si se retoma:** debería partir del voltaje o del evento `BLP`, no de un porcentaje. Convertir voltaje en porcentaje sin datos de descarga reales no es fiable.
