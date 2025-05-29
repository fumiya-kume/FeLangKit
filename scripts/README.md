# Claude Auto Issue - Automated GitHub Issue Processing

This system automatically fetches GitHub issue content, launches Claude Code on your host system, and creates pull requests.

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

2. **Claude Code Launch** (`launch-claude-docker.sh`)
   - Creates instruction file for the issue
   - Starts Docker container with shared credentials (GitHub, SSH, AWS, etc.)
   - Launches Claude Code on the host with project context
   - Tests authentication and provides container usage examples

3. **PR Creation** (`create-pr.sh`)
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

## Project Structure

```
scripts/
├── claude-auto-issue.sh      # Main orchestration script
├── fetch-issue.sh            # GitHub issue fetcher
├── launch-claude-docker.sh   # Docker container launcher with credential sharing
├── create-pr.sh              # PR automation
├── test-credentials.sh       # Credential sharing test utility
├── claude-auto-config.json   # Configuration file
└── README.md                 # This file
```

## Workflow

1. **Issue Analysis**: Fetches issue content and metadata
2. **Branch Creation**: Generates branch name following convention
3. **Container Launch**: Starts Docker with shared credentials
4. **Development**: Claude Code works on the issue (host) + container available for commands
5. **Quality Gates**: Runs tests and linting (host or container)
6. **PR Creation**: Automatically creates pull request with authentication
7. **Monitoring**: Watches PR checks and status

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