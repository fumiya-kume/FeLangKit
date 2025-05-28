# FeLangCore Architecture

This document describes the modular architecture of FeLangCore, including module responsibilities, dependencies, and organizational structure.

## 📁 Directory Structure

```
Sources/FeLangCore/
├── FeLangCore.swift              # Main module file & public API documentation
├── Tokenizer/                    # 📝 Tokenization Components
│   ├── Token.swift              # Token data structure
│   ├── TokenType.swift          # Token type enumeration
│   ├── SourcePosition.swift     # Source position tracking
│   ├── Tokenizer.swift          # Original tokenizer implementation
│   ├── ParsingTokenizer.swift   # Simplified parsing tokenizer
│   ├── TokenizerError.swift     # Tokenization error types
│   └── TokenizerUtilities.swift # Shared tokenizer utilities
├── Expression/                   # 🔢 Expression Processing
│   ├── Expression.swift         # Expression AST definitions
│   └── ExpressionParser.swift   # Expression parsing logic
├── Parser/                       # 🏗️ Statement Parsing
│   ├── Statement.swift          # Statement AST definitions
│   └── StatementParser.swift    # Statement parsing logic
└── Utilities/                    # 🛠️ Shared Utilities
    └── StringEscapeUtilities.swift # String escape sequence processing
```

## 🎯 Module Responsibilities

### 📝 Tokenizer Module (7 files)
**Purpose**: Breaking input text into tokens for parsing

**Core Components**:
- **Token.swift**: Core token data structure with type, lexeme, and position
- **TokenType.swift**: Comprehensive enumeration of all token types (keywords, operators, literals, etc.)
- **SourcePosition.swift**: Tracks line, column, and offset positions in source code

**Implementations**:
- **Tokenizer.swift**: Full-featured tokenizer with comprehensive error handling
- **ParsingTokenizer.swift**: Lightweight tokenizer optimized for parsing performance

**Support Infrastructure**:
- **TokenizerError.swift**: Specialized error types for tokenization failures
- **TokenizerUtilities.swift**: Shared utilities (keyword maps, character classification, etc.)

**📖 Module Documentation**: **[Tokenizer Module Overview](../Sources/FeLangCore/Tokenizer/docs/README.md)**

### 🔢 Expression Module (2 files)
**Purpose**: Parsing and representing expressions in the FE language

**Components**:
- **Expression.swift**: AST node definitions for all expression types
  - Literals (integer, real, string, character, boolean)
  - Binary operations (arithmetic, comparison, logical)
  - Unary operations (not, plus, minus)
  - Function calls with arguments
  - Field access (record.field)
  - Array access (array[index])
- **ExpressionParser.swift**: Recursive descent parser with proper precedence handling
  - Operator precedence management
  - Left/right associativity support
  - Security limits (max nesting depth)

**📖 Module Documentation**: **[Expression Module Overview](../Sources/FeLangCore/Expression/docs/README.md)**

### 🏗️ Parser Module (2 files)
**Purpose**: Parsing statements and building complete program ASTs

**Components**:
- **Statement.swift**: AST node definitions for all statement types
  - Variable assignments and declarations
  - Control flow (if/else, while, for)
  - Function and procedure declarations
  - Expression statements
  - Return and break statements
- **StatementParser.swift**: Comprehensive statement parser
  - All FE language constructs support
  - Proper delegation to ExpressionParser
  - Nesting depth security limits
  - Multi-language keyword support

**📖 Module Documentation**: **[Parser Module Overview](../Sources/FeLangCore/Parser/docs/README.md)**

### 🛠️ Utilities Module (1 file)
**Purpose**: Shared functionality used across multiple modules

**Components**:
- **StringEscapeUtilities.swift**: Centralized escape sequence processing
  - String and character literal processing
  - Validation and error detection
  - Performance-optimized implementations

**📖 Module Documentation**: **[Utilities Module Overview](../Sources/FeLangCore/Utilities/docs/README.md)**

## 🔗 Module Dependencies

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Parser    │───▶│ Expression  │───▶│ Tokenizer   │
│             │    │             │    │             │
│ - Statement │    │ - Expression│    │ - Token     │
│ - StatementParser   │ - ExpressionParser  │ - TokenType │
└─────────────┘    └─────────────┘    │ - etc.      │
       │                               └─────────────┘
       │           ┌─────────────┐              │
       └──────────▶│ Utilities   │◀─────────────┘
                   │             │
                   │ - StringEscapeUtilities  │
                   └─────────────┘
```

### Dependency Flow
1. **Tokenizer** → Foundation layer, no internal dependencies
2. **Expression** → Depends on Tokenizer for token types and utilities
3. **Parser** → Depends on Expression for AST nodes and parsing logic
4. **Utilities** → Shared by all modules, minimal dependencies

### Design Principles
- **Unidirectional Dependencies**: Clear dependency flow prevents circular references
- **Minimal Coupling**: Each module exposes only necessary public interfaces
- **Single Responsibility**: Each module has one focused purpose
- **Layered Architecture**: Higher-level modules build upon lower-level ones

## 📊 Module Metrics

| **Module** | **Files** | **Responsibilities** | **Key Types** |
|------------|-----------|---------------------|---------------|
| **Tokenizer** | 7 | Text → Tokens | `Token`, `TokenType`, `SourcePosition` |
| **Expression** | 2 | Tokens → Expression ASTs | `Expression`, `Literal`, `BinaryOperator` |
| **Parser** | 2 | Tokens → Statement ASTs | `Statement`, `DataType`, `VariableDeclaration` |
| **Utilities** | 1 | Shared functionality | `StringEscapeUtilities` |

## 🏗️ Architectural Benefits

### 🎯 **Maintainability**
- **Logical Grouping**: Related functionality is co-located
- **Clear Boundaries**: Module interfaces define clear contracts
- **Easier Navigation**: Developers can quickly find relevant code
- **Isolated Changes**: Modifications are contained within modules

### 🔄 **Scalability**
- **Parallel Development**: Teams can work on different modules independently
- **Module Evolution**: Each module can evolve without affecting others
- **Feature Addition**: New capabilities can be added to appropriate modules
- **Performance Optimization**: Targeted optimizations per module

### 🛠️ **Code Quality**
- **Single Responsibility**: Each module has a focused purpose
- **Dependency Management**: Clear flow prevents architectural issues
- **Reusability**: Utilities module provides shared functionality
- **Testability**: Modular structure enables focused testing

## 🔧 Internal Structure Notes

- **Swift Module System**: All subdirectory files are automatically included
- **Public API**: `import FeLangCore` provides access to all modules
- **No Breaking Changes**: Reorganization maintains API compatibility
- **Transparent Access**: Existing code continues to work seamlessly

## 🚀 Future Architecture Considerations

### Potential Extensions
- **Semantic Analysis Module**: Type checking and semantic validation
- **Code Generation Module**: Compilation to target platforms
- **Optimization Module**: AST transformations and optimizations
- **Language Server Module**: IDE support and tooling

### Scalability Patterns
- Each new module should follow the established dependency patterns
- Utilities module can be extended for cross-cutting concerns
- Test modules should mirror any new source modules
- Documentation should be updated to reflect architectural changes

This modular architecture provides a solid foundation for the continued development and maintenance of FeLangCore! 🎉 