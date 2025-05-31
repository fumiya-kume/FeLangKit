# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

You will ultrathink for the solution

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
- **Safety First**: Pause for confirmation on destructive operations

### Implementation Best Practices
- **Start with TodoWrite**: IMMEDIATELY create a detailed todo list when beginning any GitHub issue
- **Task Granularity**: Each todo item should be completable in ≤30 minutes
- **Progress Tracking**: Mark tasks as in_progress when starting, completed when finished
- **Comprehensive Coverage**: Include analysis, implementation, testing, and validation tasks
- **Real-time Updates**: Update todo status throughout the development process
- **Quality Focus**: Always include SwiftLint, build, and test validation as separate todo items

### Git and GitHub Operations
- **Execute git commands directly** when requested by the user
- **Create commits, branches, and push changes** as needed for user requests
- **Create pull requests** using `gh pr create` when asked
- **Run all git operations** (add, commit, push, merge) when appropriate
- **Use merge commits by default** instead of squash merge: `gh pr merge --merge`
- **claude.sh is available** for automated GitHub issue processing but is not required
- **Direct execution preferred** when user explicitly requests git/GitHub operations

### PR Description Format Requirements
When creating pull requests (handled automatically by claude.sh), the description must be generated in **well-structured Markdown format** with the following sections:

```markdown
## Summary
Concise overview of what this PR accomplishes and its main value

## Background & Context
Provide detailed background about the issue and context:
- **Original Issue:** Detailed explanation of the problem that was reported or identified
- **Root Cause:** What was causing the issue (if applicable)
- **User Impact:** How this issue affected users or the development process
- **Previous State:** Describe how things worked before this change
- **Requirements:** What specific requirements needed to be met

## Solution Approach
Explain the solution and reasoning in detail:
- **Core Solution:** Clear explanation of how this PR solves the identified problem
- **Technical Strategy:** The overall technical approach chosen
- **Logic & Reasoning:** Detailed explanation of the implementation logic and why this approach was selected
- **Alternative Approaches:** Briefly mention other approaches considered and why they were not chosen
- **Architecture Changes:** Any changes to the overall system architecture or design patterns

## Implementation Details
Technical implementation breakdown:
- **Key Components:** Main components or modules that were modified/added
- **Code Changes:** Detailed explanation of the major code changes made
- **Files Modified:** List of files changed with brief explanation of changes in each
- **New Functionality:** Any new features or capabilities added
- **Integration Points:** How this change integrates with existing code
- **Error Handling:** How errors and edge cases are handled

## Technical Logic
Explain the technical reasoning and logic:
- **Algorithm/Logic:** Step-by-step explanation of key algorithms or logic implemented
- **Data Flow:** How data flows through the new/modified components
- **Performance Considerations:** Any performance optimizations or trade-offs made
- **Security Considerations:** Security implications and measures taken
- **Backwards Compatibility:** How backwards compatibility is maintained (if applicable)

## Testing & Validation
Comprehensive testing approach:
- **Test Strategy:** Overall testing approach used
- **Test Coverage:** Specific tests added and what they validate
- **Manual Testing:** Manual testing performed and results
- **Edge Cases:** Edge cases tested and how they are handled
- **Quality Assurance:** SwiftLint, build, and test results

## Impact & Future Work
Analysis of impact and future implications:
- **Breaking Changes:** Any breaking changes with migration guidance
- **Performance Impact:** Measured or expected performance changes
- **Maintenance Impact:** How this affects ongoing maintenance
- **Future Enhancements:** How this change enables or supports future work
- **Technical Debt:** Any technical debt introduced or resolved
```

**Key Requirements:**
- **Comprehensive Context**: Provide detailed background about the original issue, root cause, and user impact
- **Solution Explanation**: Clearly explain how the problem is solved and why this approach was chosen
- **Technical Logic**: Include step-by-step explanation of key algorithms, data flow, and technical reasoning
- **Implementation Details**: Describe key components, integration points, and error handling approaches
- **Alternative Analysis**: Mention other approaches considered and rationale for the chosen solution
- **Testing Coverage**: Document comprehensive testing strategy including edge cases and manual testing
- **Future Impact**: Explain how changes support future work and any technical debt implications

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

## ⚠️ Critical Automation Warnings & Best Practices

### Claude Code CLI Usage
- **NEVER use non-existent flags**: `claude --format json` doesn't exist and will cause process hangs
- **Correct interactive mode**: Use `claude` for interactive sessions
- **Correct non-interactive**: Use `claude --print` for automated output
- **JSON output**: Use `claude --print --output-format json` when JSON format is needed
- **Timeout protection**: Always use `timeout` command for automated Claude Code invocations to prevent infinite hangs

### Process Management & Hanging Prevention
- **Interactive vs Non-Interactive**: Don't try to pipe input to interactive Claude Code sessions - this causes indefinite hanging
- **Background Process Cleanup**: Always kill background processes (loading spinners) and wait for them to prevent zombie processes
- **Input Redirection**: When redirecting input to commands, ensure the command expects non-interactive input
- **Loading Animations**: Use background processes for loading animations but always clean them up properly

### Git Worktree & Branch Management
- **Branch Protection**: Direct pushes to master are blocked - always create feature branches
- **Worktree Isolation**: Use git worktrees for parallel development to avoid conflicts
- **Cleanup Strategy**: Always clean up temporary files, worktrees, and background processes
- **Commit Standards**: Follow conventional commit format with scope and issue references
- **Worktree Config File**: The `.worktree-config.json` file is automatically generated by ccw and MUST NOT be committed. It's already in `.gitignore` and should remain ignored

### Error Handling & User Experience
- **Timeout Mechanisms**: Implement timeouts for all network operations and external command calls
- **Progress Visualization**: Provide visual feedback for operations that take more than a few seconds
- **Error Context**: Capture and display meaningful error messages with context
- **Graceful Degradation**: Provide fallback options when automated processes fail

### Quality Workflow Integration
- **Continuous Validation**: Run `swiftlint lint --fix && swiftlint lint && swift build && swift test` frequently during development
- **Real-time Feedback**: Integrate quality checks into the development workflow, not just at the end
- **Loading Indicators**: Provide visual feedback during quality checks to improve user experience
- **Context-Aware Prompts**: Include specific command examples and workflow guidance in Claude Code context messages

### Automation Script Development
- **Status Box Updates**: Implement real-time progress tracking with visual status indicators
- **Activity Tracking**: Show current operation being performed with detailed progress information
- **Progress Bars**: Use visual progress bars for operations with known durations
- **Comprehensive Loading**: Add loading indicators to all operations (API calls, git operations, validation) for better UX

### Common Pitfalls to Avoid
1. **Claude CLI Flag Errors**: Using invalid flags like `--format json` causes silent failures
2. **Process Hanging**: Mixing interactive and non-interactive modes without proper handling
3. **Missing Timeouts**: Operations without timeouts can hang indefinitely in automation
4. **Poor UX**: Lack of visual feedback during long-running operations confuses users
5. **Incomplete Cleanup**: Not cleaning up background processes and temporary files
6. **Manual Confirmations**: Automation scripts should minimize or eliminate manual prompts
7. **CCW Config Files**: Never commit `.worktree-config.json` - it contains issue-specific worktree information and is automatically ignored by git