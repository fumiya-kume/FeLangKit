# FeLangKit

A comprehensive Swift toolkit for the **FE pseudo-language**, providing complete parsing and analysis capabilities.

## 📦 Packages

### 🎯 FeLangCore
The core parsing library with modular architecture:
- **📝 Tokenizer Module** - Convert source text into tokens
- **🔢 Expression Module** - Parse and represent expressions  
- **🏗️ Parser Module** - Parse statements and build program ASTs
- **🛠️ Utilities Module** - Shared functionality across modules

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

## 📚 Documentation

### **🎯 Project Documentation**
| Document | Description |
|----------|-------------|
| **[🏗️ Architecture Guide](docs/ARCHITECTURE.md)** | Module structure, dependencies, and organization |
| **[🧪 Testing Guide](docs/TESTING.md)** | Test organization, coverage, and guidelines |
| **[👥 Development Guide](docs/DEVELOPMENT.md)** | Development guidelines and contribution guide |
| **[📋 Migration Guide](docs/MIGRATION.md)** | Package reorganization details and history |

### **📦 Module Documentation**
| Module | Documentation |
|--------|---------------|
| **📝 Tokenizer** | **[Module Overview](Sources/FeLangCore/Tokenizer/docs/README.md)** |
| **🔢 Expression** | **[Module Overview](Sources/FeLangCore/Expression/docs/README.md)** |
| **🏗️ Parser** | **[Module Overview](Sources/FeLangCore/Parser/docs/README.md)** |
| **🛠️ Utilities** | **[Module Overview](Sources/FeLangCore/Utilities/docs/README.md)** |

## ✨ Features

- **🏗️ Modular Architecture** - Clean separation of concerns across 4 modules
- **🧪 Comprehensive Testing** - 132 tests with organized structure
- **📖 Rich Documentation** - Detailed guides for development and usage
- **🔒 Type Safety** - Full Swift type safety with comprehensive error handling
- **🚀 Performance** - Optimized parsers with security limits and validation
- **🌐 Internationalization** - Support for both English and Japanese keywords

## 🤖 Claude Code Automation

**Automated GitHub issue processing with intelligent error recovery:**

```bash
# Install dependencies
brew install gh jq swiftlint

# Authenticate with GitHub
gh auth login

# Process issues with Claude Code automation
./claude.sh https://github.com/owner/repo/issues/123
```

**Features:**
- **🔄 Parallel Development** - Creates isolated git worktrees for each issue
- **🤖 Claude Code Integration** - Launches with pre-loaded issue context
- **🔧 Intelligent Error Recovery** - Automatic retry loop with error fixing
- **✅ Quality Validation** - SwiftLint, build, and test verification
- **📋 PR Automation** - Creates pull requests with proper formatting
- **🎯 CI Monitoring** - Watches GitHub Actions checks until completion

## 🎯 Use Cases

- **Language Development** - Build interpreters or compilers for the FE pseudo-language
- **Educational Tools** - Teach parsing concepts and compiler design
- **Code Analysis** - Analyze and transform FE pseudo-language code
- **IDE Support** - Build language servers and syntax highlighting
- **🤖 Automated Development** - Process GitHub issues intelligently with Claude Code

## 📋 Requirements

- **Swift 5.9+**
- **macOS 14.0+** / **iOS 17.0+** / **Linux**

## 🤝 Contributing

Please see the **[Development Guide](docs/DEVELOPMENT.md)** for detailed contribution guidelines, coding standards, and development setup instructions.

## 📄 License

[Add your license information here]

---

**FeLangKit** provides a complete toolkit for working with the FE pseudo-language! 🎉