import Foundation

/// A function-based visitor for traversing `Expression` AST nodes.
/// 
/// This visitor provides a flexible, closure-based approach to AST traversal that
/// allows for clean separation of concerns between AST structure and processing logic.
/// Each visit method is implemented as a closure, enabling maximum flexibility and
/// easy composition of visitor behaviors.
///
/// Example usage:
/// ```swift
/// let stringifier = ExpressionVisitor<String>(
///     visitLiteral: { literal in
///         switch literal {
///         case .integer(let value): return "\(value)"
///         case .string(let value): return "\"\(value)\""
///         // ... other cases
///         }
///     },
///     visitIdentifier: { identifier in
///         return identifier
///     },
///     visitBinary: { op, left, right in
///         return "(\(left) \(op.rawValue) \(right))"
///     }
///     // ... other visit methods
/// )
/// 
/// let result = stringifier.visit(expression)
/// ```
public struct ExpressionVisitor<Result>: Sendable where Result: Sendable {

    // MARK: - Visit Closures

    /// Visits literal expressions.
    public let visitLiteral: @Sendable (Literal) -> Result

    /// Visits identifier expressions.
    public let visitIdentifier: @Sendable (String) -> Result

    /// Visits binary expressions.
    /// - Parameters:
    ///   - operator: The binary operator
    ///   - left: The left operand expression
    ///   - right: The right operand expression
    public let visitBinary: @Sendable (BinaryOperator, Expression, Expression) -> Result

    /// Visits unary expressions.
    /// - Parameters:
    ///   - operator: The unary operator
    ///   - operand: The operand expression
    public let visitUnary: @Sendable (UnaryOperator, Expression) -> Result

    /// Visits array access expressions.
    /// - Parameters:
    ///   - array: The array expression being accessed
    ///   - index: The index expression
    public let visitArrayAccess: @Sendable (Expression, Expression) -> Result

    /// Visits field access expressions.
    /// - Parameters:
    ///   - object: The object expression being accessed
    ///   - field: The field name being accessed
    public let visitFieldAccess: @Sendable (Expression, String) -> Result

    /// Visits function call expressions.
    /// - Parameters:
    ///   - function: The function name being called
    ///   - arguments: The argument expressions
    public let visitFunctionCall: @Sendable (String, [Expression]) -> Result

    /// Visits method call expressions.
    /// - Parameters:
    ///   - receiver: The receiver expression (object on which method is called)
    ///   - method: The method name being called
    ///   - arguments: The argument expressions
    public let visitMethodCall: @Sendable (Expression, String, [Expression]) -> Result

    /// Visits array literal expressions.
    /// - Parameter elements: The array elements
    public let visitArrayLiteral: @Sendable ([Expression]) -> Result

    // MARK: - Initialization

    /// Creates a new expression visitor with the specified visit closures.
    public init(
        visitLiteral: @escaping @Sendable (Literal) -> Result,
        visitIdentifier: @escaping @Sendable (String) -> Result,
        visitBinary: @escaping @Sendable (BinaryOperator, Expression, Expression) -> Result,
        visitUnary: @escaping @Sendable (UnaryOperator, Expression) -> Result,
        visitArrayAccess: @escaping @Sendable (Expression, Expression) -> Result,
        visitFieldAccess: @escaping @Sendable (Expression, String) -> Result,
        visitFunctionCall: @escaping @Sendable (String, [Expression]) -> Result,
        visitMethodCall: @escaping @Sendable (Expression, String, [Expression]) -> Result,
        visitArrayLiteral: @escaping @Sendable ([Expression]) -> Result
    ) {
        self.visitLiteral = visitLiteral
        self.visitIdentifier = visitIdentifier
        self.visitBinary = visitBinary
        self.visitUnary = visitUnary
        self.visitArrayAccess = visitArrayAccess
        self.visitFieldAccess = visitFieldAccess
        self.visitFunctionCall = visitFunctionCall
        self.visitMethodCall = visitMethodCall
        self.visitArrayLiteral = visitArrayLiteral
    }

    // MARK: - Visit Method

    /// Visits an expression, dispatching to the appropriate visit closure based on the expression type.
    /// - Parameter expression: The expression to visit
    /// - Returns: The result of visiting the expression
    public func visit(_ expression: Expression) -> Result {
        switch expression {
        case .literal(let literal):
            return visitLiteral(literal)
        case .identifier(let identifier):
            return visitIdentifier(identifier)
        case .binary(let binaryOperator, let left, let right):
            return visitBinary(binaryOperator, left, right)
        case .unary(let unaryOperator, let operand):
            return visitUnary(unaryOperator, operand)
        case .arrayAccess(let array, let index):
            return visitArrayAccess(array, index)
        case .fieldAccess(let object, let field):
            return visitFieldAccess(object, field)
        case .functionCall(let function, let arguments):
            return visitFunctionCall(function, arguments)
        case .methodCall(let receiver, let method, let arguments):
            return visitMethodCall(receiver, method, arguments)
        case .arrayLiteral(let elements):
            return visitArrayLiteral(elements)
        }
    }
}
