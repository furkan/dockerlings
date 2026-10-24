#!/bin/bash
set -euo pipefail
source ../checker_lib.sh

IMAGE_NAME="dockerlings-core-06-test"
CONTAINER_NAME="core-06-checker"
HOST_PORT=8006
EXPECTED_PORT="8000"
EXPECTED_LABEL_KEY="org.dockerlings.author"
EXPECTED_TEXT="Hello from a configurable app!"

IMAGES_TO_CLEAN+=("$IMAGE_NAME")
CONTAINERS_TO_CLEAN+=("$CONTAINER_NAME")

require_file "Dockerfile"

build_image "$IMAGE_NAME"

log_info "Checking for '$EXPECTED_LABEL_KEY' LABEL in the image..."
LABEL_VALUE=$(docker inspect --format='{{index .Config.Labels "'"$EXPECTED_LABEL_KEY"'"}}' "$IMAGE_NAME")
if [ -z "$LABEL_VALUE" ]; then
  log_fail "Could not find the label '$EXPECTED_LABEL_KEY' in the image." "Did you add the LABEL instruction to your Dockerfile? e.g., LABEL $EXPECTED_LABEL_KEY=\"your.name@example.com\""
fi
log_success "LABEL found."

log_info "Checking for 'PORT' ENV variable..."
if ! docker inspect --format='{{.Config.Env}}' "$IMAGE_NAME" | grep -q "PORT=$EXPECTED_PORT"; then
  log_fail "The ENV variable 'PORT' is not set to '$EXPECTED_PORT'." "Did you add 'ENV PORT=$EXPECTED_PORT' to your Dockerfile?"
fi
log_success "ENV variable is correct."

log_info "Checking for 'EXPOSE $EXPECTED_PORT'..."
if ! docker inspect --format='{{json .Config.ExposedPorts}}' "$IMAGE_NAME" | grep -Fq "\"$EXPECTED_PORT/tcp\""; then
  log_fail "Port $EXPECTED_PORT is not exposed in the image metadata." "Did you add 'EXPOSE $EXPECTED_PORT' to your Dockerfile?"
fi
log_success "EXPOSE instruction found."

log_info "Running the container..."
docker run -d --name "$CONTAINER_NAME" -p "$HOST_PORT":"$EXPECTED_PORT" "$IMAGE_NAME" >/dev/null

check_web_endpoint "$HOST_PORT" "$EXPECTED_TEXT" "$CONTAINER_NAME"
