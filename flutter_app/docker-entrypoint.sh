#!/bin/sh
set -eu

: "${BACKEND_ORIGIN:?BACKEND_ORIGIN is required (e.g. https://structura-backend.onrender.com)}"

# Strip scheme + trailing slash to get just the host (for Host header / SNI).
BACKEND_HOST=$(printf '%s' "$BACKEND_ORIGIN" | sed -E 's#^https?://##; s#/.*$##')
export BACKEND_HOST

envsubst '${BACKEND_ORIGIN} ${BACKEND_HOST}' \
  < /etc/nginx/templates/default.conf.template \
  > /etc/nginx/conf.d/default.conf

exec nginx -g 'daemon off;'
