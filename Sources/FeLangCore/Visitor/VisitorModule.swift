import Foundation

/// Main module for the Visitor pattern infrastructure.
/// Provides convenient access to all visitor-related functionality.
public struct VisitorModule {
    
    // MARK: - Factory Methods
    
    /// Creates a debug visitor for Expressions that produces string representations.
    public static func debugExpressionVisitor() -> ExpressionVisitor<String> {
        return ExpressionVisitor.debug
    }
    
    /// Creates a debug visitor for Statements that produces string representations.
    public static func debugStatementVisitor() -> StatementVisitor<String> {
        return StatementVisitor.debug
    }
    
    /// Creates a unified visitor that can handle both Expression and Statement nodes.
    public static func unifiedDebugVisitor() -> UnifiedVisitor<String> {
        return UnifiedVisitor(
            expressionVisitor: ExpressionVisitor.debug,
            statementVisitor: StatementVisitor.debug
        )
    }
    
    // MARK: - Counting Visitors
    
    /// Creates a visitor that counts specific Expression node types.
    public static func expressionCounter(
        matching predicate: @escaping @Sendable (Expression) -> Bool
    ) -> ExpressionVisitor<Int> {
        return ExpressionVisitor.counter(for: Expression.self, matching: predicate)
    }
    
    /// Creates a visitor that counts specific Statement node types.
    public static func statementCounter(
        matching predicate: @escaping @Sendable (Statement) -> Bool
    ) -> StatementVisitor<Int> {
        return StatementVisitor.counter(for: Statement.self, matching: predicate)
    }
    
    /// Creates a visitor that counts literal expressions.
    public static func literalCounter() -> ExpressionVisitor<Int> {
        return expressionCounter { expression in
            if case .literal = expression {
                return true
            }
            return false
        }
    }
    
    /// Creates a visitor that counts function calls.
    public static func functionCallCounter() -> ExpressionVisitor<Int> {
        return expressionCounter { expression in
            if case .functionCall = expression {
                return true
            }
            return false
        }
    }
    
    /// Creates a visitor that counts variable declarations.
    public static func variableDeclarationCounter() -> StatementVisitor<Int> {
        return statementCounter { statement in
            if case .variableDeclaration = statement {
                return true
            }
            return false
        }
    }
    
    // MARK: - Collection Visitors
    
    /// Creates a visitor that collects all identifiers from an expression tree.
    public static func identifierCollector() -> ExpressionVisitor<[String]> {
        return ExpressionVisitor<[String]>(
            visitLiteral: { _ in [] },
            visitIdentifier: { name in [name] },
            visitBinary: { _, left, right in
                let leftIds = VisitorModule.identifierCollector().visit(left)
                let rightIds = VisitorModule.identifierCollector().visit(right)
                return leftIds + rightIds
            },
            visitUnary: { _, expr in
                return VisitorModule.identifierCollector().visit(expr)
            },
            visitArrayAccess: { array, index in
                let arrayIds = VisitorModule.identifierCollector().visit(array)
                let indexIds = VisitorModule.identifierCollector().visit(index)
                return arrayIds + indexIds
            },
            visitFieldAccess: { object, _ in
                return VisitorModule.identifierCollector().visit(object)
            },
            visitFunctionCall: { _, args in
                return args.flatMap { VisitorModule.identifierCollector().visit($0) }
            }
        )
    }
    
    /// Creates a visitor that collects all function names from an expression tree.
    public static func functionNameCollector() -> ExpressionVisitor<[String]> {
        return ExpressionVisitor<[String]>(
            visitLiteral: { _ in [] },
            visitIdentifier: { _ in [] },
            visitBinary: { _, left, right in
                let leftFuncs = VisitorModule.functionNameCollector().visit(left)
                let rightFuncs = VisitorModule.functionNameCollector().visit(right)
                return leftFuncs + rightFuncs
            },
            visitUnary: { _, expr in
                return VisitorModule.functionNameCollector().visit(expr)
            },
            visitArrayAccess: { array, index in
                let arrayFuncs = VisitorModule.functionNameCollector().visit(array)
                let indexFuncs = VisitorModule.functionNameCollector().visit(index)
                return arrayFuncs + indexFuncs
            },
            visitFieldAccess: { object, _ in
                return VisitorModule.functionNameCollector().visit(object)
            },
            visitFunctionCall: { name, args in
                let funcNames = [name]
                let argFuncs = args.flatMap { VisitorModule.functionNameCollector().visit($0) }
                return funcNames + argFuncs
            }
        )
    }
    
    // MARK: - Validation Visitors
    
    /// Creates a visitor that validates Expression trees for common issues.
    public static func expressionValidator() -> ExpressionVisitor<[String]> {
        return ExpressionVisitor<[String]>(
            visitLiteral: { _ in [] },
            visitIdentifier: { name in
                // Check for empty identifier names
                return name.isEmpty ? ["Empty identifier name"] : []
            },
            visitBinary: { op, left, right in
                var issues: [String] = []
                
                // Recursively validate children
                issues += VisitorModule.expressionValidator().visit(left)
                issues += VisitorModule.expressionValidator().visit(right)
                
                // Check for division by zero literal
                if op == .divide, case .literal(.integer(0)) = right {
                    issues.append("Division by zero literal")
                }
                if op == .divide, case .literal(.real(let value)) = right, value == 0.0 {
                    issues.append("Division by zero literal")
                }
                
                return issues
            },
            visitUnary: { _, expr in
                return VisitorModule.expressionValidator().visit(expr)
            },
            visitArrayAccess: { array, index in
                var issues: [String] = []
                issues += VisitorModule.expressionValidator().visit(array)
                issues += VisitorModule.expressionValidator().visit(index)
                return issues
            },
            visitFieldAccess: { object, field in
                var issues: [String] = []
                issues += VisitorModule.expressionValidator().visit(object)
                
                // Check for empty field names
                if field.isEmpty {
                    issues.append("Empty field name")
                }
                
                return issues
            },
            visitFunctionCall: { name, args in
                var issues: [String] = []
                
                // Check for empty function names
                if name.isEmpty {
                    issues.append("Empty function name")
                }
                
                // Recursively validate arguments
                for arg in args {
                    issues += VisitorModule.expressionValidator().visit(arg)
                }
                
                return issues
            }
        )
    }
    
    // MARK: - Transformation Utilities
    
    /// Creates an identity transformer for Expressions (returns the same tree).
    public static func identityExpressionTransformer() -> ExpressionTransformer {
        return ExpressionTransformer()
    }
    
    /// Creates an identity transformer for Statements (returns the same tree).
    public static func identityStatementTransformer() -> StatementTransformer {
        return StatementTransformer()
    }
    
    /// Creates a transformer that replaces all occurrences of a specific identifier.
    public static func identifierReplacer(
        from oldName: String,
        to newName: String
    ) -> ExpressionTransformer {
        return ExpressionTransformer(
            transformIdentifier: { name in
                return name == oldName ? .identifier(newName) : .identifier(name)
            }
        )
    }
    
    // MARK: - Walking Utilities
    
    /// Performs a depth-first walk of an Expression tree and returns all visited nodes.
    public static func walkExpression(_ expression: Expression) -> [String] {
        return ASTWalker.walkExpression(expression, visitor: ExpressionVisitor.debug)
    }
    
    /// Performs a depth-first walk of a Statement tree and returns all visited nodes.
    public static func walkStatement(_ statement: Statement) -> [String] {
        return ASTWalker.walkStatement(statement, visitor: StatementVisitor.debug)
    }
    
    /// Collects all Expression nodes from a tree that match a predicate.
    public static func collectExpressions(
        from expression: Expression,
        where predicate: @escaping (Expression) -> Bool = { _ in true }
    ) -> [Expression] {
        return ASTWalker.collectExpressions(from: expression, ofType: Expression.self, where: predicate)
    }
    
    /// Collects all Statement nodes from a tree that match a predicate.
    public static func collectStatements(
        from statement: Statement,
        where predicate: @escaping (Statement) -> Bool = { _ in true }
    ) -> [Statement] {
        return ASTWalker.collectStatements(from: statement, ofType: Statement.self, where: predicate)
    }
}

// MARK: - Convenience Extensions

extension Expression {
    /// Accepts a visitor using the convenience method.
    public func visit<Result>(_ visitor: ExpressionVisitor<Result>) -> Result {
        return visitor.visit(self)
    }
    
    /// Returns a debug string representation of this Expression.
    public var debugDescription: String {
        return ExpressionVisitor.debug.visit(self)
    }
    
    /// Validates this Expression and returns any issues found.
    public var validationIssues: [String] {
        return VisitorModule.expressionValidator().visit(self)
    }
    
    /// Collects all identifiers in this Expression tree.
    public var identifiers: [String] {
        return VisitorModule.identifierCollector().visit(self)
    }
    
    /// Collects all function names in this Expression tree.
    public var functionNames: [String] {
        return VisitorModule.functionNameCollector().visit(self)
    }
}

extension Statement {
    /// Accepts a visitor using the convenience method.
    public func visit<Result>(_ visitor: StatementVisitor<Result>) -> Result {
        return visitor.visit(self)
    }
    
    /// Returns a debug string representation of this Statement.
    public var debugDescription: String {
        return StatementVisitor.debug.visit(self)
    }
}