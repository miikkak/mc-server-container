FROM eclipse-temurin:21-jre-alpine

# Install dependencies
RUN apk add --no-cache curl bash

# Create minecraft user and directories
RUN addgroup -g 1000 minecraft && \
    adduser -D -u 1000 -G minecraft minecraft && \
    mkdir -p /data && \
    chown -R minecraft:minecraft /data

# Set working directory
WORKDIR /data

# Copy startup script
COPY --chown=minecraft:minecraft docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Switch to minecraft user
USER minecraft

# Expose Minecraft port
EXPOSE 25565

# Volume for persistent data
VOLUME ["/data"]

# Set default environment variables
ENV EULA=FALSE \
    SERVER_PORT=25565 \
    MAX_PLAYERS=20 \
    DIFFICULTY=normal \
    GAMEMODE=survival \
    MINECRAFT_VERSION=latest

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
