# Custom Minecraft Server Container

A minimal, controlled Minecraft server container with a custom solution using
 [mc-server-runner](https://github.com/itzg/mc-server-runner).

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
- 🎮 Supports Paper server and plugins
- 🔧 Simple Bash-based configuration
- 📦 Published to GitHub Container Registry (GHCR)
- 🔄 Automated builds and releases via GitHub Actions
- ✅ Pre-commit hooks and automated testing
- 🔓 **OCI-compliant images** - Works with Docker, Podman, Kubernetes, and any OCI runtime

### Using Podman

## Configuration

This container focuses on **JVM configuration only**. Minecraft-specific settings (difficulty, max-players, whitelist, etc.) should be configured in `/data/server.properties` and other standard Minecraft configuration files.

### Philosophy: Performance-First with Troubleshooting Options

- ✅ **All optimizations ENABLED by default** - MeowIce G1GC flags, GraalVM optimizations, OpenTelemetry agent
- 🔧 **Use `DISABLE_*` variables only for troubleshooting** - Not for normal operation
- 📊 **OpenTelemetry with sensible defaults** - Just set endpoint and service name
- 🎯 **Minimal configuration required** - Only specify what you need to change

## Credits

- [mc-server-runner](https://github.com/itzg/mc-server-runner) - Process supervision
- [rcon-cli](https://github.com/itzg/rcon-cli) - RCON client
- [Meowice flags](https://github.com/Meowice/Minecraft-Server-Startup-Flags) - JVM optimization
- [Paper](https://papermc.io/) - High-performance Minecraft server
