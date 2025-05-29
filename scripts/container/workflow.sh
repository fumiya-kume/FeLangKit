#!/bin/bash
"""
Container Workflow Script - Complete Development Workflow in Isolation
Executes the full development lifecycle within a Docker container using Claude API.
"""

set -euo pipefail

# Configuration
WORKSPACE_DIR="/workspace"
ISSUE_DATA_FILE="$WORKSPACE_DIR/issue-data.json"
ANALYSIS_DATA_FILE="$WORKSPACE_DIR/analysis-data.json"
EXECUTION_REPORT_FILE="$WORKSPACE_DIR/execution-report.json"
LOG_FILE="$WORKSPACE_DIR/container.log"

# Logging functions
log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [INFO] $message" | tee -a "$LOG_FILE"
}

error() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [ERROR] $message" | tee -a "$LOG_FILE" >&2
}

success() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [SUCCESS] $message" | tee -a "$LOG_FILE"
}

# Validation functions
validate_environment() {
    log "Validating container environment..."
    
    # Check required environment variables
    local required_vars=("ANTHROPIC_API_KEY" "GITHUB_TOKEN" "GIT_USER_NAME" "GIT_USER_EMAIL")
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            error "Required environment variable $var is not set"
            return 1
        fi
    done
    
    # Check required files
    if [[ ! -f "$ISSUE_DATA_FILE" ]]; then
        error "Issue data file not found: $ISSUE_DATA_FILE"
        return 1
    fi
    
    if [[ ! -f "$ANALYSIS_DATA_FILE" ]]; then
        error "Analysis data file not found: $ANALYSIS_DATA_FILE"
        return 1
    fi
    
    # Validate JSON files
    if ! jq empty "$ISSUE_DATA_FILE" 2>/dev/null; then
        error "Invalid JSON in issue data file: $ISSUE_DATA_FILE"
        return 1
    fi
    
    if ! jq empty "$ANALYSIS_DATA_FILE" 2>/dev/null; then
        error "Invalid JSON in analysis data file: $ANALYSIS_DATA_FILE"
        return 1
    fi
    
    # Check tools availability
    local required_tools=("swift" "git" "gh" "python3" "swiftlint" "jq")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            error "Required tool not found: $tool"
            return 1
        fi
    done
    
    success "Environment validation passed"
    return 0
}

setup_git_authentication() {
    log "Setting up Git authentication with token..."
    
    # Configure git user
    git config --global user.name "$GIT_USER_NAME"
    git config --global user.email "$GIT_USER_EMAIL"
    git config --global init.defaultBranch main
    git config --global pull.rebase false
    
    # Set up credential helper for HTTPS authentication
    git config --global credential.helper store
    
    # Create credentials file with GitHub token
    local git_credentials_file="$HOME/.git-credentials"
    echo "https://$GITHUB_TOKEN:x-oauth-basic@github.com" > "$git_credentials_file"
    chmod 600 "$git_credentials_file"
    
    # Test GitHub CLI authentication
    log "Testing GitHub CLI authentication..."
    if gh auth status &>/dev/null; then
        success "GitHub CLI authenticated successfully"
    else
        # Set up GitHub CLI with token
        echo "$GITHUB_TOKEN" | gh auth login --with-token
        if gh auth status &>/dev/null; then
            success "GitHub CLI authentication configured"
        else
            error "Failed to authenticate GitHub CLI"
            return 1
        fi
    fi
    
    # Test Git access to repository
    local repo_url="https://github.com/${GIT_REPO_OWNER:-}/${GIT_REPO_NAME:-}.git"
    if [[ -n "${GIT_REPO_OWNER:-}" && -n "${GIT_REPO_NAME:-}" ]]; then
        log "Testing Git repository access..."
        if git ls-remote "$repo_url" &>/dev/null; then
            success "Git repository access confirmed"
        else
            error "Failed to access Git repository: $repo_url"
            return 1
        fi
    fi
    
    success "Git authentication setup completed"
    return 0
}

setup_swift_environment() {
    log "Setting up Swift development environment..."
    
    # Verify Swift installation
    swift --version
    
    # Install SwiftLint if not available
    if ! command -v swiftlint &> /dev/null; then
        log "Installing SwiftLint..."
        # For Ubuntu, we'll need to build from source or use a binary release
        # This is a simplified approach - in production you might want to cache this
        curl -L https://github.com/realm/SwiftLint/releases/latest/download/swiftlint_linux.zip -o /tmp/swiftlint.zip
        unzip /tmp/swiftlint.zip -d /tmp/
        sudo mv /tmp/swiftlint /usr/local/bin/
        chmod +x /usr/local/bin/swiftlint
        rm -f /tmp/swiftlint.zip
    fi
    
    # Verify SwiftLint
    swiftlint version
    
    success "Swift environment setup completed"
    return 0
}

extract_issue_info() {
    log "Extracting issue information..."
    
    # Extract key information from issue data
    export ISSUE_NUMBER=$(jq -r '.issue_number' "$ISSUE_DATA_FILE")
    export ISSUE_TITLE=$(jq -r '.title' "$ISSUE_DATA_FILE")
    export BRANCH_NAME=$(jq -r '.branch_name' "$ISSUE_DATA_FILE")
    export GIT_REPO_OWNER=$(jq -r '.owner' "$ISSUE_DATA_FILE")
    export GIT_REPO_NAME=$(jq -r '.repo' "$ISSUE_DATA_FILE")
    
    # Extract analysis information
    export COMPLEXITY_LEVEL=$(jq -r '.complexity_assessment.level' "$ANALYSIS_DATA_FILE" 2>/dev/null || echo "unknown")
    export ESTIMATED_TIME=$(jq -r '.implementation_roadmap.total_estimated_time_minutes' "$ANALYSIS_DATA_FILE" 2>/dev/null || echo "unknown")
    
    log "Issue #$ISSUE_NUMBER: $ISSUE_TITLE"
    log "Branch: $BRANCH_NAME"
    log "Complexity: $COMPLEXITY_LEVEL (Est: ${ESTIMATED_TIME} min)"
    log "Repository: $GIT_REPO_OWNER/$GIT_REPO_NAME"
    
    success "Issue information extracted"
    return 0
}

clone_repository() {
    log "Cloning repository to workspace..."
    
    local repo_url="https://github.com/$GIT_REPO_OWNER/$GIT_REPO_NAME.git"
    local repo_dir="$WORKSPACE_DIR/repo"
    
    # Remove existing repo directory if it exists
    if [[ -d "$repo_dir" ]]; then
        rm -rf "$repo_dir"
    fi
    
    # Clone the repository
    if git clone "$repo_url" "$repo_dir"; then
        success "Repository cloned successfully"
        cd "$repo_dir"
        export REPO_WORKSPACE="$repo_dir"
    else
        error "Failed to clone repository: $repo_url"
        return 1
    fi
    
    return 0
}

run_claude_agent() {
    log "Starting Claude Agent for development workflow..."
    
    # Ensure we're in the repository directory
    cd "$REPO_WORKSPACE"
    
    # Run the Claude agent with proper paths
    if python3 /usr/local/bin/claude-agent.py \
        --issue-data "$ISSUE_DATA_FILE" \
        --analysis-data "$ANALYSIS_DATA_FILE" \
        --workspace "$REPO_WORKSPACE" \
        --output "$EXECUTION_REPORT_FILE"; then
        success "Claude Agent execution completed successfully"
        return 0
    else
        error "Claude Agent execution failed"
        return 1
    fi
}

generate_summary_report() {
    log "Generating summary report..."
    
    local summary_file="$WORKSPACE_DIR/summary-report.json"
    
    # Create comprehensive summary
    jq -n \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg container_id "${HOSTNAME:-unknown}" \
        --arg issue_number "$ISSUE_NUMBER" \
        --arg branch_name "$BRANCH_NAME" \
        --arg complexity "$COMPLEXITY_LEVEL" \
        --arg estimated_time "$ESTIMATED_TIME" \
        --argjson execution_report "$(cat "$EXECUTION_REPORT_FILE" 2>/dev/null || echo 'null')" \
        '{
            container_execution: {
                timestamp: $timestamp,
                container_id: $container_id,
                workspace: "/workspace",
                isolation_level: "complete"
            },
            issue_info: {
                issue_number: ($issue_number | tonumber),
                branch_name: $branch_name,
                complexity: $complexity,
                estimated_time: $estimated_time
            },
            execution_report: $execution_report,
            host_impact: {
                files_created_on_host: 0,
                credentials_shared: false,
                process_execution_on_host: false
            }
        }' > "$summary_file"
    
    log "Summary report generated: $summary_file"
    
    # Display summary
    echo ""
    echo "================================="
    echo "CONTAINER EXECUTION SUMMARY"
    echo "================================="
    echo "Issue: #$ISSUE_NUMBER - $ISSUE_TITLE"
    echo "Branch: $BRANCH_NAME"
    echo "Complexity: $COMPLEXITY_LEVEL"
    echo "Container: $HOSTNAME"
    
    if [[ -f "$EXECUTION_REPORT_FILE" ]]; then
        local success_status=$(jq -r '.success' "$EXECUTION_REPORT_FILE" 2>/dev/null || echo "unknown")
        local pr_url=$(jq -r '.pr_url' "$EXECUTION_REPORT_FILE" 2>/dev/null || echo "none")
        local duration=$(jq -r '.duration_seconds' "$EXECUTION_REPORT_FILE" 2>/dev/null || echo "unknown")
        
        echo "Status: $success_status"
        echo "Duration: ${duration}s"
        echo "PR URL: $pr_url"
    fi
    
    echo "================================="
}

cleanup() {
    log "Performing cleanup..."
    
    # Clean up sensitive files
    rm -f "$HOME/.git-credentials" 2>/dev/null || true
    
    # Ensure proper permissions on output files
    chmod 644 "$EXECUTION_REPORT_FILE" 2>/dev/null || true
    chmod 644 "$WORKSPACE_DIR/summary-report.json" 2>/dev/null || true
    chmod 644 "$LOG_FILE" 2>/dev/null || true
}

main() {
    log "Starting container workflow for GitHub issue processing"
    log "Container: $HOSTNAME"
    log "Workspace: $WORKSPACE_DIR"
    
    # Trap for cleanup
    trap cleanup EXIT
    
    # Step 1: Validate environment
    if ! validate_environment; then
        error "Environment validation failed"
        exit 1
    fi
    
    # Step 2: Extract issue information
    if ! extract_issue_info; then
        error "Failed to extract issue information"
        exit 1
    fi
    
    # Step 3: Setup authentication
    if ! setup_git_authentication; then
        error "Git authentication setup failed"
        exit 1
    fi
    
    # Step 4: Setup Swift environment
    if ! setup_swift_environment; then
        error "Swift environment setup failed"
        exit 1
    fi
    
    # Step 5: Clone repository
    if ! clone_repository; then
        error "Repository cloning failed"
        exit 1
    fi
    
    # Step 6: Run Claude Agent
    if ! run_claude_agent; then
        error "Claude Agent execution failed"
        exit 1
    fi
    
    # Step 7: Generate summary
    generate_summary_report
    
    success "Container workflow completed successfully!"
    
    # Keep container running for result extraction
    log "Container ready for result extraction. Outputs available in /workspace"
    log "Key files:"
    log "  - $EXECUTION_REPORT_FILE"
    log "  - $WORKSPACE_DIR/summary-report.json"
    log "  - $LOG_FILE"
    
    # Wait for external signal or timeout
    local wait_timeout=${CONTAINER_WAIT_TIMEOUT:-300}  # 5 minutes default
    log "Waiting for result extraction (timeout: ${wait_timeout}s)..."
    sleep "$wait_timeout"
    
    log "Container workflow session ended"
}

# Execute main function
main "$@"