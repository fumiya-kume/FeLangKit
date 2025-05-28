@testable import FeLangCore
import Testing

struct TokenizerTests {

    // MARK: - Basic Token Tests

    @Test func testBasicTokens() throws {
        let tokenizer = Tokenizer(input: "整数型: x")
        let tokens = try tokenizer.tokenize()

        #expect(tokens.count == 4) // integerType, colon, identifier, eof
        #expect(tokens[0].type == .integerType)
        #expect(tokens[0].lexeme == "整数型")
        #expect(tokens[1].type == .colon)
        #expect(tokens[1].lexeme == ":")
        #expect(tokens[2].type == .identifier)
        #expect(tokens[2].lexeme == "x")
        #expect(tokens[3].type == .eof)
    }

    @Test func testKeywords() throws {
        let input = "整数型 実数型 文字型 文字列型 論理型 レコード 配列 if while for and or not return break true false"
        let tokenizer = Tokenizer(input: input)
        let tokens = try tokenizer.tokenize()

        let expectedTypes: [TokenType] = [
            .integerType, .realType, .characterType, .stringType, .booleanType,
                         .recordType, .arrayType, .ifKeyword, .whileKeyword, .forKeyword,
            .andKeyword, .orKeyword, .notKeyword, .returnKeyword, .breakKeyword,
            .trueKeyword, .falseKeyword, .eof
        ]

        #expect(tokens.count == expectedTypes.count)
        for (index, expectedType) in expectedTypes.enumerated() {
            #expect(tokens[index].type == expectedType)
        }
    }

    @Test func testOperators() throws {
        let input = "+ - * / % ← = ≠ > ≧ < ≦"
        let tokenizer = Tokenizer(input: input)
        let tokens = try tokenizer.tokenize()

        let expectedTypes: [TokenType] = [
            .plus, .minus, .multiply, .divide, .modulo, .assign,
            .equal, .notEqual, .greater, .greaterEqual, .less, .lessEqual, .eof
        ]

        #expect(tokens.count == expectedTypes.count)
        for (index, expectedType) in expectedTypes.enumerated() {
            #expect(tokens[index].type == expectedType)
        }
    }

    @Test func testDelimiters() throws {
        let input = "( ) [ ] { } , . ; :"
        let tokenizer = Tokenizer(input: input)
        let tokens = try tokenizer.tokenize()

        let expectedTypes: [TokenType] = [
            .leftParen, .rightParen, .leftBracket, .rightBracket,
            .leftBrace, .rightBrace, .comma, .dot, .semicolon, .colon, .eof
        ]

        #expect(tokens.count == expectedTypes.count)
        for (index, expectedType) in expectedTypes.enumerated() {
            #expect(tokens[index].type == expectedType)
        }
    }

    // MARK: - Literal Tests

    @Test func testIntegerLiterals() throws {
        let input = "123 -45 0"
        let tokenizer = Tokenizer(input: input)
        let tokens = try tokenizer.tokenize()

        #expect(tokens.count == 4) // three integers + eof
        #expect(tokens[0].type == .integerLiteral)
        #expect(tokens[0].lexeme == "123")
        #expect(tokens[1].type == .integerLiteral)
        #expect(tokens[1].lexeme == "-45")
        #expect(tokens[2].type == .integerLiteral)
        #expect(tokens[2].lexeme == "0")
        #expect(tokens[3].type == .eof)
    }

    @Test func testRealLiterals() throws {
        let input = "1.25 -52.325 0.0"
        let tokenizer = Tokenizer(input: input)
        let tokens = try tokenizer.tokenize()

        #expect(tokens.count == 4) // three reals + eof
        #expect(tokens[0].type == .realLiteral)
        #expect(tokens[0].lexeme == "1.25")
        #expect(tokens[1].type == .realLiteral)
        #expect(tokens[1].lexeme == "-52.325")
        #expect(tokens[2].type == .realLiteral)
        #expect(tokens[2].lexeme == "0.0")
        #expect(tokens[3].type == .eof)
    }

    @Test func testStringLiterals() throws {
        let input = "'Hello' 'PAFUTAMA' ''"
        let tokenizer = Tokenizer(input: input)
        let tokens = try tokenizer.tokenize()

        #expect(tokens.count == 4) // three strings + eof
        #expect(tokens[0].type == .stringLiteral)
        #expect(tokens[0].lexeme == "'Hello'")
        #expect(tokens[1].type == .stringLiteral)
        #expect(tokens[1].lexeme == "'PAFUTAMA'")
        #expect(tokens[2].type == .stringLiteral)
        #expect(tokens[2].lexeme == "''")
        #expect(tokens[3].type == .eof)
    }

    @Test func testCharacterLiterals() throws {
        let input = "'A' 'B' '1'"
        let tokenizer = Tokenizer(input: input)
        let tokens = try tokenizer.tokenize()

        #expect(tokens.count == 4) // three characters + eof
        #expect(tokens[0].type == .characterLiteral)
        #expect(tokens[0].lexeme == "'A'")
        #expect(tokens[1].type == .characterLiteral)
        #expect(tokens[1].lexeme == "'B'")
        #expect(tokens[2].type == .characterLiteral)
        #expect(tokens[2].lexeme == "'1'")
        #expect(tokens[3].type == .eof)
    }

    // MARK: - Identifier Tests

    @Test func testIdentifiers() throws {
        let input = "variable_name function123 _private 変数名"
        let tokenizer = Tokenizer(input: input)
        let tokens = try tokenizer.tokenize()

        #expect(tokens.count == 5) // four identifiers + eof
        #expect(tokens[0].type == .identifier)
        #expect(tokens[0].lexeme == "variable_name")
        #expect(tokens[1].type == .identifier)
        #expect(tokens[1].lexeme == "function123")
        #expect(tokens[2].type == .identifier)
        #expect(tokens[2].lexeme == "_private")
        #expect(tokens[3].type == .identifier)
        #expect(tokens[3].lexeme == "変数名")
        #expect(tokens[4].type == .eof)
    }

    // MARK: - Comment Tests

    @Test func testSingleLineComment() throws {
        let input = "x // This is a comment\ny"
        let tokenizer = Tokenizer(input: input)
        let tokens = try tokenizer.tokenize()

        #expect(tokens.count == 4) // x, newline, y, eof
        #expect(tokens[0].type == .identifier)
        #expect(tokens[0].lexeme == "x")
        #expect(tokens[1].type == .newline)
        #expect(tokens[2].type == .identifier)
        #expect(tokens[2].lexeme == "y")
        #expect(tokens[3].type == .eof)
    }

    @Test func testMultiLineComment() throws {
        let input = "x /* This is a\nmulti-line comment */ y"
        let tokenizer = Tokenizer(input: input)
        let tokens = try tokenizer.tokenize()

        #expect(tokens.count == 3) // x, y, eof
        #expect(tokens[0].type == .identifier)
        #expect(tokens[0].lexeme == "x")
        #expect(tokens[1].type == .identifier)
        #expect(tokens[1].lexeme == "y")
        #expect(tokens[2].type == .eof)
    }

    // MARK: - Position Tracking Tests

    @Test func testPositionTracking() throws {
        let input = "x\ny"
        let tokenizer = Tokenizer(input: input)
        let tokens = try tokenizer.tokenize()

        #expect(tokens.count == 4) // x, newline, y, eof

        // First token 'x' at line 1, column 1
        #expect(tokens[0].position.line == 1)
        #expect(tokens[0].position.column == 1)

        // Newline at line 1, column 2
        #expect(tokens[1].position.line == 1)
        #expect(tokens[1].position.column == 2)

        // Second token 'y' at line 2, column 1
        #expect(tokens[2].position.line == 2)
        #expect(tokens[2].position.column == 1)
    }

    // MARK: - Error Tests

    @Test func testUnexpectedCharacter() throws {
        let tokenizer = Tokenizer(input: "x @ y")

        #expect(throws: TokenizerError.self) {
            try tokenizer.tokenize()
        }
    }

    @Test func testUnterminatedString() throws {
        let tokenizer = Tokenizer(input: "'unterminated")

        #expect(throws: TokenizerError.self) {
            try tokenizer.tokenize()
        }
    }

    @Test func testUnterminatedComment() throws {
        let tokenizer = Tokenizer(input: "/* unterminated comment")

        #expect(throws: TokenizerError.self) {
            try tokenizer.tokenize()
        }
    }

    // MARK: - Complex Expression Tests

    @Test func testComplexExpression() throws {
        let input = "整数型: x ← 10 + 20 * 3"
        let tokenizer = Tokenizer(input: input)
        let tokens = try tokenizer.tokenize()

        let expectedTypes: [TokenType] = [
            .integerType, .colon, .identifier, .assign, .integerLiteral,
            .plus, .integerLiteral, .multiply, .integerLiteral, .eof
        ]

        #expect(tokens.count == expectedTypes.count)
        for (index, expectedType) in expectedTypes.enumerated() {
            #expect(tokens[index].type == expectedType)
        }
    }

    @Test func testArrayAccess() throws {
        let input = "配列名[添字]"
        let tokenizer = Tokenizer(input: input)
        let tokens = try tokenizer.tokenize()

        #expect(tokens.count == 5) // identifier, [, identifier, ], eof
        #expect(tokens[0].type == .identifier)
        #expect(tokens[0].lexeme == "配列名")
        #expect(tokens[1].type == .leftBracket)
        #expect(tokens[2].type == .identifier)
        #expect(tokens[2].lexeme == "添字")
        #expect(tokens[3].type == .rightBracket)
        #expect(tokens[4].type == .eof)
    }

    @Test func testRecordAccess() throws {
        let input = "レコード名.フィールド名"
        let tokenizer = Tokenizer(input: input)
        let tokens = try tokenizer.tokenize()

        #expect(tokens.count == 4) // identifier, dot, identifier, eof
        #expect(tokens[0].type == .identifier)
        #expect(tokens[0].lexeme == "レコード名")
        #expect(tokens[1].type == .dot)
        #expect(tokens[2].type == .identifier)
        #expect(tokens[2].lexeme == "フィールド名")
        #expect(tokens[3].type == .eof)
    }

    // MARK: - Edge Cases

    @Test func testEmptyInput() throws {
        let tokenizer = Tokenizer(input: "")
        let tokens = try tokenizer.tokenize()

        #expect(tokens.count == 1) // only eof
        #expect(tokens[0].type == .eof)
    }

    @Test func testWhitespaceOnly() throws {
        let tokenizer = Tokenizer(input: "   \t  \n  ")
        let tokens = try tokenizer.tokenize()

        #expect(tokens.count == 2) // newline + eof
        #expect(tokens[0].type == .newline)
        #expect(tokens[1].type == .eof)
    }

    @Test func testMinusVsNegativeNumber() throws {
        let input = "x - 5 -10"
        let tokenizer = Tokenizer(input: input)
        let tokens = try tokenizer.tokenize()

        #expect(tokens.count == 5) // x, minus, integer(5), integer(-10), eof
        #expect(tokens[0].type == .identifier)
        #expect(tokens[1].type == .minus)
        #expect(tokens[2].type == .integerLiteral)
        #expect(tokens[2].lexeme == "5")
        #expect(tokens[3].type == .integerLiteral)
        #expect(tokens[3].lexeme == "-10")
        #expect(tokens[4].type == .eof)
    }

    @Test func testDotVsDecimal() throws {
        let input = "obj.field 3.14"
        let tokenizer = Tokenizer(input: input)
        let tokens = try tokenizer.tokenize()

        #expect(tokens.count == 5) // identifier, dot, identifier, real, eof
        #expect(tokens[0].type == .identifier)
        #expect(tokens[1].type == .dot)
        #expect(tokens[2].type == .identifier)
        #expect(tokens[3].type == .realLiteral)
        #expect(tokens[3].lexeme == "3.14")
        #expect(tokens[4].type == .eof)
    }

    // MARK: - Keyword Boundary Tests

    @Test func testKeywordBoundariesWithEnglishKeywords() throws {
        // Test that keywords are properly bounded and don't match partial identifiers
        let input = "if ifVar variable_if if_var while whileLoop for forEach"
        let tokenizer = Tokenizer(input: input)
        let tokens = try tokenizer.tokenize()

        let expectedTypes: [TokenType] = [
            .ifKeyword,     // "if" - exact keyword
            .identifier,    // "ifVar" - identifier starting with keyword
            .identifier,    // "variable_if" - identifier ending with keyword
            .identifier,    // "if_var" - identifier containing keyword
            .whileKeyword,  // "while" - exact keyword
            .identifier,    // "whileLoop" - identifier starting with keyword
            .forKeyword,    // "for" - exact keyword
            .identifier,    // "forEach" - identifier starting with keyword
            .eof
        ]

        #expect(tokens.count == expectedTypes.count)
        for (index, expectedType) in expectedTypes.enumerated() {
            #expect(tokens[index].type == expectedType, "Token \(index): expected \(expectedType), got \(tokens[index].type)")
        }
    }

    @Test func testKeywordBoundariesWithJapaneseKeywords() throws {
        // Test that Japanese keywords are properly bounded
        let input = "整数型 整数型変数 変数整数型 整数型_var 実数型 実数型データ"
        let tokenizer = Tokenizer(input: input)
        let tokens = try tokenizer.tokenize()

        let expectedTypes: [TokenType] = [
            .integerType,   // "整数型" - exact keyword
            .identifier,    // "整数型変数" - identifier starting with keyword
            .identifier,    // "変数整数型" - identifier ending with keyword
            .identifier,    // "整数型_var" - identifier with keyword + underscore
            .realType,      // "実数型" - exact keyword
            .identifier,    // "実数型データ" - identifier starting with keyword
            .eof
        ]

        #expect(tokens.count == expectedTypes.count)
        for (index, expectedType) in expectedTypes.enumerated() {
            #expect(tokens[index].type == expectedType, "Token \(index): expected \(expectedType), got \(tokens[index].type)")
        }
    }

    @Test func testKeywordBoundariesWithUnicodeCharacters() throws {
        // Test keyword boundaries with various Unicode characters
        let input = "if_test if123 if-var if.method"
        let tokenizer = Tokenizer(input: input)
        let tokens = try tokenizer.tokenize()

        let expectedTypes: [TokenType] = [
            .identifier,    // "if_test"
            .identifier,    // "if123"
            .ifKeyword,     // "if"
            .minus,         // "-"
            .identifier,    // "var"
            .ifKeyword,     // "if"
            .dot,           // "."
            .identifier,    // "method"
            .eof
        ]

        #expect(tokens.count == expectedTypes.count)
        for (index, expectedType) in expectedTypes.enumerated() {
            #expect(tokens[index].type == expectedType, "Token \(index): expected \(expectedType), got \(tokens[index].type)")
        }
    }

    @Test func testUnsupportedCharacterHandling() throws {
        // Test that unsupported characters (like emojis) are properly rejected
        let input = "if🚀"
        let tokenizer = Tokenizer(input: input)

        #expect(throws: TokenizerError.self) {
            try tokenizer.tokenize()
        }
    }

    @Test func testKeywordBoundariesAtEndOfInput() throws {
        // Test keywords at the end of input (no following characters)
        let input = "if"
        let tokenizer = Tokenizer(input: input)
        let tokens = try tokenizer.tokenize()

        #expect(tokens.count == 2) // keyword + eof
        #expect(tokens[0].type == .ifKeyword)
        #expect(tokens[0].lexeme == "if")
        #expect(tokens[1].type == .eof)
    }

    @Test func testKeywordBoundariesWithWhitespace() throws {
        // Test keywords properly separated by whitespace
        let input = "if while\tfor\nreturn"
        let tokenizer = Tokenizer(input: input)
        let tokens = try tokenizer.tokenize()

        let expectedTypes: [TokenType] = [
            .ifKeyword,
            .whileKeyword,
            .forKeyword,
            .newline,
            .returnKeyword,
            .eof
        ]

        #expect(tokens.count == expectedTypes.count)
        for (index, expectedType) in expectedTypes.enumerated() {
            #expect(tokens[index].type == expectedType)
        }
    }

    @Test func testExtendedCJKCharacters() throws {
        // Test that extended CJK characters are properly handled in identifiers
        let input = "変数名 𠀀test 㐀identifier"  // Using CJK Extension A and B characters
        let tokenizer = Tokenizer(input: input)
        let tokens = try tokenizer.tokenize()

        #expect(tokens.count == 4) // three identifiers + eof
        #expect(tokens[0].type == .identifier)
        #expect(tokens[0].lexeme == "変数名")
        #expect(tokens[1].type == .identifier)
        #expect(tokens[1].lexeme == "𠀀test")
        #expect(tokens[2].type == .identifier)
        #expect(tokens[2].lexeme == "㐀identifier")
        #expect(tokens[3].type == .eof)
    }
}
