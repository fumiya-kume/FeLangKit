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
            },
            visitMethodCall: { receiver, _, arguments in
                var identifiers = collectIdentifiers(from: receiver)
                identifiers.formUnion(arguments.reduce(Set<String>()) { result, arg in
                    result.union(collectIdentifiers(from: arg))
                })
                return identifiers
            },
            visitArrayLiteral: { elements in
                elements.reduce(Set<String>()) { result, element in
                    result.union(collectIdentifiers(from: element))
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
            },
            visitMethodCall: { receiver, _, arguments in
                1 + countNodes(in: receiver) + arguments.reduce(0) { result, arg in
                    result + countNodes(in: arg)
                }
            },
            visitArrayLiteral: { elements in
                1 + elements.reduce(0) { result, element in
                    result + countNodes(in: element)
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
    public static func transformExpression(
        _ expression: Expression,
        _ transform: @escaping @Sendable (Expression) -> Expression
    ) -> Expression {
        let visitor = makeTransformVisitor(transform)
        return visitor.visit(expression)
    }

    // MARK: - Statement Walking

    /// Walks a statement tree and collects all identifier names from expressions.
    ///
    /// - Parameter statement: The root statement to walk
    /// - Returns: A set of all identifier names found in the statement tree
    public static func collectIdentifiers(from statement: Statement) -> Set<String> {
        let visitor = StatementVisitor<Set<String>>(
            visitIfStatement: { collectIdentifiersFromIfStatement($0) },
            visitWhileStatement: { stmt in
                collectIdentifiers(from: stmt.condition).union(collectIdentifiersFromStatements(stmt.body))
            },
            visitDoWhileStatement: { stmt in
                collectIdentifiers(from: stmt.condition).union(collectIdentifiersFromStatements(stmt.body))
            },
            visitForStatement: { collectIdentifiersFromForStatement($0) },
            visitAssignment: { collectIdentifiersFromAssignment($0) },
            visitVariableDeclaration: { decl in
                var identifiers = Set([decl.name])
                if let value = decl.initialValue { identifiers.formUnion(collectIdentifiers(from: value)) }
                return identifiers
            },
            visitConstantDeclaration: { Set([$0.name]).union(collectIdentifiers(from: $0.initialValue)) },
            visitFunctionDeclaration: {
                collectIdentifiersFromCallableDecl(
                    name: $0.name, params: $0.parameters, locals: $0.localVariables, body: $0.body)
            },
            visitProcedureDeclaration: {
                collectIdentifiersFromCallableDecl(
                    name: $0.name, params: $0.parameters, locals: $0.localVariables, body: $0.body)
            },
            visitReturnStatement: { $0.expression.map { collectIdentifiers(from: $0) } ?? Set() },
            visitExpressionStatement: { collectIdentifiers(from: $0) },
            visitBreakStatement: { Set() },
            visitContinueStatement: { Set() },
            visitBlock: { collectIdentifiersFromStatements($0) },
            visitRecordDeclaration: { Set([$0.name]).union(Set($0.fields.map { $0.name })) },
            visitClassDeclaration: { Set([$0.name]).union(Set($0.members.map { $0.name })) },
            visitGlobalDeclaration: { decl in
                var identifiers = Set([decl.name])
                if let value = decl.initialValue { identifiers.formUnion(collectIdentifiers(from: value)) }
                return identifiers
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
            visitIfStatement: { countNodesInIfStatement($0) },
            visitWhileStatement: { 1 + countNodes(in: $0.condition) + countNodesInStatements($0.body) },
            visitDoWhileStatement: { 1 + countNodes(in: $0.condition) + countNodesInStatements($0.body) },
            visitForStatement: { countNodesInForStatement($0) },
            visitAssignment: { countNodesInAssignment($0) },
            visitVariableDeclaration: { $0.initialValue.map { 1 + countNodes(in: $0) } ?? 1 },
            visitConstantDeclaration: { 1 + countNodes(in: $0.initialValue) },
            visitFunctionDeclaration: { 1 + countNodesInStatements($0.body) },
            visitProcedureDeclaration: { 1 + countNodesInStatements($0.body) },
            visitReturnStatement: { $0.expression.map { 1 + countNodes(in: $0) } ?? 1 },
            visitExpressionStatement: { 1 + countNodes(in: $0) },
            visitBreakStatement: { 1 },
            visitContinueStatement: { 1 },
            visitBlock: { 1 + countNodesInStatements($0) },
            visitRecordDeclaration: { 1 + $0.fields.count },
            visitClassDeclaration: { 1 + $0.members.count },
            visitGlobalDeclaration: { $0.initialValue.map { 1 + countNodes(in: $0) } ?? 1 }
        )
        return visitor.visit(statement)
    }

    /// Transforms a statement tree by applying a transformation function to all expressions.
    ///
    /// - Parameters:
    ///   - statement: The root statement to transform
    ///   - transform: A function that takes an expression and returns a transformed expression
    /// - Returns: The transformed statement tree
    public static func transformExpressions(
        in statement: Statement,
        _ transform: @escaping @Sendable (Expression) -> Expression
    ) -> Statement {
        let visitor = StatementVisitor<Statement>(
            visitIfStatement: { transformExpressionsInIfStatement($0, transform) },
            visitWhileStatement: { stmt in
                .whileStatement(WhileStatement(
                    condition: transformExpression(stmt.condition, transform),
                    body: stmt.body.map { transformExpressions(in: $0, transform) }))
            },
            visitDoWhileStatement: { stmt in
                .doWhileStatement(DoWhileStatement(
                    body: stmt.body.map { transformExpressions(in: $0, transform) },
                    condition: transformExpression(stmt.condition, transform)))
            },
            visitForStatement: { transformExpressionsInForStatement($0, transform) },
            visitAssignment: { transformExpressionsInAssignment($0, transform) },
            visitVariableDeclaration: { decl in
                .variableDeclaration(VariableDeclaration(name: decl.name, type: decl.type,
                    initialValue: decl.initialValue.map { transformExpression($0, transform) }))
            },
            visitConstantDeclaration: { decl in
                .constantDeclaration(ConstantDeclaration(name: decl.name, type: decl.type,
                    initialValue: transformExpression(decl.initialValue, transform)))
            },
            visitFunctionDeclaration: { transformExpressionsInFunctionDecl($0, transform) },
            visitProcedureDeclaration: { transformExpressionsInProcedureDecl($0, transform) },
            visitReturnStatement: { stmt in
                .returnStatement(ReturnStatement(
                    expression: stmt.expression.map { transformExpression($0, transform) }))
            },
            visitExpressionStatement: { .expressionStatement(transformExpression($0, transform)) },
            visitBreakStatement: { .breakStatement },
            visitContinueStatement: { .continueStatement },
            visitBlock: { .block($0.map { transformExpressions(in: $0, transform) }) },
            visitRecordDeclaration: {
                .recordDeclaration(RecordDeclaration(
                    name: $0.name, fields: $0.fields, position: $0.position))
            },
            visitClassDeclaration: { .classDeclaration($0) },
            visitGlobalDeclaration: { decl in
                .globalDeclaration(GlobalDeclaration(name: decl.name, type: decl.type,
                    initialValue: decl.initialValue.map { transformExpression($0, transform) },
                    position: decl.position))
            }
        )
        return visitor.visit(statement)
    }

    // MARK: - Expression Transform Helper

    /// Constructs an ExpressionVisitor that recursively transforms expression nodes.
    ///
    /// - Parameter transform: A function applied to each expression node
    /// - Returns: An ExpressionVisitor configured for recursive transformation
    public static func makeTransformVisitor(
        _ transform: @escaping @Sendable (Expression) -> Expression
    ) -> ExpressionVisitor<Expression> {
        ExpressionVisitor<Expression>(
            visitLiteral: { literal in
                transform(.literal(literal))
            },
            visitIdentifier: { identifier in
                transform(.identifier(identifier))
            },
            visitBinary: { binaryOperator, left, right in
                let transformedLeft = transformExpression(left, transform)
                let transformedRight = transformExpression(right, transform)
                return transform(.binary(binaryOperator, transformedLeft, transformedRight))
            },
            visitUnary: { unaryOperator, operand in
                let transformedOperand = transformExpression(operand, transform)
                return transform(.unary(unaryOperator, transformedOperand))
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
            },
            visitMethodCall: { receiver, method, arguments in
                let transformedReceiver = transformExpression(receiver, transform)
                let transformedArguments = arguments.map { transformExpression($0, transform) }
                return transform(.methodCall(transformedReceiver, method, transformedArguments))
            },
            visitArrayLiteral: { elements in
                let transformedElements = elements.map { transformExpression($0, transform) }
                return transform(.arrayLiteral(transformedElements))
            }
        )
    }

    // MARK: - Identifier Collection Helpers

    /// Collects identifiers from an array of statements.
    ///
    /// - Parameter statements: The statements to collect identifiers from
    /// - Returns: A set of all identifier names found
    public static func collectIdentifiersFromStatements(_ statements: [Statement]) -> Set<String> {
        statements.reduce(Set<String>()) { result, stmt in
            result.union(collectIdentifiers(from: stmt))
        }
    }

    /// Collects identifiers from an if statement including elseif and else branches.
    ///
    /// - Parameter ifStmt: The if statement to collect identifiers from
    /// - Returns: A set of all identifier names found
    public static func collectIdentifiersFromIfStatement(_ ifStmt: IfStatement) -> Set<String> {
        var identifiers = collectIdentifiers(from: ifStmt.condition)
        identifiers.formUnion(collectIdentifiersFromStatements(ifStmt.thenBody))
        for elseIf in ifStmt.elseIfs {
            identifiers.formUnion(collectIdentifiers(from: elseIf.condition))
            identifiers.formUnion(collectIdentifiersFromStatements(elseIf.body))
        }
        if let elseBody = ifStmt.elseBody {
            identifiers.formUnion(collectIdentifiersFromStatements(elseBody))
        }
        return identifiers
    }

    /// Collects identifiers from a for statement (range or forEach).
    ///
    /// - Parameter forStmt: The for statement to collect identifiers from
    /// - Returns: A set of all identifier names found
    public static func collectIdentifiersFromForStatement(_ forStmt: ForStatement) -> Set<String> {
        var identifiers = Set<String>()
        switch forStmt {
        case .range(let rangeFor):
            identifiers.insert(rangeFor.variable)
            identifiers.formUnion(collectIdentifiers(from: rangeFor.start))
            identifiers.formUnion(collectIdentifiers(from: rangeFor.end))
            if let step = rangeFor.step {
                identifiers.formUnion(collectIdentifiers(from: step))
            }
            identifiers.formUnion(collectIdentifiersFromStatements(rangeFor.body))
        case .forEach(let forEach):
            identifiers.insert(forEach.variable)
            identifiers.formUnion(collectIdentifiers(from: forEach.iterable))
            identifiers.formUnion(collectIdentifiersFromStatements(forEach.body))
        }
        return identifiers
    }

    /// Collects identifiers from an assignment statement.
    ///
    /// - Parameter assignment: The assignment to collect identifiers from
    /// - Returns: A set of all identifier names found
    public static func collectIdentifiersFromAssignment(_ assignment: Assignment) -> Set<String> {
        switch assignment {
        case .variable(let name, let expr):
            return Set([name]).union(collectIdentifiers(from: expr))
        case .arrayElement(let arrayAccess, let expr):
            return collectIdentifiers(from: arrayAccess.array)
                .union(collectIdentifiers(from: arrayAccess.index))
                .union(collectIdentifiers(from: expr))
        case .fieldAccess(let fieldAccess, let expr):
            return collectIdentifiers(from: fieldAccess.object)
                .union(collectIdentifiers(from: expr))
        }
    }

    /// Collects identifiers from a function or procedure declaration.
    ///
    /// - Parameters:
    ///   - name: The callable's name
    ///   - params: The callable's parameters
    ///   - locals: The callable's local variable declarations
    ///   - body: The callable's body statements
    /// - Returns: A set of all identifier names found
    public static func collectIdentifiersFromCallableDecl(
        name: String,
        params: [Parameter],
        locals: [VariableDeclaration],
        body: [Statement]
    ) -> Set<String> {
        var identifiers = Set([name])
        identifiers.formUnion(Set(params.map { $0.name }))
        identifiers.formUnion(Set(locals.map { $0.name }))
        identifiers.formUnion(collectIdentifiersFromStatements(body))
        return identifiers
    }

    // MARK: - Node Counting Helpers

    /// Counts nodes in an array of statements.
    ///
    /// - Parameter statements: The statements to count nodes in
    /// - Returns: The total number of nodes
    public static func countNodesInStatements(_ statements: [Statement]) -> Int {
        statements.reduce(0) { result, stmt in
            result + countNodes(in: stmt)
        }
    }

    /// Counts nodes in an if statement including elseif and else branches.
    ///
    /// - Parameter ifStmt: The if statement to count nodes in
    /// - Returns: The total number of nodes
    public static func countNodesInIfStatement(_ ifStmt: IfStatement) -> Int {
        var count = 1 + countNodes(in: ifStmt.condition)
        count += countNodesInStatements(ifStmt.thenBody)
        for elseIf in ifStmt.elseIfs {
            count += countNodes(in: elseIf.condition)
            count += countNodesInStatements(elseIf.body)
        }
        if let elseBody = ifStmt.elseBody {
            count += countNodesInStatements(elseBody)
        }
        return count
    }

    /// Counts nodes in a for statement (range or forEach).
    ///
    /// - Parameter forStmt: The for statement to count nodes in
    /// - Returns: The total number of nodes
    public static func countNodesInForStatement(_ forStmt: ForStatement) -> Int {
        var count = 1
        switch forStmt {
        case .range(let rangeFor):
            count += countNodes(in: rangeFor.start)
            count += countNodes(in: rangeFor.end)
            if let step = rangeFor.step {
                count += countNodes(in: step)
            }
            count += countNodesInStatements(rangeFor.body)
        case .forEach(let forEach):
            count += countNodes(in: forEach.iterable)
            count += countNodesInStatements(forEach.body)
        }
        return count
    }

    /// Counts nodes in an assignment statement.
    ///
    /// - Parameter assignment: The assignment to count nodes in
    /// - Returns: The total number of nodes
    public static func countNodesInAssignment(_ assignment: Assignment) -> Int {
        switch assignment {
        case .variable(_, let expr):
            return 1 + countNodes(in: expr)
        case .arrayElement(let arrayAccess, let expr):
            return 1 + countNodes(in: arrayAccess.array) + countNodes(in: arrayAccess.index) + countNodes(in: expr)
        case .fieldAccess(let fieldAccess, let expr):
            return 1 + countNodes(in: fieldAccess.object) + countNodes(in: expr)
        }
    }

    // MARK: - Expression Transform Statement Helpers

    /// Transforms expressions in an if statement including elseif and else branches.
    ///
    /// - Parameters:
    ///   - ifStmt: The if statement to transform
    ///   - transform: The expression transformation function
    /// - Returns: The transformed statement
    public static func transformExpressionsInIfStatement(
        _ ifStmt: IfStatement,
        _ transform: @escaping @Sendable (Expression) -> Expression
    ) -> Statement {
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
    }

    /// Transforms expressions in a for statement (range or forEach).
    ///
    /// - Parameters:
    ///   - forStmt: The for statement to transform
    ///   - transform: The expression transformation function
    /// - Returns: The transformed statement
    public static func transformExpressionsInForStatement(
        _ forStmt: ForStatement,
        _ transform: @escaping @Sendable (Expression) -> Expression
    ) -> Statement {
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
    }

    /// Transforms expressions in an assignment statement.
    ///
    /// - Parameters:
    ///   - assignment: The assignment to transform
    ///   - transform: The expression transformation function
    /// - Returns: The transformed statement
    public static func transformExpressionsInAssignment(
        _ assignment: Assignment,
        _ transform: @escaping @Sendable (Expression) -> Expression
    ) -> Statement {
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
        case .fieldAccess(let fieldAccess, let expr):
            let transformedObject = transformExpression(fieldAccess.object, transform)
            let transformedExpr = transformExpression(expr, transform)
            return .assignment(.fieldAccess(
                Assignment.FieldAccess(object: transformedObject, field: fieldAccess.field),
                transformedExpr
            ))
        }
    }

    /// Transforms expressions in a function declaration.
    ///
    /// - Parameters:
    ///   - funcDecl: The function declaration to transform
    ///   - transform: The expression transformation function
    /// - Returns: The transformed statement
    public static func transformExpressionsInFunctionDecl(
        _ funcDecl: FunctionDeclaration,
        _ transform: @escaping @Sendable (Expression) -> Expression
    ) -> Statement {
        let transformedBody = funcDecl.body.map { transformExpressions(in: $0, transform) }
        let transformedLocalVars = transformLocalVariables(funcDecl.localVariables, transform)
        return .functionDeclaration(FunctionDeclaration(
            name: funcDecl.name,
            parameters: funcDecl.parameters,
            returnType: funcDecl.returnType,
            localVariables: transformedLocalVars,
            body: transformedBody
        ))
    }

    /// Transforms expressions in a procedure declaration.
    ///
    /// - Parameters:
    ///   - procDecl: The procedure declaration to transform
    ///   - transform: The expression transformation function
    /// - Returns: The transformed statement
    public static func transformExpressionsInProcedureDecl(
        _ procDecl: ProcedureDeclaration,
        _ transform: @escaping @Sendable (Expression) -> Expression
    ) -> Statement {
        let transformedBody = procDecl.body.map { transformExpressions(in: $0, transform) }
        let transformedLocalVars = transformLocalVariables(procDecl.localVariables, transform)
        return .procedureDeclaration(ProcedureDeclaration(
            name: procDecl.name,
            parameters: procDecl.parameters,
            localVariables: transformedLocalVars,
            body: transformedBody
        ))
    }

    /// Transforms local variable declarations by applying a transformation to their initial values.
    ///
    /// - Parameters:
    ///   - localVars: The local variable declarations to transform
    ///   - transform: The expression transformation function
    /// - Returns: The transformed variable declarations
    public static func transformLocalVariables(
        _ localVars: [VariableDeclaration],
        _ transform: @escaping @Sendable (Expression) -> Expression
    ) -> [VariableDeclaration] {
        localVars.map { varDecl in
            VariableDeclaration(
                name: varDecl.name,
                type: varDecl.type,
                initialValue: varDecl.initialValue.map { transformExpression($0, transform) }
            )
        }
    }
}
