import Foundation

/// Protocol for AST nodes that can be visited by visitors.
/// This provides a unified interface for traversing different AST node types.
public protocol Visitable: Sendable {
    /// Accepts a visitor and returns a result.
    /// This method should dispatch to the appropriate visitor method based on the node type.
    func accept<V: ASTVisitor>(_ visitor: V) -> V.Result
}

/// Base protocol for all AST visitors.
/// This allows for generic visitor handling and composition.
public protocol ASTVisitor: Sendable {
    /// The result type produced by this visitor
    associatedtype Result
}

/// A visitor that can handle both expressions and statements
public protocol UnifiedVisitor: ASTVisitor {
    /// Visit an expression node
    func visitExpression(_ expression: Expression) -> Result
    
    /// Visit a statement node
    func visitStatement(_ statement: Statement) -> Result
}

/// Extension to make Expression conform to Visitable
extension Expression: Visitable {
    public func accept<V: ASTVisitor>(_ visitor: V) -> V.Result {
        if let expressionVisitor = visitor as? any ExpressionVisitorProtocol {
            return expressionVisitor.visitExpressionNode(self) as! V.Result
        } else if let unifiedVisitor = visitor as? any UnifiedVisitor {
            return unifiedVisitor.visitExpression(self)
        } else {
            fatalError("Visitor does not support Expression nodes")
        }
    }
}

/// Extension to make Statement conform to Visitable
extension Statement: Visitable {
    public func accept<V: ASTVisitor>(_ visitor: V) -> V.Result {
        if let statementVisitor = visitor as? any StatementVisitorProtocol {
            return statementVisitor.visitStatementNode(self) as! V.Result
        } else if let unifiedVisitor = visitor as? any UnifiedVisitor {
            return unifiedVisitor.visitStatement(self)
        } else {
            fatalError("Visitor does not support Statement nodes")
        }
    }
}

/// Protocol for visitors that can handle expressions
public protocol ExpressionVisitorProtocol: ASTVisitor {
    func visitExpressionNode(_ expression: Expression) -> Result
}

/// Protocol for visitors that can handle statements
public protocol StatementVisitorProtocol: ASTVisitor {
    func visitStatementNode(_ statement: Statement) -> Result
}

/// Wrapper to make ExpressionVisitor conform to ExpressionVisitorProtocol
public struct ExpressionVisitorWrapper<Result>: ExpressionVisitorProtocol {
    private let visitor: ExpressionVisitor<Result>
    
    public init(_ visitor: ExpressionVisitor<Result>) {
        self.visitor = visitor
    }
    
    public func visitExpressionNode(_ expression: Expression) -> Result {
        return visitor.visit(expression)
    }
}

/// Wrapper to make StatementVisitor conform to StatementVisitorProtocol
public struct StatementVisitorWrapper<Result>: StatementVisitorProtocol {
    private let visitor: StatementVisitor<Result>
    
    public init(_ visitor: StatementVisitor<Result>) {
        self.visitor = visitor
    }
    
    public func visitStatementNode(_ statement: Statement) -> Result {
        return visitor.visit(statement)
    }
}

/// Convenience functions for using the visitor pattern with Visitable protocol
extension Visitable {
    /// Visits this node with an ExpressionVisitor
    public func accept<Result>(_ visitor: ExpressionVisitor<Result>) -> Result {
        let wrapper = ExpressionVisitorWrapper(visitor)
        return accept(wrapper)
    }
    
    /// Visits this node with a StatementVisitor
    public func accept<Result>(_ visitor: StatementVisitor<Result>) -> Result {
        let wrapper = StatementVisitorWrapper(visitor)
        return accept(wrapper)
    }
}