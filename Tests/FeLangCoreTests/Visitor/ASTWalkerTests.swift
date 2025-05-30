import Testing
@testable import FeLangCore

@Suite("ASTWalker Tests")
struct ASTWalkerTests {

    // MARK: - Expression Identifier Collection Tests

    @Test func collectIdentifiersFromSimpleExpression() {
        let expr = Expression.identifier("x")
        let identifiers = ASTWalker.collectIdentifiers(from: expr)
        #expect(identifiers == Set(["x"]))
    }

    @Test func collectIdentifiersFromBinaryExpression() {
        let expr = Expression.binary(.add, .identifier("x"), .identifier("y"))
        let identifiers = ASTWalker.collectIdentifiers(from: expr)
        #expect(identifiers == Set(["x", "y"]))
    }

    @Test func collectIdentifiersFromComplexExpression() {
        // (x + y) * func(z, w)
        let expr = Expression.binary(.multiply,
            .binary(.add, .identifier("x"), .identifier("y")),
            .functionCall("func", [.identifier("z"), .identifier("w")])
        )
        let identifiers = ASTWalker.collectIdentifiers(from: expr)
        #expect(identifiers == Set(["x", "y", "z", "w"]))
    }

    @Test func collectIdentifiersFromArrayAccess() {
        let expr = Expression.arrayAccess(.identifier("arr"), .identifier("index"))
        let identifiers = ASTWalker.collectIdentifiers(from: expr)
        #expect(identifiers == Set(["arr", "index"]))
    }

    @Test func collectIdentifiersFromFieldAccess() {
        let expr = Expression.fieldAccess(.identifier("obj"), "property")
        let identifiers = ASTWalker.collectIdentifiers(from: expr)
        #expect(identifiers == Set(["obj"]))
    }

    @Test func collectIdentifiersFromLiteral() {
        let expr = Expression.literal(.integer(42))
        let identifiers = ASTWalker.collectIdentifiers(from: expr)
        #expect(identifiers.isEmpty)
    }

    // MARK: - Expression Node Counting Tests

    @Test func countNodesInSimpleExpression() {
        let expr = Expression.literal(.integer(42))
        let count = ASTWalker.countNodes(in: expr)
        #expect(count == 1)
    }

    @Test func countNodesInBinaryExpression() {
        let expr = Expression.binary(.add, .literal(.integer(1)), .literal(.integer(2)))
        let count = ASTWalker.countNodes(in: expr)
        #expect(count == 3) // binary + two literals
    }

    @Test func countNodesInComplexExpression() {
        // (x + 1) * func(y, 2)
        let expr = Expression.binary(.multiply,
            .binary(.add, .identifier("x"), .literal(.integer(1))),
            .functionCall("func", [.identifier("y"), .literal(.integer(2))])
        )
        let count = ASTWalker.countNodes(in: expr)
        #expect(count == 7) // binary(multiply) + binary(add) + x + 1 + func() + y + 2
    }

    @Test func countNodesInArrayAccess() {
        let expr = Expression.arrayAccess(.identifier("arr"), .literal(.integer(0)))
        let count = ASTWalker.countNodes(in: expr)
        #expect(count == 3) // arrayAccess + arr + 0
    }

    // MARK: - Expression Transformation Tests

    @Test func transformExpressionIdentity() {
        let expr = Expression.binary(.add, .identifier("x"), .literal(.integer(1)))
        let transformed = ASTWalker.transformExpression(expr) { $0 }
        #expect(transformed == expr)
    }

    @Test func transformExpressionReplacements() {
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
        #expect(transformed == expected)
    }

    @Test func transformExpressionNested() {
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
        #expect(transformed == expected)
    }

    // MARK: - Statement Identifier Collection Tests

    @Test func collectIdentifiersFromVariableDeclaration() {
        let stmt = Statement.variableDeclaration(VariableDeclaration(
            name: "x",
            type: .integer,
            initialValue: .identifier("y")
        ))
        let identifiers = ASTWalker.collectIdentifiers(from: stmt)
        #expect(identifiers == Set(["x", "y"]))
    }

    @Test func collectIdentifiersFromAssignment() {
        let stmt = Statement.assignment(.variable("x", .binary(.add, .identifier("y"), .identifier("z"))))
        let identifiers = ASTWalker.collectIdentifiers(from: stmt)
        #expect(identifiers == Set(["x", "y", "z"]))
    }

    @Test func collectIdentifiersFromIfStatement() {
        let ifStmt = IfStatement(
            condition: .identifier("flag"),
            thenBody: [.assignment(.variable("x", .identifier("y")))]
        )
        let stmt = Statement.ifStatement(ifStmt)
        let identifiers = ASTWalker.collectIdentifiers(from: stmt)
        #expect(identifiers == Set(["flag", "x", "y"]))
    }

    @Test func collectIdentifiersFromWhileStatement() {
        let whileStmt = WhileStatement(
            condition: .identifier("condition"),
            body: [.assignment(.variable("counter", .binary(.add, .identifier("counter"), .literal(.integer(1)))))]
        )
        let stmt = Statement.whileStatement(whileStmt)
        let identifiers = ASTWalker.collectIdentifiers(from: stmt)
        #expect(identifiers == Set(["condition", "counter"]))
    }

    @Test func collectIdentifiersFromForRangeStatement() {
        let rangeFor = ForStatement.RangeFor(
            variable: "i",
            start: .identifier("start"),
            end: .identifier("end"),
            body: [.assignment(.variable("sum", .binary(.add, .identifier("sum"), .identifier("i"))))]
        )
        let stmt = Statement.forStatement(.range(rangeFor))
        let identifiers = ASTWalker.collectIdentifiers(from: stmt)
        #expect(identifiers == Set(["i", "start", "end", "sum"]))
    }

    @Test func collectIdentifiersFromForEachStatement() {
        let forEach = ForStatement.ForEachLoop(
            variable: "item",
            iterable: .identifier("items"),
            body: [.expressionStatement(.identifier("item"))]
        )
        let stmt = Statement.forStatement(.forEach(forEach))
        let identifiers = ASTWalker.collectIdentifiers(from: stmt)
        #expect(identifiers == Set(["item", "items"]))
    }

    @Test func collectIdentifiersFromFunctionDeclaration() {
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
        #expect(identifiers == Set(["add", "a", "b", "result"]))
    }

    @Test func collectIdentifiersFromBlock() {
        let block = Statement.block([
            .variableDeclaration(VariableDeclaration(name: "x", type: .integer, initialValue: .literal(.integer(1)))),
            .assignment(.variable("y", .identifier("x")))
        ])
        let identifiers = ASTWalker.collectIdentifiers(from: block)
        #expect(identifiers == Set(["x", "y"]))
    }

    // MARK: - Statement Node Counting Tests

    @Test func countNodesInSimpleStatement() {
        let stmt = Statement.breakStatement
        let count = ASTWalker.countNodes(in: stmt)
        #expect(count == 1)
    }

    @Test func countNodesInAssignmentStatement() {
        let stmt = Statement.assignment(.variable("x", .binary(.add, .identifier("y"), .literal(.integer(1)))))
        let count = ASTWalker.countNodes(in: stmt)
        #expect(count == 4) // assignment + binary + y + 1
    }

    @Test func countNodesInIfStatement() {
        let ifStmt = IfStatement(
            condition: .identifier("flag"),
            thenBody: [.breakStatement, .breakStatement]
        )
        let stmt = Statement.ifStatement(ifStmt)
        let count = ASTWalker.countNodes(in: stmt)
        #expect(count == 4) // if + flag + break + break
    }

    @Test func countNodesInWhileStatement() {
        let whileStmt = WhileStatement(
            condition: .literal(.boolean(true)),
            body: [.breakStatement]
        )
        let stmt = Statement.whileStatement(whileStmt)
        let count = ASTWalker.countNodes(in: stmt)
        #expect(count == 3) // while + true + break
    }

    @Test func countNodesInForStatement() {
        let rangeFor = ForStatement.RangeFor(
            variable: "i",
            start: .literal(.integer(0)),
            end: .literal(.integer(10)),
            body: [.breakStatement]
        )
        let stmt = Statement.forStatement(.range(rangeFor))
        let count = ASTWalker.countNodes(in: stmt)
        #expect(count == 4) // for + 0 + 10 + break
    }

    @Test func countNodesInBlock() {
        let block = Statement.block([.breakStatement, .breakStatement, .breakStatement])
        let count = ASTWalker.countNodes(in: block)
        #expect(count == 4) // block + 3 breaks
    }

    // MARK: - Statement Expression Transformation Tests

    @Test func transformExpressionsInAssignment() {
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
        #expect(transformed == expected)
    }

    @Test func transformExpressionsInIfStatement() {
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
        #expect(transformed == expected)
    }

    @Test func transformExpressionsInVariableDeclaration() {
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
        #expect(transformed == expected)
    }

    @Test func transformExpressionsInReturnStatement() {
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
        #expect(transformed == expected)
    }

    @Test func transformExpressionsInBlock() {
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
        #expect(transformed == expected)
    }

    // MARK: - Performance Tests

    @Test func expressionWalkingPerformance() {
        // Build a moderately complex expression tree
        var expr = Expression.identifier("x")
        for index in 0..<50 {
            expr = .binary(.add, expr, .literal(.integer(index)))
        }

        // Simple performance test - just ensure it completes quickly
        let startTime = getCurrentTime()
        _ = ASTWalker.collectIdentifiers(from: expr)
        let timeElapsed = getCurrentTime() - startTime

        // Verify it completes within reasonable time (100ms)
        #expect(timeElapsed < 0.1)
    }

    @Test func statementWalkingPerformance() {
        // Build a moderately complex statement tree
        var statements: [Statement] = []
        for index in 0..<50 {
            statements.append(.assignment(.variable("x\(index)", .literal(.integer(index)))))
        }
        let block = Statement.block(statements)

        // Simple performance test - just ensure it completes quickly
        let startTime = getCurrentTime()
        _ = ASTWalker.countNodes(in: block)
        let timeElapsed = getCurrentTime() - startTime

        // Verify it completes within reasonable time (100ms)
        #expect(timeElapsed < 0.1)
    }

    // MARK: - Edge Cases

    @Test func emptyBlock() {
        let block = Statement.block([])
        let identifiers = ASTWalker.collectIdentifiers(from: block)
        #expect(identifiers.isEmpty)

        let count = ASTWalker.countNodes(in: block)
        #expect(count == 1) // Just the block itself
    }

    @Test func functionCallWithoutArguments() {
        let expr = Expression.functionCall("func", [])
        let identifiers = ASTWalker.collectIdentifiers(from: expr)
        #expect(identifiers.isEmpty)

        let count = ASTWalker.countNodes(in: expr)
        #expect(count == 1)
    }

    @Test func returnStatementWithoutExpression() {
        let stmt = Statement.returnStatement(ReturnStatement())
        let identifiers = ASTWalker.collectIdentifiers(from: stmt)
        #expect(identifiers.isEmpty)

        let count = ASTWalker.countNodes(in: stmt)
        #expect(count == 1)
    }

    @Test func variableDeclarationWithoutInitialValue() {
        let stmt = Statement.variableDeclaration(VariableDeclaration(
            name: "x",
            type: .integer
        ))
        let identifiers = ASTWalker.collectIdentifiers(from: stmt)
        #expect(identifiers == Set(["x"]))

        let count = ASTWalker.countNodes(in: stmt)
        #expect(count == 1)
    }
}
