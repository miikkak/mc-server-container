# Contributing to Custom Minecraft Server Container

Thank you for considering contributing to this project! We welcome contributions from the community.

## Getting Started

1. Fork the repository
2. Clone your fork locally
3. Create a new branch for your changes
4. Make your changes
5. Test your changes
6. Submit a pull request

## Forking this Repository

If you're creating your own fork of this project, you'll need to update repository-specific references:

### Files to Update

1. **`.github/dependabot.yml`** (lines 23, 42)
   - Update `reviewers: - "miikkak"` to your GitHub username

2. **`.github/ISSUE_TEMPLATE/config.yml`** (line 4)
   - Update URL: `https://github.com/miikkak/mc-server-container/discussions`
   - Change to: `https://github.com/YOUR-USERNAME/YOUR-REPO-NAME/discussions`

3. **`CONTRIBUTING.md`** (line 154)
   - Update the GitHub Discussions URL to point to your fork

4. **`SECURITY.md`** (line 24)
   - Update URL: `https://github.com/miikkak/mc-server-container/security/advisories/new`
   - Change to: `https://github.com/YOUR-USERNAME/YOUR-REPO-NAME/security/advisories/new`

These references are intentionally hardcoded as they point to the canonical repository. After forking, update them to point to your fork's location.

## Development Requirements

- Bash 5+
- Docker or Podman
- Pre-commit hooks
- Git

## Code Quality Standards

This project maintains high code quality standards using automated tooling:

### Pre-commit Hooks

All commits must pass pre-commit hooks. Install them with:

```bash
pre-commit install
```

The hooks will automatically run:

- `shellcheck` - Shell script linting
- `shfmt` - Shell script formatting (2-space indentation)
- `hadolint` - Dockerfile linting
- `commitlint` - Commit message validation

### Commit Message Format

We use [Conventional Commits](https://www.conventionalcommits.org/). Your commit messages should follow this format:

```text
<type>(<scope>): <description>

[optional body]

[optional footer]
```

Types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `ci`

Examples:

- `feat: add support for Java 25`
- `fix: resolve memory leak in startup script`
- `docs: update README with new configuration options`
- `chore(deps): update base image to latest version`

### Code Style

#### Bash Scripts

- Use idiomatic Bash 5+ features
- Include `set -Eeuo pipefail` at script start
- Use `[[ ... ]]` for conditionals
- Quote variable expansions
- Use 2-space indentation (enforced by shfmt)
- See `.shellcheckrc` for linting rules

#### Dockerfile

- Follow Hadolint recommendations
- Use multi-stage builds
- Pin versions for dependencies
- Minimize layer count
- See `.hadolint-wrapper.sh` for configuration

## Branch Workflow

- **Never commit directly to `main`**
- Create feature branches from `main`
- Name branches descriptively (e.g., `feat/add-java-version`, `fix/startup-error`)
- All work must be submitted via Pull Request
- PRs require passing CI/CD checks

## Testing

Before submitting a PR:

1. Run pre-commit hooks:

   ```bash
   pre-commit run --all-files
   ```

2. Build the container locally:

   ```bash
   docker build -t mc-server-container:test .
   # or
   podman build -t mc-server-container:test .
   ```

3. Test the container:

   ```bash
   docker run --rm -it mc-server-container:test
   # or
   podman run --rm -it mc-server-container:test
   ```

## CI/CD Pipeline

All PRs trigger automated CI/CD that includes:

- Linting (shellcheck, hadolint, super-linter)
- Container build
- Security scanning (Trivy)
- Docker and Podman compatibility tests

Your PR must pass all checks before it can be merged.

## Pull Request Process

1. Ensure your branch is up-to-date with `main`
2. Push your branch to your fork
3. Open a Pull Request against `main`
4. Fill in the PR template with:
   - Clear description of changes
   - Link to any related issues
   - Test plan
5. Wait for CI/CD checks to complete
6. Address any review feedback
7. Once approved and checks pass, a maintainer will merge your PR

## What to Contribute

We welcome contributions in these areas:

- Bug fixes
- Feature enhancements
- Documentation improvements
- Test coverage improvements
- Performance optimizations
- Security improvements

Please open an issue first if you're planning a major change to discuss the approach.

## Getting Help

- Open an issue for bug reports or feature requests
- Use [GitHub Discussions](https://github.com/miikkak/mc-server-container/discussions) for questions
- Check existing issues and PRs to avoid duplicates

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
