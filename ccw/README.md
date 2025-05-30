# CCW - Claude Code Worktree Automation Tool

CCW is a Go-based automation tool that streamlines the complete GitHub issue workflow using Claude Code integration.

## Features

### ✨ Core Automation
- **GitHub Integration**: Uses official `gh` CLI for seamless GitHub operations
- **Git Worktree Management**: Creates isolated development environments for each issue
- **Claude Code Integration**: Automatically launches Claude Code with issue context
- **Quality Validation**: Runs SwiftLint, build, and test validation with change detection
- **Error Recovery**: Intelligent retry logic with error context (up to 3 attempts)

### 🤖 AI-Enhanced Features
- **AI-Generated PR Descriptions**: Comprehensive PR descriptions with 6+ sections including:
  - Summary, Background & Context, Solution Approach
  - Implementation Details, Technical Logic, Testing & Validation
  - Impact & Future Work analysis
- **Validation Error Recovery**: Automatic error fixing with Claude Code integration
  - Detects recoverable validation errors (lint, build, test failures)
  - Automatically calls Claude Code with error context for fixing
  - Supports multiple recovery attempts with detailed error analysis
  - Intelligent error grouping and recovery suggestions
- **Fallback Templates**: Professional PR templates when AI generation unavailable
- **Implementation Analysis**: Automatic analysis of code changes and git diff

### 🎨 Advanced Terminal UI
- **Real-time Progress Tracking**: 8-step workflow visualization with status indicators
- **Multiple Themes**: Choose from `default`, `minimal`, `modern`, or `compact` themes
- **Animated Progress**: Loading spinners and progress bars during operations
- **Dynamic Headers**: Responsive terminal layouts with border styles
- **Smart Terminal Detection**: Adapts to terminal capabilities and size

### 🛠️ Enhanced Operations
- **Change Detection**: Only runs validation when changes are detected
- **Advanced Worktree Management**: Comprehensive cleanup and conflict resolution
- **Duplicate PR Detection**: Checks for existing PRs before creation
- **Orphaned Branch Cleanup**: Maintains clean repository state
- **Environment Configuration**: Extensive customization via environment variables

### 🖥️ CI/Console Mode Support
- **Automatic CI Detection**: Detects GitHub Actions, GitLab CI, Jenkins environments
- **Clean ASCII Output**: Replaces Unicode and emoji characters with ASCII alternatives
- **CI-Friendly Progress**: Simple text-based progress indicators for logs
- **Console-Safe Characters**: Uses `[CHECK]`, `[SUCCESS]`, `[WARNING]`, `[ERROR]` instead of emojis
- **Environment Triggers**: Activated by `CI=true`, `GITHUB_ACTIONS=true`, or `CCW_CONSOLE_MODE=true`

## Prerequisites

- **GitHub CLI (gh)**: Must be installed and authenticated
  ```bash
  brew install gh
  gh auth login
  ```
- **Claude CLI**: For automated implementation
- **SwiftLint**: For code quality validation (Swift projects)
- **Git**: For worktree management

## Installation

1. Build the binary:
   ```bash
   cd ccw
   go build -o ccw main.go models.go claude.go github.go git.go validation.go ui.go
   ```

2. Move to your PATH (optional):
   ```bash
   mv ccw /usr/local/bin/
   ```

## Usage

### Basic Usage
```bash
ccw https://github.com/owner/repo/issues/123
```

### Options
```bash
ccw --help           # Show usage information
ccw --cleanup        # Clean up all existing worktrees
ccw --debug <url>    # Enable debug mode
```

### Environment Variables
```bash
DEBUG_MODE=true ccw <url>              # Enable verbose output
CCW_THEME=modern ccw <url>             # Set UI theme
CCW_ANIMATIONS=false ccw <url>         # Disable animations
CCW_CONSOLE_MODE=true ccw <url>        # Force CI-friendly console mode
```

## Workflow

CCW follows a 9-step automated workflow with real-time progress tracking and intelligent error recovery:

1. **Setting up worktree**: Creates isolated git worktree with unique branch name
2. **Fetching issue data**: Retrieves comprehensive issue information using `gh api`
3. **Generating analysis**: Prepares implementation context and strategy
4. **Running Claude Code**: Launches automated implementation with issue context
5. **Validating implementation**: Runs comprehensive quality checks with automatic recovery
   - **Primary validation**: SwiftLint, build, and test execution
   - **Error detection**: Identifies recoverable validation failures
   - **Recovery attempts**: Up to 3 automatic retry attempts with Claude Code
   - **Error context**: Detailed error analysis and fix suggestions
6. **Committing changes**: **REQUIRED STEP** - Creates git commit with all changes before PR creation
7. **Generating PR description**: Creates AI-powered comprehensive PR description
8. **Creating pull request**: Submits PR with enhanced description using `gh pr create`
9. **Workflow complete**: Cleanup and success reporting with next steps

### ⚠️ Critical Workflow Requirements

- **Step 6 is mandatory**: Git commit must be completed **before** creating the pull request
- **Synchronous operation**: Commit step cannot be run in parallel with PR creation
- **All changes must be staged**: Ensure all implementation changes are committed
- **Conventional commit format**: Follow project standards for commit messages

### 🔄 Validation Error Recovery

CCW includes an intelligent validation error recovery system that automatically attempts to fix common validation failures:

#### How Recovery Works
1. **Error Detection**: After initial validation fails, CCW analyzes errors for recoverability
2. **Recovery Attempts**: Makes up to 3 attempts to fix validation errors
3. **Claude Code Integration**: Calls Claude Code with detailed error context for each attempt
4. **Progressive Fixes**: Each attempt builds on previous fixes and remaining errors

#### Recoverable Error Types
- **SwiftLint Errors**: Code style, formatting, naming conventions, unused imports
- **Build Errors**: Compilation issues, missing imports, type mismatches, syntax errors
- **Test Failures**: Test logic issues, assertion failures, test data problems

#### Recovery Features
- **Detailed Error Analysis**: Groups errors by type with file/line information
- **Recovery Suggestions**: Provides specific fix guidance for each error type
- **Progress Tracking**: Shows recovery attempts in real-time with status updates
- **Intelligent Context**: Passes comprehensive error details to Claude Code for targeted fixes

#### Configuration
Recovery behavior can be configured via `ccw.yaml`:
```yaml
validation_recovery:
  enabled: true                    # Enable/disable recovery
  max_attempts: 3                  # Maximum recovery attempts
  recovery_timeout: "600s"         # Timeout per recovery attempt
  delay_between_attempts: "10s"    # Delay between attempts
  recoverable_error_types:         # Error types to attempt recovery
    - lint
    - build
    - test
  auto_fix_enabled: true           # Enable automatic SwiftLint fixes
  verbose_output: false            # Show detailed recovery output
```

### Enhanced Features
- **Smart Change Detection**: Only runs validation when actual changes are detected
- **Error Context Passing**: Failed validation details are passed to retry attempts
- **Progress Visualization**: Real-time step tracking with status indicators
- **AI Integration**: Claude Code generates both implementation and PR descriptions

## Examples

```bash
# Process a GitHub issue
ccw https://github.com/fumiya-kume/FeLangKit/issues/123

# Clean up all worktrees
ccw --cleanup

# Debug mode with verbose output
DEBUG_MODE=true ccw https://github.com/owner/repo/issues/456
```

## Architecture

```
CCWApp
├── GitHubClient     # GitHub operations via gh CLI
├── GitOperations    # Git worktree management
├── ClaudeIntegration # Claude Code automation
├── QualityValidator # SwiftLint/build/test validation
└── UIManager        # Terminal output and progress
```

## Error Handling

- **Network Errors**: GitHub API failures handled gracefully
- **Git Errors**: Worktree conflicts and permission issues
- **Validation Errors**: Build/test failures with retry logic
- **Authentication**: Clear error messages for gh CLI setup

## Testing

```bash
# Run all tests
go test

# Run tests in short mode (skip integration tests)
go test -short

# Run with verbose output
go test -v

# Run benchmarks
go test -bench=.
```

## Performance

```
BenchmarkExtractIssueInfo-8     218545    5562 ns/op
BenchmarkGenerateBranchName-8   4016185   296.7 ns/op  
BenchmarkJSONMarshalIssue-8     1435100   831.7 ns/op
```

The enhanced CCW maintains excellent performance while adding significant functionality:
- **URL parsing**: ~5.6μs per operation
- **Branch name generation**: ~297ns per operation  
- **JSON serialization**: ~832ns per operation

## Project Structure

```
ccw/
├── main.go              # Main application and workflow orchestration
├── models.go            # Data structures and type definitions
├── claude.go            # Claude Code integration and AI features
├── github.go            # GitHub CLI operations and API integration
├── git.go               # Git worktree management and operations
├── validation.go        # Quality validation and testing framework
├── ui.go                # Terminal UI, progress tracking, and themes
├── main_test.go         # Comprehensive test suite (20+ tests)
├── go.mod               # Go module definition
├── go.sum               # Dependency checksums
├── ccw                  # Compiled binary
└── README.md            # This file
```

## Dependencies

- **github.com/fatih/color**: Terminal color output
- **Standard Library**: Core functionality uses Go stdlib only
- **External Tools**: gh, git, claude, swiftlint, swift

## Migration from claude.sh

CCW is a complete rewrite of the original `claude.sh` tool with the following improvements:

- **Type Safety**: Go's type system prevents runtime errors
- **Better Performance**: Compiled binary vs shell script
- **Enhanced Testing**: Comprehensive test suite with benchmarks
- **Simplified Auth**: Uses gh CLI instead of manual tokens
- **Better UX**: Colorized output and clear error messages
- **Cross-platform**: Compiles to single binary for any platform

## Contributing

1. Make changes to `main.go`
2. Update tests in `main_test.go`
3. Run test suite: `go test -v`
4. Build and test: `go build -o ccw main.go && ./ccw --help`

## License

See the main project LICENSE file.