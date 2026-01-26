@testable import FeLangCore
import Testing

/// Tests to verify ParsingTokenizer behavior with shared utilities
struct TokenizerConsistencyTests {

    @Test func testTokenizerBasicExpressions() throws {
        let testCases = [
            "整数型: x ← 10 + 20 * 3",
            "if while for and or not return break true false",
            "配列名[添字] レコード名.フィールド名",
            "'Hello' 'A' 123 3.14 .5",
            "変数名 function123 _private",
            "← = != ≠ > ≧ < ≦ + - * / %",
            "( ) [ ] { } , . ; :"
        ]

        for testCase in testCases {
            let tokens = try ParsingTokenizer.tokenize(testCase)
            #expect(tokens.count >= 2, "Should produce at least one token + eof for input: '\(testCase)'")
            #expect(tokens.last?.type == .eof, "Last token should be eof for input: '\(testCase)'")
        }
    }

    @Test func testSharedUtilitiesKeywordConsistency() throws {
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
            let tokens = try ParsingTokenizer.tokenize(keyword)
            #expect(tokens.count >= 2) // keyword + eof
            #expect(tokens[0].type == expectedType)
            #expect(tokens[0].lexeme == keyword)
        }
    }

    @Test func testSharedUtilitiesCharacterClassification() throws {
        let identifierTests = [
            "variable_name",
            "function123",
            "_private",
            "変数名",
            "𠀀test",  // CJK Extension B
            "㐀identifier"  // CJK Extension A
        ]

        for identifier in identifierTests {
            let tokens = try ParsingTokenizer.tokenize(identifier)
            #expect(tokens.count >= 2) // identifier + eof
            #expect(tokens[0].type == .identifier)
            #expect(tokens[0].lexeme == identifier)
        }
    }

    @Test func testSharedUtilitiesNumberTokenTypes() throws {
        let numberTests = [
            ("123", TokenType.integerLiteral),
            ("3.14", TokenType.realLiteral),
            (".5", TokenType.realLiteral),
            ("0", TokenType.integerLiteral),
            ("0.0", TokenType.realLiteral),
            ("1e5", TokenType.realLiteral),
            ("1.23E-5", TokenType.realLiteral),
            ("0xFF", TokenType.integerLiteral),
            ("0b1010", TokenType.integerLiteral),
            ("0o777", TokenType.integerLiteral),
            ("1_000_000", TokenType.integerLiteral),
            ("3.14_159", TokenType.realLiteral)
        ]

        for (number, expectedType) in numberTests {
            let tokens = try ParsingTokenizer.tokenize(number)
            #expect(tokens.count >= 2) // number + eof
            #expect(tokens[0].type == expectedType)
            #expect(tokens[0].lexeme == number)
        }
    }

    @Test func testSharedUtilitiesStringLiteralTypes() throws {
        let stringTests = [
            ("'A'", TokenType.characterLiteral),
            ("'Hello'", TokenType.stringLiteral),
            ("''", TokenType.stringLiteral)
        ]

        for (string, expectedType) in stringTests {
            let tokens = try ParsingTokenizer.tokenize(string)
            #expect(tokens.count >= 2) // string + eof
            #expect(tokens[0].type == expectedType)
            #expect(tokens[0].lexeme == string)
        }
    }

    @Test func testASCIINotEqualOperator() throws {
        let testCase = "a != b"
        let tokens = try ParsingTokenizer.tokenize(testCase)
        #expect(tokens[1].type == .notEqual)
        #expect(tokens[1].lexeme == "!=")
    }

    @Test func testErrorHandlingConsistency() throws {
        let errorTestCases = [
            "/* unterminated comment",
            "'unterminated string"
        ]

        for testCase in errorTestCases {
            #expect(throws: TokenizerError.self) {
                _ = try ParsingTokenizer.tokenize(testCase)
            }
        }
    }
}
