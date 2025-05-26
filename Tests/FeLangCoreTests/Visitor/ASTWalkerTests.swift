import XCTest
@testable import FeLangCore

final class ASTWalkerTests: XCTestCase {
    
    func testWalkSimpleExpression() {
        let visitor = ExpressionVisitor<Int>(
            visitLiteral: { _ in 1 },
            visitIdentifier: { _ in 1 },
            visitBinary: { _, _, _ in 1 },
            visitUnary: { _, _ in 1 },
            visitArrayAccess: { _, _ in 1 },
            visitFieldAccess: { _, _ in 1 },
            visitFunctionCall: { _, _ in 1 }
        )
        
        // Test simple literal
        let result = ASTWalker.walkExpression(
            .literal(.integer(42)),
            visitor: visitor,
            accumulator: +,
            identity: 0
        )
        XCTAssertEqual(result, 1) // Only the literal itself
    }
    
    func testWalkBinaryExpression() {
        let visitor = ExpressionVisitor<Int>(
            visitLiteral: { _ in 1 },
            visitIdentifier: { _ in 1 },
            visitBinary: { _, _, _ in 1 },
            visitUnary: { _, _ in 1 },
            visitArrayAccess: { _, _ in 1 },
            visitFieldAccess: { _, _ in 1 },
            visitFunctionCall: { _, _ in 1 }
        )
        
        // Test binary expression: 1 + 2
        let binaryExpr = Expression.binary(.add, .literal(.integer(1)), .literal(.integer(2)))
        let result = ASTWalker.walkExpression(
            binaryExpr,
            visitor: visitor,
            accumulator: +,
            identity: 0
        )
        XCTAssertEqual(result, 3) // Binary node + left literal + right literal
    }
    
    func testWalkNestedExpression() {
        let visitor = ExpressionVisitor<Int>(
            visitLiteral: { _ in 1 },
            visitIdentifier: { _ in 1 },
            visitBinary: { _, _, _ in 1 },
            visitUnary: { _, _ in 1 },
            visitArrayAccess: { _, _ in 1 },
            visitFieldAccess: { _, _ in 1 },
            visitFunctionCall: { _, _ in 1 }
        )
        
        // Test nested expression: (1 + 2) * 3
        let nestedExpr = Expression.binary(
            .multiply,
            .binary(.add, .literal(.integer(1)), .literal(.integer(2))),
            .literal(.integer(3))
        )
        
        let result = ASTWalker.walkExpression(
            nestedExpr,
            visitor: visitor,
            accumulator: +,
            identity: 0
        )
        XCTAssertEqual(result, 5) // Outer *, inner +, and three literals
    }
    
    func testWalkFunctionCall() {
        let visitor = ExpressionVisitor<Int>(
            visitLiteral: { _ in 1 },
            visitIdentifier: { _ in 1 },
            visitBinary: { _, _, _ in 1 },
            visitUnary: { _, _ in 1 },
            visitArrayAccess: { _, _ in 1 },
            visitFieldAccess: { _, _ in 1 },
            visitFunctionCall: { _, _ in 1 }
        )
        
        // Test function call: max(1, 2)
        let funcCall = Expression.functionCall("max", [.literal(.integer(1)), .literal(.integer(2))])
        let result = ASTWalker.walkExpression(
            funcCall,
            visitor: visitor,
            accumulator: +,
            identity: 0
        )
        XCTAssertEqual(result, 3) // Function call + two arguments
    }
    
    func testWalkStatementWithExpressions() {
        let statementVisitor = StatementVisitor<Int>(
            visitIfStatement: { _ in 1 },
            visitWhileStatement: { _ in 1 },
            visitForStatement: { _ in 1 },
            visitAssignment: { _ in 1 },
            visitVariableDeclaration: { _ in 1 },
            visitConstantDeclaration: { _ in 1 },
            visitFunctionDeclaration: { _ in 1 },
            visitProcedureDeclaration: { _ in 1 },
            visitReturnStatement: { _ in 1 },
            visitExpressionStatement: { _ in 1 },
            visitBreakStatement: { 1 },
            visitBlock: { _ in 1 }
        )
        
        let expressionVisitor = ExpressionVisitor<Int>(
            visitLiteral: { _ in 1 },
            visitIdentifier: { _ in 1 },
            visitBinary: { _, _, _ in 1 },
            visitUnary: { _, _ in 1 },
            visitArrayAccess: { _, _ in 1 },
            visitFieldAccess: { _, _ in 1 },
            visitFunctionCall: { _, _ in 1 }
        )
        
        // Test variable declaration with initial value: var x: integer := 42
        let varDecl = VariableDeclaration(name: "x", type: .integer, initialValue: .literal(.integer(42)))
        let stmt = Statement.variableDeclaration(varDecl)
        
        let result = ASTWalker.walkStatement(
            stmt,
            statementVisitor: statementVisitor,
            expressionVisitor: expressionVisitor,
            accumulator: +,
            identity: 0
        )
        XCTAssertEqual(result, 2) // Variable declaration + literal
    }
    
    func testWalkIfStatement() {
        let statementVisitor = StatementVisitor<Int>(
            visitIfStatement: { _ in 1 },
            visitWhileStatement: { _ in 1 },
            visitForStatement: { _ in 1 },
            visitAssignment: { _ in 1 },
            visitVariableDeclaration: { _ in 1 },
            visitConstantDeclaration: { _ in 1 },
            visitFunctionDeclaration: { _ in 1 },
            visitProcedureDeclaration: { _ in 1 },
            visitReturnStatement: { _ in 1 },
            visitExpressionStatement: { _ in 1 },
            visitBreakStatement: { 1 },
            visitBlock: { _ in 1 }
        )
        
        let expressionVisitor = ExpressionVisitor<Int>(
            visitLiteral: { _ in 1 },
            visitIdentifier: { _ in 1 },
            visitBinary: { _, _, _ in 1 },
            visitUnary: { _, _ in 1 },
            visitArrayAccess: { _, _ in 1 },
            visitFieldAccess: { _, _ in 1 },
            visitFunctionCall: { _, _ in 1 }
        )
        
        // Test if statement: if true then break
        let ifStmt = IfStatement(
            condition: .literal(.boolean(true)),
            thenBody: [.breakStatement]
        )
        let stmt = Statement.ifStatement(ifStmt)
        
        let result = ASTWalker.walkStatement(
            stmt,
            statementVisitor: statementVisitor,
            expressionVisitor: expressionVisitor,
            accumulator: +,
            identity: 0
        )
        XCTAssertEqual(result, 3) // If statement + condition literal + break statement
    }
    
    func testCollectExpressions() {
        // Test collecting all literal values from an expression
        let expr = Expression.binary(
            .add,
            .literal(.integer(1)),
            .binary(.multiply, .literal(.integer(2)), .literal(.integer(3)))
        )
        
        let literals = ASTWalker.collectExpressions(expr) { expr in
            if case .literal(let literal) = expr {
                return [literal]
            }
            return []
        }
        
        XCTAssertEqual(literals.count, 3)
        XCTAssertTrue(literals.contains(.integer(1)))
        XCTAssertTrue(literals.contains(.integer(2)))
        XCTAssertTrue(literals.contains(.integer(3)))
    }
    
    func testCollectStatements() {
        // Test collecting all break statements from a block
        let blockStmt = Statement.block([
            .breakStatement,
            .assignment(.variable("x", .literal(.integer(1)))),
            .breakStatement
        ])
        
        let breakStatements = ASTWalker.collectStatements(blockStmt) { stmt in
            if case .breakStatement = stmt {
                return [1]
            }
            return []
        }
        
        XCTAssertEqual(breakStatements.count, 2) // Two break statements found
    }
    
    func testTransformExpression() {
        // Test transforming all integer literals by doubling them
        let expr = Expression.binary(
            .add,
            .literal(.integer(1)),
            .literal(.integer(2))
        )
        
        let transformed = ASTWalker.transformExpression(expr) { expr in
            if case .literal(.integer(let value)) = expr {
                return .literal(.integer(value * 2))
            }
            return expr
        }
        
        // Verify the transformation
        let debugVisitor = ExpressionVisitor<String>.makeDebugVisitor()
        let result = debugVisitor.visit(transformed)
        XCTAssertEqual(result, "(2 + 4)")
    }
    
    func testTransformNestedExpression() {
        // Test transforming nested expressions
        let expr = Expression.functionCall("max", [
            .literal(.integer(5)),
            .binary(.add, .literal(.integer(10)), .literal(.integer(15)))
        ])
        
        let transformed = ASTWalker.transformExpression(expr) { expr in
            // Replace all additions with subtractions
            if case .binary(.add, let left, let right) = expr {
                return .binary(.subtract, left, right)
            }
            return expr
        }
        
        let debugVisitor = ExpressionVisitor<String>.makeDebugVisitor()
        let result = debugVisitor.visit(transformed)
        XCTAssertEqual(result, "max(5, (10 - 15))")
    }
    
    func testIdentityTransformation() {
        // Test that identity transformation doesn't change the expression
        let expr = Expression.binary(.multiply, .literal(.integer(3)), .literal(.integer(4)))
        let transformed = ASTWalker.transformExpression(expr) { $0 }
        
        XCTAssertEqual(expr, transformed)
    }
    
    func testWalkEmptyStatements() {
        let statementVisitor = StatementVisitor<Int>(
            visitIfStatement: { _ in 1 },
            visitWhileStatement: { _ in 1 },
            visitForStatement: { _ in 1 },
            visitAssignment: { _ in 1 },
            visitVariableDeclaration: { _ in 1 },
            visitConstantDeclaration: { _ in 1 },
            visitFunctionDeclaration: { _ in 1 },
            visitProcedureDeclaration: { _ in 1 },
            visitReturnStatement: { _ in 1 },
            visitExpressionStatement: { _ in 1 },
            visitBreakStatement: { 1 },
            visitBlock: { _ in 1 }
        )
        
        let expressionVisitor = ExpressionVisitor<Int>(
            visitLiteral: { _ in 1 },
            visitIdentifier: { _ in 1 },
            visitBinary: { _, _, _ in 1 },
            visitUnary: { _, _ in 1 },
            visitArrayAccess: { _, _ in 1 },
            visitFieldAccess: { _, _ in 1 },
            visitFunctionCall: { _, _ in 1 }
        )
        
        // Test empty block
        let emptyBlock = Statement.block([])
        let result = ASTWalker.walkStatement(
            emptyBlock,
            statementVisitor: statementVisitor,
            expressionVisitor: expressionVisitor,
            accumulator: +,
            identity: 0
        )
        XCTAssertEqual(result, 1) // Only the block statement itself
    }
}