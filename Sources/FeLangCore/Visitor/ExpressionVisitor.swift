import Foundation

/// A function-based visitor for traversing Expression AST nodes.
/// This implementation uses closures for maximum flexibility and Swift idiomaticity.
public struct ExpressionVisitor<Result>: Sendable {
    /// Closure for visiting literal expressions
    public let visitLiteral: @Sendable (Literal) -> Result
    
    /// Closure for visiting identifier expressions
    public let visitIdentifier: @Sendable (String) -> Result
    
    /// Closure for visiting binary expressions
    public let visitBinary: @Sendable (BinaryOperator, Expression, Expression) -> Result
    
    /// Closure for visiting unary expressions
    public let visitUnary: @Sendable (UnaryOperator, Expression) -> Result
    
    /// Closure for visiting array access expressions
    public let visitArrayAccess: @Sendable (Expression, Expression) -> Result
    
    /// Closure for visiting field access expressions
    public let visitFieldAccess: @Sendable (Expression, String) -> Result
    
    /// Closure for visiting function call expressions
    public let visitFunctionCall: @Sendable (String, [Expression]) -> Result
    
    /// Initializes a new ExpressionVisitor with the provided closures
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
    
    /// Visits an expression and returns the result using the appropriate closure
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
        case .fieldAccess(let expr, let field):
            return visitFieldAccess(expr, field)
        case .functionCall(let name, let args):
            return visitFunctionCall(name, args)
        }
    }
}

/// Convenience extension for creating common visitor patterns
extension ExpressionVisitor {
    /// Creates a visitor that converts expressions to strings for debugging
    public static func makeDebugVisitor() -> ExpressionVisitor<String> {
        return ExpressionVisitor<String>(
            visitLiteral: { literal in
                switch literal {
                case .integer(let value):
                    return "\(value)"
                case .real(let value):
                    return "\(value)"
                case .string(let value):
                    return "\"\(value)\""
                case .character(let value):
                    return "'\(value)'"
                case .boolean(let value):
                    return "\(value)"
                }
            },
            visitIdentifier: { name in
                return name
            },
            visitBinary: { op, left, right in
                let leftStr = ExpressionVisitor.makeDebugVisitor().visit(left)
                let rightStr = ExpressionVisitor.makeDebugVisitor().visit(right)
                return "(\(leftStr) \(op.rawValue) \(rightStr))"
            },
            visitUnary: { op, expr in
                let exprStr = ExpressionVisitor.makeDebugVisitor().visit(expr)
                return "\(op.rawValue)\(exprStr)"
            },
            visitArrayAccess: { array, index in
                let arrayStr = ExpressionVisitor.makeDebugVisitor().visit(array)
                let indexStr = ExpressionVisitor.makeDebugVisitor().visit(index)
                return "\(arrayStr)[\(indexStr)]"
            },
            visitFieldAccess: { expr, field in
                let exprStr = ExpressionVisitor.makeDebugVisitor().visit(expr)
                return "\(exprStr).\(field)"
            },
            visitFunctionCall: { name, args in
                let argsStr = args.map { ExpressionVisitor.makeDebugVisitor().visit($0) }.joined(separator: ", ")
                return "\(name)(\(argsStr))"
            }
        )
    }
}