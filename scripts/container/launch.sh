#!/bin/bash

# Unified Container Launcher - Consolidated Docker Management
# Replaces: launch-claude-docker.sh and launch-claude-docker-hybrid.sh
# Usage: ./launch.sh <mode> <issue-data-file> <analysis-file> <container-name>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" >&2
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

usage() {
    cat << EOF
Usage: $0 <mode> <issue-data-file> <analysis-file> <container-name>

Container launch modes:
  hybrid     - Hybrid isolation with shared credentials (recommended)
  host       - Host Claude + dev container (legacy mode)
  isolated   - Full isolation with API-based Claude (experimental)

Examples:
  $0 hybrid issue-data.json analysis.json my-container
  $0 host issue-data.json analysis.json dev-container
  $0 isolated issue-data.json analysis.json iso-container

Options:
  -h, --help    Show this help message
  --dry-run     Show what would be done without executing
EOF
}

validate_inputs() {
    local mode="$1"
    local issue_data_file="$2"
    local analysis_file="$3"
    local container_name="$4"
    
    # Validate mode
    case "$mode" in
        hybrid|host|isolated)
            log "Using mode: $mode"
            ;;
        *)
            error "Invalid mode: $mode. Use: hybrid, host, or isolated"
            return 1
            ;;
    esac
    
    # Check if files exist
    if [[ ! -f "$issue_data_file" ]]; then
        error "Issue data file not found: $issue_data_file"
        return 1
    fi
    
    if [[ ! -f "$analysis_file" ]]; then
        error "Analysis file not found: $analysis_file"
        return 1
    fi
    
    # Validate JSON files
    if ! jq empty "$issue_data_file" 2>/dev/null; then
        error "Issue data file contains invalid JSON: $issue_data_file"
        return 1
    fi
    
    if ! jq empty "$analysis_file" 2>/dev/null; then
        error "Analysis file contains invalid JSON: $analysis_file"
        return 1
    fi
    
    # Check if Docker is running
    if ! docker info &> /dev/null; then
        error "Docker is not running. Please start Docker Desktop."
        return 1
    fi
    
    log "Input validation passed"
    return 0
}

launch_hybrid_mode() {
    local issue_data_file="$1"
    local analysis_file="$2"
    local container_name="$3"
    
    log "Launching hybrid isolation container..."
    
    # Extract issue information
    local issue_title=$(jq -r '.title' "$issue_data_file")
    local issue_number=$(jq -r '.issue_number' "$issue_data_file")
    local branch_name=$(jq -r '.branch_name' "$issue_data_file")
    local owner=$(jq -r '.owner' "$issue_data_file")
    local repo=$(jq -r '.repo' "$issue_data_file")
    
    log "Issue #$issue_number: $issue_title"
    log "Branch: $branch_name"
    log "Repository: $owner/$repo"
    
    # Build hybrid container image if needed
    local image_name="felangkit-hybrid"
    if ! docker images "$image_name" | grep -q "$image_name"; then
        log "Building hybrid container image..."
        if ! docker build -t "$image_name" -f "$PROJECT_ROOT/.devcontainer/Dockerfile.hybrid" "$PROJECT_ROOT"; then
            error "Failed to build hybrid container image"
            return 1
        fi
    fi
    
    # Create isolated workspace volume
    local workspace_volume="${container_name}-workspace"
    log "Creating isolated workspace volume: $workspace_volume"
    docker volume create "$workspace_volume" || true
    
    # Prepare credential sharing
    local credential_args=""
    
    # Environment variables
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        credential_args="$credential_args -e GITHUB_TOKEN=$GITHUB_TOKEN"
    fi
    
    if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        credential_args="$credential_args -e ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY"
    fi
    
    # Git configuration (read-only)
    if [[ -f "$HOME/.gitconfig" ]]; then
        credential_args="$credential_args -v $HOME/.gitconfig:/home/vscode/.gitconfig:ro"
        log "Sharing Git configuration (read-only)"
    fi
    
    # SSH keys for Git operations (read-only)
    if [[ -d "$HOME/.ssh" ]]; then
        credential_args="$credential_args -v $HOME/.ssh:/home/vscode/.ssh:ro"
        log "Sharing SSH keys (read-only)"
    fi
    
    # GitHub CLI authentication (read-only)
    if [[ -d "$HOME/.config/gh" ]]; then
        credential_args="$credential_args -v $HOME/.config/gh:/home/vscode/.config/gh:ro"
        log "Sharing GitHub CLI authentication (read-only)"
    fi
    
    # SSH Agent forwarding
    if [[ -n "${SSH_AUTH_SOCK:-}" ]]; then
        credential_args="$credential_args -v $SSH_AUTH_SOCK:/ssh-agent -e SSH_AUTH_SOCK=/ssh-agent"
        log "Forwarding SSH agent"
    fi
    
    # Claude settings (read-only)
    if [[ -f "$HOME/.claude/settings.local.json" ]]; then
        credential_args="$credential_args -v $HOME/.claude:/home/vscode/.claude:ro"
        log "Sharing Claude settings (read-only)"
    elif [[ -d "$HOME/.claude" ]]; then
        credential_args="$credential_args -v $HOME/.claude:/home/vscode/.claude:ro"
        log "Sharing Claude directory (read-only)"
    fi
    
    # Additional environment variables
    for env_var in USER HOME LANG LC_ALL TZ; do
        if [[ -n "${!env_var:-}" ]]; then
            credential_args="$credential_args -e $env_var=${!env_var}"
        fi
    done
    
    # Extract Git user information
    local git_user_name=$(git config user.name 2>/dev/null || echo "Claude Agent")
    local git_user_email=$(git config user.email 2>/dev/null || echo "claude-agent@anthropic.com")
    
    credential_args="$credential_args -e GIT_USER_NAME=$git_user_name"
    credential_args="$credential_args -e GIT_USER_EMAIL=$git_user_email"
    credential_args="$credential_args -e GIT_REPO_OWNER=$owner"
    credential_args="$credential_args -e GIT_REPO_NAME=$repo"
    
    log "Starting hybrid container with shared credentials and isolated workspace..."
    
    # Start the container
    docker run -d \
        --name "$container_name" \
        --workdir /workspace \
        -v "$workspace_volume:/workspace" \
        -v "$PROJECT_ROOT:/host-project:ro" \
        $credential_args \
        "$image_name" \
        bash -c "
            echo 'Hybrid Isolation Container started for issue #$issue_number'
            echo 'Workspace: /workspace (isolated volume)'
            echo 'Host project: /host-project (read-only)'
            echo 'Credentials: Shared from host (read-only)'
            
            # Copy project files to isolated workspace
            echo 'Copying project files to isolated workspace...'
            cp -r /host-project/* /workspace/ 2>/dev/null || true
            cp -r /host-project/.* /workspace/ 2>/dev/null || true
            
            # Set up Git configuration
            git config --global user.name '$git_user_name'
            git config --global user.email '$git_user_email'
            git config --global init.defaultBranch main
            git config --global pull.rebase false
            
            # Fix SSH permissions
            if [[ -d /home/vscode/.ssh ]]; then
                chmod 700 /home/vscode/.ssh
                chmod 600 /home/vscode/.ssh/* 2>/dev/null || true
            fi
            
            # Test authentication
            echo 'Testing authentication...'
            echo -n 'Git config: '
            if git config user.name &>/dev/null; then echo 'OK'; else echo 'Failed'; fi
            echo -n 'SSH access: '
            if ssh -o StrictHostKeyChecking=no -T git@github.com 2>&1 | grep -q 'successfully authenticated'; then 
                echo 'OK'
            else 
                echo 'Failed - will use HTTPS with token'
            fi
            echo -n 'GitHub CLI: '
            if gh auth status &>/dev/null; then echo 'OK'; else echo 'Failed'; fi
            echo -n 'Anthropic API: '
            if [[ -n \"\${ANTHROPIC_API_KEY:-}\" ]]; then echo 'OK'; else echo 'Failed'; fi
            
            echo 'Container ready for development workflow'
            tail -f /dev/null
        "
    
    # Wait for container to be ready
    sleep 3
    
    # Copy issue data and analysis to container
    log "Copying issue data and analysis to container..."
    docker cp "$issue_data_file" "$container_name:/workspace/issue-data.json"
    docker cp "$analysis_file" "$container_name:/workspace/analysis-data.json"
    
    success "Hybrid container launched successfully: $container_name"
    return 0
}

launch_host_mode() {
    local issue_data_file="$1"
    local analysis_file="$2"
    local container_name="$3"
    
    warn "Host mode is legacy - consider using hybrid mode for better isolation"
    
    # Call original launch-claude-docker.sh logic
    log "Launching host mode with dev container..."
    
    # This would contain the original host-based logic
    # For now, delegate to the old script if it exists
    if [[ -f "$SCRIPT_DIR/../launch-claude-docker.sh" ]]; then
        exec "$SCRIPT_DIR/../launch-claude-docker.sh" "$issue_data_file" "$analysis_file" "$container_name"
    else
        error "Host mode implementation not available. Use hybrid mode."
        return 1
    fi
}

launch_isolated_mode() {
    local issue_data_file="$1"
    local analysis_file="$2"
    local container_name="$3"
    
    warn "Isolated mode is experimental - use with caution"
    
    # Full isolation implementation would go here
    log "Launching fully isolated container..."
    
    # Build full isolation container
    local image_name="felangkit-isolated"
    if ! docker images "$image_name" | grep -q "$image_name"; then
        log "Building isolated container image..."
        if ! docker build -t "$image_name" -f "$PROJECT_ROOT/.devcontainer/Dockerfile.full-isolation" "$PROJECT_ROOT"; then
            error "Failed to build isolated container image"
            return 1
        fi
    fi
    
    # Run with minimal host interaction
    docker run -d \
        --name "$container_name" \
        --workdir /workspace \
        -e ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}" \
        -e GITHUB_TOKEN="${GITHUB_TOKEN:-}" \
        "$image_name" \
        /usr/local/bin/container-workflow.sh
    
    # Copy issue data
    docker cp "$issue_data_file" "$container_name:/workspace/issue-data.json"
    docker cp "$analysis_file" "$container_name:/workspace/analysis-data.json"
    
    success "Isolated container launched successfully: $container_name"
    return 0
}

main() {
    if [[ $# -lt 1 ]]; then
        usage
        exit 1
    fi
    
    local mode="$1"
    
    case "$mode" in
        -h|--help)
            usage
            exit 0
            ;;
        hybrid|host|isolated)
            if [[ $# -ne 4 ]]; then
                error "Mode '$mode' requires 4 arguments: <mode> <issue-data-file> <analysis-file> <container-name>"
                usage
                exit 1
            fi
            
            local issue_data_file="$2"
            local analysis_file="$3"
            local container_name="$4"
            
            if ! validate_inputs "$mode" "$issue_data_file" "$analysis_file" "$container_name"; then
                exit 1
            fi
            
            case "$mode" in
                hybrid)
                    launch_hybrid_mode "$issue_data_file" "$analysis_file" "$container_name"
                    ;;
                host)
                    launch_host_mode "$issue_data_file" "$analysis_file" "$container_name"
                    ;;
                isolated)
                    launch_isolated_mode "$issue_data_file" "$analysis_file" "$container_name"
                    ;;
            esac
            ;;
        *)
            error "Unknown command: $mode"
            usage
            exit 1
            ;;
    esac
}

main "$@"