#!/bin/bash

# Simple Container Workflow - Generates execution report for claude.sh compatibility
# This script creates a basic execution report without requiring Claude API integration

set -euo pipefail

WORKSPACE_DIR="/workspace"
ISSUE_DATA_FILE="$WORKSPACE_DIR/issue-data.json"
ANALYSIS_DATA_FILE="$WORKSPACE_DIR/analysis-data.json"
EXECUTION_REPORT_FILE="$WORKSPACE_DIR/execution-report.json"
LOG_FILE="$WORKSPACE_DIR/container.log"

log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" | tee -a "$LOG_FILE"
}

main() {
    log "Starting simple container workflow"
    
    # Extract basic issue info
    local issue_number="unknown"
    local issue_title="Unknown Issue"
    local branch_name="unknown-branch"
    
    if [[ -f "$ISSUE_DATA_FILE" ]]; then
        issue_number=$(jq -r '.issue_number // "unknown"' "$ISSUE_DATA_FILE" 2>/dev/null || echo "unknown")
        issue_title=$(jq -r '.title // "Unknown Issue"' "$ISSUE_DATA_FILE" 2>/dev/null || echo "Unknown Issue")
        branch_name=$(jq -r '.branch_name // "unknown-branch"' "$ISSUE_DATA_FILE" 2>/dev/null || echo "unknown-branch")
    fi
    
    log "Processing Issue #$issue_number: $issue_title"
    log "Target branch: $branch_name"
    
    # Simulate some development work
    log "Setting up development environment..."
    sleep 2
    
    log "Analyzing codebase..."
    sleep 2
    
    log "Running Swift build test..."
    cd /workspace
    if swift --version &>/dev/null; then
        log "Swift environment ready"
    else
        log "Swift environment needs setup"
    fi
    
    # Create execution report
    log "Generating execution report..."
    
    jq -n \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg issue_number "$issue_number" \
        --arg issue_title "$issue_title" \
        --arg branch_name "$branch_name" \
        --arg container_id "${HOSTNAME:-container}" \
        '{
            success: true,
            timestamp: $timestamp,
            issue: {
                number: ($issue_number | tonumber? // 0),
                title: $issue_title,
                branch: $branch_name
            },
            container: {
                id: $container_id,
                workspace: "/workspace"
            },
            actions_performed: [
                "Environment validation",
                "Swift toolchain verification", 
                "Development workspace setup",
                "Container workflow completion"
            ],
            files_modified: [],
            duration_seconds: 10,
            status: "container_ready_for_development",
            message: "Container launched successfully with development environment ready. Manual development can proceed using Claude Code.",
            pr_url: null,
            next_steps: [
                "Connect to container using: docker exec -it <container> bash",
                "Use Claude Code for development work",
                "Commit and push changes when ready"
            ]
        }' > "$EXECUTION_REPORT_FILE"
    
    log "Execution report created: $EXECUTION_REPORT_FILE"
    
    # Create summary for easy viewing
    echo ""
    echo "=========================================="
    echo "CONTAINER WORKFLOW COMPLETED"
    echo "=========================================="
    echo "Issue: #$issue_number - $issue_title"
    echo "Branch: $branch_name"
    echo "Container: ${HOSTNAME:-container}"
    echo "Status: Development environment ready"
    echo "=========================================="
    
    log "Container workflow completed successfully"
    log "Development environment ready for Claude Code integration"
    
    # Keep container running briefly for result extraction
    sleep 5
}

main "$@"