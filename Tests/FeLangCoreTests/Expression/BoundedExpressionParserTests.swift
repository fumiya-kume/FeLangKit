import Foundation
import Testing
@testable import FeLangCore

// Alias to avoid conflict with Foundation.Expression
typealias BoundedFEExpression = FeLangCore.Expression

@Suite("Bounded ExpressionParser Tests")
struct BoundedExpressionParserTests {

    let parser = ExpressionParser()

    private func tokenize(_ input: String) throws -> [Token] {
        try ParsingTokenizer.tokenize(input)
    }

    // MARK: - Basic Bounded Parsing Tests

    @Test func testBoundedParseSimpleExpression() throws {
        let tokens = try tokenize("a + b")
        // tokens: [identifier("a"), plus, identifier("b"), eof]
        let eofIndex = tokens.count - 1
        let (expr, _) = try parser.parseExpression(from: tokens, startingAt: 0, endingBefore: eofIndex)
        #expect(expr == BoundedFEExpression.binary(.add, .identifier("a"), .identifier("b")))
    }

    @Test func testBoundedParseReturnsCorrectIndex() throws {
        let tokens = try tokenize("a + b")
        // tokens: [identifier("a"), plus, identifier("b"), eof]
        let eofIndex = tokens.count - 1
        let (_, endIdx) = try parser.parseExpression(from: tokens, startingAt: 0, endingBefore: eofIndex)
        #expect(endIdx == 3) // After consuming a, +, b
    }

    @Test func testBoundedParseSingleToken() throws {
        let tokens = try tokenize("x")
        // tokens: [identifier("x"), eof]
        let (expr, endIdx) = try parser.parseExpression(from: tokens, startingAt: 0, endingBefore: 1)
        #expect(expr == BoundedFEExpression.identifier("x"))
        #expect(endIdx == 1)
    }

    @Test func testBoundedParseWithParentheses() throws {
        let tokens = try tokenize("(a + b)")
        let eofIndex = tokens.count - 1
        let (expr, _) = try parser.parseExpression(from: tokens, startingAt: 0, endingBefore: eofIndex)
        #expect(expr == BoundedFEExpression.binary(.add, .identifier("a"), .identifier("b")))
    }

    @Test func testBoundedParseFunctionCall() throws {
        let tokens = try tokenize("max(a, b)")
        let eofIndex = tokens.count - 1
        let (expr, _) = try parser.parseExpression(from: tokens, startingAt: 0, endingBefore: eofIndex)
        #expect(expr == BoundedFEExpression.functionCall("max", [.identifier("a"), .identifier("b")]))
    }

    // MARK: - Middle-of-Array Parsing Tests

    @Test func testBoundedParseMiddleOfTokenArray() throws {
        let tokens = try tokenize("x + a * b - c")
        // tokens: [x, +, a, *, b, -, c, eof]
        // Parse "a * b" from index 2 to 5
        let (expr, endIdx) = try parser.parseExpression(from: tokens, startingAt: 2, endingBefore: 5)
        #expect(expr == BoundedFEExpression.binary(.multiply, .identifier("a"), .identifier("b")))
        #expect(endIdx == 5)
    }

    @Test func testBoundedParseStopsAtBoundary() throws {
        let tokens = try tokenize("a + b * c")
        // tokens: [a, +, b, *, c, eof]
        // Parse only "a + b" (indices 0 to 3), boundary at index 3 (before *)
        let (expr, _) = try parser.parseExpression(from: tokens, startingAt: 0, endingBefore: 3)
        #expect(expr == BoundedFEExpression.binary(.add, .identifier("a"), .identifier("b")))
    }

    // MARK: - Error Handling Tests

    @Test func testBoundedParseIncompleteExpressionThrows() throws {
        let tokens = try tokenize("a +")
        // tokens: [a, +, eof]
        // Parse "a +" from index 0 to 2 (excluding eof) — the "+" has no right operand
        #expect(throws: (any Error).self) {
            _ = try parser.parseExpression(from: tokens, startingAt: 0, endingBefore: 2)
        }
    }

    // MARK: - Complex Expression Tests

    @Test func testBoundedParseArrayAccess() throws {
        let tokens = try tokenize("arr[i]")
        let eofIndex = tokens.count - 1
        let (expr, _) = try parser.parseExpression(from: tokens, startingAt: 0, endingBefore: eofIndex)
        #expect(expr == BoundedFEExpression.arrayAccess(.identifier("arr"), .identifier("i")))
    }

    @Test func testBoundedParseMatchesFullParse() throws {
        let tokens = try tokenize("a + b * c")
        // Full parse
        let fullExpr = try parser.parseExpression(from: tokens)
        // Bounded parse with full range (excluding EOF)
        let eofIndex = tokens.count - 1
        let (boundedExpr, _) = try parser.parseExpression(from: tokens, startingAt: 0, endingBefore: eofIndex)
        #expect(boundedExpr == fullExpr)
    }
}
