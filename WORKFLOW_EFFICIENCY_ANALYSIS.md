# GitHub Actions Workflow Efficiency Analysis

## Current Inefficiencies

### 1. Documentation-Only Changes ⚠️ **Primary Issue**

**Problem:** Changing only documentation files (`.md`) triggers expensive build/test cycles.

**Affected Workflows:**
- ✅ **`release.yml`** - Already has `paths-ignore` for `**.md` (GOOD!)
- ❌ **`build-test.yml`** - Runs full build/test cycle:
  - Builds container with Docker (hadolint + build job)
  - Builds container again for Docker tests (downloads Paper JAR)
  - Builds container again for Podman tests (downloads Paper JAR)
  - Total: ~5-10 minutes for doc changes
- ❌ **`shellcheck.yml`** - Runs shellcheck on all `.sh` files
- ❌ **`security-scan.yml`** - Builds container and runs Trivy scan

**Example Triggers:**
- Updating `README.md`
- Editing `TODO.md`, `CLAUDE.md`, `SECURITY.md`
- Modifying documentation in `docs/`

---

### 2. GitHub Actions Workflow Changes ⚠️

**Problem:** Changes to workflow files trigger the workflows themselves unnecessarily.

**Affected Workflows:**
- ❌ **`build-test.yml`** - Builds container when `.github/workflows/*.yml` changes
- ❌ **`shellcheck.yml`** - Runs when workflow files change
- ❌ **`security-scan.yml`** - Scans when workflow files change

**Example Triggers:**
- Adding a new workflow
- Updating workflow dependencies (e.g., `actions/checkout@v5` → `@v6`)
- Fixing typos in workflow comments

**Impact:** Workflow changes don't affect the container, so building is wasteful.

---

### 3. Configuration File Changes ⚠️

**Problem:** Changes to repository configuration files trigger full builds.

**Affected Workflows:**
- ❌ **`build-test.yml`** - Runs for all config changes
- ❌ **`security-scan.yml`** - Scans for all config changes

**Example Triggers:**
- Updating `.gitignore`
- Modifying `.pre-commit-config.yaml`
- Changing issue templates (`.github/ISSUE_TEMPLATE/`)
- Updating `.github/dependabot.yml`
- Editing `.github/labels.yml`

**Impact:** These files don't affect the container image, but trigger 3 container builds.

---

### 4. Script-Only Changes (Minor) ⚡

**Problem:** Changes to scripts might not require security scanning.

**Scenario:** Updating `scripts/entrypoint.sh` or helper scripts.

**Affected Workflows:**
- ✅ **`build-test.yml`** - Correctly rebuilds (scripts are in container)
- ✅ **`shellcheck.yml`** - Correctly lints changed scripts
- ⚠️ **`security-scan.yml`** - Might be overkill?
  - Script changes rarely introduce dependency vulnerabilities
  - Trivy scans for CVEs in binaries/packages, not script bugs
  - Scheduled daily scans might be sufficient

**Impact:** Low priority - security scanning is relatively fast.

---

## Recommended Optimizations

### Priority 1: Add Path Filters to `build-test.yml`

**Solution:** Only run builds when files affecting the container change.

```yaml
on:
  push:
    branches: [ main ]
    paths-ignore:
      - '**.md'
      - '.gitignore'
      - '.pre-commit-config.yaml'
      - '.github/ISSUE_TEMPLATE/**'
      - '.github/labels.yml'
      - '.github/dependabot.yml'
      - '.github/workflows/**'
  pull_request:
    branches: [ main ]
    paths-ignore:
      - '**.md'
      - '.gitignore'
      - '.pre-commit-config.yaml'
      - '.github/ISSUE_TEMPLATE/**'
      - '.github/labels.yml'
      - '.github/dependabot.yml'
      - '.github/workflows/**'
```

**Alternative:** Use `paths` to be explicit about what triggers builds:

```yaml
on:
  push:
    branches: [ main ]
    paths:
      - 'Dockerfile'
      - 'scripts/**'
      - 'docker-compose.yml'
  pull_request:
    branches: [ main ]
    paths:
      - 'Dockerfile'
      - 'scripts/**'
      - 'docker-compose.yml'
```

**Trade-off:** `paths-ignore` is more maintainable (new files trigger builds by default), but `paths` is more explicit and safer.

---

### Priority 2: Add Path Filters to `shellcheck.yml`

**Solution:** Only run when shell scripts or shellcheck config changes.

```yaml
on:
  push:
    branches: [ main ]
    paths:
      - '**.sh'
      - '.shellcheck-wrapper.sh'
  pull_request:
    branches: [ main ]
    paths:
      - '**.sh'
      - '.shellcheck-wrapper.sh'
```

**Note:** The workflow file itself is intentionally excluded to avoid self-referencing triggers. GitHub validates workflow syntax on commit.

**Benefit:** Saves ~1-2 minutes on doc-only changes.

---

### Priority 3: Add Path Filters to `security-scan.yml`

**Solution:** Only scan when container-affecting files change (or on schedule).

```yaml
on:
  schedule:
    - cron: '0 3 * * *'  # Daily scan (keep as-is)
  push:
    branches: [ main ]
    paths:
      - 'Dockerfile'
      - 'scripts/**'
      - 'docker-compose.yml'
  pull_request:
    branches: [ main ]
    paths:
      - 'Dockerfile'
      - 'scripts/**'
      - 'docker-compose.yml'
  workflow_dispatch:
```

**Benefit:**
- Doc changes don't trigger scans
- Daily scheduled scans still catch new CVEs
- Manual trigger available if needed

---

### Priority 4 (Optional): Conditional Workflow for Workflow Changes

**Problem:** When `.github/workflows/*.yml` changes, we want to validate the workflow syntax, but not build containers.

**Solution:** Create a separate workflow validator:

```yaml
# .github/workflows/validate-workflows.yml
name: Validate Workflows

on:
  pull_request:
    paths:
      - '.github/workflows/**'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - name: Validate workflow syntax
        run: |
          # Use actionlint or similar tool
          echo "Workflow validation would go here"
```

**Benefit:** Fast feedback on workflow changes without building containers.

---

## Impact Summary

| Change Type | Current Behavior | After Optimization |
|-------------|------------------|-------------------|
| **Doc changes** | 3 builds + shellcheck + security scan (~10 min) | Skip all (~0 min) ✅ |
| **Workflow changes** | 3 builds + shellcheck + security scan (~10 min) | Skip all or validate only (~30 sec) ✅ |
| **Config changes** | 3 builds + security scan (~8 min) | Skip all (~0 min) ✅ |
| **Script changes** | 3 builds + shellcheck + security scan (~10 min) | Same (correct) ✅ |
| **Dockerfile changes** | 3 builds + hadolint + security scan (~10 min) | Same (correct) ✅ |

**Estimated Savings:**
- Typical doc/config PR: **~10 minutes** → **0 minutes**
- CI/CD cost reduction: **~50-70%** (assuming mix of change types)
- GitHub Actions minutes saved: **~500-1000 minutes/month** (rough estimate)

---

## Edge Cases to Consider

### Edge Case 1: Documentation Embedding in Container

**Question:** Are any `.md` files copied into the container?

**Check:** Review `Dockerfile` for `COPY *.md` commands.

**Current Status:**
- Dockerfile doesn't copy `.md` files ✅
- Safe to ignore `.md` in build triggers

### Edge Case 2: Scripts Used During Build

**Question:** Are any scripts executed during Docker build?

**Check:** Review `Dockerfile` for `RUN` commands using scripts.

**Current Status:**
- Scripts are only `COPY`-ed, not executed during build ✅
- Script changes require rebuild ✅

### Edge Case 3: docker-compose.yml Changes

**Question:** Do `docker-compose.yml` changes require container rebuild?

**Answer:**
- Changes to service config (ports, volumes, env) don't require rebuild
- Changes to `build:` section might require rebuild
- **Recommendation:** Include in build triggers to be safe

### Edge Case 4: Pre-commit Config and Workflow Sync

**Question:** If `.pre-commit-config.yaml` changes, should workflows run?

**Answer:**
- Pre-commit hooks run locally, not in container
- No need to rebuild container
- **Recommendation:** Exclude from build triggers ✅

---

## Implementation Plan

### Step 1: Update `build-test.yml`
```bash
# Add paths-ignore to build-test.yml
```

### Step 2: Update `shellcheck.yml`
```bash
# Add paths filter to shellcheck.yml
```

### Step 3: Update `security-scan.yml`
```bash
# Add paths filter to security-scan.yml
```

### Step 4: Test
```bash
# Create test PRs for each change type:
# 1. Doc-only change (should skip builds)
# 2. Script change (should run builds)
# 3. Workflow change (should skip builds)
```

### Step 5: Monitor
```bash
# Track CI minutes usage before/after
# Verify no false negatives (missed builds)
```

---

## Related Files

- `.github/workflows/build-test.yml` - Main build workflow
- `.github/workflows/shellcheck.yml` - Shellcheck linting
- `.github/workflows/security-scan.yml` - Trivy security scanning
- `.github/workflows/release.yml` - Already optimized with `paths-ignore` ✅

---

## Notes

- **`release.yml` is already optimized** - Good reference for `paths-ignore` patterns
- **Scheduled workflows are fine** - `dependency-check.yml`, `security-scan.yml` scheduled runs are appropriate
- **Manual triggers remain** - `workflow_dispatch` allows manual runs when needed
- **Safety first** - When in doubt, include path in build triggers (false positives better than false negatives)

---

**Author:** Generated by analysis on 2025-11-08
**Status:** Recommendations pending implementation
