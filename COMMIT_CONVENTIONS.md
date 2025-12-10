# Commit Message Conventions

This repository follows [Conventional Commits](https://www.conventionalcommits.org/) specification.

## Format

```text
<type>: <subject>

[optional body]

[optional footer]
```

## Types

- **feat**: New feature or enhancement
- **fix**: Bug fix
- **docs**: Documentation changes
- **style**: Code style changes (formatting, missing semicolons, etc.)
- **refactor**: Code refactoring without changing functionality
- **perf**: Performance improvements
- **test**: Adding or updating tests
- **chore**: Maintenance tasks (dependencies, tooling, etc.)
- **ci**: CI/CD changes
- **build**: Build system changes
- **revert**: Revert a previous commit

## Rules

1. **Type is required** and must be lowercase
2. **Subject is required** and should be concise (max 100 chars for full header)
3. **No period at end of subject**
4. **Use imperative mood**: "add feature" not "added feature"
5. **Blank line between subject and body** (if body exists)
6. **Blank line between body and footer** (if footer exists)

## Examples

### Simple commit

```text
fix: correct webhook URL path from /webhook to /hooks
```

### With body

```text
feat: add commitlint configuration

Adds conventional commit linting to enforce consistent
commit message format across the project.
```

### With breaking change

```text
feat!: change deployment directory structure

BREAKING CHANGE: Tarballs now use bin/sbin/lib structure
instead of local-bin/local-sbin/local-lib. Requires server
configuration update.
```

### With footer

```text
fix: resolve nginx 404 errors on webhook endpoint

Simplified location matching from regex to prefix match.

Closes #123
```

## Enforcement

Commitlint runs automatically via pre-commit hooks:

- **Local**: Validates commit messages before commit is created
- **CI**: Skipped (commit messages already validated locally)

To bypass (emergency only):

```bash
git commit --no-verify
```

## Setup

After cloning, install pre-commit hooks:

```bash
pip install pre-commit
pre-commit install --hook-type commit-msg
```
