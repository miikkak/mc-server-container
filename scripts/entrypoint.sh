#!/usr/bin/env bash
# shellcheck shell=bash
# Custom Minecraft Server Container Entrypoint
# Runs Paper server with GraalVM and optimized MeowIce flags

set -euo pipefail

cd /data

# ============================================================================
# Validation
# ============================================================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎮 Custom Minecraft Server Container"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check EULA
if [ ! -f /data/eula.txt ]; then
  echo "❌ ERROR: /data/eula.txt not found"
  echo ""
  echo "Create /data/eula.txt with:"
  echo "  eula=true"
  echo ""
  exit 1
fi

if ! grep -q "eula=true" /data/eula.txt; then
  echo "❌ ERROR: EULA not accepted in /data/eula.txt"
  echo ""
  echo "Edit /data/eula.txt and set:"
  echo "  eula=true"
  echo ""
  exit 1
fi

# Try to find latest paper.jar
if ! latest=$(find /data -maxdepth 1 -type f -name 'paper-*.jar' |
  grep -E 'paper-[0-9]+\.[0-9]+(\.[0-9]+)?-[0-9]+\.jar$' |
  sort -V |
  tail -n 1); then
  # Check Paper JAR
  if [ ! -f /data/paper.jar ]; then
    echo "❌ ERROR: /data/paper.jar not found"
    echo ""
    echo "Download Paper JAR to /data/paper.jar before starting the server"
    echo "Visit: https://papermc.io/downloads"
    echo ""
    exit 1
  else
    JAR="/data/paper.jar"
  fi
else
  JAR="${latest}"
fi

echo "✅ EULA accepted"
echo "✅ Paper JAR found"

# ============================================================================
# Build Java Command
# ============================================================================

# Memory configuration
MEMORY="${MEMORY:-16G}"
JAVA_OPTS="-Xms${MEMORY} -Xmx${MEMORY}"

# ============================================================================
# MeowIce G1GC Flags (Default: ENABLED)
# Source: https://github.com/MeowIce/meowice-flags
# Disable with: DISABLE_MEOWICE_FLAGS=true (for troubleshooting)
# ============================================================================
if [ "${DISABLE_MEOWICE_FLAGS:-false}" != "true" ]; then
  echo "🚀 MeowIce optimization flags: ENABLED"

  # Vector API support
  JAVA_OPTS="$JAVA_OPTS --add-modules=jdk.incubator.vector"

  # G1GC configuration
  JAVA_OPTS="$JAVA_OPTS -XX:+UseG1GC"
  JAVA_OPTS="$JAVA_OPTS -XX:MaxGCPauseMillis=200"
  JAVA_OPTS="$JAVA_OPTS -XX:+UnlockExperimentalVMOptions"
  JAVA_OPTS="$JAVA_OPTS -XX:+UnlockDiagnosticVMOptions"
  JAVA_OPTS="$JAVA_OPTS -XX:+DisableExplicitGC"
  JAVA_OPTS="$JAVA_OPTS -XX:+AlwaysPreTouch"
  JAVA_OPTS="$JAVA_OPTS -XX:G1NewSizePercent=28"
  JAVA_OPTS="$JAVA_OPTS -XX:G1MaxNewSizePercent=50"
  JAVA_OPTS="$JAVA_OPTS -XX:G1HeapRegionSize=16M"
  JAVA_OPTS="$JAVA_OPTS -XX:G1ReservePercent=15"
  JAVA_OPTS="$JAVA_OPTS -XX:G1MixedGCCountTarget=3"
  JAVA_OPTS="$JAVA_OPTS -XX:InitiatingHeapOccupancyPercent=20"
  JAVA_OPTS="$JAVA_OPTS -XX:G1MixedGCLiveThresholdPercent=90"
  JAVA_OPTS="$JAVA_OPTS -XX:SurvivorRatio=32"
  JAVA_OPTS="$JAVA_OPTS -XX:G1HeapWastePercent=5"
  JAVA_OPTS="$JAVA_OPTS -XX:MaxTenuringThreshold=1"
  JAVA_OPTS="$JAVA_OPTS -XX:+PerfDisableSharedMem"
  JAVA_OPTS="$JAVA_OPTS -XX:G1SATBBufferEnqueueingThresholdPercent=30"
  JAVA_OPTS="$JAVA_OPTS -XX:G1ConcMarkStepDurationMillis=5"
  JAVA_OPTS="$JAVA_OPTS -XX:G1RSetUpdatingPauseTimePercent=0"

  # Auto-detect NUMA and enable optimization if available
  # NUMA is typically not available in standard containers, but detect it just in case
  if [ -d /sys/devices/system/node/node1 ]; then
    JAVA_OPTS="$JAVA_OPTS -XX:+UseNUMA"
  fi

  # Compiler optimizations
  JAVA_OPTS="$JAVA_OPTS -XX:-DontCompileHugeMethods"
  JAVA_OPTS="$JAVA_OPTS -XX:MaxNodeLimit=240000"
  JAVA_OPTS="$JAVA_OPTS -XX:NodeLimitFudgeFactor=8000"
  JAVA_OPTS="$JAVA_OPTS -XX:ReservedCodeCacheSize=400M"
  JAVA_OPTS="$JAVA_OPTS -XX:NonNMethodCodeHeapSize=12M"
  JAVA_OPTS="$JAVA_OPTS -XX:ProfiledCodeHeapSize=194M"
  JAVA_OPTS="$JAVA_OPTS -XX:NonProfiledCodeHeapSize=194M"
  JAVA_OPTS="$JAVA_OPTS -XX:NmethodSweepActivity=1"
  JAVA_OPTS="$JAVA_OPTS -XX:+UseFastUnorderedTimeStamps"
  JAVA_OPTS="$JAVA_OPTS -XX:+UseCriticalJavaThreadPriority"
  JAVA_OPTS="$JAVA_OPTS -XX:AllocatePrefetchStyle=3"
  JAVA_OPTS="$JAVA_OPTS -XX:+AlwaysActAsServerClassMachine"

  # Memory optimizations
  JAVA_OPTS="$JAVA_OPTS -XX:+UseTransparentHugePages"
  JAVA_OPTS="$JAVA_OPTS -XX:LargePageSizeInBytes=2M"
  JAVA_OPTS="$JAVA_OPTS -XX:+UseLargePages"
  JAVA_OPTS="$JAVA_OPTS -XX:+EagerJVMCI"
  JAVA_OPTS="$JAVA_OPTS -XX:+UseStringDeduplication"

  # Intrinsics and optimizations
  JAVA_OPTS="$JAVA_OPTS -XX:+UseAES"
  JAVA_OPTS="$JAVA_OPTS -XX:+UseAESIntrinsics"
  JAVA_OPTS="$JAVA_OPTS -XX:+UseFMA"
  JAVA_OPTS="$JAVA_OPTS -XX:+UseLoopPredicate"
  JAVA_OPTS="$JAVA_OPTS -XX:+RangeCheckElimination"
  JAVA_OPTS="$JAVA_OPTS -XX:+OptimizeStringConcat"
  JAVA_OPTS="$JAVA_OPTS -XX:+UseCompressedOops"
  JAVA_OPTS="$JAVA_OPTS -XX:+UseThreadPriorities"
  JAVA_OPTS="$JAVA_OPTS -XX:+OmitStackTraceInFastThrow"
  JAVA_OPTS="$JAVA_OPTS -XX:+RewriteBytecodes"
  JAVA_OPTS="$JAVA_OPTS -XX:+RewriteFrequentPairs"
  JAVA_OPTS="$JAVA_OPTS -XX:+UseFPUForSpilling"

  # CPU optimizations
  JAVA_OPTS="$JAVA_OPTS -XX:+UseFastStosb"
  JAVA_OPTS="$JAVA_OPTS -XX:+UseNewLongLShift"
  JAVA_OPTS="$JAVA_OPTS -XX:+UseVectorCmov"
  JAVA_OPTS="$JAVA_OPTS -XX:+UseXMMForArrayCopy"
  JAVA_OPTS="$JAVA_OPTS -XX:+UseXmmI2D"
  JAVA_OPTS="$JAVA_OPTS -XX:+UseXmmI2F"
  JAVA_OPTS="$JAVA_OPTS -XX:+UseXmmLoadAndClearUpper"
  JAVA_OPTS="$JAVA_OPTS -XX:+UseXmmRegToRegMoveAll"

  # Advanced optimizations
  JAVA_OPTS="$JAVA_OPTS -XX:+EliminateLocks"
  JAVA_OPTS="$JAVA_OPTS -XX:+DoEscapeAnalysis"
  JAVA_OPTS="$JAVA_OPTS -XX:+AlignVector"
  JAVA_OPTS="$JAVA_OPTS -XX:+OptimizeFill"
  JAVA_OPTS="$JAVA_OPTS -XX:+EnableVectorSupport"
  JAVA_OPTS="$JAVA_OPTS -XX:+UseCharacterCompareIntrinsics"
  JAVA_OPTS="$JAVA_OPTS -XX:+UseCopySignIntrinsic"
  JAVA_OPTS="$JAVA_OPTS -XX:+UseVectorStubs"
  JAVA_OPTS="$JAVA_OPTS -XX:UseAVX=2"
  JAVA_OPTS="$JAVA_OPTS -XX:UseSSE=4"
  JAVA_OPTS="$JAVA_OPTS -XX:+UseFastJNIAccessors"
  JAVA_OPTS="$JAVA_OPTS -XX:+UseInlineCaches"
  JAVA_OPTS="$JAVA_OPTS -XX:+SegmentedCodeCache"

  # System properties
  JAVA_OPTS="$JAVA_OPTS -Djdk.nio.maxCachedBufferSize=262144"
else
  echo "⚙️  MeowIce optimization flags: DISABLED (using JVM defaults)"
fi

# ============================================================================
# GraalVM-Specific Optimizations (Default: ENABLED)
# Disable with: DISABLE_MEOWICE_GRAALVM_FLAGS=true (for troubleshooting)
# Note: Only applied if MeowIce flags are enabled
# ============================================================================
if [ "${DISABLE_MEOWICE_FLAGS:-false}" != "true" ] && [ "${DISABLE_MEOWICE_GRAALVM_FLAGS:-false}" != "true" ]; then
  echo "🚀 GraalVM-specific optimization flags: ENABLED"

  JAVA_OPTS="$JAVA_OPTS -Djdk.graal.UsePriorityInlining=true"
  JAVA_OPTS="$JAVA_OPTS -Djdk.graal.Vectorization=true"
  JAVA_OPTS="$JAVA_OPTS -Djdk.graal.OptDuplication=true"
  JAVA_OPTS="$JAVA_OPTS -Djdk.graal.DetectInvertedLoopsAsCounted=true"
  JAVA_OPTS="$JAVA_OPTS -Djdk.graal.LoopInversion=true"
  JAVA_OPTS="$JAVA_OPTS -Djdk.graal.VectorizeHashes=true"
  JAVA_OPTS="$JAVA_OPTS -Djdk.graal.EnterprisePartialUnroll=true"
  JAVA_OPTS="$JAVA_OPTS -Djdk.graal.VectorizeSIMD=true"
  JAVA_OPTS="$JAVA_OPTS -Djdk.graal.StripMineNonCountedLoops=true"
  JAVA_OPTS="$JAVA_OPTS -Djdk.graal.SpeculativeGuardMovement=true"
  JAVA_OPTS="$JAVA_OPTS -Djdk.graal.TuneInlinerExploration=1"
  JAVA_OPTS="$JAVA_OPTS -Djdk.graal.LoopRotation=true"
  JAVA_OPTS="$JAVA_OPTS -Djdk.graal.CompilerConfiguration=enterprise"
elif [ "${DISABLE_MEOWICE_FLAGS:-false}" != "true" ] && [ "${DISABLE_MEOWICE_GRAALVM_FLAGS:-false}" = "true" ]; then
  echo "⚙️  GraalVM-specific optimization flags: DISABLED"
fi

# ============================================================================
# OpenTelemetry Java Agent (Default: ENABLED)
# Disable with: DISABLE_OTEL_AGENT=true (for troubleshooting)
# ============================================================================
if [ "${DISABLE_OTEL_AGENT:-false}" != "true" ]; then
  # Set sensible OpenTelemetry defaults (user can override any of these)
  export OTEL_SERVICE_NAME="${OTEL_SERVICE_NAME:-minecraft-server}"
  export OTEL_EXPORTER_OTLP_PROTOCOL="${OTEL_EXPORTER_OTLP_PROTOCOL:-grpc}"
  export OTEL_INSTRUMENTATION_RUNTIME_TELEMETRY_ENABLED="${OTEL_INSTRUMENTATION_RUNTIME_TELEMETRY_ENABLED:-true}"
  export OTEL_INSTRUMENTATION_RUNTIME_METRICS_ENABLED="${OTEL_INSTRUMENTATION_RUNTIME_METRICS_ENABLED:-true}"
  export OTEL_METRIC_EXPORT_INTERVAL="${OTEL_METRIC_EXPORT_INTERVAL:-60000}"
  export OTEL_TRACES_SAMPLER="${OTEL_TRACES_SAMPLER:-parentbased_traceidratio}"
  export OTEL_TRACES_SAMPLER_ARG="${OTEL_TRACES_SAMPLER_ARG:-0.1}"

  if [ -f /opt/opentelemetry-javaagent.jar ]; then
    echo "📊 OpenTelemetry Java agent: ENABLED"
    echo "   Service name: ${OTEL_SERVICE_NAME}"
    if [ -n "${OTEL_EXPORTER_OTLP_ENDPOINT:-}" ]; then
      echo "   Exporter endpoint: ${OTEL_EXPORTER_OTLP_ENDPOINT}"
    else
      echo "   ⚠️  Note: OTEL_EXPORTER_OTLP_ENDPOINT not set - metrics will not be exported"
    fi
    JAVA_OPTS="$JAVA_OPTS -javaagent:/opt/opentelemetry-javaagent.jar"
  else
    echo "⚠️  Warning: OpenTelemetry agent not found at /opt/opentelemetry-javaagent.jar"
    echo "   This may indicate an image build issue. Please verify you are using the latest image or rebuild the container."
    echo "   OpenTelemetry instrumentation will not be available."
  fi
else
  echo "⚙️  OpenTelemetry Java agent: DISABLED"
fi

# ============================================================================
# Custom JVM Options
# ============================================================================
if [ -n "${JAVA_OPTS_CUSTOM:-}" ]; then
  echo "🔧 Custom JVM opts: $JAVA_OPTS_CUSTOM"
  JAVA_OPTS="$JAVA_OPTS $JAVA_OPTS_CUSTOM"
fi

# ============================================================================
# Log4j Configuration
# ============================================================================
# Specify Log4j2 configuration file location
if [ -f /data/log4j2.xml ]; then
  JAVA_OPTS="$JAVA_OPTS -Dlog4j.configurationFile=log4j2.xml"
fi

# ============================================================================
# RCON Password Configuration
# ============================================================================
# mc-server-runner needs RCON_PASSWORD environment variable for graceful
# shutdown via rcon-cli. We handle this by:
# 1. Reading existing password from server.properties if it exists
# 2. Exporting RCON_PASSWORD for mc-server-runner
# 3. Writing /data/.rcon-cli.env for manual rcon-cli usage
#
# IMPORTANT: This container does NOT modify files in /data. If RCON is
# enabled but no password is set, the container will error out. User must
# configure server.properties before starting the container.

setup_rcon_password() {
  # Disable shell tracing for password handling (defense-in-depth)
  local xtrace_state
  case $- in
    *x*) xtrace_state=1 ;;
    *) xtrace_state=0 ;;
  esac
  set +x
  local rcon_password=""
  local rcon_enabled="false"
  local rcon_port="25575"

  # Check if server.properties exists
  if [ -f server.properties ]; then
    # Read RCON settings from server.properties
    if grep -q "^enable-rcon=true" server.properties 2>/dev/null; then
      rcon_enabled="true"
      # Use cut -d'=' -f2- to handle passwords/ports containing '=' character
      # Trim whitespace with tr to handle trailing spaces in server.properties
      rcon_password=$(grep "^rcon.password=" server.properties 2>/dev/null | cut -d'=' -f2- | tr -d ' \t')
      rcon_port=$(grep "^rcon.port=" server.properties 2>/dev/null | cut -d'=' -f2- | tr -d ' \t')

      # Validate port is numeric and in valid range (1-65535)
      if ! [[ "$rcon_port" =~ ^[0-9]+$ ]] || [ "$rcon_port" -lt 1 ] || [ "$rcon_port" -gt 65535 ]; then
        rcon_port="25575"
      fi
    fi
  fi

  # If RCON is enabled but no password is set, error out
  # Container policy: we do NOT modify files in /data, user must configure them
  if [ "$rcon_enabled" = "true" ] && [ -z "$rcon_password" ]; then
    # Restore xtrace state before erroring
    if [ "$xtrace_state" = "1" ]; then
      set -x
    fi
    echo "❌ ERROR: RCON is enabled but no password is set in server.properties"
    echo ""
    echo "This container does NOT modify your server.properties file."
    echo "Please add an RCON password to /data/server.properties:"
    echo "  rcon.password=<your-secure-password>"
    echo ""
    echo "Tip: Generate a secure password with: openssl rand -hex 12"
    echo ""
    exit 1
  fi

  # Export RCON configuration for mc-server-runner
  if [ "$rcon_enabled" = "true" ] && [ -n "$rcon_password" ]; then
    export ENABLE_RCON="TRUE"
    export RCON_PASSWORD="$rcon_password"
    export RCON_PORT="$rcon_port"

    # Write .rcon-cli.env for convenience (rcon-cli auto-loads this)
    # Use restrictive permissions to protect sensitive RCON credentials
    cat >/data/.rcon-cli.env <<EOF
password=${rcon_password}
port=${rcon_port}
EOF
    chmod 600 /data/.rcon-cli.env

    echo "✅ RCON configured (port: ${rcon_port})"
  else
    echo "ℹ️  RCON not enabled in server.properties"
  fi

  # Restore xtrace state if it was enabled
  if [ "$xtrace_state" = "1" ]; then
    set -x
  fi

  # Ensure function returns 0 (needed for set -e)
  return 0
}

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
if [ -f "${JAR}" ] || [ -L "${JAR}" ]; then
  PAPER_SIZE=$(du -Lh "${JAR}" 2>/dev/null | cut -f1)
  PAPER_DATE=$(stat -L -c '%y' "${JAR}" 2>/dev/null | cut -d' ' -f1)
  echo "Paper JAR:    ${PAPER_SIZE} (modified: ${PAPER_DATE})"
else
  echo "Paper JAR:    not found"
fi
# Count only JAR files in plugins/ directory (not in subdirectories)
if [ -d plugins ]; then
  PLUGIN_COUNT=$(find plugins -maxdepth 1 -name '*.jar' -type f 2>/dev/null | wc -l)
else
  PLUGIN_COUNT=0
fi

echo "Plugins:      ${PLUGIN_COUNT} found"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🚀 Starting Minecraft server..."
echo ""

# ============================================================================
# Start Server with mc-server-runner
# ============================================================================

# Configurable shutdown delays (matching itzg behavior)
# STOP_SERVER_ANNOUNCE_DELAY: Optional delay after announcing shutdown (default: none)
#   - If set, announces "Server shutting down in X seconds" and waits
#   - If unset, stops immediately without announcement (like itzg)
# STOP_DURATION: Max time to wait for graceful shutdown after stop command (default: 60s)

# Build mc-server-runner arguments
MC_SERVER_RUNNER_ARGS="--named-pipe /tmp/minecraft-console"

# Only add announce delay if explicitly configured
if [ -n "${STOP_SERVER_ANNOUNCE_DELAY:-}" ]; then
  MC_SERVER_RUNNER_ARGS="$MC_SERVER_RUNNER_ARGS --stop-server-announce-delay $STOP_SERVER_ANNOUNCE_DELAY"
fi

# Always include stop duration
MC_SERVER_RUNNER_ARGS="$MC_SERVER_RUNNER_ARGS --stop-duration ${STOP_DURATION:-60s}"

# Turn all argument lists to arrays
read -r -a JAVA_OPTS <<<"${JAVA_OPTS}"
read -r -a MC_SERVER_RUNNER_ARGS <<<"${MC_SERVER_RUNNER_ARGS}"

exec mc-server-runner \
  "${MC_SERVER_RUNNER_ARGS[@]}" \
  java \
  "${JAVA_OPTS[@]}" \
  -jar "${JAR}" --nogui
