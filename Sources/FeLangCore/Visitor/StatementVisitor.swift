import Foundation

/// A closure-based visitor for Statement AST traversal.
/// Provides type-safe visitor pattern implementation with generic Result type.
public struct StatementVisitor<Result>: Sendable {
    // MARK: - Visitor Closures
    
    /// Visits an if statement
    public let visitIfStatement: @Sendable (IfStatement) -> Result
    
    /// Visits a while statement
    public let visitWhileStatement: @Sendable (WhileStatement) -> Result
    
    /// Visits a for statement
    public let visitForStatement: @Sendable (ForStatement) -> Result
    
    /// Visits an assignment statement
    public let visitAssignment: @Sendable (Assignment) -> Result
    
    /// Visits a variable declaration
    public let visitVariableDeclaration: @Sendable (VariableDeclaration) -> Result
    
    /// Visits a constant declaration
    public let visitConstantDeclaration: @Sendable (ConstantDeclaration) -> Result
    
    /// Visits a function declaration
    public let visitFunctionDeclaration: @Sendable (FunctionDeclaration) -> Result
    
    /// Visits a procedure declaration
    public let visitProcedureDeclaration: @Sendable (ProcedureDeclaration) -> Result
    
    /// Visits a return statement
    public let visitReturnStatement: @Sendable (ReturnStatement) -> Result
    
    /// Visits an expression statement
    public let visitExpressionStatement: @Sendable (Expression) -> Result
    
    /// Visits a break statement
    public let visitBreakStatement: @Sendable () -> Result
    
    /// Visits a block statement
    public let visitBlock: @Sendable ([Statement]) -> Result
    
    // MARK: - Initialization
    
    /// Creates a new StatementVisitor with the specified closure handlers.
    /// - Parameters:
    ///   - visitIfStatement: Handler for if statements
    ///   - visitWhileStatement: Handler for while statements
    ///   - visitForStatement: Handler for for statements
    ///   - visitAssignment: Handler for assignment statements
    ///   - visitVariableDeclaration: Handler for variable declarations
    ///   - visitConstantDeclaration: Handler for constant declarations
    ///   - visitFunctionDeclaration: Handler for function declarations
    ///   - visitProcedureDeclaration: Handler for procedure declarations
    ///   - visitReturnStatement: Handler for return statements
    ///   - visitExpressionStatement: Handler for expression statements
    ///   - visitBreakStatement: Handler for break statements
    ///   - visitBlock: Handler for block statements
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
    
    // MARK: - Visit Method
    
    /// Visits a statement and dispatches to the appropriate handler.
    /// - Parameter statement: The statement to visit
    /// - Returns: The result from the appropriate handler
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