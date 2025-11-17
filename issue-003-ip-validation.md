# OpenRC: Add IP address format validation

**Labels**: `enhancement`
**Priority**: Medium

## Summary

The script validates many configuration variables but doesn't validate IP address formats for `CONTAINER_IP` and `CONTAINER_IPv6`. This can lead to confusing errors later during network setup.

## Current Behavior

**Location**: `openrc-init-scripts/minecraft:153` (start_pre function)

The script validates:
- Container volumes (paths and format)
- Container ports (numbers and format)
- Container environment variables (characters allowed)
- Memory values (units and format)

But it does NOT validate:
- IPv4 address format
- IPv6 address format

## Problem

Invalid IP addresses cause obscure errors during:
- Podman network setup
- IPv6 route configuration
- Container startup

Users may not realize the error is due to a typo in the IP address.

## Examples of Typos That Would Be Caught

```bash
# Invalid IPv4 examples
CONTAINER_IP="10.10.10.256"  # Number > 255
CONTAINER_IP="10.10.10"       # Missing octet
CONTAINER_IP="10.10.10.10.1"  # Too many octets

# Invalid IPv6 examples
CONTAINER_IPv6="2a01:4f9:3070:1169::g10c:cafe"  # Invalid character 'g'
CONTAINER_IPv6="not-an-ipv6"                    # Completely invalid
```

## Proposed Solution

Add validation to `start_pre()`:

```bash
# Validate IPv4 format
if [ -n "${CONTAINER_IP}" ]; then
  if ! echo "${CONTAINER_IP}" | grep -Eq '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'; then
    eerror "Invalid IPv4 address format: ${CONTAINER_IP}"
    eerror "Expected format: X.X.X.X (e.g., 10.10.10.10)"
    return 1
  fi

  # Validate each octet is 0-255
  for octet in $(echo "${CONTAINER_IP}" | tr '.' ' '); do
    if [ "$octet" -gt 255 ]; then
      eerror "Invalid IPv4 address: ${CONTAINER_IP} (octet $octet > 255)"
      return 1
    fi
  done
fi

# Validate IPv6 format (if set and not empty)
if [ -n "${CONTAINER_IPv6}" ]; then
  if ! echo "${CONTAINER_IPv6}" | grep -Eq '^[0-9a-fA-F:]+$'; then
    eerror "Invalid IPv6 address format: ${CONTAINER_IPv6}"
    eerror "Expected format: hexadecimal digits and colons (e.g., 2a01:4f9:3070:1169::b10c:cafe)"
    return 1
  fi
fi
```

## Benefits

- **Early error detection**: Catch typos during service start, not during obscure podman errors
- **Clear error messages**: Tell user exactly what's wrong with the IP format
- **Fail-fast**: Prevents cryptic network errors later
- **Better user experience**: Validation happens before any podman commands run

## Related

Found during comprehensive OpenRC init script review.
