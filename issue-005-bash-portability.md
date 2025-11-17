# OpenRC: Document bash requirement or improve POSIX compatibility

**Labels**: `bug`, `documentation`
**Priority**: Low

## Summary

The script uses bash-specific features that may not work on distributions where OpenRC uses a strict POSIX shell. This is documented with `# shellcheck shell=bash` but could cause portability issues.

## Current Behavior

**Locations**: Lines 330, 340, 194, 202

The script uses bash-specific features:

```bash
# Line 330, 340 - mapfile is a bash builtin
mapfile -t env_array <<< "${CONTAINER_ENV}"
mapfile -t label_array <<< "${CONTAINER_LABELS}"

# Line 194, 202 - bash parameter expansion syntax
local env_cleaned="${CONTAINER_ENV//$'\n'/ }"
local labels_cleaned="${CONTAINER_LABELS//$'\n'/ }"
```

## Problem

- `mapfile` is not available in POSIX sh (dash, ash, etc.)
- `${VAR//$'\n'/ }` syntax is bash-specific
- May fail on distributions where `/bin/sh` is not bash
- Works fine on Gentoo where sh is typically bash

## Impact

- **Gentoo**: Works perfectly (sh is bash)
- **Alpine Linux**: May fail (sh is ash/busybox)
- **Debian/Ubuntu**: May fail if using dash
- **Other distributions**: Depends on /bin/sh implementation

## Proposed Solutions

### Option 1: Document bash requirement (easier)

Add to README.md:

```markdown
## Requirements

- `bash` - This script uses bash-specific features and requires bash to be available
- `podman` - Container runtime
- `ndppd` (optional) - For IPv6 NDP proxy functionality
- `nsenter` - For IPv6 configuration (usually part of `util-linux`)
- `iproute2` - For network routing commands

Note: While OpenRC scripts typically run in `/bin/sh`, this script requires bash features.
Ensure bash is installed on your system.
```

Add shebang clarification in the script:

```bash
#!/sbin/openrc-run
# shellcheck shell=bash
# IMPORTANT: This script requires bash. It uses bash-specific features:
# - mapfile builtin for array handling
# - Advanced parameter expansion (${VAR//pattern/replacement})
# Ensure bash is installed: emerge -av app-shells/bash
```

### Option 2: Make POSIX-compatible (harder but more portable)

Replace bash-specific constructs:

```bash
# Instead of mapfile (lines 330, 340)
env_array=""
while IFS= read -r line; do
  env_array="${env_array}${line}"$'\n'
done <<EOF
${CONTAINER_ENV}
EOF

# Instead of ${VAR//$'\n'/ } (lines 194, 202)
env_cleaned=$(printf '%s' "${CONTAINER_ENV}" | tr '\n' ' ')
labels_cleaned=$(printf '%s' "${CONTAINER_LABELS}" | tr '\n' ' ')
```

However, this makes the code more complex and harder to maintain.

## Recommendation

**Option 1** (documentation) is recommended because:
- Bash is universally available on Linux systems
- The bash features make the code cleaner and more maintainable
- Gentoo users already have bash
- The script is already marked with `# shellcheck shell=bash`

## Related

Found during comprehensive OpenRC init script review.
