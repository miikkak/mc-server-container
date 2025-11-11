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
    sed "s/^${property}[[:space:]]*=[[:space:]]*//;s/^\"\(.*\)\"$/\1/;s/^'\(.*\)'$/\1/;s/[[:space:]]*$//"
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
