import Foundation

/// Protocol that defines a unified interface for visitor acceptance.
/// Types conforming to this protocol can accept visitors and return the visitor's result.
public protocol Visitable: Sendable {
    /// Accepts a visitor and returns the visitor's result.
    /// - Parameter visitor: The visitor to accept
    /// - Returns: The result from the visitor
    func accept<V: Visitor>(_ visitor: V) -> V.Result
}

/// Base protocol for all visitors.
/// Defines the associated Result type that visitors must produce.
public protocol Visitor: Sendable {
    /// The type of result this visitor produces.
    associatedtype Result
}

// MARK: - Visitor Protocol Conformance

extension ExpressionVisitor: Visitor {}
extension StatementVisitor: Visitor {}

// MARK: - Visitable Protocol Extensions

extension Expression: Visitable {
    /// Accepts an ExpressionVisitor and returns its result.
    /// - Parameter visitor: The ExpressionVisitor to accept
    /// - Returns: The result from the visitor
    public func accept<V: Visitor>(_ visitor: V) -> V.Result {
        guard let expressionVisitor = visitor as? ExpressionVisitor<V.Result> else {
            fatalError("Expression can only accept ExpressionVisitor")
        }
        return expressionVisitor.visit(self)
    }
}

extension Statement: Visitable {
    /// Accepts a StatementVisitor and returns its result.
    /// - Parameter visitor: The StatementVisitor to accept
    /// - Returns: The result from the visitor
    public func accept<V: Visitor>(_ visitor: V) -> V.Result {
        guard let statementVisitor = visitor as? StatementVisitor<V.Result> else {
            fatalError("Statement can only accept StatementVisitor")
        }
        return statementVisitor.visit(self)
    }
}

// MARK: - Convenience Type-Safe Accept Methods

extension Expression {
    /// Type-safe convenience method for accepting ExpressionVisitor.
    /// - Parameter visitor: The ExpressionVisitor to accept
    /// - Returns: The result from the visitor
    public func accept<Result>(_ visitor: ExpressionVisitor<Result>) -> Result {
        return visitor.visit(self)
    }
}

extension Statement {
    /// Type-safe convenience method for accepting StatementVisitor.
    /// - Parameter visitor: The StatementVisitor to accept
    /// - Returns: The result from the visitor
    public func accept<Result>(_ visitor: StatementVisitor<Result>) -> Result {
        return visitor.visit(self)
    }
}