import Foundation
import Testing
@testable import FeLangCore

@Suite("TokenizerUtilities Tests")
struct TokenizerUtilitiesTests {

    // MARK: - Keyword Map Tests

    @Test func testKeywordMapContainsIfKeyword() throws {
        #expect(TokenizerUtilities.keywordMap["if"] == .ifKeyword)
    }

    @Test func testKeywordMapContainsWhileKeyword() throws {
        #expect(TokenizerUtilities.keywordMap["while"] == .whileKeyword)
    }

    @Test func testKeywordMapContainsForKeyword() throws {
        #expect(TokenizerUtilities.keywordMap["for"] == .forKeyword)
    }

    @Test func testKeywordMapContainsJapaneseKeyword() throws {
        #expect(TokenizerUtilities.keywordMap["整数型"] == .integerType)
    }

    @Test func testKeywordMapReturnsNilForUnknownKeyword() throws {
        #expect(TokenizerUtilities.keywordMap["unknown"] == nil)
    }

    // MARK: - Whitespace Tests

    @Test func testIsWhitespaceSpace() throws {
        let space: UnicodeScalar = " "
        #expect(TokenizerUtilities.isWhitespace(space) == true)
    }

    @Test func testIsWhitespaceTab() throws {
        let tab: UnicodeScalar = "\t"
        #expect(TokenizerUtilities.isWhitespace(tab) == true)
    }

    @Test func testIsWhitespaceFullWidthSpace() throws {
        let fullWidthSpace: UnicodeScalar = "\u{3000}"
        #expect(TokenizerUtilities.isWhitespace(fullWidthSpace) == true)
    }

    @Test func testIsWhitespaceCharacter() throws {
        #expect(TokenizerUtilities.isWhitespace(Character(" ")) == true)
        #expect(TokenizerUtilities.isWhitespace(Character("\t")) == true)
    }

    @Test func testIsNotWhitespaceNewline() throws {
        let newline: UnicodeScalar = "\n"
        #expect(TokenizerUtilities.isWhitespace(newline) == false)
    }

    @Test func testIsNotWhitespaceLetter() throws {
        let letter: UnicodeScalar = "a"
        #expect(TokenizerUtilities.isWhitespace(letter) == false)
    }

    // MARK: - Identifier Start Tests

    @Test func testIsIdentifierStartLetter() throws {
        #expect(TokenizerUtilities.isIdentifierStart(Character("a")) == true)
        #expect(TokenizerUtilities.isIdentifierStart(Character("Z")) == true)
    }

    @Test func testIsIdentifierStartUnderscore() throws {
        #expect(TokenizerUtilities.isIdentifierStart(Character("_")) == true)
    }

    @Test func testIsIdentifierStartJapaneseHiragana() throws {
        #expect(TokenizerUtilities.isIdentifierStart(Character("あ")) == true)
    }

    @Test func testIsIdentifierStartJapaneseKatakana() throws {
        #expect(TokenizerUtilities.isIdentifierStart(Character("ア")) == true)
    }

    @Test func testIsIdentifierStartJapaneseKanji() throws {
        #expect(TokenizerUtilities.isIdentifierStart(Character("変")) == true)
    }

    @Test func testIsIdentifierStartNotDigit() throws {
        #expect(TokenizerUtilities.isIdentifierStart(Character("5")) == false)
    }

    @Test func testIsIdentifierStartNotOperator() throws {
        #expect(TokenizerUtilities.isIdentifierStart(Character("+")) == false)
    }

    // MARK: - Identifier Continue Tests

    @Test func testIsIdentifierContinueLetter() throws {
        #expect(TokenizerUtilities.isIdentifierContinue(Character("a")) == true)
        #expect(TokenizerUtilities.isIdentifierContinue(Character("Z")) == true)
    }

    @Test func testIsIdentifierContinueUnderscore() throws {
        #expect(TokenizerUtilities.isIdentifierContinue(Character("_")) == true)
    }

    @Test func testIsIdentifierContinueDigit() throws {
        #expect(TokenizerUtilities.isIdentifierContinue(Character("5")) == true)
    }

    @Test func testIsIdentifierContinueNotOperator() throws {
        #expect(TokenizerUtilities.isIdentifierContinue(Character("+")) == false)
    }

    // MARK: - Japanese Character Tests

    @Test func testIsJapaneseCharacterHiragana() throws {
        #expect(TokenizerUtilities.isJapaneseCharacter(Character("あ")) == true)
        #expect(TokenizerUtilities.isJapaneseCharacter(Character("ん")) == true)
    }

    @Test func testIsJapaneseCharacterKatakana() throws {
        #expect(TokenizerUtilities.isJapaneseCharacter(Character("ア")) == true)
        #expect(TokenizerUtilities.isJapaneseCharacter(Character("ン")) == true)
    }

    @Test func testIsJapaneseCharacterKanji() throws {
        #expect(TokenizerUtilities.isJapaneseCharacter(Character("漢")) == true)
        #expect(TokenizerUtilities.isJapaneseCharacter(Character("字")) == true)
    }

    @Test func testIsJapaneseCharacterNotAscii() throws {
        #expect(TokenizerUtilities.isJapaneseCharacter(Character("a")) == false)
        #expect(TokenizerUtilities.isJapaneseCharacter(Character("1")) == false)
    }

    // MARK: - String Matching Tests

    @Test func testMatchStringAtStart() throws {
        let input = "hello world"
        let result = TokenizerUtilities.matchString("hello", in: input, at: input.startIndex)
        #expect(result == true)
    }

    @Test func testMatchStringAtMiddle() throws {
        let input = "hello world"
        let index = input.index(input.startIndex, offsetBy: 6)
        let result = TokenizerUtilities.matchString("world", in: input, at: index)
        #expect(result == true)
    }

    @Test func testMatchStringNoMatch() throws {
        let input = "hello world"
        let result = TokenizerUtilities.matchString("foo", in: input, at: input.startIndex)
        #expect(result == false)
    }

    @Test func testMatchStringTooLong() throws {
        let input = "hi"
        let result = TokenizerUtilities.matchString("hello", in: input, at: input.startIndex)
        #expect(result == false)
    }

    // MARK: - Hex Digit Tests

    @Test func testIsHexDigitNumber() throws {
        for digit in "0123456789".unicodeScalars {
            #expect(TokenizerUtilities.isHexDigit(digit) == true)
        }
    }

    @Test func testIsHexDigitUppercase() throws {
        for digit in "ABCDEF".unicodeScalars {
            #expect(TokenizerUtilities.isHexDigit(digit) == true)
        }
    }

    @Test func testIsHexDigitLowercase() throws {
        for digit in "abcdef".unicodeScalars {
            #expect(TokenizerUtilities.isHexDigit(digit) == true)
        }
    }

    @Test func testIsNotHexDigit() throws {
        for digit in "ghijklmnopqrstuvwxyz".unicodeScalars {
            #expect(TokenizerUtilities.isHexDigit(digit) == false)
        }
    }

    // MARK: - Binary Digit Tests

    @Test func testIsBinaryDigitZero() throws {
        #expect(TokenizerUtilities.isBinaryDigit("0") == true)
    }

    @Test func testIsBinaryDigitOne() throws {
        #expect(TokenizerUtilities.isBinaryDigit("1") == true)
    }

    @Test func testIsNotBinaryDigit() throws {
        #expect(TokenizerUtilities.isBinaryDigit("2") == false)
        #expect(TokenizerUtilities.isBinaryDigit("9") == false)
        #expect(TokenizerUtilities.isBinaryDigit("a") == false)
    }

    // MARK: - Octal Digit Tests

    @Test func testIsOctalDigitValid() throws {
        for digit in "01234567".unicodeScalars {
            #expect(TokenizerUtilities.isOctalDigit(digit) == true)
        }
    }

    @Test func testIsNotOctalDigit() throws {
        #expect(TokenizerUtilities.isOctalDigit("8") == false)
        #expect(TokenizerUtilities.isOctalDigit("9") == false)
        #expect(TokenizerUtilities.isOctalDigit("a") == false)
    }

    // MARK: - Token Type Determination Tests

    @Test func testStringLiteralTokenTypeSingleChar() throws {
        #expect(TokenizerUtilities.stringLiteralTokenType(content: "a") == .characterLiteral)
    }

    @Test func testStringLiteralTokenTypeMultipleChars() throws {
        #expect(TokenizerUtilities.stringLiteralTokenType(content: "hello") == .stringLiteral)
    }

    @Test func testNumberTokenTypeInteger() throws {
        #expect(TokenizerUtilities.numberTokenType(hasDecimal: false) == .integerLiteral)
    }

    @Test func testNumberTokenTypeReal() throws {
        #expect(TokenizerUtilities.numberTokenType(hasDecimal: true) == .realLiteral)
    }

    // MARK: - Enhanced Number Token Type Tests

    @Test func testEnhancedNumberTokenTypeScientific() throws {
        #expect(TokenizerUtilities.enhancedNumberTokenType(lexeme: "1e10") == .realLiteral)
        #expect(TokenizerUtilities.enhancedNumberTokenType(lexeme: "1E10") == .realLiteral)
    }

    @Test func testEnhancedNumberTokenTypeHex() throws {
        #expect(TokenizerUtilities.enhancedNumberTokenType(lexeme: "0xFF") == .integerLiteral)
        #expect(TokenizerUtilities.enhancedNumberTokenType(lexeme: "0x123") == .integerLiteral)
    }

    @Test func testEnhancedNumberTokenTypeBinary() throws {
        #expect(TokenizerUtilities.enhancedNumberTokenType(lexeme: "0b1010") == .integerLiteral)
    }

    @Test func testEnhancedNumberTokenTypeOctal() throws {
        #expect(TokenizerUtilities.enhancedNumberTokenType(lexeme: "0o777") == .integerLiteral)
    }

    @Test func testEnhancedNumberTokenTypeDecimal() throws {
        #expect(TokenizerUtilities.enhancedNumberTokenType(lexeme: "3.14") == .realLiteral)
    }

    @Test func testEnhancedNumberTokenTypeInteger() throws {
        #expect(TokenizerUtilities.enhancedNumberTokenType(lexeme: "42") == .integerLiteral)
    }

    // MARK: - Keyword Boundary Validation Tests

    @Test func testIsValidKeywordBoundaryAtEnd() throws {
        let input = "if"
        let result = TokenizerUtilities.isValidKeywordBoundary(in: input, at: input.endIndex)
        #expect(result == true)
    }

    @Test func testIsValidKeywordBoundaryBeforeSpace() throws {
        let input = "if "
        let index = input.index(input.startIndex, offsetBy: 2)
        let result = TokenizerUtilities.isValidKeywordBoundary(in: input, at: index)
        #expect(result == true)
    }

    @Test func testIsNotValidKeywordBoundaryBeforeLetter() throws {
        let input = "iffy"
        let index = input.index(input.startIndex, offsetBy: 2)
        let result = TokenizerUtilities.isValidKeywordBoundary(in: input, at: index)
        #expect(result == false)
    }

    // MARK: - Source Position Calculation Tests

    @Test func testSourcePositionSimple() throws {
        let input = "hello world"
        let position = TokenizerUtilities.sourcePosition(from: input, startIndex: input.startIndex, currentIndex: input.endIndex)
        #expect(position.line == 1)
        #expect(position.column == 12)
    }

    @Test func testSourcePositionWithNewline() throws {
        let input = "hello\nworld"
        let position = TokenizerUtilities.sourcePosition(from: input, startIndex: input.startIndex, currentIndex: input.endIndex)
        #expect(position.line == 2)
        #expect(position.column == 6)
    }

    // MARK: - Number Validation Tests

    @Test func testValidateAndCleanNumberSimple() throws {
        let result = try TokenizerUtilities.validateAndCleanNumber("123")
        #expect(result == "123")
    }

    @Test func testValidateAndCleanNumberWithUnderscores() throws {
        let result = try TokenizerUtilities.validateAndCleanNumber("1_000")
        #expect(result == "1000")
    }

    @Test func testValidateHexadecimalNumberValid() throws {
        #expect(throws: Never.self) {
            try TokenizerUtilities.validateHexadecimalNumber("0xFF")
        }
    }

    @Test func testValidateHexadecimalNumberInvalidPrefix() throws {
        #expect(throws: TokenizerError.self) {
            try TokenizerUtilities.validateHexadecimalNumber("FF")
        }
    }

    @Test func testValidateBinaryNumberValid() throws {
        #expect(throws: Never.self) {
            try TokenizerUtilities.validateBinaryNumber("0b1010")
        }
    }

    @Test func testValidateBinaryNumberInvalidDigit() throws {
        #expect(throws: TokenizerError.self) {
            try TokenizerUtilities.validateBinaryNumber("0b1021")
        }
    }

    @Test func testValidateOctalNumberValid() throws {
        #expect(throws: Never.self) {
            try TokenizerUtilities.validateOctalNumber("0o777")
        }
    }

    @Test func testValidateOctalNumberInvalidDigit() throws {
        #expect(throws: TokenizerError.self) {
            try TokenizerUtilities.validateOctalNumber("0o789")
        }
    }

    // MARK: - Operators Array Tests

    @Test func testOperatorsContainsPlus() throws {
        let hasPlus = TokenizerUtilities.operators.contains { $0.0 == "+" && $0.1 == .plus }
        #expect(hasPlus == true)
    }

    @Test func testOperatorsContainsMinus() throws {
        let hasMinus = TokenizerUtilities.operators.contains { $0.0 == "-" && $0.1 == .minus }
        #expect(hasMinus == true)
    }

    @Test func testOperatorsContainsUnicodeAssign() throws {
        let hasAssign = TokenizerUtilities.operators.contains { $0.0 == "←" && $0.1 == .assign }
        #expect(hasAssign == true)
    }

    // MARK: - Delimiters Array Tests

    @Test func testDelimitersContainsLeftParen() throws {
        let has = TokenizerUtilities.delimiters.contains { $0.0 == "(" && $0.1 == .leftParen }
        #expect(has == true)
    }

    @Test func testDelimitersContainsRightParen() throws {
        let has = TokenizerUtilities.delimiters.contains { $0.0 == ")" && $0.1 == .rightParen }
        #expect(has == true)
    }

    @Test func testDelimitersContainsComma() throws {
        let has = TokenizerUtilities.delimiters.contains { $0.0 == "," && $0.1 == .comma }
        #expect(has == true)
    }

    // MARK: - Scientific Notation Validation Tests

    @Test func testValidateScientificNotationValid() throws {
        #expect(throws: Never.self) {
            try TokenizerUtilities.validateScientificNotation("1e10")
        }
    }

    @Test func testValidateScientificNotationWithSign() throws {
        #expect(throws: Never.self) {
            try TokenizerUtilities.validateScientificNotation("1e+10")
        }
        #expect(throws: Never.self) {
            try TokenizerUtilities.validateScientificNotation("1e-10")
        }
    }

    @Test func testValidateScientificNotationInvalid() throws {
        #expect(throws: TokenizerError.self) {
            try TokenizerUtilities.validateScientificNotation("1ee10")
        }
    }

    // MARK: - UnicodeScalar Extension Tests

    @Test func testUnicodeScalarIsLetter() throws {
        let letter: UnicodeScalar = "a"
        #expect(letter.isLetter == true)
    }

    @Test func testUnicodeScalarIsNumber() throws {
        let digit: UnicodeScalar = "5"
        #expect(digit.isNumber == true)
    }

    @Test func testUnicodeScalarIsWhitespace() throws {
        let space: UnicodeScalar = " "
        #expect(space.isWhitespace == true)
    }

    @Test func testUnicodeScalarIsUppercase() throws {
        let upper: UnicodeScalar = "A"
        let lower: UnicodeScalar = "a"
        #expect(upper.isUppercase == true)
        #expect(lower.isUppercase == false)
    }

    @Test func testUnicodeScalarIsLowercase() throws {
        let upper: UnicodeScalar = "A"
        let lower: UnicodeScalar = "a"
        #expect(lower.isLowercase == true)
        #expect(upper.isLowercase == false)
    }
}
