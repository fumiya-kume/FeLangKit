import Foundation

/// A function-based visitor for traversing `Statement` AST nodes.
///
/// This visitor provides a flexible, closure-based approach to AST traversal that
/// allows for clean separation of concerns between AST structure and processing logic.
/// Each visit method is implemented as a closure, enabling maximum flexibility and
/// easy composition of visitor behaviors.
///
/// Example usage:
/// ```swift
/// let collector = StatementVisitor<[String]>(
///     visitIfStatement: { ifStmt in
///         return ["if"] + /* process children */
///     },
///     visitWhileStatement: { whileStmt in
///         return ["while"] + /* process children */
///     }
///     // ... other visit methods
/// )
/// 
/// let identifiers = collector.visit(statement)
/// ```
public struct StatementVisitor<Result>: Sendable where Result: Sendable {

    // MARK: - Visit Closures

    /// Visits if statements.
    public let visitIfStatement: @Sendable (IfStatement) -> Result

    /// Visits while statements.
    public let visitWhileStatement: @Sendable (WhileStatement) -> Result

    /// Visits for statements.
    public let visitForStatement: @Sendable (ForStatement) -> Result

    /// Visits assignment statements.
    public let visitAssignment: @Sendable (Assignment) -> Result

    /// Visits variable declarations.
    public let visitVariableDeclaration: @Sendable (VariableDeclaration) -> Result

    /// Visits constant declarations.
    public let visitConstantDeclaration: @Sendable (ConstantDeclaration) -> Result

    /// Visits function declarations.
    public let visitFunctionDeclaration: @Sendable (FunctionDeclaration) -> Result

    /// Visits procedure declarations.
    public let visitProcedureDeclaration: @Sendable (ProcedureDeclaration) -> Result

    /// Visits return statements.
    public let visitReturnStatement: @Sendable (ReturnStatement) -> Result

    /// Visits expression statements.
    public let visitExpressionStatement: @Sendable (Expression) -> Result

    /// Visits break statements.
    public let visitBreakStatement: @Sendable () -> Result

    /// Visits block statements.
    /// - Parameter statements: The list of statements in the block
    public let visitBlock: @Sendable ([Statement]) -> Result

    // MARK: - Initialization

    /// Creates a new statement visitor with the specified visit closures.
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

    /// Visits a statement, dispatching to the appropriate visit closure based on the statement type.
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
