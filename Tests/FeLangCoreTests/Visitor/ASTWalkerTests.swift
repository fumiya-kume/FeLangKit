import XCTest
@testable import FeLangCore

final class ASTWalkerTests: XCTestCase {
    
    // MARK: - Expression Walking Tests
    
    func testWalkSimpleExpression() {
        let expr = Expression.literal(.integer(42))
        let results = ASTWalker.walkExpression(expr, visitor: ExpressionVisitor.debug)
        
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0], "Literal.integer(42)")
    }
    
    func testWalkBinaryExpression() {
        let expr = Expression.binary(.add,
            Expression.literal(.integer(1)),
            Expression.literal(.integer(2))
        )
        let results = ASTWalker.walkExpression(expr, visitor: ExpressionVisitor.debug)
        
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results[0].contains("Binary"))
        XCTAssertTrue(results[1].contains("Literal.integer(1)"))
        XCTAssertTrue(results[2].contains("Literal.integer(2)"))
    }
    
    func testWalkNestedBinaryExpression() {
        // (1 + 2) * 3
        let expr = Expression.binary(.multiply,
            Expression.binary(.add,
                Expression.literal(.integer(1)),
                Expression.literal(.integer(2))
            ),
            Expression.literal(.integer(3))
        )
        let results = ASTWalker.walkExpression(expr, visitor: ExpressionVisitor.debug)
        
        XCTAssertEqual(results.count, 6)
        // Root multiply, left add, literals 1, 2, literal 3
        XCTAssertTrue(results[0].contains("Binary(*, Binary"))
        XCTAssertTrue(results[1].contains("Binary(+"))
        XCTAssertTrue(results[2].contains("Literal.integer(1)"))
        XCTAssertTrue(results[3].contains("Literal.integer(2)"))
        XCTAssertTrue(results[4].contains("Literal.integer(3)"))
    }
    
    func testWalkUnaryExpression() {
        let expr = Expression.unary(.not, Expression.literal(.boolean(true)))
        let results = ASTWalker.walkExpression(expr, visitor: ExpressionVisitor.debug)
        
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results[0].contains("Unary"))
        XCTAssertTrue(results[1].contains("Literal.boolean(true)"))
    }
    
    func testWalkArrayAccessExpression() {
        let expr = Expression.arrayAccess(
            Expression.identifier("arr"),
            Expression.literal(.integer(0))
        )
        let results = ASTWalker.walkExpression(expr, visitor: ExpressionVisitor.debug)
        
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results[0].contains("ArrayAccess"))
        XCTAssertTrue(results[1].contains("Identifier(arr)"))
        XCTAssertTrue(results[2].contains("Literal.integer(0)"))
    }
    
    func testWalkFieldAccessExpression() {
        let expr = Expression.fieldAccess(
            Expression.identifier("obj"),
            "field"
        )
        let results = ASTWalker.walkExpression(expr, visitor: ExpressionVisitor.debug)
        
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results[0].contains("FieldAccess"))
        XCTAssertTrue(results[1].contains("Identifier(obj)"))
    }
    
    func testWalkFunctionCallExpression() {
        let expr = Expression.functionCall("add", [
            Expression.literal(.integer(1)),
            Expression.literal(.integer(2))
        ])
        let results = ASTWalker.walkExpression(expr, visitor: ExpressionVisitor.debug)
        
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results[0].contains("FunctionCall"))
        XCTAssertTrue(results[1].contains("Literal.integer(1)"))
        XCTAssertTrue(results[2].contains("Literal.integer(2)"))
    }
    
    // MARK: - Statement Walking Tests
    
    func testWalkSimpleStatement() {
        let stmt = Statement.breakStatement
        let results = ASTWalker.walkStatement(stmt, visitor: StatementVisitor.debug)
        
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0], "BreakStatement")
    }
    
    func testWalkIfStatement() {
        let ifStmt = IfStatement(
            condition: Expression.literal(.boolean(true)),
            thenBody: [Statement.breakStatement, Statement.breakStatement]
        )
        let stmt = Statement.ifStatement(ifStmt)
        let results = ASTWalker.walkStatement(stmt, visitor: StatementVisitor.debug)
        
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results[0].contains("IfStatement"))
        XCTAssertEqual(results[1], "BreakStatement")
        XCTAssertEqual(results[2], "BreakStatement")
    }
    
    func testWalkWhileStatement() {
        let whileStmt = WhileStatement(
            condition: Expression.literal(.boolean(true)),
            body: [Statement.breakStatement]
        )
        let stmt = Statement.whileStatement(whileStmt)
        let results = ASTWalker.walkStatement(stmt, visitor: StatementVisitor.debug)
        
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results[0].contains("WhileStatement"))
        XCTAssertEqual(results[1], "BreakStatement")
    }
    
    func testWalkForRangeStatement() {
        let rangeFor = ForStatement.RangeFor(
            variable: "i",
            start: Expression.literal(.integer(1)),
            end: Expression.literal(.integer(10)),
            step: nil,
            body: [Statement.breakStatement]
        )
        let stmt = Statement.forStatement(.range(rangeFor))
        let results = ASTWalker.walkStatement(stmt, visitor: StatementVisitor.debug)
        
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results[0].contains("ForStatement.range"))
        XCTAssertEqual(results[1], "BreakStatement")
    }
    
    func testWalkForEachStatement() {
        let forEach = ForStatement.ForEachLoop(
            variable: "item",
            iterable: Expression.identifier("collection"),
            body: [Statement.breakStatement]
        )
        let stmt = Statement.forStatement(.forEach(forEach))
        let results = ASTWalker.walkStatement(stmt, visitor: StatementVisitor.debug)
        
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results[0].contains("ForStatement.forEach"))
        XCTAssertEqual(results[1], "BreakStatement")
    }
    
    func testWalkFunctionDeclaration() {
        let funcDecl = FunctionDeclaration(
            name: "test",
            parameters: [],
            returnType: nil,
            localVariables: [
                VariableDeclaration(name: "x", type: .integer)
            ],
            body: [Statement.breakStatement]
        )
        let stmt = Statement.functionDeclaration(funcDecl)
        let results = ASTWalker.walkStatement(stmt, visitor: StatementVisitor.debug)
        
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results[0].contains("FunctionDeclaration"))
        XCTAssertTrue(results[1].contains("VariableDeclaration"))
        XCTAssertEqual(results[2], "BreakStatement")
    }
    
    func testWalkProcedureDeclaration() {
        let procDecl = ProcedureDeclaration(
            name: "test",
            parameters: [],
            localVariables: [
                VariableDeclaration(name: "x", type: .integer)
            ],
            body: [Statement.breakStatement]
        )
        let stmt = Statement.procedureDeclaration(procDecl)
        let results = ASTWalker.walkStatement(stmt, visitor: StatementVisitor.debug)
        
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results[0].contains("ProcedureDeclaration"))
        XCTAssertTrue(results[1].contains("VariableDeclaration"))
        XCTAssertEqual(results[2], "BreakStatement")
    }
    
    func testWalkBlockStatement() {
        let block = Statement.block([
            Statement.breakStatement,
            Statement.returnStatement(ReturnStatement())
        ])
        let results = ASTWalker.walkStatement(block, visitor: StatementVisitor.debug)
        
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results[0].contains("Block"))
        XCTAssertEqual(results[1], "BreakStatement")
        XCTAssertTrue(results[2].contains("ReturnStatement"))
    }
    
    // MARK: - Transformation Tests
    
    func testExpressionTransformation() {
        let expr = Expression.binary(.add,
            Expression.literal(.integer(1)),
            Expression.literal(.integer(2))
        )
        
        // Create a transformer that doubles integer literals
        let doubler = ExpressionTransformer(
            transformLiteral: { literal in
                switch literal {
                case .integer(let value):
                    return .literal(.integer(value * 2))
                default:
                    return .literal(literal)
                }
            }
        )
        
        let result = ASTWalker.transformExpression(expr, transformer: doubler)
        
        // Verify the transformation
        let debugResult = ExpressionVisitor.debug.visit(result)
        XCTAssertTrue(debugResult.contains("Literal.integer(2)"))
        XCTAssertTrue(debugResult.contains("Literal.integer(4)"))
    }
    
    func testStatementTransformation() {
        let stmt = Statement.block([
            Statement.breakStatement,
            Statement.breakStatement
        ])
        
        // Create a transformer that converts break statements to return statements
        let converter = StatementTransformer(
            transformBreakStatement: { .returnStatement(ReturnStatement()) }
        )
        
        let result = ASTWalker.transformStatement(stmt, transformer: converter)
        
        // Verify the transformation
        let debugResult = StatementVisitor.debug.visit(result)
        XCTAssertTrue(debugResult.contains("ReturnStatement"))
        XCTAssertFalse(debugResult.contains("BreakStatement"))
    }
    
    // MARK: - Collection Tests
    
    func testCollectExpressions() {
        let expr = Expression.binary(.add,
            Expression.literal(.integer(1)),
            Expression.binary(.multiply,
                Expression.literal(.integer(2)),
                Expression.literal(.integer(3))
            )
        )
        
        // Collect all literal expressions
        let literals = ASTWalker.collectExpressions(from: expr, ofType: Expression.self) { expr in
            if case .literal = expr {
                return true
            }
            return false
        }
        
        XCTAssertEqual(literals.count, 3)
        for literal in literals {
            if case .literal = literal {
                // Test passes
            } else {
                XCTFail("Expected literal expression")
            }
        }
    }
    
    func testCollectStatementsWithPredicate() {
        let stmt = Statement.block([
            Statement.breakStatement,
            Statement.returnStatement(ReturnStatement()),
            Statement.breakStatement
        ])
        
        // Collect all break statements
        let breakStatements = ASTWalker.collectStatements(from: stmt, ofType: Statement.self) { stmt in
            if case .breakStatement = stmt {
                return true
            }
            return false
        }
        
        XCTAssertEqual(breakStatements.count, 2)
        for breakStmt in breakStatements {
            if case .breakStatement = breakStmt {
                // Test passes
            } else {
                XCTFail("Expected break statement")
            }
        }
    }
    
    func testCollectAllStatements() {
        let stmt = Statement.block([
            Statement.breakStatement,
            Statement.returnStatement(ReturnStatement())
        ])
        
        // Collect all statements (no predicate = all statements)
        let allStatements = ASTWalker.collectStatements(from: stmt, ofType: Statement.self)
        
        XCTAssertEqual(allStatements.count, 3) // block + break + return
    }
    
    // MARK: - Complex Nested Structures
    
    func testComplexNestedExpression() {
        // Create a complex expression: add(obj.field[index], multiply(x, y))
        let complexExpr = Expression.functionCall("add", [
            Expression.arrayAccess(
                Expression.fieldAccess(
                    Expression.identifier("obj"),
                    "field"
                ),
                Expression.identifier("index")
            ),
            Expression.functionCall("multiply", [
                Expression.identifier("x"),
                Expression.identifier("y")
            ])
        ])
        
        let results = ASTWalker.walkExpression(complexExpr, visitor: ExpressionVisitor.debug)
        
        // Should visit: add call, array access, field access, obj, index, multiply call, x, y
        XCTAssertEqual(results.count, 8)
        XCTAssertTrue(results[0].contains("FunctionCall(add"))
        XCTAssertTrue(results[1].contains("ArrayAccess"))
        XCTAssertTrue(results[2].contains("FieldAccess"))
        XCTAssertTrue(results[3].contains("Identifier(obj)"))
        XCTAssertTrue(results[4].contains("Identifier(index)"))
        XCTAssertTrue(results[5].contains("FunctionCall(multiply"))
        XCTAssertTrue(results[6].contains("Identifier(x)"))
        XCTAssertTrue(results[7].contains("Identifier(y)"))
    }
    
    func testComplexNestedStatement() {
        // Create nested control structures
        let whileBody = [Statement.breakStatement]
        let whileStmt = WhileStatement(condition: Expression.literal(.boolean(true)), body: whileBody)
        
        let ifBody = [Statement.whileStatement(whileStmt)]
        let ifStmt = IfStatement(condition: Expression.literal(.boolean(true)), thenBody: ifBody)
        
        let funcBody = [Statement.ifStatement(ifStmt)]
        let funcDecl = FunctionDeclaration(
            name: "test",
            parameters: [],
            returnType: nil,
            localVariables: [],
            body: funcBody
        )
        
        let stmt = Statement.functionDeclaration(funcDecl)
        let results = ASTWalker.walkStatement(stmt, visitor: StatementVisitor.debug)
        
        XCTAssertEqual(results.count, 4)
        XCTAssertTrue(results[0].contains("FunctionDeclaration"))
        XCTAssertTrue(results[1].contains("IfStatement"))
        XCTAssertTrue(results[2].contains("WhileStatement"))
        XCTAssertEqual(results[3], "BreakStatement")
    }
    
    // MARK: - Performance Tests
    
    func testWalkPerformanceForLargeExpression() {
        // Create a deep binary expression tree
        var expr = Expression.literal(.integer(0))
        for i in 1...100 {
            expr = Expression.binary(.add, expr, Expression.literal(.integer(i)))
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let results = ASTWalker.walkExpression(expr, visitor: ExpressionVisitor.debug)
        let endTime = CFAbsoluteTimeGetCurrent()
        
        XCTAssertEqual(results.count, 201) // 101 literals + 100 binary ops
        XCTAssertLessThan(endTime - startTime, 1.0) // Should complete in less than 1 second
    }
    
    // MARK: - Edge Cases
    
    func testWalkEmptyFunctionCall() {
        let expr = Expression.functionCall("empty", [])
        let results = ASTWalker.walkExpression(expr, visitor: ExpressionVisitor.debug)
        
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].contains("FunctionCall(empty, [])"))
    }
    
    func testWalkEmptyBlock() {
        let stmt = Statement.block([])
        let results = ASTWalker.walkStatement(stmt, visitor: StatementVisitor.debug)
        
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].contains("Block([])"))
    }
    
    func testCollectFromEmptyExpression() {
        let expr = Expression.literal(.integer(42))
        
        // Collect non-existent types
        let functionCalls = ASTWalker.collectExpressions(from: expr, ofType: Expression.self) { expr in
            if case .functionCall = expr {
                return true
            }
            return false
        }
        
        XCTAssertEqual(functionCalls.count, 0)
    }
}