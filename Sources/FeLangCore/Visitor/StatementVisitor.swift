import Foundation

/// A function-based visitor for traversing Statement AST nodes.
/// This implementation uses closures for maximum flexibility and Swift idiomaticity.
public struct StatementVisitor<Result>: Sendable {
    /// Closure for visiting if statements
    public let visitIfStatement: @Sendable (IfStatement) -> Result
    
    /// Closure for visiting while statements
    public let visitWhileStatement: @Sendable (WhileStatement) -> Result
    
    /// Closure for visiting for statements
    public let visitForStatement: @Sendable (ForStatement) -> Result
    
    /// Closure for visiting assignment statements
    public let visitAssignment: @Sendable (Assignment) -> Result
    
    /// Closure for visiting variable declarations
    public let visitVariableDeclaration: @Sendable (VariableDeclaration) -> Result
    
    /// Closure for visiting constant declarations
    public let visitConstantDeclaration: @Sendable (ConstantDeclaration) -> Result
    
    /// Closure for visiting function declarations
    public let visitFunctionDeclaration: @Sendable (FunctionDeclaration) -> Result
    
    /// Closure for visiting procedure declarations
    public let visitProcedureDeclaration: @Sendable (ProcedureDeclaration) -> Result
    
    /// Closure for visiting return statements
    public let visitReturnStatement: @Sendable (ReturnStatement) -> Result
    
    /// Closure for visiting expression statements
    public let visitExpressionStatement: @Sendable (Expression) -> Result
    
    /// Closure for visiting break statements
    public let visitBreakStatement: @Sendable () -> Result
    
    /// Closure for visiting block statements
    public let visitBlock: @Sendable ([Statement]) -> Result
    
    /// Initializes a new StatementVisitor with the provided closures
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
    
    /// Visits a statement and returns the result using the appropriate closure
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

/// Convenience extension for creating common visitor patterns
extension StatementVisitor {
    /// Creates a visitor that converts statements to strings for debugging
    public static func makeDebugVisitor() -> StatementVisitor<String> {
        return StatementVisitor<String>(
            visitIfStatement: { ifStmt in
                let conditionStr = ExpressionVisitor<String>.makeDebugVisitor().visit(ifStmt.condition)
                let thenStr = ifStmt.thenBody.map { StatementVisitor.makeDebugVisitor().visit($0) }.joined(separator: "; ")
                let elseIfStr = ifStmt.elseIfs.map { elseIf in
                    let condStr = ExpressionVisitor<String>.makeDebugVisitor().visit(elseIf.condition)
                    let bodyStr = elseIf.body.map { StatementVisitor.makeDebugVisitor().visit($0) }.joined(separator: "; ")
                    return "elif \(condStr) then [\(bodyStr)]"
                }.joined(separator: " ")
                let elseStr = ifStmt.elseBody?.map { StatementVisitor.makeDebugVisitor().visit($0) }.joined(separator: "; ") ?? ""
                return "if \(conditionStr) then [\(thenStr)]\(elseIfStr.isEmpty ? "" : " \(elseIfStr)")\(elseStr.isEmpty ? "" : " else [\(elseStr)]")"
            },
            visitWhileStatement: { whileStmt in
                let conditionStr = ExpressionVisitor<String>.makeDebugVisitor().visit(whileStmt.condition)
                let bodyStr = whileStmt.body.map { StatementVisitor.makeDebugVisitor().visit($0) }.joined(separator: "; ")
                return "while \(conditionStr) do [\(bodyStr)]"
            },
            visitForStatement: { forStmt in
                switch forStmt {
                case .range(let rangeFor):
                    let startStr = ExpressionVisitor<String>.makeDebugVisitor().visit(rangeFor.start)
                    let endStr = ExpressionVisitor<String>.makeDebugVisitor().visit(rangeFor.end)
                    let stepStr = rangeFor.step.map { ExpressionVisitor<String>.makeDebugVisitor().visit($0) } ?? "1"
                    let bodyStr = rangeFor.body.map { StatementVisitor.makeDebugVisitor().visit($0) }.joined(separator: "; ")
                    return "for \(rangeFor.variable) := \(startStr) to \(endStr) step \(stepStr) do [\(bodyStr)]"
                case .forEach(let forEachLoop):
                    let iterableStr = ExpressionVisitor<String>.makeDebugVisitor().visit(forEachLoop.iterable)
                    let bodyStr = forEachLoop.body.map { StatementVisitor.makeDebugVisitor().visit($0) }.joined(separator: "; ")
                    return "for \(forEachLoop.variable) in \(iterableStr) do [\(bodyStr)]"
                }
            },
            visitAssignment: { assignment in
                switch assignment {
                case .variable(let name, let expr):
                    let exprStr = ExpressionVisitor<String>.makeDebugVisitor().visit(expr)
                    return "\(name) := \(exprStr)"
                case .arrayElement(let arrayAccess, let expr):
                    let arrayStr = ExpressionVisitor<String>.makeDebugVisitor().visit(arrayAccess.array)
                    let indexStr = ExpressionVisitor<String>.makeDebugVisitor().visit(arrayAccess.index)
                    let exprStr = ExpressionVisitor<String>.makeDebugVisitor().visit(expr)
                    return "\(arrayStr)[\(indexStr)] := \(exprStr)"
                }
            },
            visitVariableDeclaration: { varDecl in
                let initialStr = varDecl.initialValue.map { ExpressionVisitor<String>.makeDebugVisitor().visit($0) } ?? ""
                return "var \(varDecl.name): \(varDecl.type)\(initialStr.isEmpty ? "" : " := \(initialStr)")"
            },
            visitConstantDeclaration: { constDecl in
                let initialStr = ExpressionVisitor<String>.makeDebugVisitor().visit(constDecl.initialValue)
                return "const \(constDecl.name): \(constDecl.type) := \(initialStr)"
            },
            visitFunctionDeclaration: { funcDecl in
                let paramsStr = funcDecl.parameters.map { "\($0.name): \($0.type)" }.joined(separator: ", ")
                let returnStr = funcDecl.returnType.map { ": \($0)" } ?? ""
                let bodyStr = funcDecl.body.map { StatementVisitor.makeDebugVisitor().visit($0) }.joined(separator: "; ")
                return "function \(funcDecl.name)(\(paramsStr))\(returnStr) [\(bodyStr)]"
            },
            visitProcedureDeclaration: { procDecl in
                let paramsStr = procDecl.parameters.map { "\($0.name): \($0.type)" }.joined(separator: ", ")
                let bodyStr = procDecl.body.map { StatementVisitor.makeDebugVisitor().visit($0) }.joined(separator: "; ")
                return "procedure \(procDecl.name)(\(paramsStr)) [\(bodyStr)]"
            },
            visitReturnStatement: { returnStmt in
                let exprStr = returnStmt.expression.map { ExpressionVisitor<String>.makeDebugVisitor().visit($0) } ?? ""
                return "return\(exprStr.isEmpty ? "" : " \(exprStr)")"
            },
            visitExpressionStatement: { expr in
                return ExpressionVisitor<String>.makeDebugVisitor().visit(expr)
            },
            visitBreakStatement: {
                return "break"
            },
            visitBlock: { statements in
                let stmtsStr = statements.map { StatementVisitor.makeDebugVisitor().visit($0) }.joined(separator: "; ")
                return "{\(stmtsStr)}"
            }
        )
    }
}