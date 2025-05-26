import Foundation

/// A closure-based visitor for Expression AST traversal with generic result type.
/// This visitor provides an efficient, type-safe way to traverse and transform Expression trees
/// without requiring modifications to the original Expression enum.
///
/// # Usage
/// ```swift
/// let stringifier = ExpressionVisitor<String>(
///     visitLiteral: { literal in "Literal(\(literal))" },
///     visitIdentifier: { name in "ID(\(name))" },
///     visitBinary: { op, left, right in "\(left) \(op.rawValue) \(right)" },
///     visitUnary: { op, expr in "\(op.rawValue)\(expr)" },
///     visitArrayAccess: { array, index in "\(array)[\(index)]" },
///     visitFieldAccess: { object, field in "\(object).\(field)" },
///     visitFunctionCall: { name, args in "\(name)(\(args.joined(separator: ", ")))" }
/// )
/// 
/// let result = stringifier.visit(expression)
/// ```
@Sendable
public struct ExpressionVisitor<Result: Sendable> {
    
    /// Visits a literal expression.
    /// - Parameter literal: The literal value to visit
    /// - Returns: The result of visiting the literal
    public let visitLiteral: @Sendable (Literal) -> Result
    
    /// Visits an identifier expression.
    /// - Parameter name: The identifier name to visit
    /// - Returns: The result of visiting the identifier
    public let visitIdentifier: @Sendable (String) -> Result
    
    /// Visits a binary expression.
    /// - Parameters:
    ///   - operator: The binary operator
    ///   - left: The left operand expression
    ///   - right: The right operand expression
    /// - Returns: The result of visiting the binary expression
    public let visitBinary: @Sendable (BinaryOperator, Expression, Expression) -> Result
    
    /// Visits a unary expression.
    /// - Parameters:
    ///   - operator: The unary operator
    ///   - operand: The operand expression
    /// - Returns: The result of visiting the unary expression
    public let visitUnary: @Sendable (UnaryOperator, Expression) -> Result
    
    /// Visits an array access expression.
    /// - Parameters:
    ///   - array: The array expression being accessed
    ///   - index: The index expression
    /// - Returns: The result of visiting the array access
    public let visitArrayAccess: @Sendable (Expression, Expression) -> Result
    
    /// Visits a field access expression.
    /// - Parameters:
    ///   - object: The object expression being accessed
    ///   - field: The field name being accessed
    /// - Returns: The result of visiting the field access
    public let visitFieldAccess: @Sendable (Expression, String) -> Result
    
    /// Visits a function call expression.
    /// - Parameters:
    ///   - name: The function name being called
    ///   - arguments: The array of argument expressions
    /// - Returns: The result of visiting the function call
    public let visitFunctionCall: @Sendable (String, [Expression]) -> Result
    
    /// Creates a new ExpressionVisitor with the provided closures.
    /// - Parameters:
    ///   - visitLiteral: Closure to handle literal expressions
    ///   - visitIdentifier: Closure to handle identifier expressions
    ///   - visitBinary: Closure to handle binary expressions
    ///   - visitUnary: Closure to handle unary expressions
    ///   - visitArrayAccess: Closure to handle array access expressions
    ///   - visitFieldAccess: Closure to handle field access expressions
    ///   - visitFunctionCall: Closure to handle function call expressions
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
    
    /// Visits an expression using pattern matching dispatch.
    /// This method efficiently routes the expression to the appropriate closure based on its type.
    /// - Parameter expression: The expression to visit
    /// - Returns: The result of visiting the expression
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

// MARK: - Convenience Methods

extension ExpressionVisitor {
    /// Creates a simple string representation visitor for debugging purposes.
    /// - Returns: An ExpressionVisitor that produces string descriptions of expressions
    public static func debugStringifier() -> ExpressionVisitor<String> {
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
            visitIdentifier: { name in name },
            visitBinary: { op, left, right in "(\(left) \(op.rawValue) \(right))" },
            visitUnary: { op, expr in "\(op.rawValue)(\(expr))" },
            visitArrayAccess: { array, index in "\(array)[\(index)]" },
            visitFieldAccess: { object, field in "\(object).\(field)" },
            visitFunctionCall: { name, args in "\(name)(\(args.map(\.description).joined(separator: ", ")))" }
        )
    }
}

// MARK: - Expression Debug Description Support

extension Expression: CustomStringConvertible {
    public var description: String {
        return ExpressionVisitor.debugStringifier().visit(self)
    }
}