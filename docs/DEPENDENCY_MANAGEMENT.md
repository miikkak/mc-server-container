# Dependency Management Guide

This document explains the automated dependency monitoring and security scanning systems implemented in this repository.

## Overview

The repository uses multiple automated tools and workflows to monitor dependencies, check for security vulnerabilities, and maintain up-to-date software components:

1. **Dependabot** - GitHub's native dependency update tool
2. **Custom Dependency Checks** - Workflows for binary and base image monitoring
3. **Security Scanning** - Trivy for vulnerability detection
4. **Pre-commit Hook Updates** - Automated hook version management
5. **Dependency Dashboard** - Centralized status overview

## Monitored Dependencies

### 1. GitHub Actions (Dependabot)

**What:** All GitHub Actions used in workflows
**Frequency:** Weekly (Mondays at 09:00 UTC)
**Process:** Dependabot automatically creates PRs with updates
**Action Required:** Review and merge PRs

### 2. Docker Base Image (Dependabot + Custom Check)

**What:** `container-registry.oracle.com/graalvm/jdk:25`
**Frequency:** Weekly (Mondays at 09:00 UTC)
**Process:** 
- Dependabot monitors version updates
- Custom workflow checks image digests for patches
**Action Required:** Review PRs/issues and rebuild container

### 3. Binary Dependencies (Custom Check)

**What:** 
- `mc-server-runner` - Process supervisor
- `rcon-cli` - RCON client

**Frequency:** Weekly (Mondays at 09:00 UTC)
**Process:** 
- Workflow checks GitHub releases for new versions
- Issues created when updates are available
**Action Required:** Update Dockerfile and test

### 4. Pre-commit Hooks (Automated Update)

**What:** All pre-commit hooks in `.pre-commit-config.yaml`
**Frequency:** Weekly (Mondays at 09:30 UTC)
**Process:** 
- Workflow runs `pre-commit autoupdate`
- PR automatically created with updates
**Action Required:** Review and merge PR

## Workflows

### `dependency-check.yml`

**Schedule:** Weekly (Mondays at 09:00 UTC)

**Jobs:**
1. `check-binary-dependencies` - Checks mc-server-runner and rcon-cli
2. `check-base-image` - Checks GraalVM Docker image for updates

**Outputs:**
- Creates/updates issues when updates are available
- Issues are labeled: `dependencies`, `automated`, `enhancement`

**Manual Trigger:** Yes (workflow_dispatch)

### `security-scan.yml`

**Schedule:** Daily (03:00 UTC) + on push/PR

**Jobs:**
1. `trivy-scan` - Scans container image for vulnerabilities
2. `dockerfile-scan` - Checks Dockerfile for security issues

**Outputs:**
- Uploads SARIF results to GitHub Security tab
- Creates issues for CRITICAL/HIGH vulnerabilities
- Table and JSON reports in workflow logs

**Manual Trigger:** Yes (workflow_dispatch)

### `precommit-updates.yml`

**Schedule:** Weekly (Mondays at 09:30 UTC)

**Jobs:**
1. `check-updates` - Runs pre-commit autoupdate and creates PR

**Outputs:**
- Automatically creates PR with hook updates
- Falls back to issue if PR creation fails
- PRs are labeled: `dependencies`, `automated`, `release:patch`

**Manual Trigger:** Yes (workflow_dispatch)

### `dependency-dashboard.yml`

**Schedule:** Weekly (Mondays at 10:00 UTC)

**Jobs:**
1. `create-dashboard` - Generates comprehensive status report

**Outputs:**
- Creates/updates pinned dashboard issue
- Shows all dependency statuses
- Lists active monitors and recent activity
- Provides update instructions

**Manual Trigger:** Yes (workflow_dispatch)

## Responding to Updates

### GitHub Actions Updates (Dependabot PR)

1. **Review PR:** Check the changelog and release notes
2. **Verify Tests:** Ensure CI/CD tests pass
3. **Merge:** Approve and merge the PR
4. **Label:** PR already has `release:patch` label if needed

### Docker Base Image Update (Issue or PR)

1. **Review Issue/PR:** Check what changed in the new image
2. **Rebuild Container:**
   ```bash
   docker build --no-cache --pull -t mc-server-container:test .
   ```
3. **Test Locally:**
   ```bash
   docker run -d --name mc-test -e EULA=TRUE mc-server-container:test
   docker logs mc-test
   docker stop mc-test && docker rm mc-test
   ```
4. **Create PR:** If testing passes, create PR with `release:patch` label
5. **Close Issue:** Issue is automatically closed when PR merges

### Binary Dependency Update (Issue)

1. **Review Issue:** Check the new versions available
2. **Update Dockerfile:**
   ```dockerfile
   ARG MC_SERVER_RUNNER_VERSION=<new_version>
   ARG RCON_CLI_VERSION=<new_version>
   ```
3. **Test Build:**
   ```bash
   docker build -t mc-server-container:test .
   ```
4. **Test Container:**
   ```bash
   docker run -d --name mc-test -e EULA=TRUE mc-server-container:test
   docker logs mc-test
   docker stop mc-test && docker rm mc-test
   ```
5. **Create PR:** Create PR with changes and add `release:patch` label
6. **Close Issue:** Reference issue in PR to auto-close

### Pre-commit Hook Update (PR)

1. **Review PR:** Check which hooks were updated
2. **Verify Tests:** Ensure all hooks still pass
3. **Merge:** Approve and merge the PR
4. **Local Update:** Run `git pull` and `pre-commit install`

### Security Vulnerability (Issue)

1. **Review Alert:** Check Security tab for vulnerability details
2. **Assess Impact:** Determine severity and exploitability
3. **Update Dependencies:**
   - Base image: Rebuild with latest
   - Binaries: Update versions in Dockerfile
4. **Test Thoroughly:**
   ```bash
   docker build --no-cache -t mc-server-container:test .
   docker run -d --name mc-test -e EULA=TRUE mc-server-container:test
   docker logs mc-test
   ```
5. **Rescan:**
   ```bash
   docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
     aquasec/trivy image mc-server-container:test
   ```
6. **Create PR:** If vulnerability is fixed, create PR with `release:patch` label
7. **Close Issue:** Reference vulnerability in PR

## Viewing Status

### Dependency Dashboard

Check the [Dependency Status Dashboard](../../issues?q=is%3Aissue+is%3Aopen+label%3Adashboard) issue for:
- Current versions of all dependencies
- Comparison with latest available versions
- Status indicators (✅ up-to-date, ⚠️ update available)
- Active monitoring workflows
- Recent dependency-related activity

### Security Tab

Visit [Security](../../security) to see:
- Code scanning alerts (Trivy results)
- Security advisories
- Dependabot alerts (if any)

### Open Issues

Filter issues by label:
- [dependencies](../../issues?q=is%3Aissue+is%3Aopen+label%3Adependencies) - All dependency updates
- [security](../../issues?q=is%3Aissue+is%3Aopen+label%3Asecurity) - Security vulnerabilities
- [automated](../../issues?q=is%3Aissue+is%3Aopen+label%3Aautomated) - Auto-created issues

### Pull Requests

Filter PRs by label:
- [dependencies](../../pulls?q=is%3Apr+is%3Aopen+label%3Adependencies) - Dependency update PRs

## Manual Checks

Some dependencies may require manual checking:

### Paper Server

**Not monitored automatically** - Container does not auto-download Paper

Check for updates:
1. Visit [PaperMC Downloads](https://papermc.io/downloads)
2. Compare with your current version in `/data/paper.jar`
3. Download manually or use `check-minecraft-versions` tool

### Plugins

**Not monitored automatically** - Plugins are user-managed

Check for updates:
1. Use `check-minecraft-versions` tool (separate repository)
2. Check plugin websites/GitHub releases
3. Update manually in `/data/plugins/`

### OpenTelemetry Java Agent

**Not included in container** - Optional, user-provided

If using OpenTelemetry:
1. Check [opentelemetry-java-instrumentation releases](https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases)
2. Update agent JAR in your volume mount
3. Restart container

## Troubleshooting

### Workflow Not Running

**Check:**
- Workflow is enabled in Actions tab
- Schedule is correct (UTC time)
- No workflow failures blocking execution

**Fix:**
- Manually trigger with workflow_dispatch
- Check workflow logs for errors

### Issues Not Created

**Possible Causes:**
- Issue already exists (check open issues)
- No updates available
- API rate limiting

**Fix:**
- Check existing issues with `automated` label
- Manually trigger workflow
- Wait and retry later

### PRs Not Created

**Possible Causes:**
- Branch already exists
- PR already open
- Insufficient permissions

**Fix:**
- Check existing PRs
- Delete stale branch and re-run workflow
- Check workflow logs

### Security Scans Failing

**Possible Causes:**
- Container build fails
- Trivy database update issues
- Too many vulnerabilities

**Fix:**
- Check build logs
- Update base image
- Review and address vulnerabilities

## Best Practices

1. **Review Regularly:** Check dashboard weekly
2. **Respond Promptly:** Address security issues within 48 hours
3. **Test Thoroughly:** Always test updates locally before merging
4. **Label Correctly:** Use `release:patch` for dependency updates
5. **Document Changes:** Note breaking changes in PR descriptions
6. **Monitor Builds:** Watch CI/CD for failures after updates
7. **Keep Current:** Don't let dependencies fall too far behind
8. **Subscribe:** Watch the repository for issue notifications

## Customization

### Change Schedule

Edit workflow files to change when checks run:

```yaml
schedule:
  - cron: '0 9 * * 1'  # Change time/day here
```

### Add More Dependencies

To monitor additional dependencies:

1. Add to `dependency-check.yml` workflow
2. Extract version from appropriate file
3. Check against upstream source
4. Create issue if update available

### Adjust Severity Thresholds

To change which vulnerabilities trigger issues:

```yaml
severity: 'CRITICAL,HIGH'  # Add/remove severities
```

### Modify Issue Templates

Edit the issue body templates in workflow files to customize:
- Issue title format
- Issue description
- Labels applied
- Assignees

## References

- [Dependabot Documentation](https://docs.github.com/en/code-security/dependabot)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [GitHub Actions](https://docs.github.com/en/actions)
- [pre-commit](https://pre-commit.com/)
- [SARIF Format](https://sarifweb.azurewebsites.net/)

---

**Questions?** Open a [Discussion](../../discussions) or create an [Issue](../../issues/new).
