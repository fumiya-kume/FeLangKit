# Scripts Directory - Automated Development System

This directory contains the automated development system for processing GitHub issues with intelligent analysis and containerized execution.

## 📁 Directory Structure

After cleanup and reorganization:

```
scripts/
├── core/                           # Essential automation pipeline
│   ├── claude-auto-issue.sh       # Main orchestration script
│   ├── fetch-issue.sh             # GitHub issue data extraction
│   ├── ultrathink-analysis.sh     # 🧠 Strategic analysis engine
│   └── create-pr.sh               # PR automation
├── container/                      # Container management
│   ├── launch.sh                  # Unified container launcher (hybrid/host/isolated)
│   ├── workflow.sh                # Containerized development workflow
│   ├── extract-results.sh         # Result extraction and cleanup
│   └── test-credentials.sh        # Authentication testing
├── experimental/                   # Work-in-progress features
│   └── claude-agent.py            # API-based Claude integration
├── config/                        # Configuration files
│   └── claude-auto-config.json    # System configuration
└── docs/                          # Documentation
    └── README.md                  # This file
```

## 🚀 Quick Start

### Basic Usage (Automated)
```bash
# Process any GitHub issue automatically
./scripts/core/claude-auto-issue.sh https://github.com/owner/repo/issues/123
```

### Container Modes
```bash
# Hybrid isolation (recommended) - shared credentials + isolated workspace
./scripts/container/launch.sh hybrid issue-data.json analysis.json my-container

# Host mode (legacy) - Claude on host + dev container
./scripts/container/launch.sh host issue-data.json analysis.json dev-container

# Full isolation (experimental) - API-based Claude in container
./scripts/container/launch.sh isolated issue-data.json analysis.json iso-container
```

## 🧠 Ultra Think Analysis

The system performs comprehensive pre-implementation analysis:

### 📊 Analysis Stages
1. **Complexity Assessment**: Keywords, labels, effort estimation
2. **Codebase Impact**: Module detection, file predictions, compatibility
3. **Strategic Planning**: Implementation approaches, best practices
4. **Risk Assessment**: Risk identification and mitigation strategies
5. **Implementation Roadmap**: Task breakdown with time estimates

### 🎯 Benefits
- **Faster Implementation**: Strategic guidance reduces trial-and-error
- **Higher Quality**: Risk-aware development prevents common pitfalls
- **Better Planning**: Time estimates and task breakdown improve workflow
- **Parallel Processing**: Independent analysis enables concurrent execution

## 🏗️ Container Isolation Modes

### Hybrid Mode (Recommended)
- **Shared Credentials**: Read-only mounts for Git, SSH, GitHub CLI
- **Isolated Workspace**: Dedicated volume per container
- **Zero Host Impact**: No files created outside project
- **Scalable**: Multiple containers run simultaneously

### Host Mode (Legacy)
- **Host Execution**: Claude Code runs on host machine
- **Dev Container**: Supporting development environment
- **Credential Sharing**: Full access to host credentials

### Isolated Mode (Experimental)
- **Complete Isolation**: API-based Claude integration
- **Minimal Host Contact**: Only essential environment variables
- **Token-based Auth**: GitHub token authentication only

## 📋 Core Components

### 1. Main Orchestrator (`core/claude-auto-issue.sh`)
Central coordinator managing the entire workflow:
- URL validation and parsing
- Component orchestration  
- Error handling and cleanup
- Logging and status reporting

### 2. Issue Fetcher (`core/fetch-issue.sh`)
Extracts GitHub issue data using GitHub CLI:
- Structured JSON output
- Metadata extraction (labels, assignees, milestones)
- Branch name generation
- PR title formatting

### 3. Ultra Think Analyzer (`core/ultrathink-analysis.sh`)
Performs strategic analysis before implementation:
- Complexity scoring and level classification
- Module impact analysis and file predictions
- Risk assessment with mitigation strategies
- Implementation roadmap with time estimates

### 4. Container Launcher (`container/launch.sh`)
Unified launcher supporting multiple isolation modes:
- Credential sharing configuration
- Container lifecycle management
- Authentication testing
- Development environment setup

### 5. PR Creator (`core/create-pr.sh`)
Manages pull request creation:
- Branch validation
- Commit verification
- PR formatting with templates
- CI/CD monitoring

## 🔐 Security & Credentials

### What's Shared (Read-Only)
- Git configuration (`~/.gitconfig`)
- SSH keys (`~/.ssh/`)
- GitHub CLI auth (`~/.config/gh/`)
- Claude settings (`~/.claude/`)
- Environment variables (API keys)

### What's Protected
- No write access to host credentials
- Temporary containers with automatic cleanup
- No credential logging or persistence
- SSH agent socket forwarding (not key copying)

### Authentication Testing
```bash
# Test all credential sharing
./scripts/container/test-credentials.sh

# Test with specific container
./scripts/container/test-credentials.sh my-container
```

## ⚙️ Configuration

### System Configuration (`config/claude-auto-config.json`)
```json
{
  "docker": {
    "image_name": "felangkit-dev",
    "container_timeout": 3600,
    "auto_cleanup": true
  },
  "git": {
    "base_branch": "master",
    "branch_prefix": "issue-",
    "commit_format": "conventional"
  },
  "github": {
    "auto_create_pr": true,
    "watch_pr_checks": true
  },
  "quality_gates": {
    "required_commands": [
      "swiftlint lint --fix",
      "swiftlint lint",
      "swift build", 
      "swift test"
    ]
  }
}
```

### Environment Variables
```bash
export ANTHROPIC_API_KEY="your-api-key"     # Required for Claude integration
export GITHUB_TOKEN="your-token"            # Optional, uses gh CLI auth by default
```

## 🔧 Development Workflows

### Standard Issue Processing
1. **Issue Selection**: Choose GitHub issue URL
2. **Ultra Think Analysis**: Strategic analysis and planning
3. **Container Launch**: Isolated development environment
4. **Development**: AI-assisted implementation
5. **Quality Gates**: Tests, linting, build validation
6. **PR Creation**: Automatic pull request generation
7. **Monitoring**: CI/CD pipeline tracking

### Manual Development
```bash
# Fetch issue data
./scripts/core/fetch-issue.sh <url> issue-data.json

# Run strategic analysis
./scripts/core/ultrathink-analysis.sh issue-data.json analysis.json

# Launch development container
./scripts/container/launch.sh hybrid issue-data.json analysis.json dev-container

# Use container for development
docker exec dev-container swift build
docker exec dev-container swift test
docker exec dev-container git status

# Extract results
./scripts/container/extract-results.sh dev-container ./results

# Create PR
./scripts/core/create-pr.sh issue-data.json dev-container
```

## 🧪 Testing & Validation

### System Testing
```bash
# Test credential sharing
./scripts/container/test-credentials.sh

# Debug mode
bash -x ./scripts/core/claude-auto-issue.sh <url>

# Component testing
./scripts/core/fetch-issue.sh <url> /tmp/test.json
./scripts/core/ultrathink-analysis.sh /tmp/test.json /tmp/analysis.json
```

### Container Testing
```bash
# Enter container for debugging
docker exec -it <container> bash

# Check container logs
docker logs <container>

# Test authentication in container
docker exec <container> gh auth status
docker exec <container> ssh -T git@github.com
```

## 🏥 Troubleshooting

### Common Issues

#### Docker Not Running
```bash
# Start Docker Desktop
open -a Docker

# Verify Docker
docker info
```

#### GitHub Authentication
```bash
# Check host auth
gh auth status
gh auth login

# Test in container
docker exec <container> gh auth status
```

#### SSH Issues
```bash
# Check SSH agent
echo $SSH_AUTH_SOCK
ssh-add -l

# Test GitHub access
ssh -T git@github.com
```

#### Permission Problems
```bash
# Fix SSH permissions
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_*
```

### Debug Commands
```bash
# Verbose execution
bash -x ./scripts/core/claude-auto-issue.sh <url>

# Container inspection
docker inspect <container>
docker logs <container>

# Manual cleanup
docker stop <container>
docker rm <container>
docker volume rm <container>-workspace
```

## 📈 Benefits of Reorganized Structure

### Before Cleanup
- 13 files in flat structure
- Overlapping functionality (multiple Docker launchers)
- Inconsistent naming patterns
- Mixed documentation files

### After Cleanup  
- Logical categorization (core/container/experimental/config/docs)
- Unified container launcher with mode selection
- Consistent naming conventions
- Consolidated documentation
- Clear separation of concerns

### Improvements Achieved
- **Reduced Complexity**: 13 → 10 files with consolidated functionality
- **Better Organization**: 5 logical categories vs flat structure
- **Enhanced Maintainability**: Clear ownership and purposes
- **Improved Usability**: Single entry point for each workflow
- **Future-Proofing**: Experimental vs stable separation

## 🚀 Scalability Features

### Parallel Processing
```bash
# Multiple issues simultaneously
./scripts/core/claude-auto-issue.sh https://github.com/owner/repo/issues/123 &
./scripts/core/claude-auto-issue.sh https://github.com/owner/repo/issues/124 &
./scripts/core/claude-auto-issue.sh https://github.com/owner/repo/issues/125 &
```

### Resource Management
- **Isolated workspace volumes** prevent conflicts
- **Independent container lifecycles**
- **Automatic cleanup** options
- **Resource limits** can be applied per container

### Error Isolation
- **Container failures** don't affect host or other containers
- **Independent retry** mechanisms per issue
- **Separate logging** and result tracking
- **Clean failure recovery** with preserved workspace

## 🎯 Migration Guide

### For Existing Users
The reorganization maintains backward compatibility through:

1. **Symbolic Links**: Old script paths still work during transition
2. **Gradual Migration**: New structure can be adopted incrementally
3. **Documentation**: Clear migration paths provided

### Migration Steps
1. **Backup current setup**: System creates automatic backup
2. **Update script calls**: Change paths to new structure
3. **Test new workflow**: Verify functionality with sample issue
4. **Remove old scripts**: Clean up deprecated files when ready

### Path Updates
```bash
# Old paths
./scripts/claude-auto-issue.sh → ./scripts/core/claude-auto-issue.sh
./scripts/launch-claude-docker-hybrid.sh → ./scripts/container/launch.sh hybrid

# New unified launcher
./scripts/container/launch.sh <mode> <issue-data> <analysis> <container>
```

## 📚 Additional Resources

- **Ultra Think Analysis Guide**: See analysis output examples and strategic planning
- **Container Configuration**: Advanced Docker setup and credential management  
- **Security Best Practices**: Credential sharing and isolation guidelines
- **Integration Examples**: CI/CD, webhooks, and automation setups

## 🔄 Maintenance

### Regular Tasks
- **Weekly**: Update container images, test authentication
- **Monthly**: Update dependencies, review configurations
- **As Needed**: Update templates, adjust quality gates

### Health Checks
```bash
# System health
./scripts/container/test-credentials.sh

# Dependencies
gh version && jq --version && docker version

# Container usage
docker system df
docker image ls
```

This reorganized scripts directory provides a clean, scalable foundation for automated development with clear separation of concerns and improved maintainability.