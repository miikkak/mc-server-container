#!/bin/bash
# Script to create GitHub labels from labels.yml
# Requires: gh CLI tool (GitHub CLI)

set -e

if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is not installed"
    echo "Install from: https://cli.github.com/"
    exit 1
fi

# Check if logged in
if ! gh auth status &> /dev/null; then
    echo "Error: Not logged into GitHub CLI"
    echo "Run: gh auth login"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LABELS_FILE="$SCRIPT_DIR/../.github/labels.yml"

if [ ! -f "$LABELS_FILE" ]; then
    echo "Error: labels.yml not found at $LABELS_FILE"
    exit 1
fi

echo "Creating labels from labels.yml..."

# Parse YAML and create labels (basic parsing)
while IFS= read -r line; do
    if [[ $line =~ ^-[[:space:]]*name:[[:space:]]*(.+)$ ]]; then
        name="${BASH_REMATCH[1]}"
    elif [[ $line =~ ^[[:space:]]*color:[[:space:]]*\"?([^\"]*)\"?$ ]]; then
        color="${BASH_REMATCH[1]}"
    elif [[ $line =~ ^[[:space:]]*description:[[:space:]]*\"(.*)\"$ ]]; then
        description="${BASH_REMATCH[1]}"
        
        # Create or update label
        if [ -n "$name" ] && [ -n "$color" ]; then
            echo "Creating label: $name"
            gh label create "$name" --color "$color" --description "$description" --force || true
            name=""
            color=""
            description=""
        fi
    fi
done < "$LABELS_FILE"

echo "Labels created successfully!"
