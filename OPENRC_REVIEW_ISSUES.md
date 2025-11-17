# OpenRC Init Scripts Review - GitHub Issues

This document lists all GitHub issues created from the comprehensive OpenRC init script review.

## Summary

| Category | Count | Files |
|----------|-------|-------|
| High Priority Enhancements | 1 | issue-001 |
| Medium Priority Enhancements | 2 | issue-002, issue-003 |
| Low Priority Enhancements | 5 | issue-004, issue-007, issue-008, issue-009, issue-010 |
| Bugs | 2 | issue-005, issue-006 |

**Total Issues**: 10

## How to Create Issues

Since the GitHub CLI (`gh`) is not available, you'll need to create these issues manually:

### Using GitHub Web Interface

1. Go to https://github.com/miikkak/mc-server-container/issues/new
2. Copy the title from each markdown file
3. Copy the body content (everything after the title and metadata)
4. Add the labels specified in each file
5. Submit the issue

### Using GitHub CLI (if available on another machine)

```bash
# Example for issue-001
gh issue create --repo miikkak/mc-server-container \
  --title "$(head -1 issue-001-ip-conflict-fail.md | sed 's/^# //')" \
  --label "enhancement" \
  --body "$(tail -n +5 issue-001-ip-conflict-fail.md)"
```

## Issues by Priority

### 🔴 High Priority

#### 1. IP conflict detection should fail instead of warn
- **File**: `issue-001-ip-conflict-fail.md`
- **Labels**: `enhancement`
- **Impact**: Prevents network connectivity problems
- **Effort**: Low (simple change)

### 🟡 Medium Priority

#### 2. Make container startup timeout configurable
- **File**: `issue-002-configurable-timeout.md`
- **Labels**: `enhancement`
- **Impact**: Better support for large/modded servers
- **Effort**: Low (add one config variable)

#### 3. Add IP address format validation
- **File**: `issue-003-ip-validation.md`
- **Labels**: `enhancement`
- **Impact**: Catch configuration errors early
- **Effort**: Low (add validation functions)

### 🟢 Low Priority Enhancements

#### 4. Add debug/verbose mode
- **File**: `issue-004-debug-mode.md`
- **Labels**: `enhancement`
- **Impact**: Easier troubleshooting
- **Effort**: Medium (affects many commands)

#### 5. Improve memory validation error messages
- **File**: `issue-007-better-error-messages.md`
- **Labels**: `enhancement`, `good first issue`
- **Impact**: Better user experience
- **Effort**: Low (improve existing messages)

#### 6. Add container health check command
- **File**: `issue-008-healthcheck-command.md`
- **Labels**: `enhancement`
- **Impact**: Better monitoring integration
- **Effort**: Low (new command)

#### 7. Extract container interface detection to separate function
- **File**: `issue-009-refactor-interface-detection.md`
- **Labels**: `enhancement`, `good first issue`
- **Impact**: Better code organization
- **Effort**: Low (code refactoring)

#### 8. Refactor large start_pre() function
- **File**: `issue-010-refactor-large-start-pre.md`
- **Labels**: `enhancement`
- **Impact**: Better maintainability
- **Effort**: Medium (significant refactoring)

### 🐛 Bugs

#### 9. Document bash requirement or improve POSIX compatibility
- **File**: `issue-005-bash-portability.md`
- **Labels**: `bug`, `documentation`
- **Severity**: Low
- **Impact**: Portability to non-bash systems
- **Effort**: Low (documentation) or Medium (POSIX rewrite)

#### 10. Improve Go template quote nesting clarity
- **File**: `issue-006-quote-nesting.md`
- **Labels**: `enhancement`, `good first issue`
- **Severity**: Low
- **Impact**: Code maintainability
- **Effort**: Low (add comments or minor refactoring)

## Recommended Implementation Order

1. **issue-001** - IP conflict should fail (prevents runtime issues)
2. **issue-003** - IP validation (catches config errors early)
3. **issue-002** - Configurable timeout (helps large servers)
4. **issue-007** - Better error messages (good first issue, improves UX)
5. **issue-006** - Quote nesting clarity (good first issue, quick fix)
6. **issue-009** - Extract interface detection (good first issue, clean refactor)
7. **issue-005** - Bash portability documentation (quick docs update)
8. **issue-004** - Debug mode (useful for all other work)
9. **issue-008** - Health check command (nice to have)
10. **issue-010** - Refactor start_pre (requires careful testing)

## Labels to Use

Based on `.github/labels.yml`:

- `bug` - For issues 5, 6
- `enhancement` - For issues 1, 2, 3, 4, 7, 8, 9, 10
- `documentation` - For issue 5 (in addition to bug)
- `good first issue` - For issues 6, 7, 9 (easy entry points)

## Next Steps

1. Review the generated issue files
2. Create issues on GitHub using the web interface or CLI
3. Assign labels as specified
4. Consider adding milestones or projects to organize the work
5. Link related issues together

## Files Generated

```
issue-001-ip-conflict-fail.md
issue-002-configurable-timeout.md
issue-003-ip-validation.md
issue-004-debug-mode.md
issue-005-bash-portability.md
issue-006-quote-nesting.md
issue-007-better-error-messages.md
issue-008-healthcheck-command.md
issue-009-refactor-interface-detection.md
issue-010-refactor-large-start-pre.md
```

All files are ready to be used for creating GitHub issues.
