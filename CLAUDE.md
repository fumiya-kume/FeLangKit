# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

FeLangKit is a Swift toolkit for the **FE pseudo-language** providing complete parsing and analysis capabilities. The project has a modular architecture with 4 main packages: FeLangCore (core parsing), FeLangKit (main interface), FeLangRuntime (runtime support), and FeLangServer (language server).

## Development Commands

### Building and Testing
```bash
# Build the project
swift build

# Build in release mode
swift build --configuration release

# Run all tests
swift test

# Run tests with code coverage
swift test --enable-code-coverage

# Run specific test suite
swift test --filter "ExpressionParser Tests"
swift test --filter "Tokenizer Tests"

# Run specific test
swift test --filter testComplexArithmeticExpression
```

### Code Quality
```bash
# Run SwiftLint (must have SwiftLint installed)
swiftlint lint

# Auto-fix lint issues
swiftlint lint --fix

# Lint specific directories
swiftlint lint Sources/FeLangCore/Expression/
```

### Package Management
```bash
# Resolve dependencies
swift package resolve

# Update dependencies
swift package update

# Reset package cache
swift package reset
```

## Architecture

### Module Structure
The codebase follows a layered modular architecture in FeLangCore:

- **Tokenizer Module** (foundation): Text → Tokens
  - `Token.swift`, `TokenType.swift`, `SourcePosition.swift`
  - Multiple tokenizer implementations (`Tokenizer.swift`, `ParsingTokenizer.swift`)
  - `TokenizerUtilities.swift` for shared functionality

- **Expression Module**: Tokens → Expression ASTs
  - `Expression.swift` (AST definitions), `ExpressionParser.swift`
  - Handles operator precedence, associativity, function calls

- **Parser Module**: Tokens → Statement ASTs  
  - `Statement.swift` (AST definitions), `StatementParser.swift`
  - Delegates to ExpressionParser, handles control flow

- **Utilities Module**: Shared functionality
  - `StringEscapeUtilities.swift` for escape sequence processing

### Dependency Flow
```
Parser → Expression → Tokenizer
   ↓         ↓         ↓
   └─── Utilities ←────┘
```

### Key Design Principles
- Unidirectional dependencies prevent circular references
- Each module has single responsibility
- Security limits (max nesting depth) throughout parsers
- Support for both English and Japanese keywords

## Testing

The test suite mirrors the source structure with 132 tests organized by module:
- **Tokenizer Tests**: ~95 tests across 4 files (core functionality, consistency, edge cases)
- **Expression Tests**: ~20 tests (precedence, associativity, complex expressions)
- **Parser Tests**: ~24 tests (statements, control flow, declarations)
- **Utilities Tests**: ~5 tests (escape sequence processing)

### Running Specific Tests
Tests are organized to mirror source structure. Use `--filter` with descriptive test names or module names.

## Dependencies

- **Swift 5.9+** with **macOS 13+** minimum
- **swift-parsing** (from Point-Free) for parser combinators
- **SwiftLint** for code quality (check `.swiftlint.yml` for configuration)

## Code Style

- Follow existing patterns within each module
- Use descriptive variable and function names
- Document complex functionality with comprehensive comments
- Security: Always validate input bounds and implement nesting depth limits
- Performance: Use efficient algorithms (O(1) keyword lookups via hash maps)

## Development Workflow

1. Create feature branch from `master`
2. Make changes following module guidelines and existing patterns
3. Add/update tests to match source structure
4. Run `swift build && swift test && swiftlint lint` before committing
5. CI runs lint, build (debug/release), and tests with coverage on PR

The project uses GitHub Actions CI with separate jobs for linting, building, and testing.