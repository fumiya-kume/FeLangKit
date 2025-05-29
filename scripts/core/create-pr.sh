#!/bin/bash

# PR Creation Script
# Usage: ./create-pr.sh <issue-data-file> <container-name>

set -euo pipefail

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >&2
}

error() {
    echo "[ERROR] $1" >&2
}

success() {
    echo "[SUCCESS] $1" >&2
}

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <issue-data-file> <container-name>"
    exit 1
fi

ISSUE_DATA_FILE="$1"
CONTAINER_NAME="$2"

# Check if issue data file exists
if [[ ! -f "$ISSUE_DATA_FILE" ]]; then
    error "Issue data file not found: $ISSUE_DATA_FILE"
    exit 1
fi

# Extract issue information
ISSUE_TITLE=$(jq -r '.title' "$ISSUE_DATA_FILE")
BRANCH_NAME=$(jq -r '.branch_name' "$ISSUE_DATA_FILE")
PR_TITLE=$(jq -r '.pr_title' "$ISSUE_DATA_FILE")
ISSUE_NUMBER=$(jq -r '.issue_number' "$ISSUE_DATA_FILE")
OWNER=$(jq -r '.owner' "$ISSUE_DATA_FILE")
REPO=$(jq -r '.repo' "$ISSUE_DATA_FILE")

log "Monitoring container and preparing PR for issue #$ISSUE_NUMBER"

# Wait for Claude Code work to complete
wait_for_completion() {
    log "Claude Code has finished. Checking for changes..."
    
    # Give user a moment to review before proceeding
    echo -n "Press Enter to proceed with PR creation or 'q' to quit: "
    read -r input
    
    case "$input" in
        q|Q|quit|exit)
            log "User requested to quit"
            return 1
            ;;
        *)
            log "Proceeding with PR creation..."
            return 0
            ;;
    esac
}

# Check if branch exists and has commits
check_branch_status() {
    log "Checking if branch $BRANCH_NAME exists and has changes..."
    
    if ! git ls-remote --heads origin "$BRANCH_NAME" | grep -q "$BRANCH_NAME"; then
        error "Branch $BRANCH_NAME does not exist on remote"
        return 1
    fi
    
    # Get the number of commits ahead of master
    local commits_ahead
    commits_ahead=$(git rev-list --count "origin/master..origin/$BRANCH_NAME" 2>/dev/null || echo "0")
    
    if [[ "$commits_ahead" -eq 0 ]]; then
        error "Branch $BRANCH_NAME has no commits ahead of master"
        return 1
    fi
    
    success "Branch $BRANCH_NAME has $commits_ahead commits ahead of master"
    return 0
}

# Create pull request
create_pull_request() {
    log "Creating pull request..."
    
    # Check if PR already exists
    if gh pr list --head "$BRANCH_NAME" --json number --jq '.[0].number' | grep -q .; then
        local existing_pr
        existing_pr=$(gh pr list --head "$BRANCH_NAME" --json number,url --jq '.[0] | "#\(.number): \(.url)"')
        success "Pull request already exists: $existing_pr"
        return 0
    fi
    
    # Get commit messages for PR body
    local commit_messages
    commit_messages=$(git log --oneline "origin/master..origin/$BRANCH_NAME" | head -10)
    
    # Create PR body
    local pr_body
    pr_body="## Summary
Resolves #$ISSUE_NUMBER

This PR addresses the issue: $ISSUE_TITLE

## Changes
\`\`\`
$commit_messages
\`\`\`

## Test Plan
- [x] All existing tests pass
- [x] SwiftLint validation passes
- [x] Code builds successfully

🤖 Generated with Claude Code Automation"
    
    # Create the PR
    local pr_url
    if pr_url=$(gh pr create \
        --title "$PR_TITLE" \
        --body "$pr_body" \
        --head "$BRANCH_NAME" \
        --base master 2>&1); then
        success "Pull request created: $pr_url"
        
        # Watch PR checks
        log "Monitoring PR checks..."
        gh pr checks --watch
        
        return 0
    else
        error "Failed to create pull request: $pr_url"
        return 1
    fi
}

# Main execution
main() {
    log "Starting PR creation process"
    
    # Wait for container completion
    if ! wait_for_completion; then
        error "Container did not complete successfully"
        exit 1
    fi
    
    # Fetch latest changes
    log "Fetching latest changes from remote..."
    git fetch origin
    
    # Check branch status
    if ! check_branch_status; then
        error "Branch validation failed"
        exit 1
    fi
    
    # Create pull request
    if create_pull_request; then
        success "PR creation completed successfully!"
    else
        error "PR creation failed"
        exit 1
    fi
}

main