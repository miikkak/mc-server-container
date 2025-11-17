# OpenRC: IP conflict detection should fail instead of warn

**Labels**: `enhancement`
**Priority**: High

## Summary

The OpenRC init script currently warns about IP address conflicts but allows the service to start anyway. This can lead to network connectivity problems that are difficult to debug later.

## Current Behavior

**Location**: `openrc-init-scripts/minecraft:265-266`

```bash
if [ -n "${ip_owner}" ] && [ "${ip_owner}" != "${CONTAINER_NAME}" ]; then
  ewarn "IP address ${CONTAINER_IP} is already in use by container '${ip_owner}' on network ${NETWORK_NAME}"
  ewarn "Please assign a unique IP address to avoid conflicts"
fi
```

The script detects the IP conflict but only logs a warning and continues with service startup.

## Problem

Starting a container with a conflicting IP address will cause:
- Network connectivity issues
- Difficult-to-debug runtime problems
- The service appears "started" but doesn't work correctly

## Proposed Solution

Change the warning to an error and fail the service start:

```bash
if [ -n "${ip_owner}" ] && [ "${ip_owner}" != "${CONTAINER_NAME}" ]; then
  eerror "IP address ${CONTAINER_IP} is already in use by container '${ip_owner}' on network ${NETWORK_NAME}"
  eerror "Each instance must have a unique IP address"
  eerror "Please assign a different IP in /etc/conf.d/${RC_SVCNAME}"
  return 1
fi
```

## Benefits

- **Fail-fast**: Catch configuration errors immediately during service start
- **Clear feedback**: User knows exactly what's wrong before the container starts
- **Easier debugging**: No mysterious network issues to troubleshoot later
- **Prevents cascading failures**: Stops the problem at the source

## Related

Found during comprehensive OpenRC init script review.
