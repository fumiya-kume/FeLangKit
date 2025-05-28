import Foundation

/// A closure-based visitor for Expression AST traversal.
/// Provides type-safe visitor pattern implementation with generic Result type.
public struct ExpressionVisitor<Result>: Sendable {
    // MARK: - Visitor Closures
    
    /// Visits a literal expression
    public let visitLiteral: @Sendable (Literal) -> Result
    
    /// Visits an identifier expression
    public let visitIdentifier: @Sendable (String) -> Result
    
    /// Visits a binary expression
    public let visitBinary: @Sendable (BinaryOperator, Expression, Expression) -> Result
    
    /// Visits a unary expression
    public let visitUnary: @Sendable (UnaryOperator, Expression) -> Result
    
    /// Visits an array access expression
    public let visitArrayAccess: @Sendable (Expression, Expression) -> Result
    
    /// Visits a field access expression
    public let visitFieldAccess: @Sendable (Expression, String) -> Result
    
    /// Visits a function call expression
    public let visitFunctionCall: @Sendable (String, [Expression]) -> Result
    
    // MARK: - Initialization
    
    /// Creates a new ExpressionVisitor with the specified closure handlers.
    /// - Parameters:
    ///   - visitLiteral: Handler for literal expressions
    ///   - visitIdentifier: Handler for identifier expressions
    ///   - visitBinary: Handler for binary expressions
    ///   - visitUnary: Handler for unary expressions
    ///   - visitArrayAccess: Handler for array access expressions
    ///   - visitFieldAccess: Handler for field access expressions
    ///   - visitFunctionCall: Handler for function call expressions
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
    
    // MARK: - Visit Method
    
    /// Visits an expression and dispatches to the appropriate handler.
    /// - Parameter expression: The expression to visit
    /// - Returns: The result from the appropriate handler
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