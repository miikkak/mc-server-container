#!/bin/bash
set -euo pipefail

# Helper script to create GitHub issues from markdown files
# Usage: ./create-issues.sh [issue-number]
# If no issue number is provided, creates all issues

REPO="miikkak/mc-server-container"

# Function to extract title (first line without #)
get_title() {
  local file="$1"
  head -1 "$file" | sed 's/^# //'
}

# Function to extract labels
get_labels() {
  local file="$1"
  sed -n 's/^\*\*Labels\*\*: `\(.*\)`$/\1/p' "$file"
}

# Function to extract body (skip title and metadata)
get_body() {
  local file="$1"
  # Skip first 4 lines (title, blank, labels, priority)
  tail -n +5 "$file"
}

# Function to create a single issue
create_issue() {
  local file="$1"
  local title labels body

  title=$(get_title "$file")
  labels=$(get_labels "$file")
  body=$(get_body "$file")

  echo "Creating issue: $title"

  # Create issue with gh CLI
  gh issue create \
    --repo "$REPO" \
    --title "$title" \
    --label "$labels" \
    --body "$body"

  echo "✓ Created successfully"
  echo ""
}

# Main logic
if [ $# -eq 0 ]; then
  # Create all issues
  echo "Creating all issues from markdown files..."
  echo ""

  for file in issue-*.md; do
    if [ -f "$file" ]; then
      create_issue "$file"
    fi
  done

  echo "All issues created!"
else
  # Create specific issue
  issue_num=$(printf "%03d" "$1")

  # Find matching file using shell glob
  matched_file=""
  for f in issue-"${issue_num}"-*.md; do
    if [ -f "$f" ]; then
      matched_file="$f"
      break
    fi
  done

  if [ -z "$matched_file" ]; then
    echo "Error: No file found matching pattern: issue-${issue_num}-*.md"
    echo ""
    echo "Available issues:"
    for f in issue-*.md; do
      [ -f "$f" ] || continue
      # Extract issue number (e.g., "issue-001-foo.md" -> "001")
      num=$(echo "$f" | sed 's/^issue-//' | sed 's/-.*//')
      echo "  $num"
    done | sort -u
    exit 1
  fi

  create_issue "$matched_file"
fi
