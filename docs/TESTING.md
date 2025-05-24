# FeLangCore Testing

This document describes the testing strategy, organization, and guidelines for FeLangCore.

## 🧪 Test Organization

The test suite is organized to **mirror the source structure**, providing clear alignment between implementation and validation.

### 📁 Test Directory Structure

```
Tests/FeLangCoreTests/
├── FeLangCoreTests.swift         # Main test suite file
├── Tokenizer/                    # 📝 Tokenizer Tests (4 files)
│   ├── TokenizerTests.swift     # Comprehensive tokenizer tests
│   ├── ParsingTokenizerTests.swift # Parsing-focused tokenizer tests
│   ├── TokenizerConsistencyTests.swift # Cross-tokenizer consistency tests
│   └── LeadingDotTests.swift    # Decimal parsing edge case tests
├── Expression/                   # 🔢 Expression Tests (1 file)
│   └── ExpressionParserTests.swift # Expression parsing tests
├── Parser/                       # 🏗️ Parser Tests (1 file)
│   └── StatementParserTests.swift # Statement parsing tests
└── Utilities/                    # 🛠️ Utility Tests (1 file)
    └── StringEscapeUtilitiesTests.swift # String escape utility tests
```

## 📊 Test Coverage Overview

| **Test Module** | **Source Module** | **Test Files** | **Test Count** | **Coverage Focus** |
|-----------------|-------------------|----------------|----------------|-------------------|
| **Tokenizer/** | **Tokenizer/** | 4 files | ~95 tests | Tokenization, edge cases, consistency |
| **Expression/** | **Expression/** | 1 file | ~20 tests | Expression parsing, precedence, AST |
| **Parser/** | **Parser/** | 1 file | ~24 tests | Statement parsing, language constructs |
| **Utilities/** | **Utilities/** | 1 file | ~5 tests | Escape sequence processing |
| **Total** | **4 modules** | **8 files** | **132 tests** | **Complete coverage** |

## 🎯 Test Module Details

### 📝 Tokenizer Tests (4 test files, ~95 tests)

#### **TokenizerTests.swift** - Comprehensive Core Testing
- **Basic Functionality**: Keywords, operators, literals, identifiers
- **Edge Cases**: Unicode characters, whitespace handling, position tracking
- **Error Handling**: Unterminated strings, invalid characters, malformed input
- **Performance**: Large input handling, memory efficiency

#### **ParsingTokenizerTests.swift** - Parsing-Optimized Testing
- **Core Parsing Features**: Streamlined tokenization for parser use
- **Performance Validation**: Optimized token stream generation
- **Integration Testing**: Parser-specific tokenization scenarios

#### **TokenizerConsistencyTests.swift** - Cross-Implementation Validation
- **Consistency Checks**: Ensure both tokenizers produce equivalent results
- **Shared Utilities Testing**: Validate TokenizerUtilities functionality
- **Character Classification**: Unicode support, identifier rules
- **Keyword Mapping**: English/Japanese keyword consistency

#### **LeadingDotTests.swift** - Decimal Edge Cases
- **Leading Dot Decimals**: `.5`, `.25`, `.123` parsing
- **Ambiguity Resolution**: Distinguish between `.` operator and decimal
- **Edge Cases**: Boundary conditions, malformed decimals

### 🔢 Expression Tests (1 test file, ~20 tests)

#### **ExpressionParserTests.swift** - Expression Parsing Validation
- **Operator Precedence**: Arithmetic, comparison, logical operators
- **Associativity**: Left/right associative operations
- **Complex Expressions**: Nested parentheses, function calls
- **Postfix Operations**: Array access, field access, method calls
- **Error Handling**: Malformed expressions, unexpected tokens
- **Security**: Nesting depth limits, large expression handling

### 🏗️ Parser Tests (1 test file, ~24 tests)

#### **StatementParserTests.swift** - Statement Parsing Validation
- **Basic Statements**: Variable assignments, expression statements
- **Control Flow**: If/else, while loops, for loops
- **Declarations**: Function/procedure declarations with parameters
- **Advanced Features**: Nested structures, complex assignments
- **Security**: Nesting depth limits, input validation
- **Integration**: Proper delegation to ExpressionParser

### 🛠️ Utilities Tests (1 test file, ~5 tests)

#### **StringEscapeUtilitiesTests.swift** - Utility Function Validation
- **Escape Processing**: Standard escape sequences (`\n`, `\t`, `\"`, etc.)
- **Validation**: Proper error detection for malformed sequences
- **Performance**: Escape counting and optimization support
- **Integration**: Tokenizer integration testing

## 🚀 Testing Guidelines

### ✅ **Test Writing Standards**

#### **Naming Conventions**
```swift
// ✅ Good: Descriptive test names
func testComplexArithmeticExpression() { }
func testNestedControlStructures() { }
func testUnicodeIdentifierSupport() { }

// ❌ Avoid: Generic or unclear names
func testParser() { }
func testTokens() { }
```

#### **Test Structure**
```swift
@Test("Description of what is being tested")
func testSpecificFeature() throws {
    // Arrange: Set up test data
    let input = "test input"
    let parser = ExpressionParser()
    
    // Act: Execute the functionality
    let result = try parser.parse(input)
    
    // Assert: Verify expected behavior
    #expect(result.type == .expectedType)
    #expect(result.value == expectedValue)
}
```

### 🎯 **Test Categories**

#### **Unit Tests** - Individual Component Testing
- Test single functions or methods in isolation
- Mock dependencies when necessary
- Focus on edge cases and error conditions

#### **Integration Tests** - Module Interaction Testing
- Test interaction between modules (e.g., Parser + Expression)
- Validate proper delegation and data flow
- Test complete parsing pipelines

#### **Security Tests** - Protection Mechanism Testing
- Validate nesting depth limits
- Test large input handling
- Verify memory usage bounds

#### **Performance Tests** - Efficiency Validation
- Measure parsing speed for typical inputs
- Validate memory usage patterns
- Test scalability with large inputs

### 🔧 **Running Tests**

#### **All Tests**
```bash
swift test
```

#### **Specific Test Suite**
```bash
swift test --filter "ExpressionParser Tests"
swift test --filter "Tokenizer Tests"
```

#### **Specific Test**
```bash
swift test --filter testComplexArithmeticExpression
```

#### **With Coverage** (requires additional setup)
```bash
swift test --enable-code-coverage
```

## 📈 **Test Quality Metrics**

### ✅ **Current Status**
- **Total Tests**: 132 passing tests
- **Execution Time**: ~0.007 seconds
- **Success Rate**: 100% (132/132)
- **Build Integration**: Tests run on every build

### 🎯 **Quality Targets**
- **Code Coverage**: Aim for >90% line coverage
- **Test Execution Time**: Keep under 1 second for fast feedback
- **Test Reliability**: 0% flaky tests
- **Documentation**: All complex tests should have clear descriptions

## 🚀 **Future Testing Enhancements**

### **Potential Additions**
- **Property-Based Testing**: Use random input generation for edge case discovery
- **Fuzzing Tests**: Automated testing with malformed/random inputs
- **Benchmark Tests**: Performance regression detection
- **Integration Testing**: Full end-to-end language processing scenarios

### **Tooling Improvements**
- **Test Coverage Reports**: Automated coverage tracking
- **Performance Monitoring**: Track test execution time trends
- **Test Result Analytics**: Identify patterns in test failures

## 🤝 **Contributing to Tests**

### **Adding New Tests**
1. **Identify Module**: Determine which test module the new test belongs to
2. **Follow Structure**: Mirror the source module organization
3. **Use Conventions**: Follow naming and structure guidelines
4. **Document Complex Cases**: Add comments for non-obvious test scenarios
5. **Run Full Suite**: Ensure new tests don't break existing functionality

### **Test Review Guidelines**
- Tests should be clear and focused on a single concern
- Edge cases and error conditions should be covered
- Performance impact should be considered
- Integration with existing test suite should be verified

This comprehensive testing strategy ensures FeLangCore maintains high quality and reliability! 🎉 