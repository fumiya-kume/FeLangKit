# FeLangKit

> **A comprehensive Swift toolkit for the FE pseudo-language**, providing complete parsing and analysis capabilities with modular architecture.

## 🎯 Overview

FeLangKit is a powerful Swift library designed for parsing and analyzing the FE pseudo-language. It features a clean, modular architecture with comprehensive testing and documentation, making it ideal for building interpreters, compilers, educational tools, and IDE support.

## ✨ Key Features

- **🏗️ Modular Architecture** - Clean separation of concerns across 4 core modules
- **🧪 Comprehensive Testing** - 132+ tests with organized structure and excellent coverage
- **📖 Rich Documentation** - Detailed guides for development and usage
- **🔒 Type Safety** - Full Swift type safety with comprehensive error handling
- **🚀 High Performance** - Optimized parsers with security limits and validation
- **🌐 Internationalization** - Support for both English and Japanese keywords
- **🤖 Automation Ready** - Claude Code integration for intelligent issue processing

## 📋 Requirements

- **Swift 6.0+**
- **macOS 13.0+** / **iOS 17.0+** / **Linux**
- **SwiftLint** (for development)

## 📦 Installation

### Swift Package Manager

Add FeLangKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/fumiya-kume/FeLangKit.git", from: "1.0.0")
]
```

### Xcode (iOS app)

1. In Xcode, open your app project.
2. Go to **File > Add Packages...**.
3. Enter the repository URL:

```
https://github.com/fumiya-kume/FeLangKit.git
```

4. Select the version rule (e.g. "Up to Next Major" from 1.0.0).
5. Add the product you need to your target:
   - `FeLangCore` (parser/tokenizer core)
   - `FeLangKit` (core + runtime)
   - `FeLangRuntime` (interpreter/runtime)

**Requirements:** iOS 17.0+ and Swift 6.0+

## 🚀 Quick Start

```swift
import FeLangCore

// Tokenize input
let tokenizer = Tokenizer(input: "x ← 1 + 2")
let tokens = try tokenizer.tokenize()

// Parse expressions
let expressionParser = ExpressionParser()
let expression = try expressionParser.parseExpression(from: tokens)

// Parse statements
let statementParser = StatementParser()
let statements = try statementParser.parseStatements(from: tokens)
```

## 📦 Core Modules

FeLangKit consists of four core modules that work together:

### 1. **📝 Tokenizer Module**
Converts source text into tokens with multiple implementations for different use cases.
- Full-featured tokenizer with comprehensive error handling
- Lightweight parsing tokenizer for specific scenarios
- Multi-language keyword support (English/Japanese)
- [📚 Module Documentation](Sources/FeLangCore/Tokenizer/docs/README.md)

### 2. **🔢 Expression Module**
Parses and represents expressions with proper operator precedence.
- Recursive descent parser
- Security limits for nesting depth
- Support for function calls, field access, and array operations
- [📚 Module Documentation](Sources/FeLangCore/Expression/docs/README.md)

### 3. **🏗️ Parser Module**
Parses statements and builds complete program ASTs.
- Complete language construct support (if/else, while, for, functions)
- Proper delegation to ExpressionParser
- Control flow and declaration handling
- [📚 Module Documentation](Sources/FeLangCore/Parser/docs/README.md)

### 4. **🛠️ Utilities Module**
Shared functionality across all modules.
- String escape sequence processing
- Unicode normalization
- Cross-platform utilities
- [📚 Module Documentation](Sources/FeLangCore/Utilities/docs/README.md)

## 🎯 Use Cases

- **Language Development** - Build interpreters or compilers for the FE pseudo-language
- **Educational Tools** - Teach parsing concepts and compiler design
- **Code Analysis** - Analyze and transform FE pseudo-language code
- **IDE Support** - Build language servers and syntax highlighting
- **Research Projects** - Experiment with language features and parsing techniques

## 📚 Documentation

### Core Documentation
- **[🏗️ Architecture Guide](docs/ARCHITECTURE.md)** - Module structure, dependencies, and design principles
- **[🧪 Testing Guide](docs/TESTING.md)** - Test organization, coverage, and best practices
- **[👥 Development Guide](docs/DEVELOPMENT.md)** - Setup, contribution guidelines, and coding standards
- **[📋 Migration Guide](docs/MIGRATION.md)** - Package reorganization details and upgrade paths

### Advanced Topics
- **[🎨 Design Documents](docs/design/)** - Architecture decisions and design patterns
- **[⚡ Performance Analysis](docs/performance-analysis-summary.md)** - Benchmarks and optimization strategies

## 🛠️ Development

### Building and Testing

```bash
# Build the project
swift build

# Run tests
swift test

# Run tests with coverage
swift test --enable-code-coverage

# Run specific test suites
swift test --filter "TokenizerTests"
```

### Code Quality

```bash
# Install SwiftLint
brew install swiftlint

# Run linting
swiftlint lint

# Auto-fix issues
swiftlint lint --fix

# Full validation sequence
swiftlint lint --fix && swiftlint lint && swift build && swift test
```

### 🤖 Claude Code Automation

For automated GitHub issue processing with intelligent error recovery:

```bash
# Install dependencies
brew install gh jq swiftlint

# Authenticate with GitHub
gh auth login

# Process issues with Claude Code automation
./claude.sh https://github.com/fumiya-kume/FeLangKit/issues/123
```

This provides:
- Parallel development with isolated git worktrees
- Pre-loaded issue context for Claude Code
- Automatic error recovery and retry loops
- Quality validation and PR automation
- CI monitoring until completion

## 🤝 Contributing

We welcome contributions! Please see the **[Development Guide](docs/DEVELOPMENT.md)** for:
- Development environment setup
- Coding standards and conventions
- Testing requirements
- Pull request process
- Commit message guidelines

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

<div align="center">
  <strong>FeLangKit</strong> - Your complete toolkit for the FE pseudo-language! 🎉
</div>
