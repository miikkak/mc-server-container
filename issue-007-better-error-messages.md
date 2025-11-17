# OpenRC: Improve memory validation error messages

**Labels**: `enhancement`, `good first issue`
**Priority**: Low

## Summary

Memory validation error messages could be more helpful by providing clear examples and explanations.

## Current Behavior

**Location**: `openrc-init-scripts/minecraft:71`

```bash
if [ -z "$value" ] || [ -z "$unit" ]; then
  eerror "Invalid CONTAINER_MEMORY format: $container_mem (expected format: 24G, 16G, 2048M)"
  return 1
fi
```

The error message is on one line and could be more helpful.

## Problem

- Single-line error messages are easy to miss
- No explanation of what units are supported
- No clear examples of correct format
- Users may not understand G vs M units

## Proposed Solution

Expand error messages to be more informative:

```bash
if [ -z "$value" ] || [ -z "$unit" ]; then
  eerror "Invalid CONTAINER_MEMORY format: $container_mem"
  eerror "Expected format: <number><unit>"
  eerror "Supported units: G (gigabytes), M (megabytes)"
  eerror "Examples:"
  eerror "  CONTAINER_MEMORY=\"24G\"    - 24 gigabytes"
  eerror "  CONTAINER_MEMORY=\"2048M\"  - 2048 megabytes"
  return 1
fi
```

Similarly, improve other validation messages:

```bash
# Unit validation (line 90)
if ! validate unit; then
  eerror "Unsupported memory unit in CONTAINER_MEMORY: $unit"
  eerror "Supported units: G (gigabytes), M (megabytes)"
  eerror "Example: CONTAINER_MEMORY=\"16G\" or CONTAINER_MEMORY=\"2048M\""
  return 1
fi

# Minimum validation (line 100)
if [ $jvm_mb -lt $min_jvm_mb ]; then
  eerror "Calculated JVM heap (${jvm_mb}M) is below minimum requirement (${min_jvm_mb}M / 1G)"
  eerror "Paper server requires at least 1G heap to start"
  eerror "Current configuration:"
  eerror "  CONTAINER_MEMORY: ${container_mem}"
  eerror "  JVM_PERCENT: ${jvm_percent}%"
  eerror "  Calculated heap: ${jvm_mb}M"
  eerror "Solution: Set CONTAINER_MEMORY >= 2G (with 75% allocation)"
  eerror "  or adjust CONTAINER_MEMORY_JVM_PERCENT"
  return 1
fi
```

## Benefits

- **Better user experience**: Clear guidance on fixing the error
- **Educational**: Users learn the correct format immediately
- **Faster resolution**: Less time spent googling or checking docs
- **Professional appearance**: Matches quality of other error messages

## Examples

**Before**:
```
* ERROR: Invalid CONTAINER_MEMORY format: 24 (expected format: 24G, 16G, 2048M)
```

**After**:
```
* ERROR: Invalid CONTAINER_MEMORY format: 24
* ERROR: Expected format: <number><unit>
* ERROR: Supported units: G (gigabytes), M (megabytes)
* ERROR: Examples:
* ERROR:   CONTAINER_MEMORY="24G"    - 24 gigabytes
* ERROR:   CONTAINER_MEMORY="2048M"  - 2048 megabytes
```

## Related

Found during comprehensive OpenRC init script review.
