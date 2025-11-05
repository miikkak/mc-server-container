# Minecraft Server Container

A containerized Minecraft server setup for easy deployment and management.

## Features

- 🐳 Docker containerized Minecraft server
- 🔄 Automated builds and releases via GitHub Actions
- 📦 Published to GitHub Container Registry (GHCR)
- ✅ Automated testing and linting

## Quick Start

```bash
# Pull the latest image from GHCR
docker pull ghcr.io/miikka/mc-server-container:latest

# Run the container
docker run -d \
  -p 25565:25565 \
  -v minecraft-data:/data \
  --name minecraft-server \
  ghcr.io/miikka/mc-server-container:latest
```

## Building Locally

```bash
# Build the image
docker build -t mc-server-container .

# Run locally
docker run -d -p 25565:25565 -v minecraft-data:/data mc-server-container
```

## Configuration

Configuration options can be set via environment variables:

- `EULA=TRUE` - Accept Minecraft EULA (required)
- `SERVER_PORT=25565` - Server port (default: 25565)
- `MAX_PLAYERS=20` - Maximum players (default: 20)
- `DIFFICULTY=normal` - Difficulty level (peaceful, easy, normal, hard)
- `GAMEMODE=survival` - Game mode (survival, creative, adventure, spectator)

## Volumes

- `/data` - Server data directory (world, configs, plugins)

## Ports

- `25565` - Minecraft server port (TCP)

## Development

### Prerequisites

- Docker
- Git
- ShellCheck (for linting)

### Running Tests

```bash
# Build the container
docker build -t mc-server-container:test .

# Run tests
./tests/run-tests.sh
```

## Release Process

This project uses semantic versioning. To create a release:

1. Label your PR with one of:
   - `release:major` - Breaking changes (X.0.0)
   - `release:minor` - New features (0.X.0)
   - `release:patch` - Bug fixes (0.0.X)

2. Merge the PR to main
3. GitHub Actions will automatically build, tag, and push to GHCR

## License

MIT License - See LICENSE file for details

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.
