#!/usr/bin/env bash
# Wrapper script for shellcheck that mimics GitHub Actions behavior
# Changes into each script's directory before running shellcheck
set -euo pipefail

exit_code=0

for file in "$@"; do
  dir=$(dirname "$file")
  filename=$(basename "$file")

  if ! (cd "$dir" && shellcheck --external-sources "$filename"); then
    exit_code=1
  fi
done

exit "$exit_code"
