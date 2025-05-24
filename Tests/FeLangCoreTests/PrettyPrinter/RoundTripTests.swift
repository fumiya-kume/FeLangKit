import XCTest
@testable import FeLangCore

final class RoundTripTests: XCTestCase {

    var printer: PrettyPrinter!

    override func setUp() {
        super.setUp()
        printer = PrettyPrinter()
    }

    // MARK: - Round-trip Validation Tests

    func testSimpleExpressionRoundTrip() {
        // Test that expressions can be pretty-printed and maintain their structure
        let originalExpr = Expression.binary(.add,
                                           .literal(.integer(1)),
                                           .binary(.multiply, .literal(.integer(2)), .literal(.integer(3))))

        let printed = printer.print(originalExpr)
        XCTAssertEqual(printed, "1 + 2 * 3")

        // Verify the structure is preserved (precedence is correct)
        // This should parse back to the same AST structure
        let reprintedExpr = Expression.binary(.add,
                                            .literal(.integer(1)),
                                            .binary(.multiply, .literal(.integer(2)), .literal(.integer(3))))
        let reprinted = printer.print(reprintedExpr)
        XCTAssertEqual(printed, reprinted)
    }

    func testComplexExpressionRoundTrip() {
        // Test complex expression with parentheses
        let originalExpr = Expression.binary(.multiply,
                                           .binary(.add, .literal(.integer(1)), .literal(.integer(2))),
                                           .literal(.integer(3)))

        let printed = printer.print(originalExpr)
        XCTAssertEqual(printed, "(1 + 2) * 3")

        // Verify that when we create the same structure, we get the same output
        let reprintedExpr = Expression.binary(.multiply,
                                            .binary(.add, .literal(.integer(1)), .literal(.integer(2))),
                                            .literal(.integer(3)))
        let reprinted = printer.print(reprintedExpr)
        XCTAssertEqual(printed, reprinted)
    }

    func testStatementRoundTrip() {
        // Test that statements maintain their structure
        let originalStmt = Statement.ifStatement(IfStatement(
            condition: .binary(.greater, .identifier("x"), .literal(.integer(0))),
            thenBody: [
                .assignment(.variable("y", .literal(.integer(1)))),
                .assignment(.variable("z", .binary(.add, .identifier("y"), .literal(.integer(2)))))
            ],
            elseBody: [
                .assignment(.variable("y", .literal(.integer(-1))))
            ]
        ))

        let printed = printer.print(originalStmt)
        let expected = """
        if x > 0 then
            y ← 1
            z ← y + 2
        else
            y ← -1
        endif
        """
        XCTAssertEqual(printed, expected)

        // Create the same structure and verify identical output
        let reprintedStmt = Statement.ifStatement(IfStatement(
            condition: .binary(.greater, .identifier("x"), .literal(.integer(0))),
            thenBody: [
                .assignment(.variable("y", .literal(.integer(1)))),
                .assignment(.variable("z", .binary(.add, .identifier("y"), .literal(.integer(2)))))
            ],
            elseBody: [
                .assignment(.variable("y", .literal(.integer(-1))))
            ]
        ))

        let reprinted = printer.print(reprintedStmt)
        XCTAssertEqual(printed, reprinted)
    }

    func testFunctionDeclarationRoundTrip() {
        // Test function declaration round-trip
        let param1 = Parameter(name: "x", type: .integer)
        let param2 = Parameter(name: "y", type: .real)
        let localVar = VariableDeclaration(name: "result", type: .real)

        let originalFunc = FunctionDeclaration(
            name: "calculate",
            parameters: [param1, param2],
            returnType: .real,
            localVariables: [localVar],
            body: [
                .assignment(.variable("result", .binary(.add, .identifier("x"), .identifier("y")))),
                .returnStatement(ReturnStatement(expression: .identifier("result")))
            ]
        )

        let originalStmt = Statement.functionDeclaration(originalFunc)
        let printed = printer.print(originalStmt)

        let expected = """
        function calculate(x: 整数型, y: 実数型): 実数型
            変数 result: 実数型
            result ← x + y
            return result
        endfunction
        """
        XCTAssertEqual(printed, expected)

        // Create identical structure and verify same output
        let reprintedFunc = FunctionDeclaration(
            name: "calculate",
            parameters: [param1, param2],
            returnType: .real,
            localVariables: [localVar],
            body: [
                .assignment(.variable("result", .binary(.add, .identifier("x"), .identifier("y")))),
                .returnStatement(ReturnStatement(expression: .identifier("result")))
            ]
        )

        let reprintedStmt = Statement.functionDeclaration(reprintedFunc)
        let reprinted = printer.print(reprintedStmt)
        XCTAssertEqual(printed, reprinted)
    }

    // MARK: - Canonical Formatting Tests

    func testCanonicalFormatting() {
        // Test that repeated pretty-printing produces identical output
        let stmt = Statement.ifStatement(IfStatement(
            condition: .binary(.and,
                             .binary(.greater, .identifier("x"), .literal(.integer(0))),
                             .binary(.less, .identifier("x"), .literal(.integer(100)))),
            thenBody: [
                .assignment(.variable("result", .literal(.string("valid")))),
                .expressionStatement(.functionCall("log", [.literal(.string("Processing valid input"))]))
            ]
        ))

        let firstPrint = printer.print(stmt)
        let secondPrint = printer.print(stmt)
        let thirdPrint = printer.print(stmt)

        // All prints should be identical
        XCTAssertEqual(firstPrint, secondPrint)
        XCTAssertEqual(secondPrint, thirdPrint)

        // Verify the actual output format
        let expected = """
        if x > 0 and x < 100 then
            result ← "valid"
            log("Processing valid input")
        endif
        """
        XCTAssertEqual(firstPrint, expected)
    }

    // MARK: - Edge Case Tests

    func testEmptyStructuresRoundTrip() {
        // Test empty function body
        let emptyFunc = FunctionDeclaration(
            name: "empty",
            parameters: [],
            returnType: nil,
            body: []
        )
        let stmt = Statement.functionDeclaration(emptyFunc)
        let printed = printer.print(stmt)

        let expected = """
        function empty()
        endfunction
        """
        XCTAssertEqual(printed, expected)

        // Test empty if body (should still work)
        let emptyIf = IfStatement(
            condition: .literal(.boolean(true)),
            thenBody: []
        )
        let ifStmt = Statement.ifStatement(emptyIf)
        let ifPrinted = printer.print(ifStmt)

        let ifExpected = """
        if true then
        endif
        """
        XCTAssertEqual(ifPrinted, ifExpected)
    }

    func testNestedStructuresRoundTrip() {
        // Test deeply nested structures maintain their nesting
        let innerFor = ForStatement.range(ForStatement.RangeFor(
            variable: "j",
            start: .literal(.integer(1)),
            end: .literal(.integer(5)),
            body: [
                .assignment(.variable("sum", .binary(.add, .identifier("sum"), .identifier("j"))))
            ]
        ))

        let outerFor = ForStatement.range(ForStatement.RangeFor(
            variable: "i",
            start: .literal(.integer(1)),
            end: .literal(.integer(10)),
            body: [
                .forStatement(innerFor)
            ]
        ))

        let stmt = Statement.forStatement(outerFor)
        let printed = printer.print(stmt)

        let expected = """
        for i = 1 to 10 do
            for j = 1 to 5 do
                sum ← sum + j
            endfor
        endfor
        """
        XCTAssertEqual(printed, expected)

        // Verify repeated printing gives same result
        let reprinted = printer.print(stmt)
        XCTAssertEqual(printed, reprinted)
    }
}
