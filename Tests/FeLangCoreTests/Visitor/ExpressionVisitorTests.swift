import XCTest
@testable import FeLangCore

final class ExpressionVisitorTests: XCTestCase {
    
    func testVisitLiteral() {
        let visitor = ExpressionVisitor<String>(
            visitLiteral: { literal in
                switch literal {
                case .integer(let value):
                    return "int(\(value))"
                case .real(let value):
                    return "real(\(value))"
                case .string(let value):
                    return "string(\"\(value)\")"
                case .character(let value):
                    return "char('\(value)')"
                case .boolean(let value):
                    return "bool(\(value))"
                }
            },
            visitIdentifier: { _ in "id" },
            visitBinary: { _, _, _ in "binary" },
            visitUnary: { _, _ in "unary" },
            visitArrayAccess: { _, _ in "array_access" },
            visitFieldAccess: { _, _ in "field_access" },
            visitFunctionCall: { _, _ in "function_call" }
        )
        
        XCTAssertEqual(visitor.visit(.literal(.integer(42))), "int(42)")
        XCTAssertEqual(visitor.visit(.literal(.real(3.14))), "real(3.14)")
        XCTAssertEqual(visitor.visit(.literal(.string("hello"))), "string(\"hello\")")
        XCTAssertEqual(visitor.visit(.literal(.character("a"))), "char('a')")
        XCTAssertEqual(visitor.visit(.literal(.boolean(true))), "bool(true)")
    }
    
    func testVisitIdentifier() {
        let visitor = ExpressionVisitor<String>(
            visitLiteral: { _ in "literal" },
            visitIdentifier: { name in "identifier(\(name))" },
            visitBinary: { _, _, _ in "binary" },
            visitUnary: { _, _ in "unary" },
            visitArrayAccess: { _, _ in "array_access" },
            visitFieldAccess: { _, _ in "field_access" },
            visitFunctionCall: { _, _ in "function_call" }
        )
        
        XCTAssertEqual(visitor.visit(.identifier("x")), "identifier(x)")
        XCTAssertEqual(visitor.visit(.identifier("myVariable")), "identifier(myVariable)")
    }
    
    func testVisitBinary() {
        let visitor = ExpressionVisitor<String>(
            visitLiteral: { _ in "literal" },
            visitIdentifier: { _ in "id" },
            visitBinary: { op, left, right in "binary(\(op.rawValue), \(left), \(right))" },
            visitUnary: { _, _ in "unary" },
            visitArrayAccess: { _, _ in "array_access" },
            visitFieldAccess: { _, _ in "field_access" },
            visitFunctionCall: { _, _ in "function_call" }
        )
        
        let expr = Expression.binary(.add, .literal(.integer(1)), .literal(.integer(2)))
        let result = visitor.visit(expr)
        XCTAssertTrue(result.contains("binary(+"))
        XCTAssertTrue(result.contains("literal(Literal.integer(1))"))
        XCTAssertTrue(result.contains("literal(Literal.integer(2))"))
    }
    
    func testVisitUnary() {
        let visitor = ExpressionVisitor<String>(
            visitLiteral: { _ in "literal" },
            visitIdentifier: { _ in "id" },
            visitBinary: { _, _, _ in "binary" },
            visitUnary: { op, expr in "unary(\(op.rawValue), \(expr))" },
            visitArrayAccess: { _, _ in "array_access" },
            visitFieldAccess: { _, _ in "field_access" },
            visitFunctionCall: { _, _ in "function_call" }
        )
        
        let expr = Expression.unary(.not, .literal(.boolean(true)))
        let result = visitor.visit(expr)
        XCTAssertTrue(result.contains("unary(not"))
        XCTAssertTrue(result.contains("literal(Literal.boolean(true))"))
    }
    
    func testVisitArrayAccess() {
        let visitor = ExpressionVisitor<String>(
            visitLiteral: { _ in "literal" },
            visitIdentifier: { _ in "id" },
            visitBinary: { _, _, _ in "binary" },
            visitUnary: { _, _ in "unary" },
            visitArrayAccess: { array, index in "array_access(\(array), \(index))" },
            visitFieldAccess: { _, _ in "field_access" },
            visitFunctionCall: { _, _ in "function_call" }
        )
        
        let expr = Expression.arrayAccess(.identifier("arr"), .literal(.integer(0)))
        let result = visitor.visit(expr)
        XCTAssertTrue(result.contains("array_access"))
        XCTAssertTrue(result.contains("identifier(\"arr\")"))
        XCTAssertTrue(result.contains("literal(Literal.integer(0))"))
    }
    
    func testVisitFieldAccess() {
        let visitor = ExpressionVisitor<String>(
            visitLiteral: { _ in "literal" },
            visitIdentifier: { _ in "id" },
            visitBinary: { _, _, _ in "binary" },
            visitUnary: { _, _ in "unary" },
            visitArrayAccess: { _, _ in "array_access" },
            visitFieldAccess: { expr, field in "field_access(\(expr), \(field))" },
            visitFunctionCall: { _, _ in "function_call" }
        )
        
        let expr = Expression.fieldAccess(.identifier("obj"), "prop")
        let result = visitor.visit(expr)
        XCTAssertTrue(result.contains("field_access"))
        XCTAssertTrue(result.contains("identifier(\"obj\")"))
        XCTAssertTrue(result.contains("prop"))
    }
    
    func testVisitFunctionCall() {
        let visitor = ExpressionVisitor<String>(
            visitLiteral: { _ in "literal" },
            visitIdentifier: { _ in "id" },
            visitBinary: { _, _, _ in "binary" },
            visitUnary: { _, _ in "unary" },
            visitArrayAccess: { _, _ in "array_access" },
            visitFieldAccess: { _, _ in "field_access" },
            visitFunctionCall: { name, args in "function_call(\(name), \(args.count) args)" }
        )
        
        let expr = Expression.functionCall("max", [.literal(.integer(1)), .literal(.integer(2))])
        let result = visitor.visit(expr)
        XCTAssertEqual(result, "function_call(max, 2 args)")
    }
    
    func testDebugVisitor() {
        let visitor = ExpressionVisitor<String>.makeDebugVisitor()
        
        // Test simple literal
        XCTAssertEqual(visitor.visit(.literal(.integer(42))), "42")
        XCTAssertEqual(visitor.visit(.literal(.string("hello"))), "\"hello\"")
        XCTAssertEqual(visitor.visit(.literal(.boolean(true))), "true")
        
        // Test identifier
        XCTAssertEqual(visitor.visit(.identifier("x")), "x")
        
        // Test binary expression
        let binaryExpr = Expression.binary(.add, .literal(.integer(1)), .literal(.integer(2)))
        XCTAssertEqual(visitor.visit(binaryExpr), "(1 + 2)")
        
        // Test unary expression
        let unaryExpr = Expression.unary(.minus, .literal(.integer(5)))
        XCTAssertEqual(visitor.visit(unaryExpr), "-5")
        
        // Test array access
        let arrayExpr = Expression.arrayAccess(.identifier("arr"), .literal(.integer(0)))
        XCTAssertEqual(visitor.visit(arrayExpr), "arr[0]")
        
        // Test field access
        let fieldExpr = Expression.fieldAccess(.identifier("obj"), "prop")
        XCTAssertEqual(visitor.visit(fieldExpr), "obj.prop")
        
        // Test function call
        let funcExpr = Expression.functionCall("max", [.literal(.integer(1)), .literal(.integer(2))])
        XCTAssertEqual(visitor.visit(funcExpr), "max(1, 2)")
    }
    
    func testNestedExpressions() {
        let visitor = ExpressionVisitor<String>.makeDebugVisitor()
        
        // Test nested binary expressions: (1 + 2) * 3
        let nested = Expression.binary(
            .multiply,
            .binary(.add, .literal(.integer(1)), .literal(.integer(2))),
            .literal(.integer(3))
        )
        XCTAssertEqual(visitor.visit(nested), "((1 + 2) * 3)")
        
        // Test complex nested expression: max(arr[0], obj.prop)
        let complex = Expression.functionCall(
            "max",
            [
                .arrayAccess(.identifier("arr"), .literal(.integer(0))),
                .fieldAccess(.identifier("obj"), "prop")
            ]
        )
        XCTAssertEqual(visitor.visit(complex), "max(arr[0], obj.prop)")
    }
    
    func testSendableCompliance() {
        // Test that ExpressionVisitor can be used in concurrent contexts
        let visitor = ExpressionVisitor<Int>(
            visitLiteral: { _ in 1 },
            visitIdentifier: { _ in 1 },
            visitBinary: { _, _, _ in 1 },
            visitUnary: { _, _ in 1 },
            visitArrayAccess: { _, _ in 1 },
            visitFieldAccess: { _, _ in 1 },
            visitFunctionCall: { _, _ in 1 }
        )
        
        // This should compile without warnings if Sendable is properly implemented
        Task {
            let result = visitor.visit(.literal(.integer(42)))
            XCTAssertEqual(result, 1)
        }
    }
    
    func testCountingVisitor() {
        // Create a visitor that counts the number of nodes
        let countingVisitor = ExpressionVisitor<Int>(
            visitLiteral: { _ in 1 },
            visitIdentifier: { _ in 1 },
            visitBinary: { _, _, _ in 1 },
            visitUnary: { _, _ in 1 },
            visitArrayAccess: { _, _ in 1 },
            visitFieldAccess: { _, _ in 1 },
            visitFunctionCall: { _, _ in 1 }
        )
        
        // Test simple expression
        XCTAssertEqual(countingVisitor.visit(.literal(.integer(42))), 1)
        XCTAssertEqual(countingVisitor.visit(.identifier("x")), 1)
        
        // Test compound expression
        let binaryExpr = Expression.binary(.add, .literal(.integer(1)), .literal(.integer(2)))
        XCTAssertEqual(countingVisitor.visit(binaryExpr), 1) // Only counts the top-level node
    }
}