# Security Policy

## Supported Versions

This project maintains security updates for the following versions:

| Version | Supported          |
| ------- | ------------------ |
| latest  | :white_check_mark: |
| < 0.1.0 | :x:                |

We recommend always using the latest version for the most up-to-date security patches.

## Security Scanning

This repository implements comprehensive automated security scanning:

### Container Image Scanning

- **Tool:** [Trivy](https://github.com/aquasecurity/trivy)
- **Frequency:** Daily (03:00 UTC) + on every push/PR
- **Severity Levels Monitored:** CRITICAL, HIGH, MEDIUM
- **Results:** Table and JSON reports in workflow logs
- **Alerts:** Automated issues created for CRITICAL/HIGH vulnerabilities (scheduled runs only)

### Dockerfile Security Analysis

- **Tool:** Trivy config scanning + Hadolint
- **Frequency:** On every push and PR
- **Checks:** Best practices, security misconfigurations
- **Results:** Reported in workflow runs

### Dependency Monitoring

- **Base Image:** Oracle GraalVM JDK monitored weekly
- **Binary Dependencies:** mc-server-runner, rcon-cli checked weekly
- **GitHub Actions:** Dependabot monitors action versions
- **Pre-commit Hooks:** Automated version checking

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it responsibly:

### For Public Vulnerabilities

1. **Open an Issue:** Create a new issue with the `security` label
2. **Provide Details:** Include steps to reproduce and impact assessment
3. **Response Time:** We aim to respond within 48 hours

### For Private/Sensitive Vulnerabilities

1. **Use GitHub Security Advisories:** Navigate to the [Security tab](../../security/advisories)
2. **Click "Report a vulnerability"** to create a private security advisory
3. **Provide Details:**
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if available)
4. **Response Time:** We aim to respond within 48 hours
5. **Disclosure:** We will work with you to understand and fix the issue before public disclosure

### What to Include in Your Report

- Type of vulnerability
- Full paths of source file(s) related to the vulnerability
- Location of the affected code (tag/branch/commit or direct URL)
- Step-by-step instructions to reproduce the issue
- Proof-of-concept or exploit code (if available)
- Impact of the vulnerability, including how an attacker might exploit it

## Security Update Process

When a security issue is identified:

1. **Assessment:** We evaluate the severity and impact
2. **Fix Development:** A fix is developed and tested
3. **Release:** A new version is released with security patches
4. **Notification:**
   - GitHub Security Advisory is published
   - Release notes include security fix details
   - Affected users are notified through GitHub

## Security Best Practices

When using this container:

### Container Runtime

- **Run as non-root:** The container runs as UID 25565 (minecraft user) by default
- **Read-only root filesystem:** Consider using `--read-only` with appropriate volumes
- **Security options:** Use Docker security options like `--cap-drop ALL --cap-add NET_BIND_SERVICE`
- **Network isolation:** Use Docker networks to isolate the container

### Secrets Management

- **Never commit secrets:** Use environment variables or Docker secrets
- **Use .env files:** Store sensitive data in `.env` files (add to `.gitignore`)
- **Rotate credentials:** Regularly rotate RCON passwords and management tokens

### Data Volume Security

- **Proper permissions:** Ensure `/data` volume has correct ownership (UID 25565)
- **Backup encryption:** Encrypt backups of server data
- **Access control:** Limit access to the host system's `/srv/minecraft` directory

### Monitoring

- **Enable OpenTelemetry:** Monitor server behavior for anomalies
- **Check logs regularly:** Review container logs for suspicious activity
- **Security alerts:** Subscribe to GitHub notifications for security advisories

## Dependency Security

### Base Image

- **Source:** Oracle GraalVM JDK from official Oracle container registry
- **Updates:** Monitored weekly, rebuild container when updates available
- **Scanning:** Base image included in daily Trivy scans

### Binary Dependencies

- **mc-server-runner:** Official releases from [itzg/mc-server-runner](https://github.com/itzg/mc-server-runner)
- **rcon-cli:** Official releases from [itzg/rcon-cli](https://github.com/itzg/rcon-cli)
- **Verification:** Downloaded from official GitHub releases only
- **Updates:** Automated monitoring creates issues when new versions available

### GitHub Actions

- **Dependabot:** Automatically monitors and updates GitHub Actions
- **Version Pinning:** All actions pinned to specific versions
- **Review Process:** Updates reviewed before merging

## Automated Security Measures

### Continuous Monitoring

Our CI/CD pipeline includes:

- ✅ Trivy container vulnerability scanning
- ✅ Dockerfile best practice checks (Hadolint)
- ✅ Shell script security linting (ShellCheck)
- ✅ Automated dependency version checking
- ✅ Scan results in workflow logs (table and JSON formats)

### Issue Automation

Security issues are automatically created for:

- Critical or high severity vulnerabilities in container images
- Binary dependency updates (mc-server-runner, rcon-cli)
- Base image updates
- Pre-commit hook updates

### Dashboard

Check the [Dependency Status Dashboard](../../issues?q=is%3Aissue+is%3Aopen+label%3Adashboard) for current security posture and dependency status.

## Acknowledgments

We appreciate security researchers and users who report vulnerabilities responsibly. Contributors will be acknowledged in:

- Security advisories
- Release notes
- Repository credits (unless anonymity is requested)

## Contact

For security-related questions or concerns:

- **Public Issues:** Use GitHub Issues with `security` label
- **Private Reports:** Use GitHub Security Advisories
- **General Questions:** Open a Discussion in the repository

---

**Note:** This security policy applies to the container itself. Security of the Minecraft server and plugins should be managed separately according to Paper and plugin-specific guidelines.
