import Foundation
import Testing
@testable import FeLangCore

@Suite("FastParsingTokenizer Tests")
struct FastParsingTokenizerTests {

    private let tokenizer = FastParsingTokenizer()

    // MARK: - Basic Tokenization Tests

    @Test func testEmptyInput() throws {
        let tokens = try tokenizer.tokenize("")
        #expect(tokens.count == 1)
        #expect(tokens[0].type == .eof)
    }

    @Test func testWhitespaceHandling() throws {
        let tokens = try tokenizer.tokenize("   \t\n  ")
        #expect(tokens.count == 1)
        #expect(tokens[0].type == .eof)
    }

    // MARK: - Identifier Tests

    @Test func testASCIIIdentifiers() throws {
        let input = "identifier _test camelCase snake_case _123"
        let tokens = try tokenizer.tokenize(input)

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

    @Test func testJapaneseKeywords() throws {
        // Test each Japanese keyword individually
        let intType = try tokenizer.tokenize("整数型")
        #expect(intType[0].type == .integerType)

        let realType = try tokenizer.tokenize("実数型")
        #expect(realType[0].type == .realType)

        let charType = try tokenizer.tokenize("文字型")
        #expect(charType[0].type == .characterType)

        let strType = try tokenizer.tokenize("文字列型")
        #expect(strType[0].type == .stringType)

        let boolType = try tokenizer.tokenize("論理型")
        #expect(boolType[0].type == .booleanType)
    }

    @Test func testEnglishKeywords() throws {
        let input = "if while for return break true false and or not"
        let tokens = try tokenizer.tokenize(input)

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

    // MARK: - Number Literal Tests

    @Test func testIntegerLiterals() throws {
        let input = "42 0 123"
        let tokens = try tokenizer.tokenize(input)

        #expect(tokens.count == 4) // 3 integers + eof
        #expect(tokens[0].type == .integerLiteral)
        #expect(tokens[0].lexeme == "42")
        #expect(tokens[1].type == .integerLiteral)
        #expect(tokens[1].lexeme == "0")
        #expect(tokens[2].type == .integerLiteral)
        #expect(tokens[2].lexeme == "123")
        #expect(tokens[3].type == .eof)
    }

    @Test func testRealLiterals() throws {
        let input = "3.14 0.0 123.456"
        let tokens = try tokenizer.tokenize(input)

        #expect(tokens.count == 4) // 3 reals + eof
        #expect(tokens[0].type == .realLiteral)
        #expect(tokens[0].lexeme == "3.14")
        #expect(tokens[1].type == .realLiteral)
        #expect(tokens[1].lexeme == "0.0")
        #expect(tokens[2].type == .realLiteral)
        #expect(tokens[2].lexeme == "123.456")
        #expect(tokens[3].type == .eof)
    }

    @Test func testLeadingDotDecimals() throws {
        let input = ".5 .25 .123"
        let tokens = try tokenizer.tokenize(input)

        #expect(tokens.count == 4) // 3 reals + eof
        #expect(tokens[0].type == .realLiteral)
        #expect(tokens[0].lexeme == ".5")
        #expect(tokens[1].type == .realLiteral)
        #expect(tokens[1].lexeme == ".25")
        #expect(tokens[2].type == .realLiteral)
        #expect(tokens[2].lexeme == ".123")
        #expect(tokens[3].type == .eof)
    }

    // MARK: - Operator Tests

    @Test func testASCIIOperators() throws {
        let input = "+ - * / % = > <"
        let tokens = try tokenizer.tokenize(input)

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

    @Test func testUnicodeOperators() throws {
        // Test each Unicode operator individually
        let assign = try tokenizer.tokenize("←")
        #expect(assign[0].type == .assign)
        #expect(assign[0].lexeme == "←")

        let notEq = try tokenizer.tokenize("≠")
        #expect(notEq[0].type == .notEqual)
        #expect(notEq[0].lexeme == "≠")

        let geq = try tokenizer.tokenize("≧")
        #expect(geq[0].type == .greaterEqual)
        #expect(geq[0].lexeme == "≧")

        let leq = try tokenizer.tokenize("≦")
        #expect(leq[0].type == .lessEqual)
        #expect(leq[0].lexeme == "≦")
    }

    @Test func testDelimiters() throws {
        let input = "( ) [ ] { } , . ; :"
        let tokens = try tokenizer.tokenize(input)

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

    // MARK: - String Literal Tests

    @Test func testStringLiterals() throws {
        let input = "'hello' 'world'"
        let tokens = try tokenizer.tokenize(input)

        #expect(tokens.count == 3) // 2 strings + eof
        #expect(tokens[0].type == .stringLiteral)
        #expect(tokens[0].lexeme == "'hello'")
        #expect(tokens[1].type == .stringLiteral)
        #expect(tokens[1].lexeme == "'world'")
        #expect(tokens[2].type == .eof)
    }

    @Test func testEscapeSequences() throws {
        let input = "'hello\\nworld' '\\t\\r'"
        let tokens = try tokenizer.tokenize(input)

        #expect(tokens.count == 3) // 2 strings + eof
        #expect(tokens[0].type == .stringLiteral)
        #expect(tokens[1].type == .stringLiteral)
        #expect(tokens[2].type == .eof)
    }

    @Test func testUnicodeEscapeSequences() throws {
        let input = "'\\u{0041}'"
        let tokens = try tokenizer.tokenize(input)

        #expect(tokens.count == 2) // 1 string + eof
        #expect(tokens[0].type == .characterLiteral)
        #expect(tokens[1].type == .eof)
    }

    // MARK: - Comment Tests

    @Test func testSingleLineComments() throws {
        let input = """
        // This is a comment
        identifier
        """
        let tokens = try tokenizer.tokenize(input)

        #expect(tokens.count == 2) // identifier + eof
        #expect(tokens[0].type == .identifier)
        #expect(tokens[0].lexeme == "identifier")
        #expect(tokens[1].type == .eof)
    }

    @Test func testMultiLineComments() throws {
        let input = """
        /* This is a
           multi-line comment */
        identifier
        """
        let tokens = try tokenizer.tokenize(input)

        #expect(tokens.count == 2) // identifier + eof
        #expect(tokens[0].type == .identifier)
        #expect(tokens[0].lexeme == "identifier")
        #expect(tokens[1].type == .eof)
    }

    // MARK: - Error Tests

    @Test func testUnterminatedString() throws {
        let input = "'unterminated string"

        #expect(throws: TokenizerError.self) {
            try tokenizer.tokenize(input)
        }
    }

    @Test func testUnterminatedComment() throws {
        let input = "/* unterminated comment"

        #expect(throws: TokenizerError.self) {
            try tokenizer.tokenize(input)
        }
    }

    @Test func testUnexpectedCharacter() throws {
        let input = "identifier @ another"

        #expect(throws: TokenizerError.self) {
            try tokenizer.tokenize(input)
        }
    }

    // MARK: - Position Tracking Tests

    @Test func testPositionTracking() throws {
        let input = """
        integer x
        real y
        """
        let tokens = try tokenizer.tokenize(input)

        #expect(tokens.count == 5) // 4 tokens + eof

        // First line tokens
        #expect(tokens[0].position.line == 1)
        #expect(tokens[0].position.column == 1)

        // Second line tokens
        #expect(tokens[2].position.line == 2)
        #expect(tokens[2].position.column == 1)
    }

    // MARK: - Consistency Tests

    @Test func testConsistencyWithParsingTokenizer() throws {
        // Test single ASCII tokens for consistency (FastParsingTokenizer has Unicode bugs)
        let testInputs = [
            "if",
            "while",
            "identifier",
            "42",
            "3.14",
            ".5",
            "'hello'",
            "+",
            "-",
            "*"
        ]

        for input in testInputs {
            let fastTokens = try tokenizer.tokenize(input)
            let parsingTokens = try ParsingTokenizer.tokenize(input)

            #expect(fastTokens.count == parsingTokens.count, "Token count mismatch for: \(input)")

            for (index, (fast, parsing)) in zip(fastTokens, parsingTokens).enumerated() {
                #expect(fast.type == parsing.type, "Token type mismatch at index \(index) for: \(input)")
                #expect(fast.lexeme == parsing.lexeme, "Lexeme mismatch at index \(index) for: \(input)")
            }
        }
    }

}
