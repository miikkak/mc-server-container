# shellcheck shell=bash
set -euo pipefail

# ==============================================================================
# Configuration Parsing Functions
# ==============================================================================

get_properties_config_value() {
  local property="$1"
  local config_file="$2"
  grep "^${property}[[:space:]]*=" "$config_file" |
    grep -v "^[[:space:]]*#" |
    head -n 1 |
    sed "s/^${property}[[:space:]]*=[[:space:]]*//;s/^\"\(.*\)\"$/\1/;s/^'\(.*\)'$/\1/;s/[[:space:]]*$//" || true
}

# ==============================================================================
# RCON Configuration Functions
# ==============================================================================

setup_rcon_password() {
  # mc-server-runner needs RCON_PASSWORD environment variable for graceful
  # shutdown via rcon-cli. We handle this by:
  # 1. Reading existing password from server.properties if it exists
  # 2. Exporting RCON_PASSWORD for mc-server-runner
  # 3. Writing /data/.rcon-cli.env for manual rcon-cli usage
  #
  # IMPORTANT: This container does NOT modify files in /data. If RCON is
  # enabled but no password is set, the container will error out. User must
  # configure server.properties before starting the container.

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

# ==============================================================================
# Server Type Detection
# ==============================================================================

detect_server_jar() {
  # Detects and sets server JAR path and type (paper/velocity)
  # Sets: JAR, TYPE (exported variables)
  # Returns: 0 if found, 1 if not found

  local latest_paper latest_velocity

  latest_paper="$(find /data -maxdepth 1 -type f -name 'paper-*.jar' |
    { grep -E 'paper-[0-9]+\.[0-9]+(\.[0-9]+)?-[0-9]+\.jar$' || true; } |
    sort -V | tail -n 1)"

  latest_velocity="$(find /data -maxdepth 1 -type f -name 'velocity-*.jar' |
    { grep -E 'velocity-[0-9]+\.[0-9]+(\.[0-9]+)?(-SNAPSHOT)?-[0-9]+\.jar$' || true; } |
    sort -V | tail -n 1)"

  # Prefer Paper if found
  if [[ -n "${latest_paper:-}" ]]; then
    export JAR="${latest_paper}"
    export TYPE="paper"
  elif [[ -f /data/paper.jar ]]; then
    export JAR="/data/paper.jar"
    export TYPE="paper"
  elif [[ -n "${latest_velocity:-}" ]]; then
    export JAR="${latest_velocity}"
    export TYPE="velocity"
  elif [[ -f /data/velocity.jar ]]; then
    export JAR="/data/velocity.jar"
    export TYPE="velocity"
  else
    return 1 # No JAR found
  fi

  return 0
}

validate_paper_eula() {
  # Validates EULA for Paper servers
  # Returns: 0 if valid, 1 if invalid

  if [[ ! -f /data/eula.txt ]]; then
    echo "❌ ERROR: /data/eula.txt not found" >&2
    echo "" >&2
    echo "Create /data/eula.txt with:" >&2
    echo "  eula=true" >&2
    echo "" >&2
    return 1
  fi

  # Use precise pattern to avoid false positives:
  # - Matches: "eula=true", " eula=true", "eula = true"
  # - Rejects: "#eula=true", "my-eula=true", "eula=true-false"
  if ! grep -qE "^[[:space:]]*eula[[:space:]]*=[[:space:]]*true[[:space:]]*$" /data/eula.txt; then
    echo "❌ ERROR: EULA not accepted in /data/eula.txt" >&2
    echo "" >&2
    echo "Edit /data/eula.txt and set:" >&2
    echo "  eula=true" >&2
    echo "" >&2
    return 1
  fi

  return 0
}

# ==============================================================================
# JVM Options Builder Functions
# ==============================================================================

build_common_jvm_opts() {
  # Builds common JVM options for both Paper and Velocity
  # Args: $1 = nameref to array, $2 = memory (default: 16G)
  # Returns: Array via nameref

  # shellcheck disable=SC2178  # nameref intentionally used as array
  local -n _opts=$1
  local memory="${2:-16G}"

  # Memory configuration
  _opts+=("-Xms${memory}" "-Xmx${memory}")

  # Java locale and terminal configuration
  _opts+=(
    "-Duser.language=en"
    "-Duser.country=US"
    "-Dfile.encoding=UTF-8"
    "-Dterminal.jline=false"
    "-Dterminal.ansi=true"
  )
}

apply_graalvm_opts() {
  # Applies GraalVM-specific optimization flags
  # Base image guarantees GraalVM 25+, so no runtime version check needed
  # Args: $1 = nameref to array
  # Returns: Array via nameref

  # shellcheck disable=SC2178  # nameref intentionally used as array
  local -n _opts=$1

  echo "🚀 GraalVM-specific optimization flags: ENABLED"
  _opts+=(
    "-Djdk.graal.UsePriorityInlining=true"
    "-Djdk.graal.Vectorization=true"
    "-Djdk.graal.OptDuplication=true"
    "-Djdk.graal.DetectInvertedLoopsAsCounted=true"
    "-Djdk.graal.LoopInversion=true"
    "-Djdk.graal.VectorizeHashes=true"
    "-Djdk.graal.EnterprisePartialUnroll=true"
    "-Djdk.graal.VectorizeSIMD=true"
    "-Djdk.graal.StripMineNonCountedLoops=true"
    "-Djdk.graal.SpeculativeGuardMovement=true"
    "-Djdk.graal.TuneInlinerExploration=1"
    "-Djdk.graal.LoopRotation=true"
    "-Djdk.graal.CompilerConfiguration=enterprise"
  )
}

build_paper_jvm_opts() {
  # Builds Paper-specific JVM options (G1GC + MeowIce flags)
  # Assumes: GraalVM 25+ (guaranteed by Dockerfile base image)
  # Args: $1 = nameref to array, $2 = enable_meowice, $3 = enable_graalvm
  # Returns: Array via nameref

  # shellcheck disable=SC2178  # nameref intentionally used as array
  local -n _opts=$1
  local enable_meowice="${2:-true}"
  local enable_graalvm="${3:-true}"

  if [[ "${enable_meowice}" == "true" ]]; then
    echo "🚀 MeowIce optimization flags: ENABLED (G1GC for Paper)"
  else
    echo "⚙️  MeowIce optimization flags: DISABLED (using JVM defaults)"
  fi

  # Apply MeowIce flags only if enabled
  if [[ "${enable_meowice}" == "true" ]]; then
    # Note: --add-modules=jdk.incubator.vector is NOT included
    # This flag only benefits Pufferfish/Purpur (SIMD map rendering), not Paper

    # G1GC configuration
    _opts+=(
      "-XX:+UseG1GC"
      "-XX:MaxGCPauseMillis=200"
      "-XX:+UnlockExperimentalVMOptions"
      "-XX:+UnlockDiagnosticVMOptions"
      "-XX:+DisableExplicitGC"
      "-XX:+AlwaysPreTouch"
      "-XX:G1NewSizePercent=28"
      "-XX:G1MaxNewSizePercent=50"
      "-XX:G1HeapRegionSize=16M"
      "-XX:G1ReservePercent=15"
      "-XX:G1MixedGCCountTarget=3"
      "-XX:InitiatingHeapOccupancyPercent=20"
      "-XX:G1MixedGCLiveThresholdPercent=90"
      "-XX:SurvivorRatio=32"
      "-XX:G1HeapWastePercent=5"
      "-XX:MaxTenuringThreshold=1"
      "-XX:+PerfDisableSharedMem"
      "-XX:G1SATBBufferEnqueueingThresholdPercent=30"
      "-XX:G1ConcMarkStepDurationMillis=5"
      "-XX:G1RSetUpdatingPauseTimePercent=0"
    )

    # Auto-detect NUMA and enable optimization if available
    # NUMA is typically not available in standard containers, but detect it just in case
    if [[ -d /sys/devices/system/node/node1 ]]; then
      _opts+=("-XX:+UseNUMA")
    fi

    # Compiler optimizations
    _opts+=(
      "-XX:-DontCompileHugeMethods"
      "-XX:MaxNodeLimit=240000"
      "-XX:NodeLimitFudgeFactor=8000"
      "-XX:ReservedCodeCacheSize=400M"
      "-XX:NonNMethodCodeHeapSize=12M"
      "-XX:ProfiledCodeHeapSize=194M"
      "-XX:NonProfiledCodeHeapSize=194M"
      "-XX:NmethodSweepActivity=1"
      "-XX:+UseFastUnorderedTimeStamps"
      "-XX:+UseCriticalJavaThreadPriority"
      "-XX:AllocatePrefetchStyle=3"
      "-XX:+AlwaysActAsServerClassMachine"
    )

    # Memory optimizations
    _opts+=(
      "-XX:+UseTransparentHugePages"
      "-XX:LargePageSizeInBytes=2M"
      "-XX:+UseLargePages"
      "-XX:+EagerJVMCI"
      "-XX:+UseStringDeduplication"
    )

    # Intrinsics and optimizations
    _opts+=(
      "-XX:+UseAES"
      "-XX:+UseAESIntrinsics"
      "-XX:+UseFMA"
      "-XX:+UseLoopPredicate"
      "-XX:+RangeCheckElimination"
      "-XX:+OptimizeStringConcat"
      "-XX:+UseCompressedOops"
      "-XX:+UseThreadPriorities"
      "-XX:+OmitStackTraceInFastThrow"
      "-XX:+RewriteBytecodes"
      "-XX:+RewriteFrequentPairs"
      "-XX:+UseFPUForSpilling"
    )

    # CPU optimizations
    _opts+=(
      "-XX:+UseFastStosb"
      "-XX:+UseNewLongLShift"
      "-XX:+UseVectorCmov"
      "-XX:+UseXMMForArrayCopy"
      "-XX:+UseXmmI2D"
      "-XX:+UseXmmI2F"
      "-XX:+UseXmmLoadAndClearUpper"
      "-XX:+UseXmmRegToRegMoveAll"
    )

    # Advanced optimizations
    _opts+=(
      "-XX:+EliminateLocks"
      "-XX:+DoEscapeAnalysis"
      "-XX:+AlignVector"
      "-XX:+OptimizeFill"
      "-XX:+EnableVectorSupport"
      "-XX:+UseCharacterCompareIntrinsics"
      "-XX:+UseCopySignIntrinsic"
      "-XX:+UseVectorStubs"
      "-XX:UseAVX=2"
      "-XX:UseSSE=4"
      "-XX:+UseFastJNIAccessors"
      "-XX:+UseInlineCaches"
      "-XX:+SegmentedCodeCache"
    )

    # System properties
    _opts+=("-Djdk.nio.maxCachedBufferSize=262144")
  fi

  # GraalVM-specific optimizations (independent of MeowIce flags)
  if [[ "${enable_graalvm}" == "true" ]]; then
    apply_graalvm_opts "$1"
  else
    echo "⚙️  GraalVM-specific optimization flags: DISABLED"
  fi
}

build_velocity_jvm_opts() {
  # Builds Velocity-specific JVM options (ZGC for proxy workloads)
  # Assumes: GraalVM 25+ (guaranteed by Dockerfile base image)
  # Args: $1 = nameref to array, $2 = enable_zgc, $3 = enable_graalvm
  # Returns: Array via nameref

  # shellcheck disable=SC2178  # nameref intentionally used as array
  local -n _opts=$1
  local enable_zgc="${2:-true}"
  local enable_graalvm="${3:-true}"

  if [[ "${enable_zgc}" == "true" ]]; then
    echo "🚀 Velocity optimization flags: ENABLED (ZGC for proxy workloads)"
  else
    echo "⚙️  Velocity ZGC optimization: DISABLED (using JVM defaults)"
  fi

  # Apply ZGC flags only if enabled
  if [[ "${enable_zgc}" == "true" ]]; then
    # ZGC configuration (low-latency garbage collection for proxy workloads)
    # Note: ZGenerational became default in Java 23 and was removed in Java 24
    # (generational mode is always enabled in Java 24+)
    _opts+=(
      "-XX:+UseZGC"
      "-XX:+AlwaysPreTouch"
      "-XX:-ZUncommit"
      "-XX:AllocatePrefetchStyle=1" # ZGC prefers style 1 (vs 3 for G1GC)
    )

    # Compiler optimizations (similar to Paper but without G1GC-specific flags)
    _opts+=(
      "-XX:+UnlockExperimentalVMOptions"
      "-XX:+UnlockDiagnosticVMOptions"
      "-XX:+DisableExplicitGC"
      "-XX:-DontCompileHugeMethods"
      "-XX:ReservedCodeCacheSize=400M"
      "-XX:+UseFastUnorderedTimeStamps"
      "-XX:+UseCriticalJavaThreadPriority"
      "-XX:+AlwaysActAsServerClassMachine"
    )

    # Memory optimizations
    _opts+=(
      "-XX:+UseTransparentHugePages"
      "-XX:LargePageSizeInBytes=2M"
      "-XX:+UseLargePages"
      "-XX:+EagerJVMCI"
    )

    # Intrinsics and CPU optimizations
    _opts+=(
      "-XX:+UseAES"
      "-XX:+UseAESIntrinsics"
      "-XX:+UseFMA"
      "-XX:+UseCompressedOops"
      "-XX:+UseThreadPriorities"
      "-XX:+OmitStackTraceInFastThrow"
      "-XX:UseAVX=2"
      "-XX:UseSSE=4"
    )

    # System properties
    _opts+=("-Djdk.nio.maxCachedBufferSize=262144")
  fi

  # GraalVM-specific optimizations (independent of ZGC flags)
  if [[ "${enable_graalvm}" == "true" ]]; then
    apply_graalvm_opts "$1"
  else
    echo "⚙️  GraalVM-specific optimization flags: DISABLED"
  fi
}

build_java_opts() {
  # Main JVM options builder - orchestrates all flag building
  # Args: $1 = nameref to array, $2 = server_type, $3 = memory
  # Returns: Array via nameref

  # shellcheck disable=SC2178  # nameref intentionally used as array
  local -n result_array=$1
  local server_type="$2"
  local memory="${3:-16G}"

  # Start with common options
  build_common_jvm_opts result_array "$memory"

  # Add server-specific options
  case "${server_type}" in
    paper)
      local enable_meowice="true"
      local enable_graalvm="true"

      [[ "${DISABLE_MEOWICE_FLAGS:-false}" == "true" ]] && enable_meowice="false"
      [[ "${DISABLE_MEOWICE_GRAALVM_FLAGS:-false}" == "true" ]] && enable_graalvm="false"

      build_paper_jvm_opts result_array "$enable_meowice" "$enable_graalvm"
      ;;
    velocity)
      local enable_zgc="true"
      local enable_graalvm="true"

      [[ "${DISABLE_VELOCITY_ZGC:-false}" == "true" ]] && enable_zgc="false"
      [[ "${DISABLE_VELOCITY_GRAALVM_FLAGS:-false}" == "true" ]] && enable_graalvm="false"

      build_velocity_jvm_opts result_array "$enable_zgc" "$enable_graalvm"
      ;;
    *)
      echo "⚠️  Unknown server type: ${server_type}" >&2
      ;;
  esac

  # OpenTelemetry agent
  configure_otel_agent
  if [[ "${JAVA_AGENT:-false}" == "true" ]]; then
    result_array+=("-javaagent:/opt/opentelemetry-javaagent.jar")
  fi

  # Custom JVM options (appended)
  # Note: JAVA_OPTS_CUSTOM is split on whitespace. Options with spaces in values
  # are not supported (e.g., -Dfoo="bar baz" will break). Avoid spaces in values
  # or work around by setting multiple -D flags if needed.
  #
  # Design note: Environment variables are inherently strings, so string-to-array
  # conversion is unavoidable here. This is different from internal flag building,
  # where we use arrays throughout. We prefer simple word splitting over eval for
  # security and simplicity, accepting the limitation on spaces in values.
  if [[ -n "${JAVA_OPTS_CUSTOM:-}" ]]; then
    echo "🔧 Custom JVM opts: $JAVA_OPTS_CUSTOM"
    # Split custom opts into array and append (simple word splitting)
    local -a custom_opts
    read -r -a custom_opts <<<"${JAVA_OPTS_CUSTOM}"
    result_array+=("${custom_opts[@]}")
  fi

  # Log4j configuration
  if [[ -f /data/log4j2.xml ]]; then
    result_array+=("-Dlog4j.configurationFile=log4j2.xml")
  fi
}

# ==============================================================================
# OpenTelemetry Java Agent Configuration
# ==============================================================================

configure_otel_agent() {
  # Validates OpenTelemetry agent configuration and sets JAVA_AGENT flag
  # Side effect: Sets global variable JAVA_AGENT="true" if agent should be enabled
  # This side effect is intentional - caller checks JAVA_AGENT to add -javaagent flag
  # Returns: 0 (always succeeds, prints warnings for invalid configs)

  # Skip if explicitly disabled
  if [ "${DISABLE_OTEL_AGENT:-false}" = "true" ]; then
    echo "⚙️  OpenTelemetry Java agent: DISABLED"
    echo "   DISABLE_OTEL_AGENT has been set to true in container configuration"
    echo "   OpenTelemetry instrumentation will not be available."
    return 0
  fi

  # Check if config file is set
  if [ -z "${OTEL_JAVAAGENT_CONFIGURATION_FILE:-}" ]; then
    echo "⚠️  Warning: OpenTelemetry agent config file not set"
    echo "   Likely a missing setting for OTEL_JAVAAGENT_CONFIGURATION_FILE in container configuration"
    echo "   OpenTelemetry instrumentation will not be available."
    return 0
  fi

  # Check if config file exists
  if [ ! -f "${OTEL_JAVAAGENT_CONFIGURATION_FILE}" ]; then
    echo "⚠️  Warning: OpenTelemetry agent config file not found"
    echo "   Likely a missing configuration file or wrong configuration for OTEL_JAVAAGENT_CONFIGURATION_FILE"
    echo "   OpenTelemetry instrumentation will not be available."
    return 0
  fi

  # Check if agent JAR exists
  if [ ! -f /opt/opentelemetry-javaagent.jar ]; then
    echo "⚠️  Warning: OpenTelemetry agent not found at /opt/opentelemetry-javaagent.jar"
    echo "   This may indicate an image build issue. Please verify you are using the latest image or rebuild the container."
    echo "   OpenTelemetry instrumentation will not be available."
    return 0
  fi

  # Read required config values (handle failures gracefully)
  local service_name exporter_endpoint
  service_name=$(get_properties_config_value "otel.service.name" "$OTEL_JAVAAGENT_CONFIGURATION_FILE" || echo "")
  exporter_endpoint=$(get_properties_config_value "otel.exporter.otlp.endpoint" "$OTEL_JAVAAGENT_CONFIGURATION_FILE" || echo "")

  # Check service name configuration
  if [ -z "$service_name" ]; then
    echo "⚠️  Warning: OpenTelemetry agent service name not configured"
    echo "   Likely a configuration issue with ${OTEL_JAVAAGENT_CONFIGURATION_FILE}"
    echo "   OpenTelemetry instrumentation will not be available."
    return 0
  fi

  # Check exporter endpoint configuration
  if [ -z "$exporter_endpoint" ]; then
    echo "⚠️  Warning: OpenTelemetry agent OTLP endpoint not configured"
    echo "   Likely a configuration issue with ${OTEL_JAVAAGENT_CONFIGURATION_FILE}"
    echo "   OpenTelemetry instrumentation will not be available."
    return 0
  fi

  # All checks passed, enable agent
  echo "📊 OpenTelemetry Java agent: ENABLED"
  echo "   Service name: ${service_name}"
  echo "   Exporter endpoint: ${exporter_endpoint}"
  export JAVA_AGENT="true"
}
