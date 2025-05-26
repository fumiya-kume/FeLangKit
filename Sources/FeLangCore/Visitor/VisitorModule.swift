import Foundation

/// The Visitor module provides a comprehensive visitor pattern infrastructure
/// for traversing and processing FeLangKit AST nodes.
///
/// This module implements the function-based visitor pattern as outlined in the design document,
/// providing maximum flexibility and Swift idiomatic code while maintaining thread safety
/// through Sendable compliance.
///
/// ## Core Components
///
/// - `ExpressionVisitor<Result>`: Function-based visitor for Expression AST nodes
/// - `StatementVisitor<Result>`: Function-based visitor for Statement AST nodes
/// - `Visitable`: Protocol for unified traversal interface
/// - `ASTWalker`: Utilities for automatic recursive traversal
///
/// ## Usage Examples
///
/// ### Basic Expression Visitor
/// ```swift
/// let debugVisitor = ExpressionVisitor<String>.makeDebugVisitor()
/// let expr = Expression.binary(.add, .literal(.integer(1)), .literal(.integer(2)))
/// let result = debugVisitor.visit(expr) // "(1 + 2)"
/// ```
///
/// ### Custom Statement Visitor
/// ```swift
/// let countingVisitor = StatementVisitor<Int>(
///     visitIfStatement: { _ in 1 },
///     visitWhileStatement: { _ in 1 },
///     // ... other visitor methods
/// )
/// let count = countingVisitor.visit(someStatement)
/// ```
///
/// ### Recursive AST Walking
/// ```swift
/// let nodeCount = ASTWalker.walkExpression(
///     expr,
///     visitor: countingVisitor,
///     accumulator: +,
///     identity: 0
/// )
/// ```
///
/// ### AST Transformation
/// ```swift
/// let transformed = ASTWalker.transformExpression(expr) { node in
///     // Apply transformation logic here
///     return transformedNode
/// }
/// ```
///
/// ## Thread Safety
///
/// All visitor types are designed to be `Sendable` and can be safely used
/// in concurrent contexts. The visitor closures are marked with `@Sendable`
/// to ensure thread safety.
///
/// ## Performance Considerations
///
/// The function-based visitor pattern provides excellent performance through
/// Swift's optimization of closure dispatch. For maximum performance in
/// critical code paths, consider using the specialized visitor methods
/// directly rather than the generic `Visitable` protocol.
public enum VisitorModule {
    /// Version of the visitor pattern implementation
    public static let version = "1.0.0"
    
    /// Indicates whether the visitor pattern is available and properly initialized
    public static let isAvailable = true
}

// MARK: - Convenience Type Aliases

/// Type alias for expression visitors that return strings (useful for debugging)
public typealias StringExpressionVisitor = ExpressionVisitor<String>

/// Type alias for statement visitors that return strings (useful for debugging)
public typealias StringStatementVisitor = StatementVisitor<String>

/// Type alias for expression visitors that count nodes
public typealias CountingExpressionVisitor = ExpressionVisitor<Int>

/// Type alias for statement visitors that count nodes
public typealias CountingStatementVisitor = StatementVisitor<Int>

// MARK: - Common Visitor Factory Methods

extension ExpressionVisitor {
    /// Creates a visitor that always returns a constant value for any expression
    public static func makeConstantVisitor(_ constant: Result) -> ExpressionVisitor<Result> {
        return ExpressionVisitor<Result>(
            visitLiteral: { _ in constant },
            visitIdentifier: { _ in constant },
            visitBinary: { _, _, _ in constant },
            visitUnary: { _, _ in constant },
            visitArrayAccess: { _, _ in constant },
            visitFieldAccess: { _, _ in constant },
            visitFunctionCall: { _, _ in constant }
        )
    }
}

extension StatementVisitor {
    /// Creates a visitor that always returns a constant value for any statement
    public static func makeConstantVisitor(_ constant: Result) -> StatementVisitor<Result> {
        return StatementVisitor<Result>(
            visitIfStatement: { _ in constant },
            visitWhileStatement: { _ in constant },
            visitForStatement: { _ in constant },
            visitAssignment: { _ in constant },
            visitVariableDeclaration: { _ in constant },
            visitConstantDeclaration: { _ in constant },
            visitFunctionDeclaration: { _ in constant },
            visitProcedureDeclaration: { _ in constant },
            visitReturnStatement: { _ in constant },
            visitExpressionStatement: { _ in constant },
            visitBreakStatement: { constant },
            visitBlock: { _ in constant }
        )
    }
}

// MARK: - Common Collection Operations

extension ASTWalker {
    /// Counts the total number of nodes in an expression tree
    public static func countExpressionNodes(_ expression: Expression) -> Int {
        let countingVisitor = ExpressionVisitor<Int>.makeConstantVisitor(1)
        return walkExpression(expression, visitor: countingVisitor, accumulator: +, identity: 0)
    }
    
    /// Counts the total number of nodes in a statement tree
    public static func countStatementNodes(_ statement: Statement) -> Int {
        let statementVisitor = StatementVisitor<Int>.makeConstantVisitor(1)
        let expressionVisitor = ExpressionVisitor<Int>.makeConstantVisitor(1)
        return walkStatement(statement, statementVisitor: statementVisitor, expressionVisitor: expressionVisitor, accumulator: +, identity: 0)
    }
    
    /// Finds all identifiers used in an expression
    public static func findIdentifiers(_ expression: Expression) -> [String] {
        return collectExpressions(expression) { expr in
            if case .identifier(let name) = expr {
                return [name]
            }
            return []
        }
    }
    
    /// Finds all function calls in an expression
    public static func findFunctionCalls(_ expression: Expression) -> [String] {
        return collectExpressions(expression) { expr in
            if case .functionCall(let name, _) = expr {
                return [name]
            }
            return []
        }
    }
}

// MARK: - Validation Utilities

extension VisitorModule {
    /// Validates that an expression tree doesn't exceed maximum depth
    public static func validateExpressionDepth(_ expression: Expression, maxDepth: Int = 100) -> Bool {
        func getDepth(_ expr: Expression) -> Int {
            let childDepths: [Int]
            switch expr {
            case .literal, .identifier:
                return 1
            case .binary(_, let left, let right):
                childDepths = [getDepth(left), getDepth(right)]
            case .unary(_, let inner):
                childDepths = [getDepth(inner)]
            case .arrayAccess(let array, let index):
                childDepths = [getDepth(array), getDepth(index)]
            case .fieldAccess(let inner, _):
                childDepths = [getDepth(inner)]
            case .functionCall(_, let args):
                childDepths = args.map(getDepth)
            }
            
            return 1 + (childDepths.max() ?? 0)
        }
        
        return getDepth(expression) <= maxDepth
    }
    
    /// Validates that a statement tree doesn't exceed maximum depth
    public static func validateStatementDepth(_ statement: Statement, maxDepth: Int = 100) -> Bool {
        func getDepth(_ stmt: Statement) -> Int {
            let childDepths: [Int]
            switch stmt {
            case .ifStatement(let ifStmt):
                var depths = ifStmt.thenBody.map(getDepth)
                depths.append(contentsOf: ifStmt.elseIfs.flatMap { $0.body.map(getDepth) })
                if let elseBody = ifStmt.elseBody {
                    depths.append(contentsOf: elseBody.map(getDepth))
                }
                childDepths = depths
            case .whileStatement(let whileStmt):
                childDepths = whileStmt.body.map(getDepth)
            case .forStatement(let forStmt):
                switch forStmt {
                case .range(let rangeFor):
                    childDepths = rangeFor.body.map(getDepth)
                case .forEach(let forEachLoop):
                    childDepths = forEachLoop.body.map(getDepth)
                }
            case .functionDeclaration(let funcDecl):
                childDepths = funcDecl.body.map(getDepth)
            case .procedureDeclaration(let procDecl):
                childDepths = procDecl.body.map(getDepth)
            case .block(let statements):
                childDepths = statements.map(getDepth)
            default:
                return 1
            }
            
            return 1 + (childDepths.max() ?? 0)
        }
        
        return getDepth(statement) <= maxDepth
    }
}