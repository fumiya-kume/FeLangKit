import Testing
@testable import FeLangCore

@Suite("String Escape Utilities Tests")
struct StringEscapeUtilitiesTests {

    @Test("Basic Escape Sequences")
    func testBasicEscapeSequences() throws {
        #expect(try StringEscapeUtilities.processEscapeSequences("Hello\\nWorld") == "Hello\nWorld")
        #expect(try StringEscapeUtilities.processEscapeSequences("Tab\\tSeparated") == "Tab\tSeparated")
        #expect(try StringEscapeUtilities.processEscapeSequences("Return\\rChar") == "Return\rChar")
        #expect(try StringEscapeUtilities.processEscapeSequences("Back\\\\slash") == "Back\\slash")
        #expect(try StringEscapeUtilities.processEscapeSequences("Quote\\\"Mark") == "Quote\"Mark")
        #expect(try StringEscapeUtilities.processEscapeSequences("Apos\\'trophe") == "Apos'trophe")
    }

    @Test("Unicode Escape Sequences")
    func testUnicodeEscapeSequences() throws {
        // Basic Unicode escapes
        #expect(try StringEscapeUtilities.processEscapeSequences("\\u{41}") == "A")
        #expect(try StringEscapeUtilities.processEscapeSequences("\\u{1F600}") == "😀")
        #expect(try StringEscapeUtilities.processEscapeSequences("Hello \\u{1F44B} World") == "Hello 👋 World")
        
        // Different hex case
        #expect(try StringEscapeUtilities.processEscapeSequences("\\u{41}") == "A")
        #expect(try StringEscapeUtilities.processEscapeSequences("\\u{41}") == "A")
        
        // Various lengths
        #expect(try StringEscapeUtilities.processEscapeSequences("\\u{A}") == "\n") // Single digit
        #expect(try StringEscapeUtilities.processEscapeSequences("\\u{20}") == " ") // Two digits
        #expect(try StringEscapeUtilities.processEscapeSequences("\\u{3042}") == "あ") // Four digits (Japanese)
    }

    @Test("Invalid Unicode Escape Sequences")
    func testInvalidUnicodeEscapeSequences() throws {
        // Missing opening brace
        #expect(throws: StringEscapeUtilities.EscapeSequenceError.self) {
            try StringEscapeUtilities.processEscapeSequences("\\u41")
        }
        
        // Missing closing brace
        #expect(throws: StringEscapeUtilities.EscapeSequenceError.self) {
            try StringEscapeUtilities.processEscapeSequences("\\u{41")
        }
        
        // Empty hex string
        #expect(throws: StringEscapeUtilities.EscapeSequenceError.self) {
            try StringEscapeUtilities.processEscapeSequences("\\u{}")
        }
        
        // Invalid hex characters
        #expect(throws: StringEscapeUtilities.EscapeSequenceError.self) {
            try StringEscapeUtilities.processEscapeSequences("\\u{XYZ}")
        }
        
        // Too many hex digits
        #expect(throws: StringEscapeUtilities.EscapeSequenceError.self) {
            try StringEscapeUtilities.processEscapeSequences("\\u{123456789}")
        }
        
        // Invalid Unicode code point
        #expect(throws: StringEscapeUtilities.EscapeSequenceError.self) {
            try StringEscapeUtilities.processEscapeSequences("\\u{110000}")
        }
    }

    @Test("Invalid Basic Escape Sequences")
    func testInvalidBasicEscapeSequences() throws {
        // Unknown escape sequence
        #expect(throws: StringEscapeUtilities.EscapeSequenceError.self) {
            try StringEscapeUtilities.processEscapeSequences("\\x")
        }
        
        // Incomplete escape at end
        #expect(throws: StringEscapeUtilities.EscapeSequenceError.self) {
            try StringEscapeUtilities.processEscapeSequences("Hello\\")
        }
    }

    @Test("Mixed Escape Sequences")
    func testMixedEscapeSequences() throws {
        let input = "Line1\\nTab\\tUnicode: \\u{1F600}\\nQuote: \\\"Hello\\\""
        let expected = "Line1\nTab\tUnicode: 😀\nQuote: \"Hello\""
        #expect(try StringEscapeUtilities.processEscapeSequences(input) == expected)
    }

    @Test("Validate Escape Sequences")
    func testValidateEscapeSequences() throws {
        #expect(StringEscapeUtilities.validateEscapeSequences("Hello\\nWorld") == true)
        #expect(StringEscapeUtilities.validateEscapeSequences("\\u{1F600}") == true)
        #expect(StringEscapeUtilities.validateEscapeSequences("Unfinished\\") == false)
        #expect(StringEscapeUtilities.validateEscapeSequences("\\u{XYZ}") == false)
        #expect(StringEscapeUtilities.validateEscapeSequences("No escapes") == true)
        #expect(StringEscapeUtilities.validateEscapeSequences("") == true)
    }

    @Test("Validate Escape Sequences With Details")
    func testValidateEscapeSequencesWithDetails() throws {
        // Valid sequences should return empty array
        let validErrors = StringEscapeUtilities.validateEscapeSequencesWithDetails("Hello\\nWorld")
        #expect(validErrors.isEmpty)
        
        // Invalid sequences should return error details
        let invalidErrors = StringEscapeUtilities.validateEscapeSequencesWithDetails("Hello\\")
        #expect(invalidErrors.count == 1)
        #expect(invalidErrors[0].position == 5)
        #expect(invalidErrors[0].error.contains("Incomplete escape sequence"))
        
        // Multiple errors
        let multipleErrors = StringEscapeUtilities.validateEscapeSequencesWithDetails("\\x\\y\\")
        #expect(multipleErrors.count == 3)
    }

    @Test("Count Escape Sequences")
    func testCountEscapeSequences() throws {
        #expect(StringEscapeUtilities.countEscapeSequences("No escapes") == 0)
        #expect(StringEscapeUtilities.countEscapeSequences("One\\n") == 1)
        #expect(StringEscapeUtilities.countEscapeSequences("Three\\n\\t\\r") == 3)
        #expect(StringEscapeUtilities.countEscapeSequences("Unicode\\u{1F600}") == 1)
        #expect(StringEscapeUtilities.countEscapeSequences("Mixed\\n\\u{41}\\t") == 3)
    }

    @Test("Contains Escape Sequences")
    func testContainsEscapeSequences() throws {
        #expect(StringEscapeUtilities.containsEscapeSequences("No escapes") == false)
        #expect(StringEscapeUtilities.containsEscapeSequences("Has\\nEscape") == true)
        #expect(StringEscapeUtilities.containsEscapeSequences("\\u{1F600}") == true)
        #expect(StringEscapeUtilities.containsEscapeSequences("") == false)
    }

    @Test("Tokenizer Integration - Valid Escape Sequences")
    func testTokenizerValidEscapeSequences() throws {
        // Test that the tokenizer accepts valid escape sequences
        let validInput = "'Hello\\nWorld\\t!'"
        let tokenizer = Tokenizer(input: validInput)

        // This should not throw
        let tokens = try tokenizer.tokenize()

        #expect(tokens.count >= 1)
        #expect(tokens[0].type == .stringLiteral)
        #expect(tokens[0].lexeme == "'Hello\\nWorld\\t!'")
    }

    @Test("Tokenizer Integration - Unicode Escape Sequences")
    func testTokenizerUnicodeEscapeSequences() throws {
        // Test Unicode escape sequences in tokenizer
        let unicodeInput = "'\\u{1F600}'"
        let tokenizer = Tokenizer(input: unicodeInput)

        let tokens = try tokenizer.tokenize()

        #expect(tokens.count >= 1)
        #expect(tokens[0].type == .characterLiteral) // Single Unicode character
        #expect(tokens[0].lexeme == "'\\u{1F600}'")
    }

    @Test("Tokenizer Integration - Invalid Escape Sequences")
    func testTokenizerInvalidEscapeSequences() throws {
        // Test that the tokenizer properly detects invalid escape sequences
        let invalidInput = "'Hello\\x'"
        let tokenizer = Tokenizer(input: invalidInput)

        #expect(throws: TokenizerError.self) {
            try tokenizer.tokenize()
        }
    }

    @Test("Tokenizer Integration - Invalid Unicode Escape")
    func testTokenizerInvalidUnicodeEscape() throws {
        // Test invalid Unicode escape sequence
        let invalidInput = "'\\u{XYZ}'"
        let tokenizer = Tokenizer(input: invalidInput)

        #expect(throws: TokenizerError.self) {
            try tokenizer.tokenize()
        }
    }

    @Test("Edge Cases")
    func testEdgeCases() throws {
        // Empty string
        #expect(try StringEscapeUtilities.processEscapeSequences("") == "")
        
        // Only escape sequences
        #expect(try StringEscapeUtilities.processEscapeSequences("\\n\\t\\r") == "\n\t\r")
        
        // Consecutive escape sequences
        #expect(try StringEscapeUtilities.processEscapeSequences("\\n\\n") == "\n\n")
        
        // Unicode at boundaries
        #expect(try StringEscapeUtilities.processEscapeSequences("\\u{41}") == "A")
        #expect(try StringEscapeUtilities.processEscapeSequences("\\u{41}B") == "AB")
        #expect(try StringEscapeUtilities.processEscapeSequences("A\\u{41}") == "AA")
    }

    @Test("End-to-End Integration Test")
    func testEndToEndIntegration() throws {
        // Test cases that should work from tokenization to literal creation
        let successCases: [(input: String, expectedType: TokenType, description: String)] = [
            ("'Hello\\nWorld'", .stringLiteral, "Basic newline escape"),
            ("'\\u{1F600}'", .characterLiteral, "Unicode emoji escape"),
            ("'\\u{41}'", .characterLiteral, "Unicode character A"),
            ("'Tab\\tSeparated'", .stringLiteral, "Tab escape sequence"),
            ("'Quote\\\"Mark'", .stringLiteral, "Quote escape sequence"),
            ("'Back\\\\slash'", .stringLiteral, "Backslash escape")
        ]
        
        for testCase in successCases {
            // Test tokenization
            let tokenizer = Tokenizer(input: testCase.input)
            let tokens = try tokenizer.tokenize()
            
            #expect(tokens.count >= 1, "Should have at least one token for: \(testCase.description)")
            #expect(tokens[0].type == testCase.expectedType, "Expected \(testCase.expectedType) for: \(testCase.description)")
            
            // Test literal creation
            let literal = Literal(token: tokens[0])
            #expect(literal != nil, "Should be able to create literal from token for: \(testCase.description)")
        }
        
        // Test cases that should fail during tokenization
        let errorCases: [(input: String, description: String)] = [
            ("'\\x'", "Invalid escape character"),
            ("'\\u{XYZ}'", "Invalid Unicode hex digits"),
            ("'Unfinished\\'", "Incomplete escape at end"),
            ("'\\u{}'", "Empty Unicode escape"),
            ("'\\u{123456789}'", "Unicode escape too long")
        ]
        
        for testCase in errorCases {
            let tokenizer = Tokenizer(input: testCase.input)
            
            #expect(throws: TokenizerError.self) {
                try tokenizer.tokenize()
            }
        }
    }
}
