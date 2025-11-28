#!/bin/bash
set -euo pipefail
source ../checker_lib.sh

USER_FILE="container-info.txt"
CHECKER_CONTAINER_NAME="c4-checker-temp"

CONTAINERS_TO_CLEAN+=("$CHECKER_CONTAINER_NAME")

require_file "$USER_FILE"

log_info "Verifying content by running a fresh Nginx container..."
docker run -d --name $CHECKER_CONTAINER_NAME nginx >/dev/null
sleep 1
EXPECTED_CONTENT=$(docker exec $CHECKER_CONTAINER_NAME nginx -v 2>&1)
EXPECTED_VERSION=$(echo "$EXPECTED_CONTENT" | grep -E -o 'nginx version: nginx/[0-9]+\.[0-9]+\.[0-9]+' || echo "")
ACTUAL_CONTENT=$(cat "$USER_FILE")
ACTUAL_VERSION=$(echo "$ACTUAL_CONTENT" | grep -E -o 'nginx version: nginx/[0-9]+\.[0-9]+\.[0-9]+' || echo "")
if [ "$ACTUAL_VERSION" == "$EXPECTED_VERSION" ] && [ -n "$EXPECTED_VERSION" ]; then
  log_success "The file '$USER_FILE' exists and contains the correct Nginx version info."
  rm -f "$USER_FILE"
else
  log_fail "The content of '$USER_FILE' is incorrect or does not match expected version." "Expected version like: '$EXPECTED_VERSION', Got: '$ACTUAL_VERSION'"
fi
