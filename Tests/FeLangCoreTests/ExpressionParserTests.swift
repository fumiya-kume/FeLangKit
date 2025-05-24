import Foundation
import Testing
@testable import FeLangCore

// Alias to avoid conflict with Foundation.Expression
typealias FEExpression = FeLangCore.Expression

@Suite("ExpressionParser Tests")
struct ExpressionParserTests {

    // MARK: - Helper Methods

    /// Helper method to tokenize and parse an expression
    private func parseExpression(_ input: String) throws -> FEExpression {
        let tokens = try ParsingTokenizer.tokenize(input)
        let parser = ExpressionParser()
        return try parser.parseExpression(from: tokens)
    }

    /// Helper method to create a source position for testing
    private func testPosition() -> SourcePosition {
        return SourcePosition(line: 1, column: 1, offset: 0)
    }

    // MARK: - Basic Literal Tests

    @Test func testIntegerLiteral() throws {
        let expr = try parseExpression("42")
        #expect(expr == .literal(Literal.integer(42)))
    }

    @Test func testRealLiteral() throws {
        let expr = try parseExpression("3.14")
        #expect(expr == .literal(Literal.real(3.14)))
    }

    @Test func testStringLiteral() throws {
        let expr = try parseExpression("'hello'")
        #expect(expr == .literal(Literal.string("hello")))
    }

    @Test func testCharacterLiteral() throws {
        let expr = try parseExpression("'A'")
        #expect(expr == .literal(.character("A")))
    }

    @Test func testBooleanLiterals() throws {
        let trueExpr = try parseExpression("true")
        let falseExpr = try parseExpression("false")

        #expect(trueExpr == .literal(.boolean(true)))
        #expect(falseExpr == .literal(.boolean(false)))
    }

    @Test func testIdentifier() throws {
        let expr = try parseExpression("variable")
        #expect(expr == .identifier("variable"))
    }

    // MARK: - Basic Arithmetic Tests

    @Test func testSimpleAddition() throws {
        let expr = try parseExpression("1 + 2")
        let expected = Expression.binary(.add, .literal(.integer(1)), .literal(.integer(2)))
        #expect(expr == expected)
    }

    @Test func testSimpleSubtraction() throws {
        let expr = try parseExpression("5 - 3")
        let expected = Expression.binary(.subtract, .literal(.integer(5)), .literal(.integer(3)))
        #expect(expr == expected)
    }

    @Test func testSimpleMultiplication() throws {
        let expr = try parseExpression("4 * 5")
        let expected = Expression.binary(.multiply, .literal(.integer(4)), .literal(.integer(5)))
        #expect(expr == expected)
    }

    @Test func testSimpleDivision() throws {
        let expr = try parseExpression("10 / 2")
        let expected = Expression.binary(.divide, .literal(.integer(10)), .literal(.integer(2)))
        #expect(expr == expected)
    }

    @Test func testModulo() throws {
        let expr = try parseExpression("7 % 3")
        let expected = Expression.binary(.modulo, .literal(.integer(7)), .literal(.integer(3)))
        #expect(expr == expected)
    }

    // MARK: - Precedence Tests

    @Test func testArithmeticPrecedence() throws {
        // 3 + 4 * 5 should be parsed as 3 + (4 * 5) = 23
        let expr = try parseExpression("3 + 4 * 5")
        let expected = Expression.binary(
            .add,
            .literal(.integer(3)),
            .binary(.multiply, .literal(.integer(4)), .literal(.integer(5)))
        )
        #expect(expr == expected)
    }

    @Test func testParenthesesOverridePrecedence() throws {
        // (3 + 4) * 5 should be parsed as (3 + 4) * 5 = 35
        let expr = try parseExpression("(3 + 4) * 5")
        let expected = Expression.binary(
            .multiply,
            .binary(.add, .literal(.integer(3)), .literal(.integer(4))),
            .literal(.integer(5))
        )
        #expect(expr == expected)
    }

    @Test func testMultiplicationDivisionPrecedence() throws {
        // 8 / 2 * 3 should be parsed as (8 / 2) * 3 = 12 (left associative)
        let expr = try parseExpression("8 / 2 * 3")
        let expected = Expression.binary(
            .multiply,
            .binary(.divide, .literal(.integer(8)), .literal(.integer(2))),
            .literal(.integer(3))
        )
        #expect(expr == expected)
    }

    // MARK: - Left Associativity Tests

    @Test func testLeftAssociativityAddition() throws {
        // 1 + 2 + 3 should be parsed as ((1 + 2) + 3) = 6
        let expr = try parseExpression("1 + 2 + 3")
        let expected = Expression.binary(
            .add,
            .binary(.add, .literal(.integer(1)), .literal(.integer(2))),
            .literal(.integer(3))
        )
        #expect(expr == expected)
    }

    @Test func testLeftAssociativityMultiplication() throws {
        // 2 * 3 * 4 should be parsed as ((2 * 3) * 4) = 24
        let expr = try parseExpression("2 * 3 * 4")
        let expected = Expression.binary(
            .multiply,
            .binary(.multiply, .literal(.integer(2)), .literal(.integer(3))),
            .literal(.integer(4))
        )
        #expect(expr == expected)
    }

    @Test func testLeftAssociativitySubtraction() throws {
        // 10 - 3 - 2 should be parsed as ((10 - 3) - 2) = 5
        let expr = try parseExpression("10 - 3 - 2")
        let expected = Expression.binary(
            .subtract,
            .binary(.subtract, .literal(.integer(10)), .literal(.integer(3))),
            .literal(.integer(2))
        )
        #expect(expr == expected)
    }

    // MARK: - Comparison Operator Tests

    @Test func testEqualityOperator() throws {
        let expr = try parseExpression("x = 5")
        let expected = Expression.binary(.equal, .identifier("x"), .literal(.integer(5)))
        #expect(expr == expected)
    }

    @Test func testInequalityOperator() throws {
        let expr = try parseExpression("y ≠ 0")
        let expected = Expression.binary(.notEqual, .identifier("y"), .literal(.integer(0)))
        #expect(expr == expected)
    }

    @Test func testComparisonOperators() throws {
        let tests = [
            ("a > b", BinaryOperator.greater),
            ("a ≧ b", BinaryOperator.greaterEqual),
            ("a < b", BinaryOperator.less),
            ("a ≦ b", BinaryOperator.lessEqual)
        ]

        for (input, expectedOp) in tests {
            let expr = try parseExpression(input)
            let expected = Expression.binary(expectedOp, .identifier("a"), .identifier("b"))
            #expect(expr == expected)
        }
    }

    // MARK: - Logical Operator Tests

    @Test func testLogicalAnd() throws {
        let expr = try parseExpression("x > 0 and y < 10")
        let expected = Expression.binary(
            .and,
            .binary(.greater, .identifier("x"), .literal(.integer(0))),
            .binary(.less, .identifier("y"), .literal(.integer(10)))
        )
        #expect(expr == expected)
    }

    @Test func testLogicalOr() throws {
        let expr = try parseExpression("a = 1 or b = 2")
        let expected = Expression.binary(
            .or,
            .binary(.equal, .identifier("a"), .literal(.integer(1))),
            .binary(.equal, .identifier("b"), .literal(.integer(2)))
        )
        #expect(expr == expected)
    }

    @Test func testLogicalPrecedence() throws {
        // a = b and c ≠ d should be parsed as (a = b) and (c ≠ d)
        let expr = try parseExpression("a = b and c ≠ d")
        let expected = Expression.binary(
            .and,
            .binary(.equal, .identifier("a"), .identifier("b")),
            .binary(.notEqual, .identifier("c"), .identifier("d"))
        )
        #expect(expr == expected)
    }

    // MARK: - Unary Operator Tests

    @Test func testUnaryNot() throws {
        let expr = try parseExpression("not x")
        let expected = Expression.unary(.not, .identifier("x"))
        #expect(expr == expected)
    }

    @Test func testUnaryPlus() throws {
        let expr = try parseExpression("+42")
        let expected = Expression.unary(.plus, .literal(.integer(42)))
        #expect(expr == expected)
    }

    @Test func testUnaryMinus() throws {
        let expr = try parseExpression("-5")
        let expected = Expression.unary(.minus, .literal(.integer(5)))
        #expect(expr == expected)
    }

    @Test func testUnaryPrecedence() throws {
        // not x or y should be parsed as (not x) or y
        let expr = try parseExpression("not x or y")
        let expected = Expression.binary(
            .or,
            .unary(.not, .identifier("x")),
            .identifier("y")
        )
        #expect(expr == expected)
    }

    // MARK: - Array Access Tests

    @Test func testSimpleArrayAccess() throws {
        let expr = try parseExpression("array[0]")
        let expected = Expression.arrayAccess(.identifier("array"), .literal(.integer(0)))
        #expect(expr == expected)
    }

    @Test func testArrayAccessWithExpression() throws {
        // array[i + 1] * 2 should be parsed as (array[(i + 1)]) * 2
        let expr = try parseExpression("array[i + 1] * 2")
        let expected = Expression.binary(
            .multiply,
            .arrayAccess(
                .identifier("array"),
                .binary(.add, .identifier("i"), .literal(.integer(1)))
            ),
            .literal(.integer(2))
        )
        #expect(expr == expected)
    }

    // MARK: - Function Call Tests

    @Test func testSimpleFunctionCall() throws {
        let expr = try parseExpression("max(a, b)")
        let expected = Expression.functionCall("max", [.identifier("a"), .identifier("b")])
        #expect(expr == expected)
    }

    @Test func testFunctionCallWithExpressions() throws {
        // func(a + b, c * d) should be parsed as func((a + b), (c * d))
        let expr = try parseExpression("func(a + b, c * d)")
        let expected = Expression.functionCall(
            "func",
            [
                .binary(.add, .identifier("a"), .identifier("b")),
                .binary(.multiply, .identifier("c"), .identifier("d"))
            ]
        )
        #expect(expr == expected)
    }

    @Test func testFunctionCallNoArguments() throws {
        let expr = try parseExpression("getValue()")
        let expected = Expression.functionCall("getValue", [])
        #expect(expr == expected)
    }

    // MARK: - Complex Expression Tests

    @Test func testComplexArithmeticExpression() throws {
        // 1 + 2 * 3 - 4 / 2 should be parsed as (1 + (2 * 3)) - (4 / 2)
        let expr = try parseExpression("1 + 2 * 3 - 4 / 2")
        let expected = Expression.binary(
            .subtract,
            .binary(
                .add,
                .literal(.integer(1)),
                .binary(.multiply, .literal(.integer(2)), .literal(.integer(3)))
            ),
            .binary(.divide, .literal(.integer(4)), .literal(.integer(2)))
        )
        #expect(expr == expected)
    }

    @Test func testComplexLogicalExpression() throws {
        // not (x > 0 and y < max(a, b))
        let expr = try parseExpression("not (x > 0 and y < max(a, b))")
        let expected = Expression.unary(
            .not,
            .binary(
                .and,
                .binary(.greater, .identifier("x"), .literal(.integer(0))),
                .binary(
                    .less,
                    .identifier("y"),
                    .functionCall("max", [.identifier("a"), .identifier("b")])
                )
            )
        )
        #expect(expr == expected)
    }

    @Test func testMixedPrecedenceExpression() throws {
        // x + y * z > a and b ≠ c or d
        // Should be parsed as: (((x + (y * z)) > a) and (b ≠ c)) or d
        let expr = try parseExpression("x + y * z > a and b ≠ c or d")
        let expected = Expression.binary(
            .or,
            .binary(
                .and,
                .binary(
                    .greater,
                    .binary(
                        .add,
                        .identifier("x"),
                        .binary(.multiply, .identifier("y"), .identifier("z"))
                    ),
                    .identifier("a")
                ),
                .binary(.notEqual, .identifier("b"), .identifier("c"))
            ),
            .identifier("d")
        )
        #expect(expr == expected)
    }

    // MARK: - Error Handling Tests

    @Test func testUnexpectedEndOfInput() throws {
        #expect(throws: ParsingError.self) {
            try parseExpression("")
        }
    }

    @Test func testIncompleteExpression() throws {
        #expect(throws: ParsingError.self) {
            try parseExpression("3 +")
        }
    }

    @Test func testMismatchedParentheses() throws {
        #expect(throws: ParsingError.self) {
            try parseExpression("(3 + 4")
        }
    }

    @Test func testUnexpectedToken() throws {
        #expect(throws: ParsingError.self) {
            try parseExpression("3 + +")
        }
    }

    @Test func testInvalidFunctionCall() throws {
        #expect(throws: ParsingError.self) {
            try parseExpression("123()")
        }
    }

    // MARK: - Edge Cases

    @Test func testNestedParentheses() throws {
        let expr = try parseExpression("((1 + 2) * (3 + 4))")
        let expected = Expression.binary(
            .multiply,
            .binary(.add, .literal(.integer(1)), .literal(.integer(2))),
            .binary(.add, .literal(.integer(3)), .literal(.integer(4)))
        )
        #expect(expr == expected)
    }

    @Test func testChainedArrayAccess() throws {
        let expr = try parseExpression("matrix[i][j]")
        let expected = Expression.arrayAccess(
            .arrayAccess(.identifier("matrix"), .identifier("i")),
            .identifier("j")
        )
        #expect(expr == expected)
    }

    @Test func testMixedPostfixOperations() throws {
        // func(x)[0] should be parsed as (func(x))[0]
        let expr = try parseExpression("getValue()[0]")
        let expected = Expression.arrayAccess(
            .functionCall("getValue", []),
            .literal(.integer(0))
        )
        #expect(expr == expected)
    }

    // MARK: - Performance Tests

    @Test func testLargeExpression() throws {
        // Test parsing of a large expression with many terms
        let input = Array(1...50).map(String.init).joined(separator: " + ")
        let expr = try parseExpression(input)

        // Verify it's a left-associative addition chain
        var current = expr
        var count = 0
        while case .binary(.add, let left, _) = current {
            count += 1
            current = left
        }

        // The leftmost element should be a literal
        #expect(current == .literal(.integer(1)))
        #expect(count == 49) // 49 additions for 50 numbers
    }

    // MARK: - Real-world Examples

    @Test func testRealWorldExample1() throws {
        // Quadratic formula: (-b + sqrt(b * b - 4 * a * c)) / (2 * a)
        let expr = try parseExpression("(-b + sqrt(b * b - 4 * a * c)) / (2 * a)")

        // Just verify it parses without error and has the expected top-level structure
        guard case .binary(.divide, let numerator, let denominator) = expr else {
            Issue.record("Expected division at top level")
            return
        }

        // Verify denominator is 2 * a
        guard case .binary(.multiply, .literal(.integer(2)), .identifier("a")) = denominator else {
            Issue.record("Expected '2 * a' as denominator")
            return
        }

        // Verify numerator is a parenthesized addition
        guard case .binary(.add, .unary(.minus, .identifier("b")), .functionCall("sqrt", _)) = numerator else {
            Issue.record("Expected '(-b + sqrt(...))' as numerator")
            return
        }
    }

    @Test func testRealWorldExample2() throws {
        // Conditional expression: x ≧ 0 and x ≦ 100 and y > min(a, b)
        let expr = try parseExpression("x ≧ 0 and x ≦ 100 and y > min(a, b)")

        // Verify it parses as left-associative and operations
        guard case .binary(.and, let left, let right) = expr else {
            Issue.record("Expected 'and' at top level")
            return
        }

        guard case .binary(.and, _, _) = left else {
            Issue.record("Expected nested 'and' on left side")
            return
        }

        guard case .binary(.greater, .identifier("y"), .functionCall("min", _)) = right else {
            Issue.record("Expected 'y > min(a, b)' on right side")
            return
        }
    }
}
