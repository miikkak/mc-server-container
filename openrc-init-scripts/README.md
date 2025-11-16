# OpenRC Init Scripts for Minecraft Server

This directory contains OpenRC init scripts for managing a Minecraft server running in a Podman container.

## Installation

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

## Configuration

All configuration is done through `/etc/conf.d/minecraft`. The init script includes sensible defaults, but you can override any value by setting it in the conf.d file.

### Container Settings

- `CONTAINER_NAME` - Name of the container (default: `mc`)
- `CONTAINER_IMAGE` - Container image to use (default: `ghcr.io/miikkak/mc-server-container:latest`)
- `CONTAINER_MEMORY` - Memory limit for the container (default: `24G`)
- `CONTAINER_STOP_TIMEOUT` - Graceful shutdown timeout in seconds (default: `120`)

### Network Settings

- `NETWORK_NAME` - Name of the Podman network (default: `minecraft-net`)
- `NETWORK_SUBNET` - Subnet for the Podman network (default: `10.10.10.0/24`)
- `NETWORK_GATEWAY` - Gateway for the Podman network (default: `10.10.10.1`)
- `CONTAINER_IP` - IPv4 address for the container (default: `10.10.10.10`)
- `CONTAINER_IPv6` - IPv6 address for the container (default: `2a01:4f9:3070:1169::b10c:cafe`)
- `CONTAINER_INTERFACE` - Container's network interface name (default: auto-detect)
  - Leave empty for automatic detection of the first non-loopback interface
  - Set explicitly (e.g., `eth0`) only if auto-detection fails or you need a specific interface
- `NETWORK_DISABLE_DNS` - Disable DNS in the Podman network (default: `true`)

### Volume Mounts

- `CONTAINER_VOLUMES` - Space-separated list of volume mounts in format `host:container`
  
  Default:
  ```bash
  CONTAINER_VOLUMES="/srv/minecraft:/data /srv/bluemap:/data/bluemap"
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
  
  **Note**: Environment variable values cannot contain spaces, as they are split on whitespace. Use simple values like paths or flags without spaces.
  
  Default:
  ```bash
  CONTAINER_ENV="OTEL_JAVAAGENT_CONFIGURATION_FILE=/data/otel-config.properties"
  ```
  
  Example with multiple variables:
  ```bash
  CONTAINER_ENV="VAR1=value with spaces
VAR2=another value
VAR3=simple"
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

## Example Configuration

Here's an example `/etc/conf.d/minecraft` with custom settings:

```bash
# Container configuration
CONTAINER_NAME="my-minecraft-server"
CONTAINER_IMAGE="ghcr.io/miikkak/mc-server-container:v1.2.3"
CONTAINER_MEMORY="16G"

# Network configuration
NETWORK_NAME="mc-network"
CONTAINER_IP="10.20.30.40"
CONTAINER_IPv6="2001:db8::1"  # Replace with your actual IPv6 address

# Custom volumes
CONTAINER_VOLUMES="/mnt/data/minecraft:/data /mnt/data/bluemap:/data/bluemap"

# Custom ports (only expose 25565)
CONTAINER_PORTS="25565:25565/tcp 25565:25565/udp"

# Custom environment (newline-separated)
CONTAINER_ENV="OTEL_JAVAAGENT_CONFIGURATION_FILE=/data/otel-config.properties
JAVA_OPTS=-XX:+UseG1GC"
# Custom environment (note: values cannot contain spaces)
CONTAINER_ENV="OTEL_JAVAAGENT_CONFIGURATION_FILE=/data/otel-config.properties MEMORY=8G"

# Custom labels (newline-separated)
CONTAINER_LABELS="minecraft.server=true
minecraft.name=MyServer
minecraft.version=1.21.4"
```

## Features

- **Automatic network creation**: Creates the Podman network if it doesn't exist
- **IPv6 support**: Configures IPv6 address and routing for the container
- **Graceful shutdown**: Waits for the server to shut down gracefully
- **Container reuse**: Starts existing containers instead of recreating them
- **Dependencies**: Properly depends on network and optionally uses ndppd for IPv6 NDP proxy

## Dependencies

- `podman` - Container runtime
- `ndppd` (optional) - For IPv6 NDP proxy functionality
- `nsenter` - For IPv6 configuration (usually part of `util-linux`)
- `iproute2` - For network routing commands

## Notes

- The init script uses `shellcheck shell=bash` directive because OpenRC scripts run in a bash-compatible shell
- All default values in the init script match the values in `/etc/conf.d/minecraft`
- The configuration file uses `${VAR:-default}` syntax to provide defaults if variables are not set
- Volumes and data are preserved when the container is stopped or removed
