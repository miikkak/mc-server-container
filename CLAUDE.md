# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with this repository.

## Project Overview

**mc-server-container** is a custom Minecraft server Docker container designed to replace [itzg/minecraft-server](https://github.com/itzg/docker-minecraft-server) with a minimal, controlled solution.

### Purpose

This container eliminates Java helper tool dependencies and Java 25 compatibility warnings while maintaining professional process management through [mc-server-runner](https://github.com/itzg/mc-server-runner).

### Key Goals

1. **No Java compatibility warnings** - Eliminate mc-image-helper and OpenTelemetry agent warnings with Java 25
2. **Fast boot times** - Target < 10 seconds, no API calls during startup
3. **Clean architecture** - No complex init process, minimal dependencies
4. **Manual JAR management** - Predictable, no auto-download surprises
5. **Offline operation** - Boot succeeds even when Paper/Modrinth APIs are down

## Technology Stack

- **Base Image**: `container-registry.oracle.com/graalvm/jdk:latest` (Oracle GraalVM LTS)
- **Process Manager**: [mc-server-runner](https://github.com/itzg/mc-server-runner) (Go binary)
- **RCON Client**: [rcon-cli](https://github.com/itzg/rcon-cli)
- **Observability**: [OpenTelemetry Java agent](https://github.com/open-telemetry/opentelemetry-java-instrumentation) (optional)
- **Server**: Paper (manual JAR management)
- **Scripts**: Bash with `set -euo pipefail`
- **Build System**: Docker Buildx with BuildKit (produces OCI-compliant images)
- **Testing**: Docker, Podman (OCI compliance verification), ShellCheck, Hadolint
- **CI/CD**: GitHub Actions
- **Registry**: GitHub Container Registry (GHCR)

## Repository Structure

```
mc-server-container/
├── Dockerfile                      # Container definition
├── docker-compose.yml              # Local development setup
├── scripts/
│   ├── entrypoint.sh              # Container entrypoint script
│   ├── download-paper.sh          # Helper to download Paper JAR
│   ├── update-plugins.sh          # Helper to update plugins
│   └── mc-send-to-console.sh      # Console command wrapper
├── .github/
│   ├── workflows/
│   │   ├── ci-cd.yml              # Label-gated CI/CD pipeline (build, scan, test, release)
│   │   ├── shellcheck.yml         # ShellCheck linting (runs on every commit)
│   │   ├── hadolint.yml           # Hadolint linting (runs on every commit)
│   │   ├── label-management.yml   # Auto-removes ci/ready label on new commits
│   │   ├── security-scan.yml      # Scheduled security scanning
│   │   ├── dependency-check.yml   # Binary dependency monitoring
│   │   ├── precommit-updates.yml  # Pre-commit hook updates
│   │   └── dependency-dashboard.yml # Dependency status dashboard
│   ├── dependabot.yml             # Dependabot configuration
│   ├── ISSUE_TEMPLATE/            # Bug report and feature request templates
│   └── labels.yml                 # GitHub labels configuration (includes ci/ready)
├── docs/
│   ├── DEPENDENCY_MANAGEMENT.md   # Dependency monitoring guide
│   └── MONITORING_ARCHITECTURE.md # System architecture documentation
├── .pre-commit-config.yaml        # Pre-commit hooks configuration
├── .shellcheck-wrapper.sh         # Shellcheck wrapper for pre-commit
├── .gitignore                     # Git ignore patterns
├── README.md                      # User-facing documentation
├── SECURITY.md                    # Security policy and reporting
├── TODO.MD                        # Detailed implementation plan
├── CLAUDE.md                      # This file
├── LICENSE                        # MIT License
└── SETUP_GUIDE.md                 # Initial setup notes (can be removed)
```

## Development Workflow

### Code Quality Standards

All shell scripts must follow these standards:

1. **Strict mode**: Always start with `set -euo pipefail`
2. **2-space indentation**: Enforced by shfmt
3. **ShellCheck compliance**: No warnings allowed
4. **Proper quoting**: All variables must be quoted
5. **External sources**: Use `shellcheck --external-sources` for sourced files

### Pre-commit Hooks

This repository uses pre-commit hooks to enforce code quality:

```bash
# Install pre-commit
pip install pre-commit

# Set up hooks
pre-commit install

# Run manually
pre-commit run --all-files
```

**Hooks include:**
- `shellcheck` - Bash linting with external sources support
- `shfmt` - Shell formatting (2-space indent, binary ops line start)
- `hadolint` - Dockerfile linting
- `no-commit-to-branch` - Prevents commits to main/master
- Standard checks: trailing whitespace, EOF newlines, merge conflicts

### Git Workflow

**IMPORTANT**: This repository uses feature branches. **Never commit directly to main.**

```bash
# Create feature branch
git checkout -b feature/my-feature
# or
git checkout -b fix/bug-description
# or
git checkout -b refactor/improvement

# Make changes and commit
git add .
git commit -m "Description of changes"

# Push and create PR
git push origin feature/my-feature
```

**Pre-commit hooks will prevent commits to main**, but always use feature branches as best practice.

### Testing Locally

**With Docker:**
```bash
# Build the container
docker build -t mc-server-container:test .

# Run with minimal config
docker run -d --name mc-test -e EULA=TRUE mc-server-container:test

# Check logs
docker logs mc-test

# Cleanup
docker stop mc-test && docker rm mc-test
```

**With Podman (OCI compliance verification):**
```bash
# Build the container
podman build -t mc-server-container:test .

# Run with minimal config
podman run -d --name mc-test -e EULA=TRUE mc-server-container:test

# Check logs
podman logs mc-test

# Cleanup
podman stop mc-test && podman rm mc-test
```

## GitHub Actions Workflows

### Cost-Optimized Workflow Architecture

This repository uses a **label-gated workflow** to reduce CI costs by ~79% while maintaining fast feedback:

**Lightweight Validation (runs on every commit):**
- ✅ ShellCheck - Validates shell scripts (~30 seconds, ubuntu-slim)
- ✅ Hadolint - Validates Dockerfile (~30 seconds, ubuntu-slim)
- 💰 **Cost**: ~$0.001-0.002 per commit

**Heavy CI/CD Pipeline (only runs when `ci/ready` label is present):**
- 🏗️ Build container → Security scan → Test (Docker + Podman) → Release
- 💰 **Cost**: ~$0.08-0.12 per run

**Workflow:**
1. Create PR → Lightweight checks run automatically on each commit
2. Add `ci/ready` label → Full pipeline runs
3. Push new commits → Label auto-removed, re-add when ready
4. Merge to main → Full pipeline always runs (no label needed)

### 1. ShellCheck Workflow (`.github/workflows/shellcheck.yml`)

Runs on every push and PR when `**.sh` files change:

- **Runner**: ubuntu-slim
- Finds all `.sh` files
- Changes into each script's directory before running ShellCheck
- Uses `--external-sources` flag for sourced files
- Labels PRs with `shellcheck` on success
- Fails build if any warnings/errors found

### 2. Hadolint Workflow (`.github/workflows/hadolint.yml`)

Runs on every push and PR when `Dockerfile` changes:

- **Runner**: ubuntu-slim
- Lints Dockerfile for best practices
- Ignores: DL3008, DL3018 (version pinning rules)
- Fails build if any errors found

### 3. Label Management (`.github/workflows/label-management.yml`)

Automatically removes `ci/ready` label when new commits are pushed:

- **Runner**: ubuntu-slim
- **Trigger**: PR synchronize (new commits)
- Removes `ci/ready` label if present
- Adds comment: "🔄 New commits detected. The `ci/ready` label has been removed. Please re-add the label when ready to trigger the full CI/CD pipeline."

### 4. CI/CD Pipeline (`.github/workflows/ci-cd.yml`)

**Label-gated pipeline** with proper job dependencies:

**Trigger Logic:**
- **Always runs**: Push to main branch
- **Conditional**: PR with `ci/ready` label

**Job Flow:**
1. **check-trigger** (ubuntu-slim): Determines if pipeline should run based on trigger conditions
2. **lint-dockerfile** (ubuntu-latest): Lints Dockerfile (skipped if check-trigger says no)
3. **build** (ubuntu-latest): Builds container once and saves as artifact
4. **security-scan** (ubuntu-latest): Scans the built artifact with Trivy
5. **test-docker** (ubuntu-latest): Tests with Docker runtime
6. **test-podman** (ubuntu-latest): Tests with Podman runtime (OCI compliance)
7. **check-release** (ubuntu-slim): Checks for release labels on main branch pushes
8. **release** (ubuntu-latest): Tags and pushes tested artifact to GHCR, creates GitHub release

**Key Features:**
- Container is built once and reused across all jobs via artifacts
- Security scanning happens before testing
- Released images are identical to tested images
- Proper job dependencies ensure pipeline flow
- Label gating reduces unnecessary builds during review iterations

**Paper JAR Caching**: Both test jobs use GitHub Actions cache to avoid re-downloading the Paper JAR on every run:
- Cache key is based on Paper version and build number (e.g., `paper-jar-1.21.4-123`)
- Paper JAR is only downloaded on cache miss
- Cached JARs are retained for 7 days (managed by cache-cleanup workflow)
- Each test job maintains its own cache entry to avoid conflicts

**Release Process**:
- Only runs on main branch when a PR with `release:major`, `release:minor`, or `release:patch` label is merged
- Uses semantic versioning based on label
- Pushes tested container to GHCR with version tag and latest tag
- Creates GitHub release with tag and notes

### 5. Scheduled Security Scan (`.github/workflows/security-scan.yml`)

Daily scheduled security scanning (separate from CI/CD pipeline):

- **Schedule**: Daily (03:00 UTC)
- **Tool**: Trivy vulnerability scanner
- **Output**: Table and JSON reports in logs, creates/updates issues for CRITICAL/HIGH vulnerabilities
- Also runs on manual trigger (workflow_dispatch)

### 6. Dependency Monitoring Workflows

The repository includes automated dependency monitoring:

#### Dependency Check (`.github/workflows/dependency-check.yml`)
- **Schedule**: Weekly (Mondays at 09:00 UTC)
- **Checks**: mc-server-runner, rcon-cli, OpenTelemetry Java agent, Docker base image
- **Output**: Creates/updates issues when updates available

#### Pre-commit Updates (`.github/workflows/precommit-updates.yml`)
- **Schedule**: Weekly (Mondays at 09:30 UTC)
- **Action**: Automatically creates PRs with pre-commit hook updates

#### Dependency Dashboard (`.github/workflows/dependency-dashboard.yml`)
- **Schedule**: Weekly (Mondays at 10:00 UTC)
- **Output**: Maintains comprehensive dashboard issue with all dependency statuses

#### Dependabot (`.github/dependabot.yml`)
- **Schedule**: Weekly
- **Monitors**: GitHub Actions and Docker base image versions
- **Output**: Automatically creates PRs with updates

See [Dependency Management Guide](docs/DEPENDENCY_MANAGEMENT.md) for details.

## Container Architecture

### Process Management

The container uses **mc-server-runner** for professional process supervision:

- **Named pipe**: `/tmp/minecraft-console` for console commands
- **Graceful shutdown**: 30-second warning before stop
- **Signal handling**: Proper SIGTERM/SIGINT handling
- **Exit code**: Forwards server exit code

### Directory Layout

```
/data/                          # Volume mount point
├── paper.jar                   # Paper server JAR (manual)
├── server.properties           # Server configuration
├── bukkit.yml                  # Bukkit configuration
├── spigot.yml                  # Spigot configuration
├── paper-global.yml            # Paper global config
├── paper-world-defaults.yml    # Paper world defaults
├── plugins/                    # Server plugins
│   ├── LuckPerms.jar
│   ├── CoreProtect.jar
│   └── ...
├── world/                      # Main world data
├── world_nether/               # Nether dimension
├── world_the_end/              # End dimension
├── whitelist.json              # Whitelist
├── ops.json                    # Operators
└── logs/                       # Server logs
```

### Environment Variables

This container focuses on **JVM configuration only**. Minecraft-specific configuration (server.properties, plugins, etc.) should be managed manually or via helper scripts.

**Philosophy: Performance-First with Troubleshooting Options**
- All performance optimizations are **ENABLED by default**
- Use `DISABLE_*` variables only for troubleshooting
- OpenTelemetry agent is **ENABLED by default** with sensible defaults
- Users only need to set minimal configuration

**JVM Memory:**
- `MEMORY` - Server memory allocation (default: `16G`)

**JVM Performance Tuning (for troubleshooting only):**
- `DISABLE_MEOWICE_FLAGS` - Disable MeowIce G1GC optimizations (default: enabled)
- `DISABLE_MEOWICE_GRAALVM_FLAGS` - Disable GraalVM-specific optimizations (default: enabled)
- `JAVA_OPTS_CUSTOM` - Add custom JVM options (appended to generated flags)

**OpenTelemetry (enabled by default, requires configuration file):**
- `OTEL_JAVAAGENT_CONFIGURATION_FILE` - Path to OpenTelemetry Java agent configuration file (required for agent to load)
  - Example: `/data/otel-config.properties`
  - File must contain at minimum: `otel.service.name` and `otel.exporter.otlp.endpoint`
  - See Java agent documentation for all available properties
- `DISABLE_OTEL_AGENT` - Disable OpenTelemetry agent entirely (default: enabled)

**Example configuration file (`/data/otel-config.properties`):**
```properties
otel.service.name=minecraft-server
otel.exporter.otlp.endpoint=http://otel-collector:4317
otel.exporter.otlp.protocol=grpc
otel.resource.attributes=deployment.environment=production
otel.metrics.exporter=otlp
otel.logs.exporter=otlp
otel.traces.exporter=otlp
```

**Note:** The container does NOT handle Minecraft-specific configuration via environment variables. Use `/data/server.properties` and other Minecraft config files for server settings, or use helper scripts from the `check-minecraft-versions` repository.

## OCI Compliance

This container produces **OCI-compliant images** that work seamlessly across different container runtimes.

### What is OCI Compliance?

The [Open Container Initiative (OCI)](https://opencontainers.org/) defines standards for container formats and runtimes. This container is built using **Docker Buildx with BuildKit**, which produces images conforming to the [OCI Image Format Specification](https://github.com/opencontainers/image-spec).

### Supported Runtimes

Our OCI-compliant images work with:

- ✅ **Docker** - Traditional Docker Engine and Docker Desktop
- ✅ **Podman** - Daemonless, rootless container engine
- ✅ **Kubernetes** - containerd and CRI-O runtimes
- ✅ **OpenShift** - Enterprise Kubernetes platform
- ✅ **containerd** - Industry-standard container runtime
- ✅ **CRI-O** - Lightweight Kubernetes runtime
- ✅ Any OCI-compliant container runtime

### Why It Matters

**Portability**: The same image works across different container runtimes and orchestration platforms without modification.

**Security**: Compatible with rootless Podman for enhanced security. The container already runs as non-root user (UID 25565), making it ideal for rootless deployments.

**Flexibility**: Deploy to Docker, Kubernetes, edge environments, or cloud platforms without changes.

**Future-proof**: Based on open standards (OCI), not vendor lock-in.

### Verification

Our CI pipeline includes a dedicated Podman test job (`test-podman` in `ci-cd.yml`) that:
1. Installs Podman on the test runner
2. Loads the pre-built container artifact (from the build job)
3. Runs the same integration tests used for Docker
4. Verifies the Paper server starts successfully with Podman

This ensures every build is verified to work with both Docker and Podman, guaranteeing cross-runtime compatibility. The export/import process validates that the OCI image format is truly portable between runtimes.

### Build Process

The build process uses Docker Buildx with BuildKit:
- Multi-stage builds for minimal image size
- OCI-compliant image layers
- Compatible with any OCI registry (GHCR, Docker Hub, Quay.io, etc.)

**Important**: You do NOT need to migrate from Docker to Podman for building. Docker Buildx already produces OCI-compliant images. Use whichever runtime you prefer for development and deployment.

## Development Guidelines

### When Working on Scripts

1. **Always read TODO.MD** - Contains detailed implementation requirements
2. **Use existing patterns** - Check other bash repos (scripts/, check-minecraft-versions/) for patterns
3. **Test with ShellCheck** - Run `shellcheck --external-sources script.sh` before committing
4. **Format with shfmt** - Run `shfmt -i 2 -ci -w script.sh`
5. **Test in container** - Build and run container to verify changes

### When Working on Dockerfile

1. **Check hadolint** - Run `hadolint Dockerfile` before committing
2. **Multi-stage builds** - Consider using multi-stage builds for smaller images
3. **Layer caching** - Order commands from least to most frequently changing
4. **Security** - Run as non-root user (UID 25565, GID 25565)
5. **Minimal layers** - Combine RUN commands when logical

### When Adding Features

1. **Update TODO.MD** - Document the feature requirements
2. **Update README.md** - Add user-facing documentation
3. **Add tests** - Update `.github/workflows/ci-cd.yml` if needed
4. **Test locally** - Build and run container with new feature
5. **Create PR** - Use feature branch and add appropriate release label

## Backward Compatibility

The container includes a symlink for backward compatibility with external scripts that may reference the older command name:

- `/usr/local/bin/mc-send-to-console` → `/usr/local/bin/mc-send-to-console.sh`

This ensures that:
- **Existing scripts** (backup scripts, monitoring tools, etc.) continue to work without modification
- **New scripts** can use the `.sh` extension for consistency with ShellCheck automation
- **Both names** are valid and will continue to work indefinitely

Note: `mc-health.sh` does not need a symlink since it's only called by the Dockerfile's HEALTHCHECK directive, which is self-contained and updated accordingly.

When referencing these commands in documentation or new scripts, prefer the `.sh` extension.

## Common Tasks

### Building the Container

**With Docker:**
```bash
# Build with default settings
docker build -t mc-server-container:local .

# Build with build args (if needed)
docker build --build-arg VERSION=1.0.0 -t mc-server-container:local .
```

**With Podman:**
```bash
# Build with default settings
podman build -t mc-server-container:local .

# Build with build args (if needed)
podman build --build-arg VERSION=1.0.0 -t mc-server-container:local .
```

### Testing Changes

**With Docker:**
```bash
# Test with docker-compose
docker-compose up -d
docker-compose logs -f
docker-compose down

# Test with manual docker run
docker run -d \
  --name mc-test \
  -e EULA=TRUE \
  -e MEMORY=4G \
  -v $(pwd)/test-data:/data \
  mc-server-container:local

docker logs -f mc-test
docker exec mc-test rcon-cli
docker stop mc-test && docker rm mc-test
```

**With Podman:**
```bash
# Test with manual podman run
podman run -d \
  --name mc-test \
  -e EULA=TRUE \
  -e MEMORY=4G \
  -v $(pwd)/test-data:/data:Z \
  mc-server-container:local

podman logs -f mc-test
podman exec mc-test rcon-cli
podman stop mc-test && podman rm mc-test
```

### Updating Dependencies

Dependencies in this container:

1. **mc-server-runner** - Download latest from GitHub releases
2. **rcon-cli** - Download latest from GitHub releases
3. **OpenTelemetry Java agent** - Download latest from GitHub releases
4. **Paper JAR** - User manages manually (or use `download-paper.sh` helper)
5. **Plugins** - User manages manually (or use `update-plugins.sh` helper)

## Release Process

1. **Create feature branch**: `git checkout -b feature/my-feature`
2. **Make changes**: Edit code, update docs
3. **Test locally**: Run pre-commit hooks and build container
4. **Push branch**: `git push origin feature/my-feature`
5. **Create PR**: Add description and appropriate release label
   - `release:major` - Breaking changes (1.0.0 → 2.0.0)
   - `release:minor` - New features (1.0.0 → 1.1.0)
   - `release:patch` - Bug fixes (1.0.0 → 1.0.1)
6. **Review and merge**: GitHub Actions will automatically release

## Troubleshooting

### ShellCheck Errors

If shellcheck fails in CI but works locally:

- Ensure you're using `shellcheck --external-sources`
- Check that shellcheck runs from the script's directory
- Use `.shellcheck-wrapper.sh` for consistency

### Docker Build Fails

Common issues:

- **Hadolint errors**: Run `hadolint Dockerfile` to see issues
- **Layer caching**: Try `docker build --no-cache`
- **Missing files**: Ensure all `COPY` sources exist

### Container Won't Start

Debug steps:

```bash
# Check container logs
docker logs container-name

# Check if EULA was accepted
docker exec container-name cat /data/eula.txt

# Check Java version
docker exec container-name java -version

# Interactive shell (explicit /bin/bash required due to /bin/false user shell)
docker exec -it container-name /bin/bash
```

## Integration with Other Repositories

This container is part of a larger Minecraft server infrastructure:

- **check-minecraft-versions** - Can be used to check for Paper/plugin updates
- **scripts** (local-bin/local-sbin) - Server management and backup scripts
- **server-config** (Ansible) - Can deploy docker-compose configuration
- **phantom-proxy-container** - Bedrock proxy for same server infrastructure

When developing, consider how changes might affect:
- Backup scripts (rsync, Borgmatic integration)
- Update checking (Paper API, Modrinth API)
- Monitoring (OpenTelemetry, Prometheus)

## References

- **mc-server-runner**: https://github.com/itzg/mc-server-runner
- **rcon-cli**: https://github.com/itzg/rcon-cli
- **OpenTelemetry Java agent**: https://github.com/open-telemetry/opentelemetry-java-instrumentation
- **itzg/minecraft-server** (reference): https://github.com/itzg/docker-minecraft-server
- **Meowice flags**: https://github.com/Meowice/Minecraft-Server-Startup-Flags
- **Paper API**: https://api.papermc.io/docs/
- **GraalVM**: https://www.graalvm.org/

## Notes for Claude Code

- **TODO.MD** contains the full project plan and requirements - always consult it
- This is a **container repository**, not a script repository - focus on Docker best practices
- **Never commit to main** - pre-commit hooks enforce this
- **ShellCheck and hadolint are mandatory** - all scripts and Dockerfiles must pass
- **Release workflow uses PR labels** - add `release:*` label to trigger releases
- **Test everything locally** before creating PR
- **OCI compliance is verified** - Images work with Docker, Podman, Kubernetes, and other OCI runtimes
- When in doubt about patterns, check **phantom-proxy-container** (similar container repo)
