#!/usr/bin/env bash
# Wrapper script for hadolint that works with local binary, Docker, or Podman
# Automatically detects which method is available (prefers local installation)
set -euo pipefail

# Detect hadolint method - prefer local binary, fall back to containers
USE_LOCAL=false
CONTAINER_CMD=""

if command -v hadolint &>/dev/null; then
  # Local hadolint binary found
  USE_LOCAL=true
elif command -v docker &>/dev/null && docker info &>/dev/null; then
  CONTAINER_CMD="docker"
elif command -v podman &>/dev/null && podman info &>/dev/null; then
  CONTAINER_CMD="podman"
elif command -v podman &>/dev/null && sudo podman info &>/dev/null; then
  CONTAINER_CMD="sudo podman"
else
  echo "Error: hadolint not found. Install hadolint locally or install docker/podman." >&2
  exit 1
fi

# Parse hadolint arguments and files
hadolint_args=()
files=()

for arg in "$@"; do
  if [[ "$arg" == --* ]]; then
    hadolint_args+=("$arg")
  elif [[ -f "$arg" ]]; then
    files+=("$arg")
  fi
done

exit_code=0

# Run hadolint for each Dockerfile
if [ "$USE_LOCAL" = true ]; then
  # Use local hadolint binary - it can handle files directly
  for file in "${files[@]}"; do
    if ! hadolint "${hadolint_args[@]}" "$file"; then
      exit_code=1
    fi
  done
else
  # Use container runtime - needs stdin
  for file in "${files[@]}"; do
    # Use eval to properly handle CONTAINER_CMD with sudo
    # Must explicitly call /bin/hadolint when passing args (otherwise args replace CMD entirely)
    if ! eval "$CONTAINER_CMD run --rm -i docker.io/hadolint/hadolint:latest /bin/hadolint $(printf '%q ' "${hadolint_args[@]}") -" <"$file"; then
      exit_code=1
    fi
  done
fi

exit $exit_code
