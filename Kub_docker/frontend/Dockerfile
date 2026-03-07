# Stage 1: Build Flutter web app
FROM ghcr.io/cirruslabs/flutter:latest AS build

WORKDIR /app

# Copy pubspec files first for dependency caching
COPY FrontEnd/pubspec.yaml FrontEnd/pubspec.lock /app/

RUN flutter pub get

# Copy the rest of the source
COPY FrontEnd/ /app/

# Generate .env from build args (flutter_dotenv bundles it as an asset)
ARG API_BASE_URL=http://localhost:8000
ARG FIREBASE_API_KEY
ARG FIREBASE_AUTH_DOMAIN
ARG FIREBASE_PROJECT_ID
ARG FIREBASE_STORAGE_BUCKET
ARG FIREBASE_MESSAGING_SENDER_ID
ARG FIREBASE_APP_ID
ARG FIREBASE_MEASUREMENT_ID
ARG MAPBOX_ACCESS_TOKEN

RUN printf '%s\n' \
  "API_BASE_URL=${API_BASE_URL}" \
  "FIREBASE_API_KEY=${FIREBASE_API_KEY}" \
  "FIREBASE_AUTH_DOMAIN=${FIREBASE_AUTH_DOMAIN}" \
  "FIREBASE_PROJECT_ID=${FIREBASE_PROJECT_ID}" \
  "FIREBASE_STORAGE_BUCKET=${FIREBASE_STORAGE_BUCKET}" \
  "FIREBASE_MESSAGING_SENDER_ID=${FIREBASE_MESSAGING_SENDER_ID}" \
  "FIREBASE_APP_ID=${FIREBASE_APP_ID}" \
  "FIREBASE_MEASUREMENT_ID=${FIREBASE_MEASUREMENT_ID}" \
  "MAPBOX_ACCESS_TOKEN=${MAPBOX_ACCESS_TOKEN}" \
  > /app/.env

# Build web release
RUN flutter build web --release

# Stage 2: Serve with nginx
FROM nginx:1.27-alpine

RUN rm /etc/nginx/conf.d/default.conf

COPY Kub_docker/frontend/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
