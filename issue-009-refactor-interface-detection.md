# OpenRC: Extract container interface detection to separate function

**Labels**: `enhancement`, `good first issue`
**Priority**: Low

## Summary

The awk script for detecting container network interfaces is complex and buried in the `setup_ipv6()` function. Extract it to a separate function for better code organization.

## Current Behavior

**Location**: `openrc-init-scripts/minecraft:412-421`

```bash
container_iface=$(nsenter -t "$container_pid" -n ip -o link show | awk '
  $2 != "lo:" {
    gsub(/:$/, "", $2)
    gsub(/@.*$/, "", $2)
    if ($2 !~ /^(sit|ip6tnl|ip6_vti|ip_vti|gre|ipip|tunl)[0-9]*$/) {
      print $2
      exit
    }
  }
')
```

This 10-line awk script is embedded directly in the IPv6 setup flow.

## Problem

- Hard to test the interface detection logic independently
- The complexity is hidden in the middle of another function
- Difficult to reuse if needed elsewhere
- No clear documentation of what interfaces are filtered

## Proposed Solution

Extract to a dedicated function:

```bash
# Detects the first non-loopback, non-tunnel network interface in a container
# Arguments:
#   $1 - Container PID
# Returns:
#   Interface name (e.g., "eth0") on success, empty string on failure
# Exit code:
#   0 on success, 1 if no suitable interface found
detect_container_interface() {
  local container_pid="$1"
  local iface

  # Find first interface that is:
  # - Not loopback (lo)
  # - Not a tunnel interface (sit*, ip6tnl*, ip6_vti*, ip_vti*, gre*, ipip*, tunl*)
  # Strip trailing colons and @... suffixes from interface names
  iface=$(nsenter -t "$container_pid" -n ip -o link show | awk '
    $2 != "lo:" {
      # Remove trailing colon (e.g., "eth0:" -> "eth0")
      gsub(/:$/, "", $2)
      # Remove @... suffix (e.g., "sit0@NONE" -> "sit0")
      gsub(/@.*$/, "", $2)

      # Skip tunnel interfaces
      if ($2 !~ /^(sit|ip6tnl|ip6_vti|ip_vti|gre|ipip|tunl)[0-9]*$/) {
        print $2
        exit
      }
    }
  ')

  if [ -z "$iface" ]; then
    return 1
  fi

  echo "$iface"
  return 0
}
```

Then use it in `setup_ipv6()`:

```bash
setup_ipv6() {
  local container_pid bridge_ll_addr container_iface
  container_pid=$(podman inspect "${CONTAINER_NAME}" --format '{{.State.Pid}}')

  # Validate container_pid...
  case "$container_pid" in
    ''|*[!0-9]*|0)
      ewarn "Could not get container PID for IPv6 setup"
      return 1
      ;;
  esac

  # Determine container interface name
  if [ -n "${CONTAINER_INTERFACE}" ]; then
    # Use explicitly configured interface
    container_iface="${CONTAINER_INTERFACE}"
  else
    # Auto-detect interface
    if ! container_iface=$(detect_container_interface "$container_pid"); then
      ewarn "Could not detect container network interface"
      return 1
    fi
  fi

  # ... rest of IPv6 setup ...
}
```

## Benefits

- **Better code organization**: Clear separation of concerns
- **Easier testing**: Function can be tested independently
- **Improved documentation**: Function comment explains what's being filtered
- **Reusability**: Can be used elsewhere if needed
- **Clearer error handling**: Explicit return codes

## Related

Found during comprehensive OpenRC init script review.
