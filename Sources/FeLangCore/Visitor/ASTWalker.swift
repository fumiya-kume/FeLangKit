import Foundation

/// A utility that provides automatic recursive traversal of AST nodes.
///
/// `ASTWalker` simplifies the implementation of visitors that need to recursively
/// traverse the entire AST structure. It handles the traversal logic automatically,
/// allowing you to focus on the processing logic for each node type.
///
/// Example usage:
/// ```swift
/// let counter = ASTWalker.createExpressionCounter()
/// let count = counter.visit(expression)
/// 
/// let collector = ASTWalker.createIdentifierCollector()
/// let identifiers = collector.visit(expression)
/// ```
public struct ASTWalker {

    // MARK: - Expression Walkers

    /// Creates an expression visitor that counts the total number of nodes in an expression tree.
    /// - Returns: A visitor that returns the total node count
    public static func createExpressionCounter() -> ExpressionVisitor<Int> {
        return ExpressionVisitor<Int>(
            visitLiteral: { _ in 1 },
            visitIdentifier: { _ in 1 },
            visitBinary: { _, left, right in
                1 + createExpressionCounter().visit(left) + createExpressionCounter().visit(right)
            },
            visitUnary: { _, operand in
                1 + createExpressionCounter().visit(operand)
            },
            visitArrayAccess: { array, index in
                1 + createExpressionCounter().visit(array) + createExpressionCounter().visit(index)
            },
            visitFieldAccess: { object, _ in
                1 + createExpressionCounter().visit(object)
            },
            visitFunctionCall: { _, arguments in
                1 + arguments.map { createExpressionCounter().visit($0) }.reduce(0, +)
            }
        )
    }

    /// Creates an expression visitor that collects all identifier names in an expression tree.
    /// - Returns: A visitor that returns an array of identifier names
    public static func createIdentifierCollector() -> ExpressionVisitor<[String]> {
        return ExpressionVisitor<[String]>(
            visitLiteral: { _ in [] },
            visitIdentifier: { identifier in [identifier] },
            visitBinary: { _, left, right in
                createIdentifierCollector().visit(left) + createIdentifierCollector().visit(right)
            },
            visitUnary: { _, operand in
                createIdentifierCollector().visit(operand)
            },
            visitArrayAccess: { array, index in
                createIdentifierCollector().visit(array) + createIdentifierCollector().visit(index)
            },
            visitFieldAccess: { object, _ in
                createIdentifierCollector().visit(object)
            },
            visitFunctionCall: { _, arguments in
                arguments.flatMap { createIdentifierCollector().visit($0) }
            }
        )
    }

    /// Creates an expression visitor that finds the maximum nesting depth of an expression tree.
    /// - Returns: A visitor that returns the maximum depth
    public static func createDepthCalculator() -> ExpressionVisitor<Int> {
        return ExpressionVisitor<Int>(
            visitLiteral: { _ in 1 },
            visitIdentifier: { _ in 1 },
            visitBinary: { _, left, right in
                1 + max(createDepthCalculator().visit(left), createDepthCalculator().visit(right))
            },
            visitUnary: { _, operand in
                1 + createDepthCalculator().visit(operand)
            },
            visitArrayAccess: { array, index in
                1 + max(createDepthCalculator().visit(array), createDepthCalculator().visit(index))
            },
            visitFieldAccess: { object, _ in
                1 + createDepthCalculator().visit(object)
            },
            visitFunctionCall: { _, arguments in
                1 + (arguments.map { createDepthCalculator().visit($0) }.max() ?? 0)
            }
        )
    }

    // MARK: - Statement Walkers

    /// Creates a statement visitor that counts the total number of statements in a statement tree.
    /// - Returns: A visitor that returns the total statement count
    public static func createStatementCounter() -> StatementVisitor<Int> {
        return StatementVisitor<Int>(
            visitIfStatement: { ifStmt in
                let thenCount = ifStmt.thenBody.map { createStatementCounter().visit($0) }.reduce(0, +)
                let elseIfCount = ifStmt.elseIfs.flatMap(\.body).map { createStatementCounter().visit($0) }.reduce(0, +)
                let elseCount = ifStmt.elseBody?.map { createStatementCounter().visit($0) }.reduce(0, +) ?? 0
                return 1 + thenCount + elseIfCount + elseCount
            },
            visitWhileStatement: { whileStmt in
                1 + whileStmt.body.map { createStatementCounter().visit($0) }.reduce(0, +)
            },
            visitForStatement: { forStmt in
                let bodyCount: Int
                switch forStmt {
                case .range(let rangeFor):
                    bodyCount = rangeFor.body.map { createStatementCounter().visit($0) }.reduce(0, +)
                case .forEach(let forEach):
                    bodyCount = forEach.body.map { createStatementCounter().visit($0) }.reduce(0, +)
                }
                return 1 + bodyCount
            },
            visitAssignment: { _ in 1 },
            visitVariableDeclaration: { _ in 1 },
            visitConstantDeclaration: { _ in 1 },
            visitFunctionDeclaration: { funcDecl in
                1 + funcDecl.body.map { createStatementCounter().visit($0) }.reduce(0, +)
            },
            visitProcedureDeclaration: { procDecl in
                1 + procDecl.body.map { createStatementCounter().visit($0) }.reduce(0, +)
            },
            visitReturnStatement: { _ in 1 },
            visitExpressionStatement: { _ in 1 },
            visitBreakStatement: { 1 },
            visitBlock: { statements in
                1 + statements.map { createStatementCounter().visit($0) }.reduce(0, +)
            }
        )
    }

    /// Creates a statement visitor that collects all variable and constant declaration names.
    /// - Returns: A visitor that returns an array of declaration names
    public static func createDeclarationCollector() -> StatementVisitor<[String]> {
        return StatementVisitor<[String]>(
            visitIfStatement: { ifStmt in
                let thenDecls = ifStmt.thenBody.flatMap { createDeclarationCollector().visit($0) }
                let elseIfDecls = ifStmt.elseIfs.flatMap(\.body).flatMap { createDeclarationCollector().visit($0) }
                let elseDecls = ifStmt.elseBody?.flatMap { createDeclarationCollector().visit($0) } ?? []
                return thenDecls + elseIfDecls + elseDecls
            },
            visitWhileStatement: { whileStmt in
                whileStmt.body.flatMap { createDeclarationCollector().visit($0) }
            },
            visitForStatement: { forStmt in
                let bodyDecls: [String]
                switch forStmt {
                case .range(let rangeFor):
                    bodyDecls = rangeFor.body.flatMap { createDeclarationCollector().visit($0) }
                    return [rangeFor.variable] + bodyDecls
                case .forEach(let forEach):
                    bodyDecls = forEach.body.flatMap { createDeclarationCollector().visit($0) }
                    return [forEach.variable] + bodyDecls
                }
            },
            visitAssignment: { _ in [] },
            visitVariableDeclaration: { varDecl in [varDecl.name] },
            visitConstantDeclaration: { constDecl in [constDecl.name] },
            visitFunctionDeclaration: { funcDecl in
                let paramNames = funcDecl.parameters.map(\.name)
                let localVarNames = funcDecl.localVariables.map(\.name)
                let bodyDecls = funcDecl.body.flatMap { createDeclarationCollector().visit($0) }
                return [funcDecl.name] + paramNames + localVarNames + bodyDecls
            },
            visitProcedureDeclaration: { procDecl in
                let paramNames = procDecl.parameters.map(\.name)
                let localVarNames = procDecl.localVariables.map(\.name)
                let bodyDecls = procDecl.body.flatMap { createDeclarationCollector().visit($0) }
                return [procDecl.name] + paramNames + localVarNames + bodyDecls
            },
            visitReturnStatement: { _ in [] },
            visitExpressionStatement: { _ in [] },
            visitBreakStatement: { [] },
            visitBlock: { statements in
                statements.flatMap { createDeclarationCollector().visit($0) }
            }
        )
    }

    // MARK: - Utility Functions

    /// Creates a visitor that performs a depth-first traversal and applies a function to each expression.
    /// - Parameter action: The function to apply to each expression
    /// - Returns: A visitor that performs the traversal
    public static func createExpressionTraverser(action: @escaping @Sendable (Expression) -> Void) -> ExpressionVisitor<Void> {
        return ExpressionVisitor<Void>(
            visitLiteral: { literal in action(.literal(literal)) },
            visitIdentifier: { identifier in action(.identifier(identifier)) },
            visitBinary: { binaryOp, left, right in
                action(.binary(binaryOp, left, right))
                createExpressionTraverser(action: action).visit(left)
                createExpressionTraverser(action: action).visit(right)
            },
            visitUnary: { unaryOp, operand in
                action(.unary(unaryOp, operand))
                createExpressionTraverser(action: action).visit(operand)
            },
            visitArrayAccess: { array, index in
                action(.arrayAccess(array, index))
                createExpressionTraverser(action: action).visit(array)
                createExpressionTraverser(action: action).visit(index)
            },
            visitFieldAccess: { object, field in
                action(.fieldAccess(object, field))
                createExpressionTraverser(action: action).visit(object)
            },
            visitFunctionCall: { function, arguments in
                action(.functionCall(function, arguments))
                arguments.forEach { createExpressionTraverser(action: action).visit($0) }
            }
        )
    }

    /// Creates a visitor that performs a depth-first traversal and applies a function to each statement.
    /// - Parameter action: The function to apply to each statement
    /// - Returns: A visitor that performs the traversal
    public static func createStatementTraverser(action: @escaping @Sendable (Statement) -> Void) -> StatementVisitor<Void> {
        return StatementVisitor<Void>(
            visitIfStatement: { ifStmt in
                action(.ifStatement(ifStmt))
                ifStmt.thenBody.forEach { createStatementTraverser(action: action).visit($0) }
                ifStmt.elseIfs.forEach { elseIf in
                    elseIf.body.forEach { createStatementTraverser(action: action).visit($0) }
                }
                ifStmt.elseBody?.forEach { createStatementTraverser(action: action).visit($0) }
            },
            visitWhileStatement: { whileStmt in
                action(.whileStatement(whileStmt))
                whileStmt.body.forEach { createStatementTraverser(action: action).visit($0) }
            },
            visitForStatement: { forStmt in
                action(.forStatement(forStmt))
                switch forStmt {
                case .range(let rangeFor):
                    rangeFor.body.forEach { createStatementTraverser(action: action).visit($0) }
                case .forEach(let forEach):
                    forEach.body.forEach { createStatementTraverser(action: action).visit($0) }
                }
            },
            visitAssignment: { assignment in action(.assignment(assignment)) },
            visitVariableDeclaration: { varDecl in action(.variableDeclaration(varDecl)) },
            visitConstantDeclaration: { constDecl in action(.constantDeclaration(constDecl)) },
            visitFunctionDeclaration: { funcDecl in
                action(.functionDeclaration(funcDecl))
                funcDecl.body.forEach { createStatementTraverser(action: action).visit($0) }
            },
            visitProcedureDeclaration: { procDecl in
                action(.procedureDeclaration(procDecl))
                procDecl.body.forEach { createStatementTraverser(action: action).visit($0) }
            },
            visitReturnStatement: { returnStmt in action(.returnStatement(returnStmt)) },
            visitExpressionStatement: { expr in action(.expressionStatement(expr)) },
            visitBreakStatement: { action(.breakStatement) },
            visitBlock: { statements in
                action(.block(statements))
                statements.forEach { createStatementTraverser(action: action).visit($0) }
            }
        )
    }
}
