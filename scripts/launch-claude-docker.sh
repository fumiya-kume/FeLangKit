#!/bin/bash

# Claude Code Docker Launcher
# Usage: ./launch-claude-docker.sh <issue-data-file> <container-name>

set -euo pipefail

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >&2
}

error() {
    echo "[ERROR] $1" >&2
}

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <issue-data-file> <container-name>"
    exit 1
fi

ISSUE_DATA_FILE="$1"
CONTAINER_NAME="$2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Check if issue data file exists
if [[ ! -f "$ISSUE_DATA_FILE" ]]; then
    error "Issue data file not found: $ISSUE_DATA_FILE"
    exit 1
fi

# Extract issue information
ISSUE_TITLE=$(jq -r '.title' "$ISSUE_DATA_FILE")
ISSUE_BODY=$(jq -r '.body' "$ISSUE_DATA_FILE")
BRANCH_NAME=$(jq -r '.branch_name' "$ISSUE_DATA_FILE")
ISSUE_NUMBER=$(jq -r '.issue_number' "$ISSUE_DATA_FILE")
OWNER=$(jq -r '.owner' "$ISSUE_DATA_FILE")
REPO=$(jq -r '.repo' "$ISSUE_DATA_FILE")

log "Launching Claude Code for issue #$ISSUE_NUMBER: $ISSUE_TITLE"
log "Branch: $BRANCH_NAME"

# Check if Docker is running
if ! docker info &> /dev/null; then
    error "Docker is not running. Please start Docker Desktop."
    exit 1
fi

# Build the dev container image if it doesn't exist
IMAGE_NAME="felangkit-dev"
if ! docker images "$IMAGE_NAME" | grep -q "$IMAGE_NAME"; then
    log "Building dev container image..."
    if ! docker build -t "$IMAGE_NAME" -f "$PROJECT_ROOT/.devcontainer/Dockerfile" "$PROJECT_ROOT"; then
        error "Failed to build dev container image"
        exit 1
    fi
fi

# Create the instruction file for Claude in the project directory
INSTRUCTION_FILE="$PROJECT_ROOT/issue-instructions.md"

cat > "$INSTRUCTION_FILE" << EOF
# GitHub Issue: $ISSUE_TITLE

## Issue Details
- **Issue #**: $ISSUE_NUMBER
- **Repository**: $OWNER/$REPO
- **Branch**: $BRANCH_NAME

## Issue Description
$ISSUE_BODY

## Instructions for Claude
1. Read and understand the issue requirements
2. Create a new branch: $BRANCH_NAME
3. Implement the necessary changes following the project conventions in CLAUDE.md
4. Run the quality gates: swiftlint lint --fix && swiftlint lint && swift build && swift test
5. Commit changes using conventional commit format
6. Push the branch and create a PR

Please work on this issue systematically and ensure all tests pass before committing.

## Development Environment
The project uses Swift with the following tools:
- SwiftLint for code quality
- Swift Package Manager for dependencies  
- GitHub Actions for CI/CD

You can run development commands directly in the host environment or use the Docker container for isolated testing.

## Container Authentication
A Docker container is available with shared credentials from your host:
- Git configuration and SSH keys are mounted
- GitHub CLI authentication is shared
- Anthropic API key is available
- You can run git, gh, swift, and swiftlint commands in the container

Use commands like:
- \`docker exec <container-name> swift build\`
- \`docker exec <container-name> git status\`
- \`docker exec <container-name> gh pr list\`
EOF

# Prepare credential sharing arguments
CREDENTIAL_ARGS=""

# Environment variables
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    CREDENTIAL_ARGS="$CREDENTIAL_ARGS -e GITHUB_TOKEN=$GITHUB_TOKEN"
fi

if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
    CREDENTIAL_ARGS="$CREDENTIAL_ARGS -e ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY"
fi

# GitHub CLI authentication
if [[ -d "$HOME/.config/gh" ]]; then
    CREDENTIAL_ARGS="$CREDENTIAL_ARGS -v $HOME/.config/gh:/home/vscode/.config/gh:ro"
    log "Sharing GitHub CLI authentication"
fi

# SSH Agent forwarding (macOS)
if [[ -n "${SSH_AUTH_SOCK:-}" ]]; then
    CREDENTIAL_ARGS="$CREDENTIAL_ARGS -v $SSH_AUTH_SOCK:/ssh-agent -e SSH_AUTH_SOCK=/ssh-agent"
    log "Forwarding SSH agent"
fi

# Docker credentials (if exists)
if [[ -d "$HOME/.docker" ]]; then
    CREDENTIAL_ARGS="$CREDENTIAL_ARGS -v $HOME/.docker:/home/vscode/.docker:ro"
    log "Sharing Docker credentials"
fi

# AWS credentials (if exists)
if [[ -d "$HOME/.aws" ]]; then
    CREDENTIAL_ARGS="$CREDENTIAL_ARGS -v $HOME/.aws:/home/vscode/.aws:ro"
    log "Sharing AWS credentials"
fi

# Claude settings (if exists)
if [[ -f "$HOME/.claude/settings.local.json" ]]; then
    # Create .claude directory in container if needed
    CREDENTIAL_ARGS="$CREDENTIAL_ARGS -v $HOME/.claude:/home/vscode/.claude:ro"
    log "Sharing Claude settings"
elif [[ -d "$HOME/.claude" ]]; then
    # Share entire .claude directory if it exists
    CREDENTIAL_ARGS="$CREDENTIAL_ARGS -v $HOME/.claude:/home/vscode/.claude:ro"
    log "Sharing Claude directory"
fi

# Additional environment variables that might be useful
for env_var in USER HOME LANG LC_ALL TZ; do
    if [[ -n "${!env_var:-}" ]]; then
        CREDENTIAL_ARGS="$CREDENTIAL_ARGS -e $env_var=${!env_var}"
    fi
done

# Check if Claude Code is available on host
if ! command -v claude &> /dev/null; then
    error "Claude Code is not available on the host system"
    error "Please install Claude Code: https://claude.ai/code"
    exit 1
fi

log "Starting Claude Code on host for issue #$ISSUE_NUMBER"
log "Working directory: $PROJECT_ROOT"
log "Issue instructions: $INSTRUCTION_FILE"

# Start optional Docker container for development environment
log "Starting Docker container for development environment: $CONTAINER_NAME"

docker run -d \
    --name "$CONTAINER_NAME" \
    --workdir /workspace \
    -v "$PROJECT_ROOT:/workspace" \
    -v "$HOME/.gitconfig:/home/vscode/.gitconfig:ro" \
    -v "$HOME/.ssh:/home/vscode/.ssh:ro" \
    $CREDENTIAL_ARGS \
    "$IMAGE_NAME" \
    bash -c "
        echo 'Development container started for issue #$ISSUE_NUMBER'
        echo 'Container available for: swift build, swift test, swiftlint lint, git, gh commands'
        
        # Set up Git configuration
        git config --global user.name '$(git config user.name)' || true
        git config --global user.email '$(git config user.email)' || true
        
        # Fix SSH permissions
        if [[ -d /home/vscode/.ssh ]]; then
            chmod 700 /home/vscode/.ssh
            chmod 600 /home/vscode/.ssh/* 2>/dev/null || true
        fi
        
        # Test GitHub CLI authentication
        if command -v gh &> /dev/null; then
            echo 'Testing GitHub CLI authentication...'
            if gh auth status &> /dev/null; then
                echo 'GitHub CLI authenticated successfully'
            else
                echo 'GitHub CLI authentication not available'
            fi
        fi
        
        # Test Git SSH access
        echo 'Testing Git SSH access...'
        if ssh -T git@github.com 2>&1 | grep -q 'successfully authenticated'; then
            echo 'Git SSH access working'
        else
            echo 'Git SSH access may need configuration'
        fi
        
        # Check Claude settings
        if [[ -f /home/vscode/.claude/settings.local.json ]]; then
            echo 'Claude settings available at /home/vscode/.claude/settings.local.json'
        elif [[ -d /home/vscode/.claude ]]; then
            echo 'Claude directory available at /home/vscode/.claude'
        else
            echo 'Claude settings not found'
        fi
        
        echo 'Development environment ready'
        tail -f /dev/null
    "

# Wait for container to be ready
sleep 2

log "Container is ready with shared credentials. You can run commands like:"
log "  docker exec $CONTAINER_NAME swift build"
log "  docker exec $CONTAINER_NAME swift test"  
log "  docker exec $CONTAINER_NAME swiftlint lint"
log "  docker exec $CONTAINER_NAME git status"
log "  docker exec $CONTAINER_NAME gh auth status"
log "  docker exec $CONTAINER_NAME gh pr list"

# Test container authentication
log "Testing container authentication..."
docker exec "$CONTAINER_NAME" bash -c "
    echo '--- Authentication Test Results ---'
    echo -n 'Git: '
    if git config user.name &>/dev/null; then echo 'Configured'; else echo 'Not configured'; fi
    echo -n 'SSH: '
    if ssh -T git@github.com 2>&1 | grep -q 'successfully authenticated'; then echo 'Working'; else echo 'Not working'; fi
    echo -n 'GitHub CLI: '
    if gh auth status &>/dev/null; then echo 'Authenticated'; else echo 'Not authenticated'; fi
    echo -n 'Anthropic API: '
    if [[ -n \"\${ANTHROPIC_API_KEY:-}\" ]]; then echo 'Available'; else echo 'Not available'; fi
    echo -n 'Claude Settings: '
    if [[ -f /home/vscode/.claude/settings.local.json ]]; then echo 'Available'; else echo 'Not found'; fi
    echo '--- End Test Results ---'
" || log "Authentication test failed, but container is running"

# Run Claude Code on the host with the project directory
cd "$PROJECT_ROOT"
log "Starting Claude Code..."
claude "$INSTRUCTION_FILE"

log "Claude Code session completed"