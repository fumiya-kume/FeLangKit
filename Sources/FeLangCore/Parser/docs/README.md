# Parser Module

The **Parser Module** handles parsing statements and building complete program ASTs for the FE pseudo-language.

## 📁 Module Structure

```
Parser/
├── docs/
│   ├── README.md                 # This file - module overview
│   ├── STATEMENTS.md             # Statement types and syntax
│   └── EXAMPLES.md              # Usage examples and patterns
├── Statement.swift               # Statement AST definitions
└── StatementParser.swift         # Statement parsing logic
```

## 🎯 Purpose

Transforms token streams into complete program ASTs representing the full structure of FE pseudo-language programs.

## 🌳 Statement AST Structure

### Core Statement Types
```swift
public enum Statement: Equatable, CustomStringConvertible {
    case variableDeclaration(VariableDeclaration)
    case assignment(target: String, value: Expression)
    case ifStatement(condition: Expression, thenBranch: [Statement], elseBranch: [Statement]?)
    case whileStatement(condition: Expression, body: [Statement])
    case forStatement(variable: String, iterable: Expression, body: [Statement])
    case functionDeclaration(FunctionDeclaration)
    case procedureDeclaration(ProcedureDeclaration)
    case returnStatement(value: Expression?)
    case expressionStatement(Expression)
    case breakStatement
    case continueStatement
}
```

## 📖 Usage Examples

### Variable Declarations
```swift
let parser = StatementParser()

// Basic variable
let stmt = try parser.parseStatement(from: tokenize("variable x: integer ← 42"))

// Array declaration
let array = try parser.parseStatement(from: tokenize("variable numbers: array[10] of integer"))
```

### Control Flow
```swift
// If statement
let ifStmt = try parser.parseStatement(from: tokenize("""
if x > 0 then
    y ← x * 2
else
    y ← 0
end if
"""))

// While loop
let whileStmt = try parser.parseStatement(from: tokenize("""
while count < 10 do
    count ← count + 1
end while
"""))
```

## 🔍 Key Features

- **Multi-language keywords**: English and Japanese support
- **Complete language constructs**: Variables, control flow, functions
- **Expression integration**: Seamless integration with Expression module
- **Security limits**: Nesting depth protection

## 🔗 Dependencies

- **Expression Module**: For expression parsing
- **Tokenizer Module**: For token processing (via Expression)

## 🧪 Testing

Complete test coverage in **StatementParserTests.swift** with 30+ test cases.

---

The **Parser Module** provides complete FE pseudo-language parsing! 🏗️ 