import Foundation
import Testing
@testable import FeLangCore

// Alias to avoid conflict with Foundation.Expression
typealias FEExpression = FeLangCore.Expression

@Suite("ExpressionVisitor Tests")
struct ExpressionVisitorTests {
    
    // MARK: - Basic Functionality Tests
    
    @Test func testExpressionVisitorBasicFunctionality() {
        var visitor: ExpressionVisitor<String>!
        visitor = ExpressionVisitor<String>(
            visitLiteral: { literal in "Literal(\(literal))" },
            visitIdentifier: { name in "Id(\(name))" },
            visitBinary: { op, left, right in "Binary(\(op.rawValue), \(visitor.visit(left)), \(visitor.visit(right)))" },
            visitUnary: { op, expr in "Unary(\(op.rawValue), \(visitor.visit(expr)))" },
            visitArrayAccess: { array, index in "ArrayAccess(\(visitor.visit(array)), \(visitor.visit(index)))" },
            visitFieldAccess: { object, field in "FieldAccess(\(visitor.visit(object)), \(field))" },
            visitFunctionCall: { name, args in "FunctionCall(\(name), [\(args.map { visitor.visit($0) }.joined(separator: ", "))])" }
        )
        
        // Test literal
        let literalExpr = FEExpression.literal(.integer(42))
        #expect(visitor.visit(literalExpr) == "Literal(integer(42))")
        
        // Test identifier
        let identifierExpr = FEExpression.identifier("x")
        #expect(visitor.visit(identifierExpr) == "Id(x)")
        
        // Test binary expression
        let binaryExpr = FEExpression.binary(.add, .literal(.integer(1)), .literal(.integer(2)))
        #expect(visitor.visit(binaryExpr) == "Binary(+, Literal(integer(1)), Literal(integer(2)))")
        
        // Test unary expression
        let unaryExpr = FEExpression.unary(.minus, .literal(.integer(5)))
        #expect(visitor.visit(unaryExpr) == "Unary(-, Literal(integer(5)))")
        
        // Test array access
        let arrayAccessExpr = FEExpression.arrayAccess(.identifier("arr"), .literal(.integer(0)))
        #expect(visitor.visit(arrayAccessExpr) == "ArrayAccess(Id(arr), Literal(integer(0)))")
        
        // Test field access
        let fieldAccessExpr = FEExpression.fieldAccess(.identifier("obj"), "field")
        #expect(visitor.visit(fieldAccessExpr) == "FieldAccess(Id(obj), field)")
        
        // Test function call
        let functionCallExpr = FEExpression.functionCall("func", [.literal(.integer(1)), .identifier("x")])
        #expect(visitor.visit(functionCallExpr) == "FunctionCall(func, [Literal(integer(1)), Id(x)])")
    }
    
    @Test func testExpressionVisitorWithDifferentResultTypes() {
        // Test with Int result type
        var countingVisitor: ExpressionVisitor<Int>!
        countingVisitor = ExpressionVisitor<Int>(
            visitLiteral: { _ in 1 },
            visitIdentifier: { _ in 1 },
            visitBinary: { _, left, right in countingVisitor.visit(left) + countingVisitor.visit(right) + 1 },
            visitUnary: { _, expr in countingVisitor.visit(expr) + 1 },
            visitArrayAccess: { array, index in countingVisitor.visit(array) + countingVisitor.visit(index) + 1 },
            visitFieldAccess: { object, _ in countingVisitor.visit(object) + 1 },
            visitFunctionCall: { _, args in args.reduce(1) { sum, arg in sum + countingVisitor.visit(arg) } }
        )
        
        let expr = FEExpression.binary(.add, .literal(.integer(1)), .identifier("x"))
        #expect(countingVisitor.visit(expr) == 3) // 1 (literal) + 1 (identifier) + 1 (binary) = 3
        
        // Test with Bool result type
        var hasIdentifierVisitor: ExpressionVisitor<Bool>!
        hasIdentifierVisitor = ExpressionVisitor<Bool>(
            visitLiteral: { _ in false },
            visitIdentifier: { _ in true },
            visitBinary: { _, left, right in hasIdentifierVisitor.visit(left) || hasIdentifierVisitor.visit(right) },
            visitUnary: { _, expr in hasIdentifierVisitor.visit(expr) },
            visitArrayAccess: { array, index in hasIdentifierVisitor.visit(array) || hasIdentifierVisitor.visit(index) },
            visitFieldAccess: { object, _ in hasIdentifierVisitor.visit(object) },
            visitFunctionCall: { _, args in args.contains { hasIdentifierVisitor.visit($0) } }
        )
        
        #expect(hasIdentifierVisitor.visit(expr) == true) // Contains identifier "x"
        #expect(hasIdentifierVisitor.visit(.literal(.integer(42))) == false) // No identifiers
    }
    
    // MARK: - Complex Expression Tests
    
    @Test func testComplexNestedExpression() {
        let visitor = ExpressionVisitor.debugStringifier()
        
        // Create a complex nested expression: (a + b) * func(x, y[0])
        let complexExpr = FEExpression.binary(
            .multiply,
            .binary(.add, .identifier("a"), .identifier("b")),
            .functionCall("func", [
                .identifier("x"),
                .arrayAccess(.identifier("y"), .literal(.integer(0)))
            ])
        )
        
        let result = visitor.visit(complexExpr)
        #expect(result == "((a + b) * func(x, y[0]))")
    }
    
    @Test func testExpressionWithAllLiteralTypes() {
        let visitor = ExpressionVisitor.debugStringifier()
        
        // Test all literal types
        #expect(visitor.visit(.literal(.integer(42))) == "42")
        #expect(visitor.visit(.literal(.real(3.14))) == "3.14")
        #expect(visitor.visit(.literal(.string("hello"))) == "\"hello\"")
        #expect(visitor.visit(.literal(.character("c"))) == "'c'")
        #expect(visitor.visit(.literal(.boolean(true))) == "true")
        #expect(visitor.visit(.literal(.boolean(false))) == "false")
    }
    
    @Test func testExpressionWithAllOperators() {
        let visitor = ExpressionVisitor.debugStringifier()
        
        // Test all binary operators
        let operators: [BinaryOperator] = [.add, .subtract, .multiply, .divide, .modulo, .equal, .notEqual, .greater, .greaterEqual, .less, .lessEqual, .and, .or]
        
        for op in operators {
            let expr = FEExpression.binary(op, .literal(.integer(1)), .literal(.integer(2)))
            let result = visitor.visit(expr)
            #expect(result.contains(op.rawValue))
        }
        
        // Test all unary operators
        let unaryOperators: [UnaryOperator] = [.not, .plus, .minus]
        
        for op in unaryOperators {
            let expr = FEExpression.unary(op, .literal(.integer(1)))
            let result = visitor.visit(expr)
            #expect(result.contains(op.rawValue))
        }
    }
    
    // MARK: - Visitable Protocol Tests
    
    @Test func testVisitableProtocolConformance() {
        let visitor = ExpressionVisitor.debugStringifier()
        let expr = FEExpression.literal(.integer(42))
        
        // Test that Expression conforms to Visitable
        let result = expr.accept(visitor)
        #expect(result == "42")
    }
    
    @Test func testArrayVisitableExtension() {
        let visitor = ExpressionVisitor<Int>(
            visitLiteral: { _ in 1 },
            visitIdentifier: { _ in 1 },
            visitBinary: { _, _, _ in 1 },
            visitUnary: { _, _ in 1 },
            visitArrayAccess: { _, _ in 1 },
            visitFieldAccess: { _, _ in 1 },
            visitFunctionCall: { _, _ in 1 }
        )
        
        let expressions: [FEExpression] = [
            .literal(.integer(1)),
            .identifier("x"),
            .binary(.add, .literal(.integer(1)), .literal(.integer(2)))
        ]
        
        let results = expressions.accept(visitor)
        #expect(results == [1, 1, 1])
    }
    
    // MARK: - Custom Result Type Tests
    
    struct ExpressionInfo: Equatable, Sendable {
        let type: String
        let nodeCount: Int
        let identifiers: Set<String>
    }
    
    @Test func testCustomResultType() {
        var analyzer: ExpressionVisitor<ExpressionInfo>!
        analyzer = ExpressionVisitor<ExpressionInfo>(
            visitLiteral: { _ in ExpressionInfo(type: "literal", nodeCount: 1, identifiers: []) },
            visitIdentifier: { name in ExpressionInfo(type: "identifier", nodeCount: 1, identifiers: [name]) },
            visitBinary: { _, left, right in
                let leftInfo = analyzer.visit(left)
                let rightInfo = analyzer.visit(right)
                return ExpressionInfo(
                    type: "binary",
                    nodeCount: leftInfo.nodeCount + rightInfo.nodeCount + 1,
                    identifiers: leftInfo.identifiers.union(rightInfo.identifiers)
                )
            },
            visitUnary: { _, expr in
                let exprInfo = analyzer.visit(expr)
                return ExpressionInfo(
                    type: "unary",
                    nodeCount: exprInfo.nodeCount + 1,
                    identifiers: exprInfo.identifiers
                )
            },
            visitArrayAccess: { array, index in
                let arrayInfo = analyzer.visit(array)
                let indexInfo = analyzer.visit(index)
                return ExpressionInfo(
                    type: "arrayAccess",
                    nodeCount: arrayInfo.nodeCount + indexInfo.nodeCount + 1,
                    identifiers: arrayInfo.identifiers.union(indexInfo.identifiers)
                )
            },
            visitFieldAccess: { object, _ in
                let objectInfo = analyzer.visit(object)
                return ExpressionInfo(
                    type: "fieldAccess",
                    nodeCount: objectInfo.nodeCount + 1,
                    identifiers: objectInfo.identifiers
                )
            },
            visitFunctionCall: { _, args in
                let argInfos = args.map { analyzer.visit($0) }
                return ExpressionInfo(
                    type: "functionCall",
                    nodeCount: argInfos.reduce(1) { sum, info in sum + info.nodeCount },
                    identifiers: argInfos.reduce(into: Set<String>()) { result, info in
                        result.formUnion(info.identifiers)
                    }
                )
            }
        )
        
        let expr = FEExpression.binary(.add, .identifier("x"), .identifier("y"))
        let result = analyzer.visit(expr)
        
        #expect(result.type == "binary")
        #expect(result.nodeCount == 3)
        #expect(result.identifiers == ["x", "y"])
    }
    
    // MARK: - Debug Stringifier Tests
    
    @Test func testDebugStringifier() {
        let visitor = ExpressionVisitor.debugStringifier()
        
        // Test various expressions
        #expect(visitor.visit(.literal(.integer(42))) == "42")
        #expect(visitor.visit(.identifier("variable")) == "variable")
        
        let binaryExpr = FEExpression.binary(.add, .literal(.integer(1)), .literal(.integer(2)))
        #expect(visitor.visit(binaryExpr) == "(1 + 2)")
        
        let unaryExpr = FEExpression.unary(.minus, .literal(.integer(5)))
        #expect(visitor.visit(unaryExpr) == "-(5)")
        
        let arrayAccess = FEExpression.arrayAccess(.identifier("arr"), .literal(.integer(0)))
        #expect(visitor.visit(arrayAccess) == "arr[0]")
        
        let fieldAccess = FEExpression.fieldAccess(.identifier("obj"), "property")
        #expect(visitor.visit(fieldAccess) == "obj.property")
        
        let functionCall = FEExpression.functionCall("sqrt", [.literal(.integer(16))])
        #expect(visitor.visit(functionCall) == "sqrt(16)")
    }
    
    // MARK: - Performance Tests
    
    @Test func testPerformanceComparedToDirectSwitch() {
        let expr = createLargeExpression(depth: 8)
        
        // Direct switch implementation
        func processDirectly(_ expr: FEExpression) -> String {
            switch expr {
            case .literal(let literal):
                return "Literal(\(literal))"
            case .identifier(let name):
                return "Id(\(name))"
            case .binary(let op, let left, let right):
                return "Binary(\(op.rawValue), \(processDirectly(left)), \(processDirectly(right)))"
            case .unary(let op, let operand):
                return "Unary(\(op.rawValue), \(processDirectly(operand)))"
            case .arrayAccess(let array, let index):
                return "ArrayAccess(\(processDirectly(array)), \(processDirectly(index)))"
            case .fieldAccess(let object, let field):
                return "FieldAccess(\(processDirectly(object)), \(field))"
            case .functionCall(let name, let args):
                return "FunctionCall(\(name), [\(args.map(processDirectly).joined(separator: ", "))])"
            }
        }
        
        // Visitor implementation
        var visitor: ExpressionVisitor<String>!
        visitor = ExpressionVisitor<String>(
            visitLiteral: { literal in "Literal(\(literal))" },
            visitIdentifier: { name in "Id(\(name))" },
            visitBinary: { op, left, right in "Binary(\(op.rawValue), \(visitor.visit(left)), \(visitor.visit(right)))" },
            visitUnary: { op, operand in "Unary(\(op.rawValue), \(visitor.visit(operand)))" },
            visitArrayAccess: { array, index in "ArrayAccess(\(visitor.visit(array)), \(visitor.visit(index)))" },
            visitFieldAccess: { object, field in "FieldAccess(\(visitor.visit(object)), \(field))" },
            visitFunctionCall: { name, args in "FunctionCall(\(name), [\(args.map { visitor.visit($0) }.joined(separator: ", "))])" }
        )
        
        // Measure direct switch performance
        let directSwitchTime = measureTime {
            let _ = processDirectly(expr)
        }
        
        // Measure visitor performance
        let visitorTime = measureTime {
            let _ = visitor.visit(expr)
        }
        
        // Visitor should be within reasonable performance bounds
        let performanceRatio = visitorTime / directSwitchTime
        #expect(performanceRatio < 2.0) // Allow for some overhead
    }
    
    // MARK: - Helper Methods
    
    private func createLargeExpression(depth: Int) -> FEExpression {
        if depth <= 0 {
            return .literal(.integer(depth))
        }
        
        return .binary(
            .add,
            createLargeExpression(depth: depth - 1),
            createLargeExpression(depth: depth - 1)
        )
    }
    
    private func measureTime(_ block: () -> Void) -> TimeInterval {
        let startTime = CFAbsoluteTimeGetCurrent()
        block()
        let endTime = CFAbsoluteTimeGetCurrent()
        return endTime - startTime
    }
}