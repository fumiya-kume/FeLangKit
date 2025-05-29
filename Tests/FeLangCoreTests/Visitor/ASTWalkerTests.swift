import XCTest
@testable import FeLangCore

final class ASTWalkerTests: XCTestCase {

    // MARK: - Expression Counter Tests

    func testExpressionCounterWithSimpleExpression() {
        let counter = ASTWalker.createExpressionCounter()

        let expr = Expression.literal(.integer(42))
        XCTAssertEqual(counter.visit(expr), 1)

        let identifier = Expression.identifier("x")
        XCTAssertEqual(counter.visit(identifier), 1)
    }

    func testExpressionCounterWithComplexExpression() {
        let counter = ASTWalker.createExpressionCounter()

        // (x + 1) * 2
        let expr = Expression.binary(.multiply,
                                   .binary(.add, .identifier("x"), .literal(.integer(1))),
                                   .literal(.integer(2)))

        // Should count: multiply node (1) + add node (1) + x (1) + 1 (1) + 2 (1) = 5
        XCTAssertEqual(counter.visit(expr), 5)
    }

    func testExpressionCounterWithFunctionCall() {
        let counter = ASTWalker.createExpressionCounter()

        // func(x, y + 1)
        let expr = Expression.functionCall("func", [
            .identifier("x"),
            .binary(.add, .identifier("y"), .literal(.integer(1)))
        ])

        // Should count: func call (1) + x (1) + add (1) + y (1) + 1 (1) = 5
        XCTAssertEqual(counter.visit(expr), 5)
    }

    // MARK: - Identifier Collector Tests

    func testIdentifierCollectorWithSimpleExpression() {
        let collector = ASTWalker.createIdentifierCollector()

        let expr = Expression.identifier("variable")
        XCTAssertEqual(collector.visit(expr), ["variable"])

        let literal = Expression.literal(.integer(42))
        XCTAssertEqual(collector.visit(literal), [])
    }

    func testIdentifierCollectorWithComplexExpression() {
        let collector = ASTWalker.createIdentifierCollector()

        // (x + y) * z
        let expr = Expression.binary(.multiply,
                                   .binary(.add, .identifier("x"), .identifier("y")),
                                   .identifier("z"))

        let identifiers = collector.visit(expr)
        XCTAssertEqual(Set(identifiers), Set(["x", "y", "z"]))
        XCTAssertEqual(identifiers.count, 3)
    }

    func testIdentifierCollectorWithFunctionCall() {
        let collector = ASTWalker.createIdentifierCollector()

        // func(a, b.field, arr[index])
        let expr = Expression.functionCall("func", [
            .identifier("a"),
            .fieldAccess(.identifier("b"), "field"),
            .arrayAccess(.identifier("arr"), .identifier("index"))
        ])

        let identifiers = collector.visit(expr)
        XCTAssertEqual(Set(identifiers), Set(["a", "b", "arr", "index"]))
    }

    // MARK: - Depth Calculator Tests

    func testDepthCalculatorWithSimpleExpression() {
        let calculator = ASTWalker.createDepthCalculator()

        let expr = Expression.literal(.integer(42))
        XCTAssertEqual(calculator.visit(expr), 1)

        let identifier = Expression.identifier("x")
        XCTAssertEqual(calculator.visit(identifier), 1)
    }

    func testDepthCalculatorWithNestedExpression() {
        let calculator = ASTWalker.createDepthCalculator()

        // ((x + y) * z) + w
        let expr = Expression.binary(.add,
                                   .binary(.multiply,
                                         .binary(.add, .identifier("x"), .identifier("y")),
                                         .identifier("z")),
                                   .identifier("w"))

        // Depth should be: add (1) + multiply (1) + add (1) + leaf = 4
        XCTAssertEqual(calculator.visit(expr), 4)
    }

    func testDepthCalculatorWithFunctionCall() {
        let calculator = ASTWalker.createDepthCalculator()

        // func(x + y, z)
        let expr = Expression.functionCall("func", [
            .binary(.add, .identifier("x"), .identifier("y")),
            .identifier("z")
        ])

        // Depth should be: func (1) + max(add depth (2), z depth (1)) = 3
        XCTAssertEqual(calculator.visit(expr), 3)
    }

    // MARK: - Statement Counter Tests

    func testStatementCounterWithSimpleStatement() {
        let counter = ASTWalker.createStatementCounter()

        let stmt = Statement.breakStatement
        XCTAssertEqual(counter.visit(stmt), 1)

        let assignment = Statement.assignment(.variable("x", .literal(.integer(42))))
        XCTAssertEqual(counter.visit(assignment), 1)
    }

    func testStatementCounterWithBlock() {
        let counter = ASTWalker.createStatementCounter()

        let block = Statement.block([
            .breakStatement,
            .assignment(.variable("x", .literal(.integer(42)))),
            .breakStatement
        ])

        // Should count: block (1) + 3 statements = 4
        XCTAssertEqual(counter.visit(block), 4)
    }

    func testStatementCounterWithControlFlow() {
        let counter = ASTWalker.createStatementCounter()

        let ifStmt = IfStatement(
            condition: .literal(.boolean(true)),
            thenBody: [.breakStatement, .breakStatement],
            elseBody: [.breakStatement]
        )
        let stmt = Statement.ifStatement(ifStmt)

        // Should count: if (1) + then body (2) + else body (1) = 4
        XCTAssertEqual(counter.visit(stmt), 4)
    }

    // MARK: - Declaration Collector Tests

    func testDeclarationCollectorWithSimpleDeclarations() {
        let collector = ASTWalker.createDeclarationCollector()

        let varDecl = Statement.variableDeclaration(VariableDeclaration(
            name: "x",
            type: .integer
        ))
        XCTAssertEqual(collector.visit(varDecl), ["x"])

        let constDecl = Statement.constantDeclaration(ConstantDeclaration(
            name: "PI",
            type: .real,
            initialValue: .literal(.real(3.14))
        ))
        XCTAssertEqual(collector.visit(constDecl), ["PI"])
    }

    func testDeclarationCollectorWithFunctionDeclaration() {
        let collector = ASTWalker.createDeclarationCollector()

        let funcDecl = Statement.functionDeclaration(FunctionDeclaration(
            name: "add",
            parameters: [
                Parameter(name: "a", type: .integer),
                Parameter(name: "b", type: .integer)
            ],
            returnType: .integer,
            localVariables: [
                VariableDeclaration(name: "temp", type: .integer)
            ],
            body: [
                .variableDeclaration(VariableDeclaration(name: "result", type: .integer)),
                .returnStatement(ReturnStatement(expression: .identifier("result")))
            ]
        ))

        let declarations = collector.visit(funcDecl)
        XCTAssertEqual(Set(declarations), Set(["add", "a", "b", "temp", "result"]))
    }

    func testDeclarationCollectorWithForStatement() {
        let collector = ASTWalker.createDeclarationCollector()

        let forStmt = Statement.forStatement(.range(ForStatement.RangeFor(
            variable: "i",
            start: .literal(.integer(0)),
            end: .literal(.integer(10)),
            body: [
                .variableDeclaration(VariableDeclaration(name: "temp", type: .integer))
            ]
        )))

        let declarations = collector.visit(forStmt)
        XCTAssertEqual(Set(declarations), Set(["i", "temp"]))
    }

    // MARK: - Traverser Tests

    func testExpressionTraverserCreation() {
        // Test that the traverser can be created without errors
        let traverser = ASTWalker.createExpressionTraverser { _ in
            // Do nothing - just testing creation
        }

        let expr = Expression.literal(.integer(42))
        traverser.visit(expr)

        // If we get here without crashes, the traverser works
        XCTAssertTrue(true)
    }

    func testStatementTraverserCreation() {
        // Test that the traverser can be created without errors
        let traverser = ASTWalker.createStatementTraverser { _ in
            // Do nothing - just testing creation
        }

        let stmt = Statement.breakStatement
        traverser.visit(stmt)

        // If we get here without crashes, the traverser works
        XCTAssertTrue(true)
    }
}
