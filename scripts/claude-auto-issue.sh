#!/bin/bash

# Claude Auto Issue - Automated GitHub Issue Processing with Claude Code
# Usage: ./claude-auto-issue.sh <github-issue-url>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration
CONFIG_FILE="${SCRIPT_DIR}/claude-auto-config.json"
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

    # Step 1: Fetch issue data
    log "Fetching issue data..."
    if ! "$SCRIPT_DIR/fetch-issue.sh" "$issue_url" "$ISSUE_DATA_FILE"; then
        error "Failed to fetch issue data"
        exit 1
    fi

    # Step 2: Ultra Think Analysis
    ANALYSIS_FILE="${SCRIPT_DIR}/.analysis-$(basename "$ISSUE_DATA_FILE" .json).json"
    log "Running Ultra Think Analysis..."
    if ! "$SCRIPT_DIR/ultrathink-analysis.sh" "$ISSUE_DATA_FILE" "$ANALYSIS_FILE"; then
        error "Failed to complete Ultra Think Analysis"
        exit 1
    fi

    # Step 3: Launch Claude Code in Docker
    log "Launching Claude Code in Docker container..."
    if ! "$SCRIPT_DIR/launch-claude-docker.sh" "$ISSUE_DATA_FILE" "$ANALYSIS_FILE" "$CONTAINER_NAME"; then
        error "Failed to launch Claude Code"
        exit 1
    fi

    # Step 4: Monitor and create PR
    log "Monitoring progress and preparing PR..."
    if ! "$SCRIPT_DIR/create-pr.sh" "$ISSUE_DATA_FILE" "$CONTAINER_NAME"; then
        error "Failed to create PR"
        exit 1
    fi

    success "Claude Auto Issue processing completed successfully!"
}

main "$@"