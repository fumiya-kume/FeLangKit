# Code Duplication Refactoring Plan

## 🎯 Overview
This document outlines the refactoring needed to eliminate significant code duplication across the Parser and Tokenizer modules in FeLangKit.

## 🔍 Identified Duplications

### 1. **Tokenizer Parsing Methods Duplication**

**Problem**: Multiple tokenizer implementations have nearly identical parsing methods:
- `parseKeyword()` - duplicated across 4+ tokenizers
- `parseOperator()` - duplicated across 4+ tokenizers  
- `parseDelimiter()` - duplicated across 4+ tokenizers
- `parseNumber()` - multiple variants with different error handling
- `parseIdentifier()` - duplicated logic

**Files Affected**:
- `EnhancedParsingTokenizer.swift` (lines 515-655)
- `ParsingTokenizer.swift` (lines 151-287)
- `FastParsingTokenizer.swift` (lines 236-470)
- `SimpleTokenStream.swift` (lines 240-556)
- `Tokenizer.swift` (lines 99-560)

### 2. **Number Parsing Logic Duplication**

**Problem**: Complex number parsing is implemented multiple times:
- `parseNumber()` - basic decimal parsing
- `parseNumberWithRecovery()` - enhanced error handling
- `parseInvalidNumber()` - malformed number handling  
- `parseNumberWithLenientRecovery()` - lenient error recovery
- `parseHexadecimalNumber()` - hex number parsing
- `parseBinaryNumber()` - binary number parsing
- `parseOctalNumber()` - octal number parsing

**Files Affected**:
- `EnhancedParsingTokenizer.swift` (lines 291-420)
- `ParsingTokenizer.swift` (lines 234-350)
- `FastParsingTokenizer.swift` (lines 236-290)

### 3. **Error Handling Duplication**

**Problem**: Similar error conversion and handling logic:
- ParseError conversion from different error types
- Position tracking and line/column calculation
- Error context creation

**Files Affected**:
- `ParseError.swift` (lines 60-155)
- `EnhancedParsingTokenizer.swift` (lines 486-520)

### 4. **Expression Parsing Boundary Detection**

**Problem**: Expression boundary detection logic duplicated:
- `isStatementTerminator()` - Statement parsing boundaries
- `isStartOfNewStatement()` - New statement detection
- Parentheses/bracket balancing logic

**Files Affected**:
- `StatementParser.swift` (lines 656-790)
- `Parser.swift` (similar logic in parseExpression methods)

## 🔧 Refactoring Strategy

### Phase 1: Extract Shared Tokenizer Parsing Logic

1. **Create `TokenizerParsingStrategies.swift`**:
   ```swift
   public enum TokenizerParsingStrategies {
       // Consolidated parsing methods used by all tokenizers
       static func parseKeyword(from input: String, at index: inout String.Index) -> TokenData?
       static func parseOperator(from input: String, at index: inout String.Index) -> TokenData?
       static func parseDelimiter(from input: String, at index: inout String.Index) -> TokenData?
       static func parseBasicNumber(from input: String, at index: inout String.Index) -> TokenData?
       static func parseIdentifier(from input: String, at index: inout String.Index) -> TokenData?
   }
   ```

2. **Create `NumberParsingStrategies.swift`**:
   ```swift
   public enum NumberParsingStrategies {
       static func parseDecimalNumber(from input: String, at index: inout String.Index, start: String.Index) -> TokenData?
       static func parseHexadecimalNumber(from input: String, at index: inout String.Index, start: String.Index) -> TokenData?
       static func parseBinaryNumber(from input: String, at index: inout String.Index, start: String.Index) -> TokenData?
       static func parseOctalNumber(from input: String, at index: inout String.Index, start: String.Index) -> TokenData?
       static func parseNumberWithRecovery(from input: String, at index: inout String.Index, errorCollector: ErrorCollector) -> TokenData?
   }
   ```

### Phase 2: Consolidate Error Handling

1. **Extend `ParseError.swift`**:
   ```swift
   extension ParseError {
       // Unified conversion methods for all error types
       static func from(_ error: TokenizerError, at position: SourcePosition) -> ParseError
       static func from(_ error: EnhancedTokenizerError) -> ParseError
       static func from(_ error: ParsingError, at position: SourcePosition) -> ParseError
   }
   ```

### Phase 3: Extract Statement Boundary Detection

1. **Create `ParsingBoundaryDetection.swift`**:
   ```swift
   public enum ParsingBoundaryDetection {
       static func isStatementTerminator(_ tokenType: TokenType) -> Bool
       static func isStartOfNewStatement(_ tokens: [Token], at index: Int) -> Bool
       static func findExpressionBoundary(in tokens: [Token], startingAt: Int) -> Int
       static func isValidBalancedExpression(_ tokens: ArraySlice<Token>) -> Bool
   }
   ```

### Phase 4: Update All Tokenizer Implementations

1. **Refactor each tokenizer to use shared strategies**:
   - Replace duplicated methods with calls to shared strategies
   - Maintain unique error handling and performance optimizations
   - Remove redundant parsing logic

2. **Maintain backward compatibility**:
   - Keep existing public APIs unchanged
   - Ensure all tests continue to pass
   - Preserve performance characteristics

## 📊 Expected Benefits

### Code Reduction
- **Estimated LOC reduction**: ~2,000 lines (from ~8,000 to ~6,000)
- **Duplication elimination**: 70%+ reduction in parsing method duplication

### Maintainability  
- Single source of truth for parsing logic
- Easier bug fixes and feature additions
- Consistent behavior across all tokenizers

### Testing
- Centralized testing of core parsing logic
- Reduced test duplication
- Higher confidence in edge case handling

### Performance
- Shared optimizations benefit all tokenizers
- Reduced binary size due to less code duplication
- Better compiler optimization opportunities

## 🚀 Implementation Order

1. **Week 1**: Create shared strategy enums and basic parsing methods
2. **Week 2**: Implement number parsing consolidation
3. **Week 3**: Refactor error handling and boundary detection  
4. **Week 4**: Update all tokenizer implementations
5. **Week 5**: Testing, optimization, and documentation

## ✅ Success Criteria

- [ ] All existing tests pass without modification
- [ ] 325+ tests continue to pass
- [ ] SwiftLint warnings reduced by eliminating duplication
- [ ] Performance benchmarks show no regression
- [ ] Code review shows clear separation of concerns
- [ ] Documentation updated to reflect new architecture

## 🔍 Files to Modify

### New Files to Create:
- `Sources/FeLangCore/Tokenizer/TokenizerParsingStrategies.swift`
- `Sources/FeLangCore/Tokenizer/NumberParsingStrategies.swift`
- `Sources/FeLangCore/Parser/ParsingBoundaryDetection.swift`

### Files to Refactor:
- `Sources/FeLangCore/Tokenizer/EnhancedParsingTokenizer.swift`
- `Sources/FeLangCore/Tokenizer/ParsingTokenizer.swift`
- `Sources/FeLangCore/Tokenizer/FastParsingTokenizer.swift`
- `Sources/FeLangCore/Tokenizer/SimpleTokenStream.swift`
- `Sources/FeLangCore/Tokenizer/Tokenizer.swift`
- `Sources/FeLangCore/Parser/StatementParser.swift`
- `Sources/FeLangCore/Parser/Parser.swift`
- `Sources/FeLangCore/Parser/ParseError.swift`

## 📝 Notes

- Maintain existing error handling behavior for backward compatibility
- Keep performance optimizations in FastParsingTokenizer
- Preserve unique features of each tokenizer (streaming, parallel processing, etc.)
- Document the new shared architecture clearly 