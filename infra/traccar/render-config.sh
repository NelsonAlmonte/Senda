#!/usr/bin/env bash
# Renders conf/traccar.xml from the template and the values in infra/traccar/.env.
set -euo pipefail

cd "$(dirname "$0")"

if [ ! -f .env ]; then
	echo "Missing infra/traccar/.env. Copy .env.example and fill it in." >&2
	exit 1
fi

set -a
# shellcheck disable=SC1091
. ./.env
set +a

: "${SENDA_INGEST_URL:?SENDA_INGEST_URL is required}"
: "${SENDA_INGEST_SECRET:?SENDA_INGEST_SECRET is required}"

case "$SENDA_INGEST_URL" in
	https://*) ;;
	*) echo "SENDA_INGEST_URL must start with https://" >&2; exit 1 ;;
esac

if [ "${#SENDA_INGEST_SECRET}" -lt 32 ]; then
	echo "SENDA_INGEST_SECRET must contain at least 32 characters." >&2
	exit 1
fi

# The secret is embedded in XML: reject characters that would break or alter the document.
case "$SENDA_INGEST_SECRET" in
	*[\<\>\&\'\"\$]*) echo "SENDA_INGEST_SECRET must not contain < > & ' \" or \$." >&2; exit 1 ;;
esac

mkdir -p conf data logs
umask 077
envsubst '${SENDA_INGEST_URL} ${SENDA_INGEST_SECRET}' < traccar.xml.template > conf/traccar.xml
chmod 600 conf/traccar.xml
echo "conf/traccar.xml rendered (permissions 600). Start with: docker compose up -d"
