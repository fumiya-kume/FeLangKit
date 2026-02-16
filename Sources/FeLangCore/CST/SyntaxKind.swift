/// Identifies the kind of a concrete syntax tree (CST) node.
///
/// CST nodes preserve the full syntactic structure of the source code,
/// including tokens that are discarded during AST construction (keywords,
/// delimiters, whitespace). This enables lossless round-tripping and
/// fine-grained IDE tooling such as syntax highlighting and refactoring.
public enum SyntaxKind: String, Equatable, Hashable, Sendable, CaseIterable {

    // MARK: - Top-Level Structure

    /// Root node representing an entire source file.
    case sourceFile

    /// A list of top-level declarations (variables, constants, globals)
    /// that appear before function/procedure definitions.
    case importList

    /// A list of function, procedure, and class declarations.
    case declarationList

    // MARK: - Statements

    case ifStatement
    case whileStatement
    case doWhileStatement
    case forStatement
    case variableDeclaration
    case constantDeclaration
    case globalDeclaration
    case functionDeclaration
    case procedureDeclaration
    case classDeclaration
    case returnStatement
    case breakStatement
    case continueStatement
    case assignmentStatement
    case expressionStatement
    case block

    // MARK: - Expressions

    /// Function call expression – `name(args)`.
    case callExpr

    /// Method call expression – `receiver.name(args)`.
    case methodCallExpr

    /// If-then-else treated as an expression node in the CST.
    case ifExpr

    /// Pattern-matching / switch expression (reserved for future grammar).
    case whenExpr

    /// Try expression for error handling (reserved for future grammar).
    case tryExpr

    /// Binary operator expression – `lhs op rhs`.
    case binaryExpr

    /// Unary operator expression – `op operand`.
    case unaryExpr

    /// Literal value (integer, real, string, character, boolean, undefined).
    case literalExpr

    /// Identifier reference.
    case identifierExpr

    /// Array subscript – `expr[index]`.
    case arrayAccessExpr

    /// Field access – `expr.field`.
    case fieldAccessExpr

    /// Array literal – `[e1, e2, ...]` or `{e1, e2, ...}`.
    case arrayLiteralExpr

    /// Parenthesized expression – `(expr)`.
    case parenExpr

    // MARK: - Clauses & Fragments

    case elseIfClause
    case elseClause
    case thenClause
    case conditionClause
    case parameterList
    case parameter
    case argumentList
    case typeAnnotation
    case forRangeClause
    case forEachClause
    case memberDeclaration
    case constructorDeclaration
    case methodDeclaration

    // MARK: - Leaf

    /// A leaf node that wraps a single token.
    case token
}

extension SyntaxKind {
    /// Whether this kind represents an expression node.
    public var isExpression: Bool {
        switch self {
        case .callExpr, .methodCallExpr, .ifExpr, .whenExpr, .tryExpr,
             .binaryExpr, .unaryExpr, .literalExpr, .identifierExpr,
             .arrayAccessExpr, .fieldAccessExpr, .arrayLiteralExpr, .parenExpr:
            return true
        default:
            return false
        }
    }

    /// Whether this kind represents a statement node.
    public var isStatement: Bool {
        switch self {
        case .ifStatement, .whileStatement, .doWhileStatement, .forStatement,
             .variableDeclaration, .constantDeclaration, .globalDeclaration,
             .functionDeclaration, .procedureDeclaration, .classDeclaration,
             .returnStatement, .breakStatement, .continueStatement,
             .assignmentStatement, .expressionStatement, .block:
            return true
        default:
            return false
        }
    }

    /// Whether this kind represents a top-level structural node.
    public var isTopLevel: Bool {
        switch self {
        case .sourceFile, .importList, .declarationList:
            return true
        default:
            return false
        }
    }
}
