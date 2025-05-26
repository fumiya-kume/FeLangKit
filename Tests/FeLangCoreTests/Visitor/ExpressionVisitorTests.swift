import XCTest
@testable import FeLangCore

final class ExpressionVisitorTests: XCTestCase {
    
    // MARK: - Basic Visitor Tests
    
    func testLiteralVisitor() {
        let literal = Expression.literal(.integer(42))
        let visitor = ExpressionVisitor<String>(
            visitLiteral: { lit in
                switch lit {
                case .integer(let value):
                    return "Int(\(value))"
                default:
                    return "Other"
                }
            },
            visitIdentifier: { _ in "" },
            visitBinary: { _, _, _ in "" },
            visitUnary: { _, _ in "" },
            visitArrayAccess: { _, _ in "" },
            visitFieldAccess: { _, _ in "" },
            visitFunctionCall: { _, _ in "" }
        )
        
        let result = visitor.visit(literal)
        XCTAssertEqual(result, "Int(42)")
    }
    
    func testIdentifierVisitor() {
        let identifier = Expression.identifier("x")
        let visitor = ExpressionVisitor<String>(
            visitLiteral: { _ in "" },
            visitIdentifier: { name in "Var(\(name))" },
            visitBinary: { _, _, _ in "" },
            visitUnary: { _, _ in "" },
            visitArrayAccess: { _, _ in "" },
            visitFieldAccess: { _, _ in "" },
            visitFunctionCall: { _, _ in "" }
        )
        
        let result = visitor.visit(identifier)
        XCTAssertEqual(result, "Var(x)")
    }
    
    func testBinaryExpressionVisitor() {
        let left = Expression.literal(.integer(1))
        let right = Expression.literal(.integer(2))
        let binary = Expression.binary(.add, left, right)
        
        let visitor = ExpressionVisitor<String>(
            visitLiteral: { lit in
                switch lit {
                case .integer(let value):
                    return "\(value)"
                default:
                    return "?"
                }
            },
            visitIdentifier: { _ in "" },
            visitBinary: { op, left, right in
                let leftStr = ExpressionVisitor<String>(
                    visitLiteral: { lit in
                        switch lit {
                        case .integer(let value):
                            return "\(value)"
                        default:
                            return "?"
                        }
                    },
                    visitIdentifier: { _ in "" },
                    visitBinary: { _, _, _ in "" },
                    visitUnary: { _, _ in "" },
                    visitArrayAccess: { _, _ in "" },
                    visitFieldAccess: { _, _ in "" },
                    visitFunctionCall: { _, _ in "" }
                ).visit(left)
                let rightStr = ExpressionVisitor<String>(
                    visitLiteral: { lit in
                        switch lit {
                        case .integer(let value):
                            return "\(value)"
                        default:
                            return "?"
                        }
                    },
                    visitIdentifier: { _ in "" },
                    visitBinary: { _, _, _ in "" },
                    visitUnary: { _, _ in "" },
                    visitArrayAccess: { _, _ in "" },
                    visitFieldAccess: { _, _ in "" },
                    visitFunctionCall: { _, _ in "" }
                ).visit(right)
                return "(\(leftStr) \(op.rawValue) \(rightStr))"
            },
            visitUnary: { _, _ in "" },
            visitArrayAccess: { _, _ in "" },
            visitFieldAccess: { _, _ in "" },
            visitFunctionCall: { _, _ in "" }
        )
        
        let result = visitor.visit(binary)
        XCTAssertEqual(result, "(1 + 2)")
    }
    
    func testUnaryExpressionVisitor() {
        let expr = Expression.literal(.integer(5))
        let unary = Expression.unary(.minus, expr)
        
        let visitor = ExpressionVisitor<String>(
            visitLiteral: { lit in
                switch lit {
                case .integer(let value):
                    return "\(value)"
                default:
                    return "?"
                }
            },
            visitIdentifier: { _ in "" },
            visitBinary: { _, _, _ in "" },
            visitUnary: { op, expr in
                let exprStr = ExpressionVisitor<String>(
                    visitLiteral: { lit in
                        switch lit {
                        case .integer(let value):
                            return "\(value)"
                        default:
                            return "?"
                        }
                    },
                    visitIdentifier: { _ in "" },
                    visitBinary: { _, _, _ in "" },
                    visitUnary: { _, _ in "" },
                    visitArrayAccess: { _, _ in "" },
                    visitFieldAccess: { _, _ in "" },
                    visitFunctionCall: { _, _ in "" }
                ).visit(expr)
                return "\(op.rawValue)\(exprStr)"
            },
            visitArrayAccess: { _, _ in "" },
            visitFieldAccess: { _, _ in "" },
            visitFunctionCall: { _, _ in "" }
        )
        
        let result = visitor.visit(unary)
        XCTAssertEqual(result, "-5")
    }
    
    func testArrayAccessVisitor() {
        let array = Expression.identifier("arr")
        let index = Expression.literal(.integer(0))
        let arrayAccess = Expression.arrayAccess(array, index)
        
        let visitor = ExpressionVisitor<String>(
            visitLiteral: { lit in
                switch lit {
                case .integer(let value):
                    return "\(value)"
                default:
                    return "?"
                }
            },
            visitIdentifier: { name in name },
            visitBinary: { _, _, _ in "" },
            visitUnary: { _, _ in "" },
            visitArrayAccess: { array, index in
                let arrayVisitor = ExpressionVisitor<String>(
                    visitLiteral: { lit in
                        switch lit {
                        case .integer(let value):
                            return "\(value)"
                        default:
                            return "?"
                        }
                    },
                    visitIdentifier: { name in name },
                    visitBinary: { _, _, _ in "" },
                    visitUnary: { _, _ in "" },
                    visitArrayAccess: { _, _ in "" },
                    visitFieldAccess: { _, _ in "" },
                    visitFunctionCall: { _, _ in "" }
                )
                let arrayStr = arrayVisitor.visit(array)
                let indexStr = arrayVisitor.visit(index)
                return "\(arrayStr)[\(indexStr)]"
            },
            visitFieldAccess: { _, _ in "" },
            visitFunctionCall: { _, _ in "" }
        )
        
        let result = visitor.visit(arrayAccess)
        XCTAssertEqual(result, "arr[0]")
    }
    
    func testFieldAccessVisitor() {
        let object = Expression.identifier("obj")
        let fieldAccess = Expression.fieldAccess(object, "field")
        
        let visitor = ExpressionVisitor<String>(
            visitLiteral: { _ in "" },
            visitIdentifier: { name in name },
            visitBinary: { _, _, _ in "" },
            visitUnary: { _, _ in "" },
            visitArrayAccess: { _, _ in "" },
            visitFieldAccess: { object, field in
                let objectVisitor = ExpressionVisitor<String>(
                    visitLiteral: { _ in "" },
                    visitIdentifier: { name in name },
                    visitBinary: { _, _, _ in "" },
                    visitUnary: { _, _ in "" },
                    visitArrayAccess: { _, _ in "" },
                    visitFieldAccess: { _, _ in "" },
                    visitFunctionCall: { _, _ in "" }
                )
                let objectStr = objectVisitor.visit(object)
                return "\(objectStr).\(field)"
            },
            visitFunctionCall: { _, _ in "" }
        )
        
        let result = visitor.visit(fieldAccess)
        XCTAssertEqual(result, "obj.field")
    }
    
    func testFunctionCallVisitor() {
        let args = [
            Expression.literal(.integer(1)),
            Expression.literal(.integer(2))
        ]
        let functionCall = Expression.functionCall("add", args)
        
        let visitor = ExpressionVisitor<String>(
            visitLiteral: { lit in
                switch lit {
                case .integer(let value):
                    return "\(value)"
                default:
                    return "?"
                }
            },
            visitIdentifier: { _ in "" },
            visitBinary: { _, _, _ in "" },
            visitUnary: { _, _ in "" },
            visitArrayAccess: { _, _ in "" },
            visitFieldAccess: { _, _ in "" },
            visitFunctionCall: { name, args in
                let argVisitor = ExpressionVisitor<String>(
                    visitLiteral: { lit in
                        switch lit {
                        case .integer(let value):
                            return "\(value)"
                        default:
                            return "?"
                        }
                    },
                    visitIdentifier: { _ in "" },
                    visitBinary: { _, _, _ in "" },
                    visitUnary: { _, _ in "" },
                    visitArrayAccess: { _, _ in "" },
                    visitFieldAccess: { _, _ in "" },
                    visitFunctionCall: { _, _ in "" }
                )
                let argStrs = args.map { argVisitor.visit($0) }
                return "\(name)(\(argStrs.joined(separator: ", ")))"
            }
        )
        
        let result = visitor.visit(functionCall)
        XCTAssertEqual(result, "add(1, 2)")
    }
    
    // MARK: - Built-in Visitor Tests
    
    func testDebugVisitor() {
        let expr = Expression.binary(.add, 
            Expression.literal(.integer(1)), 
            Expression.literal(.integer(2))
        )
        
        let result = ExpressionVisitor.debug.visit(expr)
        XCTAssertTrue(result.contains("Binary"))
        XCTAssertTrue(result.contains("Literal.integer(1)"))
        XCTAssertTrue(result.contains("Literal.integer(2)"))
    }
    
    func testDebugVisitorAllLiteralTypes() {
        let intExpr = Expression.literal(.integer(42))
        let realExpr = Expression.literal(.real(3.14))
        let stringExpr = Expression.literal(.string("hello"))
        let charExpr = Expression.literal(.character("x"))
        let boolExpr = Expression.literal(.boolean(true))
        
        XCTAssertEqual(ExpressionVisitor.debug.visit(intExpr), "Literal.integer(42)")
        XCTAssertEqual(ExpressionVisitor.debug.visit(realExpr), "Literal.real(3.14)")
        XCTAssertEqual(ExpressionVisitor.debug.visit(stringExpr), "Literal.string(\"hello\")")
        XCTAssertEqual(ExpressionVisitor.debug.visit(charExpr), "Literal.character('x')")
        XCTAssertEqual(ExpressionVisitor.debug.visit(boolExpr), "Literal.boolean(true)")
    }
    
    // MARK: - Counter Visitor Tests
    
    func testCounterVisitor() {
        let expr = Expression.binary(.add,
            Expression.literal(.integer(1)),
            Expression.binary(.multiply,
                Expression.literal(.integer(2)),
                Expression.literal(.integer(3))
            )
        )
        
        // Count all literals
        let literalCounter = ExpressionVisitor.counter(for: Expression.self) { expr in
            if case .literal = expr {
                return true
            }
            return false
        }
        
        let literalCount = literalCounter.visit(expr)
        XCTAssertEqual(literalCount, 3)
        
        // Count all binary operations
        let binaryCounter = ExpressionVisitor.counter(for: Expression.self) { expr in
            if case .binary = expr {
                return true
            }
            return false
        }
        
        let binaryCount = binaryCounter.visit(expr)
        XCTAssertEqual(binaryCount, 2)
    }
    
    // MARK: - Complex Expression Tests
    
    func testComplexExpression() {
        // Create a complex nested expression: add(x, arr[0].field)
        let complexExpr = Expression.functionCall("add", [
            Expression.identifier("x"),
            Expression.fieldAccess(
                Expression.arrayAccess(
                    Expression.identifier("arr"),
                    Expression.literal(.integer(0))
                ),
                "field"
            )
        ])
        
        let result = ExpressionVisitor.debug.visit(complexExpr)
        XCTAssertTrue(result.contains("FunctionCall"))
        XCTAssertTrue(result.contains("FieldAccess"))
        XCTAssertTrue(result.contains("ArrayAccess"))
        XCTAssertTrue(result.contains("Identifier(x)"))
        XCTAssertTrue(result.contains("Identifier(arr)"))
    }
    
    // MARK: - Thread Safety Tests
    
    func testVisitorThreadSafety() {
        let expr = Expression.binary(.add,
            Expression.literal(.integer(1)),
            Expression.literal(.integer(2))
        )
        
        let visitor = ExpressionVisitor.debug
        
        // Test concurrent access
        let expectation = self.expectation(description: "Concurrent visitor access")
        expectation.expectedFulfillmentCount = 10
        
        for _ in 0..<10 {
            DispatchQueue.global().async {
                let result = visitor.visit(expr)
                XCTAssertTrue(result.contains("Binary"))
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 5.0)
    }
    
    // MARK: - Edge Cases
    
    func testEmptyFunctionCall() {
        let emptyCall = Expression.functionCall("empty", [])
        let result = ExpressionVisitor.debug.visit(emptyCall)
        XCTAssertEqual(result, "FunctionCall(empty, [])")
    }
    
    func testNestedUnaryOperations() {
        let nested = Expression.unary(.not,
            Expression.unary(.not,
                Expression.literal(.boolean(true))
            )
        )
        
        let result = ExpressionVisitor.debug.visit(nested)
        XCTAssertTrue(result.contains("Unary(not"))
        XCTAssertTrue(result.contains("boolean(true)"))
    }
}