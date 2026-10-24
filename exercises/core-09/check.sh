#!/bin/bash
set -euo pipefail
source ../checker_lib.sh

USER_CONTAINER_NAME="c9-dev-server"
HOST_PORT=8009
HOST_APP_DIR_ABSOLUTE="$(pwd)/app"
CONTAINER_APP_DIR="/usr/share/nginx/html"
TEST_FILE_PATH="$HOST_APP_DIR_ABSOLUTE/index.html"
ORIGINAL_CONTENT=$(cat "$TEST_FILE_PATH")
BACKUP_FILE="$TEST_FILE_PATH.bak"
cp "$TEST_FILE_PATH" "$BACKUP_FILE"
MODIFIED_CONTENT="<h1>Version 2 - Modified by Checker</h1>"

cleanup_file() {
  log_info "Restoring original file content..."
  if [ -f "$BACKUP_FILE" ]; then
    mv "$BACKUP_FILE" "$TEST_FILE_PATH"
  fi
}
trap cleanup_file EXIT INT TERM

assert_container_running "$USER_CONTAINER_NAME"

log_info "Inspecting the container for the correct read-only bind mount..."
MOUNT_INFO=$(docker inspect --format='{{range .Mounts}}{{if eq .Destination "/usr/share/nginx/html"}}{{.Type}}:{{.RW}}{{end}}{{end}}' "$USER_CONTAINER_NAME")

if [[ "$MOUNT_INFO" != "bind:false" ]]; then
  log_fail "The bind mount is incorrect or not read-only." "Expected a read-only bind mount at '$CONTAINER_APP_DIR'."
fi
log_success "Bind mount is correct and read-only."

log_info "Modifying local file 'app/index.html' to test live update..."
echo "$MODIFIED_CONTENT" >"$TEST_FILE_PATH"
sleep 1

log_info "Checking for live update via bind mount..."
if curl -s --fail http://localhost:$HOST_PORT | grep -q "<h1>Version 2 - Modified by Checker</h1>"; then
  log_success "The container served the updated content immediately. Bind mount is working!"
else
  log_fail "The change to 'app/index.html' was not reflected by the container." "Did you correctly map the local './app' directory to '/usr/share/nginx/html' in the container?"
fi

cleanup_file
