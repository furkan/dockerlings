#!/bin/bash

# --- Colorized Logging & Error Handling ---
# Provides standardized, colored output for script execution.

# Color constants
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Usage: log_success "Message"
log_success() {
  echo -e "${GREEN}✅ Success: $1${NC}"
}

# Usage: log_fail "Message" ["Hint"]
log_fail() {
  echo -e "${RED}❌ Failed: $1${NC}"
  if [ -n "${2:-}" ]; then
    echo "Hint: $2"
  fi
  exit 1
}

# Usage: log_info "Message"
log_info() {
  echo -e "${YELLOW}--> $1${NC}"
}

# --- Prerequisite Checks ---

# Usage: require_file "Dockerfile"
require_file() {
  if [ ! -f "$1" ]; then
    log_fail "'$1' not found in this directory."
  fi
}

# --- Docker Interaction Functions ---

# Usage: build_image "image_name"
build_image() {
  log_info "Building image '$1' from Dockerfile..."
  if ! docker build -t "$1" .; then
    log_fail "Docker image build failed." "Check the syntax of your Dockerfile."
  fi
  log_info "Image built successfully."
}

# Usage: assert_container_running "container_name"
assert_container_running() {
  log_info "Checking for running container '$1'..."
  if ! docker ps --filter "name=^$1$" --filter "status=running" | grep -q "$1"; then
    log_fail "Container '$1' is not running." "Did you use the correct '--name' flag in your 'docker run' or 'container_name' in your compose file?"
  fi
  log_info "Container '$1' is running."
}

# Usage: check_web_endpoint "host_port" "expected_text" ["container_name_for_logs"]
check_web_endpoint() {
  local port="$1"
  local expected_text="$2"
  local container_for_logs="${3:-}"
  local url="http://localhost:$port"

  log_info "Waiting for application..."
  sleep 3 # A simple static wait

  if [ -n "$container_for_logs" ] && ! docker ps --filter "name=^$container_for_logs$" --filter "status=running" | grep -q "$container_for_logs"; then
    docker logs "$container_for_logs"
    log_fail "Container '$container_for_logs' exited prematurely." "Check for runtime errors, e.g., missing dependencies in minimal base image."
  fi
  log_info "Checking response from $url..."
  if curl -s --fail "$url" | grep -q "$expected_text"; then
    log_success "Application responded correctly."
  else
    if [ -n "$container_for_logs" ]; then
      echo "Container logs for '$container_for_logs':"
      docker logs "$container_for_logs"
    fi
    log_fail "Application did not respond as expected." "Check your application's logs and ensure it's running correctly."
  fi
}

# --- Generic Cleanup ---
# Scripts can add resource names to these arrays for automatic cleanup on exit.

declare -a CONTAINERS_TO_CLEAN=("${CONTAINERS_TO_CLEAN[@]:-}")
declare -a IMAGES_TO_CLEAN=("${IMAGES_TO_CLEAN[@]:-}")
declare -a NETWORKS_TO_CLEAN=("${NETWORKS_TO_CLEAN[@]:-}")
declare -a COMPOSE_PROJECTS_TO_CLEAN=("${COMPOSE_PROJECTS_TO_CLEAN[@]:-}")

cleanup() {
  log_info "Cleaning up resources..."
  for container in "${CONTAINERS_TO_CLEAN[@]}"; do
    docker stop "$container" >/dev/null 2>&1 || true
    docker rm "$container" >/dev/null 2>&1 || true
  done
  for image in "${IMAGES_TO_CLEAN[@]}"; do
    docker rmi "$image" >/dev/null 2>&1 || true
  done
  for network in "${NETWORKS_TO_CLEAN[@]}"; do
    docker network rm "$network" >/dev/null 2>&1 || true
  done
  for project_dir in "${COMPOSE_PROJECTS_TO_CLEAN[@]}"; do
    if [ -f "$project_dir/docker-compose.yml" ]; then
      (cd "$project_dir" && docker compose down -v --remove-orphans >/dev/null 2>&1) || true
    fi
  done
}
trap cleanup EXIT
