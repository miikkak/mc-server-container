#!/usr/bin/env bash
# mc-send-to-console.sh - Send commands to Minecraft server console via named pipe
#
# Usage: mc-send-to-console.sh <command>
# Example: mc-send-to-console.sh "say Hello players!"

set -euo pipefail

PIPE_PATH="/tmp/minecraft-console"

if [ $# -eq 0 ]; then
  echo "Usage: mc-send-to-console.sh <command>"
  echo "Example: mc-send-to-console.sh \"say Hello!\""
  exit 1
fi

if [ ! -p "$PIPE_PATH" ]; then
  echo "Error: Named pipe not found at $PIPE_PATH"
  echo "Is the server running?"
  exit 1
fi

echo "$*" >"$PIPE_PATH"
