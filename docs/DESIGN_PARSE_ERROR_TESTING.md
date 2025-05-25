# Design Document: ParseError Tests with Golden File Comparison

**Issue:** [#27 ParseError Tests – golden file comparison](https://github.com/fumiya-kume/FeLangKit/issues/27)  
**Author:** GitHub Copilot (Design Analysis)  
**Date:** 2024-12-19  
**Status:** Draft

## 1. Problem Statement

FeLangKit currently lacks systematic testing for ParseError scenarios, which represents a significant gap in test coverage for error handling in the language parser. While the project maintains 132 passing tests covering tokenization, expression parsing, statement parsing, AST immutability, thread safety, and serialization, there is no standardized approach to verify that parse errors are correctly identified, formatted, and reported.

### Core Issues:
- **Inconsistent Error Testing**: Parse errors are tested ad-hoc without systematic coverage
- **No Golden File Validation**: Error messages and formatting lack regression protection
- **Limited Error Scenario Coverage**: Complex error cases may go untested
- **Manual Error Verification**: No automated comparison of expected vs actual error outputs

## 2. Goals / Non-Goals

### Goals:
- **Comprehensive Error Coverage**: Test all major categories of parse errors
- **Golden File Comparison**: Implement automated comparison of error outputs against expected results
- **Regression Protection**: Ensure error message changes are intentional and tracked
- **Developer Experience**: Provide clear, actionable error messages for users
- **Maintainable Test Suite**: Create scalable test infrastructure for error scenarios

### Non-Goals:
- **Performance Optimization**: Error path performance is not the primary focus
- **Error Recovery**: Advanced error recovery mechanisms are out of scope
- **Internationalization**: Localized error messages are not included
- **IDE Integration**: Editor-specific error highlighting is not covered

## 3. Current State Analysis

### Existing Test Infrastructure:
```
Tests/FeLangCoreTests/
├── Expression/
│   ├── ExpressionParserTests.swift (~20 tests)
│   └── ASTImmutabilityAuditTests.swift
├── Parser/
│   └── StatementParserTests.swift (~24 tests)
├── Tokenizer/
│   ├── TokenizerTests.swift (~95 tests)
│   └── [Additional tokenizer test files]
├── ThreadSafety/
│   └── ThreadSafetyTestSuite.swift
└── Utility/
    └── [~5 utility tests]
```

### Current Testing Patterns:
- **Swift Testing Framework**: Modern `@Test` annotations and `#expect` assertions
- **Parameterized Tests**: Using `@Test(arguments:)` for comprehensive input coverage
- **Property-Based Testing**: AST immutability verification
- **Concurrent Testing**: Thread safety validation
- **Serialization Testing**: Round-trip verification

### Gap Analysis:
1. **No dedicated ParseError test files**
2. **No golden file infrastructure**
3. **Limited error message validation**
4. **No systematic error categorization**
5. **Missing error position/location verification**

## 4. Option Exploration

### Option A: Inline Error Testing
**Approach**: Add error tests directly to existing parser test files  
**Pros**: Minimal infrastructure changes, close to existing code  
**Cons**: Scattered error tests, difficult to maintain, no golden file support  

### Option B: Dedicated Error Test Suite with Manual Verification
**Approach**: Create dedicated error test files with hardcoded expected messages  
**Pros**: Centralized error testing, easier to maintain  
**Cons**: Brittle to message changes, no visual diff support  

### Option C: Golden File-Based Error Testing (Recommended)
**Approach**: Implement comprehensive golden file system for error validation  
**Pros**: Visual diffs, easy updates, comprehensive coverage, industry standard  
**Cons**: More complex initial setup, requires file management  

### Option D: Snapshot Testing Framework
**Approach**: Use external snapshot testing library  
**Pros**: Proven solution, rich features  
**Cons**: External dependency, may not fit Swift Testing patterns  

## 5. Chosen Solution: Golden File-Based Error Testing

### Architecture Overview:
```
Tests/FeLangCoreTests/ParseError/
├── ParseErrorGoldenTests.swift       # Main test file
├── ParseErrorTestUtils.swift         # Utilities and helpers
├── GoldenFiles/
│   ├── syntax-errors.golden         # Syntax error test cases
│   ├── semantic-errors.golden       # Semantic error test cases
│   ├── tokenizer-errors.golden      # Tokenizer error test cases
│   └── complex-errors.golden        # Multi-error scenarios
└── TestCases/
    ├── syntax-errors/               # Input files for syntax errors
    ├── semantic-errors/             # Input files for semantic errors
    ├── tokenizer-errors/            # Input files for tokenizer errors
    └── complex-errors/              # Input files for complex scenarios
```

### Key Components:

1. **Golden File Format**:
```
=== Test Case: invalid_syntax_001 ===
Input: let x = 
Expected Error:
ParseError: Unexpected end of input
  at line 1, column 8
  Expected: expression after '='

=== Test Case: invalid_syntax_002 ===
Input: let = value
Expected Error:
ParseError: Expected identifier
  at line 1, column 5
  Expected: variable name after 'let'
```

2. **Test Infrastructure**:
   - Golden file reader/writer utilities
   - Error message formatter
   - Diff generation for mismatches
   - Test case discovery and execution

3. **Error Categories**:
   - **Syntax Errors**: Invalid language constructs
   - **Semantic Errors**: Type mismatches, undefined variables
   - **Tokenizer Errors**: Invalid characters, unterminated strings
   - **Complex Scenarios**: Multiple errors, nested structures

## 6. Implementation Plan

### Phase 1: Foundation (Week 1)
- [ ] Create `ParseErrorTestUtils.swift` with golden file utilities
- [ ] Implement `GoldenFileManager` class for file operations
- [ ] Create `ErrorFormatter` for consistent error message formatting
- [ ] Set up basic directory structure

### Phase 2: Core Testing (Week 2)
- [ ] Implement `ParseErrorGoldenTests.swift` main test class
- [ ] Create initial golden files for basic error scenarios
- [ ] Add 20-30 syntax error test cases
- [ ] Implement test discovery and execution logic

### Phase 3: Comprehensive Coverage (Week 3)
- [ ] Add semantic error test cases
- [ ] Add tokenizer error test cases
- [ ] Add complex multi-error scenarios
- [ ] Implement golden file update workflow

### Phase 4: Integration (Week 4)
- [ ] Integrate with existing CI/CD pipeline
- [ ] Add documentation and usage guidelines
- [ ] Create golden file update scripts
- [ ] Performance optimization if needed

### Implementation Details:

```swift
// ParseErrorTestUtils.swift
struct GoldenFileManager {
    static func loadGoldenFile(_ name: String) throws -> [GoldenTestCase]
    static func saveGoldenFile(_ name: String, cases: [GoldenTestCase]) throws
    static func compareWithGolden(_ actual: String, _ expected: String) -> DiffResult
}

struct GoldenTestCase {
    let name: String
    let input: String
    let expectedError: String
}

// ParseErrorGoldenTests.swift
@Test("Syntax Error Golden File Tests")
func testSyntaxErrorsAgainstGoldenFile() async throws {
    let goldenCases = try GoldenFileManager.loadGoldenFile("syntax-errors")
    
    for testCase in goldenCases {
        let parser = StatementParser(input: testCase.input)
        let result = parser.parse()
        
        switch result {
        case .success:
            Issue.record("Expected parse error but parsing succeeded for: \(testCase.name)")
        case .failure(let error):
            let formattedError = ErrorFormatter.format(error)
            #expect(formattedError == testCase.expectedError, 
                   "Error mismatch for \(testCase.name)")
        }
    }
}
```

## 7. Testing Strategy

### Test Categories:

1. **Unit Tests**: Individual golden file utility functions
2. **Integration Tests**: End-to-end error parsing and comparison
3. **Regression Tests**: Verify no unintended error message changes
4. **Performance Tests**: Ensure golden file operations don't impact CI speed

### Golden File Management:

1. **Update Workflow**:
   - Manual review required for golden file changes
   - Automated detection of golden file drift
   - Clear diff presentation in CI failures

2. **Validation Process**:
   - Automated golden file format validation
   - Error message quality checks
   - Coverage analysis for error scenarios

### CI Integration:

```yaml
# .github/workflows/test.yml (addition)
- name: Run ParseError Golden Tests
  run: swift test --filter ParseErrorGoldenTests
  
- name: Check Golden File Drift
  run: |
    if git diff --exit-code Tests/FeLangCoreTests/ParseError/GoldenFiles/; then
      echo "Golden files are up to date"
    else
      echo "Golden files have changed - manual review required"
      exit 1
    fi
```

## 8. Performance, Security, and Observability

### Performance Considerations:
- **Golden File Caching**: Cache parsed golden files during test runs
- **Parallel Execution**: Run error tests in parallel where possible
- **Incremental Testing**: Only test changed error scenarios in development

### Security Considerations:
- **No Security Impact**: Error testing doesn't introduce security risks
- **Safe File Operations**: Golden files are read-only during normal operation
- **Input Validation**: Ensure test inputs don't cause unexpected behavior

### Observability:
- **Test Metrics**: Track error test coverage and execution time
- **CI Reporting**: Clear reporting of golden file mismatches
- **Documentation**: Comprehensive error testing documentation

### Monitoring:
```swift
// TestMetrics.swift
struct ParseErrorTestMetrics {
    static func trackGoldenFileTests(
        totalCases: Int,
        passedCases: Int,
        executionTime: TimeInterval
    ) {
        // Track test metrics for analysis
    }
}
```

## 9. Open Questions & Risks

### Open Questions:

1. **Error Message Stability**: How frequently do error messages change during development?
2. **Golden File Size**: What's the acceptable size limit for golden files?
3. **Error Localization**: Should we prepare for future localized error messages?
4. **IDE Integration**: Should golden file updates be integrated with development tools?

### Risks and Mitigations:

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Golden file drift causing CI failures | Medium | High | Automated golden file update tools |
| Large golden files impacting repository size | Low | Medium | Golden file compression and cleanup |
| Developer resistance to golden file updates | Medium | Low | Clear documentation and tooling |
| Error message inconsistency | High | Medium | Standardized error formatting guidelines |

### Risk Mitigation Strategies:

1. **Automated Tooling**: Create scripts for easy golden file updates
2. **Developer Education**: Provide clear documentation on golden file workflow
3. **Gradual Rollout**: Implement error testing incrementally
4. **Fallback Strategy**: Maintain existing error testing as backup

## Next Steps

1. **Get Stakeholder Approval**: Review and approve this design document
2. **Create Implementation Timeline**: Detailed sprint planning for 4-week implementation
3. **Set Up Development Environment**: Prepare golden file infrastructure
4. **Begin Phase 1 Implementation**: Start with foundation utilities

---

**Review Required**: This design document should be reviewed by the FeLangKit maintainers before implementation begins.
