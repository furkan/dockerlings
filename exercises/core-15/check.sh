#!/bin/bash
set -euo pipefail
source ../checker_lib.sh

USER_IMAGE_NAME="dockerlings-core-15-user"
NAIVE_IMAGE_NAME="dockerlings-core-15-naive"
CONTAINER_NAME="core-15-checker"
HOST_PORT=8015
EXPECTED_TEXT="Hello from a Go multi-stage build!"

IMAGES_TO_CLEAN+=("$USER_IMAGE_NAME" "$NAIVE_IMAGE_NAME")
CONTAINERS_TO_CLEAN+=("$CONTAINER_NAME")

require_file "Dockerfile"
require_file "app/main.go"

log_info "Building your multi-stage Dockerfile..."
build_image "$USER_IMAGE_NAME"

log_info "Building a naive single-stage image for size comparison..."
NAIVE_DOCKERFILE_CONTENT=$(
  cat <<EOF
FROM golang:1.21-alpine
WORKDIR /src
COPY app/ .
RUN go build -o /server .
EXPOSE 8080
CMD ["/server"]
EOF
)
echo "$NAIVE_DOCKERFILE_CONTENT" > ./temp-dockerfile
if ! docker build -t "$NAIVE_IMAGE_NAME" -f temp-dockerfile .; then
  log_fail "Failed to build the naive comparison image." "This is an issue with the checker script."
fi
rm temp-dockerfile

log_info "Comparing image sizes..."
USER_SIZE=$(docker inspect --format='{{.Size}}' "$USER_IMAGE_NAME")
NAIVE_SIZE=$(docker inspect --format='{{.Size}}' "$NAIVE_IMAGE_NAME")

USER_SIZE_MB=$(echo "scale=2; $USER_SIZE / 1024 / 1024" | bc)
NAIVE_SIZE_MB=$(echo "scale=2; $NAIVE_SIZE / 1024 / 1024" | bc)

log_info "Your image size: ${USER_SIZE_MB}MB. Naive image size: ${NAIVE_SIZE_MB}MB."

if [ "$USER_SIZE" -ge $((NAIVE_SIZE / 2)) ]; then
  log_fail "Your final image is not significantly smaller than a single-stage build." "A good multi-stage build should be a fraction of the size of an image that includes the Go SDK."
fi
log_success "Image size reduction is significant!"

log_info "Running container from your image to test functionality..."
docker run -d --name "$CONTAINER_NAME" -p "$HOST_PORT":8080 "$USER_IMAGE_NAME" >/dev/null

check_web_endpoint "$HOST_PORT" "$EXPECTED_TEXT" "$CONTAINER_NAME"
