# Expression Module

The **Expression Module** handles parsing and representing expressions in the FE pseudo-language, providing complete AST (Abstract Syntax Tree) generation with proper operator precedence and associativity.

## 📁 Module Structure

```
Expression/
├── docs/
│   ├── README.md                 # This file - module overview
│   ├── AST.md                   # AST structure and node types
│   ├── PARSING.md               # Parsing algorithms and precedence
│   └── EXAMPLES.md              # Usage examples and patterns
├── Expression.swift             # Expression AST definitions
└── ExpressionParser.swift       # Expression parsing logic
```

## 🎯 Purpose

Transforms tokens from the Tokenizer module into structured expression ASTs that represent the semantic meaning of mathematical, logical, and functional expressions in the FE pseudo-language.

## 🌳 Expression AST Structure

### **Core Expression Types**

```swift
public enum Expression: Equatable, CustomStringConvertible {
    // Literals
    case literal(Literal)
    
    // Operations
    case binaryOperation(left: Expression, operator: BinaryOperator, right: Expression)
    case unaryOperation(operator: UnaryOperator, operand: Expression)
    
    // Access operations
    case functionCall(name: String, arguments: [Expression])
    case fieldAccess(object: Expression, field: String)
    case arrayAccess(array: Expression, index: Expression)
    
    // Grouping
    case grouping(Expression)
}
```

### **Literal Types**

```swift
public enum Literal: Equatable, CustomStringConvertible {
    case integer(Int)
    case real(Double)
    case string(String)
    case character(Character)
    case boolean(Bool)
}
```

### **Operator Types**

```swift
// Binary operators with precedence levels
public enum BinaryOperator: String, CaseIterable {
    // Arithmetic (higher precedence)
    case multiply = "*"
    case divide = "/"
    case modulo = "%"
    case plus = "+"
    case minus = "-"
    
    // Comparison
    case equal = "=="
    case notEqual = "!="
    case less = "<"
    case lessEqual = "<="
    case greater = ">"
    case greaterEqual = ">="
    
    // Logical (lower precedence)
    case and = "&&"
    case or = "||"
}

// Unary operators
public enum UnaryOperator: String, CaseIterable {
    case not = "!"
    case plus = "+"
    case minus = "-"
}
```

## 🔧 Parsing Features

### **Operator Precedence**
The parser implements proper operator precedence following mathematical conventions:

1. **Parentheses**: `()` - Highest precedence
2. **Unary operators**: `!`, `+`, `-`
3. **Multiplicative**: `*`, `/`, `%`
4. **Additive**: `+`, `-`
5. **Comparison**: `==`, `!=`, `<`, `<=`, `>`, `>=`
6. **Logical AND**: `&&`
7. **Logical OR**: `||` - Lowest precedence

### **Associativity**
- **Left-associative**: Most binary operators (`1 + 2 + 3` = `(1 + 2) + 3`)
- **Right-associative**: Unary operators

### **Security Features**
- **Nesting depth limits**: Prevents stack overflow attacks
- **Expression complexity limits**: Guards against excessive recursion
- **Safe parsing**: Robust error handling and recovery

## 📖 Usage Examples

### **Basic Expression Parsing**
```swift
import FeLangCore

let parser = ExpressionParser()

// Simple arithmetic
let expr1 = try parser.parseExpression(from: tokenize("1 + 2 * 3"))
// Result: binaryOperation(literal(1), +, binaryOperation(literal(2), *, literal(3)))

// With parentheses
let expr2 = try parser.parseExpression(from: tokenize("(1 + 2) * 3"))
// Result: binaryOperation(grouping(binaryOperation(literal(1), +, literal(2))), *, literal(3))
```

### **Complex Expressions**
```swift
// Function calls with arguments
let expr3 = try parser.parseExpression(from: tokenize("max(a, b + 1)"))
// Result: functionCall("max", [identifier("a"), binaryOperation(identifier("b"), +, literal(1))])

// Field access chaining
let expr4 = try parser.parseExpression(from: tokenize("person.address.street"))
// Result: fieldAccess(fieldAccess(identifier("person"), "address"), "street")

// Array access
let expr5 = try parser.parseExpression(from: tokenize("numbers[index + 1]"))
// Result: arrayAccess(identifier("numbers"), binaryOperation(identifier("index"), +, literal(1)))
```

### **Boolean Logic**
```swift
// Logical operations
let expr6 = try parser.parseExpression(from: tokenize("x > 0 && y < 10"))
// Result: binaryOperation(
//   binaryOperation(identifier("x"), >, literal(0)),
//   &&,
//   binaryOperation(identifier("y"), <, literal(10))
// )

// Unary operations
let expr7 = try parser.parseExpression(from: tokenize("!isValid"))
// Result: unaryOperation(!, identifier("isValid"))
```

### **Error Handling**
```swift
do {
    let expression = try parser.parseExpression(from: tokens)
    print("Parsed: \(expression)")
} catch ParsingError.unexpectedToken(let token, let expected) {
    print("Unexpected token '\(token.lexeme)', expected \(expected)")
} catch ParsingError.expressionTooComplex(let depth, let maxDepth) {
    print("Expression too complex: depth \(depth) exceeds limit \(maxDepth)")
}
```

## 🔍 Key Features

### **Comprehensive Literal Support**
```swift
// Numeric literals
let int = try parser.parseExpression(from: tokenize("42"))
let real = try parser.parseExpression(from: tokenize("3.14"))

// String and character literals
let str = try parser.parseExpression(from: tokenize("\"Hello, World!\""))
let char = try parser.parseExpression(from: tokenize("'A'"))

// Boolean literals
let bool = try parser.parseExpression(from: tokenize("true"))
```

### **Postfix Operation Chaining**
```swift
// Multiple postfix operations
let complex = try parser.parseExpression(from: tokenize("obj.method(arg)[index].field"))
// Parsed as: fieldAccess(arrayAccess(functionCall(fieldAccess(obj, method), [arg]), index), field)
```

### **Precedence-Aware Parsing**
```swift
// Respects mathematical precedence
let math = try parser.parseExpression(from: tokenize("2 + 3 * 4"))
// Result: 2 + (3 * 4), not (2 + 3) * 4

// Comparison operators
let comparison = try parser.parseExpression(from: tokenize("x + 1 > y * 2"))
// Result: (x + 1) > (y * 2)
```

## ⚡ Performance Features

### **Recursive Descent Optimization**
- Single-pass parsing
- Minimal backtracking
- Efficient precedence climbing

### **Memory Efficiency**
- Minimal AST node allocation
- Efficient token consumption
- Reusable parser instances

### **Security Limits**
- Maximum nesting depth: 50 levels
- Expression complexity tracking
- Stack overflow prevention

## 🛡️ Security Features

### **Input Validation**
- Token sequence validation
- Expression depth monitoring
- Safe recursion limits

### **Error Recovery**
- Graceful error handling
- Position-aware error messages
- Safe parsing state management

## 🔗 Dependencies

### **Internal Dependencies**
- **Tokenizer Module**: For `Token`, `TokenType`, and token stream processing

### **External Dependencies**
- Swift Foundation (String, Double, Int processing)

## 🧪 Testing

The Expression module has comprehensive test coverage:
- **ExpressionParserTests.swift**: Core parsing functionality with 47+ test cases

See **[../../../Tests/FeLangCoreTests/Expression/](../../../Tests/FeLangCoreTests/Expression/)** for complete test suite.

### **Test Categories**
- Literal parsing (integers, reals, strings, characters, booleans)
- Binary operations with precedence
- Unary operations
- Function calls with complex arguments
- Field access and chaining
- Array access with expression indices
- Error conditions and edge cases
- Security limits and depth protection

## 📚 Additional Documentation

- **[AST.md](AST.md)**: Complete AST structure documentation
- **[PARSING.md](PARSING.md)**: Parsing algorithms and precedence rules
- **[EXAMPLES.md](EXAMPLES.md)**: Advanced usage examples and patterns

---

The **Expression Module** provides robust expression parsing with mathematical precision! 🧮 