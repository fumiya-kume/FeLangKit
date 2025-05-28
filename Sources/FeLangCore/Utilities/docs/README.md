# Utilities Module

The **Utilities Module** provides shared functionality used across all modules in FeLangCore.

## 📁 Module Structure

```
Utilities/
├── docs/
│   └── README.md                 # This file - module overview
└── StringEscapeUtilities.swift   # String escape sequence processing
```

## 🎯 Purpose

Provides centralized utility functions that are shared across multiple modules, eliminating code duplication.

## 🔧 Core Components

### **StringEscapeUtilities.swift**

Handles escape sequence processing for string and character literals.

#### Supported Escape Sequences
- `\"` - Double quote
- `\'` - Single quote  
- `\\` - Backslash
- `\n` - Newline
- `\r` - Carriage return
- `\t` - Tab
- `\0` - Null character

## 📖 Usage Examples

```swift
import FeLangCore

// Process escape sequences
let processed = try StringEscapeUtilities.processEscapeSequences("Hello\\nWorld")
// Result: "Hello\nWorld"

// Validate before processing
try StringEscapeUtilities.validateEscapeSequences("Valid\\tString")
```

## 🔍 Key Features

- **Comprehensive escape support**: All standard escape sequences
- **Robust error detection**: Invalid sequences are caught
- **Performance optimized**: Fast path for strings without escapes
- **Cross-module usage**: Used by Tokenizer, Expression, and Parser modules

## 🔗 Dependencies

- **Internal**: None - foundation module
- **External**: Swift Foundation

## 🧪 Testing

Complete test coverage in **StringEscapeUtilitiesTests.swift**.

---

The **Utilities Module** provides efficient shared functionality! 🛠️ 