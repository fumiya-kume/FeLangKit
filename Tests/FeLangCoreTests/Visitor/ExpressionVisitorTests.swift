import XCTest
@testable import FeLangCore

final class ExpressionVisitorTests: XCTestCase {
    
    // MARK: - Basic Functionality Tests
    
    func testVisitLiteral() {
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
            visitIdentifier: { _ in "id" },
            visitBinary: { _, _, _ in "binary" },
            visitUnary: { _, _ in "unary" },
            visitArrayAccess: { _, _ in "array" },
            visitFieldAccess: { _, _ in "field" },
            visitFunctionCall: { _, _ in "call" }
        )
        
        XCTAssertEqual(visitor.visit(.literal(.integer(42))), "int(42)")
        XCTAssertEqual(visitor.visit(.literal(.real(3.14))), "real(3.14)")
        XCTAssertEqual(visitor.visit(.literal(.string("hello"))), "string(hello)")
        XCTAssertEqual(visitor.visit(.literal(.character("a"))), "char(a)")
        XCTAssertEqual(visitor.visit(.literal(.boolean(true))), "bool(true)")
    }
    
    func testVisitIdentifier() {
        let visitor = ExpressionVisitor<String>(
            visitLiteral: { _ in "literal" },
            visitIdentifier: { name in "id(\(name))" },
            visitBinary: { _, _, _ in "binary" },
            visitUnary: { _, _ in "unary" },
            visitArrayAccess: { _, _ in "array" },
            visitFieldAccess: { _, _ in "field" },
            visitFunctionCall: { _, _ in "call" }
        )
        
        XCTAssertEqual(visitor.visit(.identifier("variable")), "id(variable)")
        XCTAssertEqual(visitor.visit(.identifier("x")), "id(x)")
    }
    
    func testVisitBinary() {
        let visitor = ExpressionVisitor<String>(
            visitLiteral: { _ in "lit" },
            visitIdentifier: { _ in "id" },
            visitBinary: { op, left, right in "binary(\(op.rawValue), \(left), \(right))" },
            visitUnary: { _, _ in "unary" },
            visitArrayAccess: { _, _ in "array" },
            visitFieldAccess: { _, _ in "field" },
            visitFunctionCall: { _, _ in "call" }
        )
        
        let expr = Expression.binary(.add, .literal(.integer(1)), .literal(.integer(2)))
        XCTAssertEqual(visitor.visit(expr), "binary(+, lit, lit)")
    }
    
    func testVisitUnary() {
        let visitor = ExpressionVisitor<String>(
            visitLiteral: { _ in "lit" },
            visitIdentifier: { _ in "id" },
            visitBinary: { _, _, _ in "binary" },
            visitUnary: { op, expr in "unary(\(op.rawValue), \(expr))" },
            visitArrayAccess: { _, _ in "array" },
            visitFieldAccess: { _, _ in "field" },
            visitFunctionCall: { _, _ in "call" }
        )
        
        let expr = Expression.unary(.minus, .literal(.integer(5)))
        XCTAssertEqual(visitor.visit(expr), "unary(-, lit)")
    }
    
    func testVisitArrayAccess() {
        let visitor = ExpressionVisitor<String>(
            visitLiteral: { _ in "lit" },
            visitIdentifier: { _ in "id" },
            visitBinary: { _, _, _ in "binary" },
            visitUnary: { _, _ in "unary" },
            visitArrayAccess: { array, index in "array[\(array)][\(index)]" },
            visitFieldAccess: { _, _ in "field" },
            visitFunctionCall: { _, _ in "call" }
        )
        
        let expr = Expression.arrayAccess(.identifier("arr"), .literal(.integer(0)))
        XCTAssertEqual(visitor.visit(expr), "array[id][lit]")
    }
    
    func testVisitFieldAccess() {
        let visitor = ExpressionVisitor<String>(
            visitLiteral: { _ in "lit" },
            visitIdentifier: { _ in "id" },
            visitBinary: { _, _, _ in "binary" },
            visitUnary: { _, _ in "unary" },
            visitArrayAccess: { _, _ in "array" },
            visitFieldAccess: { object, field in "field(\(object).\(field))" },
            visitFunctionCall: { _, _ in "call" }
        )
        
        let expr = Expression.fieldAccess(.identifier("obj"), "property")
        XCTAssertEqual(visitor.visit(expr), "field(id.property)")
    }
    
    func testVisitFunctionCall() {
        let visitor = ExpressionVisitor<String>(
            visitLiteral: { _ in "lit" },
            visitIdentifier: { _ in "id" },
            visitBinary: { _, _, _ in "binary" },
            visitUnary: { _, _ in "unary" },
            visitArrayAccess: { _, _ in "array" },
            visitFieldAccess: { _, _ in "field" },
            visitFunctionCall: { name, args in "call(\(name), [\(args.count)])" }
        )
        
        let expr = Expression.functionCall("func", [.literal(.integer(1)), .identifier("x")])
        XCTAssertEqual(visitor.visit(expr), "call(func, [2])")
    }
    
    // MARK: - Complex Expression Tests
    
    func testComplexExpression() {
        let stringifier = ExpressionVisitor<String>(
            visitLiteral: { literal in
                switch literal {
                case .integer(let value): return "\(value)"
                case .real(let value): return "\(value)"
                case .string(let value): return "\"\(value)\""
                case .character(let value): return "'\(value)'"
                case .boolean(let value): return "\(value)"
                }
            },
            visitIdentifier: { name in name },
            visitBinary: { op, left, right in "(\(left) \(op.rawValue) \(right))" },
            visitUnary: { op, expr in "\(op.rawValue)\(expr)" },
            visitArrayAccess: { array, index in "\(array)[\(index)]" },
            visitFieldAccess: { object, field in "\(object).\(field)" },
            visitFunctionCall: { name, args in 
                return "\(name)(\(args.count)_args)"
            }
        )
        
        // Test: (a + b) * func(x, 2)
        let expr = Expression.binary(
            .multiply,
            .binary(.add, .identifier("a"), .identifier("b")),
            .functionCall("func", [.identifier("x"), .literal(.integer(2))])
        )
        
        XCTAssertEqual(stringifier.visit(expr), "((a + b) * func(2_args))")
    }
    
    // MARK: - Generic Result Type Tests
    
    func testIntegerResultType() {
        let counter = ExpressionVisitor<Int>(
            visitLiteral: { _ in 1 },
            visitIdentifier: { _ in 1 },
            visitBinary: { _, left, right in
                return 3 // simplified: left(1) + right(1) + binary(1) = 3
            },
            visitUnary: { _, expr in
                return 2 // simplified: expr(1) + unary(1) = 2
            },
            visitArrayAccess: { array, index in
                return 3 // simplified: array(1) + index(1) + access(1) = 3
            },
            visitFieldAccess: { object, _ in
                return 2 // simplified: object(1) + field(1) = 2
            },
            visitFunctionCall: { _, args in
                return 1 + args.count // simplified: call(1) + args
            }
        )
        
        let expr = Expression.binary(.add, .literal(.integer(1)), .identifier("x"))
        XCTAssertEqual(counter.visit(expr), 3) // left(1) + right(1) + binary(1) = 3
    }
    
    func testVoidResultType() {
        let visitCount = Ref(0)
        
        let voidVisitor = ExpressionVisitor<Void>(
            visitLiteral: { _ in visitCount.value += 1 },
            visitIdentifier: { _ in visitCount.value += 1 },
            visitBinary: { _, _, _ in visitCount.value += 1 },
            visitUnary: { _, _ in visitCount.value += 1 },
            visitArrayAccess: { _, _ in visitCount.value += 1 },
            visitFieldAccess: { _, _ in visitCount.value += 1 },
            visitFunctionCall: { _, _ in visitCount.value += 1 }
        )
        
        voidVisitor.visit(.literal(.integer(42)))
        XCTAssertEqual(visitCount.value, 1)
        
        voidVisitor.visit(.binary(.add, .identifier("a"), .identifier("b")))
        XCTAssertEqual(visitCount.value, 2) // Only visits the top-level binary node
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentAccess() {
        let visitor = ExpressionVisitor<String>(
            visitLiteral: { literal in
                Thread.sleep(forTimeInterval: 0.001) // Simulate work
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
        
        let expectation = XCTestExpectation(description: "Concurrent visitor access")
        expectation.expectedFulfillmentCount = 10
        
        for i in 0..<10 {
            Task {
                let result = visitor.visit(.literal(.integer(i)))
                XCTAssertEqual(result, "int(\(i))")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    // MARK: - Visitable Protocol Tests
    
    func testVisitableAccept() {
        let visitor = ExpressionVisitor<String>(
            visitLiteral: { _ in "literal" },
            visitIdentifier: { _ in "identifier" },
            visitBinary: { _, _, _ in "binary" },
            visitUnary: { _, _ in "unary" },
            visitArrayAccess: { _, _ in "array" },
            visitFieldAccess: { _, _ in "field" },
            visitFunctionCall: { _, _ in "call" }
        )
        
        let expr = Expression.literal(.integer(42))
        XCTAssertEqual(expr.accept(visitor), "literal")
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceVsDirectSwitch() {
        let expressions = (0..<1000).map { _ in
            Expression.binary(.add, .literal(.integer(1)), .literal(.integer(2)))
        }
        
        // Test visitor performance
        let visitor = ExpressionVisitor<Int>(
            visitLiteral: { _ in 1 },
            visitIdentifier: { _ in 1 },
            visitBinary: { _, _, _ in 1 },
            visitUnary: { _, _ in 1 },
            visitArrayAccess: { _, _ in 1 },
            visitFieldAccess: { _, _ in 1 },
            visitFunctionCall: { _, _ in 1 }
        )
        
        measure {
            for expr in expressions {
                _ = visitor.visit(expr)
            }
        }
    }
}