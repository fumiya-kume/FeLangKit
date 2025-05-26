import Foundation

/// A protocol that provides a unified interface for AST traversal.
/// Allows both Expression and Statement types to be visited uniformly.
public protocol Visitable: Sendable {
    /// Accepts a visitor that processes this node and returns a result.
    func accept<V: ASTVisitor>(_ visitor: V) -> V.Result
}

/// A unified visitor protocol that can handle both Expression and Statement nodes.
public protocol ASTVisitor: Sendable {
    associatedtype Result
    
    /// Visits an Expression node.
    func visitExpression(_ expression: Expression) -> Result
    
    /// Visits a Statement node.
    func visitStatement(_ statement: Statement) -> Result
}

// MARK: - Visitable Conformance

extension Expression: Visitable {
    /// Accepts a visitor and dispatches to the visitExpression method.
    public func accept<V: ASTVisitor>(_ visitor: V) -> V.Result {
        return visitor.visitExpression(self)
    }
}

extension Statement: Visitable {
    /// Accepts a visitor and dispatches to the visitStatement method.
    public func accept<V: ASTVisitor>(_ visitor: V) -> V.Result {
        return visitor.visitStatement(self)
    }
}

// MARK: - Default ASTVisitor Implementation

/// A concrete implementation of ASTVisitor that delegates to ExpressionVisitor and StatementVisitor.
public struct UnifiedVisitor<Result>: ASTVisitor {
    
    private let expressionVisitor: ExpressionVisitor<Result>
    private let statementVisitor: StatementVisitor<Result>
    
    /// Creates a UnifiedVisitor that combines Expression and Statement visitors.
    public init(
        expressionVisitor: ExpressionVisitor<Result>,
        statementVisitor: StatementVisitor<Result>
    ) {
        self.expressionVisitor = expressionVisitor
        self.statementVisitor = statementVisitor
    }
    
    public func visitExpression(_ expression: Expression) -> Result {
        return expressionVisitor.visit(expression)
    }
    
    public func visitStatement(_ statement: Statement) -> Result {
        return statementVisitor.visit(statement)
    }
}

// MARK: - Convenience Extensions

extension Array where Element: Visitable {
    /// Visits all elements in the array using the provided visitor.
    public func accept<V: ASTVisitor>(_ visitor: V) -> [V.Result] {
        return self.map { $0.accept(visitor) }
    }
}

extension Optional where Wrapped: Visitable {
    /// Visits the wrapped element if it exists, otherwise returns nil.
    public func accept<V: ASTVisitor>(_ visitor: V) -> V.Result? {
        return self?.accept(visitor)
    }
}