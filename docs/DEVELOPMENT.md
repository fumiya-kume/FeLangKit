# FeLangCore Development Guide

This document provides comprehensive guidelines for contributing to and developing FeLangCore.

## 🚀 Getting Started

### Prerequisites
- **Swift 5.9+**
- **Xcode 15.0+** (for macOS development)
- **Git** for version control

### Initial Setup
```bash
# Clone the repository
git clone https://github.com/your-org/FeLangKit.git
cd FeLangKit

# Build the project
swift build

# Run tests to verify setup
swift test

# Optional: Run linter for code quality
swiftlint lint
```

## 🏗️ Development Workflow

### 🔄 **Standard Development Process**

1. **Create Feature Branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make Changes Following Guidelines**
   - See [Coding Standards](#-coding-standards)
   - Follow [Module Guidelines](#-module-guidelines)

3. **Write/Update Tests**
   - Add tests for new functionality
   - Update existing tests if needed
   - Ensure all tests pass

4. **Validate Changes**
   ```bash
   swift build                    # Ensure code builds
   swift test                     # Run all tests
   swiftlint lint                 # Check code quality
   ```

5. **Commit and Push**
   ```bash
   git add .
   git commit -m "feat: descriptive commit message"
   git push origin feature/your-feature-name
   ```

6. **Create Pull Request**
   - Provide clear description
   - Reference any related issues
   - Request appropriate reviews

## 📋 Coding Standards

### ✅ **Naming Conventions**

#### **Files and Types**
```swift
// ✅ Good: Clear, descriptive names
struct TokenType { }
class ExpressionParser { }
enum StatementType { }

// ❌ Avoid: Abbreviations or unclear names
struct TokTyp { }
class ExprPars { }
```

#### **Functions and Variables**
```swift
// ✅ Good: Descriptive, action-oriented
func parseComplexExpression() { }
func validateTokenSequence() { }
let currentTokenIndex: Int

// ❌ Avoid: Generic or unclear names
func parse() { }
func check() { }
let idx: Int
```

#### **Constants and Enums**
```swift
// ✅ Good: Clear case names
enum TokenType {
    case keywordIf
    case operatorPlus
    case literalInteger
}

// Constants
static let maxNestingDepth = 50
static let defaultBufferSize = 1024
```

### 🎨 **Code Formatting**

#### **Indentation and Spacing**
```swift
// ✅ Good: Consistent indentation (4 spaces)
if condition {
    let result = processValue(
        parameter1: value1,
        parameter2: value2
    )
    return result
}

// Function declarations
func parseExpression(
    from tokens: [Token],
    at index: Int = 0
) throws -> Expression {
    // Implementation
}
```

#### **Line Length**
- **Maximum 120 characters per line**
- Break long parameter lists across multiple lines
- Use meaningful variable names even if they're longer

#### **Documentation**
```swift
/// Parses a complex arithmetic expression with proper precedence handling.
///
/// This method implements a recursive descent parser for arithmetic expressions,
/// supporting operator precedence and associativity rules.
///
/// - Parameters:
///   - tokens: Array of tokens to parse
///   - index: Starting position in the token array
/// - Returns: Parsed Expression AST node
/// - Throws: ParsingError if the expression is malformed
func parseArithmeticExpression(
    from tokens: [Token], 
    at index: Int
) throws -> Expression {
    // Implementation
}
```

### 🛡️ **Error Handling**

#### **Error Types**
```swift
// ✅ Good: Specific, descriptive errors
enum ParsingError: Error, LocalizedError {
    case unexpectedToken(Token, expected: String)
    case expressionTooComplex(depth: Int, maxDepth: Int)
    case invalidAssignmentTarget
    
    var errorDescription: String? {
        switch self {
        case .unexpectedToken(let token, let expected):
            return "Unexpected token '\(token.lexeme)', expected \(expected)"
        case .expressionTooComplex(let depth, let maxDepth):
            return "Expression nesting too deep (\(depth) > \(maxDepth))"
        case .invalidAssignmentTarget:
            return "Invalid left-hand side in assignment"
        }
    }
}
```

#### **Error Handling Patterns**
```swift
// ✅ Good: Proper error propagation
func parseStatement() throws -> Statement {
    guard !tokens.isEmpty else {
        throw ParsingError.unexpectedEndOfInput
    }
    
    // Try parsing different statement types
    do {
        return try parseAssignmentStatement()
    } catch ParsingError.unexpectedToken {
        // Fall back to expression statement
        return try parseExpressionStatement()
    }
}
```

## 🏗️ Module Guidelines

### 📝 **Adding New Features**

#### **1. Identify Module**
Determine which module your feature belongs to:
- **Tokenizer**: Text processing, token generation, lexical analysis
- **Expression**: Expression parsing, AST generation, operator handling
- **Parser**: Statement parsing, control flow, language constructs
- **Utilities**: Shared functionality, helper functions

#### **2. Follow Module Patterns**
```swift
// ✅ Good: Follow existing patterns in the module
// In Expression module:
extension Expression {
    // New expression types follow existing patterns
    case customOperation(operator: String, operands: [Expression])
}

// In ExpressionParser:
func parseCustomOperation() throws -> Expression {
    // Follow existing parsing patterns
}
```

#### **3. Maintain Dependencies**
```swift
// ✅ Good: Respect dependency flow
// Parser can use Expression and Tokenizer
import FeLangCore // Access to all modules

class StatementParser {
    private let expressionParser = ExpressionParser() // ✅ OK
    
    func parseStatement() throws -> Statement {
        let expr = try expressionParser.parseExpression() // ✅ OK
    }
}

// ❌ Avoid: Circular dependencies
// Expression should not depend on Parser
```

### 🧪 **Testing New Features**

#### **Test Organization**
```swift
// ✅ Good: Tests mirror source structure
// For new tokenizer feature:
// Source: Sources/FeLangCore/Tokenizer/NewFeature.swift
// Test:   Tests/FeLangCoreTests/Tokenizer/NewFeatureTests.swift

@Test("New feature handles edge cases correctly")
func testNewFeatureEdgeCases() throws {
    // Test implementation
}
```

#### **Test Categories**
- **Unit Tests**: Test individual functions/methods
- **Integration Tests**: Test module interactions
- **Security Tests**: Test limits and edge cases
- **Performance Tests**: Verify efficiency requirements

### 📚 **Documentation Updates**

When adding features, update relevant documentation:
- **ARCHITECTURE.md**: If adding new modules or changing dependencies
- **TESTING.md**: If adding new test categories or patterns
- **README.md**: If changing public API or usage patterns

## 🔧 Development Tools

### 🧹 **Code Quality Tools**

#### **SwiftLint Configuration**
```yaml
# .swiftlint.yml
disabled_rules:
  - todo # Allow TODO comments during development
  
opt_in_rules:
  - explicit_type_interface
  - multiline_arguments
  - sorted_imports

line_length:
  warning: 120
  error: 150

function_body_length:
  warning: 60
  error: 100
```

#### **Running Quality Checks**
```bash
# Check code style
swiftlint lint

# Auto-fix style issues
swiftlint lint --fix

# Check specific files
swiftlint lint Sources/FeLangCore/Expression/
```

### 🔍 **Debugging Tools**

#### **Print Debugging**
```swift
// ✅ Good: Structured debug output
func parseExpression() throws -> Expression {
    #if DEBUG
    print("🔍 Parsing expression at token: \(currentToken)")
    #endif
    
    let result = try parseComplexExpression()
    
    #if DEBUG
    print("✅ Parsed expression: \(result)")
    #endif
    
    return result
}
```

#### **Test Debugging**
```swift
@Test("Complex expression parsing")
func testComplexExpression() throws {
    let input = "1 + 2 * 3"
    let parser = ExpressionParser()
    
    // Enable debug output for failing tests
    let result = try parser.parseExpression(input, debug: true)
    
    #expect(result.type == .binaryOperation)
}
```

## 🚀 Performance Guidelines

### ⚡ **Optimization Principles**

#### **Memory Management**
```swift
// ✅ Good: Efficient memory usage
func tokenize(input: String) -> [Token] {
    var tokens: [Token] = []
    tokens.reserveCapacity(input.count / 4) // Estimate capacity
    
    // Process input efficiently
    for character in input {
        // Avoid unnecessary string copies
    }
    
    return tokens
}
```

#### **Algorithmic Efficiency**
```swift
// ✅ Good: O(1) lookups where possible
static let keywordMap: [String: TokenType] = [
    "if": .keywordIf,
    "else": .keywordElse,
    "while": .keywordWhile
]

func identifyKeyword(_ lexeme: String) -> TokenType? {
    return keywordMap[lexeme] // O(1) lookup
}
```

### 🛡️ **Security Considerations**

#### **Input Validation**
```swift
// ✅ Good: Validate input bounds
func parseExpression(nestingDepth: Int = 0) throws -> Expression {
    guard nestingDepth < maxNestingDepth else {
        throw ParsingError.expressionTooComplex(
            depth: nestingDepth, 
            maxDepth: maxNestingDepth
        )
    }
    
    // Continue parsing with incremented depth
}
```

## 🤝 Contributing Guidelines

### 📝 **Pull Request Process**

#### **PR Description Template**
```markdown
## Description
Brief description of changes made.

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] All existing tests pass
- [ ] New tests added for new functionality
- [ ] Manual testing completed

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] No merge conflicts
```

#### **Review Guidelines**
- **Code Quality**: Style, organization, clarity
- **Functionality**: Correctness, edge cases, error handling
- **Performance**: Efficiency, memory usage
- **Testing**: Coverage, quality, organization
- **Documentation**: Clarity, completeness

### 🔄 **Version Management**

#### **Semantic Versioning**
- **MAJOR**: Breaking changes to public API
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes, backward compatible

#### **Changelog Maintenance**
Keep `CHANGELOG.md` updated with:
- New features
- Bug fixes
- Breaking changes
- Performance improvements

## 📚 Additional Resources

### **Swift Resources**
- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- [Swift Programming Language Guide](https://docs.swift.org/swift-book/)

### **Compiler Design Resources**
- [Crafting Interpreters](https://craftinginterpreters.com/)
- [Dragon Book (Compilers: Principles, Techniques, and Tools)](https://www.amazon.com/Compilers-Principles-Techniques-Tools-2nd/dp/0321486811)

### **Project-Specific Documentation**
- **[ARCHITECTURE.md](ARCHITECTURE.md)**: Module structure and dependencies
- **[TESTING.md](TESTING.md)**: Testing guidelines and organization
- **[MIGRATION.md](MIGRATION.md)**: Package reorganization history

---

Thank you for contributing to FeLangCore! Together we're building a robust foundation for the FE pseudo-language toolkit! 🎉 