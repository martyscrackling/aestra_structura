# syntax=docker/dockerfile:1

FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

COPY pubspec.yaml pubspec.lock* ./
RUN flutter pub get

COPY . .

# Build Flutter Web using a same-origin API path.
# Nginx will proxy /api/ to the real backend at runtime.
RUN flutter build web --release --dart-define=API_BASE_URL=/api/


FROM nginx:alpine AS runtime

RUN apk add --no-cache gettext

COPY --from=build /app/build/web /usr/share/nginx/html

COPY nginx/default.conf.template /etc/nginx/templates/default.conf.template
COPY docker-entrypoint.sh /docker-entrypoint.sh

RUN chmod +x /docker-entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/docker-entrypoint.sh"]
