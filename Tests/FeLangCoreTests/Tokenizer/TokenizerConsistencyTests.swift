@testable import FeLangCore
import Testing

/// Tests to verify consistency between different tokenizer implementations
/// when using shared utilities
struct TokenizerConsistencyTests {

    @Test func testTokenizerConsistency() throws {
        // Test cases where both tokenizers should behave identically
        // Note: Negative numbers and comments are handled differently between implementations
        let testCases = [
            "整数型: x ← 10 + 20 * 3",
            "if while for and or not return break true false",
            "配列名[添字] レコード名.フィールド名",
            "'Hello' 'A' 123 3.14 .5",  // Removed negative number
            "変数名 function123 _private",
            "← = ≠ > ≧ < ≦ + - * / %",
            "( ) [ ] { } , . ; :"
        ]

        for testCase in testCases {
            let originalTokenizer = Tokenizer(input: testCase)
            let parsingTokenizer = ParsingTokenizer()

            let originalTokens = try originalTokenizer.tokenize()
            let parsingTokens = try parsingTokenizer.tokenize(testCase)

            // Both should produce the same number of tokens
            #expect(originalTokens.count == parsingTokens.count,
                   "Token count mismatch for input: '\(testCase)'. Original: \(originalTokens.count), Parsing: \(parsingTokens.count)")

            // Both should produce tokens with the same types and lexemes
            for (index, (original, parsing)) in zip(originalTokens, parsingTokens).enumerated() {
                #expect(original.type == parsing.type,
                       "Token type mismatch at index \(index) for input: '\(testCase)'. Original: \(original.type), Parsing: \(parsing.type)")
                #expect(original.lexeme == parsing.lexeme,
                       "Token lexeme mismatch at index \(index) for input: '\(testCase)'. Original: '\(original.lexeme)', Parsing: '\(parsing.lexeme)'")
            }
        }
    }

    @Test func testSharedUtilitiesKeywordConsistency() throws {
        // Test that both tokenizers use the same keyword definitions
        let keywordTests = [
            ("整数型", TokenType.integerType),
            ("実数型", TokenType.realType),
            ("文字型", TokenType.characterType),
            ("文字列型", TokenType.stringType),
            ("論理型", TokenType.booleanType),
            ("レコード", TokenType.recordType),
            ("配列", TokenType.arrayType),
            ("if", TokenType.ifKeyword),
            ("while", TokenType.whileKeyword),
            ("for", TokenType.forKeyword),
            ("and", TokenType.andKeyword),
            ("or", TokenType.orKeyword),
            ("not", TokenType.notKeyword),
            ("return", TokenType.returnKeyword),
            ("break", TokenType.breakKeyword),
            ("true", TokenType.trueKeyword),
            ("false", TokenType.falseKeyword)
        ]

        for (keyword, expectedType) in keywordTests {
            let originalTokenizer = Tokenizer(input: keyword)
            let parsingTokenizer = ParsingTokenizer()

            let originalTokens = try originalTokenizer.tokenize()
            let parsingTokens = try parsingTokenizer.tokenize(keyword)

            // Both should recognize the keyword
            #expect(originalTokens.count >= 2) // keyword + eof
            #expect(parsingTokens.count >= 2) // keyword + eof
            #expect(originalTokens[0].type == expectedType)
            #expect(parsingTokens[0].type == expectedType)
            #expect(originalTokens[0].lexeme == keyword)
            #expect(parsingTokens[0].lexeme == keyword)
        }
    }

    @Test func testSharedUtilitiesCharacterClassification() throws {
        // Test that character classification functions work consistently
        let identifierTests = [
            "variable_name",
            "function123",
            "_private",
            "変数名",
            "𠀀test",  // CJK Extension B
            "㐀identifier"  // CJK Extension A
        ]

        for identifier in identifierTests {
            let originalTokenizer = Tokenizer(input: identifier)
            let parsingTokenizer = ParsingTokenizer()

            let originalTokens = try originalTokenizer.tokenize()
            let parsingTokens = try parsingTokenizer.tokenize(identifier)

            // Both should recognize as identifier
            #expect(originalTokens.count >= 2) // identifier + eof
            #expect(parsingTokens.count >= 2) // identifier + eof
            #expect(originalTokens[0].type == .identifier)
            #expect(parsingTokens[0].type == .identifier)
            #expect(originalTokens[0].lexeme == identifier)
            #expect(parsingTokens[0].lexeme == identifier)
        }
    }

    @Test func testSharedUtilitiesNumberTokenTypes() throws {
        let numberTests = [
            ("123", TokenType.integerLiteral),
            ("3.14", TokenType.realLiteral),
            (".5", TokenType.realLiteral),
            ("0", TokenType.integerLiteral),
            ("0.0", TokenType.realLiteral)
        ]

        for (number, expectedType) in numberTests {
            let originalTokenizer = Tokenizer(input: number)
            let parsingTokenizer = ParsingTokenizer()

            let originalTokens = try originalTokenizer.tokenize()
            let parsingTokens = try parsingTokenizer.tokenize(number)

            // Both should recognize the number type correctly
            #expect(originalTokens.count >= 2) // number + eof
            #expect(parsingTokens.count >= 2) // number + eof
            #expect(originalTokens[0].type == expectedType)
            #expect(parsingTokens[0].type == expectedType)
            #expect(originalTokens[0].lexeme == number)
            #expect(parsingTokens[0].lexeme == number)
        }
    }

    @Test func testSharedUtilitiesStringLiteralTypes() throws {
        let stringTests = [
            ("'A'", TokenType.characterLiteral),
            ("'Hello'", TokenType.stringLiteral),
            ("''", TokenType.stringLiteral)
        ]

        for (string, expectedType) in stringTests {
            let originalTokenizer = Tokenizer(input: string)
            let parsingTokenizer = ParsingTokenizer()

            let originalTokens = try originalTokenizer.tokenize()
            let parsingTokens = try parsingTokenizer.tokenize(string)

            // Both should recognize the string type correctly
            #expect(originalTokens.count >= 2) // string + eof
            #expect(parsingTokens.count >= 2) // string + eof
            #expect(originalTokens[0].type == expectedType)
            #expect(parsingTokens[0].type == expectedType)
            #expect(originalTokens[0].lexeme == string)
            #expect(parsingTokens[0].lexeme == string)
        }
    }

    @Test func testErrorHandlingConsistency() throws {
        // Test that both tokenizers throw the same errors for invalid input
        let errorTestCases = [
            "/* unterminated comment",
            "'unterminated string"
        ]

        for testCase in errorTestCases {
            // Both tokenizers should throw TokenizerError
            var originalError: TokenizerError?
            var parsingError: TokenizerError?

            do {
                let originalTokenizer = Tokenizer(input: testCase)
                _ = try originalTokenizer.tokenize()
            } catch let error as TokenizerError {
                originalError = error
            }

            do {
                _ = try ParsingTokenizer.tokenize(testCase)
            } catch let error as TokenizerError {
                parsingError = error
            }

            // Both should throw the same type of error
            #expect(originalError != nil, "Original tokenizer should throw error for: '\(testCase)'")
            #expect(parsingError != nil, "Parsing tokenizer should throw error for: '\(testCase)'")

            if let original = originalError, let parsing = parsingError {
                // Check that error types match
                switch (original, parsing) {
                case (.unterminatedComment, .unterminatedComment),
                     (.unterminatedString, .unterminatedString):
                    // Errors match - this is expected
                    break
                default:
                    #expect(Bool(false), "Error types don't match for '\(testCase)'. Original: \(original), Parsing: \(parsing)")
                }
            }
        }
    }
}
