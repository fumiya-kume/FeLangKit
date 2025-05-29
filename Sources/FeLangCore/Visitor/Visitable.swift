import Foundation

/// A protocol that defines types that can be visited by visitor pattern implementations.
/// 
/// This protocol provides a unified interface for AST traversal, allowing different
/// AST node types (`Expression` and `Statement`) to be visited in a consistent manner.
/// 
/// Types conforming to `Visitable` can be processed by appropriate visitor implementations,
/// enabling clean separation between AST structure and processing logic.
public protocol Visitable: Sendable {
    /// Accepts a visitor and returns the result of the visit operation.
    /// 
    /// This method should dispatch to the appropriate visitor method based on
    /// the concrete type of the visitable node.
    ///
    /// - Parameter visitor: The visitor that will process this node
    /// - Returns: The result of the visitor operation
    func accept<V: Visitor>(_ visitor: V) -> V.Result where V.NodeType == Self
}

/// A protocol that defines visitor types that can process specific AST node types.
/// 
/// Visitors implementing this protocol provide a `visit` method that processes
/// nodes of a specific type and returns a result. This allows for type-safe
/// visitor implementations that work with the `Visitable` protocol.
public protocol Visitor: Sendable {
    /// The type of AST node this visitor can process.
    associatedtype NodeType: Visitable

    /// The type of result returned by visitor operations.
    associatedtype Result: Sendable

    /// Visits a node and returns the result of the visit operation.
    /// 
    /// - Parameter node: The node to visit
    /// - Returns: The result of visiting the node
    func visit(_ node: NodeType) -> Result
}

// MARK: - Expression Visitable Conformance

extension Expression: Visitable {
    /// Accepts a visitor that can process expressions.
    /// 
    /// - Parameter visitor: An expression visitor
    /// - Returns: The result of visiting this expression
    public func accept<V: Visitor>(_ visitor: V) -> V.Result where V.NodeType == Expression {
        return visitor.visit(self)
    }
}

// MARK: - Statement Visitable Conformance

extension Statement: Visitable {
    /// Accepts a visitor that can process statements.
    /// 
    /// - Parameter visitor: A statement visitor
    /// - Returns: The result of visiting this statement
    public func accept<V: Visitor>(_ visitor: V) -> V.Result where V.NodeType == Statement {
        return visitor.visit(self)
    }
}

// MARK: - Visitor Protocol Conformance

extension ExpressionVisitor: Visitor {
    public typealias NodeType = Expression
    // Result is already defined as an associated type in the struct
}

extension StatementVisitor: Visitor {
    public typealias NodeType = Statement
    // Result is already defined as an associated type in the struct
}

// MARK: - Convenience Extensions

extension Visitable {
    /// Convenience method to visit this node with an expression visitor.
    /// 
    /// This method provides a more ergonomic API when working with expression visitors,
    /// avoiding the need to explicitly call `accept(_:)`.
    ///
    /// - Parameter visitor: The expression visitor to use
    /// - Returns: The result of the visit operation
    public func visit<Result: Sendable>(with visitor: ExpressionVisitor<Result>) -> Result where Self == Expression {
        return accept(visitor)
    }

    /// Convenience method to visit this node with a statement visitor.
    /// 
    /// This method provides a more ergonomic API when working with statement visitors,
    /// avoiding the need to explicitly call `accept(_:)`.
    ///
    /// - Parameter visitor: The statement visitor to use
    /// - Returns: The result of the visit operation
    public func visit<Result: Sendable>(with visitor: StatementVisitor<Result>) -> Result where Self == Statement {
        return accept(visitor)
    }
}
