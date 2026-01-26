import Foundation
import Testing
@testable import FeLangCore

@Suite("Leading Dot Decimal Tests")
struct LeadingDotTests {

    @Test func testLeadingDotDecimalNumbers() throws {
        let testCases = [
            (".5", TokenType.realLiteral),
            (".25", TokenType.realLiteral),
            (".999", TokenType.realLiteral),
            (".0", TokenType.realLiteral),
            (".123456", TokenType.realLiteral)
        ]

        for (input, expectedType) in testCases {
            let tokens = try ParsingTokenizer.tokenize(input)
            #expect(tokens.count == 2) // number + eof
            #expect(tokens[0].type == expectedType)
            #expect(tokens[0].lexeme == input)
            #expect(tokens[1].type == .eof)
        }
    }

    @Test func testDotVsLeadingDotDecimal() throws {
        let input = "obj.field .5"

        let tokens = try ParsingTokenizer.tokenize(input)
        #expect(tokens.count == 5) // identifier, dot, identifier, realLiteral, eof
        #expect(tokens[0].type == .identifier)
        #expect(tokens[0].lexeme == "obj")
        #expect(tokens[1].type == .dot)
        #expect(tokens[1].lexeme == ".")
        #expect(tokens[2].type == .identifier)
        #expect(tokens[2].lexeme == "field")
        #expect(tokens[3].type == .realLiteral)
        #expect(tokens[3].lexeme == ".5")
        #expect(tokens[4].type == .eof)
    }
}
