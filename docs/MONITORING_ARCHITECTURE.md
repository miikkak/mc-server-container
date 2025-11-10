# Dependency Monitoring Architecture

## Overview

This document provides a visual overview of the automated dependency monitoring and security scanning architecture implemented in this repository.

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                     Dependency Monitoring System                     │
└─────────────────────────────────────────────────────────────────────┘

┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│   Dependabot     │  │ Custom Workflows │  │ Security Scans   │
│   (GitHub)       │  │ (GitHub Actions) │  │   (Trivy)        │
└────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘
         │                     │                      │
         │                     │                      │
         ▼                     ▼                      ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        Monitored Components                          │
├──────────────┬──────────────┬──────────────┬──────────────┬─────────┤
│ GitHub       │ Docker       │ mc-server-   │ rcon-cli     │ Pre-    │
│ Actions      │ Base Image   │ runner       │              │ commit  │
│              │              │              │              │ Hooks   │
└──────┬───────┴──────┬───────┴──────┬───────┴──────┬───────┴─────┬───┘
       │              │              │              │             │
       │              │              │              │             │
       ▼              ▼              ▼              ▼             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                          Output Actions                              │
├──────────────┬──────────────┬──────────────┬──────────────┬─────────┤
│ Auto PRs     │ Issues       │ Scan Reports │ Dashboard    │ Alerts  │
│              │              │ (Logs)       │ Issue        │         │
└──────────────┴──────────────┴──────────────┴──────────────┴─────────┘
```

## Workflow Schedule

```
Monday         Tuesday - Sunday    Daily
09:00 UTC      (No scheduled       03:00 UTC
               workflows)
┌──────────┐                      ┌──────────┐
│Dependabot│                      │ Security │
│  Check   │                      │   Scan   │
└────┬─────┘                      └────┬─────┘
     │                                 │
09:00│                            Daily│at 03:00
     │                                 │
     ▼                                 ▼
┌──────────┐                      ┌──────────┐
│ Binary   │                      │  Trivy   │
│Deps Check│                      │Container │
└────┬─────┘                      │   Scan   │
     │                            └──────────┘
09:30│                                 │
     │                                 │
     ▼                            Every│Push/PR
┌──────────┐                           │
│Pre-commit│                           ▼
│ Updates  │                      ┌──────────┐
└────┬─────┘                      │ Security │
     │                            │   Check  │
10:00│                            └──────────┘
     │
     ▼
┌──────────┐
│Dashboard │
│  Update  │
└──────────┘
```

## Data Flow

### 1. Dependabot Flow

```
Dependabot (GitHub)
       │
       ├─► Checks GitHub Actions versions
       │        │
       │        └─► Creates PR if update available
       │
       └─► Checks Docker base image version
                │
                └─► Creates PR if update available
```

### 2. Binary Dependency Check Flow

```
Workflow Trigger (Weekly)
       │
       ├─► Extract versions from Dockerfile
       │        │
       │        ├─► MC_SERVER_RUNNER_VERSION
       │        └─► RCON_CLI_VERSION
       │
       ├─► Query GitHub API for latest releases
       │        │
       │        ├─► mc-server-runner latest
       │        └─► rcon-cli latest
       │
       └─► Compare versions
                │
                ├─► Match? → No action
                └─► Mismatch? → Create/update issue
```

### 3. Security Scan Flow

```
Workflow Trigger (Daily/Push/PR)
       │
       ├─► Build container image
       │        │
       │        └─► mc-server-container:scan
       │
       ├─► Run Trivy vulnerability scan
       │        │
       │        ├─► Generate JSON report
       │        └─► Generate table report
       │
       └─► Count vulnerabilities
                │
                ├─► None? → No action
                └─► Found? → Create/update issue
```

### 4. Pre-commit Update Flow

```
Workflow Trigger (Weekly)
       │
       ├─► Run pre-commit autoupdate
       │        │
       │        └─► Check for hook updates
       │
       └─► Updates available?
                │
                ├─► Yes → Create PR with updates
                │        │
                │        └─► Fails? → Create issue
                │
                └─► No → No action
```

### 5. Dashboard Creation Flow

```
Workflow Trigger (Weekly)
       │
       ├─► Collect version information
       │        │
       │        ├─► Extract from Dockerfile
       │        ├─► Query GitHub APIs
       │        └─► List GitHub Actions
       │
       ├─► Generate status report
       │        │
       │        ├─► Current versions
       │        ├─► Latest versions
       │        ├─► Update status (✅/⚠️)
       │        └─► Active monitors
       │
       └─► Create or update dashboard issue
```

## Integration Points

### GitHub Features Used

```
┌─────────────────────────────────────────────┐
│            GitHub Integration               │
├─────────────────────────────────────────────┤
│                                             │
│  ┌──────────────┐  ┌──────────────┐       │
│  │   Workflow   │  │    Issues    │       │
│  │    Logs      │  │              │       │
│  │  (Reports)   │  │  - Updates   │       │
│  │              │  │  - Security  │       │
│  └──────────────┘  │  - Dashboard │       │
│                    └──────────────┘        │
│                                             │
│  ┌──────────────┐  ┌──────────────┐       │
│  │     PRs      │  │   Actions    │       │
│  │              │  │              │       │
│  │ - Dependabot │  │  - Workflows │       │
│  │ - Pre-commit │  │  - Manual    │       │
│  │              │  │    triggers  │       │
│  └──────────────┘  └──────────────┘        │
│                                             │
└─────────────────────────────────────────────┘
```

## Notification Flow

```
Event Occurs
     │
     ├─► Update Available
     │        │
     │        ├─► Dependabot → PR created → Email
     │        ├─► Binary → Issue created → Email
     │        └─► Pre-commit → PR created → Email
     │
     ├─► Security Issue
     │        │
     │        └─► Trivy finds vuln → Issue created → Email
     │
     └─► Dashboard Update
              │
              └─► Issue updated → No email (to reduce noise)
```

## Maintenance Windows

### Weekly (Monday Morning)
- **09:00 UTC** - Dependabot checks + Binary dependency checks
- **09:30 UTC** - Pre-commit hook updates
- **10:00 UTC** - Dashboard update

### Daily
- **03:00 UTC** - Security scan (Trivy)

### On-Demand
- Every push to main
- Every pull request
- Manual workflow trigger

## Labels Used

```
┌────────────────────────────────────────────────┐
│                  Label System                  │
├────────────────────────────────────────────────┤
│                                                │
│  dependencies    → All dependency updates      │
│  security        → Security vulnerabilities    │
│  automated       → Auto-created items          │
│  dashboard       → Dashboard issue             │
│  github-actions  → GitHub Actions updates      │
│  docker          → Docker image updates        │
│  release:patch   → Triggers patch release      │
│  bug             → Security issues (severity)  │
│  enhancement     → Feature additions           │
│                                                │
└────────────────────────────────────────────────┘
```

## Response Time SLAs

```
┌──────────────────────────────────────────────────┐
│              Recommended Response Times           │
├──────────────────────────────────────────────────┤
│                                                  │
│  CRITICAL Vulnerability  →  < 24 hours           │
│  HIGH Vulnerability      →  < 48 hours           │
│  MEDIUM Vulnerability    →  < 1 week             │
│  Binary Updates          →  < 1 week             │
│  GitHub Actions Updates  →  < 2 weeks            │
│  Pre-commit Updates      →  < 2 weeks            │
│  Base Image Updates      →  < 1 month            │
│                                                  │
└──────────────────────────────────────────────────┘
```

## Permissions Required

```
┌────────────────────────────────────────────┐
│         Workflow Permissions               │
├────────────────────────────────────────────┤
│                                            │
│  Workflow              Permissions         │
│  ─────────────────────────────────────     │
│  dependency-check      contents: read      │
│                        issues: write       │
│                                            │
│  security-scan         contents: read      │
│                        issues: write       │
│                                            │
│  precommit-updates     contents: read      │
│                        issues: write       │
│                        pull-requests:write │
│                                            │
│  dependency-dashboard  contents: read      │
│                        issues: write       │
│                                            │
└────────────────────────────────────────────┘
```

## Security Considerations

### Automated PRs
- All PRs created by workflows use GitHub Actions token
- Limited to repository scope
- Cannot access secrets
- Cannot bypass branch protection

### API Rate Limits
- GitHub API: 1000 requests/hour for workflows
- Current usage: ~10 requests/week
- No risk of rate limiting

### Secrets Management
- No secrets stored in workflows
- Uses GitHub's built-in `GITHUB_TOKEN`
- Token auto-expires after workflow

## Monitoring the Monitors

### How to verify the system is working:

1. **Check last workflow runs** - Actions tab
2. **Review dashboard issue** - Should update weekly
3. **Check for stale PRs** - Dependencies label
4. **Workflow logs** - Review scan results in security-scan workflow
5. **Issue creation** - Automated issues being created

### Signs of problems:

- ❌ Dashboard not updated in > 2 weeks
- ❌ No Trivy scans in > 2 days
- ❌ Dependabot PRs failing
- ❌ Pre-commit PR creation failing
- ❌ Workflow errors in Actions tab

## Future Enhancements

Potential additions to consider:

1. **Slack/Discord notifications** - Real-time alerts
2. **Automatic PR merging** - For low-risk updates
3. **Custom vulnerability scanners** - Additional tools
4. **Compliance reporting** - SOC2/ISO27001
5. **Dependency graphs** - Visual representations
6. **Trend analysis** - Historical data tracking

---

This architecture provides comprehensive, automated dependency monitoring with minimal manual intervention while maintaining security and visibility.
