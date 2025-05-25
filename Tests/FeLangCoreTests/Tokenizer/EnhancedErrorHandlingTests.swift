import Foundation
import Testing
@testable import FeLangCore

/// Comprehensive tests for enhanced error handling with recovery mechanisms
/// Tests multi-error collection, recovery strategies, and detailed diagnostics
@Suite("Enhanced Error Handling Tests")
struct EnhancedErrorHandlingTests {

    // MARK: - Multi-Error Collection Tests

    @Test("Multi-Error Collection: Multiple Invalid Characters")
    func testMultipleInvalidCharacters() throws {
        let source = "変数 var@ = \"Hello\" + 42# + value$ = true"
        let tokenizer = EnhancedParsingTokenizer()
        let result = tokenizer.tokenizeWithDiagnostics(source)

        // Should collect multiple errors but still produce tokens
        #expect(result.hasErrors, "Should detect multiple errors")
        #expect(result.errors.count >= 2, "Should find at least 2 invalid characters (@, #, $)")
        #expect(!result.tokens.isEmpty, "Should still produce some tokens despite errors")

        // Check specific error types
                let unexpectedCharErrors = result.errors.filter {
            if case .unexpectedCharacter = $0.type { return true }
            return false
                }
        #expect(unexpectedCharErrors.count >= 2, "Should find multiple unexpected character errors")

        // Verify errors contain correct suggestions
        for error in unexpectedCharErrors {
            #expect(!error.suggestions.isEmpty, "Unexpected character errors should have suggestions")
        }
    }

    @Test("Multi-Error Collection: String and Number Format Issues")
    func testStringAndNumberErrors() throws {
        let source = """
        変数 text = "未終端文字列
        変数 number = 123.45.67
        変数 hex = 0xGHI
        変数 final = true
        """

        let tokenizer = EnhancedParsingTokenizer()
        let result = tokenizer.tokenizeWithDiagnostics(source)

        #expect(result.hasErrors, "Should detect multiple errors")
        #expect(result.errors.count >= 2, "Should find string and number errors")

        // Check for specific error types
        let stringErrors = result.errors.filter {
            if case .unterminatedString = $0.type { return true }
            return false
        }
        #expect(!stringErrors.isEmpty, "Should find unterminated string error")

        let numberErrors = result.errors.filter {
            if case .invalidNumberFormat = $0.type { return true }
            return false
        }
        #expect(!numberErrors.isEmpty, "Should find invalid number format errors")

        // Should still find valid tokens
        let keywords = result.tokens.filter { $0.type == .variableKeyword }
        #expect(keywords.count >= 1, "Should still find '変数' keywords")

        let booleans = result.tokens.filter { $0.type == .trueKeyword }
        #expect(!booleans.isEmpty, "Should still find 'true' keyword")
    }

    @Test("Multi-Error Collection: Comment and Escape Sequence Issues")
    func testCommentAndEscapeErrors() throws {
        let source = """
        変数 text = "invalid \\q escape"
        変数 more = "another \\z problem"
        /* 未終端コメント
        変数 valid = "normal text"
        """

        let tokenizer = EnhancedParsingTokenizer()
        let result = tokenizer.tokenizeWithDiagnostics(source)

        #expect(result.hasErrors, "Should detect multiple errors")

        // Check for comment error
        let commentErrors = result.errors.filter {
            if case .unterminatedComment = $0.type { return true }
            return false
        }
        #expect(!commentErrors.isEmpty, "Should find unterminated comment error")

        // Check for escape sequence errors
        let escapeErrors = result.errors.filter {
            if case .invalidEscapeSequence = $0.type { return true }
            return false
        }
        #expect(escapeErrors.count >= 1, "Should find invalid escape sequence errors")

        // Should still parse valid parts
        let identifiers = result.tokens.filter { $0.type == .identifier }
        #expect(!identifiers.isEmpty, "Should still find identifiers")
    }

    // MARK: - Error Recovery Tests

    @Test("Error Recovery: Character Skipping")
    func testCharacterSkippingRecovery() throws {
        let source = "変数@ var% test& = true"
        let tokenizer = EnhancedParsingTokenizer()
        let result = tokenizer.tokenizeWithDiagnostics(source)

        #expect(result.hasErrors, "Should detect errors")
        #expect(result.errors.count >= 2, "Should find multiple invalid characters")

        // Should recover and find valid tokens
        let keywords = result.tokens.filter { $0.type == .variableKeyword }
        #expect(!keywords.isEmpty, "Should find '変数' keyword after recovery")

        let identifiers = result.tokens.filter { $0.type == .identifier }
        #expect(!identifiers.isEmpty, "Should find identifiers after recovery")

        let booleans = result.tokens.filter { $0.type == .trueKeyword }
        #expect(!booleans.isEmpty, "Should find boolean after recovery")
    }

    @Test("Error Recovery: String Recovery")
    func testStringRecovery() throws {
        let source = """
        変数 text = "未終端
        変数 x = 42
        変数 valid = "completed string"
        """

        let tokenizer = EnhancedParsingTokenizer()
        let result = tokenizer.tokenizeWithDiagnostics(source)

        #expect(result.hasErrors, "Should detect unterminated string")

        // Should recover and continue parsing
        let identifiers = result.tokens.filter { $0.type == .identifier && $0.lexeme == "x" }
        #expect(!identifiers.isEmpty, "Should find 'x' identifier after string recovery")

        let numbers = result.tokens.filter { $0.type == .integerLiteral }
        #expect(!numbers.isEmpty, "Should find number literal after recovery")

        let validStrings = result.tokens.filter { $0.type == .stringLiteral && $0.lexeme.contains("completed") }
        #expect(!validStrings.isEmpty, "Should find valid string after recovery")
    }

    @Test("Error Recovery: Comment Recovery")
    func testCommentRecovery() throws {
        let source = """
        変数 x = 42
        変数 y = "hello"
        /* 未終端コメント
        """

        let tokenizer = EnhancedParsingTokenizer()
        let result = tokenizer.tokenizeWithDiagnostics(source)

        #expect(result.hasErrors, "Should detect unterminated comment")

        // Should recover and parse remaining code
        let identifiers = result.tokens.filter {
            $0.type == .identifier && ($0.lexeme == "x" || $0.lexeme == "y")
        }
        #expect(identifiers.count >= 1, "Should find identifiers after comment recovery")

        let numbers = result.tokens.filter { $0.type == .integerLiteral }
        #expect(!numbers.isEmpty, "Should find number after recovery")

        let strings = result.tokens.filter { $0.type == .stringLiteral }
        #expect(!strings.isEmpty, "Should find string after recovery")
    }

    @Test("Error Recovery: Complex Multi-Error Scenario")
    func testComplexRecoveryScenario() throws {
        let source = """
        変数@ var = "未終端
        変数# number = 123.45.67
        変数$ final = true
        変数 valid = 42
        /* 未終端コメント
        """

        let tokenizer = EnhancedParsingTokenizer()
        let result = tokenizer.tokenizeWithDiagnostics(source)

        #expect(result.hasErrors, "Should detect multiple error types")
        #expect(result.errors.count >= 3, "Should find multiple errors")

        // Should still produce meaningful tokens
        #expect(result.tokens.count > 8, "Should produce substantial number of tokens despite errors")

        // Should find the valid parts
        let validKeywords = result.tokens.filter { $0.type == .variableKeyword }
        #expect(validKeywords.count >= 1, "Should find '変数' keywords")

        let validNumbers = result.tokens.filter { $0.type == .integerLiteral && $0.lexeme == "42" }
        #expect(!validNumbers.isEmpty, "Should find valid number at end")
    }

    // MARK: - Error Severity and Classification Tests

    @Test("Error Severity Classification")
    func testErrorSeverityClassification() throws {
        let source = "変数@ invalid = \"unterminated"
        let tokenizer = EnhancedParsingTokenizer()
        let result = tokenizer.tokenizeWithDiagnostics(source)

        #expect(result.hasErrors, "Should have errors")

        // All errors should be recoverable (not fatal)
        let fatalErrors = result.errors.filter { $0.severity == .fatal }
        #expect(fatalErrors.isEmpty, "Should not have fatal errors for common syntax issues")

        let recoverableErrors = result.errors.filter { $0.severity == .error }
        #expect(!recoverableErrors.isEmpty, "Should have recoverable errors")

        // Check that result is still considered successful (no fatal errors)
        #expect(result.isSuccessful, "Result should be successful despite recoverable errors")
    }

    @Test("Error Range and Position Accuracy")
    func testErrorRangeAccuracy() throws {
        let source = "変数 invalid@ = true"
        let tokenizer = EnhancedParsingTokenizer()
        let result = tokenizer.tokenizeWithDiagnostics(source)

        #expect(result.hasErrors, "Should have errors")

        guard let error = result.errors.first else {
            #expect(Bool(false), "Should have at least one error")
            return
        }

        // Check position accuracy (@ should be around column 11-16)
        #expect(error.range.start.column >= 10, "Error position should be reasonably accurate")
        #expect(error.range.start.column <= 18, "Error position should be reasonably accurate")
        #expect(error.range.start.line == 1, "Error should be on line 1")
    }

    // MARK: - Error Messages and Suggestions Tests

    @Test("Error Messages and Suggestions Quality")
    func testErrorMessagesAndSuggestions() throws {
        let source = "変数 var@ = \"unterminated"
        let tokenizer = EnhancedParsingTokenizer()
        let result = tokenizer.tokenizeWithDiagnostics(source)

        #expect(result.hasErrors, "Should have errors")

        for error in result.errors {
            // All errors should have meaningful messages
            #expect(!error.message.isEmpty, "Error should have non-empty message")
            #expect(error.message.count > 5, "Error message should be descriptive")

            // Most errors should have suggestions
            if !error.suggestions.isEmpty {
                for suggestion in error.suggestions {
                    #expect(!suggestion.isEmpty, "Suggestion should not be empty")
                    #expect(suggestion.count > 3, "Suggestion should be meaningful")
                }
            }

            // Context should be provided where available
            if let context = error.context {
                #expect(!context.isEmpty, "Context should be meaningful when provided")
            }
        }
    }

    // MARK: - Backward Compatibility Tests

    @Test("Backward Compatibility: Legacy Method Throws")
    func testBackwardCompatibilityLegacyThrows() throws {
        let source = "変数 invalid@ = true"
        let tokenizer = EnhancedParsingTokenizer()

        // Legacy method should throw on first error
        do {
            _ = try tokenizer.tokenize(source)
            #expect(Bool(false), "Legacy method should throw on error")
        } catch {
            // This is expected behavior
            #expect(error is TokenizerError, "Should throw TokenizerError for compatibility")
        }
    }

    @Test("Backward Compatibility: Error-Free Input")
    func testBackwardCompatibilityErrorFree() throws {
        let source = "変数 valid = 42"
        let tokenizer = EnhancedParsingTokenizer()

        // Both methods should work for error-free input
        let legacyTokens = try tokenizer.tokenize(source)
        let enhancedResult = tokenizer.tokenizeWithDiagnostics(source)

        #expect(!enhancedResult.hasErrors, "Should have no errors")
        #expect(!enhancedResult.hasWarnings, "Should have no warnings")
        #expect(enhancedResult.isSuccessful, "Should be successful")

        // Token counts should match (allowing for EOF differences)
        let legacyCount = legacyTokens.filter { $0.type != .eof }.count
        let enhancedCount = enhancedResult.tokens.filter { $0.type != .eof }.count
        #expect(legacyCount == enhancedCount, "Both methods should produce same token count for valid input")
    }

    // MARK: - TokenizerResult API Tests

    @Test("TokenizerResult API Functionality")
    func testTokenizerResultAPI() throws {
        let source = "変数@ var = \"unterminated"
        let tokenizer = EnhancedParsingTokenizer()
        let result = tokenizer.tokenizeWithDiagnostics(source)

        // Test various API methods
        #expect(result.hasErrors, "hasErrors should be true")
        #expect(!result.hasWarnings, "hasWarnings should be false")
        #expect(result.isSuccessful, "isSuccessful should be true (no fatal errors)")

        #expect(result.errorCount > 0, "errorCount should be positive")
        #expect(result.warningCount == 0, "warningCount should be zero")
        #expect(result.tokenCount > 0, "tokenCount should be positive")

        let recoverableErrors = result.recoverableErrors
        #expect(!recoverableErrors.isEmpty, "Should have recoverable errors")

        let fatalErrors = result.fatalErrors
        #expect(fatalErrors.isEmpty, "Should have no fatal errors")

        let errorSeverityErrors = result.errors(withSeverity: .error)
        #expect(!errorSeverityErrors.isEmpty, "Should find errors with .error severity")
    }
}
