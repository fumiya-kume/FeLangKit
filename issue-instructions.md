# GitHub Issue: Set up basic visitor pattern infrastructure

## Issue Details
- **Issue #**: 64
- **Repository**: fumiya-kume/FeLangKit
- **Branch**: issue-64-20250529

## Issue Description
## Overview

FeLangKit needs a visitor pattern infrastructure to enable clean, maintainable AST traversal for both `Expression` and `Statement` types. Currently, each module that processes ASTs implements its own traversal logic with repetitive switch statements.

## Problem

**Current State Issues:**
- `PrettyPrinter` contains 387 lines of manual switch-case traversal logic
- `SemanticAnalyzer` is empty awaiting implementation  
- Future code generators will duplicate the same traversal patterns
- Adding new AST node types requires updating multiple switch statements across modules
- Third-party extensions cannot easily add AST processing capabilities

## Goals

**Primary Objectives:**
- ✅ Implement type-safe visitor pattern for Expression and Statement ASTs
- ✅ Enable clean separation of concerns between AST structure and processing logic
- ✅ Support both mutable and immutable visitors for different use cases
- ✅ Maintain Swift's value semantics and thread safety (`@Sendable` compliance)
- ✅ Zero breaking changes to existing `Expression` and `Statement` APIs

## Solution Approach

**Function-Based Visitor Pattern** using closure-based dispatch:

```swift
public struct ExpressionVisitor<Result> {
    public var visitLiteral: (Literal) -> Result
    public var visitIdentifier: (String) -> Result
    public var visitBinary: (BinaryOperator, Expression, Expression) -> Result
    // ... other visit methods
    
    public func visit(_ expression: Expression) -> Result
}
```

**Benefits:**
- No modifications to existing AST enums required
- Swift-idiomatic with powerful enum pattern matching
- Maximum flexibility for specialized visitors
- Easy testing and composition
- Future-proof for AST extensions

## Implementation Plan

This issue tracks the overall epic. Implementation details and phases are documented in:

- **📋 [Design Document #65](https://github.com/fumiya-kume/FeLangKit/issues/65)** - Complete architectural analysis and implementation strategy
- **🚀 [Phase 1 Implementation #67](https://github.com/fumiya-kume/FeLangKit/issues/67)** - Core `ExpressionVisitor` and `StatementVisitor` infrastructure

## Success Criteria

- [ ] Core visitor infrastructure implemented (`ExpressionVisitor<Result>`, `StatementVisitor<Result>`)
- [ ] `PrettyPrinter` successfully refactored to use visitor pattern  
- [ ] `SemanticAnalyzer` skeleton implemented with visitor-based traversal
- [ ] Comprehensive test suite with performance validation (<5% overhead vs. switch statements)
- [ ] Documentation and migration guide completed
- [ ] Zero breaking changes to existing APIs

## Related Work

**Dependencies:**
- Must work with existing `Expression` enum (no modifications)
- Must work with existing `Statement` enum (no modifications)
- Must maintain `@Sendable` compliance for thread safety
- Must integrate with existing `SymbolTable` and error reporting

**Follow-up Opportunities:**
- AST optimization passes using visitor infrastructure
- Code generation backends  
- Language server protocol integration
- Static analysis and linting tools

---

**Status**: Ready for implementation  
**Priority**: High - blocks semantic analysis and code generation work  
**Complexity**: Medium-High  
**Estimated Effort**: 2-3 weeks across multiple phases

## Instructions for Claude
1. Read and understand the issue requirements
2. Create a new branch: issue-64-20250529
3. Implement the necessary changes following the project conventions in CLAUDE.md
4. Run the quality gates: swiftlint lint --fix && swiftlint lint && swift build && swift test
5. Commit changes using conventional commit format
6. Push the branch and create a PR

Please work on this issue systematically and ensure all tests pass before committing.

## Development Environment
The project uses Swift with the following tools:
- SwiftLint for code quality
- Swift Package Manager for dependencies  
- GitHub Actions for CI/CD

You can run development commands directly in the host environment or use the Docker container for isolated testing.

## Container Authentication
A Docker container is available with shared credentials from your host:
- Git configuration and SSH keys are mounted
- GitHub CLI authentication is shared
- Anthropic API key is available
- You can run git, gh, swift, and swiftlint commands in the container

Use commands like:
- `docker exec <container-name> swift build`
- `docker exec <container-name> git status`
- `docker exec <container-name> gh pr list`
