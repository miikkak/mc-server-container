# Implementation Design Document

**Status:** Finalized - Ready for Implementation
**Date:** 2025-11-05
**Version:** 1.0

## Design Philosophy

This container follows a **pure separation of concerns** approach that cleanly divides infrastructure (JVM/container) from application (Minecraft) configuration.

### Core Principle

> **"Container handles JVM, /data handles Minecraft"**

This is a migration from itzg/minecraft-server to a minimal, controlled solution. We are **deliberately giving up automation** in favor of **control, transparency, and performance**.

## Architecture Decisions

### ✅ Decision 1: server.properties as Source of Truth

**Rejected Approach:** Environment variables → server.properties transformation (itzg pattern)

**Chosen Approach:** Direct file management

**Rationale:**
1. **Faster boot time** - No configuration processing overhead
2. **Single source of truth** - All Minecraft config in /data/server.properties
3. **Aligns with Paper documentation** - Paper docs reference server.properties, not env vars
4. **Production reality** - Existing server already has all configs in place
5. **Full transparency** - No hidden transformations
6. **Debugging simplicity** - Edit file → restart → change takes effect

**Trade-off Accepted:** New users must understand Paper configuration (but that's our target audience)

### ✅ Decision 2: Layer Separation

#### Layer 1: Container/JVM Configuration (docker-compose.yml)
**Scope:** "How to run a Java application"

Configuration includes:
- JVM heap size (`MEMORY`)
- JVM flags (hardcoded Meowice flags in entrypoint)
- Monitoring instrumentation (`OTEL_*` variables)
- Container resource limits
- Networking (IPv4/IPv6)
- Port mappings

**Would apply to:** Any Java server application

#### Layer 2: Minecraft Application (/data/)
**Scope:** "What the application does"

Configuration includes:
- `eula.txt` - EULA acceptance
- `server.properties` - Minecraft server settings
- `bukkit.yml`, `spigot.yml`, `paper-*.yml` - Server configs
- `paper.jar` - Application binary (user-provided)
- `plugins/` - Application extensions (user-provided)
- `whitelist.json`, `ops.json` - Game data
- `world/` - Game state

**Managed by:** User, Paper server, plugins (not container)

### ✅ Decision 3: Base Image

**Choice:** `container-registry.oracle.com/graalvm/jdk:25`

**Rationale:**
- Java 25 LTS (matches current production)
- GraalVM for optimal performance
- Oracle official registry (reliable)
- **NOT using `:latest`** - Pin to specific version for stability
- Future updates: Manual version bumps (controlled changes)

### ✅ Decision 4: JVM Flags

**Choice:** Hardcoded MeowIce G1GC flags

**Configuration:**
- Flags source: [MeowIce/meowice-flags](https://github.com/MeowIce/meowice-flags)
- GC Strategy: G1GC (for <32GB heap)
- Heap Size: 16G (configurable via `MEMORY` env var)
- Compiler: GraalVM Enterprise (`-Djdk.graal.CompilerConfiguration=enterprise`)

**Rationale:**
- 16GB heap confirmed for production
- G1GC appropriate for this heap size (ZGC only for ≥32GB)
- Proven performance improvement over Aikar's flags
- Hardcoded in entrypoint (no runtime discovery overhead)

### ✅ Decision 5: No Auto-Download

**Container does NOT provide:**
- ❌ Paper JAR downloading
- ❌ Plugin downloading
- ❌ Automatic updates
- ❌ Configuration generation

**User provides:**
- ✅ Pre-downloaded Paper JAR (`/data/paper.jar`)
- ✅ Pre-downloaded plugins (`/data/plugins/*.jar`)
- ✅ Pre-configured settings (`/data/server.properties`)
- ✅ EULA acceptance (`/data/eula.txt`)

**Rationale:**
- **Boot time goal:** <10 seconds (no API calls)
- **Offline operation:** Boots even when Paper/Modrinth APIs are down
- **Predictability:** No auto-update surprises
- **Integration:** User can use existing tools (check-minecraft-versions) for updates

### ✅ Decision 6: Minimal Environment Variables

**Only JVM/Infrastructure variables:**

| Variable | Purpose | Default |
|----------|---------|---------|
| `MEMORY` | JVM heap size | `16G` |
| `JAVA_OPTS_CUSTOM` | Additional JVM flags | _(empty)_ |
| `OTEL_SERVICE_NAME` | OpenTelemetry service name | _(none)_ |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | OTLP collector URL | _(none)_ |
| `OTEL_RESOURCE_ATTRIBUTES` | OTEL resource attributes | _(none)_ |
| _(other OTEL_* vars)_ | OpenTelemetry configuration | _(none)_ |

**All Minecraft configuration in /data files** - no env var → server.properties mapping

### ✅ Decision 7: Helper Scripts

**Included in Container:**
- ✅ `mc-server-runner` - Process supervisor (from itzg)
- ✅ `rcon-cli` - RCON client (from itzg)
- ✅ `mc-send-to-console` - Console command script (simple bash)

**NOT Included (User Manages):**
- ❌ `download-paper.sh` - User downloads manually or uses check-minecraft-versions
- ❌ `update-plugins.sh` - User uses existing check-minecraft-versions repo

**Rationale:**
- Keep container minimal
- Leverage existing tooling (check-minecraft-versions)
- User has full control over update process

## Success Criteria

### Performance Targets
1. ✅ Boot time <10 seconds (no API calls during startup)
2. ✅ No Java 25 compatibility warnings
3. ✅ Performance equal or better than itzg setup

### Functionality Targets
4. ✅ All 22 plugins load successfully
5. ✅ RCON access works (`rcon-cli`)
6. ✅ Console commands work (`mc-send-to-console`)
7. ✅ OpenTelemetry metrics collection continues
8. ✅ Graceful shutdown preserves world data
9. ✅ Offline operation (boots without internet access)

### Migration Targets
10. ✅ Existing /srv/minecraft data works without modification
11. ✅ Dual-stack networking (IPv4 + IPv6) works
12. ✅ BlueMap rendering continues (`/srv/bluemap` mount)

## Implementation Plan

### Phase 1: Core Container (3-4 hours)

**Tasks:**
1. Create multi-stage Dockerfile
   - Stage 1: Download mc-server-runner (v1.12.3) and rcon-cli (v1.7.2)
   - Stage 2: GraalVM JDK 25 base with binaries
2. Create `scripts/entrypoint.sh` with:
   - EULA validation
   - Paper JAR existence check
   - Hardcoded MeowIce G1GC flags
   - OpenTelemetry agent integration (conditional)
   - mc-server-runner execution
3. Create `scripts/mc-send-to-console` script
4. Set up minecraft user (UID 25565, GID 25565)
5. Configure permissions for /data

**Deliverable:** Buildable container image

### Phase 2: Testing & Validation (3-4 hours)

**Tasks:**
1. Test container build
2. Create example `docker-compose.yml` with JVM/infrastructure config
3. Test with fresh Paper 1.21.10 download
4. Verify RCON functionality
5. Verify mc-send-to-console functionality
6. Test graceful shutdown (SIGTERM handling)
7. Measure boot time

**Deliverable:** Verified working container

### Phase 3: Production Migration Testing (3-4 hours)

**Tasks:**
1. Create read-only copy of production data (`/srv/minecraft → /tmp/minecraft-test`)
2. Test with production data (read-only mount)
3. Verify all 22 plugins load correctly
4. Test OpenTelemetry integration with actual collector
5. Verify dual-stack networking (minecraft4, minecraft6)
6. Performance comparison vs itzg (boot time, runtime)
7. Test management server API (port 9000)

**Deliverable:** Production-ready container

### Phase 4: Documentation (2-3 hours)

**Tasks:**
1. Update README.md:
   - Quick start guide
   - /data directory structure
   - Environment variables reference
   - Examples
2. Create MIGRATION.md:
   - Migration from itzg guide
   - Differences from itzg
   - Rollback procedure
3. Document integration with check-minecraft-versions
4. Create troubleshooting guide

**Deliverable:** Complete documentation

## File Structure

```
mc-server-container/
├── Dockerfile                      # Multi-stage build
├── docker-compose.yml              # Example infrastructure config
├── scripts/
│   ├── entrypoint.sh              # Main entrypoint
│   └── mc-send-to-console         # Console command wrapper
├── .github/                        # CI/CD (already complete)
├── README.md                       # User documentation
├── DESIGN.md                       # This file
├── MIGRATION.md                    # Migration guide (to create)
└── TODO.md                         # Original project definition

/srv/minecraft/                     # Mount point (user manages)
├── eula.txt
├── server.properties
├── paper.jar
├── plugins/
└── world/
```

## Docker Compose Example

```yaml
services:
  minecraft:
    image: ghcr.io/miikkak/mc-server-container:latest
    container_name: minecraft-cubeschool
    restart: unless-stopped

    # JVM/Infrastructure Configuration
    environment:
      MEMORY: "16G"
      OTEL_SERVICE_NAME: "minecraft-cubeschool"
      OTEL_EXPORTER_OTLP_ENDPOINT: "http://172.18.0.1:4317"
      OTEL_RESOURCE_ATTRIBUTES: "service.namespace=minecraft,deployment.environment=production"

    # Container Infrastructure
    networks:
      - minecraft4
      - minecraft6

    ports:
      - "25565:25565/tcp"
      - "25565:25565/udp"
      - "9000:9000/tcp"

    volumes:
      - /srv/minecraft:/data
      - /srv/bluemap:/bluemap

    deploy:
      resources:
        limits:
          memory: 24G

    healthcheck:
      test: ["CMD", "rcon-cli", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

networks:
  minecraft4:
    driver: bridge
  minecraft6:
    driver: bridge
    enable_ipv6: true
```

## Entrypoint Logic Flow

```
1. Validate /data/eula.txt exists and contains "eula=true"
   ↓
2. Validate /data/paper.jar exists
   ↓
3. Build Java command:
   - Set heap size from MEMORY env var
   - Add hardcoded MeowIce G1GC flags
   - Add OpenTelemetry agent (if OTEL_* vars present)
   - Add custom opts (if JAVA_OPTS_CUSTOM set)
   ↓
4. Log startup information
   ↓
5. Execute: mc-server-runner → java → paper.jar
   ↓
6. On SIGTERM: mc-server-runner handles graceful shutdown
```

## Backup Strategy

**Backup scope:** `/srv/minecraft` directory only

**Command:**
```bash
rsync -av --delete /srv/minecraft/ /backup/minecraft-$(date +%Y%m%d)/
```

**Includes everything:**
- Server configuration (server.properties, etc.)
- Paper JAR
- Plugins
- World data
- Player data (whitelist, ops, bans)
- Plugin data (LuckPerms, CoreProtect, etc.)

**Does NOT need:**
- docker-compose.yml (infrastructure config, separate backup)
- Container image (rebuilt from Dockerfile)

## Migration from itzg

### Before Migration
1. Note all environment variables in current docker-compose.yml
2. Backup /srv/minecraft
3. Extract current Minecraft settings from itzg container

### Migration Steps
1. Stop itzg container: `docker-compose down`
2. Verify /srv/minecraft has:
   - `eula.txt` with `eula=true`
   - `paper.jar` (if not, download Paper 1.21.10)
   - `server.properties` (Paper creates on first run if missing)
   - `plugins/*.jar` (all 22 plugins)
3. Update docker-compose.yml:
   - Change image to new container
   - Remove Minecraft env vars (keep JVM/OTEL vars)
4. Start new container: `docker-compose up -d`
5. Monitor logs: `docker-compose logs -f`
6. Verify boot time, plugin loading, functionality

### Rollback Procedure
1. Stop new container: `docker-compose down`
2. Restore original docker-compose.yml
3. Start itzg container: `docker-compose up -d`
4. Data at /srv/minecraft is unchanged (backward compatible)

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|---------|------------|
| Data corruption | Critical | Test with read-only copy first; keep itzg available for rollback |
| Plugin incompatibility | High | Same Paper version, same plugins - should work |
| Performance regression | High | MeowIce flags proven faster; benchmark before/after |
| Missing itzg feature | Medium | Document differences; features can be added later if needed |
| Network configuration issues | High | Test dual-stack carefully; validate with production traffic |
| OpenTelemetry failure | Medium | Test with actual collector; agent is optional |

## Future Enhancements (Post-MVP)

- Optional: Add simple download-paper.sh helper script
- Optional: Health check via management API instead of RCON
- Optional: Prometheus metrics endpoint
- Documentation: Integration examples with check-minecraft-versions
- Documentation: Automated backup scripts
- CI/CD: Automated security scanning of container image

## References

- **mc-server-runner:** https://github.com/itzg/mc-server-runner (v1.12.3)
- **rcon-cli:** https://github.com/itzg/rcon-cli (v1.7.2)
- **MeowIce flags:** https://github.com/MeowIce/meowice-flags
- **Paper API:** https://api.papermc.io/docs/
- **GraalVM:** https://www.graalvm.org/
- **OpenTelemetry Java:** https://github.com/open-telemetry/opentelemetry-java-instrumentation

---

**This design document is the authoritative source for implementation decisions.**
