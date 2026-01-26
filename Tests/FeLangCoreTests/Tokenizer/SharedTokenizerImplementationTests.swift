import Foundation
import Testing
@testable import FeLangCore

@Suite("TokenizerCore Tests")
struct TokenizerCoreTests {

    // MARK: - Keyword and Identifier Parsing Tests

    @Test func testParseKeywordOrIdentifierWithKeyword() throws {
        let input = "if"
        var index = input.startIndex
        let result = TokenizerCore.parseKeywordOrIdentifier(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.type == .ifKeyword)
        #expect(result?.lexeme == "if")
        #expect(index == input.endIndex)
    }

    @Test func testParseKeywordOrIdentifierWithIdentifier() throws {
        let input = "myVariable"
        var index = input.startIndex
        let result = TokenizerCore.parseKeywordOrIdentifier(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.type == .identifier)
        #expect(result?.lexeme == "myVariable")
        #expect(index == input.endIndex)
    }

    @Test func testParseKeywordOrIdentifierWithUnderscore() throws {
        let input = "_privateVar"
        var index = input.startIndex
        let result = TokenizerCore.parseKeywordOrIdentifier(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.type == .identifier)
        #expect(result?.lexeme == "_privateVar")
    }

    @Test func testParseKeywordOrIdentifierWithNumbers() throws {
        let input = "var123"
        var index = input.startIndex
        let result = TokenizerCore.parseKeywordOrIdentifier(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.type == .identifier)
        #expect(result?.lexeme == "var123")
    }

    @Test func testParseKeywordOrIdentifierReturnsNilForNumber() throws {
        let input = "123abc"
        var index = input.startIndex
        let result = TokenizerCore.parseKeywordOrIdentifier(from: input, at: &index)

        #expect(result == nil)
        #expect(index == input.startIndex)
    }

    @Test func testParseKeywordOnly() throws {
        let input = "while"
        var index = input.startIndex
        let result = TokenizerCore.parseKeyword(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.type == .whileKeyword)
        #expect(result?.lexeme == "while")
    }

    @Test func testParseKeywordResetsIndexForIdentifier() throws {
        let input = "notAKeyword"
        var index = input.startIndex
        let startIndex = index
        let result = TokenizerCore.parseKeyword(from: input, at: &index)

        #expect(result == nil)
        #expect(index == startIndex)
    }

    @Test func testParseIdentifierOnly() throws {
        let input = "variableName"
        var index = input.startIndex
        let result = TokenizerCore.parseIdentifier(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.type == .identifier)
        #expect(result?.lexeme == "variableName")
    }

    // MARK: - Operator Parsing Tests

    @Test func testParseOperatorPlus() throws {
        let input = "+"
        var index = input.startIndex
        let result = TokenizerCore.parseOperator(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.type == .plus)
        #expect(result?.lexeme == "+")
    }

    @Test func testParseOperatorMinus() throws {
        let input = "-"
        var index = input.startIndex
        let result = TokenizerCore.parseOperator(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.type == .minus)
        #expect(result?.lexeme == "-")
    }

    @Test func testParseOperatorMultiply() throws {
        let input = "*"
        var index = input.startIndex
        let result = TokenizerCore.parseOperator(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.type == .multiply)
        #expect(result?.lexeme == "*")
    }

    @Test func testParseOperatorDivide() throws {
        let input = "/"
        var index = input.startIndex
        let result = TokenizerCore.parseOperator(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.type == .divide)
        #expect(result?.lexeme == "/")
    }

    @Test func testParseOperatorModulo() throws {
        let input = "%"
        var index = input.startIndex
        let result = TokenizerCore.parseOperator(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.type == .modulo)
        #expect(result?.lexeme == "%")
    }

    @Test func testParseOperatorEqual() throws {
        let input = "="
        var index = input.startIndex
        let result = TokenizerCore.parseOperator(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.type == .equal)
        #expect(result?.lexeme == "=")
    }

    // MARK: - Delimiter Parsing Tests

    @Test func testParseDelimiterLeftParen() throws {
        let input = "("
        var index = input.startIndex
        let result = TokenizerCore.parseDelimiter(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.type == .leftParen)
        #expect(result?.lexeme == "(")
    }

    @Test func testParseDelimiterRightParen() throws {
        let input = ")"
        var index = input.startIndex
        let result = TokenizerCore.parseDelimiter(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.type == .rightParen)
        #expect(result?.lexeme == ")")
    }

    @Test func testParseDelimiterLeftBracket() throws {
        let input = "["
        var index = input.startIndex
        let result = TokenizerCore.parseDelimiter(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.type == .leftBracket)
        #expect(result?.lexeme == "[")
    }

    @Test func testParseDelimiterComma() throws {
        let input = ","
        var index = input.startIndex
        let result = TokenizerCore.parseDelimiter(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.type == .comma)
        #expect(result?.lexeme == ",")
    }

    @Test func testParseDelimiterSemicolon() throws {
        let input = ";"
        var index = input.startIndex
        let result = TokenizerCore.parseDelimiter(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.type == .semicolon)
        #expect(result?.lexeme == ";")
    }

    @Test func testParseDelimiterColon() throws {
        let input = ":"
        var index = input.startIndex
        let result = TokenizerCore.parseDelimiter(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.type == .colon)
        #expect(result?.lexeme == ":")
    }

    // MARK: - Number Parsing Tests

    @Test func testParseNumberInteger() throws {
        let input = "42"
        var index = input.startIndex
        let result = TokenizerCore.parseNumber(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.type == .integerLiteral)
        #expect(result?.lexeme == "42")
    }

    @Test func testParseNumberReal() throws {
        let input = "3.14"
        var index = input.startIndex
        let result = TokenizerCore.parseNumber(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.type == .realLiteral)
        #expect(result?.lexeme == "3.14")
    }

    @Test func testParseNumberLeadingDot() throws {
        let input = ".5"
        var index = input.startIndex
        let result = TokenizerCore.parseNumber(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.type == .realLiteral)
        #expect(result?.lexeme == ".5")
    }

    @Test func testParseNumberHexadecimal() throws {
        let input = "0xFF"
        var index = input.startIndex
        let result = TokenizerCore.parseNumber(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.type == .integerLiteral)
        #expect(result?.lexeme == "0xFF")
    }

    @Test func testParseNumberBinary() throws {
        let input = "0b1010"
        var index = input.startIndex
        let result = TokenizerCore.parseNumber(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.type == .integerLiteral)
        #expect(result?.lexeme == "0b1010")
    }

    @Test func testParseNumberOctal() throws {
        let input = "0o777"
        var index = input.startIndex
        let result = TokenizerCore.parseNumber(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.type == .integerLiteral)
        #expect(result?.lexeme == "0o777")
    }

    @Test func testParseNumberWithUnderscores() throws {
        let input = "1_000_000"
        var index = input.startIndex
        let result = TokenizerCore.parseNumber(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.type == .integerLiteral)
        #expect(result?.lexeme == "1_000_000")
    }

    @Test func testParseNumberScientificNotationPositive() throws {
        let input = "1.5e10"
        var index = input.startIndex
        let result = TokenizerCore.parseNumber(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.type == .realLiteral)
        #expect(result?.lexeme == "1.5e10")
    }

    @Test func testParseNumberScientificNotationNegative() throws {
        let input = "1.5e-10"
        var index = input.startIndex
        let result = TokenizerCore.parseNumber(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.type == .realLiteral)
        #expect(result?.lexeme == "1.5e-10")
    }

    @Test func testParseNumberReturnsNilForNonNumber() throws {
        let input = "abc"
        var index = input.startIndex
        let result = TokenizerCore.parseNumber(from: input, at: &index)

        #expect(result == nil)
    }

    @Test func testParseNumberDotAloneReturnsNil() throws {
        let input = "."
        var index = input.startIndex
        let result = TokenizerCore.parseNumber(from: input, at: &index)

        #expect(result == nil)
    }

    // MARK: - String Literal Parsing Tests

    @Test func testParseStringLiteralSimple() throws {
        let input = "'hello'"
        var index = input.startIndex
        let result = TokenizerCore.parseStringLiteral(from: input, at: &index, quoteChar: "'")

        switch result {
        case .success(let token):
            #expect(token.lexeme == "'hello'")
        case .failure:
            Issue.record("Expected successful parsing")
        }
    }

    @Test func testParseStringLiteralWithEscapeN() throws {
        let input = "'hello\\nworld'"
        var index = input.startIndex
        let result = TokenizerCore.parseStringLiteral(from: input, at: &index, quoteChar: "'")

        switch result {
        case .success(let token):
            #expect(token.lexeme == "'hello\\nworld'")
        case .failure:
            Issue.record("Expected successful parsing")
        }
    }

    @Test func testParseStringLiteralWithEscapeT() throws {
        let input = "'hello\\tworld'"
        var index = input.startIndex
        let result = TokenizerCore.parseStringLiteral(from: input, at: &index, quoteChar: "'")

        switch result {
        case .success(let token):
            #expect(token.lexeme == "'hello\\tworld'")
        case .failure:
            Issue.record("Expected successful parsing")
        }
    }

    @Test func testParseStringLiteralUnterminated() throws {
        let input = "'hello"
        var index = input.startIndex
        let result = TokenizerCore.parseStringLiteral(from: input, at: &index, quoteChar: "'")

        switch result {
        case .success:
            Issue.record("Expected failure for unterminated string")
        case .failure(let error):
            if case .unterminatedString = error {
                // Success
            } else {
                Issue.record("Expected unterminatedString error")
            }
        }
    }

    // MARK: - Whitespace Handling Tests

    @Test func testSkipWhitespaceSpaces() throws {
        let input = "   abc"
        var index = input.startIndex
        TokenizerCore.skipWhitespace(from: input, at: &index)

        #expect(input[index] == "a")
    }

    @Test func testSkipWhitespaceTabs() throws {
        let input = "\t\tabc"
        var index = input.startIndex
        TokenizerCore.skipWhitespace(from: input, at: &index)

        #expect(input[index] == "a")
    }

    @Test func testSkipWhitespaceNewlinesNotSkipped() throws {
        // Note: TokenizerUtilities.isWhitespace does NOT consider newlines as whitespace
        let input = "\n\nabc"
        var index = input.startIndex
        TokenizerCore.skipWhitespace(from: input, at: &index)

        // Newlines are NOT skipped
        #expect(input[index] == "\n")
    }

    @Test func testSkipWhitespaceMixed() throws {
        // Note: TokenizerUtilities.isWhitespace only considers space, tab, and full-width space
        let input = " \t  abc"
        var index = input.startIndex
        TokenizerCore.skipWhitespace(from: input, at: &index)

        #expect(input[index] == "a")
    }

    // MARK: - Comment Handling Tests

    @Test func testSkipSingleLineComment() throws {
        let input = "// comment\nabc"
        var index = input.index(input.startIndex, offsetBy: 2) // Skip the "//"
        TokenizerCore.skipSingleLineComment(from: input, at: &index)

        #expect(input[index] == "\n")
    }

    @Test func testSkipMultiLineCommentSimple() throws {
        let input = "/* comment */abc"
        var index = input.startIndex
        let result = TokenizerCore.skipMultiLineComment(from: input, at: &index)

        switch result {
        case .success:
            #expect(input[index] == "a")
        case .failure:
            Issue.record("Expected successful comment parsing")
        }
    }

    @Test func testSkipMultiLineCommentNested() throws {
        let input = "/* outer /* inner */ outer */abc"
        var index = input.startIndex
        let result = TokenizerCore.skipMultiLineComment(from: input, at: &index)

        switch result {
        case .success:
            #expect(input[index] == "a")
        case .failure:
            Issue.record("Expected successful nested comment parsing")
        }
    }

    @Test func testSkipMultiLineCommentUnterminated() throws {
        let input = "/* unterminated"
        var index = input.startIndex
        let result = TokenizerCore.skipMultiLineComment(from: input, at: &index)

        switch result {
        case .success:
            Issue.record("Expected failure for unterminated comment")
        case .failure(let error):
            if case .unterminatedComment = error {
                // Success
            } else {
                Issue.record("Expected unterminatedComment error")
            }
        }
    }

    // MARK: - Number Parsing with Validation Tests

    @Test func testParseNumberWithValidationInteger() throws {
        let input = "123"
        var index = input.startIndex
        let result = TokenizerCore.parseNumberWithValidation(from: input, at: &index)

        switch result {
        case .success(let token):
            #expect(token.type == .integerLiteral)
            #expect(token.lexeme == "123")
        case .failure:
            Issue.record("Expected successful parsing")
        }
    }

    @Test func testParseNumberWithValidationReal() throws {
        let input = "123.456"
        var index = input.startIndex
        let result = TokenizerCore.parseNumberWithValidation(from: input, at: &index)

        switch result {
        case .success(let token):
            #expect(token.type == .realLiteral)
            #expect(token.lexeme == "123.456")
        case .failure:
            Issue.record("Expected successful parsing")
        }
    }

    @Test func testParseNumberWithValidationLeadingDot() throws {
        let input = ".5"
        var index = input.startIndex
        let result = TokenizerCore.parseNumberWithValidation(from: input, at: &index)

        switch result {
        case .success(let token):
            #expect(token.type == .realLiteral)
            #expect(token.lexeme == ".5")
        case .failure:
            Issue.record("Expected successful parsing")
        }
    }

    // MARK: - Hexadecimal Number Parsing Tests

    @Test func testParseHexadecimalLowercase() throws {
        let input = "0xabcdef"
        var index = input.startIndex
        let start = index
        let result = TokenizerCore.parseHexadecimalNumber(from: input, at: &index, start: start)

        #expect(result != nil)
        #expect(result?.type == .integerLiteral)
        #expect(result?.lexeme == "0xabcdef")
    }

    @Test func testParseHexadecimalUppercase() throws {
        let input = "0xABCDEF"
        var index = input.startIndex
        let start = index
        let result = TokenizerCore.parseHexadecimalNumber(from: input, at: &index, start: start)

        #expect(result != nil)
        #expect(result?.type == .integerLiteral)
        #expect(result?.lexeme == "0xABCDEF")
    }

    @Test func testParseHexadecimalWithUnderscores() throws {
        let input = "0x12_34_AB_CD"
        var index = input.startIndex
        let start = index
        let result = TokenizerCore.parseHexadecimalNumber(from: input, at: &index, start: start)

        #expect(result != nil)
        #expect(result?.type == .integerLiteral)
        #expect(result?.lexeme == "0x12_34_AB_CD")
    }

    // MARK: - Binary Number Parsing Tests

    @Test func testParseBinarySimple() throws {
        let input = "0b1010"
        var index = input.startIndex
        let start = index
        let result = TokenizerCore.parseBinaryNumber(from: input, at: &index, start: start)

        #expect(result != nil)
        #expect(result?.type == .integerLiteral)
        #expect(result?.lexeme == "0b1010")
    }

    @Test func testParseBinaryWithUnderscores() throws {
        let input = "0b1010_1010"
        var index = input.startIndex
        let start = index
        let result = TokenizerCore.parseBinaryNumber(from: input, at: &index, start: start)

        #expect(result != nil)
        #expect(result?.type == .integerLiteral)
        #expect(result?.lexeme == "0b1010_1010")
    }

    // MARK: - Octal Number Parsing Tests

    @Test func testParseOctalSimple() throws {
        let input = "0o777"
        var index = input.startIndex
        let start = index
        let result = TokenizerCore.parseOctalNumber(from: input, at: &index, start: start)

        #expect(result != nil)
        #expect(result?.type == .integerLiteral)
        #expect(result?.lexeme == "0o777")
    }

    @Test func testParseOctalWithUnderscores() throws {
        let input = "0o12_34_56"
        var index = input.startIndex
        let start = index
        let result = TokenizerCore.parseOctalNumber(from: input, at: &index, start: start)

        #expect(result != nil)
        #expect(result?.type == .integerLiteral)
        #expect(result?.lexeme == "0o12_34_56")
    }

    // MARK: - Decimal Number Parsing Tests

    @Test func testParseDecimalInteger() throws {
        let input = "12345"
        var index = input.startIndex
        let start = index
        let result = TokenizerCore.parseDecimalNumber(from: input, at: &index, start: start)

        #expect(result != nil)
        #expect(result?.type == .integerLiteral)
        #expect(result?.lexeme == "12345")
    }

    @Test func testParseDecimalReal() throws {
        let input = "123.456"
        var index = input.startIndex
        let start = index
        let result = TokenizerCore.parseDecimalNumber(from: input, at: &index, start: start)

        #expect(result != nil)
        #expect(result?.type == .realLiteral)
        #expect(result?.lexeme == "123.456")
    }

    @Test func testParseDecimalScientificPositiveExponent() throws {
        let input = "1e10"
        var index = input.startIndex
        let start = index
        let result = TokenizerCore.parseDecimalNumber(from: input, at: &index, start: start)

        #expect(result != nil)
        #expect(result?.type == .realLiteral)
        #expect(result?.lexeme == "1e10")
    }

    @Test func testParseDecimalScientificNegativeExponent() throws {
        let input = "1e-10"
        var index = input.startIndex
        let start = index
        let result = TokenizerCore.parseDecimalNumber(from: input, at: &index, start: start)

        #expect(result != nil)
        #expect(result?.type == .realLiteral)
        #expect(result?.lexeme == "1e-10")
    }

    @Test func testParseDecimalWithUnderscores() throws {
        let input = "1_000_000"
        var index = input.startIndex
        let start = index
        let result = TokenizerCore.parseDecimalNumber(from: input, at: &index, start: start)

        #expect(result != nil)
        #expect(result?.type == .integerLiteral)
        #expect(result?.lexeme == "1_000_000")
    }

    // MARK: - TokenData Tests

    @Test func testTokenDataInitialization() throws {
        let tokenData = TokenizerCore.TokenData(type: .identifier, lexeme: "test")

        #expect(tokenData.type == .identifier)
        #expect(tokenData.lexeme == "test")
    }

    // MARK: - parseBasicNumber Tests

    @Test func testParseBasicNumberInteger() throws {
        let input = "42abc"
        var index = input.startIndex
        let result = TokenizerCore.parseBasicNumber(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.type == .integerLiteral)
        #expect(result?.lexeme == "42")
    }

    @Test func testParseBasicNumberDecimal() throws {
        let input = "3.14rest"
        var index = input.startIndex
        let result = TokenizerCore.parseBasicNumber(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.type == .realLiteral)
        #expect(result?.lexeme == "3.14")
    }

    @Test func testParseBasicNumberLeadingDot() throws {
        let input = ".5rest"
        var index = input.startIndex
        let result = TokenizerCore.parseBasicNumber(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.type == .realLiteral)
        #expect(result?.lexeme == ".5")
    }

    @Test func testParseBasicNumberNotANumber() throws {
        let input = "abc"
        var index = input.startIndex
        let result = TokenizerCore.parseBasicNumber(from: input, at: &index)

        #expect(result == nil)
    }

    // MARK: - parseBasicString Tests

    @Test func testParseBasicStringDoubleQuote() throws {
        let input = "\"hello\"rest"
        var index = input.startIndex
        let result = TokenizerCore.parseBasicString(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.lexeme == "\"hello\"")
    }

    @Test func testParseBasicStringSingleQuote() throws {
        let input = "'a'rest"
        var index = input.startIndex
        let result = TokenizerCore.parseBasicString(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.lexeme == "'a'")
    }

    @Test func testParseBasicStringWithEscapes() throws {
        let input = "\"hello\\nworld\"rest"
        var index = input.startIndex
        let result = TokenizerCore.parseBasicString(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.lexeme == "\"hello\\nworld\"")
    }

    @Test func testParseBasicStringUnterminated() throws {
        let input = "\"unterminated"
        var index = input.startIndex
        let result = TokenizerCore.parseBasicString(from: input, at: &index)

        #expect(result == nil)
    }

    @Test func testParseBasicStringUnknownEscape() throws {
        let input = "\"hello\\xworld\""
        var index = input.startIndex
        let result = TokenizerCore.parseBasicString(from: input, at: &index)

        #expect(result == nil)
        #expect(index == input.startIndex) // index should be reset
    }

    // MARK: - parseComment Tests

    @Test func testParseCommentSingleLine() throws {
        let input = "// single line\nabc"
        var index = input.startIndex
        let result = TokenizerCore.parseComment(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.type == .comment)
        #expect(result?.lexeme == "// single line")
    }

    @Test func testParseCommentMultiLine() throws {
        let input = "/* multi\nline */abc"
        var index = input.startIndex
        let result = TokenizerCore.parseComment(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.type == .comment)
        #expect(result?.lexeme == "/* multi\nline */")
    }

    @Test func testParseCommentMultiLineUnterminated() throws {
        let input = "/* unterminated"
        var index = input.startIndex
        let result = TokenizerCore.parseComment(from: input, at: &index)

        #expect(result == nil)
        #expect(index == input.startIndex) // index should be reset
    }

    @Test func testParseCommentNotAComment() throws {
        let input = "abc"
        var index = input.startIndex
        let result = TokenizerCore.parseComment(from: input, at: &index)

        #expect(result == nil)
    }

    // MARK: - isValidTokenBoundary Tests

    @Test func testIsValidTokenBoundaryAtEnd() throws {
        let input = "abc"
        let result = TokenizerCore.isValidTokenBoundary(in: input, at: input.endIndex)

        #expect(result == true)
    }

    @Test func testIsValidTokenBoundaryBeforeSpace() throws {
        let input = "abc def"
        let index = input.index(input.startIndex, offsetBy: 3) // at space
        let result = TokenizerCore.isValidTokenBoundary(in: input, at: index)

        #expect(result == true)
    }

    @Test func testIsValidTokenBoundaryBeforeIdentifier() throws {
        let input = "abcdef"
        let index = input.index(input.startIndex, offsetBy: 3) // at 'd'
        let result = TokenizerCore.isValidTokenBoundary(in: input, at: index)

        #expect(result == false) // 'd' can continue an identifier
    }

    // MARK: - canStartToken Tests

    @Test func testCanStartTokenWithLetter() throws {
        #expect(TokenizerCore.canStartToken(at: "a") == true)
    }

    @Test func testCanStartTokenWithDigit() throws {
        #expect(TokenizerCore.canStartToken(at: "0") == true)
    }

    @Test func testCanStartTokenWithDot() throws {
        #expect(TokenizerCore.canStartToken(at: ".") == true)
    }

    @Test func testCanStartTokenWithQuote() throws {
        #expect(TokenizerCore.canStartToken(at: "\"") == true)
        #expect(TokenizerCore.canStartToken(at: "'") == true)
    }

    @Test func testCanStartTokenWithSlash() throws {
        #expect(TokenizerCore.canStartToken(at: "/") == true)
    }

    @Test func testCanStartTokenWithSpace() throws {
        #expect(TokenizerCore.canStartToken(at: " ") == false)
    }

    @Test func testCanStartTokenWithNewline() throws {
        #expect(TokenizerCore.canStartToken(at: "\n") == false)
    }
}
