# Claude Auto Issue - Intelligent GitHub Issue Processing with Ultra Think

This system automatically fetches GitHub issue content, performs deep strategic analysis with **Ultra Think**, launches Claude Code on your host system, and creates pull requests with enhanced intelligence.

## Setup

### Prerequisites

1. **Claude Code** - Install from https://claude.ai/code
2. **Docker Desktop** - Optional, for isolated development environment
3. **GitHub CLI** - For GitHub API access
   ```bash
   brew install gh
   gh auth login
   ```
4. **jq** - For JSON processing
   ```bash
   brew install jq
   ```
5. **Anthropic API Key** - Set as environment variable
   ```bash
   export ANTHROPIC_API_KEY="your-api-key"
   ```

### Installation

1. Make scripts executable:
   ```bash
   chmod +x scripts/*.sh
   ```

2. Build the dev container image (optional, for isolated environment):
   ```bash
   docker build -t felangkit-dev -f .devcontainer/Dockerfile .
   ```

## Usage

### Basic Usage

```bash
./scripts/claude-auto-issue.sh https://github.com/owner/repo/issues/123
```

### Example

```bash
./scripts/claude-auto-issue.sh https://github.com/fumiya-kume/FeLangKit/issues/87
```

## How It Works

1. **Issue Fetching** (`fetch-issue.sh`)
   - Extracts issue details using GitHub CLI
   - Creates structured JSON with issue data
   - Generates branch name and PR title

2. **🧠 Ultra Think Analysis** (`ultrathink-analysis.sh`) **NEW!**
   - **Complexity Assessment**: Analyzes issue scope, keywords, and estimated effort
   - **Codebase Impact**: Identifies affected modules and potential files
   - **Strategic Planning**: Generates implementation approaches with risk/effort analysis
   - **Risk Assessment**: Identifies potential problems and mitigation strategies
   - **Implementation Roadmap**: Creates detailed task breakdown with time estimates

3. **Enhanced Claude Code Launch** (`launch-claude-docker.sh`)
   - Creates comprehensive instruction file enriched with Ultra Think analysis
   - Starts Docker container with shared credentials (GitHub, SSH, AWS, etc.)
   - Launches Claude Code on the host with strategic guidance and project context
   - Tests authentication and provides container usage examples

4. **PR Creation** (`create-pr.sh`)
   - Waits for Claude Code completion
   - Validates branch and commits
   - Creates pull request with proper formatting
   - Watches PR checks

## Configuration

Edit `scripts/claude-auto-config.json` to customize:

- **Docker settings**: Image name, timeouts, cleanup
- **Git settings**: Base branch, branch naming, commit format
- **GitHub settings**: PR templates, auto-creation
- **Quality gates**: Required commands, error handling
- **Claude settings**: Instruction templates, auto-start
- **Logging**: Level, formatting, colors

## Environment Variables

- `ANTHROPIC_API_KEY` - Required for Claude Code
- `GITHUB_TOKEN` - Optional, uses `gh` CLI auth by default

## Credential Sharing

The Docker container automatically shares credentials from your host:

### Automatically Shared
- **Git Configuration**: `~/.gitconfig` mounted read-only
- **SSH Keys**: `~/.ssh/` mounted read-only with proper permissions
- **GitHub CLI**: `~/.config/gh/` authentication shared
- **SSH Agent**: Forwarded for seamless git operations
- **Docker Credentials**: `~/.docker/` shared if available
- **AWS Credentials**: `~/.aws/` shared if available
- **Claude Settings**: `~/.claude/` shared if available (includes settings.local.json)

### Environment Variables
- `ANTHROPIC_API_KEY` - Anthropic API access
- `GITHUB_TOKEN` - GitHub API access (if set)
- `SSH_AUTH_SOCK` - SSH agent socket forwarding
- System variables: `USER`, `HOME`, `LANG`, `LC_ALL`, `TZ`

### Testing Authentication
The system automatically tests authentication when starting the container. You can also run a standalone test:

```bash
# Run comprehensive credential test
./scripts/test-credentials.sh

# Test with specific container name
./scripts/test-credentials.sh my-test-container
```

Tests include:
- Git configuration
- SSH access to GitHub
- GitHub CLI authentication  
- Anthropic API key availability
- Claude settings file sharing
- Swift build functionality
- Git repository operations

### Using Container Commands
With shared credentials, you can run authenticated commands in the container:
```bash
docker exec <container-name> git status
docker exec <container-name> gh auth status
docker exec <container-name> gh pr list
docker exec <container-name> ssh -T git@github.com
docker exec <container-name> ls -la ~/.claude/  # Check Claude settings
```

## 🧠 Ultra Think Analysis Features

Ultra Think performs comprehensive pre-implementation analysis:

### 📊 Complexity Assessment
- **Keyword Analysis**: Detects architectural, performance, and testing keywords
- **Label Processing**: Analyzes GitHub issue labels for complexity indicators
- **Effort Estimation**: Predicts time requirements (1-8+ hours)
- **Complexity Levels**: Simple → Moderate → Complex → Architectural

### 🎯 Codebase Impact Analysis
- **Module Detection**: Identifies affected components (Tokenizer, Parser, Expression, etc.)
- **File Estimation**: Predicts which files need changes
- **Backwards Compatibility**: Assesses potential breaking changes
- **Test Requirements**: Determines testing scope needed

### 🛡️ Risk Assessment
- **Architecture Risks**: Large-scale change detection
- **Compatibility Risks**: Breaking change identification  
- **Performance Risks**: Performance-critical change warnings
- **Scope Risks**: Multi-module impact analysis

### 📈 Strategic Planning
- **Implementation Strategies**: Multiple approaches with effort/risk trade-offs
- **Recommended Approach**: AI-selected optimal strategy
- **Quality Gates**: Customized validation requirements
- **Architectural Considerations**: Best practices and patterns

### 🗺️ Implementation Roadmap
- **Task Breakdown**: Detailed step-by-step implementation plan
- **Time Estimates**: Per-task and total time predictions
- **Dependencies**: Task ordering and prerequisites
- **Acceptance Criteria**: Clear success metrics

## Project Structure

```
scripts/
├── claude-auto-issue.sh      # Main orchestration script
├── fetch-issue.sh            # GitHub issue fetcher
├── ultrathink-analysis.sh    # 🧠 Ultra Think analysis engine (NEW!)
├── launch-claude-docker.sh   # Enhanced Docker launcher with analysis integration
├── create-pr.sh              # PR automation
├── test-credentials.sh       # Credential sharing test utility
├── claude-auto-config.json   # Configuration file
└── README.md                 # This file
```

## Enhanced Workflow with Ultra Think

1. **Issue Analysis**: Fetches issue content and metadata
2. **🧠 Ultra Think Analysis**: Deep strategic analysis and planning
   - Complexity assessment and time estimation
   - Risk identification and mitigation planning
   - Module impact analysis and file predictions
   - Strategic approach selection and task breakdown
3. **Branch Creation**: Generates branch name following convention
4. **Enhanced Container Launch**: Starts Docker with shared credentials + analysis
5. **Strategic Development**: Claude Code works with Ultra Think guidance
   - Pre-analyzed complexity and risk awareness
   - Detailed implementation roadmap
   - Module-specific focus areas
   - Quality gates tailored to issue complexity
6. **Quality Gates**: Runs tests and linting (host or container)
7. **PR Creation**: Automatically creates pull request with authentication
8. **Monitoring**: Watches PR checks and status

### 🎯 Ultra Think Benefits
- **Faster Implementation**: Strategic guidance reduces trial-and-error
- **Higher Quality**: Risk-aware development prevents common pitfalls
- **Better Planning**: Time estimates and task breakdown improve workflow
- **Parallel Processing**: Each issue gets independent analysis for concurrent execution

## Troubleshooting

### Common Issues

1. **Docker not running**
   ```bash
   # Start Docker Desktop
   open -a Docker
   ```

2. **GitHub authentication**
   ```bash
   gh auth login
   gh auth status
   ```

3. **Missing dependencies**
   ```bash
   brew install gh jq
   ```

4. **Container build fails**
   ```bash
   docker build -t felangkit-dev -f .devcontainer/Dockerfile .
   ```

5. **SSH authentication in container**
   ```bash
   # Check SSH agent is running
   echo $SSH_AUTH_SOCK
   ssh-add -l
   
   # Test SSH access
   docker exec <container-name> ssh -T git@github.com
   ```

6. **GitHub CLI authentication in container**
   ```bash
   # Check host authentication
   gh auth status
   
   # Test container authentication
   docker exec <container-name> gh auth status
   ```

7. **Permission issues with mounted files**
   ```bash
   # The container automatically fixes SSH permissions
   # If issues persist, check host permissions:
   chmod 700 ~/.ssh
   chmod 600 ~/.ssh/id_*
   ```

### Debug Mode

Run with bash debug mode:
```bash
bash -x ./scripts/claude-auto-issue.sh <issue-url>
```

### Manual Cleanup

If containers get stuck:
```bash
docker ps -a | grep claude-auto
docker stop <container-name>
docker rm <container-name>
```

## Security Notes

- Scripts use temporary files that are cleaned up automatically
- Git credentials are mounted read-only
- API keys are passed as environment variables
- No sensitive data is logged or persisted

## Integration

This system integrates with the existing FeLangKit development workflow:

- Uses the project's dev container configuration
- Follows CLAUDE.md conventions and guidelines
- Runs the standard quality gates before commits
- Creates branches and PRs using project conventions
- Monitors CI/CD pipeline status