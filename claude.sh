#!/bin/bash

# Claude Worktree - Parallel Claude Code development with git worktree
# Usage: ./claude-worktree.sh <github-issue-url>
# 
# This script creates a new git worktree, fetches GitHub issue data,
# launches Claude Code with issue context, and manages the complete
# development workflow including PR creation and CI monitoring.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration
WORKTREE_BASE_DIR="${PROJECT_ROOT}/../worktrees"
ISSUE_DATA_FILE=""
ANALYSIS_FILE=""
BRANCH_NAME=""
WORKTREE_PATH=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

cleanup() {
    log "Cleanup initiated..."
    if [[ -n "$ISSUE_DATA_FILE" && -f "$ISSUE_DATA_FILE" ]]; then
        rm -f "$ISSUE_DATA_FILE"
        log "Removed temporary issue data file"
    fi
    if [[ -n "$ANALYSIS_FILE" && -f "$ANALYSIS_FILE" ]]; then
        rm -f "$ANALYSIS_FILE"
        log "Removed temporary analysis file"
    fi
}

trap cleanup EXIT

usage() {
    cat << EOF
Claude Worktree - Parallel Claude Code Development

Usage: $0 <github-issue-url>

This script automates the complete development workflow:
1. Creates a new git worktree for isolated development
2. Fetches GitHub issue data using gh CLI
3. Launches Claude Code with issue context
4. Manages branch creation, commits, and push
5. Creates pull request with proper title and description
6. Monitors CI checks until completion

Examples:
  $0 https://github.com/owner/repo/issues/123
  $0 https://github.com/fumiya-kume/FeLangKit/issues/87

Prerequisites:
  - git worktree support
  - GitHub CLI (gh) installed and authenticated
  - Claude Code CLI available
  - SwiftLint for code quality

Options:
  -h, --help    Show this help message
  --cleanup     Remove all existing worktrees (use with caution)
EOF
}

validate_prerequisites() {
    step "Validating prerequisites..."
    
    # Check git version (worktree support requires git 2.5+)
    if ! git --version | grep -q "git version"; then
        error "Git is not installed or not accessible"
        exit 1
    fi
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        error "Not in a git repository"
        exit 1
    fi
    
    # Check GitHub CLI
    if ! command -v gh &> /dev/null; then
        error "GitHub CLI (gh) is not installed. Install with: brew install gh"
        exit 1
    fi
    
    # Check GitHub authentication
    if ! gh auth status &> /dev/null; then
        error "Not authenticated with GitHub CLI. Run: gh auth login"
        exit 1
    fi
    
    # Check Claude Code CLI
    if ! command -v claude &> /dev/null; then
        error "Claude Code CLI is not installed. Install from: https://docs.anthropic.com/en/docs/claude-code"
        exit 1
    fi
    
    # Check SwiftLint (optional but recommended)
    if ! command -v swiftlint &> /dev/null; then
        warn "SwiftLint not found. Install with: brew install swiftlint"
    fi
    
    success "All prerequisites validated"
}

validate_url() {
    local url="$1"
    if [[ ! "$url" =~ ^https://github\.com/[^/]+/[^/]+/issues/[0-9]+$ ]]; then
        error "Invalid GitHub issue URL format. Expected: https://github.com/owner/repo/issues/123"
        exit 1
    fi
}

extract_issue_info() {
    local issue_url="$1"
    
    if [[ "$issue_url" =~ ^https://github\.com/([^/]+)/([^/]+)/issues/([0-9]+)$ ]]; then
        OWNER="${BASH_REMATCH[1]}"
        REPO="${BASH_REMATCH[2]}"
        ISSUE_NUMBER="${BASH_REMATCH[3]}"
        BRANCH_NAME="issue-${ISSUE_NUMBER}-$(date +%Y%m%d)"
        WORKTREE_PATH="${WORKTREE_BASE_DIR}/${BRANCH_NAME}"
        ISSUE_DATA_FILE="${WORKTREE_PATH}/.issue-data.json"
        ANALYSIS_FILE="${WORKTREE_PATH}/.analysis-data.json"
    else
        error "Failed to extract issue information from URL"
        exit 1
    fi
}

fetch_issue_data() {
    local issue_url="$1"
    
    step "Fetching GitHub issue data..."
    
    # Create temporary file for issue data
    local temp_file=$(mktemp)
    trap "rm -f '$temp_file'" EXIT
    
    # Use GitHub CLI to fetch issue data
    if ! gh api "repos/${OWNER}/${REPO}/issues/${ISSUE_NUMBER}" > "$temp_file"; then
        error "Failed to fetch issue data. Check if the issue exists and you have access."
        exit 1
    fi
    
    # Create structured issue data
    jq -n \
        --arg url "$issue_url" \
        --arg owner "$OWNER" \
        --arg repo "$REPO" \
        --arg issue_number "$ISSUE_NUMBER" \
        --arg branch_name "$BRANCH_NAME" \
        --argjson issue_data "$(cat "$temp_file")" \
        '{
            url: $url,
            owner: $owner,
            repo: $repo,
            issue_number: ($issue_number | tonumber),
            branch_name: $branch_name,
            title: $issue_data.title,
            body: $issue_data.body,
            state: $issue_data.state,
            labels: [$issue_data.labels[]?.name],
            assignees: [$issue_data.assignees[]?.login],
            milestone: $issue_data.milestone?.title,
            created_at: $issue_data.created_at,
            updated_at: $issue_data.updated_at,
            author: $issue_data.user.login,
            pr_title: ("Resolve #" + $issue_number + ": " + $issue_data.title)
        }' > "$ISSUE_DATA_FILE"
    
    # Validate issue state
    local issue_state=$(jq -r '.state' "$ISSUE_DATA_FILE")
    if [[ "$issue_state" != "open" ]]; then
        error "Issue #${ISSUE_NUMBER} is not open (current state: $issue_state)"
        exit 1
    fi
    
    success "Issue data fetched: $(jq -r '.title' "$ISSUE_DATA_FILE")"
    info "Author: $(jq -r '.author' "$ISSUE_DATA_FILE")"
    info "Labels: $(jq -r '.labels | join(", ")' "$ISSUE_DATA_FILE")"
}

create_worktree() {
    step "Creating git worktree..."
    
    # Ensure base directory exists
    mkdir -p "$WORKTREE_BASE_DIR"
    
    # Check if worktree already exists
    if [[ -d "$WORKTREE_PATH" ]]; then
        warn "Worktree already exists at $WORKTREE_PATH"
        read -p "Do you want to remove and recreate it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "Removing existing worktree..."
            git worktree remove "$WORKTREE_PATH" --force || true
            rm -rf "$WORKTREE_PATH"
        else
            error "Cannot proceed with existing worktree"
            exit 1
        fi
    fi
    
    # Fetch latest changes
    log "Fetching latest changes..."
    git fetch origin
    
    # Create new worktree from master
    log "Creating worktree at: $WORKTREE_PATH"
    if ! git worktree add "$WORKTREE_PATH" -b "$BRANCH_NAME" origin/master; then
        error "Failed to create git worktree"
        exit 1
    fi
    
    success "Git worktree created: $WORKTREE_PATH"
    info "Branch: $BRANCH_NAME"
}

generate_analysis() {
    step "Generating strategic analysis for Claude Code..."
    
    # Create analysis prompt based on issue data
    local issue_title=$(jq -r '.title' "$ISSUE_DATA_FILE")
    local issue_body=$(jq -r '.body' "$ISSUE_DATA_FILE")
    local issue_labels=$(jq -r '.labels | join(", ")' "$ISSUE_DATA_FILE")
    
    # Create strategic analysis
    cat > "$ANALYSIS_FILE" << EOF
{
    "analysis_type": "strategic_implementation",
    "issue_context": {
        "title": $(jq -r '.title' "$ISSUE_DATA_FILE" | jq -R .),
        "description": $(jq -r '.body // ""' "$ISSUE_DATA_FILE" | jq -R .),
        "labels": $(jq '.labels' "$ISSUE_DATA_FILE"),
        "priority": "high"
    },
    "implementation_strategy": {
        "approach": "systematic_implementation",
        "phases": [
            "analyze_codebase_structure",
            "implement_core_functionality", 
            "add_comprehensive_tests",
            "validate_with_quality_checks"
        ],
        "quality_requirements": [
            "maintain_existing_test_coverage",
            "follow_swift_coding_standards",
            "ensure_swiftlint_compliance",
            "validate_build_success"
        ]
    },
    "development_context": {
        "project_type": "swift_package",
        "testing_framework": "swift_testing",
        "quality_tools": ["swiftlint"],
        "build_system": "swift_package_manager"
    },
    "success_criteria": {
        "functional": "implementation_meets_issue_requirements",
        "quality": "all_tests_pass_and_linting_clean",
        "integration": "builds_successfully_in_ci"
    }
}
EOF
    
    success "Strategic analysis generated"
}

launch_claude_code() {
    step "Launching Claude Code in worktree..."
    
    # Change to worktree directory
    cd "$WORKTREE_PATH"
    
    # Create initial context message
    local context_message="I need to implement the following GitHub issue:

**Issue #${ISSUE_NUMBER}: $(jq -r '.title' "$ISSUE_DATA_FILE")**

$(jq -r '.body // "No description provided"' "$ISSUE_DATA_FILE")

**Labels:** $(jq -r '.labels | join(", ")' "$ISSUE_DATA_FILE")
**Branch:** $BRANCH_NAME

Please implement this according to the project's coding standards and ensure:
1. All existing tests continue to pass
2. SwiftLint validation passes
3. Code builds successfully
4. Add appropriate tests for new functionality
5. Follow the established architecture patterns

After implementation, please:
1. Create appropriate commits with conventional commit messages
2. Push the branch to origin
3. The PR will be created automatically

Let me know when you're ready to start!"
    
    info "Starting Claude Code session..."
    info "Worktree: $WORKTREE_PATH"
    info "Branch: $BRANCH_NAME"
    echo
    echo "Context for Claude Code:"
    echo "======================="
    echo "$context_message"
    echo
    
    # Launch Claude Code with context
    if ! claude --directory "$WORKTREE_PATH" --message "$context_message"; then
        error "Claude Code session failed or was interrupted"
        exit 1
    fi
    
    success "Claude Code session completed"
}

validate_implementation() {
    step "Validating implementation..."
    
    cd "$WORKTREE_PATH"
    
    # Check if there are any changes
    if git diff --quiet && git diff --cached --quiet; then
        warn "No changes detected in worktree"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Run quality checks if SwiftLint is available
    if command -v swiftlint &> /dev/null; then
        log "Running SwiftLint validation..."
        if ! swiftlint lint --fix; then
            warn "SwiftLint auto-fix applied changes"
        fi
        
        if ! swiftlint lint; then
            error "SwiftLint validation failed"
            return 1
        fi
        success "SwiftLint validation passed"
    fi
    
    # Build the project
    log "Building project..."
    if ! swift build; then
        error "Build failed"
        return 1
    fi
    success "Build successful"
    
    # Run tests
    log "Running tests..."
    if ! swift test; then
        error "Tests failed"
        return 1
    fi
    success "All tests passed"
    
    success "Implementation validation completed"
}

push_and_create_pr() {
    step "Creating pull request..."
    
    cd "$WORKTREE_PATH"
    
    # Check if branch has commits ahead of master
    local commits_ahead=$(git rev-list --count "master..HEAD" 2>/dev/null || echo "0")
    if [[ "$commits_ahead" -eq 0 ]]; then
        error "No commits to push. Branch is up to date with master."
        exit 1
    fi
    
    info "Branch has $commits_ahead commits ahead of master"
    
    # Push branch to origin
    log "Pushing branch to origin..."
    if ! git push origin "$BRANCH_NAME"; then
        error "Failed to push branch to origin"
        exit 1
    fi
    success "Branch pushed to origin"
    
    # Check if PR already exists
    local existing_pr=$(gh pr list --head "$BRANCH_NAME" --json number,url --jq '.[0] // empty')
    if [[ -n "$existing_pr" ]]; then
        local pr_number=$(echo "$existing_pr" | jq -r '.number')
        local pr_url=$(echo "$existing_pr" | jq -r '.url')
        success "Pull request already exists: #$pr_number - $pr_url"
        info "Monitoring existing PR checks..."
    else
        # Create PR
        local pr_title=$(jq -r '.pr_title' "$ISSUE_DATA_FILE")
        local issue_title=$(jq -r '.title' "$ISSUE_DATA_FILE")
        
        # Get commit messages for PR body
        local commit_messages=$(git log --oneline "master..HEAD" | head -10)
        
        # Create PR body
        local pr_body="## Summary
Resolves #${ISSUE_NUMBER}

This PR addresses: $issue_title

## Changes
\`\`\`
$commit_messages
\`\`\`

## Quality Checks
- [x] SwiftLint validation passes
- [x] All tests pass
- [x] Build succeeds
- [x] Follows project conventions

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"
        
        log "Creating pull request..."
        local pr_url
        if pr_url=$(gh pr create \
            --title "$pr_title" \
            --body "$pr_body" \
            --head "$BRANCH_NAME" \
            --base master); then
            success "Pull request created: $pr_url"
        else
            error "Failed to create pull request"
            exit 1
        fi
    fi
    
    # Monitor PR checks
    step "Monitoring CI checks..."
    info "Watching PR checks... (Press Ctrl+C to stop monitoring)"
    if ! gh pr checks --watch; then
        warn "PR checks monitoring interrupted or failed"
        info "You can resume monitoring with: gh pr checks --watch"
    else
        success "All PR checks passed!"
    fi
}

cleanup_worktree() {
    if [[ -n "$WORKTREE_PATH" && -d "$WORKTREE_PATH" ]]; then
        read -p "Remove worktree $WORKTREE_PATH? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "Removing worktree..."
            cd "$PROJECT_ROOT"
            git worktree remove "$WORKTREE_PATH" --force
            success "Worktree removed"
        fi
    fi
}

cleanup_all_worktrees() {
    step "Cleaning up all worktrees..."
    
    if [[ ! -d "$WORKTREE_BASE_DIR" ]]; then
        info "No worktrees directory found"
        return 0
    fi
    
    echo "This will remove ALL worktrees in $WORKTREE_BASE_DIR"
    read -p "Are you sure? Type 'yes' to confirm: " -r
    if [[ $REPLY == "yes" ]]; then
        cd "$PROJECT_ROOT"
        
        # Remove all worktrees
        for worktree_path in "$WORKTREE_BASE_DIR"/*; do
            if [[ -d "$worktree_path" ]]; then
                local worktree_name=$(basename "$worktree_path")
                log "Removing worktree: $worktree_name"
                git worktree remove "$worktree_path" --force || true
            fi
        done
        
        # Remove base directory
        rm -rf "$WORKTREE_BASE_DIR"
        success "All worktrees removed"
    else
        info "Cleanup cancelled"
    fi
}

main() {
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                     Claude Worktree                         ║${NC}"
    echo -e "${PURPLE}║               Parallel Claude Code Development               ║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    # Handle command line arguments
    case "${1:-}" in
        -h|--help)
            usage
            exit 0
            ;;
        --cleanup)
            cleanup_all_worktrees
            exit 0
            ;;
        "")
            error "Missing GitHub issue URL"
            usage
            exit 1
            ;;
        *)
            local issue_url="$1"
            ;;
    esac
    
    # Validate inputs
    validate_url "$issue_url"
    extract_issue_info "$issue_url"
    
    log "Starting Claude Worktree workflow"
    info "Issue URL: $issue_url"
    info "Worktree Path: $WORKTREE_PATH"
    info "Branch Name: $BRANCH_NAME"
    echo
    
    # Execute workflow
    validate_prerequisites
    create_worktree
    fetch_issue_data "$issue_url"
    generate_analysis
    launch_claude_code
    
    # Post-implementation workflow
    if validate_implementation; then
        push_and_create_pr
        success "Workflow completed successfully!"
        echo
        info "Next steps:"
        info "1. Monitor PR: gh pr view --web"
        info "2. Check CI: gh pr checks"
        info "3. Merge when ready: gh pr merge"
        echo
        cleanup_worktree
    else
        error "Implementation validation failed"
        info "Fix issues and rerun validation manually in: $WORKTREE_PATH"
        exit 1
    fi
}

main "$@"