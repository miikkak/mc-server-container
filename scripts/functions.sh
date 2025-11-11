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
# OpenTelemetry Java Agent Configuration
# ==============================================================================

configure_otel_agent() {
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
