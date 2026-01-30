#!/bin/bash
set -euo pipefail
source ../checker_lib.sh

VOLUME_NAME="pgdata"
CONTAINER_DATA_PATH="/var/lib/postgresql/data"
CHECKER_CONTAINER_NAME="c8-checker-postgres"
TABLE_NAME="dvd_rentals"
EXPECTED_ROW_CONTENT="The Grand Budapest Hotel"

# The library's cleanup trap will handle removing this container
CONTAINERS_TO_CLEAN+=("$CHECKER_CONTAINER_NAME")

wait_for_postgres() {
  local container_name=$1
  log_info "Waiting for database in '$container_name' to be ready..."
  for i in {1..20}; do
    if docker logs "$container_name" 2>&1 | grep -q "database system is ready to accept connections"; then
      log_info "Database is ready."
      sleep 2 # A small delay to prevent race conditions
      return 0
    fi
    sleep 1
  done
  log_fail "Database in '$container_name' did not become ready in time."
}

log_info "Checking if Docker volume '$VOLUME_NAME' exists..."
if ! docker volume inspect "$VOLUME_NAME" >/dev/null 2>&1; then
  log_fail "The Docker volume '$VOLUME_NAME' was not found." "Did you create it using 'docker volume create $VOLUME_NAME'?"
fi
log_success "Volume '$VOLUME_NAME' found."

log_info "Starting a checker container using the '$VOLUME_NAME' volume..."
# We run a fresh container attached to the user's volume to verify persistence
docker run -d \
  --name "$CHECKER_CONTAINER_NAME" \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -v "$VOLUME_NAME":"$CONTAINER_DATA_PATH" \
  postgres:16 >/dev/null

wait_for_postgres "$CHECKER_CONTAINER_NAME"

log_info "Verifying data persistence inside the volume..."
QUERY="SELECT title FROM $TABLE_NAME WHERE title = '$EXPECTED_ROW_CONTENT';"
OUTPUT=$(docker exec "$CHECKER_CONTAINER_NAME" psql -U postgres -tA -c "$QUERY" 2>/dev/null || echo "QUERY_FAILED")

if [ "$OUTPUT" == "$EXPECTED_ROW_CONTENT" ]; then
  log_success "The database row was found in the checker container. The named volume is working correctly!"
elif [ "$OUTPUT" == "QUERY_FAILED" ]; then
  log_fail "Could not query the database." "Ensure the table '$TABLE_NAME' was created correctly inside the container."
else
  log_fail "The expected database row was not found." "Expected: '$EXPECTED_ROW_CONTENT', Got: '$OUTPUT'"
fi
