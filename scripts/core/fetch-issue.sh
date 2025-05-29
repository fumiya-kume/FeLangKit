#!/bin/bash

# GitHub Issue Fetcher
# Usage: ./fetch-issue.sh <github-issue-url> <output-file>

set -euo pipefail

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >&2
}

error() {
    echo "[ERROR] $1" >&2
}

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <github-issue-url> <output-file>"
    exit 1
fi

ISSUE_URL="$1"
OUTPUT_FILE="$2"

# Extract owner, repo, and issue number from URL
if [[ "$ISSUE_URL" =~ ^https://github\.com/([^/]+)/([^/]+)/issues/([0-9]+)$ ]]; then
    OWNER="${BASH_REMATCH[1]}"
    REPO="${BASH_REMATCH[2]}"
    ISSUE_NUMBER="${BASH_REMATCH[3]}"
else
    error "Invalid GitHub issue URL format"
    exit 1
fi

log "Fetching issue #$ISSUE_NUMBER from $OWNER/$REPO"

# Check if gh CLI is available
if ! command -v gh &> /dev/null; then
    error "GitHub CLI (gh) is not installed. Please install it: brew install gh"
    exit 1
fi

# Check if user is authenticated
if ! gh auth status &> /dev/null; then
    error "Not authenticated with GitHub CLI. Please run: gh auth login"
    exit 1
fi

# Fetch issue data using GitHub CLI
TEMP_FILE=$(mktemp)
trap "rm -f '$TEMP_FILE'" EXIT

if ! gh api "repos/$OWNER/$REPO/issues/$ISSUE_NUMBER" > "$TEMP_FILE"; then
    error "Failed to fetch issue data. Check if the issue exists and you have access."
    exit 1
fi

# Extract relevant information and create structured output
jq -n \
    --arg url "$ISSUE_URL" \
    --arg owner "$OWNER" \
    --arg repo "$REPO" \
    --arg issue_number "$ISSUE_NUMBER" \
    --argjson issue_data "$(cat "$TEMP_FILE")" \
    '{
        url: $url,
        owner: $owner,
        repo: $repo,
        issue_number: ($issue_number | tonumber),
        title: $issue_data.title,
        body: $issue_data.body,
        state: $issue_data.state,
        labels: [$issue_data.labels[]?.name],
        assignees: [$issue_data.assignees[]?.login],
        milestone: $issue_data.milestone?.title,
        created_at: $issue_data.created_at,
        updated_at: $issue_data.updated_at,
        author: $issue_data.user.login,
        branch_name: ("issue-" + $issue_number + "-" + (now | strftime("%Y%m%d"))),
        pr_title: ("Resolve #" + $issue_number + ": " + $issue_data.title)
    }' > "$OUTPUT_FILE"

log "Issue data saved to $OUTPUT_FILE"

# Display summary
echo "Issue Summary:"
echo "  Title: $(jq -r '.title' "$OUTPUT_FILE")"
echo "  Author: $(jq -r '.author' "$OUTPUT_FILE")"
echo "  State: $(jq -r '.state' "$OUTPUT_FILE")"
echo "  Labels: $(jq -r '.labels | join(", ")' "$OUTPUT_FILE")"
echo "  Branch: $(jq -r '.branch_name' "$OUTPUT_FILE")"

if [[ "$(jq -r '.state' "$OUTPUT_FILE")" != "open" ]]; then
    error "Issue is not in open state. Current state: $(jq -r '.state' "$OUTPUT_FILE")"
    exit 1
fi

log "Issue fetch completed successfully"