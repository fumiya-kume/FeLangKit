import Foundation

/// Provides automatic recursive AST traversal utilities for Expression and Statement trees.
///
/// ASTWalker implements common traversal patterns that automatically visit child nodes,
/// making it easy to perform operations like collecting identifiers, counting nodes,
/// or transforming entire AST subtrees without manually implementing recursion logic.
///
/// Example usage:
/// ```swift
/// // Collect all identifiers in an expression tree
/// let identifiers = ASTWalker.collectIdentifiers(from: expression)
///
/// // Count total nodes in a statement tree
/// let nodeCount = ASTWalker.countNodes(in: statement)
///
/// // Transform expressions recursively
/// let transformed = ASTWalker.transformExpressions(in: statement) { expr in
///     // Custom transformation logic
///     return expr
/// }
/// ```
public enum ASTWalker {

    // MARK: - Expression Walking

    /// Walks an expression tree and collects all identifier names.
    ///
    /// - Parameter expression: The root expression to walk
    /// - Returns: A set of all identifier names found in the expression tree
    public static func collectIdentifiers(from expression: Expression) -> Set<String> {
        let visitor = ExpressionVisitor<Set<String>>(
            visitLiteral: { _ in Set() },
            visitIdentifier: { identifier in Set([identifier]) },
            visitBinary: { _, left, right in
                collectIdentifiers(from: left).union(collectIdentifiers(from: right))
            },
            visitUnary: { _, operand in
                collectIdentifiers(from: operand)
            },
            visitArrayAccess: { array, index in
                collectIdentifiers(from: array).union(collectIdentifiers(from: index))
            },
            visitFieldAccess: { object, _ in
                collectIdentifiers(from: object)
            },
            visitFunctionCall: { _, arguments in
                arguments.reduce(Set<String>()) { result, arg in
                    result.union(collectIdentifiers(from: arg))
                }
            }
        )

        return visitor.visit(expression)
    }

    /// Walks an expression tree and counts the total number of nodes.
    ///
    /// - Parameter expression: The root expression to walk
    /// - Returns: The total number of nodes in the expression tree
    public static func countNodes(in expression: Expression) -> Int {
        let visitor = ExpressionVisitor<Int>(
            visitLiteral: { _ in 1 },
            visitIdentifier: { _ in 1 },
            visitBinary: { _, left, right in
                1 + countNodes(in: left) + countNodes(in: right)
            },
            visitUnary: { _, operand in
                1 + countNodes(in: operand)
            },
            visitArrayAccess: { array, index in
                1 + countNodes(in: array) + countNodes(in: index)
            },
            visitFieldAccess: { object, _ in
                1 + countNodes(in: object)
            },
            visitFunctionCall: { _, arguments in
                1 + arguments.reduce(0) { result, arg in
                    result + countNodes(in: arg)
                }
            }
        )

        return visitor.visit(expression)
    }

    /// Transforms an expression tree by applying a transformation function to each expression node.
    ///
    /// - Parameters:
    ///   - expression: The root expression to transform
    ///   - transform: A function that takes an expression and returns a transformed expression
    /// - Returns: The transformed expression tree
    public static func transformExpression(_ expression: Expression, _ transform: @escaping @Sendable (Expression) -> Expression) -> Expression {
        let visitor = ExpressionVisitor<Expression>(
            visitLiteral: { literal in
                transform(.literal(literal))
            },
            visitIdentifier: { identifier in
                transform(.identifier(identifier))
            },
            visitBinary: { op, left, right in
                let transformedLeft = transformExpression(left, transform)
                let transformedRight = transformExpression(right, transform)
                return transform(.binary(op, transformedLeft, transformedRight))
            },
            visitUnary: { op, operand in
                let transformedOperand = transformExpression(operand, transform)
                return transform(.unary(op, transformedOperand))
            },
            visitArrayAccess: { array, index in
                let transformedArray = transformExpression(array, transform)
                let transformedIndex = transformExpression(index, transform)
                return transform(.arrayAccess(transformedArray, transformedIndex))
            },
            visitFieldAccess: { object, field in
                let transformedObject = transformExpression(object, transform)
                return transform(.fieldAccess(transformedObject, field))
            },
            visitFunctionCall: { name, arguments in
                let transformedArguments = arguments.map { transformExpression($0, transform) }
                return transform(.functionCall(name, transformedArguments))
            }
        )

        return visitor.visit(expression)
    }

    // MARK: - Statement Walking

    /// Walks a statement tree and collects all identifier names from expressions.
    ///
    /// - Parameter statement: The root statement to walk
    /// - Returns: A set of all identifier names found in the statement tree
    public static func collectIdentifiers(from statement: Statement) -> Set<String> {
        let visitor = StatementVisitor<Set<String>>(
            visitIfStatement: { ifStmt in
                var identifiers = collectIdentifiers(from: ifStmt.condition)
                identifiers.formUnion(ifStmt.thenBody.reduce(Set<String>()) { result, stmt in
                    result.union(collectIdentifiers(from: stmt))
                })
                for elseIf in ifStmt.elseIfs {
                    identifiers.formUnion(collectIdentifiers(from: elseIf.condition))
                    identifiers.formUnion(elseIf.body.reduce(Set<String>()) { result, stmt in
                        result.union(collectIdentifiers(from: stmt))
                    })
                }
                if let elseBody = ifStmt.elseBody {
                    identifiers.formUnion(elseBody.reduce(Set<String>()) { result, stmt in
                        result.union(collectIdentifiers(from: stmt))
                    })
                }
                return identifiers
            },
            visitWhileStatement: { whileStmt in
                var identifiers = collectIdentifiers(from: whileStmt.condition)
                identifiers.formUnion(whileStmt.body.reduce(Set<String>()) { result, stmt in
                    result.union(collectIdentifiers(from: stmt))
                })
                return identifiers
            },
            visitForStatement: { forStmt in
                var identifiers = Set<String>()
                switch forStmt {
                case .range(let rangeFor):
                    identifiers.insert(rangeFor.variable)
                    identifiers.formUnion(collectIdentifiers(from: rangeFor.start))
                    identifiers.formUnion(collectIdentifiers(from: rangeFor.end))
                    if let step = rangeFor.step {
                        identifiers.formUnion(collectIdentifiers(from: step))
                    }
                    identifiers.formUnion(rangeFor.body.reduce(Set<String>()) { result, stmt in
                        result.union(collectIdentifiers(from: stmt))
                    })
                case .forEach(let forEach):
                    identifiers.insert(forEach.variable)
                    identifiers.formUnion(collectIdentifiers(from: forEach.iterable))
                    identifiers.formUnion(forEach.body.reduce(Set<String>()) { result, stmt in
                        result.union(collectIdentifiers(from: stmt))
                    })
                }
                return identifiers
            },
            visitAssignment: { assignment in
                switch assignment {
                case .variable(let name, let expr):
                    return Set([name]).union(collectIdentifiers(from: expr))
                case .arrayElement(let arrayAccess, let expr):
                    return collectIdentifiers(from: arrayAccess.array)
                        .union(collectIdentifiers(from: arrayAccess.index))
                        .union(collectIdentifiers(from: expr))
                }
            },
            visitVariableDeclaration: { varDecl in
                var identifiers = Set([varDecl.name])
                if let initialValue = varDecl.initialValue {
                    identifiers.formUnion(collectIdentifiers(from: initialValue))
                }
                return identifiers
            },
            visitConstantDeclaration: { constDecl in
                return Set([constDecl.name]).union(collectIdentifiers(from: constDecl.initialValue))
            },
            visitFunctionDeclaration: { funcDecl in
                var identifiers = Set([funcDecl.name])
                identifiers.formUnion(Set(funcDecl.parameters.map { $0.name }))
                identifiers.formUnion(Set(funcDecl.localVariables.map { $0.name }))
                identifiers.formUnion(funcDecl.body.reduce(Set<String>()) { result, stmt in
                    result.union(collectIdentifiers(from: stmt))
                })
                return identifiers
            },
            visitProcedureDeclaration: { procDecl in
                var identifiers = Set([procDecl.name])
                identifiers.formUnion(Set(procDecl.parameters.map { $0.name }))
                identifiers.formUnion(Set(procDecl.localVariables.map { $0.name }))
                identifiers.formUnion(procDecl.body.reduce(Set<String>()) { result, stmt in
                    result.union(collectIdentifiers(from: stmt))
                })
                return identifiers
            },
            visitReturnStatement: { returnStmt in
                if let expr = returnStmt.expression {
                    return collectIdentifiers(from: expr)
                }
                return Set()
            },
            visitExpressionStatement: { expr in
                return collectIdentifiers(from: expr)
            },
            visitBreakStatement: {
                return Set()
            },
            visitBlock: { statements in
                return statements.reduce(Set<String>()) { result, stmt in
                    result.union(collectIdentifiers(from: stmt))
                }
            }
        )

        return visitor.visit(statement)
    }

    /// Walks a statement tree and counts the total number of nodes.
    ///
    /// - Parameter statement: The root statement to walk
    /// - Returns: The total number of nodes in the statement tree
    public static func countNodes(in statement: Statement) -> Int {
        let visitor = StatementVisitor<Int>(
            visitIfStatement: { ifStmt in
                var count = 1 + countNodes(in: ifStmt.condition)
                count += ifStmt.thenBody.reduce(0) { result, stmt in
                    result + countNodes(in: stmt)
                }
                for elseIf in ifStmt.elseIfs {
                    count += countNodes(in: elseIf.condition)
                    count += elseIf.body.reduce(0) { result, stmt in
                        result + countNodes(in: stmt)
                    }
                }
                if let elseBody = ifStmt.elseBody {
                    count += elseBody.reduce(0) { result, stmt in
                        result + countNodes(in: stmt)
                    }
                }
                return count
            },
            visitWhileStatement: { whileStmt in
                let conditionCount = countNodes(in: whileStmt.condition)
                let bodyCount = whileStmt.body.reduce(0) { result, stmt in
                    result + countNodes(in: stmt)
                }
                return 1 + conditionCount + bodyCount
            },
            visitForStatement: { forStmt in
                var count = 1
                switch forStmt {
                case .range(let rangeFor):
                    count += countNodes(in: rangeFor.start)
                    count += countNodes(in: rangeFor.end)
                    if let step = rangeFor.step {
                        count += countNodes(in: step)
                    }
                    count += rangeFor.body.reduce(0) { result, stmt in
                        result + countNodes(in: stmt)
                    }
                case .forEach(let forEach):
                    count += countNodes(in: forEach.iterable)
                    count += forEach.body.reduce(0) { result, stmt in
                        result + countNodes(in: stmt)
                    }
                }
                return count
            },
            visitAssignment: { assignment in
                switch assignment {
                case .variable(_, let expr):
                    return 1 + countNodes(in: expr)
                case .arrayElement(let arrayAccess, let expr):
                    return 1 + countNodes(in: arrayAccess.array) + countNodes(in: arrayAccess.index) + countNodes(in: expr)
                }
            },
            visitVariableDeclaration: { varDecl in
                if let initialValue = varDecl.initialValue {
                    return 1 + countNodes(in: initialValue)
                }
                return 1
            },
            visitConstantDeclaration: { constDecl in
                return 1 + countNodes(in: constDecl.initialValue)
            },
            visitFunctionDeclaration: { funcDecl in
                return 1 + funcDecl.body.reduce(0) { result, stmt in
                    result + countNodes(in: stmt)
                }
            },
            visitProcedureDeclaration: { procDecl in
                return 1 + procDecl.body.reduce(0) { result, stmt in
                    result + countNodes(in: stmt)
                }
            },
            visitReturnStatement: { returnStmt in
                if let expr = returnStmt.expression {
                    return 1 + countNodes(in: expr)
                }
                return 1
            },
            visitExpressionStatement: { expr in
                return 1 + countNodes(in: expr)
            },
            visitBreakStatement: {
                return 1
            },
            visitBlock: { statements in
                return 1 + statements.reduce(0) { result, stmt in
                    result + countNodes(in: stmt)
                }
            }
        )

        return visitor.visit(statement)
    }

    /// Transforms a statement tree by applying a transformation function to all expressions.
    ///
    /// - Parameters:
    ///   - statement: The root statement to transform
    ///   - transform: A function that takes an expression and returns a transformed expression
    /// - Returns: The transformed statement tree
    public static func transformExpressions(in statement: Statement, _ transform: @escaping @Sendable (Expression) -> Expression) -> Statement {
        let visitor = StatementVisitor<Statement>(
            visitIfStatement: { ifStmt in
                let transformedCondition = transformExpression(ifStmt.condition, transform)
                let transformedThenBody = ifStmt.thenBody.map { transformExpressions(in: $0, transform) }
                let transformedElseIfs = ifStmt.elseIfs.map { elseIf in
                    IfStatement.ElseIf(
                        condition: transformExpression(elseIf.condition, transform),
                        body: elseIf.body.map { transformExpressions(in: $0, transform) }
                    )
                }
                let transformedElseBody = ifStmt.elseBody?.map { transformExpressions(in: $0, transform) }
                return .ifStatement(IfStatement(
                    condition: transformedCondition,
                    thenBody: transformedThenBody,
                    elseIfs: transformedElseIfs,
                    elseBody: transformedElseBody
                ))
            },
            visitWhileStatement: { whileStmt in
                let transformedCondition = transformExpression(whileStmt.condition, transform)
                let transformedBody = whileStmt.body.map { transformExpressions(in: $0, transform) }
                return .whileStatement(WhileStatement(
                    condition: transformedCondition,
                    body: transformedBody
                ))
            },
            visitForStatement: { forStmt in
                switch forStmt {
                case .range(let rangeFor):
                    let transformedStart = transformExpression(rangeFor.start, transform)
                    let transformedEnd = transformExpression(rangeFor.end, transform)
                    let transformedStep = rangeFor.step.map { transformExpression($0, transform) }
                    let transformedBody = rangeFor.body.map { transformExpressions(in: $0, transform) }
                    return .forStatement(.range(ForStatement.RangeFor(
                        variable: rangeFor.variable,
                        start: transformedStart,
                        end: transformedEnd,
                        step: transformedStep,
                        body: transformedBody
                    )))
                case .forEach(let forEach):
                    let transformedIterable = transformExpression(forEach.iterable, transform)
                    let transformedBody = forEach.body.map { transformExpressions(in: $0, transform) }
                    return .forStatement(.forEach(ForStatement.ForEachLoop(
                        variable: forEach.variable,
                        iterable: transformedIterable,
                        body: transformedBody
                    )))
                }
            },
            visitAssignment: { assignment in
                switch assignment {
                case .variable(let name, let expr):
                    let transformedExpr = transformExpression(expr, transform)
                    return .assignment(.variable(name, transformedExpr))
                case .arrayElement(let arrayAccess, let expr):
                    let transformedArray = transformExpression(arrayAccess.array, transform)
                    let transformedIndex = transformExpression(arrayAccess.index, transform)
                    let transformedExpr = transformExpression(expr, transform)
                    return .assignment(.arrayElement(
                        Assignment.ArrayAccess(array: transformedArray, index: transformedIndex),
                        transformedExpr
                    ))
                }
            },
            visitVariableDeclaration: { varDecl in
                let transformedInitialValue = varDecl.initialValue.map { transformExpression($0, transform) }
                return .variableDeclaration(VariableDeclaration(
                    name: varDecl.name,
                    type: varDecl.type,
                    initialValue: transformedInitialValue
                ))
            },
            visitConstantDeclaration: { constDecl in
                let transformedInitialValue = transformExpression(constDecl.initialValue, transform)
                return .constantDeclaration(ConstantDeclaration(
                    name: constDecl.name,
                    type: constDecl.type,
                    initialValue: transformedInitialValue
                ))
            },
            visitFunctionDeclaration: { funcDecl in
                let transformedBody = funcDecl.body.map { transformExpressions(in: $0, transform) }
                let transformedLocalVars = funcDecl.localVariables.map { varDecl in
                    VariableDeclaration(
                        name: varDecl.name,
                        type: varDecl.type,
                        initialValue: varDecl.initialValue.map { transformExpression($0, transform) }
                    )
                }
                return .functionDeclaration(FunctionDeclaration(
                    name: funcDecl.name,
                    parameters: funcDecl.parameters,
                    returnType: funcDecl.returnType,
                    localVariables: transformedLocalVars,
                    body: transformedBody
                ))
            },
            visitProcedureDeclaration: { procDecl in
                let transformedBody = procDecl.body.map { transformExpressions(in: $0, transform) }
                let transformedLocalVars = procDecl.localVariables.map { varDecl in
                    VariableDeclaration(
                        name: varDecl.name,
                        type: varDecl.type,
                        initialValue: varDecl.initialValue.map { transformExpression($0, transform) }
                    )
                }
                return .procedureDeclaration(ProcedureDeclaration(
                    name: procDecl.name,
                    parameters: procDecl.parameters,
                    localVariables: transformedLocalVars,
                    body: transformedBody
                ))
            },
            visitReturnStatement: { returnStmt in
                let transformedExpression = returnStmt.expression.map { transformExpression($0, transform) }
                return .returnStatement(ReturnStatement(expression: transformedExpression))
            },
            visitExpressionStatement: { expr in
                let transformedExpr = transformExpression(expr, transform)
                return .expressionStatement(transformedExpr)
            },
            visitBreakStatement: {
                return .breakStatement
            },
            visitBlock: { statements in
                let transformedStatements = statements.map { transformExpressions(in: $0, transform) }
                return .block(transformedStatements)
            }
        )

        return visitor.visit(statement)
    }
}
