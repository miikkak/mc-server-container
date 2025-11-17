# OpenRC: Refactor large start_pre() function into smaller functions

**Labels**: `enhancement`
**Priority**: Low

## Summary

The `start_pre()` function is 150 lines long and handles multiple distinct responsibilities. Break it down into smaller, focused functions for better maintainability.

## Current Behavior

**Location**: `openrc-init-scripts/minecraft:153-303`

The `start_pre()` function currently handles:
1. Instance name validation (lines 154-170)
2. Required configuration validation (lines 172-176)
3. Security validation (lines 178-205)
4. JVM memory percentage validation (lines 207-220)
5. JVM memory calculation (lines 222-250)
6. IP conflict detection (lines 252-268)
7. Network creation (lines 270-302)

## Problem

- **Hard to navigate**: 150 lines is too long to grasp at once
- **Mixed concerns**: Multiple responsibilities in one function
- **Difficult to test**: Can't test individual validations independently
- **Poor maintainability**: Changes risk breaking unrelated logic
- **Unclear flow**: Hard to see what validation happens in what order

## Proposed Solution

Break down into smaller, focused functions:

```bash
# Validates instance name format (lines 154-170)
validate_instance_name() {
  # Reject service names with trailing dots (e.g., minecraft.)
  if [ "${RC_SVCNAME}" != "minecraft" ] && [ -z "${INSTANCE}" ]; then
    eerror "Invalid service name '${RC_SVCNAME}': must be 'minecraft' or 'minecraft.NAME'"
    eerror "Service name cannot have trailing dots"
    return 1
  fi

  if [ -n "${INSTANCE}" ]; then
    # Instance name: lowercase letters, numbers, hyphens only
    if ! echo "${INSTANCE}" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$'; then
      eerror "Invalid instance name '${INSTANCE}': must contain only lowercase letters, numbers, and hyphens"
      eerror "Examples: survival, creative, world-1, lobby-server"
      return 1
    fi
  fi

  return 0
}

# Validates required configuration variables (lines 172-176)
validate_required_config() {
  if [ -z "${CONTAINER_NAME}" ] || [ -z "${CONTAINER_IMAGE}" ] || [ -z "${NETWORK_NAME}" ]; then
    eerror "Required configuration variables are not set"
    return 1
  fi
  return 0
}

# Validates security and format of user-provided config (lines 178-205)
validate_user_config() {
  # Validate configuration variables for security
  if ! validate_config "CONTAINER_VOLUMES" "${CONTAINER_VOLUMES}" "[a-zA-Z0-9/_. :-]*"; then
    return 1
  fi

  if ! validate_config "CONTAINER_PORTS" "${CONTAINER_PORTS}" "[0-9a-zA-Z.:/ -]*"; then
    return 1
  fi

  # CONTAINER_ENV and CONTAINER_LABELS with newline handling
  local env_cleaned="${CONTAINER_ENV//$'\n'/ }"
  if ! validate_config "CONTAINER_ENV" "${env_cleaned}" "[a-zA-Z0-9_=/.@:+ -]*"; then
    return 1
  fi

  local labels_cleaned="${CONTAINER_LABELS//$'\n'/ }"
  if ! validate_config "CONTAINER_LABELS" "${labels_cleaned}" "[a-zA-Z0-9_.=: -]*"; then
    return 1
  fi

  return 0
}

# Validates JVM memory percentage (lines 207-220)
validate_jvm_percent() {
  # Leading zeros cause octal interpretation
  case "${CONTAINER_MEMORY_JVM_PERCENT}" in
    ''|*[!0-9]*|0|0[0-9]*)
      eerror "CONTAINER_MEMORY_JVM_PERCENT must be a positive integer (1-80) without leading zeros, got: '${CONTAINER_MEMORY_JVM_PERCENT}'"
      return 1
      ;;
  esac

  if [ "${CONTAINER_MEMORY_JVM_PERCENT}" -gt 80 ]; then
    eerror "CONTAINER_MEMORY_JVM_PERCENT must be <= 80 (recommended: 70-75), got: ${CONTAINER_MEMORY_JVM_PERCENT}"
    eerror "JVM needs at least 20% overhead for metaspace, code cache, thread stacks, and native memory"
    eerror "Values > 80% will likely cause OOM during operation even if startup succeeds"
    return 1
  fi

  return 0
}

# Sets up JVM memory configuration (lines 222-250)
setup_jvm_memory() {
  # Check for MEMORY= at start of line only
  if ! printf '%s\n' "${CONTAINER_ENV}" | grep -q '^MEMORY='; then
    local calculated_memory
    if calculated_memory=$(calculate_jvm_memory "${CONTAINER_MEMORY}") && [ -n "${calculated_memory}" ]; then
      # Add MEMORY to CONTAINER_ENV
      if [ -z "${CONTAINER_ENV}" ]; then
        CONTAINER_ENV="MEMORY=${calculated_memory}"
      else
        CONTAINER_ENV="${CONTAINER_ENV}
MEMORY=${calculated_memory}"
      fi
      einfo "Auto-calculated JVM memory: ${calculated_memory} (${CONTAINER_MEMORY_JVM_PERCENT}% of ${CONTAINER_MEMORY} container limit)"
    else
      eerror "Failed to calculate JVM memory"
      eerror "Cannot safely start container - entrypoint default (16G) may exceed CONTAINER_MEMORY=${CONTAINER_MEMORY}"
      eerror "Fix configuration and try again"
      return 1
    fi
  elif ! printf '%s\n' "${CONTAINER_ENV}" | grep -q '^MEMORY=.'; then
    eerror "MEMORY is set in CONTAINER_ENV but has an empty value"
    eerror "Either remove MEMORY from CONTAINER_ENV to enable auto-calculation,"
    eerror "or provide a valid value (e.g., MEMORY=16G)"
    return 1
  else
    einfo "MEMORY already configured in CONTAINER_ENV, skipping auto-calculation"
  fi

  return 0
}

# Checks for IP conflicts on the network (lines 252-268)
check_ip_conflicts() {
  if ! podman network exists "${NETWORK_NAME}" >/dev/null 2>&1; then
    return 0  # Network doesn't exist yet, no conflicts possible
  fi

  # Extract subnet mask from NETWORK_SUBNET
  local subnet_mask="${NETWORK_SUBNET##*/}"
  local target_ip="${CONTAINER_IP}/${subnet_mask}"

  # Find which container (if any) is using this IP address
  local ip_owner
  ip_owner=$(podman network inspect "${NETWORK_NAME}" --format '{{range .Containers}}{{if eq .IPv4Address "'"${target_ip}"'"}}{{.Name}}{{end}}{{end}}' 2>/dev/null)

  if [ -n "${ip_owner}" ] && [ "${ip_owner}" != "${CONTAINER_NAME}" ]; then
    ewarn "IP address ${CONTAINER_IP} is already in use by container '${ip_owner}' on network ${NETWORK_NAME}"
    ewarn "Please assign a unique IP address to avoid conflicts"
  fi

  return 0
}

# Ensures the Podman network exists (lines 270-302)
ensure_network_exists() {
  if podman network exists "${NETWORK_NAME}" >/dev/null 2>&1; then
    return 0  # Network already exists
  fi

  ebegin "Creating Podman network ${NETWORK_NAME}"
  local network_args=(
    --subnet "${NETWORK_SUBNET}"
    --gateway "${NETWORK_GATEWAY}"
  )

  # Only set interface name if it's 15 characters or less
  if [ ${#NETWORK_NAME} -le 15 ]; then
    network_args+=(--interface-name "${NETWORK_NAME}")
  fi

  if [ "${NETWORK_DISABLE_DNS}" = "true" ]; then
    network_args+=(--disable-dns)
  fi

  if ! podman network create "${network_args[@]}" "${NETWORK_NAME}" >/dev/null; then
    eend 1
    eerror "Failed to create Podman network ${NETWORK_NAME}"
    eerror "This usually means the subnet ${NETWORK_SUBNET} is already in use."
    eerror ""
    eerror "To diagnose:"
    eerror "  podman network ls"
    eerror "  podman network inspect <network-name>"
    eerror ""
    eerror "To clean up unused networks from previous instances:"
    eerror "  rc-service ${RC_SVCNAME} remove_network"
    return 1
  fi
  eend 0
  return 0
}

# Main pre-start validation orchestrator
start_pre() {
  validate_instance_name || return 1
  validate_required_config || return 1
  validate_user_config || return 1
  validate_jvm_percent || return 1
  setup_jvm_memory || return 1
  check_ip_conflicts || return 1
  ensure_network_exists || return 1

  return 0
}
```

## Benefits

- **Better readability**: Each function has a clear, single purpose
- **Easier maintenance**: Changes to one validation don't affect others
- **Testability**: Individual functions can be tested independently
- **Clear flow**: `start_pre()` becomes a high-level overview
- **Reusability**: Functions can be called from other contexts if needed
- **Documentation**: Function names serve as inline documentation

## Implementation Notes

- Each extracted function should have a clear return contract (0 = success, 1 = failure)
- All functions use existing error messages (no functional changes)
- The refactored `start_pre()` reads like a checklist
- No changes to behavior, only code organization

## Related

Found during comprehensive OpenRC init script review.
