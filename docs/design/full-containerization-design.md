# Full Containerization Design

## Objective
Implement complete environment isolation for the automated development system by moving all operations inside Docker containers, eliminating host machine modifications.

## Architecture

### Current State
```
Host Machine:
├── Claude Code CLI execution
├── Git operations (via shared SSH)
├── File creation (issue-instructions.md)
└── Docker container (dev environment only)
```

### Target State
```
Host Machine:
└── Container orchestration only

Docker Container:
├── Anthropic API integration
├── Git operations (token-based)
├── Swift development environment
├── Complete isolation
└── Structured output/reporting
```

## Components

### 1. Containerized Claude Agent (`claude-agent.py`)
```python
# API-based Claude interaction inside container
import anthropic
import json
import subprocess
import os

class ContainerizedClaude:
    def __init__(self, api_key, issue_data, analysis_data):
        self.client = anthropic.Anthropic(api_key=api_key)
        self.issue = issue_data
        self.analysis = analysis_data
        
    def execute_development_workflow(self):
        # 1. Create branch
        # 2. Implement changes
        # 3. Run quality gates
        # 4. Commit and push
        # 5. Create PR
        pass
```

### 2. Enhanced Container (`Dockerfile.full-isolation`)
```dockerfile
FROM swift:6.0-jammy

# Install additional tools for API interaction
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    jq \
    curl \
    git \
    && pip3 install anthropic requests

# Claude agent script
COPY scripts/claude-agent.py /usr/local/bin/
COPY scripts/container-workflow.sh /usr/local/bin/

# Entry point for isolated execution
ENTRYPOINT ["/usr/local/bin/container-workflow.sh"]
```

### 3. Token-based Git Authentication
```bash
# Inside container
git config --global credential.helper store
echo "https://${GITHUB_TOKEN}:x-oauth-basic@github.com" > ~/.git-credentials
git config --global user.name "${GIT_USER_NAME}"
git config --global user.email "${GIT_USER_EMAIL}"
```

### 4. Container Workflow Script
```bash
#!/bin/bash
# container-workflow.sh - Complete development workflow in container

set -euo pipefail

ISSUE_DATA="/workspace/issue-data.json"
ANALYSIS_DATA="/workspace/analysis-data.json"

# Parse issue information
ISSUE_NUMBER=$(jq -r '.issue_number' "$ISSUE_DATA")
BRANCH_NAME=$(jq -r '.branch_name' "$ISSUE_DATA")

# Execute development workflow
python3 /usr/local/bin/claude-agent.py \
    --issue-data "$ISSUE_DATA" \
    --analysis-data "$ANALYSIS_DATA" \
    --workspace /workspace \
    --output /workspace/execution-report.json
```

## Benefits

### Complete Isolation
- Zero host machine file modifications
- No shared SSH keys or sensitive data
- Each container is a clean slate

### Scalability
- Multiple containers can run simultaneously
- Each issue gets dedicated environment
- Resource allocation per container

### Security
- Token-based authentication only
- No credential file sharing
- Isolated network namespace

### Consistency
- Identical environment every time
- Reproducible builds and tests
- Version-locked dependencies

## Migration Strategy

### Phase 1: API Integration
1. Create `claude-agent.py` for Anthropic API interaction
2. Implement structured conversation flow
3. Test API-based development workflow

### Phase 2: Container Enhancement
1. Update Dockerfile with Python/API tools
2. Add git token configuration
3. Create container workflow scripts

### Phase 3: Orchestration Update
1. Modify `launch-claude-docker.sh` for full isolation
2. Remove host file creation
3. Add container result extraction

### Phase 4: Testing & Validation
1. Test parallel container execution
2. Validate complete isolation
3. Performance benchmarking

## File Structure
```
scripts/
├── claude-auto-issue.sh              # Main orchestrator (updated)
├── launch-claude-docker.sh           # Full container launch (updated)
├── claude-agent.py                   # NEW: API-based Claude interaction
├── container-workflow.sh             # NEW: Complete workflow in container
├── Dockerfile.full-isolation         # NEW: Enhanced container
└── extract-container-results.sh     # NEW: Result extraction
```

## Configuration Updates

### Environment Variables (Container)
```bash
ANTHROPIC_API_KEY=<api-key>
GITHUB_TOKEN=<github-token>
GIT_USER_NAME=<git-name>
GIT_USER_EMAIL=<git-email>
```

### Container Volumes
```bash
# Input only (read-only)
-v "$(pwd):/workspace:ro"

# Output volume (isolated)
-v "container-output:/output"
```

## Expected Outcomes

### Host Impact: Zero
- No file creation outside project directory
- No credential sharing
- No process execution on host

### Container Impact: Complete
- All development operations
- Git history and commits
- Quality gate execution
- PR creation and monitoring

### Scalability: High
- Parallel issue processing
- Resource isolation
- Independent failure domains