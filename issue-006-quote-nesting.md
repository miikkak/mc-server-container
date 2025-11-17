# OpenRC: Improve Go template quote nesting clarity

**Labels**: `enhancement`, `good first issue`
**Priority**: Low

## Summary

The podman network inspect command uses complex quote nesting that works correctly but is difficult to read and maintain.

## Current Behavior

**Location**: `openrc-init-scripts/minecraft:263`

```bash
ip_owner=$(podman network inspect "${NETWORK_NAME}" --format '{{range .Containers}}{{if eq .IPv4Address "'"${target_ip}"'"}}{{.Name}}{{end}}{{end}}' 2>/dev/null)
```

The quote nesting `"'"${target_ip}"'"` is fragile and hard to understand:
- Outer single quotes for Go template
- Close single quote, add double quote, interpolate variable, add double quote, reopen single quote

## Problem

- Hard to read and understand
- Difficult to modify without breaking
- Prone to errors during maintenance
- Not immediately clear to code reviewers

## Proposed Solutions

### Option 1: Add explanatory comment

```bash
# Build Go template with proper quote escaping
# Go template syntax: eq .IPv4Address "VALUE"
# Shell interpolation requires: '...' + "${var}" + '...'
# Result: '{{if eq .IPv4Address "'"${target_ip}"'"}}'
ip_owner=$(podman network inspect "${NETWORK_NAME}" \
  --format '{{range .Containers}}{{if eq .IPv4Address "'"${target_ip}"'"}}{{.Name}}{{end}}{{end}}' \
  2>/dev/null)
```

### Option 2: Use printf to build template string

```bash
# Build Go template string with proper escaping
local template
template=$(printf '{{range .Containers}}{{if eq .IPv4Address "%s"}}{{.Name}}{{end}}{{end}}' "${target_ip}")
ip_owner=$(podman network inspect "${NETWORK_NAME}" --format "${template}" 2>/dev/null)
```

This is clearer but uses more lines.

### Option 3: Use here-string with variables

```bash
# Build template with variable substitution
local template='{{range .Containers}}{{if eq .IPv4Address "TARGET_IP"}}{{.Name}}{{end}}{{end}}'
template="${template//TARGET_IP/${target_ip}}"
ip_owner=$(podman network inspect "${NETWORK_NAME}" --format "${template}" 2>/dev/null)
```

This approach is clearer but adds complexity.

## Recommendation

**Option 1** (add comment) is recommended because:
- Minimal code change
- Explains the quote nesting for future maintainers
- Preserves current working implementation
- Documents the pattern for similar cases

## Additional Context

The current implementation is **functionally correct** and safe:
- `target_ip` is validated before use (line 259)
- No shell injection risk
- Works correctly in all tested scenarios

This is purely about code maintainability and readability, not a functional bug.

## Related

Found during comprehensive OpenRC init script review.
