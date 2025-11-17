# OpenRC: Make container startup timeout configurable

**Labels**: `enhancement`
**Priority**: Medium

## Summary

The container startup timeout is hardcoded to 30 seconds. Large servers with many plugins may require more time to start.

## Current Behavior

**Location**: `openrc-init-scripts/minecraft:364`

```bash
if timeout 30 podman wait --condition=running "${CONTAINER_NAME}" >/dev/null; then
```

The 30-second timeout is hardcoded and cannot be customized per instance.

## Problem

- Large modded servers may take longer than 30 seconds to start
- Servers with many plugins need more initialization time
- No way to adjust timeout without modifying the init script
- Failed starts due to timeout can be confusing (server eventually starts but service reports failure)

## Proposed Solution

Add a configuration variable in `conf.d/minecraft`:

```bash
# Container startup timeout in seconds (default: 30)
# Increase for large servers with many plugins
CONTAINER_START_TIMEOUT="${CONTAINER_START_TIMEOUT:-30}"
```

Update the script to use the variable:

```bash
if timeout "${CONTAINER_START_TIMEOUT}" podman wait --condition=running "${CONTAINER_NAME}" >/dev/null; then
```

## Benefits

- **Flexibility**: Users can adjust timeout based on their server size
- **No script modifications**: Configuration stays in conf.d files
- **Instance-specific**: Each instance can have its own timeout
- **Backward compatible**: Default remains 30 seconds

## Example Use Cases

```bash
# Small vanilla server
CONTAINER_START_TIMEOUT="30"

# Large modded server with 100+ mods
CONTAINER_START_TIMEOUT="120"

# Network proxy (fast startup)
CONTAINER_START_TIMEOUT="15"
```

## Related

Found during comprehensive OpenRC init script review.
