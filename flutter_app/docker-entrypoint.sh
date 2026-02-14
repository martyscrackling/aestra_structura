#!/bin/sh
set -eu

: "${BACKEND_ORIGIN:?BACKEND_ORIGIN is required (e.g. https://structura-backend.onrender.com)}"

envsubst '${BACKEND_ORIGIN}' < /etc/nginx/templates/default.conf.template > /etc/nginx/conf.d/default.conf

exec nginx -g 'daemon off;'
