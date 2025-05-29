import Foundation

/// ASTWalker provides automatic recursive traversal utilities for AST nodes.
///
/// This utility class simplifies the creation of visitors that need to recursively
/// traverse AST structures while performing operations at each node. It handles
/// the complexity of recursion automatically, allowing developers to focus on
/// the logic for processing individual nodes.
///
/// Example usage:
/// ```swift
/// // Create a walker that counts all expression nodes
/// let counter = ASTWalker.createExpressionCounter()
/// let totalNodes = counter.visit(expression)
///
/// // Create a walker that collects all identifier names
/// let identifierCollector = ASTWalker.createIdentifierCollector()
/// let identifiers = identifierCollector.visit(expression)
/// ```
public struct ASTWalker: Sendable {

    // MARK: - Expression Walkers

    /// Creates an expression visitor that recursively counts all nodes in an expression tree.
    ///
    /// This walker traverses the entire expression tree and returns the total count
    /// of all nodes, including the root node and all nested expressions.
    ///
    /// - Returns: An ExpressionVisitor that counts nodes and returns an Int
    public static func createExpressionCounter() -> ExpressionVisitor<Int> {
        return ExpressionVisitor<Int>(
            visitLiteral: { _ in 1 },
            visitIdentifier: { _ in 1 },
            visitBinary: { _, left, right in
                1 + createExpressionCounter().visit(left) + createExpressionCounter().visit(right)
            },
            visitUnary: { _, operand in
                1 + createExpressionCounter().visit(operand)
            },
            visitArrayAccess: { array, index in
                1 + createExpressionCounter().visit(array) + createExpressionCounter().visit(index)
            },
            visitFieldAccess: { object, _ in
                1 + createExpressionCounter().visit(object)
            },
            visitFunctionCall: { _, arguments in
                1 + arguments.reduce(0) { sum, arg in
                    sum + createExpressionCounter().visit(arg)
                }
            }
        )
    }

    /// Creates an expression visitor that recursively collects all identifier names.
    ///
    /// This walker traverses the expression tree and collects all identifier names
    /// encountered during traversal, returning them as an array.
    ///
    /// - Returns: An ExpressionVisitor that collects identifiers and returns [String]
    public static func createIdentifierCollector() -> ExpressionVisitor<[String]> {
        return ExpressionVisitor<[String]>(
            visitLiteral: { _ in [] },
            visitIdentifier: { identifier in [identifier] },
            visitBinary: { _, left, right in
                createIdentifierCollector().visit(left) + createIdentifierCollector().visit(right)
            },
            visitUnary: { _, operand in
                createIdentifierCollector().visit(operand)
            },
            visitArrayAccess: { array, index in
                createIdentifierCollector().visit(array) + createIdentifierCollector().visit(index)
            },
            visitFieldAccess: { object, _ in
                createIdentifierCollector().visit(object)
            },
            visitFunctionCall: { _, arguments in
                arguments.flatMap { createIdentifierCollector().visit($0) }
            }
        )
    }

    /// Creates an expression visitor that recursively builds a string representation.
    ///
    /// This walker provides a pretty-printed string representation of expressions
    /// with proper parenthesization and formatting.
    ///
    /// - Returns: An ExpressionVisitor that stringifies expressions and returns String
    public static func createExpressionStringifier() -> ExpressionVisitor<String> {
        return ExpressionVisitor<String>(
            visitLiteral: { literal in
                switch literal {
                case .integer(let value):
                    return "\(value)"
                case .real(let value):
                    return "\(value)"
                case .string(let value):
                    return "\"\(value)\""
                case .character(let value):
                    return "'\(value)'"
                case .boolean(let value):
                    return "\(value)"
                }
            },
            visitIdentifier: { identifier in identifier },
            visitBinary: { op, left, right in
                let leftStr = createExpressionStringifier().visit(left)
                let rightStr = createExpressionStringifier().visit(right)
                return "(\(leftStr) \(op.rawValue) \(rightStr))"
            },
            visitUnary: { op, operand in
                let operandStr = createExpressionStringifier().visit(operand)
                return "\(op.rawValue) \(operandStr)"
            },
            visitArrayAccess: { array, index in
                let arrayStr = createExpressionStringifier().visit(array)
                let indexStr = createExpressionStringifier().visit(index)
                return "\(arrayStr)[\(indexStr)]"
            },
            visitFieldAccess: { object, field in
                let objectStr = createExpressionStringifier().visit(object)
                return "\(objectStr).\(field)"
            },
            visitFunctionCall: { function, arguments in
                let argStrings = arguments.map { createExpressionStringifier().visit($0) }
                return "\(function)(\(argStrings.joined(separator: ", ")))"
            }
        )
    }

    // MARK: - Statement Walkers

    /// Creates a statement visitor that recursively counts all nodes in a statement tree.
    ///
    /// This walker traverses the entire statement tree and returns the total count
    /// of all statement nodes, including nested statements in control structures.
    ///
    /// - Returns: A StatementVisitor that counts nodes and returns an Int
    public static func createStatementCounter() -> StatementVisitor<Int> {
        return StatementVisitor<Int>(
            visitIfStatement: { ifStmt in
                let thenCount = ifStmt.thenBody.reduce(0) { sum, stmt in
                    sum + createStatementCounter().visit(stmt)
                }
                let elseIfCount = ifStmt.elseIfs.reduce(0) { sum, elseIf in
                    sum + elseIf.body.reduce(0) { innerSum, stmt in
                        innerSum + createStatementCounter().visit(stmt)
                    }
                }
                let elseCount = ifStmt.elseBody?.reduce(0) { sum, stmt in
                    sum + createStatementCounter().visit(stmt)
                } ?? 0
                return 1 + thenCount + elseIfCount + elseCount
            },
            visitWhileStatement: { whileStmt in
                let bodyCount = whileStmt.body.reduce(0) { sum, stmt in
                    sum + createStatementCounter().visit(stmt)
                }
                return 1 + bodyCount
            },
            visitForStatement: { forStmt in
                let bodyCount: Int
                switch forStmt {
                case .range(let rangeFor):
                    bodyCount = rangeFor.body.reduce(0) { sum, stmt in
                        sum + createStatementCounter().visit(stmt)
                    }
                case .forEach(let forEach):
                    bodyCount = forEach.body.reduce(0) { sum, stmt in
                        sum + createStatementCounter().visit(stmt)
                    }
                }
                return 1 + bodyCount
            },
            visitAssignment: { _ in 1 },
            visitVariableDeclaration: { _ in 1 },
            visitConstantDeclaration: { _ in 1 },
            visitFunctionDeclaration: { funcDecl in
                let bodyCount = funcDecl.body.reduce(0) { sum, stmt in
                    sum + createStatementCounter().visit(stmt)
                }
                return 1 + bodyCount
            },
            visitProcedureDeclaration: { procDecl in
                let bodyCount = procDecl.body.reduce(0) { sum, stmt in
                    sum + createStatementCounter().visit(stmt)
                }
                return 1 + bodyCount
            },
            visitReturnStatement: { _ in 1 },
            visitExpressionStatement: { _ in 1 },
            visitBreakStatement: { 1 },
            visitBlock: { statements in
                let bodyCount = statements.reduce(0) { sum, stmt in
                    sum + createStatementCounter().visit(stmt)
                }
                return 1 + bodyCount
            }
        )
    }

    /// Creates a statement visitor that recursively collects all variable and function names.
    ///
    /// This walker traverses the statement tree and collects all declared variable names,
    /// constant names, function names, and procedure names.
    ///
    /// - Returns: A StatementVisitor that collects names and returns [String]
    public static func createNameCollector() -> StatementVisitor<[String]> {
        return StatementVisitor<[String]>(
            visitIfStatement: { ifStmt in
                let thenNames = ifStmt.thenBody.flatMap { createNameCollector().visit($0) }
                let elseIfNames = ifStmt.elseIfs.flatMap { elseIf in
                    elseIf.body.flatMap { createNameCollector().visit($0) }
                }
                let elseNames = ifStmt.elseBody?.flatMap { createNameCollector().visit($0) } ?? []
                return thenNames + elseIfNames + elseNames
            },
            visitWhileStatement: { whileStmt in
                whileStmt.body.flatMap { createNameCollector().visit($0) }
            },
            visitForStatement: { forStmt in
                let (variable, bodyNames): (String, [String])
                switch forStmt {
                case .range(let rangeFor):
                    variable = rangeFor.variable
                    bodyNames = rangeFor.body.flatMap { createNameCollector().visit($0) }
                case .forEach(let forEach):
                    variable = forEach.variable
                    bodyNames = forEach.body.flatMap { createNameCollector().visit($0) }
                }
                return [variable] + bodyNames
            },
            visitAssignment: { assignment in
                switch assignment {
                case .variable(let name, _):
                    return [name]
                case .arrayElement:
                    return []
                }
            },
            visitVariableDeclaration: { varDecl in [varDecl.name] },
            visitConstantDeclaration: { constDecl in [constDecl.name] },
            visitFunctionDeclaration: { funcDecl in
                let paramNames = funcDecl.parameters.map { $0.name }
                let localVarNames = funcDecl.localVariables.map { $0.name }
                let bodyNames = funcDecl.body.flatMap { createNameCollector().visit($0) }
                return [funcDecl.name] + paramNames + localVarNames + bodyNames
            },
            visitProcedureDeclaration: { procDecl in
                let paramNames = procDecl.parameters.map { $0.name }
                let localVarNames = procDecl.localVariables.map { $0.name }
                let bodyNames = procDecl.body.flatMap { createNameCollector().visit($0) }
                return [procDecl.name] + paramNames + localVarNames + bodyNames
            },
            visitReturnStatement: { _ in [] },
            visitExpressionStatement: { _ in [] },
            visitBreakStatement: { [] },
            visitBlock: { statements in
                statements.flatMap { createNameCollector().visit($0) }
            }
        )
    }

    /// Creates a statement visitor that recursively builds a string representation.
    ///
    /// This walker provides a pretty-printed string representation of statements
    /// with proper indentation and formatting.
    ///
    /// - Parameter indentLevel: The initial indentation level (default: 0)
    /// - Returns: A StatementVisitor that stringifies statements and returns String
    public static func createStatementStringifier(indentLevel: Int = 0) -> StatementVisitor<String> {
        let indent = String(repeating: "  ", count: indentLevel)
        let nextIndent = String(repeating: "  ", count: indentLevel + 1)

        return StatementVisitor<String>(
            visitIfStatement: { ifStmt in
                let exprStr = createExpressionStringifier().visit(ifStmt.condition)
                let thenBody = ifStmt.thenBody.map { stmt in
                    nextIndent + createStatementStringifier(indentLevel: indentLevel + 1).visit(stmt)
                }.joined(separator: "\n")

                var result = "\(indent)if (\(exprStr)) {\n\(thenBody)\n\(indent)}"

                for elseIf in ifStmt.elseIfs {
                    let elseIfExpr = createExpressionStringifier().visit(elseIf.condition)
                    let elseIfBody = elseIf.body.map { stmt in
                        nextIndent + createStatementStringifier(indentLevel: indentLevel + 1).visit(stmt)
                    }.joined(separator: "\n")
                    result += " else if (\(elseIfExpr)) {\n\(elseIfBody)\n\(indent)}"
                }

                if let elseBody = ifStmt.elseBody {
                    let elseBodyStr = elseBody.map { stmt in
                        nextIndent + createStatementStringifier(indentLevel: indentLevel + 1).visit(stmt)
                    }.joined(separator: "\n")
                    result += " else {\n\(elseBodyStr)\n\(indent)}"
                }

                return result
            },
            visitWhileStatement: { whileStmt in
                let exprStr = createExpressionStringifier().visit(whileStmt.condition)
                let bodyStr = whileStmt.body.map { stmt in
                    nextIndent + createStatementStringifier(indentLevel: indentLevel + 1).visit(stmt)
                }.joined(separator: "\n")
                return "\(indent)while (\(exprStr)) {\n\(bodyStr)\n\(indent)}"
            },
            visitForStatement: { forStmt in
                switch forStmt {
                case .range(let rangeFor):
                    let startStr = createExpressionStringifier().visit(rangeFor.start)
                    let endStr = createExpressionStringifier().visit(rangeFor.end)
                    let bodyStr = rangeFor.body.map { stmt in
                        nextIndent + createStatementStringifier(indentLevel: indentLevel + 1).visit(stmt)
                    }.joined(separator: "\n")
                    return "\(indent)for \(rangeFor.variable) = \(startStr) to \(endStr) {\n\(bodyStr)\n\(indent)}"
                case .forEach(let forEach):
                    let iterableStr = createExpressionStringifier().visit(forEach.iterable)
                    let bodyStr = forEach.body.map { stmt in
                        nextIndent + createStatementStringifier(indentLevel: indentLevel + 1).visit(stmt)
                    }.joined(separator: "\n")
                    return "\(indent)for \(forEach.variable) in \(iterableStr) {\n\(bodyStr)\n\(indent)}"
                }
            },
            visitAssignment: { assignment in
                switch assignment {
                case .variable(let name, let expr):
                    let exprStr = createExpressionStringifier().visit(expr)
                    return "\(indent)\(name) = \(exprStr)"
                case .arrayElement(let arrayAccess, let expr):
                    let arrayStr = createExpressionStringifier().visit(arrayAccess.array)
                    let indexStr = createExpressionStringifier().visit(arrayAccess.index)
                    let exprStr = createExpressionStringifier().visit(expr)
                    return "\(indent)\(arrayStr)[\(indexStr)] = \(exprStr)"
                }
            },
            visitVariableDeclaration: { varDecl in
                if let initialValue = varDecl.initialValue {
                    let initStr = createExpressionStringifier().visit(initialValue)
                    return "\(indent)var \(varDecl.name): \(varDecl.type) = \(initStr)"
                } else {
                    return "\(indent)var \(varDecl.name): \(varDecl.type)"
                }
            },
            visitConstantDeclaration: { constDecl in
                let initStr = createExpressionStringifier().visit(constDecl.initialValue)
                return "\(indent)const \(constDecl.name): \(constDecl.type) = \(initStr)"
            },
            visitFunctionDeclaration: { funcDecl in
                let params = funcDecl.parameters.map { "\($0.name): \($0.type)" }.joined(separator: ", ")
                let returnType = funcDecl.returnType.map { " -> \($0)" } ?? ""
                let bodyStr = funcDecl.body.map { stmt in
                    nextIndent + createStatementStringifier(indentLevel: indentLevel + 1).visit(stmt)
                }.joined(separator: "\n")
                return "\(indent)function \(funcDecl.name)(\(params))\(returnType) {\n\(bodyStr)\n\(indent)}"
            },
            visitProcedureDeclaration: { procDecl in
                let params = procDecl.parameters.map { "\($0.name): \($0.type)" }.joined(separator: ", ")
                let bodyStr = procDecl.body.map { stmt in
                    nextIndent + createStatementStringifier(indentLevel: indentLevel + 1).visit(stmt)
                }.joined(separator: "\n")
                return "\(indent)procedure \(procDecl.name)(\(params)) {\n\(bodyStr)\n\(indent)}"
            },
            visitReturnStatement: { returnStmt in
                if let expr = returnStmt.expression {
                    let exprStr = createExpressionStringifier().visit(expr)
                    return "\(indent)return \(exprStr)"
                } else {
                    return "\(indent)return"
                }
            },
            visitExpressionStatement: { expr in
                let exprStr = createExpressionStringifier().visit(expr)
                return "\(indent)\(exprStr)"
            },
            visitBreakStatement: { "\(indent)break" },
            visitBlock: { statements in
                let bodyStr = statements.map { stmt in
                    nextIndent + createStatementStringifier(indentLevel: indentLevel + 1).visit(stmt)
                }.joined(separator: "\n")
                return "\(indent){\n\(bodyStr)\n\(indent)}"
            }
        )
    }

    // MARK: - Generic Walker Utilities

    /// Creates a generic expression transformation walker.
    ///
    /// This walker applies a transformation function to each expression node
    /// and returns the transformed expression tree.
    ///
    /// - Parameter transform: A function that transforms individual expressions
    /// - Returns: An ExpressionVisitor that transforms expressions
    public static func createExpressionTransformer(
        _ transform: @escaping @Sendable (Expression) -> Expression
    ) -> ExpressionVisitor<Expression> {
        return ExpressionVisitor<Expression>(
            visitLiteral: { literal in transform(.literal(literal)) },
            visitIdentifier: { identifier in transform(.identifier(identifier)) },
            visitBinary: { op, left, right in
                let transformedLeft = createExpressionTransformer(transform).visit(left)
                let transformedRight = createExpressionTransformer(transform).visit(right)
                return transform(.binary(op, transformedLeft, transformedRight))
            },
            visitUnary: { op, operand in
                let transformedOperand = createExpressionTransformer(transform).visit(operand)
                return transform(.unary(op, transformedOperand))
            },
            visitArrayAccess: { array, index in
                let transformedArray = createExpressionTransformer(transform).visit(array)
                let transformedIndex = createExpressionTransformer(transform).visit(index)
                return transform(.arrayAccess(transformedArray, transformedIndex))
            },
            visitFieldAccess: { object, field in
                let transformedObject = createExpressionTransformer(transform).visit(object)
                return transform(.fieldAccess(transformedObject, field))
            },
            visitFunctionCall: { function, arguments in
                let transformedArguments = arguments.map { createExpressionTransformer(transform).visit($0) }
                return transform(.functionCall(function, transformedArguments))
            }
        )
    }
}
