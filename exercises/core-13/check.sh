#!/bin/bash
set -euo pipefail
source ../checker_lib.sh

COMPOSE_FILE="docker-compose.yml"
WEB_CONTAINER_NAME="c13-web"
REDIS_CONTAINER_NAME="c13-redis"
HOST_PORT="8013"

cleanup() {
  log_info "Shutting down Docker Compose project..."
  if [ -f "$COMPOSE_FILE" ]; then
    docker compose down -v --rmi local --remove-orphans >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

require_file "$COMPOSE_FILE"

log_info "Running 'docker compose up -d --build'..."
if ! docker compose up -d --build; then
  log_fail "'docker compose up' command failed." "Check the syntax of your '$COMPOSE_FILE' and the Dockerfile in the 'app/' directory."
fi

for name in "$WEB_CONTAINER_NAME" "$REDIS_CONTAINER_NAME"; do
  assert_container_running "$name"
done

log_info "Waiting for web app to connect to Redis..."
sleep 3

log_info "Checking web app functionality..."
if ! RESPONSE_1=$(curl -sS "http://localhost:$HOST_PORT"); then
  log_fail "Could not reach the web app on port $HOST_PORT." "Check the port mapping in '$COMPOSE_FILE' and inspect the logs with 'docker compose logs web'."
fi
if ! echo "$RESPONSE_1" | grep -q "visited 1 times"; then
  log_fail "The web app did not return the expected first visit message. Response was: '$RESPONSE_1'" "Is the web app connected to Redis? Check the logs with 'docker compose logs web'."
fi
log_success "First visit successful."

if ! RESPONSE_2=$(curl -sS "http://localhost:$HOST_PORT"); then
  log_fail "Could not reach the web app on port $HOST_PORT after the first request." "Check the container logs with 'docker compose logs web' and confirm the service is still running."
fi
if ! echo "$RESPONSE_2" | grep -q "visited 2 times"; then
  log_fail "The web app did not return the expected second visit message. Response was: '$RESPONSE_2'" "This indicates a problem with the Redis connection or data persistence."
fi
log_success "The multi-service application is working correctly."
