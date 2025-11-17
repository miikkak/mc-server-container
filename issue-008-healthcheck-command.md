# OpenRC: Add container health check command

**Labels**: `enhancement`
**Priority**: Low

## Summary

Add an optional health check command that users can run to verify the container's health status.

## Motivation

Users may want to:
- Check if the Minecraft server is responding
- Monitor container health from external scripts
- Verify the container is healthy after startup
- Integrate with monitoring systems

## Proposed Solution

Add a `healthcheck` command to the extra_started_commands:

```bash
extra_started_commands="healthcheck"

healthcheck() {
  if ! podman container exists "${CONTAINER_NAME}"; then
    eerror "Container ${CONTAINER_NAME} does not exist"
    return 1
  fi

  # Check container state
  local state
  state=$(podman inspect "${CONTAINER_NAME}" --format '{{.State.Status}}' 2>/dev/null)

  if [ "$state" != "running" ]; then
    eerror "Container is not running (state: ${state})"
    return 1
  fi

  # Check health status (if container has HEALTHCHECK)
  local health_status
  health_status=$(podman inspect "${CONTAINER_NAME}" --format '{{.State.Health.Status}}' 2>/dev/null)

  if [ -n "$health_status" ] && [ "$health_status" != "<no value>" ]; then
    einfo "Container: ${state}"
    einfo "Health: ${health_status}"

    # Return success only if healthy
    if [ "$health_status" = "healthy" ]; then
      return 0
    else
      ewarn "Container is running but health check reports: ${health_status}"
      return 1
    fi
  else
    # No health check defined, just report running state
    einfo "Container: ${state}"
    einfo "Health: No health check defined"
    return 0
  fi
}
```

## Usage Examples

```bash
# Check health of default server
rc-service minecraft healthcheck

# Check health of specific instance
rc-service minecraft.survival healthcheck

# Use in monitoring scripts
if rc-service minecraft healthcheck; then
  echo "Server is healthy"
else
  echo "Server has issues"
fi

# Check all instances
for svc in /etc/init.d/minecraft.*; do
  echo "Checking $(basename "$svc")..."
  rc-service "$(basename "$svc")" healthcheck
done
```

## Output Examples

**Healthy container**:
```
* Container: running
* Health: healthy
```

**Container without health check**:
```
* Container: running
* Health: No health check defined
```

**Unhealthy container**:
```
* Container: running
* Health: unhealthy
* WARNING: Container is running but health check reports: unhealthy
```

**Stopped container**:
```
* ERROR: Container is not running (state: exited)
```

## Benefits

- **Monitoring integration**: Easy to integrate with Nagios, Prometheus, etc.
- **User-friendly**: Simple command to check server health
- **Consistent interface**: Uses OpenRC's standard command structure
- **No external dependencies**: Uses built-in podman inspect

## Alternative: RCON-based health check

For a more thorough check, could also verify RCON connectivity:

```bash
healthcheck() {
  # ... existing container state checks ...

  # Optionally check RCON connectivity
  if [ "${HEALTHCHECK_RCON}" = "true" ]; then
    if podman exec "${CONTAINER_NAME}" rcon-cli list >/dev/null 2>&1; then
      einfo "RCON: responsive"
    else
      ewarn "RCON: not responsive"
      return 1
    fi
  fi
}
```

## Related

Found during comprehensive OpenRC init script review.
