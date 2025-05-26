import Foundation

/// A closure-based visitor for Statement AST traversal with generic result type.
/// This visitor provides an efficient, type-safe way to traverse and transform Statement trees
/// without requiring modifications to the original Statement enum.
///
/// # Usage
/// ```swift
/// let collector = StatementVisitor<[String]>(
///     visitIfStatement: { ifStmt in ["if", "endif"] },
///     visitWhileStatement: { whileStmt in ["while", "endwhile"] },
///     visitForStatement: { forStmt in ["for", "endfor"] },
///     visitAssignment: { assignment in ["assignment"] },
///     visitVariableDeclaration: { varDecl in ["var \(varDecl.name)"] },
///     visitConstantDeclaration: { constDecl in ["const \(constDecl.name)"] },
///     visitFunctionDeclaration: { funcDecl in ["function \(funcDecl.name)"] },
///     visitProcedureDeclaration: { procDecl in ["procedure \(procDecl.name)"] },
///     visitReturnStatement: { returnStmt in ["return"] },
///     visitExpressionStatement: { expr in ["expression"] },
///     visitBreakStatement: { ["break"] },
///     visitBlock: { statements in ["block"] }
/// )
/// 
/// let result = collector.visit(statement)
/// ```
@Sendable
public struct StatementVisitor<Result: Sendable> {
    
    /// Visits an if statement.
    /// - Parameter ifStatement: The if statement to visit
    /// - Returns: The result of visiting the if statement
    public let visitIfStatement: @Sendable (IfStatement) -> Result
    
    /// Visits a while statement.
    /// - Parameter whileStatement: The while statement to visit
    /// - Returns: The result of visiting the while statement
    public let visitWhileStatement: @Sendable (WhileStatement) -> Result
    
    /// Visits a for statement.
    /// - Parameter forStatement: The for statement to visit
    /// - Returns: The result of visiting the for statement
    public let visitForStatement: @Sendable (ForStatement) -> Result
    
    /// Visits an assignment statement.
    /// - Parameter assignment: The assignment to visit
    /// - Returns: The result of visiting the assignment
    public let visitAssignment: @Sendable (Assignment) -> Result
    
    /// Visits a variable declaration.
    /// - Parameter variableDeclaration: The variable declaration to visit
    /// - Returns: The result of visiting the variable declaration
    public let visitVariableDeclaration: @Sendable (VariableDeclaration) -> Result
    
    /// Visits a constant declaration.
    /// - Parameter constantDeclaration: The constant declaration to visit
    /// - Returns: The result of visiting the constant declaration
    public let visitConstantDeclaration: @Sendable (ConstantDeclaration) -> Result
    
    /// Visits a function declaration.
    /// - Parameter functionDeclaration: The function declaration to visit
    /// - Returns: The result of visiting the function declaration
    public let visitFunctionDeclaration: @Sendable (FunctionDeclaration) -> Result
    
    /// Visits a procedure declaration.
    /// - Parameter procedureDeclaration: The procedure declaration to visit
    /// - Returns: The result of visiting the procedure declaration
    public let visitProcedureDeclaration: @Sendable (ProcedureDeclaration) -> Result
    
    /// Visits a return statement.
    /// - Parameter returnStatement: The return statement to visit
    /// - Returns: The result of visiting the return statement
    public let visitReturnStatement: @Sendable (ReturnStatement) -> Result
    
    /// Visits an expression statement.
    /// - Parameter expression: The expression statement to visit
    /// - Returns: The result of visiting the expression statement
    public let visitExpressionStatement: @Sendable (Expression) -> Result
    
    /// Visits a break statement.
    /// - Returns: The result of visiting the break statement
    public let visitBreakStatement: @Sendable () -> Result
    
    /// Visits a block statement.
    /// - Parameter statements: The array of statements in the block
    /// - Returns: The result of visiting the block
    public let visitBlock: @Sendable ([Statement]) -> Result
    
    /// Creates a new StatementVisitor with the provided closures.
    /// - Parameters:
    ///   - visitIfStatement: Closure to handle if statements
    ///   - visitWhileStatement: Closure to handle while statements
    ///   - visitForStatement: Closure to handle for statements
    ///   - visitAssignment: Closure to handle assignment statements
    ///   - visitVariableDeclaration: Closure to handle variable declarations
    ///   - visitConstantDeclaration: Closure to handle constant declarations
    ///   - visitFunctionDeclaration: Closure to handle function declarations
    ///   - visitProcedureDeclaration: Closure to handle procedure declarations
    ///   - visitReturnStatement: Closure to handle return statements
    ///   - visitExpressionStatement: Closure to handle expression statements
    ///   - visitBreakStatement: Closure to handle break statements
    ///   - visitBlock: Closure to handle block statements
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
    
    /// Visits a statement using pattern matching dispatch.
    /// This method efficiently routes the statement to the appropriate closure based on its type.
    /// - Parameter statement: The statement to visit
    /// - Returns: The result of visiting the statement
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

// MARK: - Convenience Methods

extension StatementVisitor {
    /// Creates a simple string representation visitor for debugging purposes.
    /// - Returns: A StatementVisitor that produces string descriptions of statements
    public static func debugStringifier() -> StatementVisitor<String> {
        return StatementVisitor<String>(
            visitIfStatement: { ifStmt in
                var result = "if (\(ifStmt.condition))"
                if !ifStmt.elseIfs.isEmpty {
                    result += " with \(ifStmt.elseIfs.count) elif(s)"
                }
                if ifStmt.elseBody != nil {
                    result += " with else"
                }
                return result
            },
            visitWhileStatement: { whileStmt in
                "while (\(whileStmt.condition))"
            },
            visitForStatement: { forStmt in
                switch forStmt {
                case .range(let rangeFor):
                    return "for \(rangeFor.variable) = \(rangeFor.start) to \(rangeFor.end)"
                case .forEach(let forEach):
                    return "for \(forEach.variable) in \(forEach.iterable)"
                }
            },
            visitAssignment: { assignment in
                switch assignment {
                case .variable(let name, let expr):
                    return "\(name) = \(expr)"
                case .arrayElement(let arrayAccess, let expr):
                    return "\(arrayAccess.array)[\(arrayAccess.index)] = \(expr)"
                }
            },
            visitVariableDeclaration: { varDecl in
                var result = "var \(varDecl.name): \(varDecl.type)"
                if let initialValue = varDecl.initialValue {
                    result += " = \(initialValue)"
                }
                return result
            },
            visitConstantDeclaration: { constDecl in
                "const \(constDecl.name): \(constDecl.type) = \(constDecl.initialValue)"
            },
            visitFunctionDeclaration: { funcDecl in
                "function \(funcDecl.name)(\(funcDecl.parameters.count) params)"
            },
            visitProcedureDeclaration: { procDecl in
                "procedure \(procDecl.name)(\(procDecl.parameters.count) params)"
            },
            visitReturnStatement: { returnStmt in
                if let expr = returnStmt.expression {
                    return "return \(expr)"
                } else {
                    return "return"
                }
            },
            visitExpressionStatement: { expr in
                "\(expr)"
            },
            visitBreakStatement: { "break" },
            visitBlock: { statements in
                "block with \(statements.count) statement(s)"
            }
        )
    }
}

// MARK: - Statement Debug Description Support

extension Statement: CustomStringConvertible {
    public var description: String {
        return StatementVisitor.debugStringifier().visit(self)
    }
}

// MARK: - Additional Type Debug Descriptions

extension DataType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .integer:
            return "integer"
        case .real:
            return "real"
        case .character:
            return "character"
        case .string:
            return "string"
        case .boolean:
            return "boolean"
        case .array(let elementType):
            return "array of \(elementType)"
        case .record(let name):
            return "record \(name)"
        }
    }
}