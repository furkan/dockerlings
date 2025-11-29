#!/bin/bash
set -euo pipefail
source ../checker_lib.sh

VOLUME_DIR_HOST_ABSOLUTE="$(pwd)/pgdata"
VOLUME_DIR_CONTAINER="/var/lib/postgresql/data"
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

log_info "Checking for 'pgdata' directory..."
if [ ! -d "$VOLUME_DIR_HOST_ABSOLUTE" ]; then
  log_fail "The 'pgdata' directory was not found." "Did you create the directory with 'mkdir pgdata' before running the container?"
fi
log_success "'pgdata' directory found."

log_info "Starting a checker container on the same 'pgdata' directory..."
docker run -d \
  --name $CHECKER_CONTAINER_NAME \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -v "$VOLUME_DIR_HOST_ABSOLUTE":"$VOLUME_DIR_CONTAINER" \
  postgres:16 >/dev/null

wait_for_postgres "$CHECKER_CONTAINER_NAME"

log_info "Verifying that the correct data has persisted..."
QUERY="SELECT title FROM $TABLE_NAME WHERE title = '$EXPECTED_ROW_CONTENT';"
OUTPUT=$(docker exec "$CHECKER_CONTAINER_NAME" psql -U postgres -tA -c "$QUERY")

if [ "$OUTPUT" == "$EXPECTED_ROW_CONTENT" ]; then
  log_success "The database row was found in the new container. The volume worked!"
else
  log_fail "The expected database row was not found." "Did you run the 'CREATE TABLE' and 'INSERT' commands exactly as specified in the hint?"
fi
