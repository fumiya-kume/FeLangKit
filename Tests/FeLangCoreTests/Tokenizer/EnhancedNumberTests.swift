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
            let tokenizer = Tokenizer(input: input)
            let tokens = try tokenizer.tokenize()

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
            let tokenizer = Tokenizer(input: input)
            let tokens = try tokenizer.tokenize()

            #expect(tokens.count == 2) // number + eof
            #expect(tokens[0].type == expectedType)
            #expect(tokens[0].lexeme == input)
        }
    }

    @Test func testInvalidScientificNotation() throws {
        let invalidCases = [
            "1e",      // Missing exponent
            "1E",      // Missing exponent
            "1e+",     // Missing exponent digits
            "1e-",     // Missing exponent digits
            // Note: "e5" is valid as an identifier, not invalid scientific notation
            "1ee5",    // Double e
            "1e5e"     // Trailing e
        ]

        for input in invalidCases {
            let tokenizer = Tokenizer(input: input)
            #expect(throws: TokenizerError.self) {
                _ = try tokenizer.tokenize()
            }
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
            let tokenizer = Tokenizer(input: input)
            let tokens = try tokenizer.tokenize()

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
            let tokenizer = Tokenizer(input: input)
            let tokens = try tokenizer.tokenize()

            #expect(tokens.count == 2) // number + eof
            #expect(tokens[0].type == expectedType)
            #expect(tokens[0].lexeme == input)
        }
    }

    @Test func testInvalidHexadecimalNumbers() throws {
        let invalidCases = [
            "0x",      // Missing digits
            "0X",      // Missing digits
            "0xG",     // Invalid hex digit
            "0xZ123",  // Invalid hex digit
            "0x12G3"   // Invalid hex digit in middle
        ]

        for input in invalidCases {
            let tokenizer = Tokenizer(input: input)
            #expect(throws: TokenizerError.self) {
                _ = try tokenizer.tokenize()
            }
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
            let tokenizer = Tokenizer(input: input)
            let tokens = try tokenizer.tokenize()

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
            let tokenizer = Tokenizer(input: input)
            let tokens = try tokenizer.tokenize()

            #expect(tokens.count == 2) // number + eof
            #expect(tokens[0].type == expectedType)
            #expect(tokens[0].lexeme == input)
        }
    }

    @Test func testInvalidBinaryNumbers() throws {
        let invalidCases = [
            "0b",      // Missing digits
            "0B",      // Missing digits
            "0b2",     // Invalid binary digit
            "0b102",   // Invalid binary digit
            "0b1a1"    // Invalid binary digit
        ]

        for input in invalidCases {
            let tokenizer = Tokenizer(input: input)
            #expect(throws: TokenizerError.self) {
                _ = try tokenizer.tokenize()
            }
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
            let tokenizer = Tokenizer(input: input)
            let tokens = try tokenizer.tokenize()

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
            let tokenizer = Tokenizer(input: input)
            let tokens = try tokenizer.tokenize()

            #expect(tokens.count == 2) // number + eof
            #expect(tokens[0].type == expectedType)
            #expect(tokens[0].lexeme == input)
        }
    }

    @Test func testInvalidOctalNumbers() throws {
        let invalidCases = [
            "0o",      // Missing digits
            "0O",      // Missing digits
            "0o8",     // Invalid octal digit
            "0o789",   // Invalid octal digit
            "0o12a3"   // Invalid octal digit
        ]

        for input in invalidCases {
            let tokenizer = Tokenizer(input: input)
            #expect(throws: TokenizerError.self) {
                _ = try tokenizer.tokenize()
            }
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
            let tokenizer = Tokenizer(input: input)
            let tokens = try tokenizer.tokenize()

            #expect(tokens.count == 2) // number + eof
            #expect(tokens[0].type == expectedType)
            #expect(tokens[0].lexeme == input)
        }
    }

    @Test func testInvalidUnderscorePlacement() throws {
        let invalidCases = [
            "_123",      // Leading underscore (should be identifier)
            "123_",      // Trailing underscore
            "12__34",    // Consecutive underscores
            "12_.34",    // Underscore before decimal point
            "1e_5",      // Underscore after e
            "1_e5",      // Underscore before e
            "1e+_5",     // Underscore after sign
            "1e_+5"      // Underscore before sign
        ]

        for input in invalidCases {
            let tokenizer = Tokenizer(input: input)
            if input.hasPrefix("_") {
                // Leading underscore should be parsed as identifier, not throw error
                let tokens = try tokenizer.tokenize()
                #expect(tokens[0].type == .identifier)
            } else {
                #expect(throws: TokenizerError.self) {
                    _ = try tokenizer.tokenize()
                }
            }
        }
    }

    @Test func testValidUnderscoreSeparation() throws {
        // Test that certain cases with underscores are correctly parsed as separate tokens
        let testCases = [
            ("12._34", [TokenType.integerLiteral, .dot, .identifier, .eof])  // Number, dot, identifier
        ]

        for (input, expectedTypes) in testCases {
            let tokenizer = Tokenizer(input: input)
            let tokens = try tokenizer.tokenize()

            #expect(tokens.count == expectedTypes.count)
            for (index, expectedType) in expectedTypes.enumerated() {
                #expect(tokens[index].type == expectedType, "Token \(index) should be \(expectedType) but was \(tokens[index].type)")
            }
        }
    }

    // MARK: - Consistency Tests

    @Test func testTokenizerConsistencyWithEnhancedNumbers() throws {
        let testCases = [
            "0xFF 0b1010 0o777",
            "1.23e5 2.5E-3 1_000_000",
            "0xFF_FF 0b1010_1100 0o123_456",
            "1e5 + 0xFF - 0b1010"
        ]

        for testCase in testCases {
            let originalTokenizer = Tokenizer(input: testCase)
            let parsingTokenizer = ParsingTokenizer()

            let originalTokens = try originalTokenizer.tokenize()
            let parsingTokens = try parsingTokenizer.tokenize(testCase)

            // Both should produce the same number of tokens
            #expect(originalTokens.count == parsingTokens.count,
                   "Token count mismatch for input: '\(testCase)'")

            // Both should produce tokens with the same types and lexemes
            for (index, (original, parsing)) in zip(originalTokens, parsingTokens).enumerated() {
                #expect(original.type == parsing.type,
                       "Token type mismatch at index \(index) for input: '\(testCase)'")
                #expect(original.lexeme == parsing.lexeme,
                       "Token lexeme mismatch at index \(index) for input: '\(testCase)'")
            }
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
            let tokenizer = Tokenizer(input: input)
            let tokens = try tokenizer.tokenize()

            #expect(tokens.count == 2) // number + eof
            #expect(tokens[0].type == expectedType)
            #expect(tokens[0].lexeme == input)
        }
    }

    @Test func testComplexNumberExpressions() throws {
        let input = "変数 x ← 0xFF + 1.23e5 - 0b1010 * 0o777 / 1_000_000"
        let tokenizer = Tokenizer(input: input)
        let tokens = try tokenizer.tokenize()

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
