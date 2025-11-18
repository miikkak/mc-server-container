#!/usr/bin/env bash
# shellcheck shell=bash
# Custom Minecraft/Velocity Server Container Entrypoint
set -euo pipefail

FUNCTIONS="/scripts/functions.sh"
if [[ -r "$FUNCTIONS" ]]; then
  # shellcheck source=./functions.sh
  . "$FUNCTIONS"
else
  echo "❌ Fatal: common library not found: $FUNCTIONS" >&2
  exit 1
fi

# Set UTF-8 locale for proper unicode/emoji character display in console logs
# Use C.UTF-8 which provides UTF-8 support without language-specific behavior
# Only set LANG - system will derive other LC_* variables automatically
export LANG="C.UTF-8"

cd /data

# ============================================================================
# Validation
# ============================================================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎮 Custom Minecraft/Velocity Server Container"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Detect server JAR
if ! detect_server_jar; then
  echo "❌ ERROR: neither Paper nor Velocity found"
  echo ""
  echo "Download Paper or Velocity to /data before starting the server"
  echo "Visit: https://papermc.io/downloads"
  echo ""
  exit 1
fi

echo "✅ Server (${TYPE}) JAR found: ${JAR}"

# Validate EULA for Paper servers
if [[ "${TYPE}" == "paper" ]]; then
  if ! validate_paper_eula; then
    exit 1
  fi
  echo "✅ EULA accepted"
fi

# ============================================================================
# Build Java Command
# ============================================================================

MEMORY="${MEMORY:-16G}"

# Build JVM options as array
declare -a JAVA_OPTS=()
build_java_opts JAVA_OPTS "${TYPE}" "${MEMORY}"

# ============================================================================
# RCON Configuration
# ============================================================================

setup_rcon_password

# ============================================================================
# Startup Information
# ============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Configuration Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Memory:       ${MEMORY}"
echo "Java:         $(java -version 2>&1 | head -n1)"

# Follow symlinks (-L) to get actual JAR size and modification date
if [[ -f "${JAR}" ]] || [[ -L "${JAR}" ]]; then
  JAR_SIZE=$(du -Lh "${JAR}" 2>/dev/null | cut -f1)
  JAR_DATE=$(stat -L -c '%y' "${JAR}" 2>/dev/null | cut -d' ' -f1)
  echo "Server JAR:   ${JAR_SIZE} (modified: ${JAR_DATE})"
else
  echo "Server JAR:   not found"
fi

# Count only JAR files in plugins/ directory (not in subdirectories)
# Only relevant for Paper servers
if [[ "${TYPE}" == "paper" ]]; then
  if [[ -d plugins ]]; then
    PLUGIN_COUNT=$(find plugins -maxdepth 1 -name '*.jar' -type f 2>/dev/null | wc -l)
  else
    PLUGIN_COUNT=0
  fi
  echo "Plugins:      ${PLUGIN_COUNT} found"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🚀 Starting server..."
echo ""

# ============================================================================
# Start Server with mc-server-runner
# ============================================================================

# Configurable shutdown delays (similar to itzg)
# STOP_SERVER_ANNOUNCE_DELAY: Optional delay after announcing shutdown (default: none)
#   - If set, announces "Server shutting down in X seconds" and waits
#   - If unset, stops immediately without announcement (similar to itzg)
# STOP_DURATION: Max time to wait for graceful shutdown after stop command (default: 60s)

# Build mc-server-runner arguments as array
declare -a MC_SERVER_RUNNER_ARGS=(
  "--named-pipe" "/tmp/minecraft-console"
)

# Only add announce delay if explicitly configured
if [[ -n "${STOP_SERVER_ANNOUNCE_DELAY:-}" ]]; then
  MC_SERVER_RUNNER_ARGS+=(
    "--stop-server-announce-delay" "${STOP_SERVER_ANNOUNCE_DELAY}"
  )
fi

# Always include stop duration
MC_SERVER_RUNNER_ARGS+=(
  "--stop-duration" "${STOP_DURATION:-60s}"
)

# Server-specific arguments
if [[ "${TYPE}" == "paper" ]]; then
  declare -a ADDL_OPTS=("--nogui")
else
  declare -a ADDL_OPTS=()
fi

# Set umask, in the host side anyone in the minecraft group would be able to
# edit the config files and update plugins etc.
umask 002

exec mc-server-runner \
  "${MC_SERVER_RUNNER_ARGS[@]}" \
  java \
  "${JAVA_OPTS[@]}" \
  -jar "${JAR}" "${ADDL_OPTS[@]}"
