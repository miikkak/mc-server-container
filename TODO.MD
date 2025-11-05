# Project Definition: Custom Minecraft Server Container

## Goal
Build a minimal, controlled Minecraft server Docker container that replaces itzg/minecraft-server with a custom solution using mc-server-runner, eliminating Java helper tool dependencies and compatibility issues while maintaining professional process management.

## Current State
- Using `itzg/minecraft-server:java25-graalvm`
- Running Paper 1.21.10 server
- Experiencing Java 25 compatibility warnings from:
  - mc-image-helper (Netty 4.1.x using sun.misc.Unsafe)
  - OpenTelemetry Java agent (ByteBuddy using sun.misc.Unsafe)
- Managing 22 plugins via PLUGINS environment variable
- Complex init process with multiple Java tool invocations
- Boot delays from API calls to Paper/plugin download sources

## Target State
- Custom Docker image based on `container-registry.oracle.com/graalvm/jdk:latest` (or similar suitable, any case latest available Oracle GraalVM LTS)
- mc-server-runner (Go binary) for process management
- Manual Paper JAR management (no auto-download)
- Bash-based plugin management (optional automation, existing in repository check-minecraft-versions)
- Clean boot process with no Java helper tools
- No Java 25 compatibility warnings during startup

## Components to Include

### Core Binaries
1. **mc-server-runner** - Server process manager
   - Source: https://github.com/itzg/mc-server-runner
   - Handles graceful shutdown, signal management, process supervision
   - Creates named pipe for console commands
   
2. **rcon-cli** - RCON client tool
   - Source: https://github.com/itzg/rcon-cli
   - Command: `docker exec -it mc rcon-cli`
   
3. **mc-send-to-console** - Console command wrapper
   - Simple bash script that writes to named pipe
   - Command: `docker exec mc mc-send-to-console <command>`

### Configuration Files to Preserve
- `/data/server.properties`
- `/data/bukkit.yml`
- `/data/spigot.yml`
- `/data/paper-global.yml`
- `/data/paper-world-defaults.yml`
- `/data/whitelist.json`
- `/data/ops.json`
- `/data/permissions.yml` (LuckPerms)

### Current Environment Variables to Migrate
```yaml
# Server Identity
SERVER_NAME: "CubeSchool"
MOTD: "\\u00A73\\u00A7kLuokan servu\n\u00A79Luokan servu"

# Java Settings
MEMORY: "16G"
USE_MEOWICE_FLAGS: "true"
USE_MEOWICE_GRAALVM_FLAGS: "true"

# Server Properties
DIFFICULTY: "normal"
MAX_PLAYERS: "20"
ONLINE_MODE: "true"
ENABLE_WHITELIST: "true"
ENABLE_QUERY: "true"
ENABLE_COMMAND_BLOCK: "true"
ALLOW_FLIGHT: "true"
SEED: "-4339844081236397650"

# Monitoring (OpenTelemetry)
OTEL_SERVICE_NAME: "minecraft-cubeschool"
OTEL_RESOURCE_ATTRIBUTES: "..."
OTEL_EXPORTER_OTLP_ENDPOINT: "http://172.18.0.1:4317"
# [full OTEL config preserved]

# Management Server
MANAGEMENT_SERVER_ENABLED: "true"
MANAGEMENT_SERVER_PORT: "9000"
MANAGEMENT_SERVER_SECRET: ${MANAGEMENT_SERVER_SECRET}
```

### Current JVM Flags to Preserve
- Meowice flags for Java 17+
- Modified GraalVM flags for Java 24+
- OpenTelemetry Java agent configuration
- Memory settings: -Xms16G -Xmx16G

### Current Plugin List (22 plugins)
```
BlueMap (5.13)
CalcMod (1.4.2+paper.1.21.9-pre2)
Chunky (1.4.40)
ChunkyBorder (1.2.23)
CoreProtect (23.3)
Essentials suite (6 plugins)
Geyser-Spigot (2.9.0-SNAPSHOT)
GriefPrevention (16.18.5)
LuckPerms (5.5.18)
PrometheusExporter (3.1.2)
TabListPing (2.02)
UltimateShop (3.13.2)
Vault (1.7.3-b131)
ViaBackwards (5.5.1)
ViaVersion (5.5.1)
WorldEdit (7.3.17+7262-c7fbe08)
floodgate (2.2.5-SNAPSHOT)
mclogs (3.0.9)
```

## Tasks to Complete

### 1. Create Dockerfile
- [ ] Base image: `container-registry.oracle.com/graalvm/jdk:latest`
- [ ] Install mc-server-runner binary
- [ ] Install rcon-cli binary
- [ ] Create mc-send-to-console script
- [ ] Create minecraft user (UID 25565, GID 25565)
- [ ] Set up working directory and permissions
- [ ] Configure ENTRYPOINT with mc-server-runner

### 2. Create Entrypoint Configuration
- [ ] Extract current Meowice JVM flags from itzg logs
- [ ] Extract current GraalVM-specific flags
- [ ] Configure mc-server-runner parameters:
  - Shell: `/bin/sh`
  - Named pipe: `/tmp/minecraft-console`
  - Stop server announce delay: 30s
- [ ] Build complete Java command line with all flags

### 3. Create Helper Scripts (Optional)

#### download-paper.sh (check if covered with existing code in check-minecraft-versions)
- [ ] Download Paper JAR from PaperMC API
- [ ] Accept version as parameter
- [ ] Verify download integrity
- [ ] Place in `/data/paper.jar`

#### update-plugins.sh (likely covered completely in check-minecraft-versions)
- [ ] Read plugin URLs from config file
- [ ] Check if updates available (compare file size/hash)
- [ ] Download only changed plugins
- [ ] Place in `/data/plugins/`

### 4. Create Docker Compose Configuration
- [ ] Port mappings (same as current)
- [ ] Network configuration (minecraft4, minecraft6)
- [ ] Volume mounts:
  - `/srv/minecraft:/data`
  - `/srv/bluemap:/data/bluemap`
- [ ] Environment variables for OpenTelemetry
- [ ] Resource limits (24G memory limit)
- [ ] Health check configuration
- [ ] Logging configuration

### 5. Migration Steps
- [ ] Build new Docker image
- [ ] Test with existing `/srv/minecraft` data
- [ ] Verify all plugins load correctly
- [ ] Test RCON access
- [ ] Test console commands
- [ ] Verify OpenTelemetry metrics collection
- [ ] Test graceful shutdown
- [ ] Verify whitelist/ops work
- [ ] Performance comparison (boot time, runtime)

### 6. Documentation
- [ ] README with build instructions
- [ ] Usage guide for updating Paper
- [ ] Usage guide for managing plugins
- [ ] Troubleshooting guide
- [ ] Rollback procedure to itzg if needed

## Success Criteria
1. ✅ Server boots in <10 seconds (no API calls)
2. ✅ No Java 25 compatibility warnings during startup
3. ✅ All 22 plugins load successfully
4. ✅ RCON and console commands work
5. ✅ OpenTelemetry metrics collection continues
6. ✅ Graceful shutdown preserves world data
7. ✅ Server performance unchanged or better
8. ✅ Boot succeeds even when Paper/Modrinth APIs are down

## Risks & Mitigations
- **Risk**: Forgotten itzg functionality breaks something
  - *Mitigation*: Keep itzg setup in parallel initially, test thoroughly
  
- **Risk**: mc-server-runner doesn't handle edge cases
  - *Mitigation*: Review mc-server-runner issues/docs, test crash scenarios
  
- **Risk**: Manual updates become tedious
  - *Mitigation*: Create helper scripts to automate when needed

## Future Enhancements (Optional)
- Automated plugin update checker (cron job)
- Backup integration script
- Health check endpoint beyond Docker's basic check
- Metrics collection from server logs
- Automatic Paper update notifications (check only, not auto-update)
- Check if mc-send-to-console script is the best option or should be replaced with something more advanced

## References
- mc-server-runner: https://github.com/itzg/mc-server-runner
- rcon-cli: https://github.com/itzg/rcon-cli
- Current itzg image: https://github.com/itzg/docker-minecraft-server
- Meowice flags: https://github.com/Meowlce/Minecraft-Server-Startup-Flags
- Paper API: https://api.papermc.io/docs/

---

**Note**: This preserves full control while keeping professional process management. The trade-off is manual updates for predictability and clean architecture.
