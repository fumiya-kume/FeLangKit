#!/bin/bash

# Test Credential Sharing
# Usage: ./test-credentials.sh [container-name]

set -euo pipefail

CONTAINER_NAME="${1:-claude-auto-test-$$}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    echo "[ERROR] $1" >&2
}

success() {
    echo "[SUCCESS] $1"
}

cleanup() {
    if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
        log "Cleaning up test container: $CONTAINER_NAME"
        docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
        docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || true
    fi
}

trap cleanup EXIT

log "Testing credential sharing with container: $CONTAINER_NAME"

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

# Prepare credential sharing arguments (same as launch script)
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
    log "Found GitHub CLI authentication"
fi

# SSH Agent forwarding (macOS)
if [[ -n "${SSH_AUTH_SOCK:-}" ]]; then
    CREDENTIAL_ARGS="$CREDENTIAL_ARGS -v $SSH_AUTH_SOCK:/ssh-agent -e SSH_AUTH_SOCK=/ssh-agent"
    log "Found SSH agent"
fi

# Docker credentials (if exists)
if [[ -d "$HOME/.docker" ]]; then
    CREDENTIAL_ARGS="$CREDENTIAL_ARGS -v $HOME/.docker:/home/vscode/.docker:ro"
    log "Found Docker credentials"
fi

# AWS credentials (if exists)
if [[ -d "$HOME/.aws" ]]; then
    CREDENTIAL_ARGS="$CREDENTIAL_ARGS -v $HOME/.aws:/home/vscode/.aws:ro"
    log "Found AWS credentials"
fi

# Claude settings (if exists)
if [[ -f "$HOME/.claude/settings.local.json" ]]; then
    CREDENTIAL_ARGS="$CREDENTIAL_ARGS -v $HOME/.claude:/home/vscode/.claude:ro"
    log "Found Claude settings"
elif [[ -d "$HOME/.claude" ]]; then
    CREDENTIAL_ARGS="$CREDENTIAL_ARGS -v $HOME/.claude:/home/vscode/.claude:ro"
    log "Found Claude directory"
fi

# Additional environment variables
for env_var in USER HOME LANG LC_ALL TZ; do
    if [[ -n "${!env_var:-}" ]]; then
        CREDENTIAL_ARGS="$CREDENTIAL_ARGS -e $env_var=${!env_var}"
    fi
done

# Start test container
log "Starting test container..."

docker run -d \
    --name "$CONTAINER_NAME" \
    --workdir /workspace \
    -v "$PROJECT_ROOT:/workspace" \
    -v "$HOME/.gitconfig:/home/vscode/.gitconfig:ro" \
    -v "$HOME/.ssh:/home/vscode/.ssh:ro" \
    $CREDENTIAL_ARGS \
    "$IMAGE_NAME" \
    bash -c "
        # Set up Git configuration
        git config --global user.name '$(git config user.name)' || true
        git config --global user.email '$(git config user.email)' || true
        
        # Fix SSH permissions
        if [[ -d /home/vscode/.ssh ]]; then
            chmod 700 /home/vscode/.ssh
            chmod 600 /home/vscode/.ssh/* 2>/dev/null || true
        fi
        
        echo 'Test container ready'
        tail -f /dev/null
    "

# Wait for container to be ready
sleep 3

# Run comprehensive tests
log "Running credential tests..."

echo
echo "=== CREDENTIAL TEST RESULTS ==="
echo

# Test 1: Git Configuration
echo -n "Git Configuration: "
if docker exec "$CONTAINER_NAME" bash -c "git config user.name &>/dev/null && git config user.email &>/dev/null"; then
    success "✓ WORKING"
    docker exec "$CONTAINER_NAME" bash -c "echo '  User: '$(git config user.name)' <'$(git config user.email)'>'"
else
    error "✗ FAILED"
fi

echo

# Test 2: SSH Access
echo -n "SSH Access to GitHub: "
if docker exec "$CONTAINER_NAME" bash -c "ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -T git@github.com 2>&1 | grep -q 'successfully authenticated'"; then
    success "✓ WORKING"
else
    error "✗ FAILED"
    echo "  SSH agent status:"
    docker exec "$CONTAINER_NAME" bash -c "echo '  SSH_AUTH_SOCK: '${SSH_AUTH_SOCK:-'not set'}"
fi

echo

# Test 3: GitHub CLI
echo -n "GitHub CLI Authentication: "
if docker exec "$CONTAINER_NAME" bash -c "command -v gh &>/dev/null && gh auth status &>/dev/null"; then
    success "✓ WORKING"
    docker exec "$CONTAINER_NAME" bash -c "echo '  '$(gh auth status 2>&1 | head -1)"
else
    error "✗ FAILED"
    if ! docker exec "$CONTAINER_NAME" bash -c "command -v gh &>/dev/null"; then
        echo "  GitHub CLI not installed in container"
    else
        echo "  GitHub CLI not authenticated"
    fi
fi

echo

# Test 4: Anthropic API Key
echo -n "Anthropic API Key: "
if docker exec "$CONTAINER_NAME" bash -c "[[ -n \"\${ANTHROPIC_API_KEY:-}\" ]]"; then
    success "✓ AVAILABLE"
    docker exec "$CONTAINER_NAME" bash -c "echo '  Length: '${#ANTHROPIC_API_KEY}' characters'"
else
    error "✗ NOT SET"
fi

echo

# Test 4.5: Claude Settings
echo -n "Claude Settings: "
if docker exec "$CONTAINER_NAME" bash -c "[[ -f /home/vscode/.claude/settings.local.json ]]"; then
    success "✓ AVAILABLE"
    docker exec "$CONTAINER_NAME" bash -c "echo '  File: /home/vscode/.claude/settings.local.json'"
    docker exec "$CONTAINER_NAME" bash -c "echo '  Size: '$(stat -c%s /home/vscode/.claude/settings.local.json 2>/dev/null || stat -f%z /home/vscode/.claude/settings.local.json 2>/dev/null || echo 'unknown')' bytes'"
elif docker exec "$CONTAINER_NAME" bash -c "[[ -d /home/vscode/.claude ]]"; then
    echo "✓ DIRECTORY AVAILABLE"
    docker exec "$CONTAINER_NAME" bash -c "echo '  Directory: /home/vscode/.claude'"
    docker exec "$CONTAINER_NAME" bash -c "ls -la /home/vscode/.claude/ 2>/dev/null | head -5 || echo '  (empty or no access)'"
else
    error "✗ NOT FOUND"
fi

echo

# Test 5: Swift Build (if this is a Swift project)
echo -n "Swift Build Test: "
if docker exec "$CONTAINER_NAME" bash -c "cd /workspace && swift build &>/dev/null"; then
    success "✓ WORKING"
else
    error "✗ FAILED"
fi

echo

# Test 6: Git Operations
echo -n "Git Repository Status: "
if docker exec "$CONTAINER_NAME" bash -c "cd /workspace && git status &>/dev/null"; then
    success "✓ WORKING"
    docker exec "$CONTAINER_NAME" bash -c "cd /workspace && echo '  Branch: '$(git branch --show-current)"
else
    error "✗ FAILED"
fi

echo
echo "=== END TEST RESULTS ==="
echo

# Show container logs for debugging
log "Container setup logs:"
docker logs "$CONTAINER_NAME" | tail -10

log "Test completed. Container will be cleaned up automatically."