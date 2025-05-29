# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

FeLangKit is a Swift toolkit for the **FE pseudo-language** providing complete parsing and analysis capabilities. The project implements a 3-stage parsing pipeline: Tokenizer → Expression → Parser, with shared utilities and comprehensive testing.

## Development Commands

### Prerequisites
```bash
# Install SwiftLint via Homebrew
brew install swiftlint
```

### 🚀 Claude Code Parallel Development
For automated GitHub issue processing with parallel Claude Code sessions:
```bash
# Install additional dependencies for automation
brew install gh jq

# Authenticate with GitHub
gh auth login

# Process GitHub issues with Claude Code in isolated worktrees
./claude.sh https://github.com/owner/repo/issues/123
```

**Features:**
- **Git Worktree Integration**: Creates isolated development environments
- **GitHub Issue Fetching**: Automatically retrieves and parses issue data
- **Claude Code Integration**: Launches with full issue context
- **Quality Validation**: Runs SwiftLint, build, and test verification
- **PR Automation**: Creates PR with proper titles and descriptions
- **CI Monitoring**: Watches PR checks until completion


### Verification Command Sequence
After making changes, run this command sequence to ensure everything is working correctly:
```bash
swiftlint lint --fix && swiftlint lint && swift build && swift test
```

### Building and Testing
```bash
# Build the project
swift build

# Build in release mode  
swift build --configuration release

# Run all tests (132 tests, ~0.007s execution)
swift test

# Run tests with code coverage
swift test --enable-code-coverage

# Run specific test suites
swift test --filter "TokenizerTests"
swift test --filter "ExpressionParserTests" 
swift test --filter "StatementParserTests"

# Run individual tests
swift test --filter testComplexArithmeticExpression
```

### Code Quality
```bash
# Run SwiftLint
swiftlint lint

# Auto-fix lint issues
swiftlint lint --fix

# Quiet mode for CI
swiftlint lint --quiet --reporter github-actions-logging
```

### Package Management
```bash
# Resolve dependencies
swift package resolve

# Update dependencies
swift package update
```

## Architecture

### Parsing Pipeline
The codebase implements a clear 3-stage parsing pipeline:

```
Tokenizer → Expression → Parser
    ↓          ↓         ↓
    └── Utilities ←──────┘
```

**Stage 1 - Tokenizer**: Text → Tokens
- Multiple implementations: `Tokenizer` (full-featured), `ParsingTokenizer` (lightweight)
- Shared parsing strategies (recent refactoring eliminated ~300 lines of duplication)
- Multi-language support (English/Japanese keywords)
- Comprehensive error handling with position tracking

**Stage 2 - Expression**: Tokens → Expression ASTs  
- Recursive descent parser with operator precedence
- Security limits (max nesting depth)
- Function calls, field access, array access support

**Stage 3 - Parser**: Tokens → Statement ASTs
- Complete language construct support (if/else, while, for, functions)
- Proper delegation to ExpressionParser
- Control flow and declaration handling

**Utilities**: Shared functionality across all modules
- String escape sequence processing
- Unicode normalization

### Module Structure (FeLangCore)
- **Tokenizer/** (7 files) - Foundation tokenization with multiple implementations
- **Expression/** (2 files) - Expression parsing with precedence handling  
- **Parser/** (2 files) - Statement parsing and AST construction
- **Utilities/** (2 files) - Shared string processing utilities

### Dependencies
- **Swift 6.0** with **macOS 13+** minimum
- **swift-parsing** (0.5.0+) for parser combinators
- **SwiftLint** for code quality

## Testing Strategy

Tests mirror the source structure with 132 tests organized by module:

- **TokenizerTests** (4 files, ~95 tests) - Core tokenization, consistency, edge cases
- **ExpressionParserTests** (~20 tests) - Expression parsing, precedence, complex expressions  
- **StatementParserTests** (~24 tests) - Statement parsing, control flow, declarations
- **UtilitiesTests** (~5 tests) - String escape processing

### Test Categories
- **Unit Tests**: Individual component testing
- **Integration Tests**: Module interaction validation
- **Security Tests**: Nesting limits and input validation
- **Performance Tests**: Efficiency validation

### Running Specific Tests
Use `--filter` with module names or specific test function names. Tests execute in ~0.007 seconds total.

## Development Patterns

### Code Style
- Follow SwiftLint configuration (120-char lines, explicit documentation)
- Use descriptive naming: clear types, action-oriented functions
- Comprehensive error handling with position tracking
- Security-first: validate inputs and implement nesting depth limits

### Architecture Principles
- **Unidirectional dependencies** prevent circular references
- **Modular design** with clear separation of concerns
- **Performance optimization** through shared strategies and O(1) lookups
- **Multi-language support** built into tokenization layer

### Recent Refactoring
The codebase recently completed Phase 1-4 of a major refactoring plan:
- Extracted shared parsing strategies to eliminate duplication
- Maintained all 325 tests with zero regressions
- Follow established patterns when making changes

## CI/CD Workflow

GitHub Actions pipeline runs on both macOS-15 and ubuntu-22.04:
1. **Lint**: SwiftLint with caching (both platforms)
2. **Build**: Matrix builds (debug/release) with artifact upload  
3. **Test**: Unit tests with code coverage reporting

The CI caches dependencies (.build, .swiftpm) and tools for performance.

## Development Environment

### VS Code Dev Container
The project includes a complete VS Code dev container configuration for consistent development environments:

```bash
# Open in dev container (VS Code)
# Container includes: Swift 6.0, SwiftLint, development tools

# Manual container verification
.devcontainer/verify.sh

# Container initialization
.devcontainer/devcontainer-init.sh
```

**Features:**
- Swift 6.0 toolchain with Linux compatibility
- SwiftLint 0.57.0 (pinned for reproducibility)
- VS Code extensions: Swift Language Support, LLDB, test adapters
- Cross-platform timing utilities for Linux/macOS compatibility
- Automatic package resolution on container startup

## User Preferences (from Cursor Rules)

### Workflow Requirements
- **Commit Standards**: Use conventional commits with scope: `<scope>: <what>\n\nRefs #<num>` (≤200 LOC/commit)
- **Quality Gates**: Always run `swiftlint lint --fix && swiftlint lint && swift build && swift test`
- **Branch Strategy**: Create feature branches for issues: `issue-<num>-<date>`
- **PR Format**: Title format: "Resolve #<num>: <Issue Title>"

### Todo List Management
- **ALWAYS use TodoWrite tool** when starting work on GitHub issues to create detailed task breakdown
- **Create comprehensive todo lists** with specific, actionable items for complex implementations
- **Break down large features** into small, manageable tasks (≤30 minutes each)
- **Include implementation steps**: analysis, design, coding, testing, validation
- **Update todo status** in real-time: pending → in_progress → completed
- **Example detailed breakdown**:
  ```
  1. Analyze existing codebase architecture for integration points
  2. Design new component interface and data structures  
  3. Implement core functionality with error handling
  4. Add comprehensive unit tests covering edge cases
  5. Integrate with existing modules and update dependencies
  6. Add documentation and code examples
  7. Run validation sequence and fix any issues
  ```

### Code Quality Standards
- **Linting**: SwiftLint fixes applied automatically before validation
- **Testing**: All tests must pass before commits
- **Build**: Clean builds required for all configurations
- **Documentation**: Maintain clear, concise documentation

### Development Constraints
- **Minimal Diffs**: Keep commits focused and small (≤200 LOC)
- **CI Watching**: Monitor CI status with `gh pr checks --watch`
- **Safety First**: Pause for confirmation on destructive operations

### Implementation Best Practices
- **Start with TodoWrite**: IMMEDIATELY create a detailed todo list when beginning any GitHub issue
- **Task Granularity**: Each todo item should be completable in ≤30 minutes
- **Progress Tracking**: Mark tasks as in_progress when starting, completed when finished
- **Comprehensive Coverage**: Include analysis, implementation, testing, and validation tasks
- **Real-time Updates**: Update todo status throughout the development process
- **Quality Focus**: Always include SwiftLint, build, and test validation as separate todo items

## Recent Work Log

### Dev Container Implementation (Add PR #86)
**Objective**: Add VS Code dev container support for consistent Swift development environment

**Key Achievements:**
- ✅ **Dev Container Setup**: Complete .devcontainer configuration with Swift 6.0
- ✅ **Cross-Platform Compatibility**: Fixed `CFAbsoluteTimeGetCurrent()` Linux issues
- ✅ **CI Enhancement**: Added Linux runners to GitHub Actions
- ✅ **Code Quality**: Extracted shared `getCurrentTime()` utility to reduce duplication
- ✅ **Docker Optimization**: Consolidated apt-get commands, fixed workspace paths
- ✅ **Resource Management**: Proper golden test files declaration in Package.swift

**Technical Details:**
- **Container**: Swift 6.0-jammy with SwiftLint 0.57.0, non-root user setup
- **Cross-Platform**: Conditional compilation for CoreFoundation timing functions
- **CI Matrix**: Both macOS-15 and ubuntu-22.04 runners with caching
- **Utilities**: New `CrossPlatformUtilities.swift` module for shared timing code

**Files Modified:**
- `.devcontainer/`: Complete container configuration (devcontainer.json, Dockerfile, scripts)
- `Sources/FeLangCore/Utilities/CrossPlatformUtilities.swift`: New shared timing utilities
- `Package.swift`: Added resources configuration for golden test files
- `Tests/`: Updated timing code to use shared utilities
- `.github/workflows/ci.yml`: Extended CI for Linux runners

**Outcome**: Full dev container support with cross-platform CI passing on both macOS and Linux

## Repository Workflow Notes

- master branch can't push directly, you have to create branch before commit. and then you can create PR