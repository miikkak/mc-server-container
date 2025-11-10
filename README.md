# Custom Minecraft Server Container

A minimal, controlled Minecraft server container with a custom solution using [mc-server-runner](https://github.com/itzg/mc-server-runner).

## Why This Container?

This custom container focuses on the minimum requirements while maintaining professional process management:

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

## Quick Start

### Using Docker

```bash
# Pull the latest image from GHCR
docker pull ghcr.io/miikkak/mc-server-container:latest

# Run the container
docker run -d \
  -p 25565:25565 \
  -v /srv/minecraft:/data \
  -e EULA=TRUE \
  -e MEMORY=16G \
  --name minecraft-server \
  ghcr.io/miikkak/mc-server-container:latest
```

### Using Podman

This container is **fully OCI-compliant** and works seamlessly with Podman:

```bash
# Pull the latest image from GHCR
podman pull ghcr.io/miikkak/mc-server-container:latest

# Run the container
podman run -d \
  -p 25565:25565 \
  -v /srv/minecraft:/data:Z \
  -e EULA=TRUE \
  -e MEMORY=16G \
  --name minecraft-server \
  ghcr.io/miikkak/mc-server-container:latest
```

**Note about `:Z` flag**: This flag relabels the volume content for SELinux, required on SELinux-enabled systems (like Fedora, RHEL, CentOS). The `:Z` flag makes the volume **private** to this container. If you need to share the volume between multiple containers, use `:z` (lowercase) instead, which allows sharing. On non-SELinux systems (like Ubuntu, Debian), this flag is safe to use but has no effect.

**Rootless mode**: Podman can run this container rootless. The container already runs as non-root user (UID 25565), making it ideal for rootless deployments.

### Using Kubernetes/OpenShift

The OCI-compliant images work directly with Kubernetes, OpenShift, and other container orchestration platforms:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: minecraft-server
spec:
  containers:
  - name: minecraft
    image: ghcr.io/miikkak/mc-server-container:latest
    env:
    - name: EULA
      value: "TRUE"
    - name: MEMORY
      value: "16G"
    ports:
    - containerPort: 25565
      protocol: TCP
    volumeMounts:
    - name: minecraft-data
      mountPath: /data
  volumes:
  - name: minecraft-data
    persistentVolumeClaim:
      claimName: minecraft-data
```

## OCI Compliance

This container is built using **Docker Buildx with BuildKit**, which produces images conforming to the [OCI Image Format Specification](https://github.com/opencontainers/image-spec). This means the images work with:

- ✅ **Docker** - Traditional Docker Engine and Docker Desktop
- ✅ **Podman** - Daemonless, rootless container engine
- ✅ **Kubernetes** - Standard container orchestration (containerd, CRI-O)
- ✅ **OpenShift** - Enterprise Kubernetes platform
- ✅ **containerd** - Industry-standard container runtime
- ✅ **CRI-O** - Lightweight Kubernetes runtime
- ✅ Any OCI-compliant container runtime

**Why it matters:**
- **Portability** - Same image works across different container runtimes
- **Security** - Run rootless with Podman for enhanced security
- **Flexibility** - Deploy to Docker, Kubernetes, or edge environments without modification
- **Future-proof** - Based on open standards, not vendor lock-in

**Verification**: Our CI pipeline tests the container with both Docker and Podman to ensure cross-runtime compatibility.

## Configuration

This container focuses on **JVM configuration only**. Minecraft-specific settings (difficulty, max-players, whitelist, etc.) should be configured in `/data/server.properties` and other standard Minecraft configuration files.

### Philosophy: Performance-First with Troubleshooting Options

- ✅ **All optimizations ENABLED by default** - MeowIce G1GC flags, GraalVM optimizations, OpenTelemetry agent
- 🔧 **Use `DISABLE_*` variables only for troubleshooting** - Not for normal operation
- 📊 **OpenTelemetry with sensible defaults** - Just set endpoint and service name
- 🎯 **Minimal configuration required** - Only specify what you need to change

### Environment Variables

**JVM Memory:**
```yaml
MEMORY: "16G"  # Default: 16G
```

**OpenTelemetry (enabled by default):**
```yaml
OTEL_SERVICE_NAME: "minecraft-server"              # Default: "minecraft-server"
OTEL_EXPORTER_OTLP_ENDPOINT: "http://otel:4317"    # Required for metrics export
OTEL_RESOURCE_ATTRIBUTES: "env=production"         # Optional
# All other OTEL_* variables have sensible defaults but can be overridden
```

**Troubleshooting JVM Performance (for debugging only):**
```yaml
DISABLE_MEOWICE_FLAGS: "true"          # Disable MeowIce G1GC optimizations
DISABLE_MEOWICE_GRAALVM_FLAGS: "true"  # Disable GraalVM-specific optimizations
DISABLE_OTEL_AGENT: "true"             # Disable OpenTelemetry Java agent
JAVA_OPTS_CUSTOM: "-Xlog:gc*"         # Add custom JVM options
```

**Example: Minimal Configuration**
```yaml
environment:
  MEMORY: "16G"
  OTEL_SERVICE_NAME: "my-minecraft-server"
  OTEL_EXPORTER_OTLP_ENDPOINT: "http://172.18.0.1:4317"
```

See `docker-compose.yml` for a complete example.

## Volumes

| Path | Purpose |
|------|---------|
| `/data` | Server data (world, configs, plugins, JARs) |
| `/data/paper.jar` | Paper server JAR (provide manually) |
| `/data/plugins/` | Server plugins |
| `/data/world/` | Main world data |

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| `25565` | TCP/UDP | Minecraft server (configure in `server.properties`) |
| `25575` | TCP | RCON (configure in `server.properties`) |

## Management Tools

### RCON Console

```bash
docker exec -it minecraft-server rcon-cli
```

### Send Console Commands

```bash
docker exec minecraft-server mc-send-to-console "say Hello players!"
```

## Troubleshooting

### Bypassing Entrypoint for Diagnostics

If you need to inspect the container filesystem or debug issues without running the server entrypoint:

```bash
# Override entrypoint to get direct shell access
docker run --rm -it --entrypoint /bin/bash ghcr.io/miikka/mc-server-container:latest

# Or for a specific image ID
docker run --rm -it --entrypoint /bin/bash <image-id>
```

This is useful for:
- Inspecting file permissions and ownership
- Testing commands before modifying scripts
- Debugging when the entrypoint fails
- Checking which files are present in the image

For a running container, use:
```bash
docker exec -it minecraft-server bash
```

## Development

### Prerequisites

- Docker and Docker Buildx (or Podman)
- Git with pre-commit hooks
- ShellCheck (for bash script linting)
- Hadolint (for Dockerfile linting)

### Setup Pre-commit Hooks

```bash
pip install pre-commit
pre-commit install
pre-commit run --all-files
```

### Building Locally

**With Docker:**
```bash
# Build the image
docker build -t mc-server-container:local .

# Run with docker-compose
docker-compose up -d
```

**With Podman:**
```bash
# Build the image
podman build -t mc-server-container:local .

# Run the container
podman run -d --name mc-local \
  -v /srv/minecraft:/data:Z \
  -e EULA=TRUE \
  mc-server-container:local
```

### Running Tests

Tests run automatically in GitHub Actions. To run locally:

**With Docker:**
```bash
# Build and test
docker build -t mc-server-container:test .
docker run -d --name mc-test -e EULA=TRUE mc-server-container:test
docker logs mc-test
docker stop mc-test && docker rm mc-test
```

**With Podman:**
```bash
# Build and test
podman build -t mc-server-container:test .
podman run -d --name mc-test -e EULA=TRUE mc-server-container:test
podman logs mc-test
podman stop mc-test && podman rm mc-test
```

## Release Process

This project uses semantic versioning with automated releases:

1. Create a PR with your changes
2. Add a release label:
   - `release:major` - Breaking changes (1.0.0 → 2.0.0)
   - `release:minor` - New features (1.0.0 → 1.1.0)
   - `release:patch` - Bug fixes (1.0.0 → 1.0.1)
3. Merge to main
4. GitHub Actions automatically:
   - Builds the container
   - Tags with semantic version
   - Pushes to `ghcr.io/miikkak/mc-server-container`
   - Creates a GitHub release

## Project Structure

```
mc-server-container/
├── Dockerfile              # Container definition
├── docker-compose.yml      # Local development setup
├── scripts/
│   ├── entrypoint.sh      # Container entrypoint
│   ├── download-paper.sh  # Paper JAR download helper
│   └── update-plugins.sh  # Plugin update helper
├── .github/
│   └── workflows/         # GitHub Actions CI/CD
├── TODO.md                # Detailed project plan and goals
└── CLAUDE.md              # Development guide for Claude Code
```

## Comparison to itzg/minecraft-server

| Feature | This Container | itzg/minecraft-server |
|---------|---------------|----------------------|
| Boot time | < 10s | 30-60s (API calls) |
| Java warnings | None | Yes (Java 25 issues) |
| Dependencies | Minimal | Many Java helpers |
| JAR management | Manual | Auto-download |
| Offline operation | Yes | No (needs APIs) |
| Process manager | mc-server-runner | Custom Java tools |

## Dependency Management

This repository includes automated dependency monitoring and security scanning:

### Automated Processes

- **🤖 Dependabot** - Automatically creates PRs for GitHub Actions and Docker base image updates (weekly)
- **🔍 Dependency Check** - Monitors binary dependencies (mc-server-runner, rcon-cli) and automatically creates PRs with updates (weekly)
- **🔒 Security Scan** - Runs Trivy vulnerability scanning on container images and reports to GitHub Security tab (daily)
- **🔧 Pre-commit Updates** - Automatically creates PRs when pre-commit hook updates are available (weekly)
- **📊 Dependency Dashboard** - Maintains a comprehensive dashboard issue with all dependency statuses (weekly)

### Viewing Dependency Status

Check the [Dependency Status Dashboard](../../issues?q=is%3Aissue+is%3Aopen+label%3Adashboard) issue for a complete overview of all dependencies and their current status.

For detailed information, see [Dependency Management Guide](docs/DEPENDENCY_MANAGEMENT.md).

### Security Alerts

Security vulnerabilities are automatically detected and reported:
- View alerts in the [Security tab](../../security)
- Critical/high vulnerabilities trigger automatic issue creation
- Table and JSON scan results available in workflow logs

See [Security Policy](SECURITY.md) for detailed security information.

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Run pre-commit hooks (`pre-commit run --all-files`)
4. Commit your changes (never commit directly to main)
5. Push and create a Pull Request

## License

MIT License - See [LICENSE](LICENSE) file for details.

## Credits

- [mc-server-runner](https://github.com/itzg/mc-server-runner) - Process supervision
- [rcon-cli](https://github.com/itzg/rcon-cli) - RCON client
- [Meowice flags](https://github.com/Meowice/Minecraft-Server-Startup-Flags) - JVM optimization
- [Paper](https://papermc.io/) - High-performance Minecraft server
