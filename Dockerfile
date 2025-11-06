# Custom Minecraft Server Container
# Multi-stage build for minimal final image

# ============================================================================
# Stage 1: Download binaries
# ============================================================================
FROM busybox:1.37 AS downloader

WORKDIR /downloads

# Download and extract mc-server-runner
ARG MC_SERVER_RUNNER_VERSION=1.12.3
ADD https://github.com/itzg/mc-server-runner/releases/download/${MC_SERVER_RUNNER_VERSION}/mc-server-runner_${MC_SERVER_RUNNER_VERSION}_linux_amd64.tar.gz mc-server-runner.tar.gz
RUN tar -xzf mc-server-runner.tar.gz && chmod +x mc-server-runner

# Download and extract rcon-cli
ARG RCON_CLI_VERSION=1.7.2
ADD https://github.com/itzg/rcon-cli/releases/download/${RCON_CLI_VERSION}/rcon-cli_${RCON_CLI_VERSION}_linux_amd64.tar.gz rcon-cli.tar.gz
RUN tar -xzf rcon-cli.tar.gz && chmod +x rcon-cli

# Download OpenTelemetry Java agent
ARG OTEL_VERSION=2.11.0
ADD https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v${OTEL_VERSION}/opentelemetry-javaagent.jar opentelemetry-javaagent.jar

# ============================================================================
# Stage 2: Final image
# ============================================================================
FROM container-registry.oracle.com/graalvm/jdk:25

LABEL maintainer="miikka"
LABEL description="Custom Minecraft server container with GraalVM and mc-server-runner"
LABEL version="1.0.0"

# Create minecraft user and group (UID/GID 25565)
RUN groupadd -g 25565 minecraft \
  && useradd -u 25565 -g minecraft -m -s /bin/bash minecraft

# Create directories
RUN mkdir -p /data /opt /scripts \
  && chown -R minecraft:minecraft /data

# Copy binaries from downloader stage
COPY --from=downloader /downloads/mc-server-runner /usr/local/bin/mc-server-runner
COPY --from=downloader /downloads/rcon-cli /usr/local/bin/rcon-cli
COPY --from=downloader /downloads/opentelemetry-javaagent.jar /opt/opentelemetry-javaagent.jar

# Copy scripts
COPY scripts/entrypoint.sh /scripts/entrypoint.sh
COPY scripts/mc-send-to-console /usr/local/bin/mc-send-to-console

# Make scripts executable and readable
RUN chmod 755 /scripts/entrypoint.sh /usr/local/bin/mc-send-to-console

# Set working directory
WORKDIR /data

# Expose ports
# 25565 - Minecraft server (TCP/UDP)
# 25575 - RCON (TCP)
EXPOSE 25565/tcp 25565/udp 25575/tcp

# Switch to minecraft user
USER minecraft

# Set entrypoint
ENTRYPOINT ["/scripts/entrypoint.sh"]
