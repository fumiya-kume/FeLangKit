#!/bin/bash

# Claude.sh - Easy-to-use wrapper for FeLangKit's automated development system
# Usage: ./scripts/claude.sh <command> [args...]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
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
${CYAN}Claude.sh - FeLangKit Automated Development System${NC}

${YELLOW}QUICK COMMANDS:${NC}
  ${GREEN}./scripts/claude.sh issue <url>${NC}           Process GitHub issue automatically
  ${GREEN}./scripts/claude.sh dev <mode> <container>${NC}   Launch development container
  ${GREEN}./scripts/claude.sh test${NC}                    Test system components

${YELLOW}AVAILABLE COMMANDS:${NC}

${PURPLE}📋 Issue Processing:${NC}
  ${GREEN}issue <github-issue-url>${NC}          Fully automated issue processing
  ${GREEN}fetch <url> <output-file>${NC}         Fetch issue data only
  ${GREEN}analyze <issue-file> <output>${NC}     Run Ultra Think analysis only
  ${GREEN}pr <issue-file> <container>${NC}       Create PR from container results

${PURPLE}🐳 Container Management:${NC}
  ${GREEN}dev <mode> <container-name>${NC}       Launch development container
      Modes: hybrid (recommended), host, isolated
  ${GREEN}extract <container> <output-dir>${NC}  Extract container results
  ${GREEN}cleanup <container>${NC}               Clean up specific container
  ${GREEN}ps${NC}                               List active containers

${PURPLE}🔧 System Tools:${NC}
  ${GREEN}test${NC}                             Test authentication and system
  ${GREEN}validate <container>${NC}             Validate container workflow completion
  ${GREEN}config${NC}                          Show current configuration
  ${GREEN}status${NC}                          Show system status
  ${GREEN}logs <container>${NC}                 Show container logs

${PURPLE}📖 Information:${NC}
  ${GREEN}help${NC}                            Show this help message
  ${GREEN}docs${NC}                            Open documentation
  ${GREEN}version${NC}                         Show version information

${YELLOW}EXAMPLES:${NC}
  ${CYAN}# Process an issue automatically${NC}
  ./scripts/claude.sh issue https://github.com/owner/repo/issues/123

  ${CYAN}# Launch hybrid development container${NC}
  ./scripts/claude.sh dev hybrid my-dev-container

  ${CYAN}# Test system authentication${NC}
  ./scripts/claude.sh test

  ${CYAN}# Check active containers${NC}
  ./scripts/claude.sh ps

${YELLOW}NOTES:${NC}
  - Most commands require Docker to be running
  - GitHub authentication via 'gh auth login' is required
  - For help with specific commands, use: ./scripts/claude.sh help <command>
EOF
}

detailed_help() {
    local command="$1"
    case "$command" in
        issue)
            cat << EOF
${CYAN}Issue Processing Command${NC}

${YELLOW}Usage:${NC} ./scripts/claude.sh issue <github-issue-url>

${YELLOW}Description:${NC}
Fully automated GitHub issue processing pipeline that:
1. Fetches issue data and metadata
2. Performs Ultra Think strategic analysis  
3. Launches development container with hybrid isolation
4. Executes AI-assisted development workflow
5. Extracts results and creates pull request

${YELLOW}Examples:${NC}
  ./scripts/claude.sh issue https://github.com/fumiya-kume/FeLangKit/issues/87
  ./scripts/claude.sh issue https://github.com/owner/repo/issues/123

${YELLOW}Requirements:${NC}
  - Valid GitHub issue URL
  - GitHub CLI authentication (gh auth login)
  - Docker running
  - ANTHROPIC_API_KEY environment variable
EOF
            ;;
        dev)
            cat << EOF
${CYAN}Development Container Command${NC}

${YELLOW}Usage:${NC} ./scripts/claude.sh dev <mode> <container-name> [issue-file] [analysis-file]

${YELLOW}Modes:${NC}
  ${GREEN}hybrid${NC}     - Recommended: Shared credentials + isolated workspace
  ${GREEN}host${NC}       - Legacy: Claude on host + dev container  
  ${GREEN}isolated${NC}   - Experimental: Full API-based isolation

${YELLOW}Examples:${NC}
  ./scripts/claude.sh dev hybrid my-container
  ./scripts/claude.sh dev hybrid dev-123 issue-data.json analysis.json
  ./scripts/claude.sh dev host legacy-container

${YELLOW}Features:${NC}
  - Automatic credential sharing (read-only)
  - Isolated workspace volumes
  - Swift development environment
  - GitHub CLI and SSH access
EOF
            ;;
        test)
            cat << EOF
${CYAN}System Testing Command${NC}

${YELLOW}Usage:${NC} ./scripts/claude.sh test [container-name]

${YELLOW}Description:${NC}
Comprehensive testing of:
- Docker connectivity
- GitHub CLI authentication
- SSH key access
- Container credential sharing
- System dependencies

${YELLOW}Examples:${NC}
  ./scripts/claude.sh test
  ./scripts/claude.sh test my-container

${YELLOW}Output:${NC}
Shows detailed status of all system components
EOF
            ;;
        *)
            echo "No detailed help available for: $command"
            echo "Use './scripts/claude.sh help' for general usage"
            ;;
    esac
}

validate_dependencies() {
    local missing=()
    
    if ! command -v docker &> /dev/null; then
        missing+=("docker")
    fi
    
    if ! command -v gh &> /dev/null; then
        missing+=("gh (GitHub CLI)")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing+=("jq")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing dependencies: ${missing[*]}"
        echo "Install with: brew install ${missing[*]// (GitHub CLI)/}"
        return 1
    fi
    
    # Check Docker is running
    if ! docker info &> /dev/null; then
        error "Docker is not running. Please start Docker Desktop."
        return 1
    fi
    
    return 0
}

show_status() {
    log "System Status Check"
    echo
    
    # Docker status
    if docker info &> /dev/null; then
        success "✓ Docker: Running"
    else
        error "✗ Docker: Not running"
    fi
    
    # GitHub CLI status
    if gh auth status &> /dev/null; then
        success "✓ GitHub CLI: Authenticated"
    else
        warn "⚠ GitHub CLI: Not authenticated (run 'gh auth login')"
    fi
    
    # Anthropic API key
    if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        success "✓ Anthropic API: Key configured"
    else
        warn "⚠ Anthropic API: Key not set (export ANTHROPIC_API_KEY)"
    fi
    
    # Active containers
    local active_containers
    active_containers=$(docker ps --filter "name=claude-" --format "table {{.Names}}\t{{.Status}}" 2>/dev/null || echo "")
    if [[ -n "$active_containers" && "$active_containers" != "NAMES	STATUS" ]]; then
        echo
        log "Active Claude containers:"
        echo "$active_containers"
    else
        log "No active Claude containers"
    fi
}

show_config() {
    log "Current Configuration"
    echo
    
    local config_file="${SCRIPT_DIR}/config/claude-auto-config.json"
    if [[ -f "$config_file" ]]; then
        echo "Configuration file: $config_file"
        echo
        jq . "$config_file" 2>/dev/null || cat "$config_file"
    else
        warn "Configuration file not found: $config_file"
    fi
}

list_containers() {
    log "Container Status"
    echo
    
    # All containers with claude in name
    local containers
    containers=$(docker ps -a --filter "name=claude" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" 2>/dev/null || echo "")
    
    if [[ -n "$containers" && "$containers" != "NAMES	STATUS	IMAGE" ]]; then
        echo "$containers"
    else
        log "No Claude containers found"
    fi
}

main() {
    local command="${1:-help}"
    
    case "$command" in
        help|--help|-h)
            if [[ $# -gt 1 ]]; then
                detailed_help "$2"
            else
                usage
            fi
            ;;
        
        issue)
            if [[ $# -lt 2 ]]; then
                error "GitHub issue URL required"
                echo "Usage: ./scripts/claude.sh issue <github-issue-url>"
                exit 1
            fi
            validate_dependencies
            log "Starting automated issue processing..."
            exec "${SCRIPT_DIR}/core/claude-auto-issue.sh" "$2"
            ;;
            
        fetch)
            if [[ $# -lt 3 ]]; then
                error "URL and output file required"
                echo "Usage: ./scripts/claude.sh fetch <url> <output-file>"
                exit 1
            fi
            validate_dependencies
            exec "${SCRIPT_DIR}/core/fetch-issue.sh" "$2" "$3"
            ;;
            
        analyze)
            if [[ $# -lt 3 ]]; then
                error "Issue file and output file required"
                echo "Usage: ./scripts/claude.sh analyze <issue-file> <output-file>"
                exit 1
            fi
            exec "${SCRIPT_DIR}/core/ultrathink-analysis.sh" "$2" "$3"
            ;;
            
        dev)
            if [[ $# -lt 3 ]]; then
                error "Mode and container name required"
                echo "Usage: ./scripts/claude.sh dev <mode> <container-name> [issue-file] [analysis-file]"
                echo "Modes: hybrid, host, isolated"
                exit 1
            fi
            validate_dependencies
            local mode="$2"
            local container="$3"
            local issue_file="${4:-}"
            local analysis_file="${5:-}"
            
            if [[ -n "$issue_file" && -n "$analysis_file" ]]; then
                exec "${SCRIPT_DIR}/container/launch.sh" "$mode" "$issue_file" "$analysis_file" "$container"
            else
                exec "${SCRIPT_DIR}/container/launch.sh" "$mode" "" "" "$container"
            fi
            ;;
            
        extract)
            if [[ $# -lt 3 ]]; then
                error "Container name and output directory required"
                echo "Usage: ./scripts/claude.sh extract <container> <output-dir>"
                exit 1
            fi
            validate_dependencies
            exec "${SCRIPT_DIR}/container/extract-results.sh" "$2" "$3"
            ;;
            
        pr)
            if [[ $# -lt 3 ]]; then
                error "Issue file and container name required"
                echo "Usage: ./scripts/claude.sh pr <issue-file> <container>"
                exit 1
            fi
            validate_dependencies
            exec "${SCRIPT_DIR}/core/create-pr.sh" "$2" "$3"
            ;;
            
        cleanup)
            if [[ $# -lt 2 ]]; then
                error "Container name required"
                echo "Usage: ./scripts/claude.sh cleanup <container>"
                exit 1
            fi
            validate_dependencies
            log "Cleaning up container: $2"
            docker stop "$2" 2>/dev/null || true
            docker rm "$2" 2>/dev/null || true
            docker volume rm "${2}-workspace" 2>/dev/null || true
            success "Container $2 cleaned up"
            ;;
            
        test)
            validate_dependencies
            if [[ $# -gt 1 ]]; then
                exec "${SCRIPT_DIR}/container/test-credentials.sh" "$2"
            else
                exec "${SCRIPT_DIR}/container/test-credentials.sh"
            fi
            ;;
            
        validate)
            if [[ $# -lt 2 ]]; then
                error "Container name required"
                echo "Usage: ./scripts/claude.sh validate <container>"
                exit 1
            fi
            validate_dependencies
            local validator_script="${SCRIPT_DIR}/container/workflow-validator.sh"
            if [[ -f "$validator_script" ]]; then
                exec bash "$validator_script" "$2" "${3:-30}"
            else
                error "Workflow validator not found: $validator_script"
                exit 1
            fi
            ;;
            
        config)
            show_config
            ;;
            
        status)
            show_status
            ;;
            
        ps)
            list_containers
            ;;
            
        logs)
            if [[ $# -lt 2 ]]; then
                error "Container name required"
                echo "Usage: ./scripts/claude.sh logs <container>"
                exit 1
            fi
            validate_dependencies
            docker logs "$2"
            ;;
            
        docs)
            log "Opening documentation..."
            if command -v open &> /dev/null; then
                open "${SCRIPT_DIR}/docs/README.md"
            else
                echo "Documentation: ${SCRIPT_DIR}/docs/README.md"
            fi
            ;;
            
        version)
            echo "Claude.sh - FeLangKit Automated Development System"
            echo "Version: 1.0.0"
            echo "Location: $SCRIPT_DIR"
            ;;
            
        *)
            error "Unknown command: $command"
            echo
            usage
            exit 1
            ;;
    esac
}

main "$@"