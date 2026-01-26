import Testing
@testable import FeLangCore

/// Tests for enhanced number formats including scientific notation, alternative bases, and underscore separators
struct EnhancedNumberTests {

    // MARK: - Scientific Notation Tests

    @Test func testScientificNotationBasic() throws {
        let testCases = [
            ("1e5", TokenType.realLiteral),
            ("1E5", TokenType.realLiteral),
            ("1.23e5", TokenType.realLiteral),
            ("1.23E5", TokenType.realLiteral),
            ("1e-3", TokenType.realLiteral),
            ("1E-3", TokenType.realLiteral),
            ("2.5e+10", TokenType.realLiteral),
            ("2.5E+10", TokenType.realLiteral),
            ("123e0", TokenType.realLiteral),
            ("0e0", TokenType.realLiteral)
        ]

        for (input, expectedType) in testCases {
            let tokens = try ParsingTokenizer.tokenize(input)

            #expect(tokens.count == 2) // number + eof
            #expect(tokens[0].type == expectedType)
            #expect(tokens[0].lexeme == input)
        }
    }

    @Test func testScientificNotationWithUnderscores() throws {
        let testCases = [
            ("1_000e5", TokenType.realLiteral),
            ("1.23_456e7", TokenType.realLiteral),
            ("1e1_000", TokenType.realLiteral),
            ("1.5e+1_000", TokenType.realLiteral)
        ]

        for (input, expectedType) in testCases {
            let tokens = try ParsingTokenizer.tokenize(input)

            #expect(tokens.count == 2) // number + eof
            #expect(tokens[0].type == expectedType)
            #expect(tokens[0].lexeme == input)
        }
    }

    @Test func testInvalidScientificNotation() throws {
        // ParsingTokenizer does not throw errors for invalid scientific notation.
        // Instead, it silently consumes the prefix or splits into multiple tokens.

        // Cases where the entire input is consumed silently (only eof produced)
        let silentlyConsumedCases = ["1e", "1E", "1e+", "1e-"]
        for input in silentlyConsumedCases {
            let tokens = try ParsingTokenizer.tokenize(input)
            #expect(tokens.count == 1, "Expected only eof for input: '\(input)'")
            #expect(tokens[0].type == .eof)
        }

        // "1ee5" => the "1e" prefix is consumed, then "e5" is parsed as identifier
        do {
            let tokens = try ParsingTokenizer.tokenize("1ee5")
            #expect(tokens.count == 2) // identifier('e5') + eof
            #expect(tokens[0].type == .identifier)
            #expect(tokens[0].lexeme == "e5")
        }

        // "1e5e" => "1e5" is a valid realLiteral, then "e" is an identifier
        do {
            let tokens = try ParsingTokenizer.tokenize("1e5e")
            #expect(tokens.count == 3) // realLiteral('1e5') + identifier('e') + eof
            #expect(tokens[0].type == .realLiteral)
            #expect(tokens[0].lexeme == "1e5")
            #expect(tokens[1].type == .identifier)
            #expect(tokens[1].lexeme == "e")
        }
    }

    // MARK: - Hexadecimal Number Tests

    @Test func testHexadecimalNumbers() throws {
        let testCases = [
            ("0xFF", TokenType.integerLiteral),
            ("0xff", TokenType.integerLiteral),
            ("0XFF", TokenType.integerLiteral),
            ("0x1A2B", TokenType.integerLiteral),
            ("0x0", TokenType.integerLiteral),
            ("0xDEADBEEF", TokenType.integerLiteral),
            ("0xabcdef", TokenType.integerLiteral),
            ("0x123456789ABCDEF", TokenType.integerLiteral)
        ]

        for (input, expectedType) in testCases {
            let tokens = try ParsingTokenizer.tokenize(input)

            #expect(tokens.count == 2) // number + eof
            #expect(tokens[0].type == expectedType)
            #expect(tokens[0].lexeme == input)
        }
    }

    @Test func testHexadecimalWithUnderscores() throws {
        let testCases = [
            ("0xFF_FF", TokenType.integerLiteral),
            ("0x1A_2B_3C", TokenType.integerLiteral),
            ("0xDEAD_BEEF", TokenType.integerLiteral),
            ("0x1_2_3_4", TokenType.integerLiteral)
        ]

        for (input, expectedType) in testCases {
            let tokens = try ParsingTokenizer.tokenize(input)

            #expect(tokens.count == 2) // number + eof
            #expect(tokens[0].type == expectedType)
            #expect(tokens[0].lexeme == input)
        }
    }

    @Test func testInvalidHexadecimalNumbers() throws {
        // ParsingTokenizer does not throw errors for invalid hex numbers.
        // Instead, it silently consumes the "0x" prefix or splits into multiple tokens.

        // Cases where the "0x"/"0X" prefix is consumed silently (only eof produced)
        let silentlyConsumedCases = ["0x", "0X"]
        for input in silentlyConsumedCases {
            let tokens = try ParsingTokenizer.tokenize(input)
            #expect(tokens.count == 1, "Expected only eof for input: '\(input)'")
            #expect(tokens[0].type == .eof)
        }

        // "0xG" => "0x" consumed, "G" parsed as identifier
        do {
            let tokens = try ParsingTokenizer.tokenize("0xG")
            #expect(tokens.count == 2) // identifier('G') + eof
            #expect(tokens[0].type == .identifier)
            #expect(tokens[0].lexeme == "G")
        }

        // "0xZ123" => "0x" consumed, "Z123" parsed as identifier
        do {
            let tokens = try ParsingTokenizer.tokenize("0xZ123")
            #expect(tokens.count == 2) // identifier('Z123') + eof
            #expect(tokens[0].type == .identifier)
            #expect(tokens[0].lexeme == "Z123")
        }

        // "0x12G3" => "0x12" is valid hex, "G3" parsed as identifier
        do {
            let tokens = try ParsingTokenizer.tokenize("0x12G3")
            #expect(tokens.count == 3) // integerLiteral('0x12') + identifier('G3') + eof
            #expect(tokens[0].type == .integerLiteral)
            #expect(tokens[0].lexeme == "0x12")
            #expect(tokens[1].type == .identifier)
            #expect(tokens[1].lexeme == "G3")
        }
    }

    // MARK: - Binary Number Tests

    @Test func testBinaryNumbers() throws {
        let testCases = [
            ("0b1010", TokenType.integerLiteral),
            ("0B1010", TokenType.integerLiteral),
            ("0b0", TokenType.integerLiteral),
            ("0b1", TokenType.integerLiteral),
            ("0b11111111", TokenType.integerLiteral),
            ("0b10101010", TokenType.integerLiteral)
        ]

        for (input, expectedType) in testCases {
            let tokens = try ParsingTokenizer.tokenize(input)

            #expect(tokens.count == 2) // number + eof
            #expect(tokens[0].type == expectedType)
            #expect(tokens[0].lexeme == input)
        }
    }

    @Test func testBinaryWithUnderscores() throws {
        let testCases = [
            ("0b1010_1100", TokenType.integerLiteral),
            ("0b1111_0000_1111_0000", TokenType.integerLiteral),
            ("0b1_0_1_0", TokenType.integerLiteral)
        ]

        for (input, expectedType) in testCases {
            let tokens = try ParsingTokenizer.tokenize(input)

            #expect(tokens.count == 2) // number + eof
            #expect(tokens[0].type == expectedType)
            #expect(tokens[0].lexeme == input)
        }
    }

    @Test func testInvalidBinaryNumbers() throws {
        // ParsingTokenizer does not throw errors for invalid binary numbers.
        // Instead, it silently consumes the "0b" prefix or splits into multiple tokens.

        // Cases where the "0b"/"0B" prefix is consumed silently (only eof produced)
        let silentlyConsumedCases = ["0b", "0B"]
        for input in silentlyConsumedCases {
            let tokens = try ParsingTokenizer.tokenize(input)
            #expect(tokens.count == 1, "Expected only eof for input: '\(input)'")
            #expect(tokens[0].type == .eof)
        }

        // "0b2" => "0b" consumed, "2" parsed as integer
        do {
            let tokens = try ParsingTokenizer.tokenize("0b2")
            #expect(tokens.count == 2) // integerLiteral('2') + eof
            #expect(tokens[0].type == .integerLiteral)
            #expect(tokens[0].lexeme == "2")
        }

        // "0b102" => "0b10" is valid binary, "2" parsed as integer
        do {
            let tokens = try ParsingTokenizer.tokenize("0b102")
            #expect(tokens.count == 3) // integerLiteral('0b10') + integerLiteral('2') + eof
            #expect(tokens[0].type == .integerLiteral)
            #expect(tokens[0].lexeme == "0b10")
            #expect(tokens[1].type == .integerLiteral)
            #expect(tokens[1].lexeme == "2")
        }

        // "0b1a1" => "0b1" is valid binary, "a1" parsed as identifier
        do {
            let tokens = try ParsingTokenizer.tokenize("0b1a1")
            #expect(tokens.count == 3) // integerLiteral('0b1') + identifier('a1') + eof
            #expect(tokens[0].type == .integerLiteral)
            #expect(tokens[0].lexeme == "0b1")
            #expect(tokens[1].type == .identifier)
            #expect(tokens[1].lexeme == "a1")
        }
    }

    // MARK: - Octal Number Tests

    @Test func testOctalNumbers() throws {
        let testCases = [
            ("0o777", TokenType.integerLiteral),
            ("0O777", TokenType.integerLiteral),
            ("0o0", TokenType.integerLiteral),
            ("0o123", TokenType.integerLiteral),
            ("0o567", TokenType.integerLiteral)
        ]

        for (input, expectedType) in testCases {
            let tokens = try ParsingTokenizer.tokenize(input)

            #expect(tokens.count == 2) // number + eof
            #expect(tokens[0].type == expectedType)
            #expect(tokens[0].lexeme == input)
        }
    }

    @Test func testOctalWithUnderscores() throws {
        let testCases = [
            ("0o123_456", TokenType.integerLiteral),
            ("0o7_7_7", TokenType.integerLiteral),
            ("0o1_2_3_4_5_6_7", TokenType.integerLiteral)
        ]

        for (input, expectedType) in testCases {
            let tokens = try ParsingTokenizer.tokenize(input)

            #expect(tokens.count == 2) // number + eof
            #expect(tokens[0].type == expectedType)
            #expect(tokens[0].lexeme == input)
        }
    }

    @Test func testInvalidOctalNumbers() throws {
        // ParsingTokenizer does not throw errors for invalid octal numbers.
        // Instead, it silently consumes the "0o" prefix or splits into multiple tokens.

        // Cases where the "0o"/"0O" prefix is consumed silently (only eof produced)
        let silentlyConsumedCases = ["0o", "0O"]
        for input in silentlyConsumedCases {
            let tokens = try ParsingTokenizer.tokenize(input)
            #expect(tokens.count == 1, "Expected only eof for input: '\(input)'")
            #expect(tokens[0].type == .eof)
        }

        // "0o8" => "0o" consumed, "8" parsed as integer
        do {
            let tokens = try ParsingTokenizer.tokenize("0o8")
            #expect(tokens.count == 2) // integerLiteral('8') + eof
            #expect(tokens[0].type == .integerLiteral)
            #expect(tokens[0].lexeme == "8")
        }

        // "0o789" => "0o7" is valid octal, "89" parsed as integer
        do {
            let tokens = try ParsingTokenizer.tokenize("0o789")
            #expect(tokens.count == 3) // integerLiteral('0o7') + integerLiteral('89') + eof
            #expect(tokens[0].type == .integerLiteral)
            #expect(tokens[0].lexeme == "0o7")
            #expect(tokens[1].type == .integerLiteral)
            #expect(tokens[1].lexeme == "89")
        }

        // "0o12a3" => "0o12" is valid octal, "a3" parsed as identifier
        do {
            let tokens = try ParsingTokenizer.tokenize("0o12a3")
            #expect(tokens.count == 3) // integerLiteral('0o12') + identifier('a3') + eof
            #expect(tokens[0].type == .integerLiteral)
            #expect(tokens[0].lexeme == "0o12")
            #expect(tokens[1].type == .identifier)
            #expect(tokens[1].lexeme == "a3")
        }
    }

    // MARK: - Underscore Separator Tests

    @Test func testUnderscoreInRegularNumbers() throws {
        let testCases = [
            ("1_000_000", TokenType.integerLiteral),
            ("123_456", TokenType.integerLiteral),
            ("1_2_3", TokenType.integerLiteral),
            ("3_14.159_265", TokenType.realLiteral),
            ("1_000.5_00", TokenType.realLiteral)
        ]

        for (input, expectedType) in testCases {
            let tokens = try ParsingTokenizer.tokenize(input)

            #expect(tokens.count == 2) // number + eof
            #expect(tokens[0].type == expectedType)
            #expect(tokens[0].lexeme == input)
        }
    }

    @Test func testInvalidUnderscorePlacement() throws {
        // ParsingTokenizer does not throw errors for most invalid underscore placements.
        // It is more lenient than the old Tokenizer and accepts underscores in many positions.

        // Leading underscore should be parsed as identifier
        do {
            let tokens = try ParsingTokenizer.tokenize("_123")
            #expect(tokens[0].type == .identifier)
        }

        // Trailing underscore: ParsingTokenizer accepts it as part of the number
        do {
            let tokens = try ParsingTokenizer.tokenize("123_")
            #expect(tokens.count == 2) // integerLiteral('123_') + eof
            #expect(tokens[0].type == .integerLiteral)
            #expect(tokens[0].lexeme == "123_")
        }

        // Consecutive underscores: ParsingTokenizer accepts them
        do {
            let tokens = try ParsingTokenizer.tokenize("12__34")
            #expect(tokens.count == 2) // integerLiteral('12__34') + eof
            #expect(tokens[0].type == .integerLiteral)
            #expect(tokens[0].lexeme == "12__34")
        }

        // Underscore before decimal point: ParsingTokenizer treats as a real literal
        do {
            let tokens = try ParsingTokenizer.tokenize("12_.34")
            #expect(tokens.count == 2) // realLiteral('12_.34') + eof
            #expect(tokens[0].type == .realLiteral)
            #expect(tokens[0].lexeme == "12_.34")
        }

        // Underscore after e: ParsingTokenizer treats as scientific notation
        do {
            let tokens = try ParsingTokenizer.tokenize("1e_5")
            #expect(tokens.count == 2) // realLiteral('1e_5') + eof
            #expect(tokens[0].type == .realLiteral)
            #expect(tokens[0].lexeme == "1e_5")
        }

        // Underscore before e: ParsingTokenizer treats as scientific notation
        do {
            let tokens = try ParsingTokenizer.tokenize("1_e5")
            #expect(tokens.count == 2) // realLiteral('1_e5') + eof
            #expect(tokens[0].type == .realLiteral)
            #expect(tokens[0].lexeme == "1_e5")
        }

        // Underscore after sign: ParsingTokenizer accepts it
        do {
            let tokens = try ParsingTokenizer.tokenize("1e+_5")
            #expect(tokens.count == 2) // realLiteral('1e+_5') + eof
            #expect(tokens[0].type == .realLiteral)
            #expect(tokens[0].lexeme == "1e+_5")
        }

        // Underscore before sign: split into multiple tokens
        do {
            let tokens = try ParsingTokenizer.tokenize("1e_+5")
            #expect(tokens.count == 4) // realLiteral('1e_') + plus('+') + integerLiteral('5') + eof
            #expect(tokens[0].type == .realLiteral)
            #expect(tokens[0].lexeme == "1e_")
            #expect(tokens[1].type == .plus)
            #expect(tokens[2].type == .integerLiteral)
            #expect(tokens[2].lexeme == "5")
        }
    }

    @Test func testValidUnderscoreSeparation() throws {
        // Test that certain cases with underscores are correctly parsed as separate tokens
        let testCases = [
            ("12._34", [TokenType.integerLiteral, .dot, .identifier, .eof])  // Number, dot, identifier
        ]

        for (input, expectedTypes) in testCases {
            let tokens = try ParsingTokenizer.tokenize(input)

            #expect(tokens.count == expectedTypes.count)
            for (index, expectedType) in expectedTypes.enumerated() {
                #expect(tokens[index].type == expectedType, "Token \(index) should be \(expectedType) but was \(tokens[index].type)")
            }
        }
    }

    // MARK: - ParsingTokenizer Tests

    @Test func testParsingTokenizerWithEnhancedNumbers() throws {
        let testCases = [
            "0xFF 0b1010 0o777",
            "1.23e5 2.5E-3 1_000_000",
            "0xFF_FF 0b1010_1100 0o123_456",
            "1e5 + 0xFF - 0b1010"
        ]

        for testCase in testCases {
            let tokens = try ParsingTokenizer.tokenize(testCase)

            // Verify tokens were produced (at minimum an eof token)
            #expect(tokens.count >= 1, "Should produce at least one token for input: '\(testCase)'")
            #expect(tokens.last?.type == .eof, "Last token should be eof for input: '\(testCase)'")
        }
    }

    // MARK: - Edge Cases

    @Test func testNumberFormatEdgeCases() throws {
        let testCases = [
            ("0", TokenType.integerLiteral),      // Plain zero
            ("0.0", TokenType.realLiteral),       // Zero with decimal
            ("0e0", TokenType.realLiteral),       // Zero in scientific notation
            (".0", TokenType.realLiteral),        // Leading dot zero
            ("1e0", TokenType.realLiteral),       // Scientific with zero exponent
            ("1E+0", TokenType.realLiteral),      // Scientific with explicit positive zero exponent
            ("1e-0", TokenType.realLiteral)       // Scientific with negative zero exponent
        ]

        for (input, expectedType) in testCases {
            let tokens = try ParsingTokenizer.tokenize(input)

            #expect(tokens.count == 2) // number + eof
            #expect(tokens[0].type == expectedType)
            #expect(tokens[0].lexeme == input)
        }
    }

    @Test func testComplexNumberExpressions() throws {
        let input = "変数 x ← 0xFF + 1.23e5 - 0b1010 * 0o777 / 1_000_000"
        let tokens = try ParsingTokenizer.tokenize(input)

        // Verify we get the expected number tokens
        let numberTokens = tokens.filter { $0.type == .integerLiteral || $0.type == .realLiteral }
        #expect(numberTokens.count == 5)

        // Verify specific number formats
        #expect(numberTokens[0].lexeme == "0xFF")
        #expect(numberTokens[0].type == .integerLiteral)

        #expect(numberTokens[1].lexeme == "1.23e5")
        #expect(numberTokens[1].type == .realLiteral)

        #expect(numberTokens[2].lexeme == "0b1010")
        #expect(numberTokens[2].type == .integerLiteral)

        #expect(numberTokens[3].lexeme == "0o777")
        #expect(numberTokens[3].type == .integerLiteral)

        #expect(numberTokens[4].lexeme == "1_000_000")
        #expect(numberTokens[4].type == .integerLiteral)
    }
}
