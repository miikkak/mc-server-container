# Security Policy

## Supported Versions

We release patches for security vulnerabilities for the following versions:

| Version | Supported          |
| ------- | ------------------ |
| latest  | :white_check_mark: |
| < 0.9.x | :x:                |

## Reporting a Vulnerability

We take the security of this project seriously. If you discover a security vulnerability, please follow these steps:

### Do Not

- **Do not** open a public GitHub issue for security vulnerabilities
- **Do not** disclose the vulnerability publicly until it has been addressed

### Do

1. **Report privately** via one of these methods:
   - Use [GitHub Security Advisories](https://github.com/miikkak/mc-server-container/security/advisories/new) (preferred)
   - Email the maintainer directly (check git log for contact information)

2. **Include in your report:**
   - Description of the vulnerability
   - Steps to reproduce the issue
   - Potential impact
   - Suggested fix (if you have one)
   - Your contact information for follow-up

3. **Response timeline:**
   - You should receive an acknowledgment within 48 hours
   - We'll provide a detailed response within 7 days
   - We'll work with you to understand and fix the issue
   - We'll release a fix as soon as possible

## Security Best Practices

When using this container in production:

### Container Security

- Always use specific version tags, not `latest`
- Run containers with minimal privileges (non-root when possible)
- Use read-only filesystems where appropriate
- Limit container resources (CPU, memory)
- Enable security scanning in your CI/CD pipeline

### Network Security

- Restrict network access to Minecraft ports
- Use firewalls to limit connections
- Consider using a VPN for administrative access
- Enable RCON authentication if using remote console

### Data Security

- Store world data on persistent volumes
- Back up world data regularly
- Protect RCON passwords (use secrets management)
- Don't commit sensitive data to version control

### Monitoring

- Monitor container logs for suspicious activity
- Set up alerts for unusual behavior
- Keep the container image updated
- Subscribe to security advisories

## Security Scanning

This project uses automated security scanning:

- **Trivy** for container vulnerability scanning
- **Hadolint** for Dockerfile security linting
- **ShellCheck** for shell script security issues
- **GitHub Dependabot** for dependency updates

All PRs are automatically scanned before merge.

## Disclosure Policy

- Security issues are fixed in private before public disclosure
- After a fix is released, we publish a security advisory
- We credit reporters in the advisory (unless they prefer anonymity)
- We aim for responsible disclosure within 90 days

## Past Security Advisories

No security advisories have been published yet.

## Contact

For security-related questions or concerns, please use the reporting methods above rather than public channels.
