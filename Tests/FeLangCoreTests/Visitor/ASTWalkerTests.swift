import XCTest
@testable import FeLangCore

final class ASTWalkerTests: XCTestCase {
    
    // MARK: - Expression Walking Tests
    
    func testWalkSimpleExpression() {
        let expr = Expression.literal(.integer(42))
        let walked = ASTWalker.walkExpression(expr)
        
        XCTAssertEqual(walked.count, 1)
        XCTAssertEqual(walked[0], expr)
    }
    
    func testWalkBinaryExpression() {
        let left = Expression.literal(.integer(1))
        let right = Expression.literal(.integer(2))
        let expr = Expression.binary(.add, left, right)
        
        let walked = ASTWalker.walkExpression(expr)
        
        XCTAssertEqual(walked.count, 3)
        XCTAssertEqual(walked[0], expr) // Root node first in depth-first
        XCTAssertEqual(walked[1], left)
        XCTAssertEqual(walked[2], right)
    }
    
    func testWalkComplexExpression() {
        // Create expression: (a + b) * func(x, y[0])
        let a = Expression.identifier("a")
        let b = Expression.identifier("b")
        let x = Expression.identifier("x")
        let y = Expression.identifier("y")
        let zero = Expression.literal(.integer(0))
        
        let addExpr = Expression.binary(.add, a, b)
        let arrayAccess = Expression.arrayAccess(y, zero)
        let funcCall = Expression.functionCall("func", [x, arrayAccess])
        let root = Expression.binary(.multiply, addExpr, funcCall)
        
        let walked = ASTWalker.walkExpression(root)
        
        XCTAssertEqual(walked.count, 8) // All nodes in the tree
        XCTAssertEqual(walked[0], root) // Root first
        
        // Verify all nodes are present
        XCTAssertTrue(walked.contains(a))
        XCTAssertTrue(walked.contains(b))
        XCTAssertTrue(walked.contains(x))
        XCTAssertTrue(walked.contains(y))
        XCTAssertTrue(walked.contains(zero))
        XCTAssertTrue(walked.contains(addExpr))
        XCTAssertTrue(walked.contains(arrayAccess))
        XCTAssertTrue(walked.contains(funcCall))
    }
    
    func testWalkExpressionWithDepthLimit() {
        // Create nested expression: ((1 + 2) + 3)
        let innerBinary = Expression.binary(.add, .literal(.integer(1)), .literal(.integer(2)))
        let outerBinary = Expression.binary(.add, innerBinary, .literal(.integer(3)))
        
        // Walk with depth limit of 1
        let limitedWalk = ASTWalker.walkExpression(
            outerBinary,
            options: ASTWalker.TraversalOptions(maxDepth: 1)
        )
        
        XCTAssertEqual(limitedWalk.count, 3) // Root + immediate children only
        XCTAssertEqual(limitedWalk[0], outerBinary)
        XCTAssertEqual(limitedWalk[1], innerBinary)
        XCTAssertEqual(limitedWalk[2], .literal(.integer(3)))
    }
    
    func testWalkExpressionBreadthFirst() {
        // Create binary tree: (1 + 2) * (3 + 4)
        let left = Expression.binary(.add, .literal(.integer(1)), .literal(.integer(2)))
        let right = Expression.binary(.add, .literal(.integer(3)), .literal(.integer(4)))
        let root = Expression.binary(.multiply, left, right)
        
        let breadthFirst = ASTWalker.walkExpression(
            root,
            options: ASTWalker.TraversalOptions(depthFirst: false)
        )
        
        XCTAssertEqual(breadthFirst.count, 7)
        XCTAssertEqual(breadthFirst[0], root) // Level 0
        XCTAssertEqual(breadthFirst[1], left) // Level 1
        XCTAssertEqual(breadthFirst[2], right) // Level 1
        XCTAssertEqual(breadthFirst[3], .literal(.integer(1))) // Level 2
        XCTAssertEqual(breadthFirst[4], .literal(.integer(2))) // Level 2
        XCTAssertEqual(breadthFirst[5], .literal(.integer(3))) // Level 2
        XCTAssertEqual(breadthFirst[6], .literal(.integer(4))) // Level 2
    }
    
    func testWalkExpressionExcludeRoot() {
        let expr = Expression.binary(.add, .literal(.integer(1)), .literal(.integer(2)))
        
        let walked = ASTWalker.walkExpression(
            expr,
            options: ASTWalker.TraversalOptions(includeRoot: false)
        )
        
        XCTAssertEqual(walked.count, 2) // Only children, not root
        XCTAssertEqual(walked[0], .literal(.integer(1)))
        XCTAssertEqual(walked[1], .literal(.integer(2)))
    }
    
    // MARK: - Statement Walking Tests
    
    func testWalkSimpleStatement() {
        let stmt = Statement.breakStatement
        let walked = ASTWalker.walkStatement(stmt)
        
        XCTAssertEqual(walked.count, 1)
        XCTAssertEqual(walked[0], stmt)
    }
    
    func testWalkIfStatement() {
        let thenBody = [Statement.breakStatement]
        let elseBody = [Statement.returnStatement(ReturnStatement())]
        let ifStmt = IfStatement(
            condition: .literal(.boolean(true)),
            thenBody: thenBody,
            elseIfs: [],
            elseBody: elseBody
        )
        let statement = Statement.ifStatement(ifStmt)
        
        let walked = ASTWalker.walkStatement(statement)
        
        XCTAssertEqual(walked.count, 3) // if + then + else
        XCTAssertEqual(walked[0], statement)
        XCTAssertEqual(walked[1], .breakStatement)
        XCTAssertEqual(walked[2], .returnStatement(ReturnStatement()))
    }
    
    func testWalkBlockStatement() {
        let innerStatements = [
            Statement.breakStatement,
            Statement.returnStatement(ReturnStatement()),
            Statement.assignment(.variable("x", .literal(.integer(42))))
        ]
        let blockStatement = Statement.block(innerStatements)
        
        let walked = ASTWalker.walkStatement(blockStatement)
        
        XCTAssertEqual(walked.count, 4) // block + 3 inner statements
        XCTAssertEqual(walked[0], blockStatement)
        XCTAssertEqual(walked[1], .breakStatement)
        XCTAssertEqual(walked[2], .returnStatement(ReturnStatement()))
        XCTAssertEqual(walked[3], .assignment(.variable("x", .literal(.integer(42)))))
    }
    
    func testWalkNestedStatements() {
        let innerBlock = Statement.block([.breakStatement])
        let outerBlock = Statement.block([innerBlock, .returnStatement(ReturnStatement())])
        
        let walked = ASTWalker.walkStatement(outerBlock)
        
        XCTAssertEqual(walked.count, 4) // outer block + inner block + break + return
        XCTAssertEqual(walked[0], outerBlock)
        XCTAssertEqual(walked[1], innerBlock)
        XCTAssertEqual(walked[2], .breakStatement)
        XCTAssertEqual(walked[3], .returnStatement(ReturnStatement()))
    }
    
    func testWalkForStatement() {
        let body = [Statement.breakStatement, Statement.returnStatement(ReturnStatement())]
        let rangeFor = ForStatement.RangeFor(
            variable: "i",
            start: .literal(.integer(0)),
            end: .literal(.integer(10)),
            body: body
        )
        let forStatement = Statement.forStatement(.range(rangeFor))
        
        let walked = ASTWalker.walkStatement(forStatement)
        
        XCTAssertEqual(walked.count, 3) // for + break + return
        XCTAssertEqual(walked[0], forStatement)
        XCTAssertEqual(walked[1], .breakStatement)
        XCTAssertEqual(walked[2], .returnStatement(ReturnStatement()))
    }
    
    // MARK: - Expression from Statement Walking Tests
    
    func testWalkStatementsForExpressions() {
        let assignment = Assignment.variable("x", .binary(.add, .literal(.integer(1)), .literal(.integer(2))))
        let assignmentStmt = Statement.assignment(assignment)
        
        let expressions = ASTWalker.walkStatementsForExpressions(assignmentStmt)
        
        XCTAssertEqual(expressions.count, 3) // binary expr + two literals
        XCTAssertTrue(expressions.contains(.binary(.add, .literal(.integer(1)), .literal(.integer(2)))))
        XCTAssertTrue(expressions.contains(.literal(.integer(1))))
        XCTAssertTrue(expressions.contains(.literal(.integer(2))))
    }
    
    func testWalkIfStatementForExpressions() {
        let condition = Expression.identifier("condition")
        let elseIf = IfStatement.ElseIf(
            condition: .literal(.boolean(false)),
            body: []
        )
        let ifStmt = IfStatement(
            condition: condition,
            thenBody: [],
            elseIfs: [elseIf],
            elseBody: []
        )
        let statement = Statement.ifStatement(ifStmt)
        
        let expressions = ASTWalker.walkStatementsForExpressions(statement)
        
        XCTAssertEqual(expressions.count, 2) // main condition + elseIf condition
        XCTAssertTrue(expressions.contains(condition))
        XCTAssertTrue(expressions.contains(.literal(.boolean(false))))
    }
    
    func testWalkForStatementForExpressions() {
        let rangeFor = ForStatement.RangeFor(
            variable: "i",
            start: .literal(.integer(0)),
            end: .literal(.integer(10)),
            step: .literal(.integer(2)),
            body: []
        )
        let statement = Statement.forStatement(.range(rangeFor))
        
        let expressions = ASTWalker.walkStatementsForExpressions(statement)
        
        XCTAssertEqual(expressions.count, 3) // start + end + step
        XCTAssertTrue(expressions.contains(.literal(.integer(0))))
        XCTAssertTrue(expressions.contains(.literal(.integer(10))))
        XCTAssertTrue(expressions.contains(.literal(.integer(2))))
    }
    
    // MARK: - Visitor Integration Tests
    
    func testVisitExpressionTree() {
        let expr = Expression.binary(
            .add,
            .literal(.integer(1)),
            .binary(.multiply, .literal(.integer(2)), .literal(.integer(3)))
        )
        
        let visitor = ExpressionVisitor<String>(
            visitLiteral: { literal in "L(\(literal))" },
            visitIdentifier: { name in "I(\(name))" },
            visitBinary: { op, _, _ in "B(\(op.rawValue))" },
            visitUnary: { op, _ in "U(\(op.rawValue))" },
            visitArrayAccess: { _, _ in "A" },
            visitFieldAccess: { _, field in "F(\(field))" },
            visitFunctionCall: { name, _ in "FC(\(name))" }
        )
        
        let results = ASTWalker.visitExpressionTree(expr, with: visitor)
        
        XCTAssertEqual(results.count, 5) // 1 root + 2 binary + 2 literals
        XCTAssertTrue(results.contains("B(+)"))
        XCTAssertTrue(results.contains("B(*)"))
        XCTAssertTrue(results.contains("L(integer(1))"))
        XCTAssertTrue(results.contains("L(integer(2))"))
        XCTAssertTrue(results.contains("L(integer(3))"))
    }
    
    func testVisitStatementTree() {
        let innerBlock = Statement.block([.breakStatement])
        let outerBlock = Statement.block([innerBlock])
        
        let visitor = StatementVisitor<String>(
            visitIfStatement: { _ in "IF" },
            visitWhileStatement: { _ in "WHILE" },
            visitForStatement: { _ in "FOR" },
            visitAssignment: { _ in "ASSIGN" },
            visitVariableDeclaration: { _ in "VAR" },
            visitConstantDeclaration: { _ in "CONST" },
            visitFunctionDeclaration: { _ in "FUNC" },
            visitProcedureDeclaration: { _ in "PROC" },
            visitReturnStatement: { _ in "RETURN" },
            visitExpressionStatement: { _ in "EXPR" },
            visitBreakStatement: { "BREAK" },
            visitBlock: { _ in "BLOCK" }
        )
        
        let results = ASTWalker.visitStatementTree(outerBlock, with: visitor)
        
        XCTAssertEqual(results.count, 3) // outer block + inner block + break
        XCTAssertEqual(results[0], "BLOCK") // outer block
        XCTAssertEqual(results[1], "BLOCK") // inner block
        XCTAssertEqual(results[2], "BREAK") // break statement
    }
    
    // MARK: - Traversal Options Tests
    
    func testTraversalOptionsDefaults() {
        let options = ASTWalker.TraversalOptions.default
        
        XCTAssertTrue(options.depthFirst)
        XCTAssertNil(options.maxDepth)
        XCTAssertTrue(options.includeRoot)
    }
    
    func testTraversalOptionsCustom() {
        let options = ASTWalker.TraversalOptions(
            depthFirst: false,
            maxDepth: 5,
            includeRoot: false
        )
        
        XCTAssertFalse(options.depthFirst)
        XCTAssertEqual(options.maxDepth, 5)
        XCTAssertFalse(options.includeRoot)
    }
    
    // MARK: - Edge Cases Tests
    
    func testWalkEmptyFunctionCall() {
        let expr = Expression.functionCall("empty", [])
        let walked = ASTWalker.walkExpression(expr)
        
        XCTAssertEqual(walked.count, 1)
        XCTAssertEqual(walked[0], expr)
    }
    
    func testWalkEmptyBlock() {
        let stmt = Statement.block([])
        let walked = ASTWalker.walkStatement(stmt)
        
        XCTAssertEqual(walked.count, 1)
        XCTAssertEqual(walked[0], stmt)
    }
    
    func testWalkExpressionWithMaxDepthZero() {
        let expr = Expression.binary(.add, .literal(.integer(1)), .literal(.integer(2)))
        let walked = ASTWalker.walkExpression(
            expr,
            options: ASTWalker.TraversalOptions(maxDepth: 0)
        )
        
        XCTAssertEqual(walked.count, 1) // Only root
        XCTAssertEqual(walked[0], expr)
    }
    
    func testWalkStatementWithMaxDepthZero() {
        let stmt = Statement.block([.breakStatement])
        let walked = ASTWalker.walkStatement(
            stmt,
            options: ASTWalker.TraversalOptions(maxDepth: 0)
        )
        
        XCTAssertEqual(walked.count, 1) // Only root
        XCTAssertEqual(walked[0], stmt)
    }
    
    // MARK: - Performance Tests
    
    func testWalkLargeExpressionTree() {
        let largeExpr = createLargeExpression(depth: 10)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let walked = ASTWalker.walkExpression(largeExpr)
        let endTime = CFAbsoluteTimeGetCurrent()
        
        let executionTime = endTime - startTime
        XCTAssertLessThan(executionTime, 1.0, "Walking large expression should complete within 1 second")
        
        // Verify we walked all nodes (2^11 - 1 nodes in complete binary tree of depth 10)
        XCTAssertEqual(walked.count, 2047)
    }
    
    func testWalkLargeStatementTree() {
        let largeStmt = createLargeStatementTree(depth: 8)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let walked = ASTWalker.walkStatement(largeStmt)
        let endTime = CFAbsoluteTimeGetCurrent()
        
        let executionTime = endTime - startTime
        XCTAssertLessThan(executionTime, 1.0, "Walking large statement tree should complete within 1 second")
        
        // Should have many nested blocks
        XCTAssertGreaterThan(walked.count, 8)
    }
    
    // MARK: - Helper Methods
    
    private func createLargeExpression(depth: Int) -> Expression {
        if depth <= 0 {
            return .literal(.integer(depth))
        }
        
        return .binary(
            .add,
            createLargeExpression(depth: depth - 1),
            createLargeExpression(depth: depth - 1)
        )
    }
    
    private func createLargeStatementTree(depth: Int) -> Statement {
        if depth <= 0 {
            return .breakStatement
        }
        
        return .block([
            createLargeStatementTree(depth: depth - 1),
            createLargeStatementTree(depth: depth - 1)
        ])
    }
}