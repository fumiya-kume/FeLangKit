import Foundation

/// Utilities for recursive AST traversal and transformation.
/// Provides both depth-first and breadth-first traversal strategies.
public struct ASTWalker {
    
    // MARK: - Tree Walking
    
    /// Performs a depth-first traversal of an Expression tree, visiting each node.
    public static func walkExpression<Result>(
        _ expression: Expression,
        visitor: ExpressionVisitor<Result>
    ) -> [Result] {
        var results: [Result] = []
        
        func visit(_ expr: Expression) {
            results.append(visitor.visit(expr))
            
            // Recursively visit children
            switch expr {
            case .binary(_, let left, let right):
                visit(left)
                visit(right)
            case .unary(_, let subExpr):
                visit(subExpr)
            case .arrayAccess(let array, let index):
                visit(array)
                visit(index)
            case .fieldAccess(let object, _):
                visit(object)
            case .functionCall(_, let args):
                args.forEach { visit($0) }
            case .literal, .identifier:
                // No children to visit
                break
            }
        }
        
        visit(expression)
        return results
    }
    
    /// Performs a depth-first traversal of a Statement tree, visiting each node.
    public static func walkStatement<Result>(
        _ statement: Statement,
        visitor: StatementVisitor<Result>
    ) -> [Result] {
        var results: [Result] = []
        
        func visit(_ stmt: Statement) {
            results.append(visitor.visit(stmt))
            
            // Recursively visit children
            switch stmt {
            case .ifStatement(let ifStmt):
                ifStmt.thenBody.forEach { visit($0) }
                ifStmt.elseIfs.forEach { elseIf in
                    elseIf.body.forEach { visit($0) }
                }
                ifStmt.elseBody?.forEach { visit($0) }
                
            case .whileStatement(let whileStmt):
                whileStmt.body.forEach { visit($0) }
                
            case .forStatement(let forStmt):
                switch forStmt {
                case .range(let rangeFor):
                    rangeFor.body.forEach { visit($0) }
                case .forEach(let forEach):
                    forEach.body.forEach { visit($0) }
                }
                
            case .functionDeclaration(let funcDecl):
                funcDecl.localVariables.forEach { 
                    visit(.variableDeclaration($0))
                }
                funcDecl.body.forEach { visit($0) }
                
            case .procedureDeclaration(let procDecl):
                procDecl.localVariables.forEach { 
                    visit(.variableDeclaration($0))
                }
                procDecl.body.forEach { visit($0) }
                
            case .block(let statements):
                statements.forEach { visit($0) }
                
            case .assignment, .variableDeclaration, .constantDeclaration,
                 .returnStatement, .expressionStatement, .breakStatement:
                // No child statements to visit
                break
            }
        }
        
        visit(statement)
        return results
    }
    
    // MARK: - Tree Transformation
    
    /// Transforms an Expression tree by applying a transformation visitor.
    public static func transformExpression(
        _ expression: Expression,
        transformer: ExpressionTransformer
    ) -> Expression {
        return transformer.transform(expression)
    }
    
    /// Transforms a Statement tree by applying a transformation visitor.
    public static func transformStatement(
        _ statement: Statement,
        transformer: StatementTransformer
    ) -> Statement {
        return transformer.transform(statement)
    }
    
    // MARK: - Collection Operations
    
    /// Collects all nodes of a specific type from an Expression tree.
    public static func collectExpressions<T>(
        from expression: Expression,
        ofType type: T.Type,
        where predicate: @escaping (Expression) -> Bool = { _ in true }
    ) -> [Expression] {
        var collected: [Expression] = []
        
        let collector = ExpressionVisitor<Void>(
            visitLiteral: { _ in
                if predicate(.literal($0)) {
                    collected.append(.literal($0))
                }
            },
            visitIdentifier: { name in
                let expr = Expression.identifier(name)
                if predicate(expr) {
                    collected.append(expr)
                }
            },
            visitBinary: { op, left, right in
                let expr = Expression.binary(op, left, right)
                if predicate(expr) {
                    collected.append(expr)
                }
                _ = collector.visit(left)
                _ = collector.visit(right)
            },
            visitUnary: { op, subExpr in
                let expr = Expression.unary(op, subExpr)
                if predicate(expr) {
                    collected.append(expr)
                }
                _ = collector.visit(subExpr)
            },
            visitArrayAccess: { array, index in
                let expr = Expression.arrayAccess(array, index)
                if predicate(expr) {
                    collected.append(expr)
                }
                _ = collector.visit(array)
                _ = collector.visit(index)
            },
            visitFieldAccess: { object, field in
                let expr = Expression.fieldAccess(object, field)
                if predicate(expr) {
                    collected.append(expr)
                }
                _ = collector.visit(object)
            },
            visitFunctionCall: { name, args in
                let expr = Expression.functionCall(name, args)
                if predicate(expr) {
                    collected.append(expr)
                }
                args.forEach { _ = collector.visit($0) }
            }
        )
        
        _ = collector.visit(expression)
        return collected
    }
    
    /// Collects all nodes of a specific type from a Statement tree.
    public static func collectStatements<T>(
        from statement: Statement,
        ofType type: T.Type,
        where predicate: @escaping (Statement) -> Bool = { _ in true }
    ) -> [Statement] {
        var collected: [Statement] = []
        
        let collector = StatementVisitor<Void>(
            visitIfStatement: { ifStmt in
                let stmt = Statement.ifStatement(ifStmt)
                if predicate(stmt) {
                    collected.append(stmt)
                }
                ifStmt.thenBody.forEach { _ = collector.visit($0) }
                ifStmt.elseIfs.forEach { elseIf in
                    elseIf.body.forEach { _ = collector.visit($0) }
                }
                ifStmt.elseBody?.forEach { _ = collector.visit($0) }
            },
            visitWhileStatement: { whileStmt in
                let stmt = Statement.whileStatement(whileStmt)
                if predicate(stmt) {
                    collected.append(stmt)
                }
                whileStmt.body.forEach { _ = collector.visit($0) }
            },
            visitForStatement: { forStmt in
                let stmt = Statement.forStatement(forStmt)
                if predicate(stmt) {
                    collected.append(stmt)
                }
                switch forStmt {
                case .range(let rangeFor):
                    rangeFor.body.forEach { _ = collector.visit($0) }
                case .forEach(let forEach):
                    forEach.body.forEach { _ = collector.visit($0) }
                }
            },
            visitAssignment: { assignment in
                let stmt = Statement.assignment(assignment)
                if predicate(stmt) {
                    collected.append(stmt)
                }
            },
            visitVariableDeclaration: { varDecl in
                let stmt = Statement.variableDeclaration(varDecl)
                if predicate(stmt) {
                    collected.append(stmt)
                }
            },
            visitConstantDeclaration: { constDecl in
                let stmt = Statement.constantDeclaration(constDecl)
                if predicate(stmt) {
                    collected.append(stmt)
                }
            },
            visitFunctionDeclaration: { funcDecl in
                let stmt = Statement.functionDeclaration(funcDecl)
                if predicate(stmt) {
                    collected.append(stmt)
                }
                funcDecl.localVariables.forEach { 
                    _ = collector.visit(.variableDeclaration($0))
                }
                funcDecl.body.forEach { _ = collector.visit($0) }
            },
            visitProcedureDeclaration: { procDecl in
                let stmt = Statement.procedureDeclaration(procDecl)
                if predicate(stmt) {
                    collected.append(stmt)
                }
                procDecl.localVariables.forEach { 
                    _ = collector.visit(.variableDeclaration($0))
                }
                procDecl.body.forEach { _ = collector.visit($0) }
            },
            visitReturnStatement: { returnStmt in
                let stmt = Statement.returnStatement(returnStmt)
                if predicate(stmt) {
                    collected.append(stmt)
                }
            },
            visitExpressionStatement: { expr in
                let stmt = Statement.expressionStatement(expr)
                if predicate(stmt) {
                    collected.append(stmt)
                }
            },
            visitBreakStatement: {
                let stmt = Statement.breakStatement
                if predicate(stmt) {
                    collected.append(stmt)
                }
            },
            visitBlock: { statements in
                let stmt = Statement.block(statements)
                if predicate(stmt) {
                    collected.append(stmt)
                }
                statements.forEach { _ = collector.visit($0) }
            }
        )
        
        _ = collector.visit(statement)
        return collected
    }
}

// MARK: - Transformation Visitors

/// A specialized visitor for transforming Expression trees immutably.
public struct ExpressionTransformer: @unchecked Sendable {
    
    private let transformLiteral: @Sendable (Literal) -> Expression
    private let transformIdentifier: @Sendable (String) -> Expression
    private let transformBinary: @Sendable (BinaryOperator, Expression, Expression) -> Expression
    private let transformUnary: @Sendable (UnaryOperator, Expression) -> Expression
    private let transformArrayAccess: @Sendable (Expression, Expression) -> Expression
    private let transformFieldAccess: @Sendable (Expression, String) -> Expression
    private let transformFunctionCall: @Sendable (String, [Expression]) -> Expression
    
    /// Creates an ExpressionTransformer with custom transformation functions.
    public init(
        transformLiteral: @escaping @Sendable (Literal) -> Expression = { .literal($0) },
        transformIdentifier: @escaping @Sendable (String) -> Expression = { .identifier($0) },
        transformBinary: @escaping @Sendable (BinaryOperator, Expression, Expression) -> Expression = { op, left, right in
            .binary(op, left, right)
        },
        transformUnary: @escaping @Sendable (UnaryOperator, Expression) -> Expression = { op, expr in
            .unary(op, expr)
        },
        transformArrayAccess: @escaping @Sendable (Expression, Expression) -> Expression = { array, index in
            .arrayAccess(array, index)
        },
        transformFieldAccess: @escaping @Sendable (Expression, String) -> Expression = { object, field in
            .fieldAccess(object, field)
        },
        transformFunctionCall: @escaping @Sendable (String, [Expression]) -> Expression = { name, args in
            .functionCall(name, args)
        }
    ) {
        self.transformLiteral = transformLiteral
        self.transformIdentifier = transformIdentifier
        self.transformBinary = transformBinary
        self.transformUnary = transformUnary
        self.transformArrayAccess = transformArrayAccess
        self.transformFieldAccess = transformFieldAccess
        self.transformFunctionCall = transformFunctionCall
    }
    
    /// Transforms an Expression by recursively applying transformation functions.
    public func transform(_ expression: Expression) -> Expression {
        switch expression {
        case .literal(let literal):
            return transformLiteral(literal)
        case .identifier(let name):
            return transformIdentifier(name)
        case .binary(let op, let left, let right):
            let transformedLeft = transform(left)
            let transformedRight = transform(right)
            return transformBinary(op, transformedLeft, transformedRight)
        case .unary(let op, let expr):
            let transformedExpr = transform(expr)
            return transformUnary(op, transformedExpr)
        case .arrayAccess(let array, let index):
            let transformedArray = transform(array)
            let transformedIndex = transform(index)
            return transformArrayAccess(transformedArray, transformedIndex)
        case .fieldAccess(let object, let field):
            let transformedObject = transform(object)
            return transformFieldAccess(transformedObject, field)
        case .functionCall(let name, let args):
            let transformedArgs = args.map { transform($0) }
            return transformFunctionCall(name, transformedArgs)
        }
    }
}

/// A specialized visitor for transforming Statement trees immutably.
public struct StatementTransformer: @unchecked Sendable {
    
    private let transformIfStatement: @Sendable (IfStatement) -> Statement
    private let transformWhileStatement: @Sendable (WhileStatement) -> Statement
    private let transformForStatement: @Sendable (ForStatement) -> Statement
    private let transformAssignment: @Sendable (Assignment) -> Statement
    private let transformVariableDeclaration: @Sendable (VariableDeclaration) -> Statement
    private let transformConstantDeclaration: @Sendable (ConstantDeclaration) -> Statement
    private let transformFunctionDeclaration: @Sendable (FunctionDeclaration) -> Statement
    private let transformProcedureDeclaration: @Sendable (ProcedureDeclaration) -> Statement
    private let transformReturnStatement: @Sendable (ReturnStatement) -> Statement
    private let transformExpressionStatement: @Sendable (Expression) -> Statement
    private let transformBreakStatement: @Sendable () -> Statement
    private let transformBlock: @Sendable ([Statement]) -> Statement
    
    /// Creates a StatementTransformer with custom transformation functions.
    public init(
        transformIfStatement: @escaping @Sendable (IfStatement) -> Statement = { .ifStatement($0) },
        transformWhileStatement: @escaping @Sendable (WhileStatement) -> Statement = { .whileStatement($0) },
        transformForStatement: @escaping @Sendable (ForStatement) -> Statement = { .forStatement($0) },
        transformAssignment: @escaping @Sendable (Assignment) -> Statement = { .assignment($0) },
        transformVariableDeclaration: @escaping @Sendable (VariableDeclaration) -> Statement = { .variableDeclaration($0) },
        transformConstantDeclaration: @escaping @Sendable (ConstantDeclaration) -> Statement = { .constantDeclaration($0) },
        transformFunctionDeclaration: @escaping @Sendable (FunctionDeclaration) -> Statement = { .functionDeclaration($0) },
        transformProcedureDeclaration: @escaping @Sendable (ProcedureDeclaration) -> Statement = { .procedureDeclaration($0) },
        transformReturnStatement: @escaping @Sendable (ReturnStatement) -> Statement = { .returnStatement($0) },
        transformExpressionStatement: @escaping @Sendable (Expression) -> Statement = { .expressionStatement($0) },
        transformBreakStatement: @escaping @Sendable () -> Statement = { .breakStatement },
        transformBlock: @escaping @Sendable ([Statement]) -> Statement = { .block($0) }
    ) {
        self.transformIfStatement = transformIfStatement
        self.transformWhileStatement = transformWhileStatement
        self.transformForStatement = transformForStatement
        self.transformAssignment = transformAssignment
        self.transformVariableDeclaration = transformVariableDeclaration
        self.transformConstantDeclaration = transformConstantDeclaration
        self.transformFunctionDeclaration = transformFunctionDeclaration
        self.transformProcedureDeclaration = transformProcedureDeclaration
        self.transformReturnStatement = transformReturnStatement
        self.transformExpressionStatement = transformExpressionStatement
        self.transformBreakStatement = transformBreakStatement
        self.transformBlock = transformBlock
    }
    
    /// Transforms a Statement by recursively applying transformation functions.
    public func transform(_ statement: Statement) -> Statement {
        switch statement {
        case .ifStatement(let ifStmt):
            let transformedThenBody = ifStmt.thenBody.map { transform($0) }
            let transformedElseIfs = ifStmt.elseIfs.map { elseIf in
                IfStatement.ElseIf(
                    condition: elseIf.condition,
                    body: elseIf.body.map { transform($0) }
                )
            }
            let transformedElseBody = ifStmt.elseBody?.map { transform($0) }
            let transformedIfStmt = IfStatement(
                condition: ifStmt.condition,
                thenBody: transformedThenBody,
                elseIfs: transformedElseIfs,
                elseBody: transformedElseBody
            )
            return transformIfStatement(transformedIfStmt)
        case .whileStatement(let whileStmt):
            let transformedBody = whileStmt.body.map { transform($0) }
            let transformedWhileStmt = WhileStatement(
                condition: whileStmt.condition,
                body: transformedBody
            )
            return transformWhileStatement(transformedWhileStmt)
        case .forStatement(let forStmt):
            let transformedForStmt: ForStatement
            switch forStmt {
            case .range(let rangeFor):
                let transformedBody = rangeFor.body.map { transform($0) }
                transformedForStmt = .range(ForStatement.RangeFor(
                    variable: rangeFor.variable,
                    start: rangeFor.start,
                    end: rangeFor.end,
                    step: rangeFor.step,
                    body: transformedBody
                ))
            case .forEach(let forEach):
                let transformedBody = forEach.body.map { transform($0) }
                transformedForStmt = .forEach(ForStatement.ForEachLoop(
                    variable: forEach.variable,
                    iterable: forEach.iterable,
                    body: transformedBody
                ))
            }
            return transformForStatement(transformedForStmt)
        case .assignment(let assignment):
            return transformAssignment(assignment)
        case .variableDeclaration(let varDecl):
            return transformVariableDeclaration(varDecl)
        case .constantDeclaration(let constDecl):
            return transformConstantDeclaration(constDecl)
        case .functionDeclaration(let funcDecl):
            let transformedBody = funcDecl.body.map { transform($0) }
            let transformedFuncDecl = FunctionDeclaration(
                name: funcDecl.name,
                parameters: funcDecl.parameters,
                returnType: funcDecl.returnType,
                localVariables: funcDecl.localVariables,
                body: transformedBody
            )
            return transformFunctionDeclaration(transformedFuncDecl)
        case .procedureDeclaration(let procDecl):
            let transformedBody = procDecl.body.map { transform($0) }
            let transformedProcDecl = ProcedureDeclaration(
                name: procDecl.name,
                parameters: procDecl.parameters,
                localVariables: procDecl.localVariables,
                body: transformedBody
            )
            return transformProcedureDeclaration(transformedProcDecl)
        case .returnStatement(let returnStmt):
            return transformReturnStatement(returnStmt)
        case .expressionStatement(let expr):
            return transformExpressionStatement(expr)
        case .breakStatement:
            return transformBreakStatement()
        case .block(let statements):
            let transformedStatements = statements.map { transform($0) }
            return transformBlock(transformedStatements)
        }
    }
}