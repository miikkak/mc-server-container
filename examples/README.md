# Examples

This directory contains example configurations for running the Minecraft Server Container.

## Docker Compose Examples

### Basic Paper Server

See [docker-compose.yml](docker-compose.yml) for a complete example.

**Quick start:**

1. Copy the example file:

   ```bash
   cp examples/docker-compose.yml docker-compose.yml
   ```

2. Create the data directory and download Paper:

   ```bash
   mkdir minecraft-data
   cd minecraft-data
   wget https://api.papermc.io/v2/projects/paper/versions/1.21.4/builds/155/downloads/paper-1.21.4-155.jar
   echo "eula=true" > eula.txt
   cd ..
   ```

3. Start the server:

   ```bash
   docker compose up -d
   ```

4. View logs:

   ```bash
   docker compose logs -f
   ```

### Velocity Proxy

See [docker-compose-velocity.yml](docker-compose-velocity.yml) for a Velocity-specific example.

**Quick start:**

1. Copy the example file:

   ```bash
   cp examples/docker-compose-velocity.yml docker-compose.yml
   ```

2. Create the data directory and download Velocity:

   ```bash
   mkdir velocity-data
   cd velocity-data
   wget https://api.papermc.io/v2/projects/velocity/versions/3.4.0-SNAPSHOT/builds/546/downloads/velocity-3.4.0-SNAPSHOT-546.jar
   cd ..
   ```

3. Start the proxy:

   ```bash
   docker compose up -d
   ```

## Podman Compose

For Podman, the same docker-compose.yml files work with `podman-compose`:

```bash
podman-compose up -d
```

Remember to use `:Z` suffix for volume mounts when using Podman directly:

```bash
podman run -v ./minecraft-data:/data:Z ...
```

## Podman Systemd Service

Generate a systemd service for Podman:

```bash
# Start the container first
podman-compose up -d

# Generate systemd unit file
podman generate systemd --name minecraft --files

# Move to systemd directory
mv container-minecraft.service ~/.config/systemd/user/

# Enable and start
systemctl --user enable container-minecraft.service
systemctl --user start container-minecraft.service
```

## OpenTelemetry Example

Create `otel-config.properties` in your data directory:

```properties
otel.service.name=minecraft-server
otel.exporter.otlp.endpoint=http://your-otel-collector:4317
otel.metrics.exporter=otlp
otel.logs.exporter=otlp
```

Then add to your docker-compose.yml:

```yaml
environment:
  OTEL_JAVAAGENT_CONFIGURATION_FILE: /data/otel-config.properties
```

## Multi-Server Setup

You can run multiple servers on the same host by using different ports and data directories:

```yaml
services:
  minecraft-survival:
    image: ghcr.io/miikkak/mc-server-container:latest
    container_name: minecraft-survival
    ports:
      - "25565:25565"
    volumes:
      - ./survival-data:/data
    environment:
      MEMORY: "4G"

  minecraft-creative:
    image: ghcr.io/miikkak/mc-server-container:latest
    container_name: minecraft-creative
    ports:
      - "25566:25565"  # Different host port
    volumes:
      - ./creative-data:/data
    environment:
      MEMORY: "2G"
```

## Troubleshooting

### Container won't start

Check the logs:

```bash
docker compose logs
```

Common issues:

- Missing Paper/Velocity JAR in data directory
- EULA not accepted (Paper only)
- Port already in use

### Performance issues

Try disabling optimizations one at a time:

```yaml
environment:
  DISABLE_MEOWICE_GRAALVM_FLAGS: "true"
```

### Graceful shutdown not working

Ensure RCON is configured in server.properties:

```properties
enable-rcon=true
rcon.password=your-password
```
