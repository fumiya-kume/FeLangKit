import Foundation
import Testing
@testable import FeLangCore

@Suite("ParsingTokenizer Tests")
struct ParsingTokenizerTests {

    @Test func testEmptyInput() throws {
        let tokens = try ParsingTokenizer.tokenize("")
        #expect(tokens.count == 1)
        #expect(tokens[0].type == .eof)
    }

    @Test func testJapaneseKeywords() throws {
        let input = "整数型 実数型 文字型 文字列型 論理型 レコード 配列"
        let tokens = try ParsingTokenizer.tokenize(input)

        #expect(tokens.count == 8) // 7 keywords + eof
        #expect(tokens[0].type == .integerType)
        #expect(tokens[1].type == .realType)
        #expect(tokens[2].type == .characterType)
        #expect(tokens[3].type == .stringType)
        #expect(tokens[4].type == .booleanType)
        #expect(tokens[5].type == .recordType)
        #expect(tokens[6].type == .arrayType)
        #expect(tokens[7].type == .eof)
    }

    @Test func testEnglishKeywords() throws {
        let input = "if while for return break true false and or not"
        let tokens = try ParsingTokenizer.tokenize(input)

        #expect(tokens.count == 11) // 10 keywords + eof
        #expect(tokens[0].type == .ifKeyword)
        #expect(tokens[1].type == .whileKeyword)
        #expect(tokens[2].type == .forKeyword)
        #expect(tokens[3].type == .returnKeyword)
        #expect(tokens[4].type == .breakKeyword)
        #expect(tokens[5].type == .trueKeyword)
        #expect(tokens[6].type == .falseKeyword)
        #expect(tokens[7].type == .andKeyword)
        #expect(tokens[8].type == .orKeyword)
        #expect(tokens[9].type == .notKeyword)
        #expect(tokens[10].type == .eof)
    }

    @Test func testUnicodeOperators() throws {
        let input = "← ≠ ≧ ≦"
        let tokens = try ParsingTokenizer.tokenize(input)

        #expect(tokens.count == 5) // 4 operators + eof
        #expect(tokens[0].type == .assign)
        #expect(tokens[0].lexeme == "←")
        #expect(tokens[1].type == .notEqual)
        #expect(tokens[1].lexeme == "≠")
        #expect(tokens[2].type == .greaterEqual)
        #expect(tokens[2].lexeme == "≧")
        #expect(tokens[3].type == .lessEqual)
        #expect(tokens[3].lexeme == "≦")
        #expect(tokens[4].type == .eof)
    }

    @Test func testBasicOperators() throws {
        let input = "+ - * / % = > <"
        let tokens = try ParsingTokenizer.tokenize(input)

        #expect(tokens.count == 9) // 8 operators + eof
        #expect(tokens[0].type == .plus)
        #expect(tokens[1].type == .minus)
        #expect(tokens[2].type == .multiply)
        #expect(tokens[3].type == .divide)
        #expect(tokens[4].type == .modulo)
        #expect(tokens[5].type == .equal)
        #expect(tokens[6].type == .greater)
        #expect(tokens[7].type == .less)
        #expect(tokens[8].type == .eof)
    }

    @Test func testDelimiters() throws {
        let input = "( ) [ ] { } , . ; :"
        let tokens = try ParsingTokenizer.tokenize(input)

        #expect(tokens.count == 11) // 10 delimiters + eof
        #expect(tokens[0].type == .leftParen)
        #expect(tokens[1].type == .rightParen)
        #expect(tokens[2].type == .leftBracket)
        #expect(tokens[3].type == .rightBracket)
        #expect(tokens[4].type == .leftBrace)
        #expect(tokens[5].type == .rightBrace)
        #expect(tokens[6].type == .comma)
        #expect(tokens[7].type == .dot)
        #expect(tokens[8].type == .semicolon)
        #expect(tokens[9].type == .colon)
        #expect(tokens[10].type == .eof)
    }

    @Test func testIntegerLiterals() throws {
        let input = "42 -17 0 123"
        let tokens = try ParsingTokenizer.tokenize(input)

        #expect(tokens.count == 6) // 42, minus, 17, 0, 123, eof
        #expect(tokens[0].type == .integerLiteral)
        #expect(tokens[0].lexeme == "42")
        #expect(tokens[1].type == .minus)
        #expect(tokens[1].lexeme == "-")
        #expect(tokens[2].type == .integerLiteral)
        #expect(tokens[2].lexeme == "17")
        #expect(tokens[3].type == .integerLiteral)
        #expect(tokens[3].lexeme == "0")
        #expect(tokens[4].type == .integerLiteral)
        #expect(tokens[4].lexeme == "123")
        #expect(tokens[5].type == .eof)
    }

    @Test func testRealLiterals() throws {
        let input = "3.14 -2.5 0.0 123.456"
        let tokens = try ParsingTokenizer.tokenize(input)

        #expect(tokens.count == 6) // 3.14, minus, 2.5, 0.0, 123.456, eof
        #expect(tokens[0].type == .realLiteral)
        #expect(tokens[0].lexeme == "3.14")
        #expect(tokens[1].type == .minus)
        #expect(tokens[1].lexeme == "-")
        #expect(tokens[2].type == .realLiteral)
        #expect(tokens[2].lexeme == "2.5")
        #expect(tokens[3].type == .realLiteral)
        #expect(tokens[3].lexeme == "0.0")
        #expect(tokens[4].type == .realLiteral)
        #expect(tokens[4].lexeme == "123.456")
        #expect(tokens[5].type == .eof)
    }

    @Test func testStringLiterals() throws {
        let input = "'hello' 'world' 'test string'"
        let tokens = try ParsingTokenizer.tokenize(input)

        #expect(tokens.count == 4) // 3 strings + eof
        #expect(tokens[0].type == .stringLiteral)
        #expect(tokens[0].lexeme == "'hello'")
        #expect(tokens[1].type == .stringLiteral)
        #expect(tokens[1].lexeme == "'world'")
        #expect(tokens[2].type == .stringLiteral)
        #expect(tokens[2].lexeme == "'test string'")
        #expect(tokens[3].type == .eof)
    }

    @Test func testCharacterLiterals() throws {
        let input = "'a' 'x' '1'"
        let tokens = try ParsingTokenizer.tokenize(input)

        #expect(tokens.count == 4) // 3 characters + eof
        #expect(tokens[0].type == .characterLiteral)
        #expect(tokens[0].lexeme == "'a'")
        #expect(tokens[1].type == .characterLiteral)
        #expect(tokens[1].lexeme == "'x'")
        #expect(tokens[2].type == .characterLiteral)
        #expect(tokens[2].lexeme == "'1'")
        #expect(tokens[3].type == .eof)
    }

    @Test func testIdentifiers() throws {
        let input = "identifier _test camelCase snake_case _123"
        let tokens = try ParsingTokenizer.tokenize(input)

        #expect(tokens.count == 6) // 5 identifiers + eof
        #expect(tokens[0].type == .identifier)
        #expect(tokens[0].lexeme == "identifier")
        #expect(tokens[1].type == .identifier)
        #expect(tokens[1].lexeme == "_test")
        #expect(tokens[2].type == .identifier)
        #expect(tokens[2].lexeme == "camelCase")
        #expect(tokens[3].type == .identifier)
        #expect(tokens[3].lexeme == "snake_case")
        #expect(tokens[4].type == .identifier)
        #expect(tokens[4].lexeme == "_123")
        #expect(tokens[5].type == .eof)
    }

    @Test func testJapaneseIdentifiers() throws {
        let input = "変数 カウンタ 日本語識別子"
        let tokens = try ParsingTokenizer.tokenize(input)

        #expect(tokens.count == 4) // 3 identifiers + eof
        #expect(tokens[0].type == .identifier)
        #expect(tokens[0].lexeme == "変数")
        #expect(tokens[1].type == .identifier)
        #expect(tokens[1].lexeme == "カウンタ")
        #expect(tokens[2].type == .identifier)
        #expect(tokens[2].lexeme == "日本語識別子")
        #expect(tokens[3].type == .eof)
    }

    @Test func testComments() throws {
        let input = """
        // This is a single line comment
        /* This is a
           multi-line comment */
        identifier
        """
        let tokens = try ParsingTokenizer.tokenize(input)

        // Comments should be filtered out, so we should only have the identifier and eof
        #expect(tokens.count == 2)
        #expect(tokens[0].type == .identifier)
        #expect(tokens[0].lexeme == "identifier")
        #expect(tokens[1].type == .eof)
    }

    @Test func testWhitespaceFiltering() throws {
        let input = "  identifier    \t   another  "
        let tokens = try ParsingTokenizer.tokenize(input)

        // Whitespace should be filtered out
        #expect(tokens.count == 3) // 2 identifiers + eof
        #expect(tokens[0].type == .identifier)
        #expect(tokens[0].lexeme == "identifier")
        #expect(tokens[1].type == .identifier)
        #expect(tokens[1].lexeme == "another")
        #expect(tokens[2].type == .eof)
    }

    @Test func testPositionTracking() throws {
        let input = """
        整数型 x
        実数型 y
        """
        let tokens = try ParsingTokenizer.tokenize(input)

        #expect(tokens.count == 5) // 4 tokens + eof

        // First line tokens
        #expect(tokens[0].position.line == 1)
        #expect(tokens[0].position.column == 1)
        #expect(tokens[1].position.line == 1)
        #expect(tokens[1].position.column == 5)

        // Second line tokens
        #expect(tokens[2].position.line == 2)
        #expect(tokens[2].position.column == 1)
        #expect(tokens[3].position.line == 2)
        #expect(tokens[3].position.column == 5)
    }

    @Test func testComplexExpression() throws {
        let input = "if (x ≧ 10 and y ≦ 20) { result ← x + y }"
        let tokens = try ParsingTokenizer.tokenize(input)

        let expectedTypes: [TokenType] = [
            .ifKeyword, .leftParen, .identifier, .greaterEqual, .integerLiteral,
            .andKeyword, .identifier, .lessEqual, .integerLiteral, .rightParen,
            .leftBrace, .identifier, .assign, .identifier, .plus, .identifier,
            .rightBrace, .eof
        ]

        #expect(tokens.count == expectedTypes.count)
        for (index, expectedType) in expectedTypes.enumerated() {
            #expect(tokens[index].type == expectedType)
        }
    }

    @Test func testDotVsDecimal() throws {
        let input = "obj.field 3.14"
        let tokens = try ParsingTokenizer.tokenize(input)

        #expect(tokens.count == 5) // identifier, dot, identifier, real, eof
        #expect(tokens[0].type == .identifier)
        #expect(tokens[1].type == .dot)
        #expect(tokens[2].type == .identifier)
        #expect(tokens[3].type == .realLiteral)
        #expect(tokens[3].lexeme == "3.14")
        #expect(tokens[4].type == .eof)
    }

    @Test func testUnexpectedCharacter() throws {
        let input = "identifier @ another"

        #expect(throws: TokenizerError.self) {
            try ParsingTokenizer.tokenize(input)
        }
    }
}
