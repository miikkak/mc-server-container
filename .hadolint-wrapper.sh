#!/usr/bin/env bash
# Wrapper script for hadolint that works with local binary, Docker, or Podman
# Automatically detects which method is available (prefers local installation)
set -euo pipefail

# Detect hadolint method - prefer local binary, fall back to containers
USE_LOCAL=false
CONTAINER_CMD=""
USE_SUDO=false

if command -v hadolint &>/dev/null; then
  # Local hadolint binary found
  USE_LOCAL=true
elif command -v docker &>/dev/null && docker info &>/dev/null; then
  CONTAINER_CMD="docker"
elif command -v podman &>/dev/null && podman info &>/dev/null; then
  CONTAINER_CMD="podman"
elif command -v podman &>/dev/null && sudo podman info &>/dev/null; then
  CONTAINER_CMD="podman"
  USE_SUDO=true
else
  echo "Error: hadolint not found. Install hadolint locally or install docker/podman." >&2
  exit 1
fi

# Parse hadolint arguments and files
hadolint_args=()
files=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ignore | --format | --config | --trusted-registry)
      # These options require a value argument
      hadolint_args+=("$1")
      shift
      if [[ $# -gt 0 ]]; then
        hadolint_args+=("$1")
        shift
      fi
      ;;
    --*)
      # Other options without values
      hadolint_args+=("$1")
      shift
      ;;
    *)
      # It's a file
      if [[ -f "$1" ]]; then
        files+=("$1")
      fi
      shift
      ;;
  esac
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
  # Build command prefix (empty or sudo)
  cmd_prefix=()
  if [ "$USE_SUDO" = true ]; then
    cmd_prefix=(sudo)
  fi

  for file in "${files[@]}"; do
    # Must explicitly call /bin/hadolint when passing args (otherwise args replace CMD entirely)
    if ! "${cmd_prefix[@]}" "$CONTAINER_CMD" run --rm -i docker.io/hadolint/hadolint:latest /bin/hadolint "${hadolint_args[@]}" - <"$file"; then
      exit_code=1
    fi
  done
fi

exit "$exit_code"
