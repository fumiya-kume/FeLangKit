import Foundation
import Testing
@testable import FeLangCore

@Suite("RefactoredParsingTokenizer Tests")
struct RefactoredParsingTokenizerTests {

    private let tokenizer = RefactoredParsingTokenizer()

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

    // MARK: - Keyword Tests

    @Test func testEnglishKeywords() throws {
        let input = "if while for return break true false"
        let tokens = try tokenizer.tokenize(input)

        #expect(tokens.count == 8) // 7 keywords + eof
        #expect(tokens[0].type == .ifKeyword)
        #expect(tokens[1].type == .whileKeyword)
        #expect(tokens[2].type == .forKeyword)
        #expect(tokens[3].type == .returnKeyword)
        #expect(tokens[4].type == .breakKeyword)
        #expect(tokens[5].type == .trueKeyword)
        #expect(tokens[6].type == .falseKeyword)
        #expect(tokens[7].type == .eof)
    }

    @Test func testLogicalKeywords() throws {
        let input = "and or not"
        let tokens = try tokenizer.tokenize(input)

        #expect(tokens.count == 4) // 3 keywords + eof
        #expect(tokens[0].type == .andKeyword)
        #expect(tokens[1].type == .orKeyword)
        #expect(tokens[2].type == .notKeyword)
        #expect(tokens[3].type == .eof)
    }

    // MARK: - Identifier Tests

    @Test func testIdentifiers() throws {
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

    // MARK: - Number Tests

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

    @Test func testHexadecimalLiterals() throws {
        let input = "0xFF 0x123"
        let tokens = try tokenizer.tokenize(input)

        #expect(tokens.count == 3) // 2 hex + eof
        #expect(tokens[0].type == .integerLiteral)
        #expect(tokens[0].lexeme == "0xFF")
        #expect(tokens[1].type == .integerLiteral)
        #expect(tokens[1].lexeme == "0x123")
        #expect(tokens[2].type == .eof)
    }

    @Test func testBinaryLiterals() throws {
        let input = "0b1010 0b0000"
        let tokens = try tokenizer.tokenize(input)

        #expect(tokens.count == 3) // 2 binary + eof
        #expect(tokens[0].type == .integerLiteral)
        #expect(tokens[0].lexeme == "0b1010")
        #expect(tokens[1].type == .integerLiteral)
        #expect(tokens[1].lexeme == "0b0000")
        #expect(tokens[2].type == .eof)
    }

    @Test func testOctalLiterals() throws {
        let input = "0o777 0o123"
        let tokens = try tokenizer.tokenize(input)

        #expect(tokens.count == 3) // 2 octal + eof
        #expect(tokens[0].type == .integerLiteral)
        #expect(tokens[0].lexeme == "0o777")
        #expect(tokens[1].type == .integerLiteral)
        #expect(tokens[1].lexeme == "0o123")
        #expect(tokens[2].type == .eof)
    }

    // MARK: - Operator Tests

    @Test func testBasicOperators() throws {
        let input = "+ - * / %"
        let tokens = try tokenizer.tokenize(input)

        #expect(tokens.count == 6) // 5 operators + eof
        #expect(tokens[0].type == .plus)
        #expect(tokens[1].type == .minus)
        #expect(tokens[2].type == .multiply)
        #expect(tokens[3].type == .divide)
        #expect(tokens[4].type == .modulo)
        #expect(tokens[5].type == .eof)
    }

    @Test func testComparisonOperators() throws {
        let input = "= > <"
        let tokens = try tokenizer.tokenize(input)

        #expect(tokens.count == 4) // 3 operators + eof
        #expect(tokens[0].type == .equal)
        #expect(tokens[1].type == .greater)
        #expect(tokens[2].type == .less)
        #expect(tokens[3].type == .eof)
    }

    // MARK: - Delimiter Tests

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

    @Test func testCharacterLiterals() throws {
        let input = "'a' 'x'"
        let tokens = try tokenizer.tokenize(input)

        #expect(tokens.count == 3) // 2 characters + eof
        #expect(tokens[0].type == .characterLiteral)
        #expect(tokens[0].lexeme == "'a'")
        #expect(tokens[1].type == .characterLiteral)
        #expect(tokens[1].lexeme == "'x'")
        #expect(tokens[2].type == .eof)
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
        if x
        while y
        """
        let tokens = try tokenizer.tokenize(input)

        #expect(tokens.count == 5) // if, x, while, y, eof

        // First line tokens
        #expect(tokens[0].position.line == 1)
        #expect(tokens[0].position.column == 1)

        // Second line tokens
        #expect(tokens[2].position.line == 2)
        #expect(tokens[2].position.column == 1)
    }

    // MARK: - Consistency Tests

    @Test func testConsistencyWithParsingTokenizer() throws {
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
            let refactoredTokens = try tokenizer.tokenize(input)
            let parsingTokens = try ParsingTokenizer.tokenize(input)

            #expect(refactoredTokens.count == parsingTokens.count, "Token count mismatch for: \(input)")

            for (index, (refactored, parsing)) in zip(refactoredTokens, parsingTokens).enumerated() {
                #expect(refactored.type == parsing.type, "Token type mismatch at index \(index) for: \(input)")
                #expect(refactored.lexeme == parsing.lexeme, "Lexeme mismatch at index \(index) for: \(input)")
            }
        }
    }

    // MARK: - Complex Expression Tests

    @Test func testComplexExpression() throws {
        let input = "if (x > 10) { y = x + 1 }"
        let tokens = try tokenizer.tokenize(input)

        let expectedTypes: [TokenType] = [
            .ifKeyword, .leftParen, .identifier, .greater, .integerLiteral,
            .rightParen, .leftBrace, .identifier, .equal, .identifier,
            .plus, .integerLiteral, .rightBrace, .eof
        ]

        #expect(tokens.count == expectedTypes.count)
        for (index, expectedType) in expectedTypes.enumerated() {
            #expect(tokens[index].type == expectedType, "Token type mismatch at index \(index)")
        }
    }
}
