# Tokenizer Module Architecture

The **Tokenizer Module** implements a robust lexical analysis system for the FE pseudo-language with comprehensive keyword management and security features.

## 🏗️ Architecture Overview

### Core Components

```
TokenizerUtilities.swift     # Shared utilities and keyword definitions
├── Keywords                 # Longest-first ordered keyword array  
├── Character Classification # Unicode-aware identifier detection
├── String Matching         # Efficient pattern matching utilities
└── Position Calculation    # Source position tracking

Tokenizer.swift             # Full-featured tokenizer
├── Character-by-character  # Complete tokenization with full error handling
├── Position Tracking      # Line, column, and offset tracking
└── Security Limits        # Input size and complexity protection

ParsingTokenizer.swift      # Lightweight parser-optimized tokenizer
├── Token Stream           # On-demand tokenization for parsing
├── Minimal Overhead       # Optimized for parsing performance
└── Consistent API         # Same interface as full tokenizer
```

## 🔤 Keyword Management System

### Longest-First Ordering Strategy

The tokenizer uses a **longest-first ordering** strategy to prevent prefix matching conflicts. This ensures that longer keywords are checked before shorter ones that might be prefixes.

#### Current Keyword Ordering
```swift
// 12 characters
"endprocedure"

// 11 characters  
"endfunction"

// 9 characters
"procedure"

// 8 characters
"endwhile", "function"

// 6 characters
"return", "endfor"

// 5 characters
"endif", "break", "while", "false"

// 4 characters
"文字列型", "レコード", "true", "then", "else", "elif", "step"

// 3 characters
"整数型", "実数型", "文字型", "論理型", "and", "not", "for"

// 2 characters
"配列", "or", "to", "in", "do", "if"
```

#### Why Longest-First Matters

Without proper ordering, shorter keywords could match prefixes of longer keywords:

```swift
// ❌ Problematic ordering:
["if", "endif"]
// Input: "endif" would incorrectly match "if" first

// ✅ Correct ordering:
["endif", "if"] 
// Input: "endif" correctly matches complete keyword
```

### Implementation Details

#### Method 1: Complete Identifier Extraction (Current)
Both tokenizers extract complete identifiers first, then check if they're keywords:

```swift
// Extract complete identifier
let lexeme = extractIdentifier() // e.g., "endif"

// O(1) hash map lookup
if let tokenType = keywordMap[lexeme] {
    return keyword(tokenType, lexeme)
} else {
    return identifier(lexeme)
}
```

**Advantages:**
- O(1) keyword lookup performance
- Natural word boundary handling
- No prefix matching issues

#### Method 2: Ordered Prefix Matching (Alternative)
For tokenizers that check keywords incrementally:

```swift
// Check keywords in longest-first order
for (keyword, tokenType) in orderedKeywords {
    if input.hasPrefix(keyword) && isWordBoundary(after: keyword) {
        return token(tokenType, keyword)
    }
}
```

**Advantages:**
- Early termination on first match
- Explicit longest-first guarantees
- Works with streaming tokenization

### Keyword Categories

#### Japanese Data Type Keywords (CJK)
- **文字列型** (4 chars) - String type
- **レコード** (4 chars) - Record type  
- **整数型** (3 chars) - Integer type
- **実数型** (3 chars) - Real type
- **文字型** (3 chars) - Character type
- **論理型** (3 chars) - Boolean type
- **配列** (2 chars) - Array type

#### English Control Flow Keywords
- **endprocedure** (12 chars) - Procedure end
- **endfunction** (11 chars) - Function end
- **procedure** (9 chars) - Procedure declaration
- **endwhile** (8 chars) - While loop end
- **function** (8 chars) - Function declaration
- **return** (6 chars) - Return statement
- **endfor** (6 chars) - For loop end
- **endif** (5 chars) - If statement end
- **break** (5 chars) - Break statement
- **while** (5 chars) - While loop
- **false** (5 chars) - Boolean literal
- **true** (4 chars) - Boolean literal
- **then** (4 chars) - If condition separator
- **else** (4 chars) - Else clause
- **elif** (4 chars) - Else-if clause
- **step** (4 chars) - For loop step
- **and** (3 chars) - Logical AND
- **not** (3 chars) - Logical NOT
- **for** (3 chars) - For loop
- **or** (2 chars) - Logical OR
- **to** (2 chars) - Range separator
- **in** (2 chars) - Iterator separator
- **do** (2 chars) - Block start
- **if** (2 chars) - Conditional

## 🔍 Character Classification System

### Unicode-Aware Identifier Detection

The tokenizer supports full Unicode identifier rules with special handling for CJK characters:

```swift
func isIdentifierStart(_ char: Character) -> Bool {
    return char.isLetter || char == "_" || isJapaneseCharacter(char)
}

func isIdentifierContinue(_ char: Character) -> Bool {
    return char.isLetter || char.isNumber || char == "_" || isJapaneseCharacter(char)
}
```

### CJK Character Support

Comprehensive Unicode range support for Japanese characters:

```swift
func isJapaneseCharacter(_ scalar: UnicodeScalar) -> Bool {
    let value = scalar.value
    return (value >= 0x3040 && value <= 0x309F) ||  // Hiragana
           (value >= 0x30A0 && value <= 0x30FF) ||  // Katakana  
           (value >= 0x4E00 && value <= 0x9FAF) ||  // CJK Unified Ideographs
           (value >= 0x3400 && value <= 0x4DBF) ||  // CJK Extension A
           (value >= 0x20000 && value <= 0x2A6DF)   // CJK Extension B
}
```

## 🛡️ Security Features

### Input Validation
- **Size limits**: Protection against extremely large inputs
- **Character validation**: Safe Unicode processing
- **Memory bounds**: Controlled memory allocation

### Position Tracking
- **Line and column**: Accurate error reporting
- **Character offset**: Precise error locations
- **Efficient calculation**: Minimal performance overhead

### Error Boundaries
- **Controlled propagation**: Safe error handling
- **Position-aware errors**: Detailed error context
- **Graceful degradation**: Robust failure modes

## ⚡ Performance Optimizations

### Hash Map Lookups
- **O(1) keyword identification**: Constant-time keyword detection
- **Pre-computed maps**: Static initialization for efficiency
- **Memory efficient**: Minimal space overhead

### String Processing
- **Single-pass tokenization**: No backtracking required
- **Minimal allocations**: Efficient string handling
- **Unicode optimized**: Fast CJK character processing

### Caching Strategies
- **Position calculation**: Efficient line/column tracking
- **Character classification**: Optimized Unicode category checks

## 🔧 Future Extensibility

### Adding New Keywords

When adding new keywords, follow the longest-first ordering principle:

1. **Determine length**: Count characters in new keyword
2. **Find insertion point**: Locate correct position by length
3. **Insert in order**: Maintain longest-first within same length
4. **Update tests**: Verify no conflicts introduced
5. **Document changes**: Update this architecture document

### Keyword Conflict Detection

Use the verification script pattern to check for conflicts:

```swift
// Check for prefix conflicts
for i in 0..<keywords.count {
    for j in (i+1)..<keywords.count {
        if keywords[i].hasPrefix(keywords[j]) {
            print("CONFLICT: \(keywords[i]) contains prefix \(keywords[j])")
        }
    }
}
```

---

This architecture ensures **robust**, **efficient**, and **scalable** lexical analysis for the FE pseudo-language! 🚀 