#!/usr/bin/env bash
# shellcheck shell=bash
# Custom Minecraft Server Container Entrypoint
# Runs Paper server with GraalVM and optimized MeowIce flags
set -euo pipefail

FUNCTIONS="/scripts/functions.sh"
if [ -r "$FUNCTIONS" ]; then
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
if latest_paper="$(find /data -maxdepth 1 -type f -name 'paper-*.jar' |
  grep -E 'paper-[0-9]+\.[0-9]+(\.[0-9]+)?-[0-9]+\.jar$' |
  sort -V |
  tail -n 1)"; then
  echo "Found Paper JAR"
fi
if latest_velocity="$(find /data -maxdepth 1 -type f -name 'velocity-*.jar' |
  grep -E 'velocity-[0-9]+\.[0-9]+(\.[0-9]+)?(-SNAPSHOT)?-[0-9]+\.jar$' |
  sort -V |
  tail -n 1)"; then
  echo "Found Velocity JAR"
fi

# Entrypoint will always prefer Paper if it is found, user is not supposed to
# keep both Paper and Velocity in the /data folder
#
# First, try to find latest Paper JAR with version numbers
if [ -z "${latest_paper:-}" ]; then
  # Check for paper.jar instead of versioned filename
  if [ ! -f /data/paper.jar ]; then
    # Paper isn't found, check for Velocity
    if [ -z "${latest_velocity:-}" ]; then
      if [ ! -f /data/velocity.jar ]; then
        echo "❌ ERROR: neither Paper nor Velocity found"
        echo ""
        echo "Download Paper or Velocity to /data before starting the server"
        echo "Visit: https://papermc.io/downloads"
        echo ""
        exit 1
      else
        JAR="/data/velocity.jar"
        TYPE="velocity"
      fi
    else
      JAR="${latest_velocity}"
      TYPE="velocity"
    fi
  else
    JAR="/data/paper.jar"
    TYPE="paper"
  fi
else
  JAR="${latest_paper}"
  TYPE="paper"
fi
echo "✅ Server (${TYPE}) JAR found: ${JAR}"

if [ "${TYPE:-}" = "paper" ]; then
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

  echo "✅ EULA accepted"
fi

# ============================================================================
# Build Java Command
# ============================================================================

# Memory configuration
MEMORY="${MEMORY:-16G}"
JAVA_OPTS="-Xms${MEMORY} -Xmx${MEMORY}"

# ============================================================================
# Java Locale and Terminal Configuration
# ============================================================================
# Explicitly set Java locale properties to ensure proper language detection
# and unicode/emoji support in console logs (fixes Floodgate "en_" warning)
JAVA_OPTS="$JAVA_OPTS -Duser.language=en"
JAVA_OPTS="$JAVA_OPTS -Duser.country=US"
JAVA_OPTS="$JAVA_OPTS -Dfile.encoding=UTF-8"

# Terminal configuration for proper ANSI color support
# - terminal.jline=false: Disables JLine advanced terminal features (avoids warnings in container)
# - terminal.ansi=true: Forces ANSI color codes for log levels (warnings=yellow, errors=red)
JAVA_OPTS="$JAVA_OPTS -Dterminal.jline=false"
JAVA_OPTS="$JAVA_OPTS -Dterminal.ansi=true"

# ============================================================================
# MeowIce G1GC Flags (Default: ENABLED for Paper, DISABLED for Velocity)
# Source: https://github.com/MeowIce/meowice-flags
# Disable with: DISABLE_MEOWICE_FLAGS=true (for troubleshooting)
# Note: These flags are optimized for Paper/Minecraft servers and are not
#       applied to Velocity proxy servers due to different performance characteristics
# ============================================================================
if [ "${DISABLE_MEOWICE_FLAGS:-false}" != "true" ] && [ "${TYPE:-}" = "paper" ]; then
  echo "🚀 MeowIce optimization flags: ENABLED"

  # Note: --add-modules=jdk.incubator.vector is NOT included
  # This flag only benefits Pufferfish/Purpur (SIMD map rendering), not Paper
  # Paper has no code that uses the Vector API, so the flag provides zero benefit

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
elif [ "${TYPE:-}" = "velocity" ]; then
  echo "⚙️  MeowIce optimization flags: DISABLED (not applicable for Velocity proxy)"
else
  echo "⚙️  MeowIce optimization flags: DISABLED (using JVM defaults)"
fi

# ============================================================================
# GraalVM-Specific Optimizations (Default: ENABLED for Paper, DISABLED for Velocity)
# Disable with: DISABLE_MEOWICE_GRAALVM_FLAGS=true (for troubleshooting)
# Note: Only applied if MeowIce flags are enabled
#       These flags are optimized for Paper/Minecraft servers and are not
#       applied to Velocity proxy servers due to different performance characteristics
# ============================================================================
if [ "${DISABLE_MEOWICE_FLAGS:-false}" != "true" ] &&
  [ "${DISABLE_MEOWICE_GRAALVM_FLAGS:-false}" != "true" ] &&
  [ "${TYPE:-}" = "paper" ]; then
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
elif [ "${DISABLE_MEOWICE_FLAGS:-false}" != "true" ] &&
  [ "${DISABLE_MEOWICE_GRAALVM_FLAGS:-false}" = "true" ] &&
  [ "${TYPE:-}" = "paper" ]; then
  echo "⚙️  GraalVM-specific optimization flags: DISABLED"
elif [ "${TYPE:-}" = "velocity" ]; then
  echo "⚠️  GraalVM-specific optimization flags: NOT APPLICABLE for Velocity proxy servers"
fi

# ============================================================================
# OpenTelemetry Java Agent (Default: ENABLED)
# Disable with: DISABLE_OTEL_AGENT=true (for troubleshooting)
# ============================================================================
configure_otel_agent
if [ "${JAVA_AGENT:-false}" = "true" ]; then
  JAVA_OPTS="$JAVA_OPTS -javaagent:/opt/opentelemetry-javaagent.jar"
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
  JAR_SIZE=$(du -Lh "${JAR}" 2>/dev/null | cut -f1)
  JAR_DATE=$(stat -L -c '%y' "${JAR}" 2>/dev/null | cut -d' ' -f1)
  echo "Server JAR:    ${JAR_SIZE} (modified: ${JAR_DATE})"
else
  echo "Server JAR:    not found"
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
