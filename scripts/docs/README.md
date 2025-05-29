# Scripts Directory - Automated Development System

This directory contains the automated development system for processing GitHub issues with intelligent analysis and containerized execution.

## 🚀 Quick Start

### One-Command Issue Processing
```bash
# Process any GitHub issue automatically with claude.sh
./scripts/claude.sh issue https://github.com/owner/repo/issues/123
```

### Manual Development
```bash
# Launch development container
./scripts/claude.sh dev hybrid my-container

# Test system components
./scripts/claude.sh test

# Check system status
./scripts/claude.sh status
```

## 📁 Directory Structure

```
scripts/
├── claude.sh                      # 🎯 Easy-to-use wrapper for all commands
├── core/                          # Essential automation pipeline
│   ├── claude-auto-issue.sh      # Main orchestration script
│   ├── fetch-issue.sh            # GitHub issue data extraction
│   ├── ultrathink-analysis.sh    # 🧠 Strategic analysis engine
│   └── create-pr.sh              # PR automation
├── container/                     # Container management
│   ├── launch.sh                 # Unified container launcher (hybrid/host/isolated)
│   ├── workflow.sh               # Containerized development workflow
│   ├── extract-results.sh        # Result extraction and cleanup
│   └── test-credentials.sh       # Authentication testing
├── experimental/                  # Work-in-progress features
│   └── claude-agent.py           # API-based Claude integration
├── config/                       # Configuration files
│   └── claude-auto-config.json   # System configuration
└── docs/                         # Documentation
    └── README.md                 # This file
```

## 🎯 Claude.sh - Unified Interface

The `claude.sh` script provides a simple, consistent interface to all automation features:

### Primary Commands
```bash
# Issue processing
./scripts/claude.sh issue <url>           # Full automated processing
./scripts/claude.sh fetch <url> <file>    # Fetch issue data only
./scripts/claude.sh analyze <in> <out>    # Ultra Think analysis only

# Container management  
./scripts/claude.sh dev <mode> <name>     # Launch development container
./scripts/claude.sh ps                    # List active containers
./scripts/claude.sh cleanup <container>   # Clean up container

# System tools
./scripts/claude.sh test                  # Test authentication/system
./scripts/claude.sh status                # Show system status
./scripts/claude.sh config                # Show configuration
```

### Help System
```bash
./scripts/claude.sh help                  # General help
./scripts/claude.sh help issue            # Detailed command help
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

### Isolated Mode (Experimental)
- **Complete Isolation**: API-based Claude integration
- **Token-based Auth**: GitHub token authentication only

## 🔐 Security & Credentials

### Shared Resources (Read-Only)
- Git configuration (`~/.gitconfig`)
- SSH keys (`~/.ssh/`)
- GitHub CLI auth (`~/.config/gh/`)
- Claude settings (`~/.claude/`)
- Environment variables (API keys)

### Security Features
- No write access to host credentials
- Temporary containers with automatic cleanup
- No credential logging or persistence
- SSH agent socket forwarding (not key copying)

## ⚙️ Configuration

### Prerequisites
```bash
# Install dependencies
brew install gh jq swiftlint

# Authenticate with GitHub
gh auth login

# Set Anthropic API key
export ANTHROPIC_API_KEY="your-api-key"
```

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

## 🔧 Development Workflows

### Automated Workflow (Recommended)
```bash
# Single command processes entire issue
./scripts/claude.sh issue https://github.com/owner/repo/issues/123
```

**Pipeline**: Issue fetch → Ultra Think analysis → Container launch → Development → Quality gates → PR creation → CI monitoring

### Manual Workflow
```bash
# Step-by-step control
./scripts/claude.sh fetch <url> issue-data.json
./scripts/claude.sh analyze issue-data.json analysis.json
./scripts/claude.sh dev hybrid my-container issue-data.json analysis.json
./scripts/claude.sh extract my-container ./results
./scripts/claude.sh pr issue-data.json my-container
```

### Container Development
```bash
# Work inside container
docker exec my-container swift build
docker exec my-container swift test
docker exec my-container git status

# Or enter container interactively
docker exec -it my-container bash
```

## 🧪 Testing & Debugging

### System Testing
```bash
# Comprehensive system test
./scripts/claude.sh test

# Test specific container
./scripts/claude.sh test my-container

# Check system status
./scripts/claude.sh status
```

### Debugging
```bash
# Verbose execution
bash -x ./scripts/claude.sh issue <url>

# Check container logs
./scripts/claude.sh logs my-container

# Manual container inspection
docker inspect my-container
docker exec my-container env
```

## 🏥 Troubleshooting

### Common Issues

#### Docker Not Running
```bash
# Start Docker Desktop
open -a Docker

# Verify
docker info
```

#### Authentication Problems
```bash
# GitHub CLI
gh auth status
gh auth login

# SSH keys
ssh -T git@github.com
ssh-add -l
```

#### Container Issues
```bash
# Clean up problematic container
./scripts/claude.sh cleanup my-container

# Check Docker resources
docker system df
docker system prune
```

## 🚀 Scalability & Performance

### Parallel Processing
```bash
# Process multiple issues simultaneously
./scripts/claude.sh issue https://github.com/owner/repo/issues/123 &
./scripts/claude.sh issue https://github.com/owner/repo/issues/124 &
./scripts/claude.sh issue https://github.com/owner/repo/issues/125 &
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

## 📈 Cleanup Benefits (Ultra Think Implementation)

### Transformation Results
- **File Count**: 13 → 10 files (-23% reduction)
- **Structure**: Flat → 5 logical categories
- **Functionality**: Eliminated duplicate container launchers
- **Documentation**: Consolidated 2 files → 1 comprehensive guide

### Organization Improvements
- **Clear Ownership**: Each category has specific purpose
- **Reduced Complexity**: Unified container launcher
- **Enhanced Maintainability**: Logical separation of concerns
- **Future-Proofing**: Experimental vs stable separation

## 🔄 Maintenance

### Health Checks
```bash
# System health
./scripts/claude.sh status

# Dependencies
gh version && jq --version && docker version

# Container cleanup
docker system prune
```

### Regular Tasks
- **Weekly**: Update container images, test authentication
- **Monthly**: Update dependencies, review configurations
- **As Needed**: Update templates, adjust quality gates

This reorganized scripts directory provides a clean, scalable foundation for automated development with `claude.sh` as the primary interface for all operations.