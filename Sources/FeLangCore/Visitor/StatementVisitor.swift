import Foundation

/// A function-based visitor for traversing Statement AST nodes.
/// Uses closure-based dispatch for maximum flexibility and Swift-idiomatic patterns.
public struct StatementVisitor<Result>: @unchecked Sendable {
    
    // MARK: - Visitor Functions
    
    public let visitIfStatement: @Sendable (IfStatement) -> Result
    public let visitWhileStatement: @Sendable (WhileStatement) -> Result
    public let visitForStatement: @Sendable (ForStatement) -> Result
    public let visitAssignment: @Sendable (Assignment) -> Result
    public let visitVariableDeclaration: @Sendable (VariableDeclaration) -> Result
    public let visitConstantDeclaration: @Sendable (ConstantDeclaration) -> Result
    public let visitFunctionDeclaration: @Sendable (FunctionDeclaration) -> Result
    public let visitProcedureDeclaration: @Sendable (ProcedureDeclaration) -> Result
    public let visitReturnStatement: @Sendable (ReturnStatement) -> Result
    public let visitExpressionStatement: @Sendable (Expression) -> Result
    public let visitBreakStatement: @Sendable () -> Result
    public let visitBlock: @Sendable ([Statement]) -> Result
    
    // MARK: - Initialization
    
    /// Creates a new StatementVisitor with the specified closure functions.
    public init(
        visitIfStatement: @escaping @Sendable (IfStatement) -> Result,
        visitWhileStatement: @escaping @Sendable (WhileStatement) -> Result,
        visitForStatement: @escaping @Sendable (ForStatement) -> Result,
        visitAssignment: @escaping @Sendable (Assignment) -> Result,
        visitVariableDeclaration: @escaping @Sendable (VariableDeclaration) -> Result,
        visitConstantDeclaration: @escaping @Sendable (ConstantDeclaration) -> Result,
        visitFunctionDeclaration: @escaping @Sendable (FunctionDeclaration) -> Result,
        visitProcedureDeclaration: @escaping @Sendable (ProcedureDeclaration) -> Result,
        visitReturnStatement: @escaping @Sendable (ReturnStatement) -> Result,
        visitExpressionStatement: @escaping @Sendable (Expression) -> Result,
        visitBreakStatement: @escaping @Sendable () -> Result,
        visitBlock: @escaping @Sendable ([Statement]) -> Result
    ) {
        self.visitIfStatement = visitIfStatement
        self.visitWhileStatement = visitWhileStatement
        self.visitForStatement = visitForStatement
        self.visitAssignment = visitAssignment
        self.visitVariableDeclaration = visitVariableDeclaration
        self.visitConstantDeclaration = visitConstantDeclaration
        self.visitFunctionDeclaration = visitFunctionDeclaration
        self.visitProcedureDeclaration = visitProcedureDeclaration
        self.visitReturnStatement = visitReturnStatement
        self.visitExpressionStatement = visitExpressionStatement
        self.visitBreakStatement = visitBreakStatement
        self.visitBlock = visitBlock
    }
    
    // MARK: - Dispatch
    
    /// Visits a Statement node by dispatching to the appropriate closure.
    public func visit(_ statement: Statement) -> Result {
        switch statement {
        case .ifStatement(let ifStmt):
            return visitIfStatement(ifStmt)
        case .whileStatement(let whileStmt):
            return visitWhileStatement(whileStmt)
        case .forStatement(let forStmt):
            return visitForStatement(forStmt)
        case .assignment(let assignment):
            return visitAssignment(assignment)
        case .variableDeclaration(let varDecl):
            return visitVariableDeclaration(varDecl)
        case .constantDeclaration(let constDecl):
            return visitConstantDeclaration(constDecl)
        case .functionDeclaration(let funcDecl):
            return visitFunctionDeclaration(funcDecl)
        case .procedureDeclaration(let procDecl):
            return visitProcedureDeclaration(procDecl)
        case .returnStatement(let returnStmt):
            return visitReturnStatement(returnStmt)
        case .expressionStatement(let expr):
            return visitExpressionStatement(expr)
        case .breakStatement:
            return visitBreakStatement()
        case .block(let statements):
            return visitBlock(statements)
        }
    }
}

// MARK: - Built-in Visitors

extension StatementVisitor {
    
    /// A debug visitor that produces a string representation of Statement nodes.
    public static var debug: StatementVisitor<String> {
        return StatementVisitor<String>(
            visitIfStatement: { ifStmt in
                let conditionStr = ExpressionVisitor.debug.visit(ifStmt.condition)
                let thenBodyStr = ifStmt.thenBody.map { StatementVisitor.debug.visit($0) }.joined(separator: "; ")
                let elseIfsStr = ifStmt.elseIfs.map { elseIf in
                    let condStr = ExpressionVisitor.debug.visit(elseIf.condition)
                    let bodyStr = elseIf.body.map { StatementVisitor.debug.visit($0) }.joined(separator: "; ")
                    return "ElseIf(\(condStr), [\(bodyStr)])"
                }.joined(separator: ", ")
                let elseBodyStr = ifStmt.elseBody?.map { StatementVisitor.debug.visit($0) }.joined(separator: "; ") ?? "nil"
                return "IfStatement(\(conditionStr), [\(thenBodyStr)], [\(elseIfsStr)], \(elseBodyStr))"
            },
            visitWhileStatement: { whileStmt in
                let conditionStr = ExpressionVisitor.debug.visit(whileStmt.condition)
                let bodyStr = whileStmt.body.map { StatementVisitor.debug.visit($0) }.joined(separator: "; ")
                return "WhileStatement(\(conditionStr), [\(bodyStr)])"
            },
            visitForStatement: { forStmt in
                switch forStmt {
                case .range(let rangeFor):
                    let startStr = ExpressionVisitor.debug.visit(rangeFor.start)
                    let endStr = ExpressionVisitor.debug.visit(rangeFor.end)
                    let stepStr = rangeFor.step.map { ExpressionVisitor.debug.visit($0) } ?? "nil"
                    let bodyStr = rangeFor.body.map { StatementVisitor.debug.visit($0) }.joined(separator: "; ")
                    return "ForStatement.range(\(rangeFor.variable), \(startStr), \(endStr), \(stepStr), [\(bodyStr)])"
                case .forEach(let forEach):
                    let iterableStr = ExpressionVisitor.debug.visit(forEach.iterable)
                    let bodyStr = forEach.body.map { StatementVisitor.debug.visit($0) }.joined(separator: "; ")
                    return "ForStatement.forEach(\(forEach.variable), \(iterableStr), [\(bodyStr)])"
                }
            },
            visitAssignment: { assignment in
                switch assignment {
                case .variable(let name, let expr):
                    let exprStr = ExpressionVisitor.debug.visit(expr)
                    return "Assignment.variable(\(name), \(exprStr))"
                case .arrayElement(let arrayAccess, let expr):
                    let arrayStr = ExpressionVisitor.debug.visit(arrayAccess.array)
                    let indexStr = ExpressionVisitor.debug.visit(arrayAccess.index)
                    let exprStr = ExpressionVisitor.debug.visit(expr)
                    return "Assignment.arrayElement(ArrayAccess(\(arrayStr), \(indexStr)), \(exprStr))"
                }
            },
            visitVariableDeclaration: { varDecl in
                let typeStr = debugDataType(varDecl.type)
                let initialValueStr = varDecl.initialValue.map { ExpressionVisitor.debug.visit($0) } ?? "nil"
                return "VariableDeclaration(\(varDecl.name), \(typeStr), \(initialValueStr))"
            },
            visitConstantDeclaration: { constDecl in
                let typeStr = debugDataType(constDecl.type)
                let initialValueStr = ExpressionVisitor.debug.visit(constDecl.initialValue)
                return "ConstantDeclaration(\(constDecl.name), \(typeStr), \(initialValueStr))"
            },
            visitFunctionDeclaration: { funcDecl in
                let paramsStr = funcDecl.parameters.map { "\($0.name): \(debugDataType($0.type))" }.joined(separator: ", ")
                let returnTypeStr = funcDecl.returnType.map { debugDataType($0) } ?? "nil"
                let localVarsStr = funcDecl.localVariables.map { StatementVisitor.debug.visit(.variableDeclaration($0)) }.joined(separator: ", ")
                let bodyStr = funcDecl.body.map { StatementVisitor.debug.visit($0) }.joined(separator: "; ")
                return "FunctionDeclaration(\(funcDecl.name), [\(paramsStr)], \(returnTypeStr), [\(localVarsStr)], [\(bodyStr)])"
            },
            visitProcedureDeclaration: { procDecl in
                let paramsStr = procDecl.parameters.map { "\($0.name): \(debugDataType($0.type))" }.joined(separator: ", ")
                let localVarsStr = procDecl.localVariables.map { StatementVisitor.debug.visit(.variableDeclaration($0)) }.joined(separator: ", ")
                let bodyStr = procDecl.body.map { StatementVisitor.debug.visit($0) }.joined(separator: "; ")
                return "ProcedureDeclaration(\(procDecl.name), [\(paramsStr)], [\(localVarsStr)], [\(bodyStr)])"
            },
            visitReturnStatement: { returnStmt in
                let exprStr = returnStmt.expression.map { ExpressionVisitor.debug.visit($0) } ?? "nil"
                return "ReturnStatement(\(exprStr))"
            },
            visitExpressionStatement: { expr in
                let exprStr = ExpressionVisitor.debug.visit(expr)
                return "ExpressionStatement(\(exprStr))"
            },
            visitBreakStatement: {
                return "BreakStatement"
            },
            visitBlock: { statements in
                let statementsStr = statements.map { StatementVisitor.debug.visit($0) }.joined(separator: "; ")
                return "Block([\(statementsStr)])"
            }
        )
    }
}

// MARK: - Helper Functions

private func debugDataType(_ dataType: DataType) -> String {
    switch dataType {
    case .integer:
        return "DataType.integer"
    case .real:
        return "DataType.real"
    case .character:
        return "DataType.character"
    case .string:
        return "DataType.string"
    case .boolean:
        return "DataType.boolean"
    case .array(let elementType):
        return "DataType.array(\(debugDataType(elementType)))"
    case .record(let name):
        return "DataType.record(\(name))"
    }
}

// MARK: - Convenience Factory Methods

extension StatementVisitor {
    
    /// Creates a visitor that counts the number of nodes of a specific type.
    public static func counter<T>(for nodeType: T.Type, matching predicate: @escaping @Sendable (Statement) -> Bool) -> StatementVisitor<Int> {
        return StatementVisitor<Int>(
            visitIfStatement: { ifStmt in
                let stmt = Statement.ifStatement(ifStmt)
                let selfCount = predicate(stmt) ? 1 : 0
                let thenCount = ifStmt.thenBody.reduce(0) { sum, s in
                    sum + StatementVisitor.counter(for: nodeType, matching: predicate).visit(s)
                }
                let elseIfsCount = ifStmt.elseIfs.reduce(0) { sum, elseIf in
                    sum + elseIf.body.reduce(0) { elseIfSum, s in
                        elseIfSum + StatementVisitor.counter(for: nodeType, matching: predicate).visit(s)
                    }
                }
                let elseCount = ifStmt.elseBody?.reduce(0) { sum, s in
                    sum + StatementVisitor.counter(for: nodeType, matching: predicate).visit(s)
                } ?? 0
                return selfCount + thenCount + elseIfsCount + elseCount
            },
            visitWhileStatement: { whileStmt in
                let stmt = Statement.whileStatement(whileStmt)
                let selfCount = predicate(stmt) ? 1 : 0
                let bodyCount = whileStmt.body.reduce(0) { sum, s in
                    sum + StatementVisitor.counter(for: nodeType, matching: predicate).visit(s)
                }
                return selfCount + bodyCount
            },
            visitForStatement: { forStmt in
                let stmt = Statement.forStatement(forStmt)
                let selfCount = predicate(stmt) ? 1 : 0
                let bodyCount: Int
                switch forStmt {
                case .range(let rangeFor):
                    bodyCount = rangeFor.body.reduce(0) { sum, s in
                        sum + StatementVisitor.counter(for: nodeType, matching: predicate).visit(s)
                    }
                case .forEach(let forEach):
                    bodyCount = forEach.body.reduce(0) { sum, s in
                        sum + StatementVisitor.counter(for: nodeType, matching: predicate).visit(s)
                    }
                }
                return selfCount + bodyCount
            },
            visitAssignment: { assignment in
                let stmt = Statement.assignment(assignment)
                return predicate(stmt) ? 1 : 0
            },
            visitVariableDeclaration: { varDecl in
                let stmt = Statement.variableDeclaration(varDecl)
                return predicate(stmt) ? 1 : 0
            },
            visitConstantDeclaration: { constDecl in
                let stmt = Statement.constantDeclaration(constDecl)
                return predicate(stmt) ? 1 : 0
            },
            visitFunctionDeclaration: { funcDecl in
                let stmt = Statement.functionDeclaration(funcDecl)
                let selfCount = predicate(stmt) ? 1 : 0
                let bodyCount = funcDecl.body.reduce(0) { sum, s in
                    sum + StatementVisitor.counter(for: nodeType, matching: predicate).visit(s)
                }
                return selfCount + bodyCount
            },
            visitProcedureDeclaration: { procDecl in
                let stmt = Statement.procedureDeclaration(procDecl)
                let selfCount = predicate(stmt) ? 1 : 0
                let bodyCount = procDecl.body.reduce(0) { sum, s in
                    sum + StatementVisitor.counter(for: nodeType, matching: predicate).visit(s)
                }
                return selfCount + bodyCount
            },
            visitReturnStatement: { returnStmt in
                let stmt = Statement.returnStatement(returnStmt)
                return predicate(stmt) ? 1 : 0
            },
            visitExpressionStatement: { expr in
                let stmt = Statement.expressionStatement(expr)
                return predicate(stmt) ? 1 : 0
            },
            visitBreakStatement: {
                let stmt = Statement.breakStatement
                return predicate(stmt) ? 1 : 0
            },
            visitBlock: { statements in
                let stmt = Statement.block(statements)
                let selfCount = predicate(stmt) ? 1 : 0
                let childCount = statements.reduce(0) { sum, s in
                    sum + StatementVisitor.counter(for: nodeType, matching: predicate).visit(s)
                }
                return selfCount + childCount
            }
        )
    }
}