# Unicode Normalization and Extended Character Support

This document describes the comprehensive Unicode normalization system implemented in FeLangKit, providing robust support for international text processing with enhanced security features.

## Overview

The Unicode normalization system in FeLangKit provides:

- **Multiple Normalization Forms**: NFC, NFD, NFKC, NFKD support
- **Enhanced Character Classification**: Detailed Unicode General Category classification
- **Security Features**: Homoglyph detection, bidirectional text protection, normalization attack prevention
- **Extended Character Support**: Emoji, mathematical symbols, CJK extensions, private use area characters
- **Comprehensive Statistics**: Detailed tracking of all normalization operations

## Quick Start

### Basic Usage

```swift
// Simple normalization (default NFC form)
let normalized = UnicodeNormalizer.normalizeForFE(text)

// Or using string extension
let normalized = text.normalizedForFE
```

### Advanced Usage with Statistics

```swift
var normalizer = UnicodeNormalizer()
let result = normalizer.normalize(text, form: .nfkc)
let stats = normalizer.getStats()

print("Applied \(stats.fullwidthConversions) full-width conversions")
print("Detected \(stats.homoglyphsDetected) potential homoglyphs")
print("Security concerns: \(stats.hasSecurityConcerns)")
```

### One-shot Analysis

```swift
let (normalized, stats) = text.normalizedForFEWithStats(
    form: .nfc,
    securityConfig: UnicodeNormalizer.SecurityConfig()
)
```

## Normalization Forms

### NFC (Canonical Decomposition followed by Canonical Composition) - Default
- Preferred form for most applications
- Composes combining characters into precomposed forms
- Example: `e + ́` → `é`

```swift
let result = normalizer.normalize(text, form: .nfc)
```

### NFD (Canonical Decomposition)
- Decomposes precomposed characters into base + combining marks
- Useful for detailed character analysis
- Example: `é` → `e + ́`

```swift
let result = normalizer.normalize(text, form: .nfd)
```

### NFKC (Compatibility Decomposition followed by Canonical Composition)
- Decomposes compatibility characters and then composes
- Normalizes formatting variations
- Example: `ﬁ` → `fi`

```swift
let result = normalizer.normalize(text, form: .nfkc)
```

### NFKD (Compatibility Decomposition)
- Applies both compatibility and canonical decomposition
- Most comprehensive decomposition
- Useful for search and comparison

```swift
let result = normalizer.normalize(text, form: .nfkd)
```

## Character Classification System

The enhanced character classification system provides detailed Unicode General Category information:

```swift
let scalar = UnicodeScalar("π")!
let classification = UnicodeNormalizer.classifyCharacter(scalar)

switch classification {
case .letter(let subcategory):
    print("Letter: \(subcategory)")
case .symbol(let subcategory):
    print("Symbol: \(subcategory)")  // .mathSymbol for π
case .number(let subcategory):
    print("Number: \(subcategory)")
// ... other categories
}
```

### Supported Categories

- **Letters**: Uppercase, lowercase, titlecase, modifier, other (includes CJK)
- **Marks**: Nonspacing, spacing combining, enclosing
- **Numbers**: Decimal digit, letter, other
- **Punctuation**: Connector, dash, open, close, initial, final, other
- **Symbols**: Math, currency, modifier, other (includes emoji)
- **Separators**: Space, line, paragraph
- **Other**: Control, format, surrogate, private use, not assigned

## Security Features

### Homoglyph Detection and Mitigation

Detects and converts characters that look similar but have different Unicode codepoints:

```swift
let homoglyphText = "асе"  // Cyrillic letters that look like Latin "ace"
let normalized = UnicodeNormalizer.normalizeForFE(homoglyphText)
// Result: "ace" (converted to Latin)
```

**Supported Homoglyph Sets:**
- Cyrillic ↔ Latin
- Greek ↔ Latin (mathematical contexts)

### Bidirectional Text Protection

Removes dangerous bidirectional formatting characters that could be used for attacks:

```swift
let dangerousText = "normal\u{202E}dangerous\u{202C}text"
let safe = UnicodeNormalizer.normalizeForFE(dangerousText)
// Result: "normaldangeroustext" (bidi formatting removed)
```

**Removed Characters:**
- LRE (Left-to-Right Embedding)
- RLE (Right-to-Left Embedding)
- PDF (Pop Directional Formatting)
- LRO/RLO (Left/Right-to-Right Override)
- LRI/RLI/FSI/PDI (Isolate controls)

### Security Configuration

```swift
let securityConfig = UnicodeNormalizer.SecurityConfig(
    enableHomoglyphDetection: true,      // Default: true
    preventNormalizationAttacks: true,   // Default: true
    maxNormalizedLength: 10000,          // Default: 10000
    detectBidiReordering: true           // Default: true
)

let normalizer = UnicodeNormalizer(securityConfig: securityConfig)
```

## Extended Character Support

### Mathematical Symbols

Converts mathematical symbols to programming-friendly equivalents:

```swift
let mathText = "π × α ÷ β ≈ ∞"
let normalized = UnicodeNormalizer.normalizeForFE(mathText)
// Result: "pi * alpha / beta ~= infinity"
```

**Supported Conversions:**
- Greek letters: `π` → `pi`, `α` → `alpha`, `β` → `beta`, etc.
- Math operators: `×` → `*`, `÷` → `/`, `≈` → `~=`
- Special symbols: `∞` → `infinity`, `∑` → `sum`, `∏` → `product`

### Emoji Normalization

Removes variation selectors for consistent emoji handling:

```swift
let emojiText = "😀\u{FE0F}👋\u{FE0E}"  // With variation selectors
let normalized = UnicodeNormalizer.normalizeForFE(emojiText)
// Result: "😀👋" (variation selectors removed)
```

### CJK and Extended Character Sets

Preserves important character sets while normalizing where appropriate:

- **CJK Extension A/B**: Preserved for linguistic accuracy
- **Private Use Area**: Preserved for custom symbols
- **Japanese Characters**: Selective normalization of confusing variants

## Statistics and Analysis

### Available Statistics

```swift
let stats = normalizer.getStats()

print("Original length: \(stats.originalLength)")
print("Normalized length: \(stats.normalizedLength)")
print("Compression ratio: \(stats.compressionRatio)")

print("Full-width conversions: \(stats.fullwidthConversions)")
print("NFC normalizations: \(stats.nfcNormalizations)")
print("Japanese normalizations: \(stats.japaneseNormalizations)")
print("Emoji normalizations: \(stats.emojiNormalizations)")
print("Math symbol normalizations: \(stats.mathSymbolNormalizations)")

print("Bidi reorderings: \(stats.bidiReorderings)")
print("Homoglyphs detected: \(stats.homoglyphsDetected)")
print("Security issues: \(stats.securityIssuesFound)")

print("Has security concerns: \(stats.hasSecurityConcerns)")
```

### Detailed Analysis

```swift
let analysis = normalizer.analyzeNormalization(text)

print("Changes needed: \(analysis.hasChanges)")
print("Security concerns: \(analysis.hasSecurityConcerns)")
print("Summary: \(analysis.summary)")
```

## Tokenizer Integration

The Unicode normalization is automatically applied during tokenization:

```swift
let tokenizer = Tokenizer(input: "変数　ＶＡＲ　＝　π")
let tokens = try tokenizer.tokenize()

// Tokens will contain normalized identifiers:
// - "変数" (preserved Japanese)
// - "VAR" (normalized from full-width)
// - "=" (normalized from full-width)
// - "pi" (normalized from π)
```

### Enhanced Identifier Support

The tokenizer now supports:

- **Unicode letters** of all categories
- **Combining marks** in identifiers
- **Private use area** characters for custom symbols
- **Comprehensive CJK** support including extensions

```swift
// All of these are valid identifiers:
let examples = [
    "变量",           // Chinese
    "変数",           // Japanese
    "переменная",     // Russian
    "μεταβλητή",      // Greek
    "𝕧𝖆𝖗𝖎𝖆𝖇𝖑𝖊",      // Mathematical symbols
    "café",          // With combining characters
    "\u{E000}custom" // Private use area
]
```

## Best Practices

### When to Use Different Forms

- **NFC**: Default for most applications, storage, and comparison
- **NFD**: When you need to analyze individual combining marks
- **NFKC**: When you want to normalize formatting differences
- **NFKD**: For comprehensive search and indexing

### Security Considerations

1. **Always enable security features** in user-facing applications
2. **Set appropriate length limits** to prevent DoS attacks
3. **Monitor security statistics** in logs for attack detection
4. **Use strict configuration** for sensitive contexts

```swift
// Recommended secure configuration
let secureConfig = UnicodeNormalizer.SecurityConfig(
    enableHomoglyphDetection: true,
    preventNormalizationAttacks: true,
    maxNormalizedLength: 1000,  // Adjust based on your needs
    detectBidiReordering: true
)
```

### Performance Considerations

- **Cache normalized results** for frequently used strings
- **Use static methods** when statistics are not needed
- **Consider batch processing** for large datasets
- **Monitor processing time** for very long strings

### Error Handling

```swift
// The normalizer is designed to be robust and not throw errors
// Instead, it tracks issues in statistics
let result = normalizer.normalize(potentiallyDangerousText)
let stats = normalizer.getStats()

if stats.hasSecurityConcerns {
    // Log security concerns
    logger.warning("Detected \(stats.homoglyphsDetected) homoglyphs")
    logger.warning("Detected \(stats.bidiReorderings) bidi issues")
}

if stats.securityIssuesFound > 0 {
    // Handle potential attacks
    logger.error("Security issue detected, normalization limited")
}
```

## Migration Guide

### From Basic to Enhanced System

If you were using the basic normalization:

```swift
// Old way
let normalized = text.normalizedForFE

// New way (same result, enhanced features)
let normalized = text.normalizedForFE  // Still works!

// Or with full control
let (normalized, stats) = text.normalizedForFEWithStats(
    form: .nfc,
    securityConfig: UnicodeNormalizer.SecurityConfig()
)
```

### Updating Tokenizer Usage

The tokenizer automatically uses the enhanced system, but you may want to verify the behavior:

```swift
// Test with complex Unicode text
let tokenizer = Tokenizer(input: complexUnicodeText)
let tokens = try tokenizer.tokenize()

// Verify normalization worked as expected
for token in tokens {
    print("Token: \(token.lexeme) (type: \(token.type))")
}
```

## Examples

### Complete Example: Processing User Input

```swift
func processUserCode(_ input: String) throws -> [Token] {
    // Create normalizer with strict security
    var normalizer = UnicodeNormalizer(securityConfig: UnicodeNormalizer.SecurityConfig(
        enableHomoglyphDetection: true,
        preventNormalizationAttacks: true,
        maxNormalizedLength: 10000,
        detectBidiReordering: true
    ))
    
    // Normalize and analyze
    let normalized = normalizer.normalize(input, form: .nfc)
    let stats = normalizer.getStats()
    
    // Log security concerns
    if stats.hasSecurityConcerns {
        print("Security concerns detected:")
        print("- Homoglyphs: \(stats.homoglyphsDetected)")
        print("- Bidi issues: \(stats.bidiReorderings)")
    }
    
    // Log normalization applied
    if stats.fullwidthConversions > 0 {
        print("Normalized \(stats.fullwidthConversions) full-width characters")
    }
    if stats.mathSymbolNormalizations > 0 {
        print("Normalized \(stats.mathSymbolNormalizations) mathematical symbols")
    }
    
    // Tokenize the normalized input
    let tokenizer = Tokenizer(input: normalized)
    return try tokenizer.tokenize()
}
```

### Example: Analyzing Text for Security

```swift
func analyzeTextSecurity(_ text: String) -> SecurityReport {
    let normalizer = UnicodeNormalizer()
    let analysis = normalizer.analyzeNormalization(text)
    
    return SecurityReport(
        hasHomoglyphs: analysis.homoglyphsDetected > 0,
        hasBidiIssues: analysis.bidiIssuesFound > 0,
        hasSecurityConcerns: analysis.hasSecurityConcerns,
        summary: analysis.summary
    )
}
```

## Conclusion

The enhanced Unicode normalization system in FeLangKit provides comprehensive support for international text processing while maintaining security and performance. It automatically handles the complexities of Unicode normalization, allowing developers to focus on their language implementation while ensuring robust, secure text processing.

For more information, see the test suite in `Tests/FeLangCoreTests/Utilities/UnicodeNormalizationTests.swift` for comprehensive examples of all features. 