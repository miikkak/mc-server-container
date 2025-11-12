#!/usr/bin/env bash
# Wrapper script for hadolint that works with both Docker and Podman
# Automatically detects which container runtime is available and working
set -euo pipefail

# Detect container runtime - test that it actually works, not just that it exists
CONTAINER_CMD=""

if command -v docker &>/dev/null && docker info &>/dev/null; then
  CONTAINER_CMD="docker"
elif command -v podman &>/dev/null && podman info &>/dev/null; then
  CONTAINER_CMD="podman"
elif command -v podman &>/dev/null && sudo podman info &>/dev/null; then
  CONTAINER_CMD="sudo podman"
else
  echo "Error: No working container runtime found. Install docker or podman." >&2
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

# Run hadolint via container runtime for each Dockerfile
for file in "${files[@]}"; do
  # Use eval to properly handle CONTAINER_CMD with sudo
  # Must explicitly call /bin/hadolint when passing args (otherwise args replace CMD entirely)
  if ! eval "$CONTAINER_CMD run --rm -i docker.io/hadolint/hadolint:latest /bin/hadolint $(printf '%q ' "${hadolint_args[@]}") -" < "$file"; then
    exit_code=1
  fi
done

exit $exit_code
