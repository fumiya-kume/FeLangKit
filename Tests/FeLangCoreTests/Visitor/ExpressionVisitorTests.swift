import Testing
@testable import FeLangCore

@Suite("ExpressionVisitor Tests")
struct ExpressionVisitorTests {

    // MARK: - Basic Visitor Tests

    @Test func visitLiteral() {
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
            visitIdentifier: { _ in "identifier" },
            visitBinary: { _, _, _ in "binary" },
            visitUnary: { _, _ in "unary" },
            visitArrayAccess: { _, _ in "array_access" },
            visitFieldAccess: { _, _ in "field_access" },
            visitFunctionCall: { _, _ in "function_call" }
        )

        #expect(visitor.visit(.literal(.integer(42))) == "int(42)")
        #expect(visitor.visit(.literal(.real(3.14))) == "real(3.14)")
        #expect(visitor.visit(.literal(.string("hello"))) == "string(hello)")
        #expect(visitor.visit(.literal(.character("x"))) == "char(x)")
        #expect(visitor.visit(.literal(.boolean(true))) == "bool(true)")
    }

    @Test func visitIdentifier() {
        let visitor = ExpressionVisitor<String>(
            visitLiteral: { _ in "literal" },
            visitIdentifier: { identifier in "id(\(identifier))" },
            visitBinary: { _, _, _ in "binary" },
            visitUnary: { _, _ in "unary" },
            visitArrayAccess: { _, _ in "array_access" },
            visitFieldAccess: { _, _ in "field_access" },
            visitFunctionCall: { _, _ in "function_call" }
        )

        #expect(visitor.visit(.identifier("variable")) == "id(variable)")
        #expect(visitor.visit(.identifier("x")) == "id(x)")
    }

    @Test func visitBinary() {
        let visitor = ExpressionVisitor<String>(
            visitLiteral: { _ in "literal" },
            visitIdentifier: { _ in "identifier" },
            visitBinary: { op, left, right in "binary(\(op.rawValue), \(left), \(right))" },
            visitUnary: { _, _ in "unary" },
            visitArrayAccess: { _, _ in "array_access" },
            visitFieldAccess: { _, _ in "field_access" },
            visitFunctionCall: { _, _ in "function_call" }
        )

        let expr = Expression.binary(.add, .literal(.integer(1)), .literal(.integer(2)))

        // Note: This will show the raw Expression values, not the recursive visitor results
        let result = visitor.visit(expr)
        #expect(result.hasPrefix("binary(+,"))
        #expect(result.contains("literal("))
        #expect(result.contains("integer(1)"))
        #expect(result.contains("integer(2)"))
    }

    @Test func visitUnary() {
        let visitor = ExpressionVisitor<String>(
            visitLiteral: { _ in "literal" },
            visitIdentifier: { _ in "identifier" },
            visitBinary: { _, _, _ in "binary" },
            visitUnary: { op, operand in "unary(\(op.rawValue), \(operand))" },
            visitArrayAccess: { _, _ in "array_access" },
            visitFieldAccess: { _, _ in "field_access" },
            visitFunctionCall: { _, _ in "function_call" }
        )

        let expr = Expression.unary(.not, .literal(.boolean(true)))
        let result = visitor.visit(expr)
        #expect(result.hasPrefix("unary(not,"))
        #expect(result.contains("boolean(true)"))
    }

    @Test func visitArrayAccess() {
        let visitor = ExpressionVisitor<String>(
            visitLiteral: { _ in "literal" },
            visitIdentifier: { _ in "identifier" },
            visitBinary: { _, _, _ in "binary" },
            visitUnary: { _, _ in "unary" },
            visitArrayAccess: { array, index in "array_access(\(array), \(index))" },
            visitFieldAccess: { _, _ in "field_access" },
            visitFunctionCall: { _, _ in "function_call" }
        )

        let expr = Expression.arrayAccess(.identifier("arr"), .literal(.integer(0)))
        let result = visitor.visit(expr)
        #expect(result.hasPrefix("array_access(identifier(\"arr\"),"))
        #expect(result.contains("integer(0)"))
    }

    @Test func visitFieldAccess() {
        let visitor = ExpressionVisitor<String>(
            visitLiteral: { _ in "literal" },
            visitIdentifier: { _ in "identifier" },
            visitBinary: { _, _, _ in "binary" },
            visitUnary: { _, _ in "unary" },
            visitArrayAccess: { _, _ in "array_access" },
            visitFieldAccess: { object, field in "field_access(\(object), \(field))" },
            visitFunctionCall: { _, _ in "function_call" }
        )

        let expr = Expression.fieldAccess(.identifier("obj"), "property")
        let result = visitor.visit(expr)
        #expect(result.hasPrefix("field_access("))
        #expect(result.contains("identifier(\"obj\")"))
        #expect(result.contains("property"))
    }

    @Test func visitFunctionCall() {
        let visitor = ExpressionVisitor<String>(
            visitLiteral: { _ in "literal" },
            visitIdentifier: { _ in "identifier" },
            visitBinary: { _, _, _ in "binary" },
            visitUnary: { _, _ in "unary" },
            visitArrayAccess: { _, _ in "array_access" },
            visitFieldAccess: { _, _ in "field_access" },
            visitFunctionCall: { function, arguments in "function_call(\(function), \(arguments.count) args)" }
        )

        let expr = Expression.functionCall("func", [.literal(.integer(1)), .identifier("x")])
        let result = visitor.visit(expr)
        #expect(result == "function_call(func, 2 args)")
    }

    // MARK: - Manual Recursive Visitor Test

    @Test func manualRecursiveVisitor() {
        // Create a manual recursive visitor for basic expression stringification
        func stringifyExpression(_ expr: FeLangCore.Expression) -> String {
            switch expr {
            case .literal(let literal):
                switch literal {
                case .integer(let value): return "\(value)"
                case .real(let value): return "\(value)"
                case .string(let value): return "\"\(value)\""
                case .character(let value): return "'\(value)'"
                case .boolean(let value): return "\(value)"
                }
            case .identifier(let identifier):
                return identifier
            case .binary(let op, let left, let right):
                return "(\(stringifyExpression(left)) \(op.rawValue) \(stringifyExpression(right)))"
            case .unary(let op, let operand):
                return "\(op.rawValue) \(stringifyExpression(operand))"
            case .arrayAccess(let array, let index):
                return "\(stringifyExpression(array))[\(stringifyExpression(index))]"
            case .fieldAccess(let object, let field):
                return "\(stringifyExpression(object)).\(field)"
            case .functionCall(let function, let arguments):
                let argStrings = arguments.map(stringifyExpression)
                return "\(function)(\(argStrings.joined(separator: ", ")))"
            }
        }

        // Test simple literal
        #expect(stringifyExpression(FeLangCore.Expression.literal(.integer(42))) == "42")

        // Test binary expression
        let binaryExpr = FeLangCore.Expression.binary(.add, .literal(.integer(1)), .literal(.integer(2)))
        #expect(stringifyExpression(binaryExpr) == "(1 + 2)")

        // Test nested binary expression
        let nestedExpr = FeLangCore.Expression.binary(.multiply,
                                         .binary(.add, .literal(.integer(1)), .literal(.integer(2))),
                                         .literal(.integer(3)))
        #expect(stringifyExpression(nestedExpr) == "((1 + 2) * 3)")

        // Test function call with arguments
        let funcCall = FeLangCore.Expression.functionCall("max", [.literal(.integer(1)), .literal(.integer(2))])
        #expect(stringifyExpression(funcCall) == "max(1, 2)")

        // Test field access
        let fieldAccess = FeLangCore.Expression.fieldAccess(.identifier("obj"), "prop")
        #expect(stringifyExpression(fieldAccess) == "obj.prop")

        // Test array access
        let arrayAccess = FeLangCore.Expression.arrayAccess(.identifier("arr"), .literal(.integer(0)))
        #expect(stringifyExpression(arrayAccess) == "arr[0]")
    }

    // MARK: - Visitable Protocol Tests

    @Test func visitableProtocolConformance() {
        let visitor = ExpressionVisitor<String>(
            visitLiteral: { _ in "literal" },
            visitIdentifier: { _ in "identifier" },
            visitBinary: { _, _, _ in "binary" },
            visitUnary: { _, _ in "unary" },
            visitArrayAccess: { _, _ in "array_access" },
            visitFieldAccess: { _, _ in "field_access" },
            visitFunctionCall: { _, _ in "function_call" }
        )

        let expr = Expression.literal(.integer(42))

        // Test accept method
        #expect(expr.accept(visitor) == "literal")

        // Test convenience method
        #expect(expr.visit(with: visitor) == "literal")
    }

    // MARK: - Type Counting Visitor Test

    @Test func typeCountingVisitor() {
        // Create a manual recursive visitor for counting node types
        func countExpressionTypes(_ expr: FeLangCore.Expression) -> [String: Int] {
            switch expr {
            case .literal:
                return ["literal": 1]
            case .identifier:
                return ["identifier": 1]
            case .binary(_, let left, let right):
                var result = ["binary": 1]
                let leftCounts = countExpressionTypes(left)
                let rightCounts = countExpressionTypes(right)
                for (key, value) in leftCounts {
                    result[key, default: 0] += value
                }
                for (key, value) in rightCounts {
                    result[key, default: 0] += value
                }
                return result
            case .unary(_, let operand):
                var result = ["unary": 1]
                let operandCounts = countExpressionTypes(operand)
                for (key, value) in operandCounts {
                    result[key, default: 0] += value
                }
                return result
            case .arrayAccess(let array, let index):
                var result = ["array_access": 1]
                let arrayCounts = countExpressionTypes(array)
                let indexCounts = countExpressionTypes(index)
                for (key, value) in arrayCounts {
                    result[key, default: 0] += value
                }
                for (key, value) in indexCounts {
                    result[key, default: 0] += value
                }
                return result
            case .fieldAccess(let object, _):
                var result = ["field_access": 1]
                let objectCounts = countExpressionTypes(object)
                for (key, value) in objectCounts {
                    result[key, default: 0] += value
                }
                return result
            case .functionCall(_, let arguments):
                var result = ["function_call": 1]
                for arg in arguments {
                    let argCounts = countExpressionTypes(arg)
                    for (key, value) in argCounts {
                        result[key, default: 0] += value
                    }
                }
                return result
            }
        }

        // Test with a complex expression: (x + 1) * func(y)
        let complexExpr = FeLangCore.Expression.binary(.multiply,
                                          .binary(.add, .identifier("x"), .literal(.integer(1))),
                                          .functionCall("func", [.identifier("y")]))

        let counts = countExpressionTypes(complexExpr)
        #expect(counts["binary"] == 2)
        #expect(counts["identifier"] == 2)
        #expect(counts["literal"] == 1)
        #expect(counts["function_call"] == 1)
    }

    // MARK: - Performance Test

    @Test func visitorPerformance() {
        // Create a manual recursive counter for performance testing
        func countNodes(_ expr: FeLangCore.Expression) -> Int {
            switch expr {
            case .literal:
                return 1
            case .identifier:
                return 1
            case .binary(_, let left, let right):
                return countNodes(left) + countNodes(right) + 1
            case .unary(_, let operand):
                return countNodes(operand) + 1
            case .arrayAccess(let array, let index):
                return countNodes(array) + countNodes(index) + 1
            case .fieldAccess(let object, _):
                return countNodes(object) + 1
            case .functionCall(_, let arguments):
                return arguments.map(countNodes).reduce(1, +)
            }
        }

        // Create a deep binary expression tree
        var expr = FeLangCore.Expression.literal(.integer(1))
        for _ in 0..<100 { // Reduced from 1000 to avoid stack overflow
            expr = .binary(.add, expr, .literal(.integer(1)))
        }

        // Swift Testing doesn't have a built-in measure, so we'll validate the functionality
        let nodeCount = countNodes(expr)
        #expect(nodeCount == 201) // 1 initial + 100 * 2 (binary + literal) = 201
    }
}
