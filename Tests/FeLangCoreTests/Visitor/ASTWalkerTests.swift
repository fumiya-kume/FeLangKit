import XCTest
@testable import FeLangCore

final class ASTWalkerTests: XCTestCase {

    // MARK: - Expression Identifier Collection Tests

    func testCollectIdentifiersFromSimpleExpression() {
        let expr = Expression.identifier("x")
        let identifiers = ASTWalker.collectIdentifiers(from: expr)
        XCTAssertEqual(identifiers, Set(["x"]))
    }

    func testCollectIdentifiersFromBinaryExpression() {
        let expr = Expression.binary(.add, .identifier("x"), .identifier("y"))
        let identifiers = ASTWalker.collectIdentifiers(from: expr)
        XCTAssertEqual(identifiers, Set(["x", "y"]))
    }

    func testCollectIdentifiersFromComplexExpression() {
        // (x + y) * func(z, w)
        let expr = Expression.binary(.multiply,
            .binary(.add, .identifier("x"), .identifier("y")),
            .functionCall("func", [.identifier("z"), .identifier("w")])
        )
        let identifiers = ASTWalker.collectIdentifiers(from: expr)
        XCTAssertEqual(identifiers, Set(["x", "y", "z", "w"]))
    }

    func testCollectIdentifiersFromArrayAccess() {
        let expr = Expression.arrayAccess(.identifier("arr"), .identifier("index"))
        let identifiers = ASTWalker.collectIdentifiers(from: expr)
        XCTAssertEqual(identifiers, Set(["arr", "index"]))
    }

    func testCollectIdentifiersFromFieldAccess() {
        let expr = Expression.fieldAccess(.identifier("obj"), "property")
        let identifiers = ASTWalker.collectIdentifiers(from: expr)
        XCTAssertEqual(identifiers, Set(["obj"]))
    }

    func testCollectIdentifiersFromLiteral() {
        let expr = Expression.literal(.integer(42))
        let identifiers = ASTWalker.collectIdentifiers(from: expr)
        XCTAssertTrue(identifiers.isEmpty)
    }

    // MARK: - Expression Node Counting Tests

    func testCountNodesInSimpleExpression() {
        let expr = Expression.literal(.integer(42))
        let count = ASTWalker.countNodes(in: expr)
        XCTAssertEqual(count, 1)
    }

    func testCountNodesInBinaryExpression() {
        let expr = Expression.binary(.add, .literal(.integer(1)), .literal(.integer(2)))
        let count = ASTWalker.countNodes(in: expr)
        XCTAssertEqual(count, 3) // binary + two literals
    }

    func testCountNodesInComplexExpression() {
        // (x + 1) * func(y, 2)
        let expr = Expression.binary(.multiply,
            .binary(.add, .identifier("x"), .literal(.integer(1))),
            .functionCall("func", [.identifier("y"), .literal(.integer(2))])
        )
        let count = ASTWalker.countNodes(in: expr)
        XCTAssertEqual(count, 7) // binary(multiply) + binary(add) + x + 1 + func() + y + 2
    }

    func testCountNodesInArrayAccess() {
        let expr = Expression.arrayAccess(.identifier("arr"), .literal(.integer(0)))
        let count = ASTWalker.countNodes(in: expr)
        XCTAssertEqual(count, 3) // arrayAccess + arr + 0
    }

    // MARK: - Expression Transformation Tests

    func testTransformExpressionIdentity() {
        let expr = Expression.binary(.add, .identifier("x"), .literal(.integer(1)))
        let transformed = ASTWalker.transformExpression(expr) { $0 }
        XCTAssertEqual(transformed, expr)
    }

    func testTransformExpressionReplacements() {
        let expr = Expression.binary(.add, .identifier("x"), .identifier("y"))
        let transformed = ASTWalker.transformExpression(expr) { expr in
            switch expr {
            case .identifier("x"):
                return .identifier("a")
            case .identifier("y"):
                return .identifier("b")
            default:
                return expr
            }
        }

        let expected = Expression.binary(.add, .identifier("a"), .identifier("b"))
        XCTAssertEqual(transformed, expected)
    }

    func testTransformExpressionNested() {
        // func(x, y + 1)
        let expr = Expression.functionCall("func", [
            .identifier("x"),
            .binary(.add, .identifier("y"), .literal(.integer(1)))
        ])

        let transformed = ASTWalker.transformExpression(expr) { expr in
            switch expr {
            case .identifier(let name):
                return .identifier(name.uppercased())
            default:
                return expr
            }
        }

        let expected = Expression.functionCall("func", [
            .identifier("X"),
            .binary(.add, .identifier("Y"), .literal(.integer(1)))
        ])
        XCTAssertEqual(transformed, expected)
    }

    // MARK: - Statement Identifier Collection Tests

    func testCollectIdentifiersFromVariableDeclaration() {
        let stmt = Statement.variableDeclaration(VariableDeclaration(
            name: "x",
            type: .integer,
            initialValue: .identifier("y")
        ))
        let identifiers = ASTWalker.collectIdentifiers(from: stmt)
        XCTAssertEqual(identifiers, Set(["x", "y"]))
    }

    func testCollectIdentifiersFromAssignment() {
        let stmt = Statement.assignment(.variable("x", .binary(.add, .identifier("y"), .identifier("z"))))
        let identifiers = ASTWalker.collectIdentifiers(from: stmt)
        XCTAssertEqual(identifiers, Set(["x", "y", "z"]))
    }

    func testCollectIdentifiersFromIfStatement() {
        let ifStmt = IfStatement(
            condition: .identifier("flag"),
            thenBody: [.assignment(.variable("x", .identifier("y")))]
        )
        let stmt = Statement.ifStatement(ifStmt)
        let identifiers = ASTWalker.collectIdentifiers(from: stmt)
        XCTAssertEqual(identifiers, Set(["flag", "x", "y"]))
    }

    func testCollectIdentifiersFromWhileStatement() {
        let whileStmt = WhileStatement(
            condition: .identifier("condition"),
            body: [.assignment(.variable("counter", .binary(.add, .identifier("counter"), .literal(.integer(1)))))]
        )
        let stmt = Statement.whileStatement(whileStmt)
        let identifiers = ASTWalker.collectIdentifiers(from: stmt)
        XCTAssertEqual(identifiers, Set(["condition", "counter"]))
    }

    func testCollectIdentifiersFromForRangeStatement() {
        let rangeFor = ForStatement.RangeFor(
            variable: "i",
            start: .identifier("start"),
            end: .identifier("end"),
            body: [.assignment(.variable("sum", .binary(.add, .identifier("sum"), .identifier("i"))))]
        )
        let stmt = Statement.forStatement(.range(rangeFor))
        let identifiers = ASTWalker.collectIdentifiers(from: stmt)
        XCTAssertEqual(identifiers, Set(["i", "start", "end", "sum"]))
    }

    func testCollectIdentifiersFromForEachStatement() {
        let forEach = ForStatement.ForEachLoop(
            variable: "item",
            iterable: .identifier("items"),
            body: [.expressionStatement(.identifier("item"))]
        )
        let stmt = Statement.forStatement(.forEach(forEach))
        let identifiers = ASTWalker.collectIdentifiers(from: stmt)
        XCTAssertEqual(identifiers, Set(["item", "items"]))
    }

    func testCollectIdentifiersFromFunctionDeclaration() {
        let funcDecl = FunctionDeclaration(
            name: "add",
            parameters: [Parameter(name: "a", type: .integer), Parameter(name: "b", type: .integer)],
            returnType: .integer,
            localVariables: [VariableDeclaration(name: "result", type: .integer)],
            body: [
                .assignment(.variable("result", .binary(.add, .identifier("a"), .identifier("b")))),
                .returnStatement(ReturnStatement(expression: .identifier("result")))
            ]
        )
        let stmt = Statement.functionDeclaration(funcDecl)
        let identifiers = ASTWalker.collectIdentifiers(from: stmt)
        XCTAssertEqual(identifiers, Set(["add", "a", "b", "result"]))
    }

    func testCollectIdentifiersFromBlock() {
        let block = Statement.block([
            .variableDeclaration(VariableDeclaration(name: "x", type: .integer, initialValue: .literal(.integer(1)))),
            .assignment(.variable("y", .identifier("x")))
        ])
        let identifiers = ASTWalker.collectIdentifiers(from: block)
        XCTAssertEqual(identifiers, Set(["x", "y"]))
    }

    // MARK: - Statement Node Counting Tests

    func testCountNodesInSimpleStatement() {
        let stmt = Statement.breakStatement
        let count = ASTWalker.countNodes(in: stmt)
        XCTAssertEqual(count, 1)
    }

    func testCountNodesInAssignmentStatement() {
        let stmt = Statement.assignment(.variable("x", .binary(.add, .identifier("y"), .literal(.integer(1)))))
        let count = ASTWalker.countNodes(in: stmt)
        XCTAssertEqual(count, 4) // assignment + binary + y + 1
    }

    func testCountNodesInIfStatement() {
        let ifStmt = IfStatement(
            condition: .identifier("flag"),
            thenBody: [.breakStatement, .breakStatement]
        )
        let stmt = Statement.ifStatement(ifStmt)
        let count = ASTWalker.countNodes(in: stmt)
        XCTAssertEqual(count, 4) // if + flag + break + break
    }

    func testCountNodesInWhileStatement() {
        let whileStmt = WhileStatement(
            condition: .literal(.boolean(true)),
            body: [.breakStatement]
        )
        let stmt = Statement.whileStatement(whileStmt)
        let count = ASTWalker.countNodes(in: stmt)
        XCTAssertEqual(count, 3) // while + true + break
    }

    func testCountNodesInForStatement() {
        let rangeFor = ForStatement.RangeFor(
            variable: "i",
            start: .literal(.integer(0)),
            end: .literal(.integer(10)),
            body: [.breakStatement]
        )
        let stmt = Statement.forStatement(.range(rangeFor))
        let count = ASTWalker.countNodes(in: stmt)
        XCTAssertEqual(count, 4) // for + 0 + 10 + break
    }

    func testCountNodesInBlock() {
        let block = Statement.block([.breakStatement, .breakStatement, .breakStatement])
        let count = ASTWalker.countNodes(in: block)
        XCTAssertEqual(count, 4) // block + 3 breaks
    }

    // MARK: - Statement Expression Transformation Tests

    func testTransformExpressionsInAssignment() {
        let stmt = Statement.assignment(.variable("x", .identifier("y")))
        let transformed = ASTWalker.transformExpressions(in: stmt) { expr in
            switch expr {
            case .identifier("y"):
                return .identifier("z")
            default:
                return expr
            }
        }

        let expected = Statement.assignment(.variable("x", .identifier("z")))
        XCTAssertEqual(transformed, expected)
    }

    func testTransformExpressionsInIfStatement() {
        let ifStmt = IfStatement(
            condition: .identifier("flag"),
            thenBody: [.assignment(.variable("x", .identifier("y")))]
        )
        let stmt = Statement.ifStatement(ifStmt)

        let transformed = ASTWalker.transformExpressions(in: stmt) { expr in
            switch expr {
            case .identifier(let name):
                return .identifier(name.uppercased())
            default:
                return expr
            }
        }

        let expectedIfStmt = IfStatement(
            condition: .identifier("FLAG"),
            thenBody: [.assignment(.variable("x", .identifier("Y")))]
        )
        let expected = Statement.ifStatement(expectedIfStmt)
        XCTAssertEqual(transformed, expected)
    }

    func testTransformExpressionsInVariableDeclaration() {
        let stmt = Statement.variableDeclaration(VariableDeclaration(
            name: "x",
            type: .integer,
            initialValue: .identifier("y")
        ))

        let transformed = ASTWalker.transformExpressions(in: stmt) { expr in
            switch expr {
            case .identifier("y"):
                return .literal(.integer(42))
            default:
                return expr
            }
        }

        let expected = Statement.variableDeclaration(VariableDeclaration(
            name: "x",
            type: .integer,
            initialValue: .literal(.integer(42))
        ))
        XCTAssertEqual(transformed, expected)
    }

    func testTransformExpressionsInReturnStatement() {
        let stmt = Statement.returnStatement(ReturnStatement(expression: .identifier("result")))

        let transformed = ASTWalker.transformExpressions(in: stmt) { expr in
            switch expr {
            case .identifier("result"):
                return .literal(.integer(0))
            default:
                return expr
            }
        }

        let expected = Statement.returnStatement(ReturnStatement(expression: .literal(.integer(0))))
        XCTAssertEqual(transformed, expected)
    }

    func testTransformExpressionsInBlock() {
        let block = Statement.block([
            .assignment(.variable("x", .identifier("y"))),
            .expressionStatement(.identifier("z"))
        ])

        let transformed = ASTWalker.transformExpressions(in: block) { expr in
            switch expr {
            case .identifier(let name):
                return .identifier(name.uppercased())
            default:
                return expr
            }
        }

        let expected = Statement.block([
            .assignment(.variable("x", .identifier("Y"))),
            .expressionStatement(.identifier("Z"))
        ])
        XCTAssertEqual(transformed, expected)
    }

    // MARK: - Performance Tests

    func testExpressionWalkingPerformance() {
        // Build a moderately complex expression tree
        var expr = Expression.identifier("x")
        for index in 0..<50 {
            expr = .binary(.add, expr, .literal(.integer(index)))
        }

        measure {
            _ = ASTWalker.collectIdentifiers(from: expr)
        }
    }

    func testStatementWalkingPerformance() {
        // Build a moderately complex statement tree
        var statements: [Statement] = []
        for index in 0..<50 {
            statements.append(.assignment(.variable("x\(index)", .literal(.integer(index)))))
        }
        let block = Statement.block(statements)

        measure {
            _ = ASTWalker.countNodes(in: block)
        }
    }

    // MARK: - Edge Cases

    func testEmptyBlock() {
        let block = Statement.block([])
        let identifiers = ASTWalker.collectIdentifiers(from: block)
        XCTAssertTrue(identifiers.isEmpty)

        let count = ASTWalker.countNodes(in: block)
        XCTAssertEqual(count, 1) // Just the block itself
    }

    func testFunctionCallWithoutArguments() {
        let expr = Expression.functionCall("func", [])
        let identifiers = ASTWalker.collectIdentifiers(from: expr)
        XCTAssertTrue(identifiers.isEmpty)

        let count = ASTWalker.countNodes(in: expr)
        XCTAssertEqual(count, 1)
    }

    func testReturnStatementWithoutExpression() {
        let stmt = Statement.returnStatement(ReturnStatement())
        let identifiers = ASTWalker.collectIdentifiers(from: stmt)
        XCTAssertTrue(identifiers.isEmpty)

        let count = ASTWalker.countNodes(in: stmt)
        XCTAssertEqual(count, 1)
    }

    func testVariableDeclarationWithoutInitialValue() {
        let stmt = Statement.variableDeclaration(VariableDeclaration(
            name: "x",
            type: .integer
        ))
        let identifiers = ASTWalker.collectIdentifiers(from: stmt)
        XCTAssertEqual(identifiers, Set(["x"]))

        let count = ASTWalker.countNodes(in: stmt)
        XCTAssertEqual(count, 1)
    }
}
