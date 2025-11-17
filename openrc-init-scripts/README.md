# OpenRC Init Scripts for Minecraft Server

This directory contains a **generic, symlink-based** OpenRC init script for managing multiple Minecraft servers in Podman containers.

## Overview

This init script uses the same pattern as OpenRC's `net.lo` service: a single generic script can manage multiple server instances via symlinks. Each symlink automatically uses its own configuration file.

**Example:**
- `/etc/init.d/minecraft` → Default server (uses `/etc/conf.d/minecraft`)
- `/etc/init.d/minecraft.survival` → Survival server (uses `/etc/conf.d/minecraft.survival`)
- `/etc/init.d/minecraft.creative` → Creative server (uses `/etc/conf.d/minecraft.creative`)

## Installation

### Single Server Setup

1. Copy the init script to `/etc/init.d/`:
   ```bash
   cp minecraft /etc/init.d/minecraft
   chmod +x /etc/init.d/minecraft
   ```

2. Copy the configuration file to `/etc/conf.d/`:
   ```bash
   cp conf.d/minecraft /etc/conf.d/minecraft
   ```

3. Edit `/etc/conf.d/minecraft` to customize your server settings.

### Multiple Server Setup

1. Install the base script (same as single server):
   ```bash
   cp minecraft /etc/init.d/minecraft
   chmod +x /etc/init.d/minecraft
   ```

2. Create symlinks for each server instance:
   ```bash
   ln -s /etc/init.d/minecraft /etc/init.d/minecraft.survival
   ln -s /etc/init.d/minecraft /etc/init.d/minecraft.creative
   ln -s /etc/init.d/minecraft /etc/init.d/minecraft.modded
   ```

3. Create configuration files for each instance:
   ```bash
   cp conf.d/minecraft /etc/conf.d/minecraft.survival
   cp conf.d/minecraft /etc/conf.d/minecraft.creative
   cp conf.d/minecraft /etc/conf.d/minecraft.modded
   ```

4. Edit each configuration file to set unique values (IPs, ports, volumes, etc.).

## How It Works

The init script detects its service name (via `$RC_SVCNAME`) and extracts the instance identifier.

**Instance naming rules:**
- Use only lowercase letters, numbers, and hyphens
- No dots, spaces, or special characters
- No leading or trailing hyphens
- Valid examples: `survival`, `creative`, `world-1`, `lobby-server`
- Invalid examples: `World.1`, `server_1`, `.survival`, `-lobby`

- Service name: `minecraft` → Instance: (default/empty)
  - Container name: `mc`
  - Network name: `minecraft-net`
  - Volumes: `/srv/minecraft:/data`, `/srv/bluemap:/data/bluemap`

- Service name: `minecraft.survival` → Instance: `survival`
  - Container name: `mc-survival`
  - Network name: `minecraft-survival-net`
  - Volumes: `/srv/minecraft/survival:/data`, `/srv/bluemap/survival:/data/bluemap`

- Service name: `minecraft.creative` → Instance: `creative`
  - Container name: `mc-creative`
  - Network name: `minecraft-creative-net`
  - Volumes: `/srv/minecraft/creative:/data`, `/srv/bluemap/creative:/data/bluemap`

This automatic naming ensures each server instance has isolated resources.

## Configuration

All configuration is done through `/etc/conf.d/${RC_SVCNAME}`. The init script includes instance-aware defaults, but you can override any value by setting it in the conf.d file.

### Container Settings

- `CONTAINER_NAME` - Name of the container
  - Default: `mc` (or `mc-${INSTANCE}` for symlinked services)
- `CONTAINER_IMAGE` - Container image to use (default: `ghcr.io/miikkak/mc-server-container:latest`)
- `CONTAINER_MEMORY` - Total memory limit for the container (default: `24G`)
  - **Important**: This is the total container memory limit (includes JVM heap + JVM overhead + container processes)
  - **Minimum**: 2G required (Paper server needs 1G heap + overhead)
  - The init script automatically calculates the JVM heap size (`MEMORY` environment variable) as a percentage of this value
  - Default calculation: 75% of `CONTAINER_MEMORY` is allocated to JVM heap (configurable via `CONTAINER_MEMORY_JVM_PERCENT`)
  - Example: `CONTAINER_MEMORY="24G"` → auto-calculates `MEMORY="18G"` for JVM heap
  - **Validation**: Service start fails if calculated heap < 1G or >= container limit
- `CONTAINER_MEMORY_JVM_PERCENT` - Percentage of container memory allocated to JVM heap (default: `75`)
  - This controls how much of `CONTAINER_MEMORY` is allocated to the JVM heap
  - The remaining percentage is headroom for JVM metaspace, native memory, and container overhead
  - Valid range: 1-80 (recommended: 70-75, max: 80)
  - Example: `CONTAINER_MEMORY="24G"` with `CONTAINER_MEMORY_JVM_PERCENT="80"` → `MEMORY="19G"`
  - **Maximum enforced**: 80% to ensure at least 20% overhead for metaspace, code cache, thread stacks, and native memory
  - **Note**: Values > 80% will cause service start failure to prevent OOM during operation
- `CONTAINER_STOP_TIMEOUT` - Graceful shutdown timeout in seconds (default: `120`)

### Network Settings

- `NETWORK_NAME` - Name of the Podman network
  - Default: `minecraft-net` (or `minecraft-${INSTANCE}-net` for symlinked services)
  - **Shared networks**: Set all instances to the same network name to allow inter-container communication (e.g., for Velocity proxy + backend servers)
- `NETWORK_SUBNET` - Subnet for the Podman network (default: `10.10.10.0/24`)
- `NETWORK_GATEWAY` - Gateway for the Podman network (default: `10.10.10.1`)
- `CONTAINER_IP` - IPv4 address for the container (default: `10.10.10.10`)
  - **Important**: Each container needs a unique IP within the network
- `CONTAINER_IPv6` - IPv6 address for the container (default: `2a01:4f9:3070:1169::b10c:cafe`)
  - **Important**: Each container needs a unique IPv6 address
  - **Skip IPv6**: Set to empty string (`CONTAINER_IPv6=""`) to skip IPv6 setup entirely (useful for internal-only servers)
- `CONTAINER_INTERFACE` - Container's network interface name (default: auto-detect)
  - Leave empty for automatic detection of the first non-loopback interface
  - Set explicitly (e.g., `eth0`) only if auto-detection fails or you need a specific interface
- `NETWORK_DISABLE_DNS` - Disable DNS in the Podman network (default: `true`)

### Volume Mounts

- `CONTAINER_VOLUMES` - Space-separated list of volume mounts in format `host:container`

  Default (for base `minecraft` service):
  ```bash
  CONTAINER_VOLUMES="/srv/minecraft:/data /srv/bluemap:/data/bluemap"
  ```

  Default (for symlinked service, e.g., `minecraft.survival`):
  ```bash
  CONTAINER_VOLUMES="/srv/minecraft/survival:/data /srv/bluemap/survival:/data/bluemap"
  ```

### Port Mappings

- `CONTAINER_PORTS` - Space-separated list of port mappings in format `host:container/protocol`

  Default:
  ```bash
  CONTAINER_PORTS="127.0.0.1:8100:8100 127.0.0.1:9000:9000 127.0.0.1:9940:9940 19132:19132/udp 25565:25565/udp 25565:25565/tcp"
  ```

### Environment Variables

- `CONTAINER_ENV` - Newline-separated list of environment variables in format `KEY=value`
  - Values may contain spaces
  - Use newlines to separate multiple entries
  - **Note**: The `MEMORY` environment variable is automatically calculated based on `CONTAINER_MEMORY`
    - Auto-calculated as 75% of `CONTAINER_MEMORY` (e.g., `CONTAINER_MEMORY="24G"` → `MEMORY="18G"`)
    - To override the auto-calculated value, add `MEMORY=<value>` to `CONTAINER_ENV`
    - Manual override is useful for fine-tuning or testing different JVM heap sizes

  Default:
  ```bash
  CONTAINER_ENV="OTEL_JAVAAGENT_CONFIGURATION_FILE=/data/otel-config.properties"
  # MEMORY is auto-calculated and added by the init script
  ```

  Example with manual MEMORY override:
  ```bash
  CONTAINER_ENV="MEMORY=20G
OTEL_JAVAAGENT_CONFIGURATION_FILE=/data/otel-config.properties"
  ```

  Example with custom JVM options:
  ```bash
  CONTAINER_ENV="MEMORY=20G
JAVA_OPTS_CUSTOM=-Xlog:gc*
OTEL_JAVAAGENT_CONFIGURATION_FILE=/data/otel-config.properties"
  ```

### Container Labels

- `CONTAINER_LABELS` - Newline-separated list of labels in format `key=value`
  - Values may contain spaces
  - Use newlines to separate multiple entries

  Default:
  ```bash
  CONTAINER_LABELS="minecraft.server=true
minecraft.name=CubeSchool"
  ```

  Example with values containing spaces:
  ```bash
  CONTAINER_LABELS="minecraft.server=true
minecraft.name=My Server Name
minecraft.description=A server for friends"
  ```

## Usage

### Single Server

```bash
# Start the server
rc-service minecraft start

# Stop the server
rc-service minecraft stop

# Check status
rc-service minecraft status

# Remove container (preserves data in volumes)
rc-service minecraft remove

# Enable at boot
rc-update add minecraft default
```

### Multiple Servers

```bash
# Start specific servers
rc-service minecraft.survival start
rc-service minecraft.creative start
rc-service minecraft.modded start

# Stop specific servers
rc-service minecraft.survival stop
rc-service minecraft.creative stop

# Check status of all servers
rc-service minecraft.survival status
rc-service minecraft.creative status
rc-service minecraft.modded status

# Enable servers at boot
rc-update add minecraft.survival default
rc-update add minecraft.creative default
rc-update add minecraft.modded default

# Start all Minecraft servers
for svc in /etc/init.d/minecraft.*; do
  rc-service "$(basename "$svc")" start
done
```

## Example Configuration

Here's an example `/etc/conf.d/minecraft` with custom settings:

```bash
# Container configuration
CONTAINER_NAME="my-minecraft-server"
CONTAINER_IMAGE="ghcr.io/miikkak/mc-server-container:v1.2.3"
CONTAINER_MEMORY="16G"  # Container limit; JVM will auto-calculate to 12G (75%)

# Network configuration
NETWORK_NAME="mc-network"
CONTAINER_IP="10.20.30.40"
CONTAINER_IPv6="2001:db8::1"  # Replace with your actual IPv6 address

# Custom volumes
CONTAINER_VOLUMES="/mnt/data/minecraft:/data /mnt/data/bluemap:/data/bluemap"

# Custom ports (only expose 25565)
CONTAINER_PORTS="25565:25565/tcp 25565:25565/udp"

# Custom environment (newline-separated)
# Note: MEMORY is auto-calculated from CONTAINER_MEMORY (add manually to override)
CONTAINER_ENV="OTEL_JAVAAGENT_CONFIGURATION_FILE=/data/otel-config.properties
JAVA_OPTS_CUSTOM=-Xlog:gc*"

# Custom labels (newline-separated)
CONTAINER_LABELS="minecraft.server=true
minecraft.name=MyServer
minecraft.version=1.21.4"
```

### Multiple Server Example

Here's an example of running three different server instances with different configurations:

**`/etc/conf.d/minecraft.survival`:**
```bash
# Survival server with 16GB container limit → 12G JVM heap (auto-calculated)
CONTAINER_MEMORY="16G"
CONTAINER_IP="10.10.10.10"
CONTAINER_IPv6="2a01:4f9:3070:1169::b10c:cafe"
CONTAINER_PORTS="25565:25565/tcp 25565:25565/udp"
# Volumes default to /srv/minecraft/survival:/data automatically
```

**`/etc/conf.d/minecraft.creative`:**
```bash
# Creative server with 8GB container limit → 6G JVM heap (auto-calculated)
CONTAINER_MEMORY="8G"
CONTAINER_IP="10.10.10.11"
CONTAINER_IPv6="2a01:4f9:3070:1169::b10c:caf1"
CONTAINER_PORTS="25566:25565/tcp 25566:25565/udp"
# Volumes default to /srv/minecraft/creative:/data automatically
```

**`/etc/conf.d/minecraft.modded`:**
```bash
# Modded server with 32GB container limit → 24G JVM heap (auto-calculated)
CONTAINER_MEMORY="32G"
CONTAINER_IP="10.10.10.12"
CONTAINER_IPv6="2a01:4f9:3070:1169::b10c:caf2"
CONTAINER_PORTS="25567:25565/tcp 25567:25565/udp"
CONTAINER_IMAGE="ghcr.io/miikkak/mc-server-container:modded"
# Volumes default to /srv/minecraft/modded:/data automatically
```

**Setup commands:**
```bash
# Create symlinks
ln -s /etc/init.d/minecraft /etc/init.d/minecraft.survival
ln -s /etc/init.d/minecraft /etc/init.d/minecraft.creative
ln -s /etc/init.d/minecraft /etc/init.d/minecraft.modded

# Create directories
mkdir -p /srv/minecraft/{survival,creative,modded}
mkdir -p /srv/bluemap/{survival,creative,modded}

# Start all servers
rc-service minecraft.survival start
rc-service minecraft.creative start
rc-service minecraft.modded start
```

### Proxy + Backend Servers Architecture

For running a Velocity proxy with multiple backend servers (lobby + world servers):

**`/etc/conf.d/minecraft.proxy` (Velocity - Internet-facing):**
```bash
# Velocity proxy exposed to the Internet
NETWORK_NAME="minecraft-net"  # Shared network
CONTAINER_IP="10.10.10.10"
CONTAINER_IPv6="2a01:4f9:3070:1169::b10c:cafe"  # Has IPv6
CONTAINER_PORTS="25565:25565/tcp 25565:25565/udp"  # Public ports
CONTAINER_VOLUMES="/srv/minecraft/proxy:/data"
CONTAINER_LABELS="minecraft.server=true
minecraft.name=proxy
minecraft.role=velocity"
```

**`/etc/conf.d/minecraft.lobby` (Backend - Internal only):**
```bash
# Lobby server - internal only
NETWORK_NAME="minecraft-net"  # Shared network with proxy
CONTAINER_IP="10.10.10.20"
CONTAINER_IPv6=""  # No IPv6 = skips IPv6 setup
CONTAINER_PORTS=""  # No port mappings - internal only
CONTAINER_VOLUMES="/srv/minecraft/lobby:/data"
CONTAINER_LABELS="minecraft.server=true
minecraft.name=lobby
minecraft.role=backend"
```

**`/etc/conf.d/minecraft.world1` (Backend - Internal only):**
```bash
# World server 1 - internal only
NETWORK_NAME="minecraft-net"
CONTAINER_IP="10.10.10.21"
CONTAINER_IPv6=""  # No IPv6
CONTAINER_PORTS=""  # Internal only
CONTAINER_VOLUMES="/srv/minecraft/world1:/data"
CONTAINER_LABELS="minecraft.server=true
minecraft.name=world1
minecraft.role=backend"
```

**Similar for `minecraft.world2` and `minecraft.world3`** (IPs: 10.10.10.22, 10.10.10.23)

**Setup commands:**
```bash
# Create symlinks
ln -s /etc/init.d/minecraft /etc/init.d/minecraft.proxy
ln -s /etc/init.d/minecraft /etc/init.d/minecraft.lobby
ln -s /etc/init.d/minecraft /etc/init.d/minecraft.world1
ln -s /etc/init.d/minecraft /etc/init.d/minecraft.world2
ln -s /etc/init.d/minecraft /etc/init.d/minecraft.world3

# Create directories
mkdir -p /srv/minecraft/{proxy,lobby,world1,world2,world3}

# Start all servers
rc-service minecraft.proxy start
rc-service minecraft.lobby start
rc-service minecraft.world1 start
rc-service minecraft.world2 start
rc-service minecraft.world3 start
```

**Key points:**
- All containers share the same network (`minecraft-net`) and can communicate
- Only the proxy has port mappings exposed to the Internet
- Backend servers have `CONTAINER_IPv6=""` which **automatically skips IPv6 setup**
- **Fixed internal IPs** make Velocity configuration stable and easy to maintain:
  - `10.10.10.10` - Velocity proxy
  - `10.10.10.20` - Lobby server
  - `10.10.10.21-23` - World servers (survival, creative, minigames, etc.)

**Example Velocity configuration** (`/srv/minecraft/proxy/velocity.toml`):
```toml
[servers]
lobby = "10.10.10.20:25565"
survival = "10.10.10.21:25565"
creative = "10.10.10.22:25565"
minigames = "10.10.10.23:25565"

try = [
  "lobby"
]
```

These IPs are **predictable and stable** - no DNS needed, no IP changes on container restart.

**Benefits of fixed internal IPs:**
- 🔒 **Stable configuration**: Velocity config doesn't change when containers restart
- 📝 **Easy maintenance**: You know exactly which IP belongs to which server
- 🚫 **No DNS required**: Direct IP addressing on internal network
- 🔍 **Simple troubleshooting**: `podman exec minecraft.lobby ping 10.10.10.10` to test connectivity
- 📊 **Predictable monitoring**: Fixed IPs for health checks and metrics collection

**IP allocation strategy:**
```
10.10.10.1    - Gateway (reserved)
10.10.10.10   - Proxy/Internet-facing services
10.10.10.20+  - Backend servers (lobby, worlds, etc.)
10.10.10.100+ - Reserved for future services (database, monitoring, etc.)
```

## Features

- **Symlink-based multi-instance support**: One script manages unlimited server instances via symlinks (just like `net.lo`)
- **Instance-aware defaults**: Each instance automatically gets isolated containers, networks, and volumes
- **Shared network support**: Override `NETWORK_NAME` to share a network between multiple containers
- **Automatic network creation**: Creates the Podman network if it doesn't exist
- **Optional IPv6 support**: Set `CONTAINER_IPv6=""` to skip IPv6 configuration (useful for internal-only servers)
- **Graceful shutdown**: Waits for the server to shut down gracefully
- **Container reuse**: Starts existing containers instead of recreating them
- **Dependencies**: Properly depends on network and optionally uses ndppd for IPv6 NDP proxy

## Dependencies

- `podman` - Container runtime
- `ndppd` (optional) - For IPv6 NDP proxy functionality
- `nsenter` - For IPv6 configuration (usually part of `util-linux`)
- `iproute2` - For network routing commands

## Notes

- **Symlink pattern**: This script uses the same approach as OpenRC's `net.lo` - symlink to create instances
- **Automatic config loading**: OpenRC automatically sources `/etc/conf.d/${RC_SVCNAME}` for each service
- **Instance detection**: The script detects its service name via `$RC_SVCNAME` and extracts the instance identifier
- **Isolated resources**: Each instance gets its own container, network, and default volume paths
- The init script uses `shellcheck shell=bash` directive because OpenRC scripts run in a bash-compatible shell
- The configuration file uses `${VAR:-default}` syntax to provide defaults if variables are not set
- Volumes and data are preserved when the container is stopped or removed
