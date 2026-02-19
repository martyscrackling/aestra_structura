#!/usr/bin/env sh
set -eu

echo "Starting Structura backend…"

TRIES="${MIGRATE_RETRIES:-8}"
SLEEP_SECONDS="${MIGRATE_RETRY_SLEEP_SECONDS:-3}"

i=1
while [ "$i" -le "$TRIES" ]; do
  echo "Running migrations (attempt $i/$TRIES)…"
  if python manage.py migrate --noinput; then
    echo "Migrations OK"
    break
  fi

  if [ "$i" -eq "$TRIES" ]; then
    echo "Migrations failed after $TRIES attempts. Exiting."
    exit 1
  fi

  echo "Migrations failed. Retrying in ${SLEEP_SECONDS}s…"
  sleep "$SLEEP_SECONDS"
  i=$((i + 1))
done

echo "Starting Gunicorn on 0.0.0.0:${PORT:-8000}…"
exec gunicorn structura_backend.wsgi:application --bind 0.0.0.0:"${PORT:-8000}"
