# Tokenizer Module

The **Tokenizer Module** is responsible for breaking input text into tokens for parsing in the FE pseudo-language toolkit.

## 📁 Module Structure

```
Tokenizer/
├── docs/
│   ├── README.md                 # This file - module overview
│   ├── ARCHITECTURE.md           # Internal architecture details
│   ├── PERFORMANCE.md            # Performance optimizations and benchmarks
│   └── EXAMPLES.md              # Usage examples and patterns
├── Token.swift                   # Core token data structure
├── TokenType.swift              # Token type enumeration
├── SourcePosition.swift         # Source position tracking
├── Tokenizer.swift              # Full-featured tokenizer
├── ParsingTokenizer.swift       # Lightweight parsing tokenizer
├── TokenizerError.swift         # Specialized error types
└── TokenizerUtilities.swift     # Shared utilities and keyword maps
```

## 🎯 Purpose

Converts raw source text into a stream of tokens that can be consumed by parsers. Provides two implementations:

- **Tokenizer**: Full-featured tokenizer with comprehensive error reporting
- **ParsingTokenizer**: Lightweight tokenizer optimized for parsing performance

## 🔧 Core Components

### **Token.swift**
Core token data structure containing:
- `type`: TokenType enumeration value
- `lexeme`: Original text representation
- `literal`: Parsed literal value (for literals)
- `position`: Source position information

### **TokenType.swift**
Comprehensive enumeration of all token types:
- Keywords (English & Japanese): `if`/`もし`, `else`/`そうでなければ`, etc.
- Operators: `+`, `-`, `*`, `/`, `=`, `==`, etc.
- Literals: integers, reals, strings, characters, booleans
- Punctuation: `(`, `)`, `[`, `]`, `{`, `}`, `,`, `;`
- Special: `EOF`, `newline`, `whitespace`

### **SourcePosition.swift**
Tracks position information for debugging and error reporting:
- Line and column numbers
- Character offset
- Efficient position tracking during tokenization

## 📖 Usage Examples

### **Basic Tokenization**
```swift
import FeLangCore

let tokenizer = Tokenizer(input: "x ← 1 + 2")
let tokens = try tokenizer.tokenize()

for token in tokens {
    print("\(token.type): '\(token.lexeme)' at \(token.position)")
}
```

### **Parsing-Optimized Tokenization**
```swift
let parsingTokenizer = ParsingTokenizer(input: "if x == 1 then y ← 2")

while !parsingTokenizer.isAtEnd {
    let token = try parsingTokenizer.nextToken()
    // Process token immediately
}
```

### **Error Handling**
```swift
do {
    let tokens = try tokenizer.tokenize()
} catch TokenizerError.unexpectedCharacter(let char, let position) {
    print("Unexpected character '\(char)' at \(position)")
} catch TokenizerError.unterminatedString(let position) {
    print("Unterminated string at \(position)")
}
```

## 🔍 Key Features

### **Multi-Language Support**
```swift
// English keywords
let englishCode = "if x > 0 then y ← x"

// Japanese keywords  
let japaneseCode = "もし x > 0 なら y ← x"

// Both produce identical token streams
```

### **Comprehensive Literal Support**
```swift
// Integer literals
"42", "0", "-123"

// Real literals
"3.14", "0.5", "-2.718"

// String literals with escape sequences
"\"Hello\\nWorld\"", "'c'"

// Boolean literals
"true", "false", "真", "偽"
```

### **Robust Error Detection**
- Invalid characters
- Unterminated strings
- Malformed numbers
- Position tracking for all errors

## ⚡ Performance Features

### **Efficient Character Processing**
- Single-pass tokenization
- Minimal string allocations
- Optimized keyword lookup using hash maps

### **Memory Management**
- Token reuse where possible
- Efficient position tracking
- Minimal object creation

### **Parser Integration**
- `ParsingTokenizer` provides on-demand tokenization
- Reduces memory usage for large files
- Supports streaming tokenization patterns

## 🛡️ Security Features

### **Input Validation**
- Character encoding validation
- Maximum input size limits
- Safe string processing

### **Error Boundaries**
- Controlled error propagation
- Safe handling of malformed input
- Position-aware error reporting

## 🔗 Dependencies

### **Internal Dependencies**
- None - Tokenizer is the foundation layer

### **External Dependencies**
- Swift Foundation (String, Character processing)

## 🧪 Testing

The Tokenizer module has comprehensive test coverage:
- **TokenizerTests.swift**: Core tokenizer functionality
- **ParsingTokenizerTests.swift**: Parser-optimized tokenizer
- **TokenizerConsistencyTests.swift**: Cross-implementation consistency
- **LeadingDotTests.swift**: Edge case handling

See **[../../../Tests/FeLangCoreTests/Tokenizer/](../../../Tests/FeLangCoreTests/Tokenizer/)** for complete test suite.

## 📚 Additional Documentation

- **[ARCHITECTURE.md](ARCHITECTURE.md)**: Internal architecture and design decisions
- **[PERFORMANCE.md](PERFORMANCE.md)**: Performance optimizations and benchmarks
- **[EXAMPLES.md](EXAMPLES.md)**: Advanced usage examples and patterns

---

The **Tokenizer Module** provides the foundation for all text processing in FeLangCore! 🚀 