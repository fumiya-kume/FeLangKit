#!/bin/bash

# Extract Container Results - Workspace Management for Hybrid Isolation
# Usage: ./extract-container-results.sh <container-name> [output-directory]

set -euo pipefail

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    echo "[ERROR] $1" >&2
}

success() {
    echo "[SUCCESS] $1"
}

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <container-name> [output-directory]"
    echo ""
    echo "Extracts development results from hybrid isolation container."
    echo ""
    echo "Arguments:"
    echo "  container-name    Name of the container to extract from"
    echo "  output-directory  Directory to save results (default: current directory)"
    exit 1
fi

CONTAINER_NAME="$1"
OUTPUT_DIR="${2:-.}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

log "Extracting results from container: $CONTAINER_NAME"
log "Output directory: $OUTPUT_DIR"

# Check if container exists and is running
if ! docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
    if docker ps -a -q -f name="$CONTAINER_NAME" | grep -q .; then
        log "Container exists but is not running. Starting container..."
        docker start "$CONTAINER_NAME"
        sleep 2
    else
        error "Container '$CONTAINER_NAME' not found"
        exit 1
    fi
fi

# Function to safely extract file from container
extract_file() {
    local container_path="$1"
    local output_filename="$2"
    local description="$3"
    local required="${4:-false}"
    
    log "Extracting $description..."
    
    if docker exec "$CONTAINER_NAME" test -f "$container_path" 2>/dev/null; then
        if docker cp "$CONTAINER_NAME:$container_path" "$OUTPUT_DIR/$output_filename"; then
            success "$description extracted: $OUTPUT_DIR/$output_filename"
            return 0
        else
            error "Failed to extract $description"
            return 1
        fi
    else
        if [[ "$required" == "true" ]]; then
            error "$description not found in container: $container_path"
            return 1
        else
            log "$description not found (optional): $container_path"
            return 0
        fi
    fi
}

# Function to extract directory from container
extract_directory() {
    local container_path="$1"
    local output_dirname="$2"
    local description="$3"
    
    log "Extracting $description..."
    
    if docker exec "$CONTAINER_NAME" test -d "$container_path" 2>/dev/null; then
        if docker cp "$CONTAINER_NAME:$container_path" "$OUTPUT_DIR/"; then
            # Rename if needed
            if [[ "$output_dirname" != "$(basename "$container_path")" ]]; then
                mv "$OUTPUT_DIR/$(basename "$container_path")" "$OUTPUT_DIR/$output_dirname"
            fi
            success "$description extracted: $OUTPUT_DIR/$output_dirname"
            return 0
        else
            error "Failed to extract $description"
            return 1
        fi
    else
        log "$description not found: $container_path"
        return 0
    fi
}

# Extract execution results
log "Starting result extraction process..."

# Core execution files
extract_file "/workspace/execution-report.json" "execution-report.json" "Execution Report" true
extract_file "/workspace/summary-report.json" "summary-report.json" "Summary Report"
extract_file "/workspace/container.log" "container.log" "Container Log"

# Issue and analysis data (for reference)
extract_file "/workspace/issue-data.json" "issue-data.json" "Issue Data"
extract_file "/workspace/analysis-data.json" "analysis-data.json" "Analysis Data"

# Git information
log "Extracting Git information..."
docker exec "$CONTAINER_NAME" bash -c "cd /workspace && git status --porcelain > git-status.txt 2>/dev/null || echo 'No git repository' > git-status.txt"
docker exec "$CONTAINER_NAME" bash -c "cd /workspace && git log --oneline -10 > git-log.txt 2>/dev/null || echo 'No git history' > git-log.txt"
docker exec "$CONTAINER_NAME" bash -c "cd /workspace && git branch -a > git-branches.txt 2>/dev/null || echo 'No git branches' > git-branches.txt"

extract_file "/workspace/git-status.txt" "git-status.txt" "Git Status"
extract_file "/workspace/git-log.txt" "git-log.txt" "Git Log"
extract_file "/workspace/git-branches.txt" "git-branches.txt" "Git Branches"

# Build and test outputs
docker exec "$CONTAINER_NAME" bash -c "cd /workspace && swift build 2>&1 | tee build-output.txt" || true
docker exec "$CONTAINER_NAME" bash -c "cd /workspace && swift test 2>&1 | tee test-output.txt" || true
docker exec "$CONTAINER_NAME" bash -c "cd /workspace && swiftlint lint 2>&1 | tee lint-output.txt" || true

extract_file "/workspace/build-output.txt" "build-output.txt" "Build Output"
extract_file "/workspace/test-output.txt" "test-output.txt" "Test Output"
extract_file "/workspace/lint-output.txt" "lint-output.txt" "Lint Output"

# Source code changes (if any)
log "Checking for source code changes..."
if docker exec "$CONTAINER_NAME" bash -c "cd /workspace && git diff --name-only HEAD" 2>/dev/null | grep -q .; then
    log "Source code changes detected, creating diff..."
    docker exec "$CONTAINER_NAME" bash -c "cd /workspace && git diff > source-changes.diff"
    extract_file "/workspace/source-changes.diff" "source-changes.diff" "Source Code Changes"
    
    # Extract modified files
    log "Extracting modified source files..."
    docker exec "$CONTAINER_NAME" bash -c "cd /workspace && git diff --name-only HEAD" | while read -r file; do
        if [[ -n "$file" ]]; then
            local output_file="modified-files/$(basename "$file")"
            mkdir -p "$OUTPUT_DIR/modified-files"
            extract_file "/workspace/$file" "$output_file" "Modified File: $file"
        fi
    done
else
    log "No source code changes detected"
fi

# Container environment information
log "Extracting container environment information..."
docker exec "$CONTAINER_NAME" bash -c "
    echo '=== Container Environment Information ===' > container-info.txt
    echo 'Date: $(date)' >> container-info.txt
    echo 'Container: $HOSTNAME' >> container-info.txt
    echo 'User: $(whoami)' >> container-info.txt
    echo 'Working Directory: $(pwd)' >> container-info.txt
    echo 'Swift Version:' >> container-info.txt
    swift --version >> container-info.txt 2>&1
    echo '' >> container-info.txt
    echo 'Python Version:' >> container-info.txt
    python3 --version >> container-info.txt 2>&1
    echo '' >> container-info.txt
    echo 'SwiftLint Version:' >> container-info.txt
    swiftlint version >> container-info.txt 2>&1
    echo '' >> container-info.txt
    echo 'GitHub CLI Version:' >> container-info.txt
    gh --version >> container-info.txt 2>&1
    echo '' >> container-info.txt
    echo 'Environment Variables:' >> container-info.txt
    env | grep -E '^(GITHUB_|ANTHROPIC_|GIT_)' | sort >> container-info.txt 2>&1 || echo 'No relevant environment variables' >> container-info.txt
    echo '=== End Container Information ===' >> container-info.txt
"

extract_file "/workspace/container-info.txt" "container-info.txt" "Container Information"

# Create extraction summary
log "Creating extraction summary..."

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EXTRACTED_FILES=($(find "$OUTPUT_DIR" -maxdepth 2 -type f -name "*.json" -o -name "*.txt" -o -name "*.diff" -o -name "*.log" | sort))

cat > "$OUTPUT_DIR/extraction-summary.json" << EOF
{
  "extraction_info": {
    "timestamp": "$TIMESTAMP",
    "container_name": "$CONTAINER_NAME",
    "output_directory": "$OUTPUT_DIR",
    "extracted_files": [
$(printf '      "%s"' "${EXTRACTED_FILES[@]}" | sed 's|'"$OUTPUT_DIR/"'||g' | paste -sd, -)
    ]
  },
  "workspace_status": {
    "isolation_level": "hybrid",
    "credential_sharing": "read-only",
    "development_environment": "containerized"
  }
}
EOF

# Display summary
echo ""
echo "================================="
echo "EXTRACTION SUMMARY"
echo "================================="
echo "Container: $CONTAINER_NAME"
echo "Output Directory: $OUTPUT_DIR"
echo "Extracted Files: ${#EXTRACTED_FILES[@]}"
echo ""

if [[ -f "$OUTPUT_DIR/execution-report.json" ]]; then
    echo "Execution Status:"
    local success_status=$(jq -r '.success' "$OUTPUT_DIR/execution-report.json" 2>/dev/null || echo "unknown")
    local pr_url=$(jq -r '.pr_url' "$OUTPUT_DIR/execution-report.json" 2>/dev/null || echo "none")
    local duration=$(jq -r '.duration_seconds' "$OUTPUT_DIR/execution-report.json" 2>/dev/null || echo "unknown")
    
    echo "  Success: $success_status"
    echo "  Duration: ${duration}s"
    echo "  PR URL: $pr_url"
    echo ""
fi

echo "Key Files:"
for file in "${EXTRACTED_FILES[@]}"; do
    echo "  - $(basename "$file")"
done

echo ""
echo "Workspace Management:"
echo "  - Container workspace: Isolated volume"
echo "  - Host impact: Zero (outside project directory)"
echo "  - Credential sharing: Read-only mounts"
echo "  - Scalability: Multiple containers supported"

echo ""
success "Result extraction completed successfully!"

# Option to clean up container
read -p "Remove container and workspace volume? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log "Cleaning up container and workspace..."
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
    docker volume rm "${CONTAINER_NAME}-workspace" 2>/dev/null || true
    success "Container and workspace cleaned up"
else
    log "Container preserved for further inspection"
    log "To clean up later: docker stop $CONTAINER_NAME && docker rm $CONTAINER_NAME && docker volume rm ${CONTAINER_NAME}-workspace"
fi