import XCTest
@testable import FeLangCore

final class VisitableTests: XCTestCase {
    
    // MARK: - Visitable Protocol Tests
    
    func testExpressionVisitableAccept() {
        let visitor = ExpressionVisitor<String>(
            visitLiteral: { literal in
                switch literal {
                case .integer(let value): return "int(\(value))"
                case .real(let value): return "real(\(value))"
                case .string(let value): return "string(\(value))"
                case .character(let value): return "char(\(value))"
                case .boolean(let value): return "bool(\(value))"
                }
            },
            visitIdentifier: { name in "id(\(name))" },
            visitBinary: { op, left, right in "(\(left) \(op.rawValue) \(right))" },
            visitUnary: { op, expr in "\(op.rawValue)\(expr)" },
            visitArrayAccess: { array, index in "\(array)[\(index)]" },
            visitFieldAccess: { object, field in "\(object).\(field)" },
            visitFunctionCall: { name, args in 
                return "\(name)(\(args.count) args)"
            }
        )
        
        // Test literal
        let literalExpr = Expression.literal(.integer(42))
        XCTAssertEqual(literalExpr.accept(visitor), "int(42)")
        
        // Test identifier
        let identifierExpr = Expression.identifier("x")
        XCTAssertEqual(identifierExpr.accept(visitor), "id(x)")
        
        // Test complex expression: (a + b) * func(x)
        let complexExpr = Expression.binary(
            .multiply,
            .binary(.add, .identifier("a"), .identifier("b")),
            .functionCall("func", [.identifier("x")])
        )
        XCTAssertEqual(complexExpr.accept(visitor), "((id(a) + id(b)) * func(1 args))")
    }
    
    func testStatementVisitableAccept() {
        let visitor = StatementVisitor<String>(
            visitIfStatement: { ifStmt in "if-statement" },
            visitWhileStatement: { whileStmt in "while-statement" },
            visitForStatement: { forStmt in
                switch forStmt {
                case .range: return "for-range"
                case .forEach: return "for-each"
                }
            },
            visitAssignment: { assignment in
                switch assignment {
                case .variable(let name, _): return "assign(\(name))"
                case .arrayElement: return "assign-array"
                }
            },
            visitVariableDeclaration: { varDecl in "var(\(varDecl.name))" },
            visitConstantDeclaration: { constDecl in "const(\(constDecl.name))" },
            visitFunctionDeclaration: { funcDecl in "func(\(funcDecl.name))" },
            visitProcedureDeclaration: { procDecl in "proc(\(procDecl.name))" },
            visitReturnStatement: { returnStmt in 
                return returnStmt.expression != nil ? "return-expr" : "return-void"
            },
            visitExpressionStatement: { _ in "expr-stmt" },
            visitBreakStatement: { "break" },
            visitBlock: { statements in "block[\(statements.count)]" }
        )
        
        // Test various statement types
        XCTAssertEqual(Statement.breakStatement.accept(visitor), "break")
        
        let ifStmt = IfStatement(condition: .literal(.boolean(true)), thenBody: [])
        XCTAssertEqual(Statement.ifStatement(ifStmt).accept(visitor), "if-statement")
        
        let varDecl = VariableDeclaration(name: "x", type: .integer, initialValue: nil)
        XCTAssertEqual(Statement.variableDeclaration(varDecl).accept(visitor), "var(x)")
        
        let assignment = Assignment.variable("y", .literal(.integer(42)))
        XCTAssertEqual(Statement.assignment(assignment).accept(visitor), "assign(y)")
    }
    
    // MARK: - Type-Safe Accept Methods Tests
    
    func testTypeSafeExpressionAccept() {
        let stringVisitor = ExpressionVisitor<String>(
            visitLiteral: { _ in "literal" },
            visitIdentifier: { _ in "identifier" },
            visitBinary: { _, _, _ in "binary" },
            visitUnary: { _, _ in "unary" },
            visitArrayAccess: { _, _ in "array" },
            visitFieldAccess: { _, _ in "field" },
            visitFunctionCall: { _, _ in "call" }
        )
        
        let intVisitor = ExpressionVisitor<Int>(
            visitLiteral: { _ in 1 },
            visitIdentifier: { _ in 2 },
            visitBinary: { _, _, _ in 3 },
            visitUnary: { _, _ in 4 },
            visitArrayAccess: { _, _ in 5 },
            visitFieldAccess: { _, _ in 6 },
            visitFunctionCall: { _, _ in 7 }
        )
        
        let expr = Expression.literal(.integer(42))
        
        let stringResult: String = expr.accept(stringVisitor)
        let intResult: Int = expr.accept(intVisitor)
        
        XCTAssertEqual(stringResult, "literal")
        XCTAssertEqual(intResult, 1)
    }
    
    func testTypeSafeStatementAccept() {
        let stringVisitor = StatementVisitor<String>(
            visitIfStatement: { _ in "if" },
            visitWhileStatement: { _ in "while" },
            visitForStatement: { _ in "for" },
            visitAssignment: { _ in "assignment" },
            visitVariableDeclaration: { _ in "var" },
            visitConstantDeclaration: { _ in "const" },
            visitFunctionDeclaration: { _ in "func" },
            visitProcedureDeclaration: { _ in "proc" },
            visitReturnStatement: { _ in "return" },
            visitExpressionStatement: { _ in "expr" },
            visitBreakStatement: { "break" },
            visitBlock: { _ in "block" }
        )
        
        let boolVisitor = StatementVisitor<Bool>(
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
            visitBreakStatement: { false },
            visitBlock: { _ in true }
        )
        
        let stmt = Statement.breakStatement
        
        let stringResult: String = stmt.accept(stringVisitor)
        let boolResult: Bool = stmt.accept(boolVisitor)
        
        XCTAssertEqual(stringResult, "break")
        XCTAssertEqual(boolResult, false)
    }
    
    // MARK: - Visitor Protocol Conformance Tests
    
    func testExpressionVisitorConformsToVisitor() {
        let visitor = ExpressionVisitor<String>(
            visitLiteral: { _ in "literal" },
            visitIdentifier: { _ in "identifier" },
            visitBinary: { _, _, _ in "binary" },
            visitUnary: { _, _ in "unary" },
            visitArrayAccess: { _, _ in "array" },
            visitFieldAccess: { _, _ in "field" },
            visitFunctionCall: { _, _ in "call" }
        )
        
        // This test ensures ExpressionVisitor conforms to Visitor protocol
        func acceptGenericVisitor<V: Visitor>(_ visitor: V) -> V.Result where V.Result == String {
            let expr = Expression.literal(.integer(42))
            return expr.accept(visitor)
        }
        
        let result = acceptGenericVisitor(visitor)
        XCTAssertEqual(result, "literal")
    }
    
    func testStatementVisitorConformsToVisitor() {
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
        
        // This test ensures StatementVisitor conforms to Visitor protocol
        func acceptGenericVisitor<V: Visitor>(_ visitor: V) -> V.Result where V.Result == Int {
            let stmt = Statement.breakStatement
            return stmt.accept(visitor)
        }
        
        let result = acceptGenericVisitor(visitor)
        XCTAssertEqual(result, 11)
    }
    
    // MARK: - Real-World Usage Scenarios
    
    func testASTPrinting() {
        let prettyPrinter = ExpressionVisitor<String>(
            visitLiteral: { literal in
                switch literal {
                case .integer(let value): return "\(value)"
                case .real(let value): return String(format: "%.2f", value)
                case .string(let value): return "\"\(value)\""
                case .character(let value): return "'\(value)'"
                case .boolean(let value): return value ? "true" : "false"
                }
            },
            visitIdentifier: { name in name },
            visitBinary: { op, left, right in
                return "binary_op"
            },
            visitUnary: { op, expr in
                return "unary_op"
            },
            visitArrayAccess: { array, index in
                return "array_access"
            },
            visitFieldAccess: { object, field in
                return "field_access"
            },
            visitFunctionCall: { name, args in
                return "function_call"
            }
        )
        
        let complexExpr = Expression.functionCall("max", [
            .binary(.add, .identifier("a"), .literal(.integer(10))),
            .arrayAccess(.identifier("values"), .literal(.integer(0))),
            .fieldAccess(.identifier("obj"), "count")
        ])
        
        let result = complexExpr.accept(prettyPrinter)
        XCTAssertEqual(result, "function_call")
    }
    
    func testVariableCollector() {
        let variableCollector = ExpressionVisitor<Set<String>>(
            visitLiteral: { _ in Set() },
            visitIdentifier: { name in Set([name]) },
            visitBinary: { _, left, right in
                return Set(["binary_var"])
            },
            visitUnary: { _, expr in
                return Set(["unary_var"])
            },
            visitArrayAccess: { array, index in
                return Set(["array_var"])
            },
            visitFieldAccess: { object, _ in
                return Set(["field_var"])
            },
            visitFunctionCall: { _, args in
                return Set(["function_var"])
            }
        )
        
        let expr = Expression.identifier("test_var")
        
        let variables = expr.accept(variableCollector)
        XCTAssertEqual(variables, Set(["test_var"]))
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentVisitableAccess() {
        let visitor = ExpressionVisitor<String>(
            visitLiteral: { literal in
                Thread.sleep(forTimeInterval: 0.001)
                switch literal {
                case .integer(let value): return "int(\(value))"
                default: return "other"
                }
            },
            visitIdentifier: { name in "id(\(name))" },
            visitBinary: { _, _, _ in "binary" },
            visitUnary: { _, _ in "unary" },
            visitArrayAccess: { _, _ in "array" },
            visitFieldAccess: { _, _ in "field" },
            visitFunctionCall: { _, _ in "call" }
        )
        
        let expressions = (0..<10).map { Expression.literal(.integer($0)) }
        let expectation = XCTestExpectation(description: "Concurrent visitable access")
        expectation.expectedFulfillmentCount = 10
        
        for (index, expr) in expressions.enumerated() {
            Task {
                let result = expr.accept(visitor)
                XCTAssertEqual(result, "int(\(index))")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
}