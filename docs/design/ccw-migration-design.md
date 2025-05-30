# CCW Migration Design Document

## Executive Summary

This document outlines the migration of all features from `claude.sh` (Bash) to `ccw` (Go), implementing a comprehensive GitHub issue automation tool with enhanced functionality, better error handling, and improved maintainability.

## Project Overview

### Current State: claude.sh
- **Language**: Bash (~3000 lines)
- **Purpose**: Automated GitHub issue processing with Claude Code integration
- **Features**: Git worktree management, GitHub API integration, Claude Code automation, PR creation, CI monitoring

### Target State: ccw
- **Language**: Go
- **Purpose**: Enhanced GitHub automation tool with comprehensive testing and maintainability  
- **Benefits**: Type safety, better error handling, easier testing, cross-platform compatibility

## Core Features Analysis

### 1. GitHub Integration
**Current Implementation**: GitHub CLI (`gh`) and REST API calls
- Issue fetching and parsing
- Repository metadata extraction
- PR creation and management
- CI status monitoring

**Go Implementation**: 
- Direct GitHub API v4 (GraphQL) integration
- Structured data models
- Comprehensive error handling
- Rate limiting and retry logic

### 2. Git Worktree Management
**Current Implementation**: Git CLI commands for worktree operations
- Branch creation with timestamp/random suffixes
- Isolated development environments
- Automatic cleanup

**Go Implementation**:
- Go-git library integration
- Structured worktree lifecycle management
- Enhanced error recovery

### 3. Claude Code Integration
**Current Implementation**: Direct `claude` CLI invocation with context
- Issue context preparation
- Automated retry logic
- Error handling and validation

**Go Implementation**:
- Subprocess management with proper I/O handling
- Context-aware error recovery
- Enhanced logging and monitoring

### 4. Quality Validation
**Current Implementation**: SwiftLint, Swift build, and test execution
- Automated validation pipeline
- Retry logic for failed validations
- Error reporting

**Go Implementation**:
- Configurable validation pipelines
- Parallel execution support
- Structured error reporting

### 5. Terminal UI/UX
**Current Implementation**: Complex ANSI color handling, loading animations
- Dynamic header display
- Progress tracking
- Terminal capability detection

**Go Implementation**:
- Unified UI framework (likely bubbletea/lipgloss)
- Cross-platform terminal handling
- Enhanced visual feedback

## Architecture Design

### Package Structure
```
gg/
├── cmd/
│   └── gg/
│       └── main.go              # CLI entry point
├── internal/
│   ├── config/
│   │   ├── config.go            # Configuration management
│   │   └── validation.go        # Config validation
│   ├── github/
│   │   ├── client.go           # GitHub API client
│   │   ├── issues.go           # Issue operations
│   │   ├── pr.go               # PR operations
│   │   └── models.go           # Data models
│   ├── git/
│   │   ├── worktree.go         # Worktree management
│   │   ├── branch.go           # Branch operations
│   │   └── operations.go       # Git operations
│   ├── claude/
│   │   ├── integration.go      # Claude Code integration
│   │   ├── context.go          # Context preparation
│   │   └── validation.go       # Validation logic
│   ├── quality/
│   │   ├── validator.go        # Quality validation
│   │   ├── swiftlint.go        # SwiftLint integration
│   │   └── testing.go          # Test execution
│   ├── ui/
│   │   ├── display.go          # Terminal UI
│   │   ├── progress.go         # Progress tracking
│   │   └── styles.go           # Visual styling
│   └── workflow/
│       ├── orchestrator.go     # Main workflow
│       ├── steps.go            # Workflow steps
│       └── retry.go            # Retry logic
├── pkg/
│   ├── models/
│   │   ├── issue.go            # Issue data models
│   │   ├── worktree.go         # Worktree models
│   │   └── config.go           # Configuration models
│   └── utils/
│       ├── filesystem.go       # File system utilities
│       ├── process.go          # Process management
│       └── validation.go       # Validation utilities
├── go.mod
├── go.sum
└── gg_test.go                  # Main test suite
```

### Core Interfaces

```go
// GitHub operations interface
type GitHubClient interface {
    GetIssue(owner, repo string, number int) (*models.Issue, error)
    CreatePR(req *models.PRRequest) (*models.PullRequest, error)
    GetPRStatus(owner, repo string, number int) (*models.PRStatus, error)
}

// Git operations interface
type GitOperations interface {
    CreateWorktree(path, branch string) error
    RemoveWorktree(path string) error
    CreateBranch(name, base string) error
    Push(remote, branch string) error
}

// Claude Code integration interface
type ClaudeIntegration interface {
    RunWithContext(ctx *models.ClaudeContext) error
    ValidateImplementation(path string) (*models.ValidationResult, error)
}

// Quality validation interface
type QualityValidator interface {
    RunSwiftLint(path string) (*models.LintResult, error)
    RunBuild(path string) (*models.BuildResult, error)
    RunTests(path string) (*models.TestResult, error)
}
```

### Data Models

```go
type Issue struct {
    Number      int                    `json:"number"`
    Title       string                 `json:"title"`
    Body        string                 `json:"body"`
    State       string                 `json:"state"`
    URL         string                 `json:"url"`
    Labels      []Label                `json:"labels"`
    Assignees   []User                 `json:"assignees"`
    CreatedAt   time.Time              `json:"created_at"`
    UpdatedAt   time.Time              `json:"updated_at"`
    Repository  Repository             `json:"repository"`
    Metadata    map[string]interface{} `json:"metadata"`
}

type WorktreeConfig struct {
    BasePath     string    `json:"base_path"`
    BranchName   string    `json:"branch_name"`
    WorktreePath string    `json:"worktree_path"`
    IssueNumber  int       `json:"issue_number"`
    CreatedAt    time.Time `json:"created_at"`
    Owner        string    `json:"owner"`
    Repository   string    `json:"repository"`
}

type ValidationResult struct {
    Success      bool              `json:"success"`
    LintResult   *LintResult       `json:"lint_result,omitempty"`
    BuildResult  *BuildResult      `json:"build_result,omitempty"`
    TestResult   *TestResult       `json:"test_result,omitempty"`
    Errors       []ValidationError `json:"errors,omitempty"`
    Duration     time.Duration     `json:"duration"`
    Timestamp    time.Time         `json:"timestamp"`
}
```

## Implementation Plan

### Phase 1: Core Infrastructure (Day 1-2)
1. **Project Setup**
   - Initialize Go module
   - Set up package structure
   - Configure GitHub Actions for Go

2. **GitHub Integration**
   - Implement GitHub API client
   - Create issue fetching functionality
   - Add PR creation and management

3. **Git Operations**
   - Implement git worktree management
   - Add branch creation and management
   - Implement cleanup procedures

### Phase 2: Claude Integration (Day 3-4)
1. **Claude Code Integration**
   - Process management for Claude CLI
   - Context preparation and injection
   - Error handling and recovery

2. **Validation Framework**
   - SwiftLint integration
   - Build system integration
   - Test execution framework

### Phase 3: Workflow Orchestration (Day 5-6)
1. **Main Workflow**
   - Implement step-by-step workflow
   - Add retry logic and error recovery
   - Progress tracking and reporting

2. **Terminal UI**
   - Implement progress display
   - Add loading animations
   - Create status reporting

### Phase 4: Testing and Polish (Day 7)
1. **Unit Tests**
   - Comprehensive test coverage
   - Mock implementations
   - Integration tests

2. **Documentation and CLI**
   - Command-line interface
   - Configuration management
   - Help and usage documentation

## Configuration Management

### Configuration File Structure
```yaml
# gg.yaml - configuration file
github:
  token: "${GITHUB_TOKEN}"
  default_owner: "fumiya-kume"
  default_repo: "FeLangKit"

worktree:
  base_path: "."
  cleanup_on_success: true
  branch_prefix: "issue"

claude:
  timeout: "30m"
  max_retries: 3
  debug_mode: false

validation:
  swiftlint:
    enabled: true
    auto_fix: true
  build:
    enabled: true
    configuration: "debug"
  tests:
    enabled: true
    parallel: true

ui:
  theme: "default"
  animations: true
  verbose: false
```

## Error Handling Strategy

### Error Types
1. **Network Errors**: GitHub API failures, timeouts
2. **Git Errors**: Worktree creation failures, branch conflicts
3. **Process Errors**: Claude Code execution failures, validation errors
4. **System Errors**: File system issues, permission problems

### Recovery Strategies
1. **Automatic Retry**: Network operations, transient failures
2. **User Intervention**: Validation failures, manual fixes required
3. **Graceful Degradation**: Optional features, fallback modes
4. **Clean Shutdown**: Resource cleanup, state preservation

## Testing Strategy

### Unit Tests (`gg_test.go`)
```go
func TestGitHubIntegration(t *testing.T) {
    // Test GitHub API client functionality
}

func TestWorktreeManagement(t *testing.T) {
    // Test git worktree operations
}

func TestClaudeIntegration(t *testing.T) {
    // Test Claude Code integration
}

func TestValidationPipeline(t *testing.T) {
    // Test quality validation workflow
}

func TestWorkflowOrchestration(t *testing.T) {
    // Test complete workflow execution
}
```

### Integration Tests
- End-to-end workflow testing
- GitHub API integration testing
- File system operations testing
- Process execution testing

### Mock Implementations
- GitHub API mocking
- Git operations mocking
- Claude Code process mocking
- File system mocking

## Dependencies

### Core Dependencies
```go
// GitHub API
"github.com/google/go-github/v57/github"
"golang.org/x/oauth2"

// Git operations
"github.com/go-git/go-git/v5"

// Terminal UI
"github.com/charmbracelet/bubbletea"
"github.com/charmbracelet/lipgloss"

// CLI framework
"github.com/spf13/cobra"
"github.com/spf13/viper"

// Utilities
"gopkg.in/yaml.v3"
"github.com/stretchr/testify"
```

## Migration Benefits

### 1. **Type Safety**
- Compile-time error detection
- Structured data models
- Interface-based design

### 2. **Maintainability**
- Clear package structure
- Comprehensive testing
- Documentation generation

### 3. **Performance**
- Parallel execution support
- Efficient resource management
- Cross-platform compatibility

### 4. **Error Handling**
- Structured error types
- Comprehensive error context
- Graceful failure modes

### 5. **Extensibility**
- Plugin architecture support
- Configuration-driven behavior
- Easy feature additions

## Compatibility Notes

### Command Line Interface
- Maintain compatibility with existing `claude.sh` usage patterns
- Support for environment variable overrides
- Backward-compatible configuration options

### File System
- Preserve existing worktree structure
- Maintain issue data format compatibility
- Support for existing cleanup procedures

### GitHub Integration
- Use same GitHub CLI authentication
- Preserve PR creation format
- Maintain CI monitoring behavior

## Future Enhancements

### 1. **Plugin System**
- Support for custom validation plugins
- Extensible workflow steps
- Third-party integrations

### 2. **Web Interface**
- Browser-based workflow management
- Real-time progress monitoring
- Team collaboration features

### 3. **Advanced Analytics**
- Workflow performance metrics
- Issue processing statistics
- Quality trend analysis

### 4. **Multi-Repository Support**
- Batch issue processing
- Cross-repository dependencies
- Unified reporting

This design provides a comprehensive foundation for migrating all `claude.sh` functionality to Go while enhancing maintainability, testing, and extensibility.