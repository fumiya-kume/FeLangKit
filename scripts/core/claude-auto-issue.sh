#!/bin/bash

# Claude Auto Issue - Automated GitHub Issue Processing with Claude Code
# Usage: ./claude-auto-issue.sh <github-issue-url>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration
CONFIG_FILE="${SCRIPT_DIR}/../config/claude-auto-config.json"
ISSUE_DATA_FILE="${SCRIPT_DIR}/.issue-data.json"
CONTAINER_NAME="claude-auto-${RANDOM}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

cleanup() {
    log "Cleaning up..."
    if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
        docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
        docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || true
    fi
    rm -f "$ISSUE_DATA_FILE"
    rm -f "${SCRIPT_DIR}/.analysis-"*.json 2>/dev/null || true
}

trap cleanup EXIT

usage() {
    cat << EOF
Usage: $0 <github-issue-url>

Automatically processes a GitHub issue using Claude Code in a Docker container.

Examples:
  $0 https://github.com/owner/repo/issues/123
  $0 https://github.com/fumiya-kume/FeLangKit/issues/87

Options:
  -h, --help    Show this help message
  -c, --config  Specify custom config file (default: claude-auto-config.json)
  --dry-run     Show what would be done without executing
EOF
}

validate_url() {
    local url="$1"
    if [[ ! "$url" =~ ^https://github\.com/[^/]+/[^/]+/issues/[0-9]+$ ]]; then
        error "Invalid GitHub issue URL format. Expected: https://github.com/owner/repo/issues/123"
        exit 1
    fi
}

main() {
    if [[ $# -lt 1 ]]; then
        usage
        exit 1
    fi

    local issue_url="$1"
    
    case "$issue_url" in
        -h|--help)
            usage
            exit 0
            ;;
        *)
            validate_url "$issue_url"
            ;;
    esac

    log "Starting Claude Auto Issue processing"
    log "Issue URL: $issue_url"
    log "Project Root: $PROJECT_ROOT"

    # Step 1: Fetch issue data (with single retry)
    log "Fetching issue data..."
    if ! retry_data_fetch "$issue_url" "$ISSUE_DATA_FILE"; then
        error "Failed to fetch issue data after retry"
        exit 1
    fi

    # Step 2: Ultra Think Analysis (with single retry)
    ANALYSIS_FILE="${SCRIPT_DIR}/../.analysis-$(basename "$ISSUE_DATA_FILE" .json).json"
    log "Running Ultra Think Analysis..."
    log "Analysis will be saved to: $ANALYSIS_FILE"
    if ! retry_analysis_generation "$ISSUE_DATA_FILE" "$ANALYSIS_FILE"; then
        error "Failed to complete Ultra Think Analysis after retry"
        exit 1
    fi
    log "Ultra Think Analysis file verified: $(du -h "$ANALYSIS_FILE" | cut -f1)"

    # Step 3: Launch Claude Code in Hybrid Container
    log "Launching Claude Code in hybrid isolation container..."
    if ! "$SCRIPT_DIR/../container/launch.sh" hybrid "$ISSUE_DATA_FILE" "$ANALYSIS_FILE" "$CONTAINER_NAME"; then
        error "Failed to launch Claude Code in hybrid container"
        exit 1
    fi

    # Step 4: Extract results and create PR
    log "Extracting results from container..."
    if ! "$SCRIPT_DIR/../container/extract-results.sh" "$CONTAINER_NAME" "$PROJECT_ROOT/container-results"; then
        error "Failed to extract container results"
        exit 1
    fi

    # Step 5: Create PR from container results
    log "Creating PR from container results..."
    if ! "$SCRIPT_DIR/create-pr.sh" "$ISSUE_DATA_FILE" "$CONTAINER_NAME"; then
        error "Failed to create PR"
        exit 1
    fi

    success "Claude Auto Issue processing completed successfully!"
}

# Retry mechanism for issue data fetch (single retry only)
retry_data_fetch() {
    local url="$1"
    local output_file="$2"
    
    # First attempt
    if "$SCRIPT_DIR/fetch-issue.sh" "$url" "$output_file"; then
        # Validate the fetched data
        if [[ -f "$output_file" ]] && jq empty "$output_file" 2>/dev/null; then
            log "Issue data fetch successful"
            return 0
        else
            warn "Issue data fetch completed but file is invalid, retrying..."
            rm -f "$output_file"
        fi
    else
        warn "Issue data fetch failed, retrying..."
    fi
    
    # Single retry attempt
    log "Retrying issue data fetch (single retry attempt)..."
    sleep 2  # Brief pause before retry
    
    if "$SCRIPT_DIR/fetch-issue.sh" "$url" "$output_file"; then
        # Validate the retry result
        if [[ -f "$output_file" ]] && jq empty "$output_file" 2>/dev/null; then
            log "Issue data fetch successful on retry"
            return 0
        else
            error "Issue data fetch retry completed but file is still invalid"
            rm -f "$output_file"
            return 1
        fi
    else
        error "Issue data fetch failed on retry"
        return 1
    fi
}

# Retry mechanism for analysis generation (single retry only)
retry_analysis_generation() {
    local issue_file="$1"
    local analysis_file="$2"
    
    # Validate input file first
    if [[ ! -f "$issue_file" ]] || ! jq empty "$issue_file" 2>/dev/null; then
        error "Invalid issue file for analysis: $issue_file"
        return 1
    fi
    
    # First attempt
    if "$SCRIPT_DIR/ultrathink-analysis.sh" "$issue_file" "$analysis_file"; then
        # Validate the generated analysis
        if [[ -f "$analysis_file" ]] && jq empty "$analysis_file" 2>/dev/null; then
            log "Ultra Think Analysis generation successful"
            return 0
        else
            warn "Analysis generation completed but file is invalid, retrying..."
            rm -f "$analysis_file"
        fi
    else
        warn "Analysis generation failed, retrying..."
    fi
    
    # Single retry attempt
    log "Retrying Ultra Think Analysis generation (single retry attempt)..."
    sleep 2  # Brief pause before retry
    
    if "$SCRIPT_DIR/ultrathink-analysis.sh" "$issue_file" "$analysis_file"; then
        # Validate the retry result
        if [[ -f "$analysis_file" ]] && jq empty "$analysis_file" 2>/dev/null; then
            log "Ultra Think Analysis generation successful on retry"
            return 0
        else
            error "Analysis generation retry completed but file is still invalid"
            rm -f "$analysis_file"
            return 1
        fi
    else
        error "Analysis generation failed on retry"
        return 1
    fi
}

main "$@"