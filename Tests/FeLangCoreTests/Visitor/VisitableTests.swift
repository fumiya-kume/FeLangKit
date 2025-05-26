import XCTest
@testable import FeLangCore

final class VisitableTests: XCTestCase {
    
    // MARK: - Basic Protocol Conformance Tests
    
    func testExpressionVisitableConformance() {
        let expression = Expression.literal(.integer(42))
        let visitor = ExpressionVisitor<String>(
            visitLiteral: { literal in "Literal(\(literal))" },
            visitIdentifier: { name in "Id(\(name))" },
            visitBinary: { op, left, right in "Binary(\(op.rawValue), \(left), \(right))" },
            visitUnary: { op, expr in "Unary(\(op.rawValue), \(expr))" },
            visitArrayAccess: { array, index in "ArrayAccess(\(array), \(index))" },
            visitFieldAccess: { object, field in "FieldAccess(\(object), \(field))" },
            visitFunctionCall: { name, args in "FunctionCall(\(name), \(args))" }
        )
        
        // Test direct visitation through Visitable protocol
        let result = expression.accept(visitor)
        XCTAssertEqual(result, "Literal(integer(42))")
    }
    
    func testStatementVisitableConformance() {
        let statement = Statement.breakStatement
        let visitor = StatementVisitor<String>(
            visitIfStatement: { _ in "If" },
            visitWhileStatement: { _ in "While" },
            visitForStatement: { _ in "For" },
            visitAssignment: { _ in "Assignment" },
            visitVariableDeclaration: { _ in "VarDecl" },
            visitConstantDeclaration: { _ in "ConstDecl" },
            visitFunctionDeclaration: { _ in "FuncDecl" },
            visitProcedureDeclaration: { _ in "ProcDecl" },
            visitReturnStatement: { _ in "Return" },
            visitExpressionStatement: { _ in "ExprStmt" },
            visitBreakStatement: { "Break" },
            visitBlock: { _ in "Block" }
        )
        
        // Test direct visitation through Visitable protocol
        let result = statement.accept(visitor)
        XCTAssertEqual(result, "Break")
    }
    
    // MARK: - Visitor Protocol Conformance Tests
    
    func testExpressionVisitorConformsToVisitor() {
        let visitor = ExpressionVisitor<Int>(
            visitLiteral: { _ in 1 },
            visitIdentifier: { _ in 1 },
            visitBinary: { _, _, _ in 1 },
            visitUnary: { _, _ in 1 },
            visitArrayAccess: { _, _ in 1 },
            visitFieldAccess: { _, _ in 1 },
            visitFunctionCall: { _, _ in 1 }
        )
        
        // Verify type conformance
        XCTAssertTrue(visitor is any Visitor)
        
        // Test visit method
        let expression = Expression.literal(.integer(42))
        let result = visitor.visit(expression)
        XCTAssertEqual(result, 1)
    }
    
    func testStatementVisitorConformsToVisitor() {
        let visitor = StatementVisitor<Bool>(
            visitIfStatement: { _ in true },
            visitWhileStatement: { _ in true },
            visitForStatement: { _ in true },
            visitAssignment: { _ in true },
            visitVariableDeclaration: { _ in true },
            visitConstantDeclaration: { _ in true },
            visitFunctionDeclaration: { _ in true },
            visitProcedureDeclaration: { _ in true },
            visitReturnStatement: { _ in true },
            visitExpressionStatement: { _ in true },
            visitBreakStatement: { true },
            visitBlock: { _ in true }
        )
        
        // Verify type conformance
        XCTAssertTrue(visitor is any Visitor)
        
        // Test visit method
        let statement = Statement.breakStatement
        let result = visitor.visit(statement)
        XCTAssertTrue(result)
    }
    
    // MARK: - Generic Visitor Function Tests
    
    func testGenericVisitableFunction() {
        func processNode<T: Visitable, V: Visitor>(_ node: T, with visitor: V) -> V.Result where V.Node == T {
            return node.accept(visitor)
        }
        
        // Test with Expression
        let expression = Expression.identifier("test")
        let expressionVisitor = ExpressionVisitor<String>(
            visitLiteral: { _ in "literal" },
            visitIdentifier: { name in "identifier(\(name))" },
            visitBinary: { _, _, _ in "binary" },
            visitUnary: { _, _ in "unary" },
            visitArrayAccess: { _, _ in "arrayAccess" },
            visitFieldAccess: { _, _ in "fieldAccess" },
            visitFunctionCall: { _, _ in "functionCall" }
        )
        
        let expressionResult = processNode(expression, with: expressionVisitor)
        XCTAssertEqual(expressionResult, "identifier(test)")
        
        // Test with Statement
        let statement = Statement.breakStatement
        let statementVisitor = StatementVisitor<Int>(
            visitIfStatement: { _ in 1 },
            visitWhileStatement: { _ in 2 },
            visitForStatement: { _ in 3 },
            visitAssignment: { _ in 4 },
            visitVariableDeclaration: { _ in 5 },
            visitConstantDeclaration: { _ in 6 },
            visitFunctionDeclaration: { _ in 7 },
            visitProcedureDeclaration: { _ in 8 },
            visitReturnStatement: { _ in 9 },
            visitExpressionStatement: { _ in 10 },
            visitBreakStatement: { 11 },
            visitBlock: { _ in 12 }
        )
        
        let statementResult = processNode(statement, with: statementVisitor)
        XCTAssertEqual(statementResult, 11)
    }
    
    // MARK: - Convenience Extension Tests
    
    func testExpressionConvenienceAccept() {
        let expression = Expression.literal(.real(3.14))
        let visitor = ExpressionVisitor<Double>(
            visitLiteral: { literal in
                switch literal {
                case .real(let value):
                    return value
                default:
                    return 0.0
                }
            },
            visitIdentifier: { _ in 0.0 },
            visitBinary: { _, _, _ in 0.0 },
            visitUnary: { _, _ in 0.0 },
            visitArrayAccess: { _, _ in 0.0 },
            visitFieldAccess: { _, _ in 0.0 },
            visitFunctionCall: { _, _ in 0.0 }
        )
        
        // Test convenience method
        let result = expression.accept(visitor)
        XCTAssertEqual(result, 3.14, accuracy: 0.001)
    }
    
    func testStatementConvenienceAccept() {
        let varDecl = VariableDeclaration(name: "test", type: .string)
        let statement = Statement.variableDeclaration(varDecl)
        
        let visitor = StatementVisitor<String>(
            visitIfStatement: { _ in "if" },
            visitWhileStatement: { _ in "while" },
            visitForStatement: { _ in "for" },
            visitAssignment: { _ in "assignment" },
            visitVariableDeclaration: { varDecl in "var:\(varDecl.name)" },
            visitConstantDeclaration: { _ in "const" },
            visitFunctionDeclaration: { _ in "func" },
            visitProcedureDeclaration: { _ in "proc" },
            visitReturnStatement: { _ in "return" },
            visitExpressionStatement: { _ in "expr" },
            visitBreakStatement: { "break" },
            visitBlock: { _ in "block" }
        )
        
        // Test convenience method
        let result = statement.accept(visitor)
        XCTAssertEqual(result, "var:test")
    }
    
    // MARK: - Collection Extension Tests
    
    func testExpressionArrayAccept() {
        let expressions: [Expression] = [
            .literal(.integer(1)),
            .identifier("x"),
            .binary(.add, .literal(.integer(2)), .literal(.integer(3)))
        ]
        
        let visitor = ExpressionVisitor<String>(
            visitLiteral: { literal in "L(\(literal))" },
            visitIdentifier: { name in "I(\(name))" },
            visitBinary: { op, _, _ in "B(\(op.rawValue))" },
            visitUnary: { _, _ in "U" },
            visitArrayAccess: { _, _ in "A" },
            visitFieldAccess: { _, _ in "F" },
            visitFunctionCall: { _, _ in "FC" }
        )
        
        let results = expressions.accept(visitor)
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0], "L(integer(1))")
        XCTAssertEqual(results[1], "I(x)")
        XCTAssertEqual(results[2], "B(+)")
    }
    
    func testStatementArrayAccept() {
        let statements: [Statement] = [
            .breakStatement,
            .returnStatement(ReturnStatement()),
            .assignment(.variable("x", .literal(.integer(42))))
        ]
        
        let visitor = StatementVisitor<Int>(
            visitIfStatement: { _ in 1 },
            visitWhileStatement: { _ in 2 },
            visitForStatement: { _ in 3 },
            visitAssignment: { _ in 4 },
            visitVariableDeclaration: { _ in 5 },
            visitConstantDeclaration: { _ in 6 },
            visitFunctionDeclaration: { _ in 7 },
            visitProcedureDeclaration: { _ in 8 },
            visitReturnStatement: { _ in 9 },
            visitExpressionStatement: { _ in 10 },
            visitBreakStatement: { 11 },
            visitBlock: { _ in 12 }
        )
        
        let results = statements.accept(visitor)
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0], 11) // break
        XCTAssertEqual(results[1], 9)  // return
        XCTAssertEqual(results[2], 4)  // assignment
    }
    
    func testGenericCollectionAccept() {
        let expressions: [Expression] = [
            .literal(.integer(1)),
            .literal(.integer(2)),
            .literal(.integer(3))
        ]
        
        let visitor = ExpressionVisitor<Bool>(
            visitLiteral: { literal in
                switch literal {
                case .integer(let value):
                    return value > 1
                default:
                    return false
                }
            },
            visitIdentifier: { _ in false },
            visitBinary: { _, _, _ in false },
            visitUnary: { _, _ in false },
            visitArrayAccess: { _, _ in false },
            visitFieldAccess: { _, _ in false },
            visitFunctionCall: { _, _ in false }
        )
        
        // Test generic collection extension
        let results: [Bool] = expressions.accept(visitor)
        XCTAssertEqual(results, [false, true, true])
    }
    
    // MARK: - Type Safety Tests
    
    func testTypeSafetyWithMismatchedVisitor() {
        // This test ensures compile-time type safety
        let expression = Expression.literal(.integer(42))
        let expressionVisitor = ExpressionVisitor<String>(
            visitLiteral: { _ in "literal" },
            visitIdentifier: { _ in "identifier" },
            visitBinary: { _, _, _ in "binary" },
            visitUnary: { _, _ in "unary" },
            visitArrayAccess: { _, _ in "arrayAccess" },
            visitFieldAccess: { _, _ in "fieldAccess" },
            visitFunctionCall: { _, _ in "functionCall" }
        )
        
        // This should work fine
        let result = expression.accept(expressionVisitor)
        XCTAssertEqual(result, "literal")
        
        // The following should NOT compile (type safety):
        // let statement = Statement.breakStatement
        // let wrongResult = statement.accept(expressionVisitor) // Compile error!
    }
    
    // MARK: - Complex Hierarchy Tests
    
    func testNestedVisitableStructures() {
        // Create a complex nested structure
        let innerExpr = Expression.binary(.add, .literal(.integer(1)), .literal(.integer(2)))
        let assignment = Assignment.variable("result", innerExpr)
        let assignmentStmt = Statement.assignment(assignment)
        let block = Statement.block([assignmentStmt])
        
        // Create visitors
        let expressionVisitor = ExpressionVisitor<String>(
            visitLiteral: { literal in "\(literal)" },
            visitIdentifier: { name in name },
            visitBinary: { op, left, right in "(\(expressionVisitor.visit(left)) \(op.rawValue) \(expressionVisitor.visit(right)))" },
            visitUnary: { op, expr in "\(op.rawValue)\(expressionVisitor.visit(expr))" },
            visitArrayAccess: { array, index in "\(expressionVisitor.visit(array))[\(expressionVisitor.visit(index))]" },
            visitFieldAccess: { object, field in "\(expressionVisitor.visit(object)).\(field)" },
            visitFunctionCall: { name, args in "\(name)(\(args.map { expressionVisitor.visit($0) }.joined(separator: ", ")))" }
        )
        
        let statementVisitor = StatementVisitor<String>(
            visitIfStatement: { _ in "if-statement" },
            visitWhileStatement: { _ in "while-statement" },
            visitForStatement: { _ in "for-statement" },
            visitAssignment: { assignment in
                switch assignment {
                case .variable(let name, let expr):
                    return "\(name) = \(expressionVisitor.visit(expr))"
                case .arrayElement(let arrayAccess, let expr):
                    return "\(expressionVisitor.visit(arrayAccess.array))[\(expressionVisitor.visit(arrayAccess.index))] = \(expressionVisitor.visit(expr))"
                }
            },
            visitVariableDeclaration: { _ in "var-decl" },
            visitConstantDeclaration: { _ in "const-decl" },
            visitFunctionDeclaration: { _ in "func-decl" },
            visitProcedureDeclaration: { _ in "proc-decl" },
            visitReturnStatement: { _ in "return" },
            visitExpressionStatement: { expr in expressionVisitor.visit(expr) },
            visitBreakStatement: { "break" },
            visitBlock: { statements in "{ \(statements.map { statementVisitor.visit($0) }.joined(separator: "; ")) }" }
        )
        
        // Test the complex structure
        let result = block.accept(statementVisitor)
        XCTAssertEqual(result, "{ result = (integer(1) + integer(2)) }")
    }
    
    // MARK: - Performance Tests
    
    func testVisitablePerformance() {
        let expressions = (0..<1000).map { i in
            Expression.binary(.add, .literal(.integer(i)), .literal(.integer(i + 1)))
        }
        
        let visitor = ExpressionVisitor<Int>(
            visitLiteral: { _ in 1 },
            visitIdentifier: { _ in 1 },
            visitBinary: { _, left, right in visitor.visit(left) + visitor.visit(right) + 1 },
            visitUnary: { _, expr in visitor.visit(expr) + 1 },
            visitArrayAccess: { array, index in visitor.visit(array) + visitor.visit(index) + 1 },
            visitFieldAccess: { object, _ in visitor.visit(object) + 1 },
            visitFunctionCall: { _, args in args.reduce(1) { sum, arg in sum + visitor.visit(arg) } }
        )
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let results = expressions.accept(visitor)
        let endTime = CFAbsoluteTimeGetCurrent()
        
        let executionTime = endTime - startTime
        XCTAssertLessThan(executionTime, 1.0, "Visiting 1000 expressions should complete within 1 second")
        XCTAssertEqual(results.count, 1000)
        XCTAssertTrue(results.allSatisfy { $0 == 3 }) // Each binary expr should count as 3 (2 literals + 1 binary)
    }
    
    // MARK: - Thread Safety Tests
    
    func testVisitableThreadSafety() {
        let expressions = (0..<100).map { i in
            Expression.identifier("var\(i)")
        }
        
        let visitor = ExpressionVisitor<String>(
            visitLiteral: { _ in "literal" },
            visitIdentifier: { name in "id(\(name))" },
            visitBinary: { _, _, _ in "binary" },
            visitUnary: { _, _ in "unary" },
            visitArrayAccess: { _, _ in "arrayAccess" },
            visitFieldAccess: { _, _ in "fieldAccess" },
            visitFunctionCall: { _, _ in "functionCall" }
        )
        
        let expectation = XCTestExpectation(description: "Thread safety test")
        expectation.expectedFulfillmentCount = expressions.count
        
        DispatchQueue.concurrentPerform(iterations: expressions.count) { index in
            let result = expressions[index].accept(visitor)
            XCTAssertEqual(result, "id(var\(index))")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
}