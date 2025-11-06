#!/bin/bash
# Custom Minecraft Server Container Entrypoint
# Runs Paper server with GraalVM and optimized MeowIce flags

set -euo pipefail

cd /data

# ============================================================================
# Validation
# ============================================================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎮 Custom Minecraft Server Container"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check EULA
if [ ! -f eula.txt ]; then
  echo "❌ ERROR: /data/eula.txt not found"
  echo ""
  echo "Create /data/eula.txt with:"
  echo "  eula=true"
  echo ""
  exit 1
fi

if ! grep -q "eula=true" eula.txt; then
  echo "❌ ERROR: EULA not accepted in /data/eula.txt"
  echo ""
  echo "Edit /data/eula.txt and set:"
  echo "  eula=true"
  echo ""
  exit 1
fi

# Check Paper JAR
if [ ! -f paper.jar ]; then
  echo "❌ ERROR: /data/paper.jar not found"
  echo ""
  echo "Download Paper JAR to /data/paper.jar before starting the server"
  echo "Visit: https://papermc.io/downloads"
  echo ""
  exit 1
fi

echo "✅ EULA accepted"
echo "✅ Paper JAR found"

# ============================================================================
# Build Java Command
# ============================================================================

# Memory configuration
MEMORY="${MEMORY:-16G}"
JAVA_OPTS="-Xms${MEMORY} -Xmx${MEMORY}"

# MeowIce G1GC flags (hardcoded for GraalVM + G1GC + <32GB heap)
# Source: https://github.com/MeowIce/meowice-flags

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
JAVA_OPTS="$JAVA_OPTS -XX:+UseNUMA"

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

# GraalVM-specific optimizations
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

# OpenTelemetry agent (if configured)
if [ -n "${OTEL_EXPORTER_OTLP_ENDPOINT:-}" ]; then
  if [ -f /opt/opentelemetry-javaagent.jar ]; then
    echo "📊 OpenTelemetry enabled"
    JAVA_OPTS="$JAVA_OPTS -javaagent:/opt/opentelemetry-javaagent.jar"
  else
    echo "⚠️ Warning: OTEL_EXPORTER_OTLP_ENDPOINT is set but OpenTelemetry agent not found at /opt/opentelemetry-javaagent.jar"
    echo "   This may indicate an image build issue. Please verify you are using the latest image or rebuild the container."
    echo "   OpenTelemetry instrumentation will not be available."
  fi
fi

# Custom additional opts (if provided)
if [ -n "${JAVA_OPTS_CUSTOM:-}" ]; then
  echo "🔧 Custom JVM opts: $JAVA_OPTS_CUSTOM"
  JAVA_OPTS="$JAVA_OPTS $JAVA_OPTS_CUSTOM"
fi

# ============================================================================
# Startup Information
# ============================================================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Memory:       ${MEMORY}"
echo "Java:         $(java -version 2>&1 | head -n1)"
echo "Paper JAR:    $(find . -maxdepth 1 -name 'paper.jar' -exec du -h {} \; | cut -f1)"
echo "Plugins:      $(find plugins -name '*.jar' 2>/dev/null | wc -l) found"
echo "GC Strategy:  G1GC with MeowIce flags"
echo "Compiler:     GraalVM Enterprise"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🚀 Starting Minecraft server..."
echo ""

# ============================================================================
# Start Server with mc-server-runner
# ============================================================================

# shellcheck disable=SC2086
exec mc-server-runner \
  --named-pipe /tmp/minecraft-console \
  --stop-server-announce-delay 30s \
  java $JAVA_OPTS -jar paper.jar nogui
