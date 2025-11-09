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

## Quick Start

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

## Configuration

Currently to be implemented.

See TODO.md for complete environment variable documentation.

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
| `25565` | TCP | Minecraft server (configurable via `SERVER_PORT`) |
| `9000` | TCP | Management server (if `MANAGEMENT_SERVER_ENABLED=true`) |

## Management Tools

### RCON Console

```bash
docker exec -it minecraft-server rcon-cli
```

### Send Console Commands

```bash
docker exec minecraft-server mc-send-to-console "say Hello players!"
```

## Development

### Prerequisites

- Docker and Docker Buildx
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

```bash
# Build the image
docker build -t mc-server-container:local .

# Run with docker-compose
docker-compose up -d
```

### Running Tests

Tests run automatically in GitHub Actions. To run locally:

```bash
# Build and test
docker build -t mc-server-container:test .
docker run -d --name mc-test -e EULA=TRUE mc-server-container:test
docker logs mc-test
docker stop mc-test && docker rm mc-test
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
   - Pushes to `ghcr.io/miikka/mc-server-container`
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
- SARIF results are uploaded for detailed analysis

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
