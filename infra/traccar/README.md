# Traccar para el GPS Mictrack MT710L-LA

Receptor TCP que decodifica el protocolo del rastreador y reenvía cada posición a la Edge Function `ingest-device-location` de Supabase. Contexto completo en [`docs/10-INTEGRACION-GPS-FISICO.md`](../../docs/10-INTEGRACION-GPS-FISICO.md).

**Estado:** la configuración se probó en local con Traccar 6.17.0 y un dispositivo de prueba OsmAnd. El 2026-11-22 se desplegó en un VPS de DigitalOcean (NYC3) y el equipo real conectó y reportó posiciones por el puerto `5030` (`tlt2h`), sin errores en `logs/tracker-server.log`. El puerto `5191` no se usó. El VPS es temporal. Para ver las conexiones lee `logs/tracker-server.log`: `docker compose logs` solo muestra el arranque.

## Qué necesitas

- Un VPS con **IPv4 pública** y Linux (por ejemplo Ubuntu LTS). La memoria necesaria no se ha medido: empieza con 1 GB o más y ajusta si Java se queda sin memoria.
- Docker con el plugin Compose, `git` y `envsubst` (paquete `gettext-base`).
- Tu `SENDA_INGEST_SECRET`, el mismo que está en los Secrets de Edge Functions de Supabase.

## Despliegue

```sh
# 1. Firewall: solo SSH y los dos puertos del rastreador.
sudo ufw allow OpenSSH
sudo ufw allow 5030/tcp
sudo ufw allow 5191/tcp
sudo ufw enable

# 2. Código y configuración.
git clone <url-del-repositorio> senda && cd senda/infra/traccar
cp .env.example .env
nano .env                 # SENDA_INGEST_URL y SENDA_INGEST_SECRET reales
./render-config.sh        # genera conf/traccar.xml con permisos 600

# 3. Arranque.
docker compose up -d
docker compose logs -f traccar
```

Comprueba desde **tu PC** (no desde el servidor) que los puertos son alcanzables:

```sh
npm run check:gps-readiness -- --traccar-host <ip-o-dominio>
```

## Puertos

| Puerto | Protocolo Traccar | Exposición                         |
| ------ | ----------------- | ---------------------------------- |
| `5030` | `tlt2h`           | Público (el rastreador se conecta) |
| `5191` | `mictrack`        | Público (alternativa)              |
| `8082` | Interfaz web      | Solo `127.0.0.1`, por túnel SSH    |

La lista de dispositivos de Traccar incluye el MT710 con ambos protocolos y no indica cuál es el vigente. Configura el equipo con `5030`; si en 10 minutos no llega nada, cambia a `5191`.

## Interfaz de administración

```sh
ssh -L 8082:127.0.0.1:8082 usuario@<servidor>
# abre http://localhost:8082
```

La primera cuenta que se crea es la administradora. Después, **desactiva el registro abierto** en los ajustes del servidor (comprueba el nombre exacto de la opción en la interfaz de tu versión). La interfaz nunca debe quedar abierta a Internet.

## Decisiones y límites

- `database.registerUnknown = true`: cualquier IMEI que se conecte se crea en Traccar. La autoridad es el registro de Senda: un IMEI no registrado allí recibe `UNKNOWN_DEVICE` y no se guarda nada. Si prefieres cerrar esa puerta, ponlo en `false` y registra el equipo a mano en la interfaz.
- `forward.retry.enable = true`: Traccar reintenta si la función no responde `2xx`. La función responde `2xx` a todo rechazo permanente y `500` solo ante fallos transitorios, así que no hay tormentas de reintentos.
- La documentación de Traccar no indica si la cola de reintentos es persistente. Si el servidor se reinicia, puede perder las posiciones pendientes.
- La imagen está fijada por resumen (`sha256`) a Traccar 6.17.0. Para actualizar, cambia el resumen en `docker-compose.yml` tras probar la nueva versión.
- Copia de seguridad: guarda `data/` (base H2 de Traccar). `conf/traccar.xml` contiene el secreto y no se versiona.

## Reconfigurar tras rotar el secreto

Cambia el valor en Supabase y en `.env` del servidor, ejecuta `./render-config.sh` y `docker compose restart traccar`.
