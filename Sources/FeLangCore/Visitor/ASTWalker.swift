import Foundation

/// Utility for automatically traversing and transforming AST nodes.
/// Provides recursive traversal with visitor pattern integration.
public struct ASTWalker: Sendable {
    
    // MARK: - Expression Walking
    
    /// Recursively walks an expression tree, applying transformations via visitor.
    /// - Parameters:
    ///   - expression: The expression to walk
    ///   - visitor: The visitor to apply at each node
    /// - Returns: The transformed expression
    public static func walk<Result>(_ expression: Expression, 
                                   with visitor: ExpressionVisitor<Result>) -> Result {
        return visitor.visit(expression)
    }
    
    /// Recursively walks an expression tree and transforms all sub-expressions.
    /// - Parameters:
    ///   - expression: The expression to transform
    ///   - transformer: A closure that transforms expressions
    /// - Returns: The transformed expression
    public static func transformExpression(
        _ expression: Expression,
        transformer: @Sendable (Expression) -> Expression
    ) -> Expression {
        let transformedExpression: Expression
        
        switch expression {
        case .literal:
            // Literals have no sub-expressions
            transformedExpression = expression
            
        case .identifier:
            // Identifiers have no sub-expressions
            transformedExpression = expression
            
        case .binary(let op, let left, let right):
            let transformedLeft = transformExpression(left, transformer: transformer)
            let transformedRight = transformExpression(right, transformer: transformer)
            transformedExpression = .binary(op, transformedLeft, transformedRight)
            
        case .unary(let op, let expr):
            let transformedExpr = transformExpression(expr, transformer: transformer)
            transformedExpression = .unary(op, transformedExpr)
            
        case .arrayAccess(let array, let index):
            let transformedArray = transformExpression(array, transformer: transformer)
            let transformedIndex = transformExpression(index, transformer: transformer)
            transformedExpression = .arrayAccess(transformedArray, transformedIndex)
            
        case .fieldAccess(let object, let field):
            let transformedObject = transformExpression(object, transformer: transformer)
            transformedExpression = .fieldAccess(transformedObject, field)
            
        case .functionCall(let name, let args):
            let transformedArgs = args.map { transformExpression($0, transformer: transformer) }
            transformedExpression = .functionCall(name, transformedArgs)
        }
        
        return transformer(transformedExpression)
    }
    
    // MARK: - Statement Walking
    
    /// Recursively walks a statement tree, applying transformations via visitor.
    /// - Parameters:
    ///   - statement: The statement to walk
    ///   - visitor: The visitor to apply at each node
    /// - Returns: The result from the visitor
    public static func walk<Result>(_ statement: Statement, 
                                   with visitor: StatementVisitor<Result>) -> Result {
        return visitor.visit(statement)
    }
    
    /// Recursively walks a statement tree and transforms all sub-statements and expressions.
    /// - Parameters:
    ///   - statement: The statement to transform
    ///   - statementTransformer: A closure that transforms statements
    ///   - expressionTransformer: A closure that transforms expressions
    /// - Returns: The transformed statement
    public static func transformStatement(
        _ statement: Statement,
        statementTransformer: @Sendable (Statement) -> Statement = { $0 },
        expressionTransformer: @Sendable (Expression) -> Expression = { $0 }
    ) -> Statement {
        let transformedStatement: Statement
        
        switch statement {
        case .ifStatement(let ifStmt):
            let transformedCondition = transformExpression(ifStmt.condition, transformer: expressionTransformer)
            let transformedThenBody = ifStmt.thenBody.map { 
                transformStatement($0, statementTransformer: statementTransformer, expressionTransformer: expressionTransformer)
            }
            let transformedElseIfs = ifStmt.elseIfs.map { elseIf in
                let transformedCondition = transformExpression(elseIf.condition, transformer: expressionTransformer)
                let transformedBody = elseIf.body.map {
                    transformStatement($0, statementTransformer: statementTransformer, expressionTransformer: expressionTransformer)
                }
                return IfStatement.ElseIf(condition: transformedCondition, body: transformedBody)
            }
            let transformedElseBody = ifStmt.elseBody?.map {
                transformStatement($0, statementTransformer: statementTransformer, expressionTransformer: expressionTransformer)
            }
            let newIfStmt = IfStatement(
                condition: transformedCondition,
                thenBody: transformedThenBody,
                elseIfs: transformedElseIfs,
                elseBody: transformedElseBody
            )
            transformedStatement = .ifStatement(newIfStmt)
            
        case .whileStatement(let whileStmt):
            let transformedCondition = transformExpression(whileStmt.condition, transformer: expressionTransformer)
            let transformedBody = whileStmt.body.map {
                transformStatement($0, statementTransformer: statementTransformer, expressionTransformer: expressionTransformer)
            }
            let newWhileStmt = WhileStatement(condition: transformedCondition, body: transformedBody)
            transformedStatement = .whileStatement(newWhileStmt)
            
        case .forStatement(let forStmt):
            switch forStmt {
            case .range(let rangeFor):
                let transformedStart = transformExpression(rangeFor.start, transformer: expressionTransformer)
                let transformedEnd = transformExpression(rangeFor.end, transformer: expressionTransformer)
                let transformedStep = rangeFor.step.map { transformExpression($0, transformer: expressionTransformer) }
                let transformedBody = rangeFor.body.map {
                    transformStatement($0, statementTransformer: statementTransformer, expressionTransformer: expressionTransformer)
                }
                let newRangeFor = ForStatement.RangeFor(
                    variable: rangeFor.variable,
                    start: transformedStart,
                    end: transformedEnd,
                    step: transformedStep,
                    body: transformedBody
                )
                transformedStatement = .forStatement(.range(newRangeFor))
                
            case .forEach(let forEach):
                let transformedIterable = transformExpression(forEach.iterable, transformer: expressionTransformer)
                let transformedBody = forEach.body.map {
                    transformStatement($0, statementTransformer: statementTransformer, expressionTransformer: expressionTransformer)
                }
                let newForEach = ForStatement.ForEachLoop(
                    variable: forEach.variable,
                    iterable: transformedIterable,
                    body: transformedBody
                )
                transformedStatement = .forStatement(.forEach(newForEach))
            }
            
        case .assignment(let assignment):
            switch assignment {
            case .variable(let name, let expr):
                let transformedExpr = transformExpression(expr, transformer: expressionTransformer)
                transformedStatement = .assignment(.variable(name, transformedExpr))
                
            case .arrayElement(let arrayAccess, let expr):
                let transformedArray = transformExpression(arrayAccess.array, transformer: expressionTransformer)
                let transformedIndex = transformExpression(arrayAccess.index, transformer: expressionTransformer)
                let transformedExpr = transformExpression(expr, transformer: expressionTransformer)
                let newArrayAccess = Assignment.ArrayAccess(array: transformedArray, index: transformedIndex)
                transformedStatement = .assignment(.arrayElement(newArrayAccess, transformedExpr))
            }
            
        case .variableDeclaration(let varDecl):
            let transformedInitialValue = varDecl.initialValue.map { transformExpression($0, transformer: expressionTransformer) }
            let newVarDecl = VariableDeclaration(
                name: varDecl.name,
                type: varDecl.type,
                initialValue: transformedInitialValue
            )
            transformedStatement = .variableDeclaration(newVarDecl)
            
        case .constantDeclaration(let constDecl):
            let transformedInitialValue = transformExpression(constDecl.initialValue, transformer: expressionTransformer)
            let newConstDecl = ConstantDeclaration(
                name: constDecl.name,
                type: constDecl.type,
                initialValue: transformedInitialValue
            )
            transformedStatement = .constantDeclaration(newConstDecl)
            
        case .functionDeclaration(let funcDecl):
            let transformedLocalVars = funcDecl.localVariables.map { varDecl in
                let transformedInitialValue = varDecl.initialValue.map { transformExpression($0, transformer: expressionTransformer) }
                return VariableDeclaration(
                    name: varDecl.name,
                    type: varDecl.type,
                    initialValue: transformedInitialValue
                )
            }
            let transformedBody = funcDecl.body.map {
                transformStatement($0, statementTransformer: statementTransformer, expressionTransformer: expressionTransformer)
            }
            let newFuncDecl = FunctionDeclaration(
                name: funcDecl.name,
                parameters: funcDecl.parameters,
                returnType: funcDecl.returnType,
                localVariables: transformedLocalVars,
                body: transformedBody
            )
            transformedStatement = .functionDeclaration(newFuncDecl)
            
        case .procedureDeclaration(let procDecl):
            let transformedLocalVars = procDecl.localVariables.map { varDecl in
                let transformedInitialValue = varDecl.initialValue.map { transformExpression($0, transformer: expressionTransformer) }
                return VariableDeclaration(
                    name: varDecl.name,
                    type: varDecl.type,
                    initialValue: transformedInitialValue
                )
            }
            let transformedBody = procDecl.body.map {
                transformStatement($0, statementTransformer: statementTransformer, expressionTransformer: expressionTransformer)
            }
            let newProcDecl = ProcedureDeclaration(
                name: procDecl.name,
                parameters: procDecl.parameters,
                localVariables: transformedLocalVars,
                body: transformedBody
            )
            transformedStatement = .procedureDeclaration(newProcDecl)
            
        case .returnStatement(let returnStmt):
            let transformedExpression = returnStmt.expression.map { transformExpression($0, transformer: expressionTransformer) }
            let newReturnStmt = ReturnStatement(expression: transformedExpression)
            transformedStatement = .returnStatement(newReturnStmt)
            
        case .expressionStatement(let expr):
            let transformedExpr = transformExpression(expr, transformer: expressionTransformer)
            transformedStatement = .expressionStatement(transformedExpr)
            
        case .breakStatement:
            transformedStatement = statement
            
        case .block(let statements):
            let transformedStatements = statements.map {
                transformStatement($0, statementTransformer: statementTransformer, expressionTransformer: expressionTransformer)
            }
            transformedStatement = .block(transformedStatements)
        }
        
        return statementTransformer(transformedStatement)
    }
    
    // MARK: - Traversal Helpers
    
    /// Collects all expressions from a statement tree using a visitor.
    /// - Parameters:
    ///   - statement: The statement to traverse
    ///   - collector: A visitor that collects expressions
    /// - Returns: Array of collected results
    public static func collectExpressions<Result: Sendable>(
        from statement: Statement,
        using collector: ExpressionVisitor<Result>
    ) -> [Result] {
        func collectFromStatement(_ stmt: Statement) -> [Result] {
            switch stmt {
            case .ifStatement(let ifStmt):
                var results: [Result] = []
                results.append(collector.visit(ifStmt.condition))
                for elseIf in ifStmt.elseIfs {
                    results.append(collector.visit(elseIf.condition))
                    for bodyStmt in elseIf.body {
                        results.append(contentsOf: collectFromStatement(bodyStmt))
                    }
                }
                for thenStmt in ifStmt.thenBody {
                    results.append(contentsOf: collectFromStatement(thenStmt))
                }
                if let elseBody = ifStmt.elseBody {
                    for elseStmt in elseBody {
                        results.append(contentsOf: collectFromStatement(elseStmt))
                    }
                }
                return results
                
            case .whileStatement(let whileStmt):
                var results: [Result] = []
                results.append(collector.visit(whileStmt.condition))
                for bodyStmt in whileStmt.body {
                    results.append(contentsOf: collectFromStatement(bodyStmt))
                }
                return results
                
            case .forStatement(let forStmt):
                var results: [Result] = []
                switch forStmt {
                case .range(let rangeFor):
                    results.append(collector.visit(rangeFor.start))
                    results.append(collector.visit(rangeFor.end))
                    if let step = rangeFor.step {
                        results.append(collector.visit(step))
                    }
                    for bodyStmt in rangeFor.body {
                        results.append(contentsOf: collectFromStatement(bodyStmt))
                    }
                case .forEach(let forEach):
                    results.append(collector.visit(forEach.iterable))
                    for bodyStmt in forEach.body {
                        results.append(contentsOf: collectFromStatement(bodyStmt))
                    }
                }
                return results
                
            case .assignment(let assignment):
                switch assignment {
                case .variable(_, let expr):
                    return [collector.visit(expr)]
                case .arrayElement(let arrayAccess, let expr):
                    return [
                        collector.visit(arrayAccess.array),
                        collector.visit(arrayAccess.index),
                        collector.visit(expr)
                    ]
                }
                
            case .variableDeclaration(let varDecl):
                if let initialValue = varDecl.initialValue {
                    return [collector.visit(initialValue)]
                }
                return []
                
            case .constantDeclaration(let constDecl):
                return [collector.visit(constDecl.initialValue)]
                
            case .functionDeclaration(let funcDecl):
                var results: [Result] = []
                for varDecl in funcDecl.localVariables {
                    if let initialValue = varDecl.initialValue {
                        results.append(collector.visit(initialValue))
                    }
                }
                for bodyStmt in funcDecl.body {
                    results.append(contentsOf: collectFromStatement(bodyStmt))
                }
                return results
                
            case .procedureDeclaration(let procDecl):
                var results: [Result] = []
                for varDecl in procDecl.localVariables {
                    if let initialValue = varDecl.initialValue {
                        results.append(collector.visit(initialValue))
                    }
                }
                for bodyStmt in procDecl.body {
                    results.append(contentsOf: collectFromStatement(bodyStmt))
                }
                return results
                
            case .returnStatement(let returnStmt):
                if let expression = returnStmt.expression {
                    return [collector.visit(expression)]
                }
                return []
                
            case .expressionStatement(let expr):
                return [collector.visit(expr)]
                
            case .breakStatement:
                return []
                
            case .block(let statements):
                var results: [Result] = []
                for stmt in statements {
                    results.append(contentsOf: collectFromStatement(stmt))
                }
                return results
            }
        }
        
        return collectFromStatement(statement)
    }
}