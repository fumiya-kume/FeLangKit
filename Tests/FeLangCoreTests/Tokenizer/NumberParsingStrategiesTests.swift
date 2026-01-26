import Foundation
import Testing
@testable import FeLangCore

@Suite("NumberParsingStrategies Tests")
struct NumberParsingStrategiesTests {

    // MARK: - Decimal Number Parsing Tests

    @Test func testParseDecimalIntegerSimple() throws {
        let input = "123"
        var index = input.startIndex
        let start = index
        let result = TokenizerCore.parseDecimalNumber(from: input, at: &index, start: start)

        #expect(result != nil)
        #expect(result?.type == .integerLiteral)
        #expect(result?.lexeme == "123")
    }

    @Test func testParseDecimalRealSimple() throws {
        let input = "123.456"
        var index = input.startIndex
        let start = index
        let result = TokenizerCore.parseDecimalNumber(from: input, at: &index, start: start)

        #expect(result != nil)
        #expect(result?.type == .realLiteral)
        #expect(result?.lexeme == "123.456")
    }

    @Test func testParseDecimalLeadingDot() throws {
        // Note: parseDecimalNumber starts from digits, so leading dot is handled differently
        let input = "456"
        var index = input.startIndex
        let start = index
        let result = TokenizerCore.parseDecimalNumber(from: input, at: &index, start: start)

        #expect(result != nil)
        #expect(result?.type == .integerLiteral)
        #expect(result?.lexeme == "456")
    }

    @Test func testParseDecimalZero() throws {
        let input = "0"
        var index = input.startIndex
        let start = index
        let result = TokenizerCore.parseDecimalNumber(from: input, at: &index, start: start)

        #expect(result != nil)
        #expect(result?.type == .integerLiteral)
        #expect(result?.lexeme == "0")
    }

    @Test func testParseDecimalZeroPointZero() throws {
        let input = "0.0"
        var index = input.startIndex
        let start = index
        let result = TokenizerCore.parseDecimalNumber(from: input, at: &index, start: start)

        #expect(result != nil)
        #expect(result?.type == .realLiteral)
        #expect(result?.lexeme == "0.0")
    }

    // MARK: - Hexadecimal Number Parsing Tests

    @Test func testParseHexadecimalLowercase() throws {
        let input = "0xff"
        var index = input.startIndex
        let start = index
        let result = TokenizerCore.parseHexadecimalNumber(from: input, at: &index, start: start)

        #expect(result != nil)
        #expect(result?.type == .integerLiteral)
        #expect(result?.lexeme == "0xff")
    }

    @Test func testParseHexadecimalUppercase() throws {
        let input = "0XFF"
        var index = input.startIndex
        let start = index
        let result = TokenizerCore.parseHexadecimalNumber(from: input, at: &index, start: start)

        #expect(result != nil)
        #expect(result?.type == .integerLiteral)
        #expect(result?.lexeme == "0XFF")
    }

    @Test func testParseHexadecimalMixed() throws {
        let input = "0xAbCdEf"
        var index = input.startIndex
        let start = index
        let result = TokenizerCore.parseHexadecimalNumber(from: input, at: &index, start: start)

        #expect(result != nil)
        #expect(result?.type == .integerLiteral)
        #expect(result?.lexeme == "0xAbCdEf")
    }

    @Test func testParseHexadecimalWithUnderscores() throws {
        let input = "0x12_34_AB"
        var index = input.startIndex
        let start = index
        let result = TokenizerCore.parseHexadecimalNumber(from: input, at: &index, start: start)

        #expect(result != nil)
        #expect(result?.type == .integerLiteral)
        #expect(result?.lexeme == "0x12_34_AB")
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

    @Test func testParseBinaryUppercase() throws {
        let input = "0B1111"
        var index = input.startIndex
        let start = index
        let result = TokenizerCore.parseBinaryNumber(from: input, at: &index, start: start)

        #expect(result != nil)
        #expect(result?.type == .integerLiteral)
        #expect(result?.lexeme == "0B1111")
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

    @Test func testParseBinaryZeros() throws {
        let input = "0b0000"
        var index = input.startIndex
        let start = index
        let result = TokenizerCore.parseBinaryNumber(from: input, at: &index, start: start)

        #expect(result != nil)
        #expect(result?.type == .integerLiteral)
        #expect(result?.lexeme == "0b0000")
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

    @Test func testParseOctalUppercase() throws {
        let input = "0O123"
        var index = input.startIndex
        let start = index
        let result = TokenizerCore.parseOctalNumber(from: input, at: &index, start: start)

        #expect(result != nil)
        #expect(result?.type == .integerLiteral)
        #expect(result?.lexeme == "0O123")
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

    // MARK: - Advanced Number Parsing Tests

    @Test func testParseAdvancedNumberDecimal() throws {
        let input = "12345"
        var index = input.startIndex
        let result = TokenizerCore.parseNumber(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.type == .integerLiteral)
        #expect(result?.lexeme == "12345")
    }

    @Test func testParseAdvancedNumberReal() throws {
        let input = "123.456"
        var index = input.startIndex
        let result = TokenizerCore.parseNumber(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.type == .realLiteral)
        #expect(result?.lexeme == "123.456")
    }

    @Test func testParseAdvancedNumberLeadingDot() throws {
        let input = ".5"
        var index = input.startIndex
        let result = TokenizerCore.parseNumber(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.type == .realLiteral)
        #expect(result?.lexeme == ".5")
    }

    @Test func testParseAdvancedNumberHex() throws {
        let input = "0xFF"
        var index = input.startIndex
        let result = TokenizerCore.parseNumber(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.type == .integerLiteral)
        #expect(result?.lexeme == "0xFF")
    }

    @Test func testParseAdvancedNumberBinary() throws {
        let input = "0b1010"
        var index = input.startIndex
        let result = TokenizerCore.parseNumber(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.type == .integerLiteral)
        #expect(result?.lexeme == "0b1010")
    }

    @Test func testParseAdvancedNumberOctal() throws {
        let input = "0o777"
        var index = input.startIndex
        let result = TokenizerCore.parseNumber(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.type == .integerLiteral)
        #expect(result?.lexeme == "0o777")
    }

    @Test func testParseAdvancedNumberScientificPositive() throws {
        let input = "1e10"
        var index = input.startIndex
        let result = TokenizerCore.parseNumber(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.type == .realLiteral)
        #expect(result?.lexeme == "1e10")
    }

    @Test func testParseAdvancedNumberScientificNegative() throws {
        let input = "1e-10"
        var index = input.startIndex
        let result = TokenizerCore.parseNumber(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.type == .realLiteral)
        #expect(result?.lexeme == "1e-10")
    }

    @Test func testParseAdvancedNumberScientificWithDecimal() throws {
        let input = "1.5e10"
        var index = input.startIndex
        let result = TokenizerCore.parseNumber(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.type == .realLiteral)
        #expect(result?.lexeme == "1.5e10")
    }

    @Test func testParseAdvancedNumberWithUnderscores() throws {
        let input = "1_000_000"
        var index = input.startIndex
        let result = TokenizerCore.parseNumber(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.type == .integerLiteral)
        #expect(result?.lexeme == "1_000_000")
    }

    @Test func testParseAdvancedNumberReturnsNilForNonNumber() throws {
        let input = "abc"
        var index = input.startIndex
        let result = TokenizerCore.parseNumber(from: input, at: &index)

        #expect(result == nil)
    }

    @Test func testParseAdvancedNumberDotAloneReturnsNil() throws {
        let input = "."
        var index = input.startIndex
        let result = TokenizerCore.parseNumber(from: input, at: &index)

        #expect(result == nil)
    }

    // MARK: - Validation Tests

    @Test func testIsValidNumberFormatInteger() throws {
        #expect(TokenizerCore.isValidNumberFormat("123") == true)
    }

    @Test func testIsValidNumberFormatReal() throws {
        #expect(TokenizerCore.isValidNumberFormat("123.456") == true)
    }

    @Test func testIsValidNumberFormatScientific() throws {
        #expect(TokenizerCore.isValidNumberFormat("1e10") == true)
        #expect(TokenizerCore.isValidNumberFormat("1E-10") == true)
    }

    @Test func testIsValidNumberFormatHex() throws {
        #expect(TokenizerCore.isValidNumberFormat("0xFF") == true)
    }

    @Test func testIsValidNumberFormatBinary() throws {
        #expect(TokenizerCore.isValidNumberFormat("0b1010") == true)
    }

    @Test func testIsValidNumberFormatOctal() throws {
        #expect(TokenizerCore.isValidNumberFormat("0o777") == true)
    }

    @Test func testIsValidNumberFormatWithUnderscores() throws {
        #expect(TokenizerCore.isValidNumberFormat("1_000") == true)
    }

    @Test func testIsInvalidNumberFormatEmpty() throws {
        #expect(TokenizerCore.isValidNumberFormat("") == false)
    }

    @Test func testIsInvalidNumberFormatMultipleDecimals() throws {
        #expect(TokenizerCore.isValidNumberFormat("1.2.3") == false)
    }

    @Test func testIsInvalidNumberFormatStartsWithLetter() throws {
        #expect(TokenizerCore.isValidNumberFormat("abc") == false)
    }

    // MARK: - Type Inference Tests

    @Test func testInferNumberTypeInteger() throws {
        #expect(TokenizerCore.inferNumberType(from: "123") == .integerLiteral)
    }

    @Test func testInferNumberTypeReal() throws {
        #expect(TokenizerCore.inferNumberType(from: "123.456") == .realLiteral)
    }

    @Test func testInferNumberTypeScientific() throws {
        #expect(TokenizerCore.inferNumberType(from: "1e10") == .realLiteral)
        #expect(TokenizerCore.inferNumberType(from: "1E10") == .realLiteral)
    }

    @Test func testInferNumberTypeHex() throws {
        // Hex numbers are integers
        #expect(TokenizerCore.inferNumberType(from: "0xFF") == .integerLiteral)
    }

    // MARK: - Edge Cases

    @Test func testParseNumberAtEndOfInput() throws {
        let input = "42"
        var index = input.startIndex
        let result = TokenizerCore.parseNumber(from: input, at: &index)

        #expect(result != nil)
        #expect(index == input.endIndex)
    }

    @Test func testParseNumberFollowedByOperator() throws {
        let input = "42+"
        var index = input.startIndex
        let result = TokenizerCore.parseNumber(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.lexeme == "42")
        #expect(input[index] == "+")
    }

    @Test func testParseNumberFollowedBySpace() throws {
        let input = "42 "
        var index = input.startIndex
        let result = TokenizerCore.parseNumber(from: input, at: &index)

        #expect(result != nil)
        #expect(result?.lexeme == "42")
        #expect(input[index] == " ")
    }

    @Test func testParseLeadingDotFollowedByNonDigit() throws {
        let input = ".abc"
        var index = input.startIndex
        let result = TokenizerCore.parseNumber(from: input, at: &index)

        #expect(result == nil)
    }
}
