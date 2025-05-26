import Foundation

/// A function-based visitor for traversing Expression AST nodes.
/// Uses closure-based dispatch for maximum flexibility and Swift-idiomatic patterns.
public struct ExpressionVisitor<Result>: @unchecked Sendable {
    
    // MARK: - Visitor Functions
    
    public let visitLiteral: @Sendable (Literal) -> Result
    public let visitIdentifier: @Sendable (String) -> Result
    public let visitBinary: @Sendable (BinaryOperator, Expression, Expression) -> Result
    public let visitUnary: @Sendable (UnaryOperator, Expression) -> Result
    public let visitArrayAccess: @Sendable (Expression, Expression) -> Result
    public let visitFieldAccess: @Sendable (Expression, String) -> Result
    public let visitFunctionCall: @Sendable (String, [Expression]) -> Result
    
    // MARK: - Initialization
    
    /// Creates a new ExpressionVisitor with the specified closure functions.
    public init(
        visitLiteral: @escaping @Sendable (Literal) -> Result,
        visitIdentifier: @escaping @Sendable (String) -> Result,
        visitBinary: @escaping @Sendable (BinaryOperator, Expression, Expression) -> Result,
        visitUnary: @escaping @Sendable (UnaryOperator, Expression) -> Result,
        visitArrayAccess: @escaping @Sendable (Expression, Expression) -> Result,
        visitFieldAccess: @escaping @Sendable (Expression, String) -> Result,
        visitFunctionCall: @escaping @Sendable (String, [Expression]) -> Result
    ) {
        self.visitLiteral = visitLiteral
        self.visitIdentifier = visitIdentifier
        self.visitBinary = visitBinary
        self.visitUnary = visitUnary
        self.visitArrayAccess = visitArrayAccess
        self.visitFieldAccess = visitFieldAccess
        self.visitFunctionCall = visitFunctionCall
    }
    
    // MARK: - Dispatch
    
    /// Visits an Expression node by dispatching to the appropriate closure.
    public func visit(_ expression: Expression) -> Result {
        switch expression {
        case .literal(let literal):
            return visitLiteral(literal)
        case .identifier(let name):
            return visitIdentifier(name)
        case .binary(let op, let left, let right):
            return visitBinary(op, left, right)
        case .unary(let op, let expr):
            return visitUnary(op, expr)
        case .arrayAccess(let array, let index):
            return visitArrayAccess(array, index)
        case .fieldAccess(let object, let field):
            return visitFieldAccess(object, field)
        case .functionCall(let name, let args):
            return visitFunctionCall(name, args)
        }
    }
}

// MARK: - Built-in Visitors

extension ExpressionVisitor {
    
    /// A debug visitor that produces a string representation of Expression nodes.
    public static var debug: ExpressionVisitor<String> {
        return ExpressionVisitor<String>(
            visitLiteral: { literal in
                switch literal {
                case .integer(let value):
                    return "Literal.integer(\(value))"
                case .real(let value):
                    return "Literal.real(\(value))"
                case .string(let value):
                    return "Literal.string(\"\(value)\")"
                case .character(let value):
                    return "Literal.character('\(value)')"
                case .boolean(let value):
                    return "Literal.boolean(\(value))"
                }
            },
            visitIdentifier: { name in
                return "Identifier(\(name))"
            },
            visitBinary: { op, left, right in
                let leftStr = ExpressionVisitor.debug.visit(left)
                let rightStr = ExpressionVisitor.debug.visit(right)
                return "Binary(\(op.rawValue), \(leftStr), \(rightStr))"
            },
            visitUnary: { op, expr in
                let exprStr = ExpressionVisitor.debug.visit(expr)
                return "Unary(\(op.rawValue), \(exprStr))"
            },
            visitArrayAccess: { array, index in
                let arrayStr = ExpressionVisitor.debug.visit(array)
                let indexStr = ExpressionVisitor.debug.visit(index)
                return "ArrayAccess(\(arrayStr), \(indexStr))"
            },
            visitFieldAccess: { object, field in
                let objectStr = ExpressionVisitor.debug.visit(object)
                return "FieldAccess(\(objectStr), \(field))"
            },
            visitFunctionCall: { name, args in
                let argStrs = args.map { ExpressionVisitor.debug.visit($0) }
                return "FunctionCall(\(name), [\(argStrs.joined(separator: ", "))])"
            }
        )
    }
}

// MARK: - Convenience Factory Methods

extension ExpressionVisitor {
    
    /// Creates a visitor that counts the number of nodes of a specific type.
    public static func counter<T>(for nodeType: T.Type, matching predicate: @escaping @Sendable (Expression) -> Bool) -> ExpressionVisitor<Int> {
        return ExpressionVisitor<Int>(
            visitLiteral: { _ in predicate(.literal($0)) ? 1 : 0 },
            visitIdentifier: { name in predicate(.identifier(name)) ? 1 : 0 },
            visitBinary: { op, left, right in
                let expr = Expression.binary(op, left, right)
                let selfCount = predicate(expr) ? 1 : 0
                let leftCount = ExpressionVisitor.counter(for: nodeType, matching: predicate).visit(left)
                let rightCount = ExpressionVisitor.counter(for: nodeType, matching: predicate).visit(right)
                return selfCount + leftCount + rightCount
            },
            visitUnary: { op, expr in
                let unaryExpr = Expression.unary(op, expr)
                let selfCount = predicate(unaryExpr) ? 1 : 0
                let exprCount = ExpressionVisitor.counter(for: nodeType, matching: predicate).visit(expr)
                return selfCount + exprCount
            },
            visitArrayAccess: { array, index in
                let expr = Expression.arrayAccess(array, index)
                let selfCount = predicate(expr) ? 1 : 0
                let arrayCount = ExpressionVisitor.counter(for: nodeType, matching: predicate).visit(array)
                let indexCount = ExpressionVisitor.counter(for: nodeType, matching: predicate).visit(index)
                return selfCount + arrayCount + indexCount
            },
            visitFieldAccess: { object, field in
                let expr = Expression.fieldAccess(object, field)
                let selfCount = predicate(expr) ? 1 : 0
                let objectCount = ExpressionVisitor.counter(for: nodeType, matching: predicate).visit(object)
                return selfCount + objectCount
            },
            visitFunctionCall: { name, args in
                let expr = Expression.functionCall(name, args)
                let selfCount = predicate(expr) ? 1 : 0
                let argsCount = args.reduce(0) { sum, arg in
                    sum + ExpressionVisitor.counter(for: nodeType, matching: predicate).visit(arg)
                }
                return selfCount + argsCount
            }
        )
    }
}