import Foundation
import Testing
@testable import FeLangCore

@Suite("Leading Dot Decimal Tests")
struct LeadingDotTests {

    @Test func testLeadingDotDecimalNumbers() throws {
        // Test that leading-dot decimals are correctly recognized as real literals
        let testCases = [
            (".5", TokenType.realLiteral),
            (".25", TokenType.realLiteral),
            (".999", TokenType.realLiteral),
            (".0", TokenType.realLiteral),
            (".123456", TokenType.realLiteral)
        ]

        for (input, expectedType) in testCases {
            // Test original tokenizer
            let tokenizer = Tokenizer(input: input)
            let originalTokens = try tokenizer.tokenize()
            #expect(originalTokens.count == 2) // number + eof
            #expect(originalTokens[0].type == expectedType)
            #expect(originalTokens[0].lexeme == input)
            #expect(originalTokens[1].type == .eof)

            // Test parsing tokenizer
            let parsingTokens = try ParsingTokenizer.tokenize(input)
            #expect(parsingTokens.count == 2) // number + eof
            #expect(parsingTokens[0].type == expectedType)
            #expect(parsingTokens[0].lexeme == input)
            #expect(parsingTokens[1].type == .eof)
        }
    }

    @Test func testDotVsLeadingDotDecimal() throws {
        // Test that regular dots are still recognized correctly
        let input = "obj.field .5"

        // Test original tokenizer
        let tokenizer = Tokenizer(input: input)
        let originalTokens = try tokenizer.tokenize()
        #expect(originalTokens.count == 5) // identifier, dot, identifier, realLiteral, eof
        #expect(originalTokens[0].type == .identifier)
        #expect(originalTokens[0].lexeme == "obj")
        #expect(originalTokens[1].type == .dot)
        #expect(originalTokens[1].lexeme == ".")
        #expect(originalTokens[2].type == .identifier)
        #expect(originalTokens[2].lexeme == "field")
        #expect(originalTokens[3].type == .realLiteral)
        #expect(originalTokens[3].lexeme == ".5")
        #expect(originalTokens[4].type == .eof)

        // Test parsing tokenizer
        let parsingTokens = try ParsingTokenizer.tokenize(input)
        #expect(parsingTokens.count == 5) // identifier, dot, identifier, realLiteral, eof
        #expect(parsingTokens[0].type == .identifier)
        #expect(parsingTokens[0].lexeme == "obj")
        #expect(parsingTokens[1].type == .dot)
        #expect(parsingTokens[1].lexeme == ".")
        #expect(parsingTokens[2].type == .identifier)
        #expect(parsingTokens[2].lexeme == "field")
        #expect(parsingTokens[3].type == .realLiteral)
        #expect(parsingTokens[3].lexeme == ".5")
        #expect(parsingTokens[4].type == .eof)
    }
}
