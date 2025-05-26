import Foundation

/// A protocol that provides a unified interface for visitor acceptance.
/// Types conforming to this protocol can be visited by appropriate visitors,
/// enabling polymorphic traversal of AST nodes.
@Sendable
public protocol Visitable: Sendable {
    /// Accepts a visitor and returns the result of the visit.
    /// This method allows for polymorphic visitation where the specific visitor
    /// type is determined at runtime while maintaining type safety.
    /// - Parameter visitor: The visitor to accept
    /// - Returns: The result of visiting this instance
    func accept<V: Visitor>(_ visitor: V) -> V.Result where V.Node == Self
}

/// A protocol that defines the interface for visitors.
/// Visitors implementing this protocol can traverse and transform AST nodes
/// in a type-safe manner.
@Sendable
public protocol Visitor: Sendable {
    /// The type of node this visitor can visit.
    associatedtype Node: Visitable
    
    /// The type of result produced by this visitor.
    associatedtype Result: Sendable
    
    /// Visits a node and returns a result.
    /// - Parameter node: The node to visit
    /// - Returns: The result of visiting the node
    func visit(_ node: Node) -> Result
}

// MARK: - Expression Visitable Conformance

extension Expression: Visitable {
    /// Accepts an expression visitor and returns the result.
    /// - Parameter visitor: The expression visitor to accept
    /// - Returns: The result of visiting this expression
    public func accept<V: Visitor>(_ visitor: V) -> V.Result where V.Node == Expression {
        return visitor.visit(self)
    }
}

// MARK: - Statement Visitable Conformance

extension Statement: Visitable {
    /// Accepts a statement visitor and returns the result.
    /// - Parameter visitor: The statement visitor to accept
    /// - Returns: The result of visiting this statement
    public func accept<V: Visitor>(_ visitor: V) -> V.Result where V.Node == Statement {
        return visitor.visit(self)
    }
}

// MARK: - Visitor Protocol Conformance

extension ExpressionVisitor: Visitor {
    public typealias Node = Expression
}

extension StatementVisitor: Visitor {
    public typealias Node = Statement
}

// MARK: - Convenience Extensions

extension Visitable {
    /// Convenience method to visit this instance with an ExpressionVisitor.
    /// This method is only available for Expression instances.
    /// - Parameter visitor: The expression visitor to use
    /// - Returns: The result of the visit
    public func accept<Result: Sendable>(_ visitor: ExpressionVisitor<Result>) -> Result where Self == Expression {
        return visitor.visit(self)
    }
    
    /// Convenience method to visit this instance with a StatementVisitor.
    /// This method is only available for Statement instances.
    /// - Parameter visitor: The statement visitor to use
    /// - Returns: The result of the visit
    public func accept<Result: Sendable>(_ visitor: StatementVisitor<Result>) -> Result where Self == Statement {
        return visitor.visit(self)
    }
}

// MARK: - Collection Extensions

extension Collection where Element: Visitable {
    /// Visits all elements in the collection using the provided visitor.
    /// - Parameter visitor: The visitor to use for each element
    /// - Returns: An array of results from visiting each element
    public func accept<V: Visitor>(_ visitor: V) -> [V.Result] where V.Node == Element {
        return self.map { $0.accept(visitor) }
    }
}

extension Array where Element == Expression {
    /// Convenience method to visit all expressions with an ExpressionVisitor.
    /// - Parameter visitor: The expression visitor to use
    /// - Returns: An array of results from visiting each expression
    public func accept<Result: Sendable>(_ visitor: ExpressionVisitor<Result>) -> [Result] {
        return self.map { visitor.visit($0) }
    }
}

extension Array where Element == Statement {
    /// Convenience method to visit all statements with a StatementVisitor.
    /// - Parameter visitor: The statement visitor to use
    /// - Returns: An array of results from visiting each statement
    public func accept<Result: Sendable>(_ visitor: StatementVisitor<Result>) -> [Result] {
        return self.map { visitor.visit($0) }
    }
}