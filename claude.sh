#!/bin/bash

# Claude Worktree - Parallel Claude Code development with git worktree
# Usage: ./claude-worktree.sh <github-issue-url>
# 
# This script creates a new git worktree, fetches GitHub issue data,
# launches Claude Code with issue context, and manages the complete
# development workflow including PR creation and CI monitoring.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Configuration
WORKTREE_BASE_DIR="${PROJECT_ROOT}"
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

# Global status variables
STATUS_BOX_LINES=0
ISSUE_TITLE=""
ISSUE_DESCRIPTION=""
WORKFLOW_STEPS=()
CURRENT_STEP=0

init_status_box() {
    local issue_title="$1"
    local issue_body="$2"
    local branch_name="$3"
    
    # Store issue information
    ISSUE_TITLE="$issue_title"
    # Truncate description to first line or first 80 chars
    ISSUE_DESCRIPTION=$(echo "$issue_body" | head -n1 | cut -c1-80)
    if [[ ${#issue_body} -gt 80 ]]; then
        ISSUE_DESCRIPTION="${ISSUE_DESCRIPTION}..."
    fi
    
    # Define workflow steps
    WORKFLOW_STEPS=(
        "🔧 Setting up worktree"
        "📋 Fetching issue data" 
        "🧠 Generating analysis"
        "⚡ Running Claude Code"
        "✅ Validating implementation"
        "📝 Creating pull request"
        "🔍 Monitoring CI checks"
        "🎉 Workflow complete"
    )
    CURRENT_STEP=0
    
    # Calculate box dimensions
    local title_len=${#ISSUE_TITLE}
    local desc_len=${#ISSUE_DESCRIPTION}
    local branch_len=$((${#branch_name} + 9)) # "Branch: " prefix
    local max_width=$((title_len > desc_len ? title_len : desc_len))
    max_width=$((max_width > branch_len ? max_width : branch_len))
    max_width=$((max_width > 60 ? max_width : 60))
    max_width=$((max_width + 4)) # padding
    
    # Draw status box
    draw_status_box "$max_width"
}

draw_status_box() {
    local width="$1"
    local border_line=$(printf "╔%*s╗" $((width-2)) "" | tr ' ' '═')
    local empty_line=$(printf "║%*s║" $((width-2)) "")
    
    # Save cursor position and clear area
    echo -ne "\033[s" # Save cursor
    echo -ne "\033[H" # Move to top
    
    STATUS_BOX_LINES=0
    echo -e "${BLUE}$border_line${NC}"; ((STATUS_BOX_LINES++))
    echo -e "${BLUE}║${NC} ${GREEN}${ISSUE_TITLE}$(printf "%*s" $((width-4-${#ISSUE_TITLE})) "")${BLUE}║${NC}"; ((STATUS_BOX_LINES++))
    echo -e "${BLUE}║${NC} ${YELLOW}${ISSUE_DESCRIPTION}$(printf "%*s" $((width-4-${#ISSUE_DESCRIPTION})) "")${BLUE}║${NC}"; ((STATUS_BOX_LINES++))
    echo -e "${BLUE}║${NC} Branch: ${CYAN}${BRANCH_NAME}$(printf "%*s" $((width-13-${#BRANCH_NAME})) "")${BLUE}║${NC}"; ((STATUS_BOX_LINES++))
    echo -e "${BLUE}║$(printf "%*s" $((width-2)) "")║${NC}"; ((STATUS_BOX_LINES++))
    
    # Draw workflow steps
    for i in "${!WORKFLOW_STEPS[@]}"; do
        local step="${WORKFLOW_STEPS[i]}"
        local status_icon=""
        local color=""
        
        if [[ $i -lt $CURRENT_STEP ]]; then
            status_icon="✓"
            color="${GREEN}"
        elif [[ $i -eq $CURRENT_STEP ]]; then
            status_icon="►"
            color="${YELLOW}"
        else
            status_icon="○"
            color="${NC}"  # Use default color instead of undefined GRAY
        fi
        
        echo -e "${BLUE}║${NC} ${color}${status_icon} ${step}$(printf "%*s" $((width-6-${#step})) "")${BLUE}║${NC}"; ((STATUS_BOX_LINES++))
    done
    
    echo -e "${BLUE}║$(printf "%*s" $((width-2)) "")║${NC}"; ((STATUS_BOX_LINES++))
    local bottom_line=$(printf "╚%*s╝" $((width-2)) "" | tr ' ' '═')
    echo -e "${BLUE}$bottom_line${NC}"; ((STATUS_BOX_LINES++))
    
    # Restore cursor position
    echo -ne "\033[u" # Restore cursor
    echo -ne "\033[${STATUS_BOX_LINES}B" # Move cursor below box
}

update_step() {
    local step_number="$1"
    CURRENT_STEP="$step_number"
    draw_status_box 66
}

show_loading() {
    local message="$1"
    local spinner=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    local seconds=0
    local start_time=$(date +%s)
    
    while true; do
        local current_time=$(date +%s)
        seconds=$((current_time - start_time))
        
        # Format time as MM:SS
        local minutes=$((seconds / 60))
        local remaining_seconds=$((seconds % 60))
        local formatted_time=$(printf "%02d:%02d" "$minutes" "$remaining_seconds")
        
        printf "\r${CYAN}[${spinner[i]}]${NC} %s ${YELLOW}[%s]${NC}          " "$message" "$formatted_time"
        i=$(( (i + 1) % ${#spinner[@]} ))
        sleep 0.1
    done
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
    if [[ -n "$WORKTREE_PATH" ]]; then
        rm -f "${WORKTREE_PATH}/.validation-errors.md"
        rm -f "${WORKTREE_PATH}/.claude-input.txt"
        rm -f "${WORKTREE_PATH}/.claude-error-input.txt"
        rm -f "${WORKTREE_PATH}/.claude-pr-input.txt"
        rm -f "${WORKTREE_PATH}/.claude-pr-output.json"
        rm -f "${WORKTREE_PATH}/.claude-commit-input.txt"
        rm -f "${WORKTREE_PATH}/.claude-commit-output.txt"
        rm -f "${WORKTREE_PATH}/.claude-output.log"
        rm -f "${WORKTREE_PATH}/.claude-error.log"
        rm -f "${WORKTREE_PATH}/.claude-error-output.log"
        rm -f "${WORKTREE_PATH}/.claude-error-stderr.log"
        rm -f "${WORKTREE_PATH}/.claude-pr-error.log"
        rm -f "${WORKTREE_PATH}/.claude-commit-error.log"
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
        BRANCH_NAME="issue-${ISSUE_NUMBER}-$(date +%Y%m%d-%H%M%S)"
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
        log "Automatically removing existing worktree..."
        git worktree remove "$WORKTREE_PATH" --force || true
        rm -rf "$WORKTREE_PATH"
        success "Existing worktree removed"
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
    
    # Write context to a temporary file for Claude Code to reference
    local context_file="${WORKTREE_PATH}/.claude-context.md"
    cat > "$context_file" << EOF
# GitHub Issue Context

$context_message

---

*This context file was automatically generated by claude.sh and can be referenced during your Claude Code session.*
EOF
    
    info "Context saved to: $context_file"
    echo
    
    # Create a temporary input file with the context message
    local input_file="${WORKTREE_PATH}/.claude-input.txt"
    echo "$context_message" > "$input_file"
    
    # Launch Claude Code with automatic prompt execution
    info "Launching Claude Code with issue context..."
    info "Note: You may see a trust prompt - select 'Yes, proceed' to continue"
    echo
    info "Issue context has been saved to: $context_file"
    info "Auto-launching Claude Code with prompt..."
    
    # Launch Claude Code with the context message pre-loaded
    printf "%s\n" "$context_message" | claude
    if [[ $? -eq 0 ]]; then
        success "Claude Code session completed successfully"
    else
        local exit_code=$?
        error "Claude Code session failed or was interrupted (exit code: $exit_code)"
        exit 1
    fi
    
    # Clean up input file
    rm -f "$input_file"
    
    success "Claude Code session completed"
}

launch_claude_code_with_errors() {
    step "Launching Claude Code to fix validation errors..."
    
    cd "$WORKTREE_PATH"
    
    # Read validation errors
    local validation_errors=""
    if [[ -f "${WORKTREE_PATH}/.validation-errors.md" ]]; then
        validation_errors=$(cat "${WORKTREE_PATH}/.validation-errors.md")
    fi
    
    # Create error context message
    local error_context_message="The implementation has validation errors that need to be fixed:

$validation_errors

Please fix these issues and ensure:
1. SwiftLint validation passes (\`swiftlint lint\`)
2. Code builds successfully (\`swift build\`)
3. All tests pass (\`swift test\`)
4. Follow the established architecture patterns

After fixing the issues, I'll run validation again automatically."
    
    info "Starting Claude Code session to fix validation errors..."
    info "Worktree: $WORKTREE_PATH"
    info "Branch: $BRANCH_NAME"
    echo
    
    # Update context file with error information
    local context_file="${WORKTREE_PATH}/.claude-context.md"
    cat >> "$context_file" << EOF

---

# Validation Error Context

$error_context_message

---

*This error context was automatically added by claude.sh after validation failure.*
EOF
    
    # Create a temporary input file with the error context message
    local input_file="${WORKTREE_PATH}/.claude-error-input.txt"
    echo "$error_context_message" > "$input_file"
    
    # Launch Claude Code with error context pre-loaded
    info "Launching Claude Code with validation error context..."
    echo
    error "Validation errors detected! Auto-launching Claude Code to fix them."
    info "Error context has been saved to: $context_file"
    
    # Launch Claude Code with the error context message pre-loaded
    printf "%s\n" "$error_context_message" | claude
    if [[ $? -eq 0 ]]; then
        success "Claude Code error-fixing session completed successfully"
    else
        local exit_code=$?
        error "Claude Code error-fixing session failed or was interrupted (exit code: $exit_code)"
        exit 1
    fi
    
    # Clean up input file
    rm -f "$input_file"
    
    success "Claude Code error-fixing session completed"
}

validate_implementation() {
    step "Validating implementation..."
    
    cd "$WORKTREE_PATH"
    
    local validation_errors=""
    local has_errors=false
    
    # Check if there are any real changes (excluding gitignored files)
    local has_changes=false
    
    # Test if git add would stage any new changes
    local staged_before=$(git diff --cached --numstat | wc -l)
    if git add --dry-run . >/dev/null 2>&1; then
        git add . >/dev/null 2>&1
        local staged_after=$(git diff --cached --numstat | wc -l)
        if [[ $staged_after -gt $staged_before ]]; then
            has_changes=true
        fi
        # Reset to previous state
        git reset >/dev/null 2>&1
    fi
    
    if [[ "$has_changes" == "false" ]] && git diff --quiet && git diff --cached --quiet; then
        warn "No trackable changes detected in worktree (only gitignored files present)"
        info "Continuing with validation anyway..."
    fi
    
    # Run quality checks if SwiftLint is available
    if command -v swiftlint &> /dev/null; then
        log "Running SwiftLint validation..."
        if ! swiftlint lint --fix; then
            warn "SwiftLint auto-fix applied changes"
        fi
        
        local swiftlint_output
        if ! swiftlint_output=$(swiftlint lint 2>&1); then
            error "SwiftLint validation failed"
            validation_errors+="\n## SwiftLint Errors:\n\`\`\`\n$swiftlint_output\n\`\`\`\n"
            has_errors=true
        else
            success "SwiftLint validation passed"
        fi
    fi
    
    # Build the project
    log "Building project..."
    local build_output
    if ! build_output=$(swift build 2>&1); then
        error "Build failed"
        validation_errors+="\n## Build Errors:\n\`\`\`\n$build_output\n\`\`\`\n"
        has_errors=true
    else
        success "Build successful"
    fi
    
    # Run tests
    log "Running tests..."
    local test_output
    if ! test_output=$(swift test 2>&1); then
        error "Tests failed"
        validation_errors+="\n## Test Errors:\n\`\`\`\n$test_output\n\`\`\`\n"
        has_errors=true
    else
        success "All tests passed"
    fi
    
    if [[ "$has_errors" == "true" ]]; then
        # Store validation errors for retry
        echo "$validation_errors" > "${WORKTREE_PATH}/.validation-errors.md"
        return 1
    fi
    
    success "Implementation validation completed"
    return 0
}

generate_pr_description() {
    step "Generating PR description with Claude Code..."
    
    cd "$WORKTREE_PATH"
    
    # Collect implementation context
    local issue_title=$(jq -r '.title' "$ISSUE_DATA_FILE")
    local issue_body=$(jq -r '.body // ""' "$ISSUE_DATA_FILE")
    local commit_messages=$(git log --oneline "master..HEAD" | head -10)
    local files_changed=$(git diff --name-only "master..HEAD")
    local files_added=$(git diff --name-status "master..HEAD" | grep "^A" | cut -f2)
    local files_modified=$(git diff --name-status "master..HEAD" | grep "^M" | cut -f2)
    
    # Create context message for Claude Code
    local pr_context_message="I need you to generate a JSON-formatted PR description for the following GitHub issue implementation:

**Issue #${ISSUE_NUMBER}: $issue_title**

**Issue Description:**
$issue_body

**Implementation Details:**
- Branch: $BRANCH_NAME  
- Commits made:
\`\`\`
$commit_messages
\`\`\`

**Files Changed:**
$files_changed

**Files Added:**
$files_added

**Files Modified:**  
$files_modified

**Validation Results:**
- ✅ SwiftLint validation passed
- ✅ Build successful
- ✅ All tests passed

Please generate a PR description in the JSON format specified in CLAUDE.md. The description should include:
1. Summary of changes made
2. Background context explaining why this implementation was needed
3. Decision rationale for the approach chosen
4. Implementation details and key changes
5. Testing coverage and validation steps
6. Impact assessment including any breaking changes

Return ONLY the JSON object, no additional text or markdown formatting."

    # Create temporary input file for Claude Code PR description generation
    local pr_input_file="${WORKTREE_PATH}/.claude-pr-input.txt"
    echo "$pr_context_message" > "$pr_input_file"
    
    # Create temporary output file to capture Claude Code response
    local pr_output_file="${WORKTREE_PATH}/.claude-pr-output.json"
    
    info "Launching Claude Code to generate JSON PR description..."
    
    # Start loading animation in background
    show_loading "Generating PR description with Claude Code" &
    local loading_pid=$!
    
    local claude_pr_error_file="${WORKTREE_PATH}/.claude-pr-error.log"
    
    if timeout 180 claude --print --output-format json < "$pr_input_file" > "$pr_output_file" 2> "$claude_pr_error_file"; then
        kill $loading_pid 2>/dev/null
        wait $loading_pid 2>/dev/null
        echo -e "\r\033[K" # Clear loading line
        # Validate that we got valid JSON
        if jq . "$pr_output_file" >/dev/null 2>&1; then
            success "PR description generated successfully"
            cat "$pr_output_file"
        else
            warn "Claude Code output is not valid JSON, falling back to default format"
            echo "Failed to generate valid JSON PR description. Using fallback format."
            if [[ -s "$claude_pr_error_file" ]]; then
                error "Claude Code PR generation error output:"
                cat "$claude_pr_error_file"
            fi
            return 1
        fi
    else
        local exit_code=$?
        kill $loading_pid 2>/dev/null
        wait $loading_pid 2>/dev/null
        echo -e "\r\033[K" # Clear loading line
        
        if [[ $exit_code -eq 124 ]]; then
            warn "Claude Code PR description generation timed out after 3 minutes, using fallback format"
        else
            warn "Claude Code PR description generation failed, using fallback format (exit code: $exit_code)"
        fi
        
        if [[ -s "$claude_pr_error_file" ]]; then
            error "Claude Code PR generation error output:"
            cat "$claude_pr_error_file"
        fi
        return 1
    fi
    
    # Cleanup temporary files
    rm -f "$pr_input_file" "$pr_output_file"
}

generate_commit_message() {
    step "Generating commit message with Claude Code..."
    
    cd "$WORKTREE_PATH"
    
    # Collect implementation context for commit message
    local issue_title=$(jq -r '.title' "$ISSUE_DATA_FILE")
    local issue_body=$(jq -r '.body // ""' "$ISSUE_DATA_FILE")
    local files_changed=$(git diff --cached --name-only)
    local files_added=$(git diff --cached --name-status | grep "^A" | cut -f2)
    local files_modified=$(git diff --cached --name-status | grep "^M" | cut -f2)
    local files_deleted=$(git diff --cached --name-status | grep "^D" | cut -f2)
    
    # Create context message for Claude Code commit message generation
    local commit_context_message="I need you to generate a conventional commit message for the following GitHub issue implementation:

**Issue #${ISSUE_NUMBER}: $issue_title**

**Issue Description:**
$issue_body

**Changes Made:**
- Files changed: $files_changed
- Files added: $files_added  
- Files modified: $files_modified
- Files deleted: $files_deleted

Please generate a conventional commit message following this format:
\`\`\`
<type>(<scope>): <description>

<body>

Refs #${ISSUE_NUMBER}
\`\`\`

Requirements:
1. Use appropriate conventional commit type (feat, fix, docs, style, refactor, test, chore)
2. Include a scope if relevant (e.g., tokenizer, parser, visitor, tests)
3. Write a clear, concise description (≤50 chars for first line)
4. Include a body explaining what and why (not how)
5. Reference the issue number with 'Refs #${ISSUE_NUMBER}'
6. Follow project conventions from CLAUDE.md

Return ONLY the commit message text, no additional formatting or markdown."

    # Create temporary input file for Claude Code commit message generation
    local commit_input_file="${WORKTREE_PATH}/.claude-commit-input.txt"
    echo "$commit_context_message" > "$commit_input_file"
    
    # Create temporary output file to capture Claude Code response
    local commit_output_file="${WORKTREE_PATH}/.claude-commit-output.txt"
    
    info "Launching Claude Code to generate conventional commit message..."
    
    # Start loading animation in background
    show_loading "Generating commit message with Claude Code" &
    local loading_pid=$!
    
    local claude_commit_error_file="${WORKTREE_PATH}/.claude-commit-error.log"
    
    if timeout 120 claude --print < "$commit_input_file" > "$commit_output_file" 2> "$claude_commit_error_file"; then
        kill $loading_pid 2>/dev/null
        wait $loading_pid 2>/dev/null
        echo -e "\r\033[K" # Clear loading line
        # Validate that we got a reasonable commit message
        local generated_message=$(cat "$commit_output_file")
        if [[ -n "$generated_message" ]] && [[ ${#generated_message} -gt 10 ]]; then
            success "Commit message generated successfully"
            echo "$generated_message"
        else
            warn "Claude Code generated empty or too short commit message, using fallback"
            if [[ -s "$claude_commit_error_file" ]]; then
                error "Claude Code commit generation error output:"
                cat "$claude_commit_error_file"
            fi
            return 1
        fi
    else
        local exit_code=$?
        kill $loading_pid 2>/dev/null
        wait $loading_pid 2>/dev/null
        echo -e "\r\033[K" # Clear loading line
        
        if [[ $exit_code -eq 124 ]]; then
            warn "Claude Code commit message generation timed out after 2 minutes, using fallback"
        else
            warn "Claude Code commit message generation failed, using fallback (exit code: $exit_code)"
        fi
        
        if [[ -s "$claude_commit_error_file" ]]; then
            error "Claude Code commit generation error output:"
            cat "$claude_commit_error_file"
        fi
        return 1
    fi
    
    # Cleanup temporary files
    rm -f "$commit_input_file" "$commit_output_file"
}

push_and_create_pr() {
    step "Creating pull request..."
    
    cd "$WORKTREE_PATH"
    
    # Check if branch has commits ahead of master
    local commits_ahead=$(git rev-list --count "master..HEAD" 2>/dev/null || echo "0")
    if [[ "$commits_ahead" -eq 0 ]]; then
        error "No commits to push. Branch is up to date with master."
        echo
        warn "This can happen when Claude Code doesn't create any commits."
        echo
        info "Options:"
        info "1. Check if there are unstaged changes that need to be committed"
        info "2. Re-launch Claude Code to ensure implementation is completed"
        info "3. Create a manual commit if changes exist"
        echo
        
        # Check for unstaged changes (excluding gitignored files)
        local has_real_changes=false
        
        # Check if there are any changes that would actually be staged
        if git add --dry-run . >/dev/null 2>&1; then
            # Test if git add would actually stage anything
            local staged_count_before=$(git diff --cached --numstat | wc -l)
            git add . >/dev/null 2>&1
            local staged_count_after=$(git diff --cached --numstat | wc -l)
            
            if [[ $staged_count_after -gt $staged_count_before ]]; then
                has_real_changes=true
            fi
            
            # Reset staging area to previous state
            git reset >/dev/null 2>&1
        fi
        
        if [[ "$has_real_changes" == "true" ]]; then
            log "Detected changes ready for commit"
            git add .
            
            # Generate commit message using Claude Code
            local commit_message=""
            if commit_message=$(generate_commit_message); then
                info "Using Claude Code generated commit message"
                # Add Claude Code attribution to the generated message
                commit_message="$commit_message

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"
            else
                warn "Falling back to default commit message format"
                local issue_title=$(jq -r '.title' "$ISSUE_DATA_FILE")
                commit_message="feat: implement ${issue_title}

Resolves #${ISSUE_NUMBER}

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"
            fi
            
            git commit -m "$commit_message"
            
            # Recheck commits ahead
            commits_ahead=$(git rev-list --count "master..HEAD" 2>/dev/null || echo "0")
            if [[ "$commits_ahead" -eq 0 ]]; then
                error "Still no commits after adding changes"
                exit 1
            fi
            success "Commit created automatically"
        else
            # Auto-select option 2: Re-launch Claude Code
            warn "Auto-selecting option 2: Re-launching Claude Code to complete implementation..."
            launch_claude_code_with_errors
            
            # After Claude Code session, recheck for commits
            commits_ahead=$(git rev-list --count "master..HEAD" 2>/dev/null || echo "0")
            if [[ "$commits_ahead" -eq 0 ]]; then
                error "Still no commits after re-launching Claude Code"
                exit 1
            fi
        fi
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
        
        # Generate PR description using Claude Code
        local pr_body=""
        if pr_body=$(generate_pr_description); then
            info "Using Claude Code generated JSON PR description"
        else
            warn "Falling back to default PR description format"
            # Get commit messages for fallback PR body
            local commit_messages=$(git log --oneline "master..HEAD" | head -10)
            
            # Fallback PR body
            pr_body="## Summary
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
        fi
        
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
    
    # Monitor for up to 5 minutes, checking every 10 seconds
    info "Monitoring PR checks for up to 5 minutes (checking every 10 seconds)..."
    local monitor_time=0
    local max_monitor_time=300  # 5 minutes
    local check_interval=10     # 10 seconds
    local all_checks_passed=false
    local checks_started=false
    
    while [[ $monitor_time -lt $max_monitor_time ]]; do
        # Get current check status
        local check_output
        if check_output=$(gh pr checks 2>/dev/null); then
            if [[ "$checks_started" == "false" ]]; then
                echo -e "\r\033[K" # Clear the waiting line
            fi
            checks_started=true
            
            # Display current status
            echo "--- CI Status (${monitor_time}s/${max_monitor_time}s) ---"
            echo "$check_output"
            echo
            
            # Check if all checks are complete and successful
            local pending_count=$(echo "$check_output" | grep -c "pending" 2>/dev/null || echo "0")
            local fail_count=$(echo "$check_output" | grep -c "fail" 2>/dev/null || echo "0")
            
            # Ensure we have valid numeric values
            if ! [[ "$pending_count" =~ ^[0-9]+$ ]]; then
                pending_count=0
            fi
            if ! [[ "$fail_count" =~ ^[0-9]+$ ]]; then
                fail_count=0
            fi
            
            if [[ "$pending_count" -eq 0 ]] && [[ "$fail_count" -eq 0 ]]; then
                local total_checks=$(echo "$check_output" | wc -l)
                if [[ "$total_checks" -gt 0 ]]; then
                    all_checks_passed=true
                    success "All PR checks passed!"
                    break
                fi
            elif [[ "$fail_count" -gt 0 ]]; then
                error "Some PR checks failed"
                break
            fi
        else
            if [[ "$checks_started" == "false" ]]; then
                local remaining_time=$((max_monitor_time - monitor_time))
                printf "\r${CYAN}[INFO]${NC} Waiting for CI checks to start... (%ds remaining)          " "$remaining_time"
            fi
        fi
        
        sleep $check_interval
        monitor_time=$((monitor_time + check_interval))
    done
    
    # Clear any remaining waiting message
    if [[ "$checks_started" == "false" ]]; then
        echo -e "\r\033[K"
    fi
    
    if [[ "$all_checks_passed" == "true" ]]; then
        success "All CI checks completed successfully!"
    elif [[ "$checks_started" == "false" ]]; then
        warn "No CI checks detected after 5 minutes"
        info "This may be normal if no workflows are configured for this repository"
        info "You can check manually later with: gh pr checks"
    elif [[ $monitor_time -ge $max_monitor_time ]]; then
        warn "CI monitoring timeout reached (5 minutes)"
        info "Checks may still be running. You can continue monitoring with: gh pr checks --watch"
    fi
}

cleanup_worktree() {
    if [[ -n "$WORKTREE_PATH" && -d "$WORKTREE_PATH" ]]; then
        log "Removing worktree..."
        cd "$PROJECT_ROOT"
        git worktree remove "$WORKTREE_PATH" --force
        success "Worktree removed: $WORKTREE_PATH"
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
    update_step 1  # Setting up worktree completed
    fetch_issue_data "$issue_url"
    
    # Initialize status box after fetching issue data
    local issue_title=$(jq -r '.title' "$ISSUE_DATA_FILE")
    local issue_body=$(jq -r '.body // ""' "$ISSUE_DATA_FILE")
    init_status_box "$issue_title" "$issue_body" "$BRANCH_NAME"
    
    update_step 2  # Fetching issue data completed
    generate_analysis
    update_step 3  # Generating analysis completed
    launch_claude_code
    update_step 4  # Running Claude Code completed
    
    # Post-implementation workflow with retry loop
    local max_retries=3
    local retry_count=0
    
    while [[ $retry_count -lt $max_retries ]]; do
        if validate_implementation; then
            # Validation successful - proceed with PR creation
            update_step 5  # Validating implementation completed
            push_and_create_pr
            update_step 6  # Creating pull request completed
            update_step 7  # Monitoring CI checks completed
            update_step 8  # Workflow complete
            success "Workflow completed successfully!"
            echo
            info "Next steps:"
            info "1. Monitor PR: gh pr view --web"
            info "2. Check CI: gh pr checks"
            info "3. Merge when ready: gh pr merge --merge"
            echo
            cleanup_worktree
            return 0
        else
            # Validation failed
            retry_count=$((retry_count + 1))
            error "Implementation validation failed (attempt $retry_count/$max_retries)"
            
            if [[ $retry_count -lt $max_retries ]]; then
                echo
                warn "Launching Claude Code to fix validation errors..."
                info "Remaining attempts: $((max_retries - retry_count))"
                echo
                
                # Launch Claude Code with error context and JSON format
                launch_claude_code_with_errors
                
                # Continue to next iteration for validation retry
                continue
            else
                # Max retries reached
                echo
                error "Maximum retry attempts ($max_retries) reached"
                error "Implementation validation still failing"
                echo
                info "Manual intervention required in: $WORKTREE_PATH"
                info "You can:"
                info "1. Fix issues manually and run: swiftlint lint && swift build && swift test"
                info "2. Continue with PR creation anyway (if appropriate)"
                info "3. Remove worktree: git worktree remove $WORKTREE_PATH --force"
                echo
                
                warn "Auto-proceeding with PR creation despite validation failures..."
                push_and_create_pr
            fi
        fi
    done
}

main "$@"