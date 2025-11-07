# Custom Minecraft Server Container
# Multi-stage build for minimal final image

# ============================================================================
# Stage 1: Download binaries
# ============================================================================
FROM busybox:1.37 AS downloader

WORKDIR /downloads

# Download and extract mc-server-runner
ARG MC_SERVER_RUNNER_VERSION=1.13.4
ADD https://github.com/itzg/mc-server-runner/releases/download/${MC_SERVER_RUNNER_VERSION}/mc-server-runner_${MC_SERVER_RUNNER_VERSION}_linux_amd64.tar.gz mc-server-runner.tar.gz
RUN tar -xzf mc-server-runner.tar.gz && chmod +x mc-server-runner

# Download and extract rcon-cli
ARG RCON_CLI_VERSION=1.7.3
ADD https://github.com/itzg/rcon-cli/releases/download/${RCON_CLI_VERSION}/rcon-cli_${RCON_CLI_VERSION}_linux_amd64.tar.gz rcon-cli.tar.gz
RUN tar -xzf rcon-cli.tar.gz && chmod +x rcon-cli

# Download and extract mc-monitor
ARG MC_MONITOR_VERSION=0.15.8
ADD https://github.com/itzg/mc-monitor/releases/download/${MC_MONITOR_VERSION}/mc-monitor_${MC_MONITOR_VERSION}_linux_amd64.tar.gz mc-monitor.tar.gz
RUN tar -xzf mc-monitor.tar.gz && chmod +x mc-monitor

# Download OpenTelemetry Java agent
ARG OTEL_VERSION=2.21.0
ADD https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v${OTEL_VERSION}/opentelemetry-javaagent.jar opentelemetry-javaagent.jar

# ============================================================================
# Stage 2: Final image
# ============================================================================
FROM container-registry.oracle.com/graalvm/jdk:25

LABEL maintainer="miikka"
LABEL description="Custom Minecraft server container with GraalVM and mc-server-runner"

# Create minecraft user and group (UID/GID 25565)
RUN groupadd -g 25565 minecraft \
  && useradd -u 25565 -g minecraft -m -s /bin/bash minecraft

# Create directories
RUN mkdir -p /data /opt /scripts \
  && chown -R minecraft:minecraft /data

# ============================================================================
# Copy files with explicit ownership (all system files owned by root:root)
# ============================================================================

# Copy observability tools to /opt/
COPY --from=downloader --chown=root:root --chmod=644 /downloads/opentelemetry-javaagent.jar /opt/opentelemetry-javaagent.jar

# Copy binaries from downloader stage to /usr/local/bin/ (alphabetical order, with execute permissions)
COPY --from=downloader --chown=root:root --chmod=755 /downloads/mc-monitor /usr/local/bin/mc-monitor
COPY --from=downloader --chown=root:root --chmod=755 /downloads/mc-server-runner /usr/local/bin/mc-server-runner
COPY --from=downloader --chown=root:root --chmod=755 /downloads/rcon-cli /usr/local/bin/rcon-cli

# Copy local scripts to /usr/local/bin/ (alphabetical order, with execute permissions)
COPY --chown=root:root --chmod=755 scripts/mc-health /usr/local/bin/mc-health
COPY --chown=root:root --chmod=755 scripts/mc-send-to-console /usr/local/bin/mc-send-to-console

# Copy entrypoint script to /scripts/ (with execute permissions)
COPY --chown=root:root --chmod=755 scripts/entrypoint.sh /scripts/entrypoint.sh

# Set working directory
WORKDIR /data

# Expose ports
# 25565 - Minecraft server (TCP/UDP)
# 25575 - RCON (TCP)
EXPOSE 25565/tcp 25565/udp 25575/tcp

# Declare shutdown signal (SIGTERM is Docker default, declared for explicitness)
STOPSIGNAL SIGTERM

# Switch to minecraft user
USER minecraft

# Health check - verify both mc-server-runner and server are responding
HEALTHCHECK --interval=30s --timeout=15s --start-period=90s --retries=3 \
  CMD mc-health

# Set entrypoint
ENTRYPOINT ["/scripts/entrypoint.sh"]
