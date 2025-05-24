# FeLangCore Package Organization

FeLangCore has been reorganized into a clean, modular structure for better maintainability and development experience.

## 📁 Directory Structure

```
Sources/FeLangCore/
├── FeLangCore.swift              # Main module file & public API documentation
├── README.md                     # This documentation file
├── Tokenizer/                    # Tokenization Components
│   ├── Token.swift              # Token data structure
│   ├── TokenType.swift          # Token type enumeration
│   ├── SourcePosition.swift     # Source position tracking
│   ├── Tokenizer.swift          # Original tokenizer implementation
│   ├── ParsingTokenizer.swift   # Simplified parsing tokenizer
│   ├── TokenizerError.swift     # Tokenization error types
│   └── TokenizerUtilities.swift # Shared tokenizer utilities
├── Expression/                   # Expression Processing
│   ├── Expression.swift         # Expression AST definitions
│   └── ExpressionParser.swift   # Expression parsing logic
├── Parser/                       # Statement Parsing
│   ├── Statement.swift          # Statement AST definitions
│   └── StatementParser.swift    # Statement parsing logic
└── Utilities/                    # Shared Utilities
    └── StringEscapeUtilities.swift # String escape sequence processing

Tests/FeLangCoreTests/            # Mirror the source structure for tests
├── FeLangCoreTests.swift         # Main test suite file
├── Tokenizer/                    # Tokenizer Tests
│   ├── TokenizerTests.swift     # Comprehensive tokenizer tests
│   ├── ParsingTokenizerTests.swift # Parsing-focused tokenizer tests
│   ├── TokenizerConsistencyTests.swift # Cross-tokenizer consistency tests
│   └── LeadingDotTests.swift    # Decimal parsing edge case tests
├── Expression/                   # Expression Tests
│   └── ExpressionParserTests.swift # Expression parsing tests
├── Parser/                       # Parser Tests
│   └── StatementParserTests.swift # Statement parsing tests
└── Utilities/                    # Utility Tests
    └── StringEscapeUtilitiesTests.swift # String escape utility tests
```

## 🎯 Module Responsibilities

### 📝 Tokenizer Module
**Purpose**: Breaking input text into tokens for parsing
- **Token.swift**: Core token data structure with type, lexeme, and position
- **TokenType.swift**: Comprehensive enumeration of all token types (keywords, operators, literals, etc.)
- **SourcePosition.swift**: Tracks line, column, and offset positions in source code
- **Tokenizer.swift**: Full-featured tokenizer with comprehensive error handling
- **ParsingTokenizer.swift**: Lightweight tokenizer optimized for parsing performance
- **TokenizerError.swift**: Specialized error types for tokenization failures
- **TokenizerUtilities.swift**: Shared utilities (keyword maps, character classification, etc.)

### 🔢 Expression Module  
**Purpose**: Parsing and representing expressions in the FE language
- **Expression.swift**: AST node definitions for all expression types (literals, binary ops, unary ops, function calls, field access, array access)
- **ExpressionParser.swift**: Recursive descent parser for expressions with proper precedence handling

### 🏗️ Parser Module
**Purpose**: Parsing statements and building complete program ASTs
- **Statement.swift**: AST node definitions for all statement types (assignments, control flow, declarations, etc.)
- **StatementParser.swift**: Comprehensive statement parser with support for all FE language constructs

### 🛠️ Utilities Module
**Purpose**: Shared functionality used across multiple modules
- **StringEscapeUtilities.swift**: Centralized escape sequence processing for strings and character literals

## 🧪 Test Organization

The test suite is organized to mirror the source structure, providing clear alignment between implementation and validation:

### 📝 Tokenizer Tests (4 test files)
- **TokenizerTests.swift**: Comprehensive testing of the main tokenizer functionality
- **ParsingTokenizerTests.swift**: Focused tests for the optimized parsing tokenizer
- **TokenizerConsistencyTests.swift**: Cross-validation between different tokenizer implementations
- **LeadingDotTests.swift**: Edge case testing for decimal number parsing (e.g., `.5`, `.25`)

### 🔢 Expression Tests (1 test file)
- **ExpressionParserTests.swift**: Complete testing of expression parsing, precedence, and AST generation

### 🏗️ Parser Tests (1 test file)
- **StatementParserTests.swift**: Comprehensive statement parsing tests covering all language constructs

### 🛠️ Utilities Tests (1 test file)
- **StringEscapeUtilitiesTests.swift**: Validation of escape sequence processing functionality

**Total Test Coverage**: 132 test cases across 8 test files, ensuring robust validation of all components.

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

## 📊 Key Benefits

### 🎯 **Improved Maintainability**
- **Logical Grouping**: Related functionality is co-located
- **Clear Responsibilities**: Each module has a single, well-defined purpose
- **Easier Navigation**: Developers can quickly find relevant code
- **Reduced Coupling**: Clear module boundaries prevent tight coupling

### 🔄 **Better Development Workflow**
- **Parallel Development**: Different teams can work on different modules
- **Aligned Testing**: Test structure mirrors source organization (8 test files → 4 modules)
- **Easier Code Reviews**: Changes are scoped to relevant modules with matching tests
- **Clear Ownership**: Module structure supports code ownership for both source and tests

### 🛠️ **Enhanced Code Quality**
- **Single Responsibility**: Each file has a focused purpose
- **Dependency Management**: Clear dependency flow prevents circular dependencies
- **Reusability**: Utilities module provides shared functionality
- **Extensibility**: New features can be added to appropriate modules

## 📋 Usage Examples

### Tokenization
```swift
import FeLangCore

let tokenizer = Tokenizer(input: "x ← 1 + 2")
let tokens = try tokenizer.tokenize()
// Tokens are automatically available from Tokenizer module
```

### Expression Parsing
```swift
import FeLangCore

let parser = ExpressionParser()
let expression = try parser.parseExpression(from: tokens)
// Expression types automatically available from Expression module
```

### Statement Parsing
```swift
import FeLangCore

let parser = StatementParser()
let statements = try parser.parseStatements(from: tokens)
// Statement types automatically available from Parser module
```

### Utility Functions
```swift
import FeLangCore

let processed = StringEscapeUtilities.processEscapeSequences("Hello\\nWorld")
// Utility functions available from Utilities module
```

## 🔧 Internal Structure Notes

- **No Breaking Changes**: Public API remains identical
- **Transparent Imports**: `import FeLangCore` continues to work seamlessly
- **Swift Module System**: Swift automatically includes all subdirectory files
- **Backward Compatibility**: Existing code requires no modifications

## 📊 Source-to-Test Mapping

This table shows the clear 1:1 relationship between source modules and their corresponding test suites:

| **Source Module** | **Source Files** | **Test Module** | **Test Files** | **Test Count** |
|-------------------|------------------|-----------------|----------------|----------------|
| **Tokenizer/** | 7 files | **Tokenizer/** | 4 files | ~95 tests |
| **Expression/** | 2 files | **Expression/** | 1 file | ~20 tests |
| **Parser/** | 2 files | **Parser/** | 1 file | ~24 tests |
| **Utilities/** | 1 file | **Utilities/** | 1 file | ~5 tests |
| **Total** | **13 files** | **Total** | **8 files** | **132 tests** |

## 🎨 Development Guidelines

### Adding New Features
1. **Identify Module**: Determine which module the feature belongs to
2. **Create Source File**: Add implementation to appropriate source module
3. **Create Test File**: Add corresponding tests to matching test module
4. **Follow Conventions**: Match existing naming and organization patterns
5. **Update Documentation**: Keep module documentation current
6. **Consider Dependencies**: Minimize cross-module dependencies

### File Naming
- Use descriptive names that indicate the file's primary purpose
- Group related functionality in the same file when appropriate
- Separate concerns into different files when they become large or complex

### Module Evolution
- **Tokenizer**: Add new token types, improve error handling
- **Expression**: Support new expression types, operators
- **Parser**: Add new statement types, language constructs  
- **Utilities**: Add shared functionality needed by multiple modules

This organization provides a solid foundation for the continued development and maintenance of the FeLangCore package! 🎉 