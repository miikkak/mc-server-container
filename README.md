# Custom Minecraft Server Container

[![CI/CD](https://github.com/miikkak/mc-server-container/actions/workflows/ci-cd.yml/badge.svg)](https://github.com/miikkak/mc-server-container/actions/workflows/ci-cd.yml)
[![Latest Release](https://img.shields.io/github/v/release/miikkak/mc-server-container)](https://github.com/miikkak/mc-server-container/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Container Registry](https://img.shields.io/badge/ghcr.io-miikkak%2Fmc--server--container-blue)](https://github.com/miikkak/mc-server-container/pkgs/container/mc-server-container)

A minimal, controlled Minecraft server container with a custom solution using
[mc-server-runner](https://github.com/itzg/mc-server-runner),
[mc-monitor](https://github.com/itzg/mc-monitor) and
[rcon-cli](https://github.com/itzg/rcon-cli).

## Why This Container?

This custom container focuses on the minimum requirements while maintaining
professional process management:

- ✅ **Java 25 compatibility**
- ✅ **Fast boot times**
- ✅ **Clean architecture** (no complex init process, no additional helper tools)
- ✅ **Manual JAR management** (predictable)
- ✅ **Professional process supervision** (mc-server-runner for graceful shutdown)
- ✅ **Offline-capable** (no dependencies to other services during the start)

## Features

- 🐳 Based on Oracle GraalVM JDK for optimal performance
- 🎮 Supports Paper server and Velocity proxy
- 🔧 Simple Bash-based configuration
- 📦 Published to GitHub Container Registry (GHCR)
- 🔄 Automated builds and releases via GitHub Actions
- ✅ Pre-commit hooks and automated testing
- 🔓 **OCI-compliant images** - Works with Docker, Podman, Kubernetes, and any OCI runtime

## Quick Start

### Installation

Pull the latest image from GitHub Container Registry:

```bash
# Using Docker
docker pull ghcr.io/miikkak/mc-server-container:latest

# Using Podman
podman pull ghcr.io/miikkak/mc-server-container:latest
```

For production use, specify a version tag instead of `latest`:

```bash
docker pull ghcr.io/miikkak/mc-server-container:v0.9.8
```

### Basic Usage

#### Paper Server

1. Create a data directory and download Paper:

   ```bash
   mkdir minecraft-data
   cd minecraft-data

   # Download Paper (replace with desired version)
   wget https://api.papermc.io/v2/projects/paper/versions/1.21.4/builds/155/downloads/paper-1.21.4-155.jar

   # Accept EULA
   echo "eula=true" > eula.txt
   ```

2. Run the container:

   ```bash
   # Using Docker
   docker run -d \
     --name minecraft \
     -p 25565:25565 \
     -v ./minecraft-data:/data \
     -e MEMORY=4G \
     ghcr.io/miikkak/mc-server-container:latest

   # Using Podman
   podman run -d \
     --name minecraft \
     -p 25565:25565 \
     -v ./minecraft-data:/data:Z \
     -e MEMORY=4G \
     ghcr.io/miikkak/mc-server-container:latest
   ```

#### Velocity Proxy

1. Create a data directory and download Velocity:

   ```bash
   mkdir velocity-data
   cd velocity-data

   # Download Velocity (replace with desired version)
   wget https://api.papermc.io/v2/projects/velocity/versions/3.4.0-SNAPSHOT/builds/546/downloads/velocity-3.4.0-SNAPSHOT-546.jar
   ```

2. Run the container:

   ```bash
   # Using Docker
   docker run -d \
     --name velocity \
     -p 25565:25565 \
     -v ./velocity-data:/data \
     -e MEMORY=2G \
     ghcr.io/miikkak/mc-server-container:latest
   ```

### Using Docker Compose

Create a `docker-compose.yml`:

```yaml
services:
  minecraft:
    image: ghcr.io/miikkak/mc-server-container:latest
    container_name: minecraft
    restart: unless-stopped
    ports:
      - "25565:25565"
      - "25575:25575"  # RCON (optional)
    volumes:
      - ./minecraft-data:/data
    environment:
      MEMORY: "4G"
    stdin_open: true
    tty: true
```

Start with:

```bash
docker compose up -d
```

For Podman, use `podman-compose` or generate a systemd service.

## Configuration

This container focuses on **JVM configuration only**. Minecraft-specific settings (difficulty, max-players, whitelist, etc.) should be configured in `/data/server.properties` and other standard Minecraft configuration files.

### Environment Variables

| Variable                              | Default   | Description                                                |
|---------------------------------------|-----------|------------------------------------------------------------|
| `MEMORY`                              | `16G`     | Memory allocation for the JVM (e.g., `4G`, `8G`, `16G`)  |
| `STOP_DURATION`                       | `60s`     | Maximum time to wait for graceful shutdown                 |
| `STOP_SERVER_ANNOUNCE_DELAY`          | _(none)_  | Optional delay before shutdown announcement                |
| `DISABLE_MEOWICE_FLAGS`               | `false`   | Disable MeowIce G1GC optimization flags                    |
| `DISABLE_MEOWICE_GRAALVM_FLAGS`       | `false`   | Disable MeowIce GraalVM optimization flags                 |
| `DISABLE_VELOCITY_ZGC`                | `false`   | Disable ZGC for Velocity (uses G1GC instead)               |
| `DISABLE_VELOCITY_GRAALVM_FLAGS`      | `false`   | Disable GraalVM flags for Velocity                         |
| `DISABLE_OTEL_AGENT`                  | `false`   | Disable OpenTelemetry Java agent                           |
| `OTEL_JAVAAGENT_CONFIGURATION_FILE`   | _(none)_  | Path to OpenTelemetry configuration file                   |

### Performance Philosophy: Optimizations Enabled by Default

- ✅ **All optimizations ENABLED by default** - MeowIce G1GC flags, GraalVM optimizations, OpenTelemetry agent
- 🔧 **Use `DISABLE_*` variables only for troubleshooting** - Not for normal operation
- 📊 **OpenTelemetry with sensible defaults** - Just set endpoint and service name
- 🎯 **Minimal configuration required** - Only specify what you need to change

### Volume Mounts

The container expects `/data` to be mounted with your Minecraft server files:

- `/data/paper-*.jar` or `/data/paper.jar` - Paper server JAR
- `/data/velocity-*.jar` or `/data/velocity.jar` - Velocity proxy JAR
- `/data/eula.txt` - EULA acceptance (Paper only)
- `/data/server.properties` - Server configuration (Paper only)
- `/data/plugins/` - Plugin directory (Paper only)
- `/data/velocity.toml` - Velocity configuration (Velocity only)

### Ports

| Port  | Protocol | Description      |
|-------|----------|------------------|
| 25565 | TCP/UDP  | Minecraft server |
| 25575 | TCP      | RCON (optional)  |

### RCON Configuration

For Paper servers, RCON can be enabled in `/data/server.properties`:

```properties
enable-rcon=true
rcon.port=25575
rcon.password=your-secure-password
```

The container will automatically detect and configure RCON for graceful shutdowns.

## Advanced Usage

### OpenTelemetry Integration

The container includes the OpenTelemetry Java agent for observability. To use it:

1. Create an OpenTelemetry configuration file in `/data/otel-config.properties`:

   ```properties
   otel.service.name=minecraft-server
   otel.exporter.otlp.endpoint=http://your-otel-collector:4317
   ```

2. Set the environment variable:

   ```bash
   -e OTEL_JAVAAGENT_CONFIGURATION_FILE=/data/otel-config.properties
   ```

### Custom JVM Flags

The container uses optimized JVM flags from [Meowice](https://github.com/Meowice/Minecraft-Server-Startup-Flags). To troubleshoot performance issues, you can selectively disable optimizations:

```bash
# Disable all MeowIce optimizations
-e DISABLE_MEOWICE_FLAGS=true

# Disable only GraalVM optimizations
-e DISABLE_MEOWICE_GRAALVM_FLAGS=true
```

### Graceful Shutdown

The container uses `mc-server-runner` for professional process management:

```bash
# Default: 60 seconds for graceful shutdown
docker stop minecraft

# Custom shutdown delay with announcement
docker run -e STOP_SERVER_ANNOUNCE_DELAY=30s ...
docker run -e STOP_DURATION=120s ...
```

### Health Checks

The container includes built-in health checks using `mc-monitor`:

```bash
# Check container health
docker inspect --format='{{.State.Health.Status}}' minecraft

# View health check logs
docker inspect --format='{{range .State.Health.Log}}{{.Output}}{{end}}' minecraft
```

## Supported Platforms

- **Architecture**: linux/amd64
- **Container Runtimes**: Docker, Podman, containerd, CRI-O, Kubernetes

### Podman-Specific Notes

When using Podman, add `:Z` to volume mounts for proper SELinux labeling:

```bash
podman run -v ./minecraft-data:/data:Z ...
```

To run as a systemd service, generate a unit file:

```bash
podman generate systemd --name minecraft --files
```

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines, code quality standards, and how to contribute.

## Security

See [SECURITY.md](SECURITY.md) for security policies and how to report vulnerabilities.

## Credits

- [mc-server-runner](https://github.com/itzg/mc-server-runner) - Process supervision
- [mc-monitor](https://github.com/itzg/mc-monitor) - Minecraft monitoring
- [rcon-cli](https://github.com/itzg/rcon-cli) - RCON client
- [Meowice flags](https://github.com/Meowice/Minecraft-Server-Startup-Flags) - JVM optimization
- [Paper](https://papermc.io/) - High-performance Minecraft server
- [Velocity](https://papermc.io/software/velocity/) - High-performance Minecraft proxy

## License

[MIT License](LICENSE) - Copyright (c) 2025 Miikka Karhuluoma

## Support

- 📖 [Documentation](https://github.com/miikkak/mc-server-container)
- 🐛 [Issue Tracker](https://github.com/miikkak/mc-server-container/issues)
- 💬 [Discussions](https://github.com/miikkak/mc-server-container/discussions)
