import Foundation

/// ASTWalker provides automatic recursive traversal of AST structures.
/// This is useful for visitors that need to process entire AST trees recursively.
public struct ASTWalker: Sendable {
    
    /// Recursively walks an expression tree, applying the visitor to each node
    /// and combining results using the provided accumulator function.
    public static func walkExpression<Result>(
        _ expression: Expression,
        visitor: ExpressionVisitor<Result>,
        accumulator: @Sendable (Result, Result) -> Result,
        identity: Result
    ) -> Result {
        let currentResult = visitor.visit(expression)
        
        // Recursively process child expressions
        let childResults = getChildExpressions(expression).map { childExpr in
            walkExpression(childExpr, visitor: visitor, accumulator: accumulator, identity: identity)
        }
        
        // Combine current result with child results
        return childResults.reduce(currentResult, accumulator)
    }
    
    /// Recursively walks a statement tree, applying the visitor to each node
    /// and combining results using the provided accumulator function.
    public static func walkStatement<Result>(
        _ statement: Statement,
        statementVisitor: StatementVisitor<Result>,
        expressionVisitor: ExpressionVisitor<Result>,
        accumulator: @Sendable (Result, Result) -> Result,
        identity: Result
    ) -> Result {
        let currentResult = statementVisitor.visit(statement)
        
        // Process child expressions
        let expressionResults = getChildExpressions(statement).map { expr in
            walkExpression(expr, visitor: expressionVisitor, accumulator: accumulator, identity: identity)
        }
        
        // Process child statements
        let statementResults = getChildStatements(statement).map { stmt in
            walkStatement(stmt, statementVisitor: statementVisitor, expressionVisitor: expressionVisitor, accumulator: accumulator, identity: identity)
        }
        
        // Combine all results
        let allResults = expressionResults + statementResults
        return allResults.reduce(currentResult, accumulator)
    }
    
    /// Collects all expressions in an expression tree using a collecting visitor
    public static func collectExpressions<T>(
        _ expression: Expression,
        collector: @Sendable (Expression) -> [T]
    ) -> [T] {
        let visitor = ExpressionVisitor<[T]>(
            visitLiteral: { _ in collector(expression) },
            visitIdentifier: { _ in collector(expression) },
            visitBinary: { _, _, _ in collector(expression) },
            visitUnary: { _, _ in collector(expression) },
            visitArrayAccess: { _, _ in collector(expression) },
            visitFieldAccess: { _, _ in collector(expression) },
            visitFunctionCall: { _, _ in collector(expression) }
        )
        
        return walkExpression(expression, visitor: visitor, accumulator: +, identity: [])
    }
    
    /// Collects all statements in a statement tree using a collecting visitor
    public static func collectStatements<T>(
        _ statement: Statement,
        statementCollector: @Sendable (Statement) -> [T],
        expressionCollector: @Sendable (Expression) -> [T] = { _ in [] }
    ) -> [T] {
        let statementVisitor = StatementVisitor<[T]>(
            visitIfStatement: { _ in statementCollector(statement) },
            visitWhileStatement: { _ in statementCollector(statement) },
            visitForStatement: { _ in statementCollector(statement) },
            visitAssignment: { _ in statementCollector(statement) },
            visitVariableDeclaration: { _ in statementCollector(statement) },
            visitConstantDeclaration: { _ in statementCollector(statement) },
            visitFunctionDeclaration: { _ in statementCollector(statement) },
            visitProcedureDeclaration: { _ in statementCollector(statement) },
            visitReturnStatement: { _ in statementCollector(statement) },
            visitExpressionStatement: { _ in statementCollector(statement) },
            visitBreakStatement: { statementCollector(statement) },
            visitBlock: { _ in statementCollector(statement) }
        )
        
        let expressionVisitor = ExpressionVisitor<[T]>(
            visitLiteral: { _ in [] },
            visitIdentifier: { _ in [] },
            visitBinary: { _, _, _ in [] },
            visitUnary: { _, _ in [] },
            visitArrayAccess: { _, _ in [] },
            visitFieldAccess: { _, _ in [] },
            visitFunctionCall: { _, _ in [] }
        )
        
        return walkStatement(statement, statementVisitor: statementVisitor, expressionVisitor: expressionVisitor, accumulator: +, identity: [])
    }
    
    /// Transforms an expression tree by applying a transformation function to each node
    public static func transformExpression(
        _ expression: Expression,
        transform: @Sendable (Expression) -> Expression
    ) -> Expression {
        // First transform child expressions
        let transformedExpression: Expression
        switch expression {
        case .literal:
            transformedExpression = expression
        case .identifier:
            transformedExpression = expression
        case .binary(let op, let left, let right):
            let transformedLeft = transformExpression(left, transform: transform)
            let transformedRight = transformExpression(right, transform: transform)
            transformedExpression = .binary(op, transformedLeft, transformedRight)
        case .unary(let op, let expr):
            let transformedExpr = transformExpression(expr, transform: transform)
            transformedExpression = .unary(op, transformedExpr)
        case .arrayAccess(let array, let index):
            let transformedArray = transformExpression(array, transform: transform)
            let transformedIndex = transformExpression(index, transform: transform)
            transformedExpression = .arrayAccess(transformedArray, transformedIndex)
        case .fieldAccess(let expr, let field):
            let transformedExpr = transformExpression(expr, transform: transform)
            transformedExpression = .fieldAccess(transformedExpr, field)
        case .functionCall(let name, let args):
            let transformedArgs = args.map { transformExpression($0, transform: transform) }
            transformedExpression = .functionCall(name, transformedArgs)
        }
        
        // Then apply transformation to the current node
        return transform(transformedExpression)
    }
    
    // MARK: - Helper methods for extracting child nodes
    
    /// Extracts child expressions from an expression
    private static func getChildExpressions(_ expression: Expression) -> [Expression] {
        switch expression {
        case .literal, .identifier:
            return []
        case .binary(_, let left, let right):
            return [left, right]
        case .unary(_, let expr):
            return [expr]
        case .arrayAccess(let array, let index):
            return [array, index]
        case .fieldAccess(let expr, _):
            return [expr]
        case .functionCall(_, let args):
            return args
        }
    }
    
    /// Extracts child expressions from a statement
    private static func getChildExpressions(_ statement: Statement) -> [Expression] {
        switch statement {
        case .ifStatement(let ifStmt):
            var expressions = [ifStmt.condition]
            expressions.append(contentsOf: ifStmt.elseIfs.map { $0.condition })
            return expressions
        case .whileStatement(let whileStmt):
            return [whileStmt.condition]
        case .forStatement(let forStmt):
            switch forStmt {
            case .range(let rangeFor):
                var expressions = [rangeFor.start, rangeFor.end]
                if let step = rangeFor.step {
                    expressions.append(step)
                }
                return expressions
            case .forEach(let forEachLoop):
                return [forEachLoop.iterable]
            }
        case .assignment(let assignment):
            switch assignment {
            case .variable(_, let expr):
                return [expr]
            case .arrayElement(let arrayAccess, let expr):
                return [arrayAccess.array, arrayAccess.index, expr]
            }
        case .variableDeclaration(let varDecl):
            return varDecl.initialValue.map { [$0] } ?? []
        case .constantDeclaration(let constDecl):
            return [constDecl.initialValue]
        case .functionDeclaration:
            return []
        case .procedureDeclaration:
            return []
        case .returnStatement(let returnStmt):
            return returnStmt.expression.map { [$0] } ?? []
        case .expressionStatement(let expr):
            return [expr]
        case .breakStatement:
            return []
        case .block:
            return []
        }
    }
    
    /// Extracts child statements from a statement
    private static func getChildStatements(_ statement: Statement) -> [Statement] {
        switch statement {
        case .ifStatement(let ifStmt):
            var statements = ifStmt.thenBody
            statements.append(contentsOf: ifStmt.elseIfs.flatMap { $0.body })
            if let elseBody = ifStmt.elseBody {
                statements.append(contentsOf: elseBody)
            }
            return statements
        case .whileStatement(let whileStmt):
            return whileStmt.body
        case .forStatement(let forStmt):
            switch forStmt {
            case .range(let rangeFor):
                return rangeFor.body
            case .forEach(let forEachLoop):
                return forEachLoop.body
            }
        case .assignment:
            return []
        case .variableDeclaration:
            return []
        case .constantDeclaration:
            return []
        case .functionDeclaration(let funcDecl):
            return funcDecl.body
        case .procedureDeclaration(let procDecl):
            return procDecl.body
        case .returnStatement:
            return []
        case .expressionStatement:
            return []
        case .breakStatement:
            return []
        case .block(let statements):
            return statements
        }
    }
}