#!/bin/bash
set -euo pipefail
source ../checker_lib.sh

COMPOSE_FILE="docker-compose.yml"
WEB_CONTAINER_NAME="c14-web"
REDIS_CONTAINER_NAME="c14-redis"
HOST_PORT="8014"
NETWORK_NAME="c14-app-net"
# Compose prepends the project name (directory name) to networks and volumes
PROJECT_NAME=$(basename "$PWD")
COMPOSE_NETWORK_NAME="${PROJECT_NAME}_${NETWORK_NAME}"
COMPOSE_VOLUME_NAME="${PROJECT_NAME}_redis-data"

cleanup() {
  log_info "Shutting down Docker Compose project..."
  if [ -f "$COMPOSE_FILE" ]; then
    # -v removes named volumes, --rmi removes images
    docker compose down -v --rmi local --remove-orphans >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

require_file "$COMPOSE_FILE"

log_info "Running 'docker compose up -d --build' for the first time..."
if ! docker compose up -d --build; then
  log_fail "'docker compose up' command failed." "Check the syntax of your '$COMPOSE_FILE' and the Dockerfile in the 'app/' directory."
fi

for name in "$WEB_CONTAINER_NAME" "$REDIS_CONTAINER_NAME"; do
  assert_container_running "$name"
done

log_info "Waiting for web app to connect to Redis..."
sleep 3

log_info "Verifying services are on the custom network..."
for name in "$WEB_CONTAINER_NAME" "$REDIS_CONTAINER_NAME"; do
  # This inspect command checks if the container is attached to our specific network
  if ! docker inspect --format='{{range $key, $value := .NetworkSettings.Networks}}{{$key}}{{end}}' "$name" | grep -q "$COMPOSE_NETWORK_NAME"; then
    log_fail "Container '$name' is not on the '$NETWORK_NAME' network." "Did you add the 'networks' section to the service definition in '$COMPOSE_FILE'?"
  fi
done
log_success "Both services are connected to the '$NETWORK_NAME' network."

log_info "Verifying a named volume is mounted on the redis container at /data..."
MOUNT_INFO=$(docker inspect --format='{{range .Mounts}}{{if eq .Destination "/data"}}{{.Type}}:{{.Name}}{{end}}{{end}}' "$REDIS_CONTAINER_NAME")
if [[ "$MOUNT_INFO" == "volume:"* ]] && [ -n "$MOUNT_INFO" ]; then
  ACTUAL_VOLUME_NAME=$(echo "$MOUNT_INFO" | cut -d':' -f2)
  log_success "Named volume '$ACTUAL_VOLUME_NAME' is correctly mounted at /data."
else
  log_fail "No named volume found mounted at /data." "Expected a Docker-managed volume (type: volume), Found: '$MOUNT_INFO'"
fi

log_info "Performing persistence test..."
log_info "Accessing web app to increment counter to 1..."
RESPONSE_1=$(curl -s http://localhost:$HOST_PORT)
if ! echo "$RESPONSE_1" | grep -q "visited 1 times"; then
  log_fail "The web app did not return the expected first visit message. Response was: '$RESPONSE_1'" "Is the web app connected to Redis? Check the logs with 'docker compose logs web'."
fi
log_success "First visit successful (count is 1)."

log_info "Bringing services down (preserving volume)..."
docker compose down

log_info "Bringing services back up..."
docker compose up -d
sleep 3 # Give app time to start

log_info "Accessing web app again to check for persisted count..."
RESPONSE_2=$(curl -s http://localhost:$HOST_PORT)
if ! echo "$RESPONSE_2" | grep -q "visited 2 times"; then
  log_fail "The visit counter did not persist. Response was: '$RESPONSE_2'" "This indicates the named volume is not working correctly. Expected counter to be 2."
fi
log_success "The application state persisted correctly across restarts. (count is 2)."
