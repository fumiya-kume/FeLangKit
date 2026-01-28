import Testing
@testable import FeLangCore

@Suite("Statement Expression Delegation Tests")
struct StatementExpressionDelegationTests {

    let parser = StatementParser()

    private func parseStatements(_ input: String) throws -> [Statement] {
        let tokens = try ParsingTokenizer.tokenize(input)
        return try parser.parseStatements(from: tokens)
    }

    // MARK: - Condition Expression Tests

    @Test func testIfConditionExpression() throws {
        let statements = try parseStatements("if x > 0 then\nx ← 1\nendif")
        #expect(statements.count == 1)
        guard case .ifStatement(let ifStmt) = statements[0] else {
            Issue.record("Expected if statement")
            return
        }
        #expect(ifStmt.condition == Expression.binary(.greater, .identifier("x"), .literal(.integer(0))))
    }

    @Test func testWhileConditionWithFunctionCall() throws {
        let statements = try parseStatements("while isEmpty(list) do\nbreak\nendwhile")
        #expect(statements.count == 1)
        guard case .whileStatement(let whileStmt) = statements[0] else {
            Issue.record("Expected while statement")
            return
        }
        #expect(whileStmt.condition == Expression.functionCall("isEmpty", [.identifier("list")]))
    }

    @Test func testForRangeExpressions() throws {
        let statements = try parseStatements("for i ← a + 1 to b * 2 do\nwriteLine(i)\nendfor")
        #expect(statements.count == 1)
        guard case .forStatement(.range(let rangeFor)) = statements[0] else {
            Issue.record("Expected for range statement")
            return
        }
        #expect(rangeFor.start == Expression.binary(.add, .identifier("a"), .literal(.integer(1))))
        #expect(rangeFor.end == Expression.binary(.multiply, .identifier("b"), .literal(.integer(2))))
    }

    // MARK: - Assignment Expression Tests

    @Test func testAssignmentRHSExpression() throws {
        let statements = try parseStatements("x ← a + b * c")
        #expect(statements.count == 1)
        guard case .assignment(.variable(_, let value)) = statements[0] else {
            Issue.record("Expected assignment statement")
            return
        }
        let expected = Expression.binary(
            .add,
            .identifier("a"),
            Expression.binary(.multiply, .identifier("b"), .identifier("c"))
        )
        #expect(value == expected)
    }

    @Test func testDeclarationInitialValue() throws {
        let statements = try parseStatements("変数 x: 整数型 ← arr[0] + 1")
        #expect(statements.count == 1)
        guard case .variableDeclaration(let decl) = statements[0] else {
            Issue.record("Expected variable declaration")
            return
        }
        #expect(decl.initialValue != nil)
        let expected = Expression.binary(
            .add,
            Expression.arrayAccess(.identifier("arr"), .literal(.integer(0))),
            .literal(.integer(1))
        )
        #expect(decl.initialValue == expected)
    }

    // MARK: - Nested Control Flow Tests

    @Test func testNestedControlFlowExpressions() throws {
        let input = "if a > 0 then\nwhile b < 10 do\nb ← b + 1\nendwhile\nendif"
        let statements = try parseStatements(input)
        #expect(statements.count == 1)

        guard case .ifStatement(let ifStmt) = statements[0] else {
            Issue.record("Expected if statement")
            return
        }
        #expect(ifStmt.condition == Expression.binary(.greater, .identifier("a"), .literal(.integer(0))))

        guard case .whileStatement(let whileStmt) = ifStmt.thenBody[0] else {
            Issue.record("Expected while statement in body")
            return
        }
        #expect(whileStmt.condition == Expression.binary(.less, .identifier("b"), .literal(.integer(10))))
    }

    // MARK: - Expression Statement Tests

    @Test func testReturnExpression() throws {
        let statements = try parseStatements("return a + b")
        #expect(statements.count == 1)
        guard case .returnStatement(let retStmt) = statements[0] else {
            Issue.record("Expected return statement")
            return
        }
        #expect(retStmt.expression == Expression.binary(.add, .identifier("a"), .identifier("b")))
    }

    @Test func testMethodCallExpression() throws {
        let statements = try parseStatements("obj.method(x + 1)")
        #expect(statements.count == 1)
        guard case .expressionStatement(let expr) = statements[0] else {
            Issue.record("Expected expression statement")
            return
        }
        let expected = Expression.methodCall(
            .identifier("obj"),
            "method",
            [Expression.binary(.add, .identifier("x"), .literal(.integer(1)))]
        )
        #expect(expr == expected)
    }
}
