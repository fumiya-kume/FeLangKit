#!/bin/bash

# Claude Code Docker Launcher - Hybrid Isolation Mode
# Shares credentials between host and container while providing development environment isolation
# Usage: ./launch-claude-docker-hybrid.sh <issue-data-file> <analysis-file> <container-name>

set -euo pipefail

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >&2
}

error() {
    echo "[ERROR] $1" >&2
}

if [[ $# -ne 3 ]]; then
    echo "Usage: $0 <issue-data-file> <analysis-file> <container-name>"
    exit 1
fi

ISSUE_DATA_FILE="$1"
ANALYSIS_FILE="$2"
CONTAINER_NAME="$3"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Check if issue and analysis files exist
if [[ ! -f "$ISSUE_DATA_FILE" ]]; then
    error "Issue data file not found: $ISSUE_DATA_FILE"
    exit 1
fi

if [[ ! -f "$ANALYSIS_FILE" ]]; then
    error "Analysis file not found: $ANALYSIS_FILE"
    exit 1
fi

# Validate JSON files
if ! jq empty "$ISSUE_DATA_FILE" 2>/dev/null; then
    error "Issue data file contains invalid JSON: $ISSUE_DATA_FILE"
    exit 1
fi

if ! jq empty "$ANALYSIS_FILE" 2>/dev/null; then
    error "Analysis file contains invalid JSON: $ANALYSIS_FILE"
    exit 1
fi

log "Analysis file validation passed"

# Extract issue information
ISSUE_TITLE=$(jq -r '.title' "$ISSUE_DATA_FILE")
ISSUE_NUMBER=$(jq -r '.issue_number' "$ISSUE_DATA_FILE")
BRANCH_NAME=$(jq -r '.branch_name' "$ISSUE_DATA_FILE")
OWNER=$(jq -r '.owner' "$ISSUE_DATA_FILE")
REPO=$(jq -r '.repo' "$ISSUE_DATA_FILE")

log "Starting Hybrid Isolation Mode for issue #$ISSUE_NUMBER: $ISSUE_TITLE"
log "Branch: $BRANCH_NAME"
log "Repository: $OWNER/$REPO"

# Check if Docker is running
if ! docker info &> /dev/null; then
    error "Docker is not running. Please start Docker Desktop."
    exit 1
fi

# Build the hybrid container image if it doesn't exist
IMAGE_NAME="felangkit-hybrid"
if ! docker images "$IMAGE_NAME" | grep -q "$IMAGE_NAME"; then
    log "Building hybrid container image..."
    if ! docker build -t "$IMAGE_NAME" -f "$PROJECT_ROOT/.devcontainer/Dockerfile.hybrid" "$PROJECT_ROOT"; then
        error "Failed to build hybrid container image"
        exit 1
    fi
fi

# Create isolated workspace volume for this container
WORKSPACE_VOLUME="${CONTAINER_NAME}-workspace"
log "Creating isolated workspace volume: $WORKSPACE_VOLUME"
docker volume create "$WORKSPACE_VOLUME" || true

# Prepare credential sharing arguments with read-only mounts for security
CREDENTIAL_ARGS=""

# Environment variables for API access
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    CREDENTIAL_ARGS="$CREDENTIAL_ARGS -e GITHUB_TOKEN=$GITHUB_TOKEN"
fi

if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
    CREDENTIAL_ARGS="$CREDENTIAL_ARGS -e ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY"
fi

# Git configuration (read-only)
if [[ -f "$HOME/.gitconfig" ]]; then
    CREDENTIAL_ARGS="$CREDENTIAL_ARGS -v $HOME/.gitconfig:/home/vscode/.gitconfig:ro"
    log "Sharing Git configuration (read-only)"
fi

# SSH keys for Git operations (read-only)
if [[ -d "$HOME/.ssh" ]]; then
    CREDENTIAL_ARGS="$CREDENTIAL_ARGS -v $HOME/.ssh:/home/vscode/.ssh:ro"
    log "Sharing SSH keys (read-only)"
fi

# GitHub CLI authentication (read-only)
if [[ -d "$HOME/.config/gh" ]]; then
    CREDENTIAL_ARGS="$CREDENTIAL_ARGS -v $HOME/.config/gh:/home/vscode/.config/gh:ro"
    log "Sharing GitHub CLI authentication (read-only)"
fi

# SSH Agent forwarding for Git operations
if [[ -n "${SSH_AUTH_SOCK:-}" ]]; then
    CREDENTIAL_ARGS="$CREDENTIAL_ARGS -v $SSH_AUTH_SOCK:/ssh-agent -e SSH_AUTH_SOCK=/ssh-agent"
    log "Forwarding SSH agent"
fi

# Claude Code settings (read-only)
if [[ -f "$HOME/.claude/settings.local.json" ]]; then
    CREDENTIAL_ARGS="$CREDENTIAL_ARGS -v $HOME/.claude:/home/vscode/.claude:ro"
    log "Sharing Claude settings (read-only)"
elif [[ -d "$HOME/.claude" ]]; then
    CREDENTIAL_ARGS="$CREDENTIAL_ARGS -v $HOME/.claude:/home/vscode/.claude:ro"
    log "Sharing Claude directory (read-only)"
fi

# Additional environment variables
for env_var in USER HOME LANG LC_ALL TZ; do
    if [[ -n "${!env_var:-}" ]]; then
        CREDENTIAL_ARGS="$CREDENTIAL_ARGS -e $env_var=${!env_var}"
    fi
done

# Extract Git user information from host
GIT_USER_NAME=$(git config user.name 2>/dev/null || echo "Claude Agent")
GIT_USER_EMAIL=$(git config user.email 2>/dev/null || echo "claude-agent@anthropic.com")

CREDENTIAL_ARGS="$CREDENTIAL_ARGS -e GIT_USER_NAME=$GIT_USER_NAME"
CREDENTIAL_ARGS="$CREDENTIAL_ARGS -e GIT_USER_EMAIL=$GIT_USER_EMAIL"
CREDENTIAL_ARGS="$CREDENTIAL_ARGS -e GIT_REPO_OWNER=$OWNER"
CREDENTIAL_ARGS="$CREDENTIAL_ARGS -e GIT_REPO_NAME=$REPO"

log "Starting hybrid container with shared credentials and isolated workspace..."

# Start the container with hybrid isolation
docker run -d \
    --name "$CONTAINER_NAME" \
    --workdir /workspace \
    -v "$WORKSPACE_VOLUME:/workspace" \
    -v "$PROJECT_ROOT:/host-project:ro" \
    $CREDENTIAL_ARGS \
    "$IMAGE_NAME" \
    bash -c "
        echo 'Hybrid Isolation Container started for issue #$ISSUE_NUMBER'
        echo 'Workspace: /workspace (isolated volume)'
        echo 'Host project: /host-project (read-only)'
        echo 'Credentials: Shared from host (read-only)'
        
        # Copy project files to isolated workspace
        echo 'Copying project files to isolated workspace...'
        cp -r /host-project/* /workspace/ 2>/dev/null || true
        cp -r /host-project/.* /workspace/ 2>/dev/null || true
        
        # Set up Git configuration from host
        git config --global user.name '$GIT_USER_NAME'
        git config --global user.email '$GIT_USER_EMAIL'
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
        echo -n 'Claude settings: '
        if [[ -f /home/vscode/.claude/settings.local.json ]]; then echo 'OK'; else echo 'Not found'; fi
        
        echo 'Container ready for development workflow'
        echo 'Available commands:'
        echo '  docker exec $CONTAINER_NAME swift build'
        echo '  docker exec $CONTAINER_NAME swift test'
        echo '  docker exec $CONTAINER_NAME swiftlint lint'
        echo '  docker exec $CONTAINER_NAME git status'
        echo '  docker exec $CONTAINER_NAME gh pr create'
        
        # Wait for commands or timeout
        echo 'Container will remain active for development...'
        tail -f /dev/null
    "

# Wait for container to be ready
sleep 3

log "Container ready! You can now work in isolated environment with shared credentials."
log ""
log "Development Commands:"
log "  docker exec $CONTAINER_NAME swift build"
log "  docker exec $CONTAINER_NAME swift test"
log "  docker exec $CONTAINER_NAME swiftlint lint"
log "  docker exec $CONTAINER_NAME git status"
log ""
log "Authentication Status:"
docker exec "$CONTAINER_NAME" bash -c "
    echo '--- Authentication Status ---'
    echo -n 'Git User: '; git config user.name
    echo -n 'Git Email: '; git config user.email
    echo -n 'SSH Agent: '; if [[ -n \"\$SSH_AUTH_SOCK\" ]]; then echo 'Available'; else echo 'Not available'; fi
    echo -n 'GitHub Token: '; if [[ -n \"\$GITHUB_TOKEN\" ]]; then echo 'Available'; else echo 'Not available'; fi
    echo -n 'Anthropic API: '; if [[ -n \"\$ANTHROPIC_API_KEY\" ]]; then echo 'Available'; else echo 'Not available'; fi
    echo '--- End Status ---'
" 2>/dev/null || log "Container authentication check failed"

# Copy issue data and analysis to container workspace
log "Copying issue data and analysis to container..."
docker cp "$ISSUE_DATA_FILE" "$CONTAINER_NAME:/workspace/issue-data.json"
docker cp "$ANALYSIS_FILE" "$CONTAINER_NAME:/workspace/analysis-data.json"

# Option 1: Run automated workflow
read -p "Run automated Claude Agent workflow? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log "Starting automated workflow in container..."
    docker exec "$CONTAINER_NAME" /usr/local/bin/container-workflow.sh
    
    # Extract results
    log "Extracting execution results..."
    docker cp "$CONTAINER_NAME:/workspace/execution-report.json" "$PROJECT_ROOT/execution-report.json" 2>/dev/null || true
    docker cp "$CONTAINER_NAME:/workspace/summary-report.json" "$PROJECT_ROOT/summary-report.json" 2>/dev/null || true
    docker cp "$CONTAINER_NAME:/workspace/container.log" "$PROJECT_ROOT/container.log" 2>/dev/null || true
    
    log "Results extracted to project root:"
    log "  - execution-report.json"
    log "  - summary-report.json" 
    log "  - container.log"
else
    # Option 2: Interactive development
    log "Container is ready for interactive development."
    log "Use 'docker exec -it $CONTAINER_NAME bash' to enter the container."
    log ""
    log "When ready, you can run the Claude Agent manually:"
    log "  docker exec $CONTAINER_NAME python3 /usr/local/bin/claude-agent.py \\"
    log "    --issue-data /workspace/issue-data.json \\"
    log "    --analysis-data /workspace/analysis-data.json \\"
    log "    --workspace /workspace \\"
    log "    --output /workspace/execution-report.json"
fi

log "Hybrid isolation setup completed successfully!"
log ""
log "Benefits of this approach:"
log "  ✓ Credentials shared securely (read-only mounts)"
log "  ✓ Development environment completely isolated"
log "  ✓ No files created on host outside project"
log "  ✓ Git operations work with your existing setup"
log "  ✓ Multiple containers can run simultaneously"
log ""
log "Container name: $CONTAINER_NAME"
log "Workspace volume: $WORKSPACE_VOLUME"