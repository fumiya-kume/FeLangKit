# Design Document: Enhanced Error Handling with Recovery Mechanisms

**Issue:** [#16 Enhanced Error Handling with Recovery Mechanisms](https://github.com/fumiya-kume/FeLangKit/issues/16)  
**Author:** GitHub Copilot (Design Analysis)  
**Date:** 2025-01-07  
**Status:** Draft

## 1. Problem Statement

The current FeLangKit tokenizer provides basic error detection but lacks robust error handling and recovery mechanisms essential for practical language tools. Users and developers need the ability to collect multiple errors, continue processing after encountering issues, and receive detailed diagnostic information to improve code quality and development experience.

### Core Issues:
- **Single Error Termination**: Tokenizer stops at the first error encountered, preventing discovery of additional issues
- **Limited Error Context**: Basic error types without detailed positioning, suggestions, or severity levels
- **No Recovery Mechanisms**: Cannot continue tokenization after encountering invalid input
- **Insufficient Diagnostic Information**: Lack of actionable feedback for error resolution
- **Inconsistent Error Handling**: Different error handling patterns across Tokenizer and ParsingTokenizer implementations

### Current Limitations:
```swift
// Current behavior - stops at first error
let source = "let 変数@ = 10; let another = \"unterminated string"
// Only reports: unexpectedCharacter('@') - second error never discovered

// Desired behavior - collects all errors
// Should report both: unexpectedCharacter('@') AND unterminatedString
```

## 2. Goals / Non-Goals

### Goals:
- **Multi-Error Collection**: Gather and report all tokenization errors in a single pass
- **Intelligent Recovery**: Implement strategies to continue tokenization after errors
- **Enhanced Diagnostics**: Provide detailed error information with position, context, and suggestions
- **Consistent Implementation**: Unified error handling across both tokenizer implementations
- **Performance Preservation**: Maintain tokenization speed while adding error resilience
- **Developer Experience**: Improve error messages and diagnostic capabilities

### Non-Goals:
- **Parse-Level Error Recovery**: Focus on tokenizer-level errors only (parser errors are separate)
- **Automatic Code Fixing**: Error recovery != automatic correction of source code
- **Interactive Error Correction**: Real-time editing assistance is out of scope
- **Localization**: Multi-language error messages not included in initial implementation

## 3. Current State Analysis

### Existing Error Infrastructure:

#### TokenizerError Enum (4 error types):
```swift
public enum TokenizerError: Error, Equatable {
    case unexpectedCharacter(Character, position: Int)
    case unterminatedString(position: Int)
    case unterminatedComment(position: Int)
    case invalidEscapeSequence(Character, position: Int)
}
```

#### Current Error Handling Pattern:
- **Single Error Throw**: Both Tokenizer.swift and ParsingTokenizer.swift throw immediately on error
- **Basic Position Information**: Only character index provided
- **No Error Classification**: All errors treated with equal severity
- **No Recovery Logic**: Processing terminates on any error

#### Test Coverage:
- TokenizerConsistencyTests.swift verifies both tokenizers throw same error types
- Basic error scenarios covered but no comprehensive error recovery testing

### Architecture Analysis:
```
Current Architecture:
Input Source → Tokenizer → [Error] → Stop Processing
                    ↓
               Single Error Thrown

Enhanced Architecture:
Input Source → Tokenizer → Error Collector → TokenizerResult
                    ↓           ↓
               Recovery Logic   Multi-Error Report
```

## 4. Proposed Solution

### 4.1 Enhanced Error Model

#### New Error Types and Severity Levels:
```swift
public enum ErrorSeverity: Int, Comparable {
    case warning = 0    // Potential issues, processing continues
    case error = 1      // Clear errors, but recoverable
    case fatal = 2      // Critical errors, may stop processing
    
    public static func < (lhs: ErrorSeverity, rhs: ErrorSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct SourceRange {
    let start: SourcePosition
    let end: SourcePosition
    
    public struct SourcePosition {
        let index: Int      // Character index
        let line: Int       // Line number (1-based)
        let column: Int     // Column number (1-based)
    }
}

public struct EnhancedTokenizerError {
    let type: ErrorType
    let range: SourceRange
    let message: String
    let suggestions: [String]
    let severity: ErrorSeverity
    let context: String?        // Surrounding code snippet
}

public enum ErrorType {
    // Character-level errors
    case unexpectedCharacter(Character)
    case invalidEscapeSequence(Character)
    
    // String-related errors
    case unterminatedString
    case invalidStringContent
    
    // Comment-related errors
    case unterminatedComment
    
    // Number-related errors
    case invalidNumberFormat
    case numberOverflow
    
    // Unicode-related errors
    case invalidUnicodeSequence
    case unsupportedCharacterEncoding
    
    // Recovery-related warnings
    case recoveredFromError(originalError: ErrorType)
    case assumedTokenBoundary
}
```

### 4.2 Result-Based Architecture

#### TokenizerResult Structure:
```swift
public struct TokenizerResult {
    let tokens: [Token]
    let errors: [EnhancedTokenizerError]
    let warnings: [EnhancedTokenizerError]
    let isSuccessful: Bool
    
    public var allDiagnostics: [EnhancedTokenizerError] {
        (errors + warnings).sorted { $0.range.start.index < $1.range.start.index }
    }
}
```

### 4.3 Recovery Strategies

#### 1. Character-Level Recovery:
```swift
// Strategy: Skip invalid characters and continue
let source = "let 変数@ = 10"
// Recovery: Skip '@', continue from '='
// Result: [let, identifier("変数"), =, number(10)] + error report
```

#### 2. Token Boundary Recovery:
```swift
// Strategy: Synchronize at whitespace or known delimiters
let source = "let var123@#$ = 42"
// Recovery: Skip invalid sequence "@#$", sync at '='
// Result: [let, identifier("var123"), =, number(42)] + error report
```

#### 3. String Recovery:
```swift
// Strategy: Assume string termination at line end or EOF
let source = "let text = \"unterminated string\nlet next = 42"
// Recovery: Close string at line end, continue parsing
// Result: [let, identifier("text"), =, string("unterminated string"), let, identifier("next"), =, number(42)]
```

#### 4. Comment Recovery:
```swift
// Strategy: Close comment at EOF
let source = "/* unclosed comment\nlet x = 5"
// Recovery: Assume comment closes at EOF
// Result: [let, identifier("x"), =, number(5)] + warning
```

### 4.4 Enhanced Tokenizer Interface

#### Updated Tokenizer Protocol:
```swift
public protocol TokenizerProtocol {
    func tokenize(_ source: String) throws -> [Token]                    // Legacy method
    func tokenizeWithDiagnostics(_ source: String) -> TokenizerResult    // New method
}

extension TokenizerProtocol {
    // Backward compatibility
    public func tokenize(_ source: String) throws -> [Token] {
        let result = tokenizeWithDiagnostics(source)
        if let firstFatalError = result.errors.first(where: { $0.severity == .fatal }) {
            throw firstFatalError
        }
        return result.tokens
    }
}
```

## 5. Technical Implementation

### 5.1 Core Components

#### Error Collector:
```swift
internal class ErrorCollector {
    private var errors: [EnhancedTokenizerError] = []
    private var warnings: [EnhancedTokenizerError] = []
    
    func reportError(_ type: ErrorType, at range: SourceRange, 
                    message: String, suggestions: [String] = [],
                    severity: ErrorSeverity = .error, context: String? = nil) {
        let error = EnhancedTokenizerError(
            type: type, range: range, message: message,
            suggestions: suggestions, severity: severity, context: context
        )
        
        switch severity {
        case .warning:
            warnings.append(error)
        case .error, .fatal:
            errors.append(error)
        }
    }
    
    func createResult(tokens: [Token]) -> TokenizerResult {
        let hasErrors = !errors.isEmpty
        let hasFatalErrors = errors.contains { $0.severity == .fatal }
        
        return TokenizerResult(
            tokens: tokens,
            errors: errors,
            warnings: warnings,
            isSuccessful: !hasErrors || !hasFatalErrors
        )
    }
}
```

#### Position Tracker:
```swift
internal class PositionTracker {
    private var currentIndex = 0
    private var currentLine = 1
    private var currentColumn = 1
    private var lineStarts: [Int] = [0]
    
    func advance(character: Character) {
        currentIndex += 1
        if character.isNewline {
            currentLine += 1
            currentColumn = 1
            lineStarts.append(currentIndex)
        } else {
            currentColumn += 1
        }
    }
    
    func currentPosition() -> SourcePosition {
        SourcePosition(index: currentIndex, line: currentLine, column: currentColumn)
    }
    
    func createRange(from start: SourcePosition, to end: SourcePosition) -> SourceRange {
        SourceRange(start: start, end: end)
    }
}
```

### 5.2 Recovery Implementation

#### Recovery State Machine:
```swift
internal enum RecoveryState {
    case normal                    // Normal tokenization
    case recovering(from: ErrorType)  // Attempting recovery
    case synchronized             // Successfully recovered
}

internal class RecoveryManager {
    private var state: RecoveryState = .normal
    private let errorCollector: ErrorCollector
    
    func attemptRecovery(from error: ErrorType, at position: SourcePosition, 
                        in source: String, currentIndex: Int) -> RecoveryAction {
        switch error {
        case .unexpectedCharacter(let char):
            return skipCharacterRecovery(char: char, at: position)
        case .unterminatedString:
            return stringRecovery(at: position, in: source, from: currentIndex)
        case .unterminatedComment:
            return commentRecovery(at: position, in: source, from: currentIndex)
        case .invalidEscapeSequence:
            return escapeSequenceRecovery(at: position)
        }
    }
}

internal enum RecoveryAction {
    case skip(count: Int)          // Skip n characters
    case insertToken(Token)        // Insert synthetic token
    case synchronizeAt(Int)        // Jump to specific position
    case abort                     // Cannot recover
}
```

### 5.3 Implementation Phases

#### Phase 1: Enhanced Error Model (Week 1-2)
- Implement `EnhancedTokenizerError` structure
- Create `SourceRange` and `SourcePosition` types
- Add `ErrorSeverity` enumeration
- Update `ErrorType` enumeration with new cases

#### Phase 2: Result-Based Architecture (Week 3-4)
- Implement `TokenizerResult` structure
- Create `ErrorCollector` class
- Add `PositionTracker` for accurate source positioning
- Update tokenizer interfaces for backward compatibility

#### Phase 3: Basic Recovery Mechanisms (Week 5-8)
- Implement character-level recovery strategies
- Add token boundary synchronization
- Create string and comment recovery logic
- Develop `RecoveryManager` component

#### Phase 4: Integration and Testing (Week 9-12)
- Integrate enhanced error handling into both tokenizers
- Ensure consistency between Tokenizer and ParsingTokenizer
- Comprehensive testing of recovery scenarios
- Performance validation and optimization

#### Phase 5: Documentation and Refinement (Week 13-14)
- Update API documentation
- Create usage examples and best practices guide
- Performance benchmarking
- Final refinements based on testing feedback

## 6. Error Recovery Strategies

### 6.1 Character-Level Recovery

#### Invalid Character Handling:
```swift
// Strategy: Skip invalid characters, report as warning
func recoverFromInvalidCharacter(_ char: Character, at position: SourcePosition) -> RecoveryAction {
    if char.isWhitespace || char.isSymbol {
        // Skip single character and continue
        return .skip(count: 1)
    } else {
        // Skip until next valid token boundary
        return .synchronizeAt(findNextTokenBoundary())
    }
}
```

### 6.2 String Recovery

#### Unterminated String Handling:
```swift
// Strategy: Close string at line end or EOF
func recoverFromUnterminatedString(at position: SourcePosition, 
                                  in source: String, from index: Int) -> RecoveryAction {
    // Look for logical string termination
    if let lineEnd = source.firstIndex(of: "\n", startingAt: index) {
        // Close string at line end
        return .insertToken(.string(source[index..<lineEnd]))
    } else {
        // Close string at EOF
        return .insertToken(.string(source[index...]))
    }
}
```

### 6.3 Synchronization Points

#### Token Boundary Detection:
```swift
func findNextTokenBoundary(in source: String, from index: Int) -> Int {
    let synchronizationPoints: Set<Character> = [" ", "\t", "\n", ";", "{", "}", "(", ")", ","]
    
    for i in index..<source.count {
        let char = source[source.index(source.startIndex, offsetBy: i)]
        if synchronizationPoints.contains(char) {
            return i
        }
    }
    return source.count
}
```

## 7. Testing Strategy

### 7.1 Error Collection Testing

#### Multi-Error Scenarios:
```swift
func testMultipleErrorCollection() {
    let source = """
    let var@ = "unterminated string
    let another# = 42
    /* unclosed comment
    let final = true
    """
    
    let result = tokenizer.tokenizeWithDiagnostics(source)
    
    XCTAssertEqual(result.errors.count, 3)
    XCTAssertTrue(result.errors.contains { $0.type == .unexpectedCharacter("@") })
    XCTAssertTrue(result.errors.contains { $0.type == .unterminatedString })
    XCTAssertTrue(result.errors.contains { $0.type == .unexpectedCharacter("#") })
}
```

### 7.2 Recovery Validation Testing

#### Recovery Accuracy:
```swift
func testStringRecovery() {
    let source = "let text = \"unclosed\nlet x = 42"
    let result = tokenizer.tokenizeWithDiagnostics(source)
    
    // Should produce tokens despite error
    XCTAssertGreaterThan(result.tokens.count, 0)
    XCTAssertEqual(result.errors.count, 1)
    XCTAssertEqual(result.errors.first?.type, .unterminatedString)
    
    // Should continue parsing after recovery
    XCTAssertTrue(result.tokens.contains { token in
        if case .identifier(let name) = token { return name == "x" }
        return false
    })
}
```

### 7.3 Performance Testing

#### Error Handling Performance:
```swift
func testErrorHandlingPerformance() {
    let sourceWithErrors = String(repeating: "let var@ = 1; ", count: 1000)
    
    measure {
        _ = tokenizer.tokenizeWithDiagnostics(sourceWithErrors)
    }
    
    // Should not be significantly slower than error-free tokenization
}
```

### 7.4 Consistency Testing

#### Cross-Tokenizer Consistency:
```swift
func testTokenizerConsistencyWithErrors() {
    let testCases = [
        "let var@ = 42",
        "\"unterminated string",
        "/* unclosed comment",
        "let \\invalid = true"
    ]
    
    for testCase in testCases {
        let result1 = tokenizer.tokenizeWithDiagnostics(testCase)
        let result2 = parsingTokenizer.tokenizeWithDiagnostics(testCase)
        
        XCTAssertEqual(result1.errors.count, result2.errors.count)
        XCTAssertEqual(result1.tokens.count, result2.tokens.count)
    }
}
```

## 8. Performance Considerations

### 8.1 Memory Efficiency

#### Error Storage Optimization:
- Use value types for error structures to minimize memory overhead
- Implement lazy evaluation for context extraction
- Consider error deduplication for repeated issues

#### Memory Profile:
```swift
// Efficient error storage
struct CompactError {
    let type: UInt8          // Enum raw value
    let startIndex: UInt32   // Source position
    let endIndex: UInt32     // Error range
    let severity: UInt8      // Severity level
}

// Full error information generated on demand
extension CompactError {
    func expanded(in source: String) -> EnhancedTokenizerError {
        // Generate detailed error information when needed
    }
}
```

### 8.2 Processing Speed

#### Fast Path Optimization:
```swift
// Optimize common case (no errors)
func tokenizeWithDiagnostics(_ source: String) -> TokenizerResult {
    if !source.containsLikelyErrors() {
        // Fast path: normal tokenization
        do {
            let tokens = try tokenize(source)
            return TokenizerResult(tokens: tokens, errors: [], warnings: [], isSuccessful: true)
        } catch {
            // Fallback to enhanced error handling
        }
    }
    
    // Slow path: comprehensive error handling
    return tokenizeWithRecovery(source)
}
```

### 8.3 Benchmarking Targets

#### Performance Goals:
- **Error-free code**: <5% performance regression
- **Code with errors**: 2-3x slower than current implementation (acceptable for error cases)
- **Memory overhead**: <10% increase for normal operation
- **Error collection**: O(n) complexity where n = source length

## 9. Implementation Timeline

### Phase 1: Foundation (Weeks 1-2)
- [ ] Implement enhanced error model structures
- [ ] Create SourceRange and SourcePosition types
- [ ] Add ErrorSeverity enumeration
- [ ] Update TokenizerError to ErrorType

### Phase 2: Architecture (Weeks 3-4)
- [ ] Implement TokenizerResult structure
- [ ] Create ErrorCollector class
- [ ] Add PositionTracker component
- [ ] Update tokenizer interfaces

### Phase 3: Recovery Logic (Weeks 5-8)
- [ ] Implement RecoveryManager
- [ ] Add character-level recovery strategies
- [ ] Create string and comment recovery logic
- [ ] Implement token synchronization

### Phase 4: Integration (Weeks 9-10)
- [ ] Integrate enhanced error handling into Tokenizer.swift
- [ ] Update ParsingTokenizer.swift with new error handling
- [ ] Ensure cross-tokenizer consistency
- [ ] Backward compatibility testing

### Phase 5: Testing & Validation (Weeks 11-12)
- [ ] Comprehensive error scenario testing
- [ ] Recovery accuracy validation
- [ ] Performance benchmarking
- [ ] Cross-tokenizer consistency tests

### Phase 6: Documentation (Weeks 13-14)
- [ ] API documentation updates
- [ ] Usage examples and guides
- [ ] Migration guide from old API
- [ ] Performance analysis report

### Risk Mitigation:
- **Backward Compatibility**: Maintain existing tokenize() method for legacy code
- **Performance Regression**: Implement fast path for error-free code
- **Complexity Management**: Incremental implementation with thorough testing at each phase
- **Testing Coverage**: Golden file tests for error scenarios to prevent regressions

## Success Metrics

### Functional Metrics:
- [ ] Collect and report multiple errors in single tokenization pass
- [ ] Successfully recover from at least 80% of common error scenarios
- [ ] Provide actionable error messages with position information
- [ ] Maintain consistency between both tokenizer implementations

### Performance Metrics:
- [ ] <5% performance regression for error-free code
- [ ] <10% memory overhead increase
- [ ] Error handling complexity remains O(n) where n = source length

### Quality Metrics:
- [ ] 100% test coverage for new error handling components
- [ ] All existing tests continue to pass
- [ ] Documentation covers all new APIs and recovery strategies

This design provides a comprehensive foundation for implementing robust error handling with recovery mechanisms in FeLangKit's tokenizer, addressing all requirements specified in issue #16 while maintaining performance and backward compatibility.
