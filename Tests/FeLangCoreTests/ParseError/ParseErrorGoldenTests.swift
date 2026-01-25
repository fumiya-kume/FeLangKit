import Testing
import Foundation
@testable import FeLangCore

/// Comprehensive ParseError testing using golden file comparison.
/// This test suite ensures that error messages remain consistent across changes
/// and provides regression protection for all parsing error scenarios.
@Suite("ParseError Golden File Tests")
struct ParseErrorGoldenTests {

    // MARK: - Setup

    init() async throws {
        // Ensure golden files structure exists
        try ParseErrorTestUtils.createInitialGoldenFiles()

        // Initialize golden files with sample test cases if they're empty
        try await initializeGoldenFilesIfNeeded()
    }

    // MARK: - Golden File Tests by Category

    @Test("Syntax Error Golden File Tests")
    func testSyntaxErrorsAgainstGoldenFile() async throws {
        try ParseErrorTestUtils.executeGoldenTests(for: .syntaxErrors)
    }

    @Test("Semantic Error Golden File Tests")
    func testSemanticErrorsAgainstGoldenFile() async throws {
        try ParseErrorTestUtils.executeGoldenTests(for: .semanticErrors)
    }

    @Test("Tokenizer Error Golden File Tests")
    func testTokenizerErrorsAgainstGoldenFile() async throws {
        try ParseErrorTestUtils.executeGoldenTests(for: .tokenizerErrors)
    }

    @Test("Complex Error Golden File Tests")
    func testComplexErrorsAgainstGoldenFile() async throws {
        try ParseErrorTestUtils.executeGoldenTests(for: .complexErrors)
    }

    @Test("Edge Cases Golden File Tests")
    func testEdgeCasesAgainstGoldenFile() async throws {
        try ParseErrorTestUtils.executeGoldenTests(for: .edgeCases)
    }

    // MARK: - Comprehensive Error Coverage Tests

    @Test("All Error Categories Coverage")
    func testAllErrorCategoriesCoverage() async throws {
        let allTestCases = try ParseErrorTestUtils.loadAllGoldenFiles()

        // Ensure we have test cases for each category
        for category in ParseErrorTestUtils.ErrorCategory.allCases {
            let testCases = allTestCases[category] ?? []

            // At minimum, we should have some test cases for major categories
            switch category {
            case .syntaxErrors, .tokenizerErrors:
                // These are core categories that should always have tests
                #expect(!testCases.isEmpty, "Category \(category) should have test cases")
            case .semanticErrors, .complexErrors, .edgeCases:
                // These categories may start empty but should be populated over time
                // No strict requirement for now
                break
            }
        }
    }

    @Test("Golden File Format Validation")
    func testGoldenFileFormatValidation() async throws {
        // Test that all golden files can be parsed successfully
        let allTestCases = try ParseErrorTestUtils.loadAllGoldenFiles()

        for (category, testCases) in allTestCases {
            for testCase in testCases {
                // Validate test case structure
                #expect(!testCase.name.isEmpty, "Test case name should not be empty in \(category)")
                #expect(!testCase.input.isEmpty, "Test case input should not be empty in \(category)")
                #expect(!testCase.expectedError.isEmpty, "Test case expected error should not be empty in \(category)")
                #expect(testCase.category == category, "Test case category should match file category")
            }
        }
    }

    // MARK: - Individual Error Type Tests

    private struct StatementErrorTestCase {
        let name: String
        let parsingError: StatementParsingError
        let expectedFormat: String
    }

    private struct ExpressionErrorTestCase {
        let name: String
        let parsingError: ParsingError
        let expectedFormat: String
    }

    @Test("Statement Parser Error Formatting")
    func testStatementParserErrorFormatting() async throws {
        // Test each StatementParsingError case for consistent formatting
        let testCases: [StatementErrorTestCase] = [
            StatementErrorTestCase(
                name: "unexpected_end_of_input",
                parsingError: .unexpectedEndOfInput,
                expectedFormat: "StatementParseError: Unexpected end of input\n  Expected: complete statement"
            ),
            StatementErrorTestCase(
                name: "expected_identifier",
                parsingError: .expectedIdentifier,
                expectedFormat: "StatementParseError: Expected identifier\n  Found: invalid or missing identifier"
            ),
            StatementErrorTestCase(
                name: "expected_data_type",
                parsingError: .expectedDataType,
                expectedFormat: "StatementParseError: Expected data type\n  Expected: integer, real, string, boolean, array, or record type"
            ),
            StatementErrorTestCase(
                name: "input_too_large",
                parsingError: .inputTooLarge,
                expectedFormat: "StatementParseError: Input too large for safe processing\n  Maximum input size exceeded (100,000 tokens)"
            ),
            StatementErrorTestCase(
                name: "nesting_too_deep",
                parsingError: .nestingTooDeep,
                expectedFormat: "StatementParseError: Nesting depth too deep\n  Maximum nesting depth exceeded (100 levels)"
            )
        ]

        for testCase in testCases {
            let formattedError = ErrorFormatter.format(testCase.parsingError)
            #expect(formattedError == testCase.expectedFormat, "Error formatting mismatch for \(testCase.name)")
        }
    }

    @Test("Expression Parser Error Formatting")
    func testExpressionParserErrorFormatting() async throws {
        // Test each ParsingError case for consistent formatting
        let testCases: [ExpressionErrorTestCase] = [
            ExpressionErrorTestCase(
                name: "unexpected_end_of_input",
                parsingError: .unexpectedEndOfInput,
                expectedFormat: "ParseError: Unexpected end of input\n  Expected: expression or statement"
            ),
            ExpressionErrorTestCase(
                name: "expected_identifier",
                parsingError: .expectedIdentifier,
                expectedFormat: "ParseError: Expected identifier\n  Found: invalid or missing identifier"
            )
        ]

        for testCase in testCases {
            let formattedError = ErrorFormatter.format(testCase.parsingError)
            #expect(formattedError == testCase.expectedFormat, "Error formatting mismatch for \(testCase.name)")
        }
    }

    @Test("Error Formatting with Context")
    func testErrorFormattingWithContext() async throws {
        let input = "variable x ← \nend"
        let position = SourcePosition(line: 1, column: 12, offset: 11)
        let token = Token(type: .newline, lexeme: "\n", position: position)
        let error = ParsingError.unexpectedToken(token, expected: .identifier)

        let formattedError = ErrorFormatter.formatWithContext(error, input: input)

        // Verify that context is included
        #expect(formattedError.contains("Source context:"))
        #expect(formattedError.contains("1: variable x ←"))
        #expect(formattedError.contains("^"))
    }

    // MARK: - Real Parsing Scenario Tests

    @Test("Real Syntax Error Scenarios")
    func testRealSyntaxErrorScenarios() async throws {
        let syntaxErrorScenarios: [(String, String)] = [
            ("incomplete_assignment", "variable x ←"),
            ("missing_then", "if x > 5\nwriteLine(x)"),
            ("missing_endif", "if x > 5 then\nwriteLine(x)"),
            ("missing_colon", "variable x integer ← 5"),
            ("incomplete_function", "function test(\nreturn 42"),
            ("invalid_array_syntax", "array["),
            ("incomplete_string", "writeLine(\"Hello")
        ]

        for (testName, input) in syntaxErrorScenarios {
            var caughtError: Error?

            do {
                let tokens = try ParsingTokenizer().tokenize(input)
                let parser = StatementParser()
                _ = try parser.parseStatements(from: tokens)
            } catch {
                caughtError = error
            }

            #expect(caughtError != nil, "Expected parsing to fail for scenario: \(testName)")

            if let error = caughtError {
                let formattedError = ErrorFormatter.format(error)
                #expect(!formattedError.isEmpty, "Formatted error should not be empty for: \(testName)")
                #expect(formattedError.contains("Error") || formattedError.contains("ParseError"),
                       "Formatted error should contain error indicator for: \(testName)")
            }
        }
    }

    @Test("Unicode and Internationalization Error Scenarios")
    func testUnicodeErrorScenarios() async throws {
        let unicodeErrorScenarios: [(String, String)] = [
            ("japanese_syntax_error", "変数 データ ← "),
            ("unicode_string_error", "writeLine(\"こんにちは"),
            ("combining_characters", "variable café̌: integer ←")
        ]

        for (testName, input) in unicodeErrorScenarios {
            var caughtError: Error?

            do {
                let tokens = try ParsingTokenizer().tokenize(input)
                let parser = StatementParser()
                _ = try parser.parseStatements(from: tokens)
            } catch {
                caughtError = error
            }

            #expect(caughtError != nil, "Expected parsing to fail for Unicode scenario: \(testName)")

            if let error = caughtError {
                let formattedError = ErrorFormatter.format(error)
                #expect(!formattedError.isEmpty, "Formatted error should not be empty for Unicode: \(testName)")
            }
        }
    }

    // MARK: - Performance and Scale Tests

    @Test("Large Input Error Handling")
    func testLargeInputErrorHandling() async throws {
        // Test that parser gracefully handles large invalid inputs
        let largeInput = String(repeating: "invalid syntax ", count: 1000)

        var caughtError: Error?
        do {
            let tokens = try ParsingTokenizer().tokenize(largeInput)
            let parser = StatementParser()
            _ = try parser.parseStatements(from: tokens)
        } catch {
            caughtError = error
        }

        #expect(caughtError != nil, "Expected parsing to fail for large invalid input")

        if let error = caughtError {
            let formattedError = ErrorFormatter.format(error)
            #expect(!formattedError.isEmpty, "Formatted error should not be empty for large input")
        }
    }

    @Test("Deeply Nested Error Handling")
    func testDeeplyNestedErrorHandling() async throws {
        // Test parser's handling of deeply nested structures with errors
        var nestedInput = ""
        for index in 0..<50 {
            nestedInput += "if condition\(index) then\n"
        }
        nestedInput += "invalid syntax here"

        var caughtError: Error?
        do {
            let tokens = try ParsingTokenizer().tokenize(nestedInput)
            let parser = StatementParser()
            _ = try parser.parseStatements(from: tokens)
        } catch {
            caughtError = error
        }

        #expect(caughtError != nil, "Expected parsing to fail for deeply nested input")

        if let error = caughtError {
            let formattedError = ErrorFormatter.format(error)
            #expect(!formattedError.isEmpty, "Formatted error should not be empty for nested input")
        }
    }

    // MARK: - Helper Methods

    /// Initialize golden files with sample test cases if they don't contain any test cases yet.
    private func initializeGoldenFilesIfNeeded() async throws {
        let currentTestCases = try ParseErrorTestUtils.loadAllGoldenFiles()

        // Initialize syntax errors with common parsing failures
        if currentTestCases[.syntaxErrors]?.isEmpty ?? true {
            let syntaxTestCases = [
                ParseErrorTestUtils.GoldenTestCase(
                    name: "incomplete_assignment",
                    input: "variable x ←",
                    expectedError: "StatementParseError: Expected primary expression\n  at line 0, column 0\n  Found: ''\n  (Source context unavailable)",
                    category: .syntaxErrors
                ),
                ParseErrorTestUtils.GoldenTestCase(
                    name: "missing_colon_in_declaration",
                    input: "variable x integer ← 5",
                    expectedError: "StatementParseError: Unexpected token 'x'\n  at line 1, column 10\n  Expected: eof\n  Source context:\n  1: variable x integer ← 5\n              ^",
                    category: .syntaxErrors
                ),
                ParseErrorTestUtils.GoldenTestCase(
                    name: "missing_then_keyword",
                    input: "if x > 5\nwriteLine(x)",
                    expectedError: "StatementParseError: Unexpected token 'writeLine'\n  at line 2, column 1\n  Expected: eof\n  Source context:\n  2: writeLine(x)\n     ^",
                    category: .syntaxErrors
                )
            ]

            try ParseErrorTestUtils.generateGoldenFile(for: .syntaxErrors, testCases: syntaxTestCases)
        }

        // Initialize tokenizer errors with lexical analysis failures
        if currentTestCases[.tokenizerErrors]?.isEmpty ?? true {
            let tokenizerTestCases = [
                ParseErrorTestUtils.GoldenTestCase(
                    name: "unterminated_string",
                    input: "writeLine(\"Hello world",
                    expectedError: "UnknownParseError: Unterminated string literal at line 1, column 11",
                    category: .tokenizerErrors
                )
            ]

            try ParseErrorTestUtils.generateGoldenFile(for: .tokenizerErrors, testCases: tokenizerTestCases)
        }

        // Initialize edge cases with boundary and unusual scenarios
        if currentTestCases[.edgeCases]?.isEmpty ?? true {
            let edgeCaseTestCases = [
                ParseErrorTestUtils.GoldenTestCase(
                    name: "invalid_keyword",
                    input: "invalidkeyword x",
                    expectedError: "StatementParseError: Unexpected token 'x'\n  at line 1, column 16\n  Expected: eof\n  Source context:\n  1: invalidkeyword x\n                    ^",
                    category: .edgeCases
                )
            ]

            try ParseErrorTestUtils.generateGoldenFile(for: .edgeCases, testCases: edgeCaseTestCases)
        }
    }
}

// MARK: - Golden File Update Utilities

/// Utilities for updating golden files when error messages intentionally change.
/// These are separate from the main test suite and intended for maintenance use.
@Suite("Golden File Maintenance")
struct GoldenFileMaintenanceTests {

    @Test("Regenerate All Golden Files", .disabled("Run manually for maintenance only"))
    func regenerateAllGoldenFiles() async throws {
        // This test is marked as hidden and is used for maintenance purposes
        // Run this when error message formats change intentionally

        print("🔄 Starting golden file regeneration...")

        let categories = ParseErrorTestUtils.ErrorCategory.allCases
        for category in categories {
            print("📁 Processing category: \(category.rawValue)")

            // Load existing test cases
            do {
                let existingCases = try ParseErrorTestUtils.loadGoldenFile(for: category)

                // Regenerate with current error formatting
                var updatedCases: [ParseErrorTestUtils.GoldenTestCase] = []

                for testCase in existingCases {
                    // Re-run the test to get the current error format
                    do {
                        let tokens = try ParsingTokenizer().tokenize(testCase.input)
                        let parser = StatementParser()
                        _ = try parser.parseStatements(from: tokens)

                        // If parsing succeeds, something is wrong with the test case
                        print("⚠️  Warning: Test case '\(testCase.name)' no longer fails")
                        updatedCases.append(testCase)
                    } catch {
                        let currentError = ErrorFormatter.formatWithContext(error, input: testCase.input)
                        let updatedCase = ParseErrorTestUtils.GoldenTestCase(
                            name: testCase.name,
                            input: testCase.input,
                            expectedError: currentError,
                            category: category
                        )
                        updatedCases.append(updatedCase)
                    }
                }

                // Save updated golden file
                try ParseErrorTestUtils.generateGoldenFile(for: category, testCases: updatedCases)
                print("✅ Updated \(category.rawValue): \(updatedCases.count) test cases")

            } catch GoldenFileError.fileNotFound(_) {
                print("ℹ️  No existing golden file for \(category.rawValue), skipping")
            }
        }

        print("🎉 Golden file regeneration complete!")
    }
}
