# OpenRC: Add debug/verbose mode for troubleshooting

**Labels**: `enhancement`
**Priority**: Low

## Summary

Most podman commands redirect output to `/dev/null`, making debugging difficult when things go wrong. Add an optional debug mode that preserves command output.

## Current Behavior

Throughout the script, podman commands suppress output:

```bash
podman start "${CONTAINER_NAME}" >/dev/null
podman run -d ... >/dev/null
podman network create ... >/dev/null
podman stop "${CONTAINER_NAME}" >/dev/null
```

This keeps the output clean for normal operation, but makes troubleshooting difficult.

## Problem

When something goes wrong:
- No podman error messages visible
- Hard to diagnose network issues
- Container creation failures are cryptic
- Users must manually run podman commands to debug

## Proposed Solution

Add a `DEBUG` configuration variable:

```bash
# In conf.d/minecraft
# Enable debug mode to show podman command output (useful for troubleshooting)
DEBUG="${DEBUG:-false}"
```

Update the script to conditionally suppress output:

```bash
# Helper function
run_podman() {
  if [ "${DEBUG}" = "true" ]; then
    "$@"
  else
    "$@" >/dev/null
  fi
}

# Usage
run_podman podman start "${CONTAINER_NAME}"
run_podman podman network create "${network_args[@]}" "${NETWORK_NAME}"
```

Alternatively, simpler inline approach:

```bash
if [ "${DEBUG}" = "true" ]; then
  podman start "${CONTAINER_NAME}"
else
  podman start "${CONTAINER_NAME}" >/dev/null
fi
```

## Benefits

- **Easier troubleshooting**: See actual podman errors when debugging
- **No script modifications**: Just set `DEBUG=true` in conf.d
- **Clean by default**: Normal operation stays quiet
- **Educational**: New users can learn what commands are being run

## Example Usage

```bash
# Normal operation (quiet)
rc-service minecraft start

# Debug mode - see all podman output
# Add to /etc/conf.d/minecraft:
DEBUG="true"

rc-service minecraft start
# Now you see all podman command output
```

## Related

Found during comprehensive OpenRC init script review.
