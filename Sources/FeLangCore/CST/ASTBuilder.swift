import Foundation

/// Converts a concrete syntax tree (CST) produced by `CSTParser` into the
/// existing `Statement` / `Expression` AST without re-scanning tokens.
///
/// By walking the already-parsed CST, `ASTBuilder` eliminates the need for
/// a second parse pass and makes the AST construction deterministic from the
/// tree structure alone.
public struct ASTBuilder {

    private let tokens: [Token]

    public init(tokens: [Token]) {
        self.tokens = tokens
    }

    // MARK: - Public API

    /// Builds an array of `Statement` from a `sourceFile` CST node.
    public func build(from root: SyntaxNode) throws -> [Statement] {
        guard root.kind == .sourceFile else {
            throw ASTBuildError.expectedKind(.sourceFile, got: root.kind)
        }
        var statements: [Statement] = []
        for child in root.children {
            switch child.kind {
            case .importList, .declarationList:
                for stmt in child.children {
                    statements.append(try buildStatement(stmt))
                }
            default:
                statements.append(try buildStatement(child))
            }
        }
        return statements
    }

    // MARK: - Statement Building

    private func buildStatement(_ node: SyntaxNode) throws -> Statement {
        switch node.kind {
        case .ifStatement:
            return .ifStatement(try buildIfStatement(node))
        case .whileStatement:
            return .whileStatement(try buildWhileStatement(node))
        case .doWhileStatement:
            return .doWhileStatement(try buildDoWhileStatement(node))
        case .forStatement:
            return .forStatement(try buildForStatement(node))
        case .variableDeclaration:
            return .variableDeclaration(try buildVariableDeclaration(node))
        case .constantDeclaration:
            return .constantDeclaration(try buildConstantDeclaration(node))
        case .globalDeclaration:
            return .globalDeclaration(try buildGlobalDeclaration(node))
        case .functionDeclaration:
            return .functionDeclaration(try buildFunctionDeclaration(node))
        case .procedureDeclaration:
            return .procedureDeclaration(try buildProcedureDeclaration(node))
        case .classDeclaration:
            return .classDeclaration(try buildClassDeclaration(node))
        case .returnStatement:
            return .returnStatement(try buildReturnStatement(node))
        case .breakStatement:
            return .breakStatement
        case .continueStatement:
            return .continueStatement
        case .assignmentStatement:
            return .assignment(try buildAssignment(node))
        case .expressionStatement:
            guard let exprChild = node.children.first else {
                throw ASTBuildError.missingChild("expression", parent: node.kind)
            }
            return .expressionStatement(try buildExpression(exprChild))
        case .block:
            let stmts = try node.children.map { try buildStatement($0) }
            return .block(stmts)
        default:
            throw ASTBuildError.unexpectedKind(node.kind)
        }
    }

    // MARK: - Control Flow

    private func buildIfStatement(_ node: SyntaxNode) throws -> IfStatement {
        let condClause = node.firstChild(ofKind: .conditionClause)
        guard let condExprNode = condClause?.children.first else {
            throw ASTBuildError.missingChild("condition", parent: .ifStatement)
        }
        let condition = try buildExpression(condExprNode)

        let thenClause = node.firstChild(ofKind: .thenClause)
        let thenBody: [Statement]
        if let block = thenClause?.children.first {
            thenBody = try buildBlock(block)
        } else {
            thenBody = []
        }

        let elseIfs: [IfStatement.ElseIf] = try node.children(ofKind: .elseIfClause).map { clause in
            let elifCond = clause.firstChild(ofKind: .conditionClause)
            guard let elifCondExpr = elifCond?.children.first else {
                throw ASTBuildError.missingChild("condition", parent: .elseIfClause)
            }
            let elifThen = clause.firstChild(ofKind: .thenClause)
            let elifBody: [Statement]
            if let block = elifThen?.children.first {
                elifBody = try buildBlock(block)
            } else {
                elifBody = []
            }
            return IfStatement.ElseIf(condition: try buildExpression(elifCondExpr), body: elifBody)
        }

        var elseBody: [Statement]?
        if let elseClause = node.firstChild(ofKind: .elseClause) {
            let blocks = elseClause.children(ofKind: .block)
            if let block = blocks.first {
                elseBody = try buildBlock(block)
            }
        }

        return IfStatement(condition: condition, thenBody: thenBody, elseIfs: elseIfs, elseBody: elseBody)
    }

    private func buildWhileStatement(_ node: SyntaxNode) throws -> WhileStatement {
        guard let condExpr = node.firstChild(ofKind: .conditionClause)?.children.first else {
            throw ASTBuildError.missingChild("condition", parent: .whileStatement)
        }
        let condition = try buildExpression(condExpr)

        let blocks = node.children(ofKind: .block)
        let body = try buildBlock(blocks.first ?? SyntaxNode(kind: .block, children: []))

        return WhileStatement(condition: condition, body: body)
    }

    private func buildDoWhileStatement(_ node: SyntaxNode) throws -> DoWhileStatement {
        guard let condExpr = node.firstChild(ofKind: .conditionClause)?.children.first else {
            throw ASTBuildError.missingChild("condition", parent: .doWhileStatement)
        }
        let condition = try buildExpression(condExpr)

        let blocks = node.children(ofKind: .block)
        let body = try buildBlock(blocks.first ?? SyntaxNode(kind: .block, children: []))

        return DoWhileStatement(body: body, condition: condition)
    }

    private func buildForStatement(_ node: SyntaxNode) throws -> ForStatement {
        let identNodes = node.children.filter { $0.kind == .identifierExpr || ($0.isToken && tokenAt($0)?.type == .identifier) }
        guard let varNode = identNodes.first else {
            throw ASTBuildError.missingChild("variable", parent: .forStatement)
        }
        let variable = tokenLexeme(varNode)

        if let rangeClause = node.firstChild(ofKind: .forRangeClause) {
            let exprs = rangeClause.children.filter { $0.kind != .token }
            guard exprs.count >= 2 else {
                throw ASTBuildError.missingChild("range expressions", parent: .forRangeClause)
            }
            let start = try buildExpression(exprs[0])
            let end = try buildExpression(exprs[1])
            let step: Expression? = exprs.count > 2 ? try buildExpression(exprs[2]) : nil

            let blocks = node.children(ofKind: .block)
            let body = try buildBlock(blocks.first ?? SyntaxNode(kind: .block, children: []))

            return .range(ForStatement.RangeFor(variable: variable, start: start, end: end, step: step, body: body))
        } else if let forEachClause = node.firstChild(ofKind: .forEachClause) {
            let exprs = forEachClause.children.filter { $0.kind != .token }
            guard let iterExpr = exprs.first else {
                throw ASTBuildError.missingChild("iterable", parent: .forEachClause)
            }
            let iterable = try buildExpression(iterExpr)
            let blocks = node.children(ofKind: .block)
            let body = try buildBlock(blocks.first ?? SyntaxNode(kind: .block, children: []))

            return .forEach(ForStatement.ForEachLoop(variable: variable, iterable: iterable, body: body))
        }

        throw ASTBuildError.missingChild("for clause", parent: .forStatement)
    }

    // MARK: - Declarations

    private func buildVariableDeclaration(_ node: SyntaxNode) throws -> VariableDeclaration {
        let position = tokenAt(node.children.first)?.position
        let name = identifierName(in: node)
        let type = try buildDataType(node.firstChild(ofKind: .typeAnnotation))
        let exprChildren = node.children.filter { $0.kind.isExpression }
        let initialValue: Expression? = exprChildren.isEmpty ? nil : try buildExpression(exprChildren[0])

        return VariableDeclaration(name: name, type: type, initialValue: initialValue, position: position)
    }

    private func buildConstantDeclaration(_ node: SyntaxNode) throws -> ConstantDeclaration {
        let position = tokenAt(node.children.first)?.position
        let name = identifierName(in: node)
        let type = try buildDataType(node.firstChild(ofKind: .typeAnnotation))
        let exprChildren = node.children.filter { $0.kind.isExpression }
        guard let exprNode = exprChildren.first else {
            throw ASTBuildError.missingChild("initial value", parent: .constantDeclaration)
        }
        let initialValue = try buildExpression(exprNode)

        return ConstantDeclaration(name: name, type: type, initialValue: initialValue, position: position)
    }

    private func buildGlobalDeclaration(_ node: SyntaxNode) throws -> GlobalDeclaration {
        let position = tokenAt(node.children.first)?.position
        let name = identifierName(in: node)
        let type = try buildDataType(node.firstChild(ofKind: .typeAnnotation))
        let exprChildren = node.children.filter { $0.kind.isExpression }
        let initialValue: Expression? = exprChildren.isEmpty ? nil : try buildExpression(exprChildren[0])

        return GlobalDeclaration(name: name, type: type, initialValue: initialValue, position: position)
    }

    private func buildFunctionDeclaration(_ node: SyntaxNode) throws -> FunctionDeclaration {
        let position = tokenAt(node.children.first)?.position
        let name = identifierName(in: node)
        let paramList = node.firstChild(ofKind: .parameterList)
        let parameters = try buildParameterList(paramList)

        let typeAnnotations = node.children(ofKind: .typeAnnotation)
        let returnType: DataType? = typeAnnotations.isEmpty ? nil : try buildDataType(typeAnnotations.first)

        let blocks = node.children(ofKind: .block)
        let body = try buildBlock(blocks.first ?? SyntaxNode(kind: .block, children: []))

        return FunctionDeclaration(
            name: name,
            parameters: parameters,
            returnType: returnType,
            localVariables: [],
            body: body,
            position: position
        )
    }

    private func buildProcedureDeclaration(_ node: SyntaxNode) throws -> ProcedureDeclaration {
        let position = tokenAt(node.children.first)?.position
        let name = identifierName(in: node)
        let paramList = node.firstChild(ofKind: .parameterList)
        let parameters = try buildParameterList(paramList)

        let blocks = node.children(ofKind: .block)
        let body = try buildBlock(blocks.first ?? SyntaxNode(kind: .block, children: []))

        return ProcedureDeclaration(
            name: name,
            parameters: parameters,
            localVariables: [],
            body: body,
            position: position
        )
    }

    private func buildClassDeclaration(_ node: SyntaxNode) throws -> ClassDeclaration {
        let position = tokenAt(node.children.first)?.position
        let name = identifierName(in: node)

        let members = try node.children(ofKind: .memberDeclaration).map { member -> MemberDeclaration in
            let memberName = identifierName(in: member)
            let type = try buildDataType(member.firstChild(ofKind: .typeAnnotation))
            return MemberDeclaration(name: memberName, type: type)
        }

        var constructor: ConstructorDeclaration?
        if let ctorNode = node.firstChild(ofKind: .constructorDeclaration) {
            let params = try buildParameterList(ctorNode.firstChild(ofKind: .parameterList))
            let blocks = ctorNode.children(ofKind: .block)
            let body = try buildBlock(blocks.first ?? SyntaxNode(kind: .block, children: []))
            constructor = ConstructorDeclaration(parameters: params, body: body)
        }

        let methods = try node.children(ofKind: .methodDeclaration).map { method -> MethodDeclaration in
            let methodName = identifierName(in: method)
            let params = try buildParameterList(method.firstChild(ofKind: .parameterList))
            let typeAnnotations = method.children(ofKind: .typeAnnotation)
            let retType: DataType? = typeAnnotations.isEmpty ? nil : try buildDataType(typeAnnotations.first)
            let blocks = method.children(ofKind: .block)
            let body = try buildBlock(blocks.first ?? SyntaxNode(kind: .block, children: []))
            return MethodDeclaration(name: methodName, parameters: params, returnType: retType, body: body)
        }

        return ClassDeclaration(
            name: name,
            superclass: nil,
            members: members,
            constructor: constructor,
            methods: methods,
            position: position
        )
    }

    private func buildReturnStatement(_ node: SyntaxNode) throws -> ReturnStatement {
        let exprChildren = node.children.filter { $0.kind.isExpression }
        let expression: Expression? = exprChildren.isEmpty ? nil : try buildExpression(exprChildren[0])
        return ReturnStatement(expression: expression)
    }

    // MARK: - Assignment

    private func buildAssignment(_ node: SyntaxNode) throws -> Assignment {
        let tokenChildren = node.children.filter { $0.isToken }
        let exprChildren = node.children.filter { $0.kind.isExpression }

        guard let firstToken = tokenChildren.first, let firstTok = tokenAt(firstToken) else {
            throw ASTBuildError.missingChild("identifier", parent: .assignmentStatement)
        }
        let identifier = firstTok.lexeme

        let hasLeftBracket = tokenChildren.contains { tokenAt($0)?.type == .leftBracket }
        let hasDot = tokenChildren.contains { tokenAt($0)?.type == .dot }

        if hasLeftBracket {
            let indexExprs = exprChildren.dropLast()
            guard let valueExpr = exprChildren.last else {
                throw ASTBuildError.missingChild("value", parent: .assignmentStatement)
            }
            var arrayExpr: Expression = .identifier(identifier)
            for indexNode in indexExprs {
                let indexExpr = try buildExpression(indexNode)
                arrayExpr = .arrayAccess(arrayExpr, indexExpr)
            }
            if case let .arrayAccess(array, index) = arrayExpr {
                return .arrayElement(Assignment.ArrayAccess(array: array, index: index), try buildExpression(valueExpr))
            }
            return .variable(identifier, try buildExpression(valueExpr))
        } else if hasDot {
            let fieldTokens = tokenChildren.filter { tokenAt($0)?.type == .identifier }
            guard let valueExpr = exprChildren.last else {
                throw ASTBuildError.missingChild("value", parent: .assignmentStatement)
            }
            var currentExpr: Expression = .identifier(identifier)
            for fieldTok in fieldTokens.dropFirst() {
                currentExpr = .fieldAccess(currentExpr, tokenAt(fieldTok)?.lexeme ?? "")
            }
            if case let .fieldAccess(obj, field) = currentExpr {
                return .fieldAccess(Assignment.FieldAccess(object: obj, field: field), try buildExpression(valueExpr))
            }
            return .variable(identifier, try buildExpression(valueExpr))
        } else {
            guard let valueExpr = exprChildren.last else {
                throw ASTBuildError.missingChild("value", parent: .assignmentStatement)
            }
            return .variable(identifier, try buildExpression(valueExpr))
        }
    }

    // MARK: - Expression Building

    private func buildExpression(_ node: SyntaxNode) throws -> Expression {
        switch node.kind {
        case .literalExpr:
            guard let tokNode = node.children.first, let tok = tokenAt(tokNode) else {
                throw ASTBuildError.missingChild("literal token", parent: .literalExpr)
            }
            guard let literal = Literal(token: tok) else {
                throw ASTBuildError.invalidLiteral(tok.lexeme)
            }
            return .literal(literal)

        case .identifierExpr:
            guard let tokNode = node.children.first, let tok = tokenAt(tokNode) else {
                throw ASTBuildError.missingChild("identifier token", parent: .identifierExpr)
            }
            return .identifier(tok.lexeme)

        case .binaryExpr:
            guard node.children.count >= 3 else {
                throw ASTBuildError.missingChild("operands", parent: .binaryExpr)
            }
            let left = try buildExpression(node.children[0])
            guard let opTok = tokenAt(node.children[1]),
                  let op = BinaryOperator(tokenType: opTok.type) else {
                throw ASTBuildError.missingChild("operator", parent: .binaryExpr)
            }
            let right = try buildExpression(node.children[2])
            return .binary(op, left, right)

        case .unaryExpr:
            guard node.children.count >= 2 else {
                throw ASTBuildError.missingChild("operand", parent: .unaryExpr)
            }
            guard let opTok = tokenAt(node.children[0]),
                  let op = UnaryOperator(tokenType: opTok.type) else {
                throw ASTBuildError.missingChild("operator", parent: .unaryExpr)
            }
            let operand = try buildExpression(node.children[1])
            return .unary(op, operand)

        case .callExpr:
            guard let nameNode = node.children.first else {
                throw ASTBuildError.missingChild("name", parent: .callExpr)
            }
            let name: String
            if nameNode.kind == .identifierExpr, let tok = nameNode.children.first, let resolved = tokenAt(tok) {
                name = resolved.lexeme
            } else if let resolved = tokenAt(nameNode) {
                name = resolved.lexeme
            } else {
                throw ASTBuildError.missingChild("name token", parent: .callExpr)
            }

            let argList = node.firstChild(ofKind: .argumentList)
            let args = try buildArgumentList(argList)
            return .functionCall(name, args)

        case .methodCallExpr:
            let nonTokenChildren = node.children.filter { !$0.isToken }
            guard let receiverNode = nonTokenChildren.first else {
                throw ASTBuildError.missingChild("receiver", parent: .methodCallExpr)
            }
            let receiver = try buildExpression(receiverNode)

            let identTokens = node.children.filter { $0.isToken && tokenAt($0)?.type == .identifier }
            guard let methodToken = identTokens.last, let methodTok = tokenAt(methodToken) else {
                throw ASTBuildError.missingChild("method name", parent: .methodCallExpr)
            }

            let argList = node.firstChild(ofKind: .argumentList)
            let args = try buildArgumentList(argList)
            return .methodCall(receiver, methodTok.lexeme, args)

        case .arrayAccessExpr:
            let nonTokenChildren = node.children.filter { !$0.isToken }
            guard nonTokenChildren.count >= 2 else {
                throw ASTBuildError.missingChild("array and index", parent: .arrayAccessExpr)
            }
            var arrayExpr = try buildExpression(nonTokenChildren[0])
            for indexNode in nonTokenChildren.dropFirst() {
                let indexExpr = try buildExpression(indexNode)
                arrayExpr = .arrayAccess(arrayExpr, indexExpr)
            }
            return arrayExpr

        case .fieldAccessExpr:
            let nonTokenChildren = node.children.filter { !$0.isToken }
            guard let objNode = nonTokenChildren.first else {
                throw ASTBuildError.missingChild("object", parent: .fieldAccessExpr)
            }
            let obj = try buildExpression(objNode)
            let identTokens = node.children.filter { $0.isToken && tokenAt($0)?.type == .identifier }
            guard let fieldToken = identTokens.last, let fieldTok = tokenAt(fieldToken) else {
                throw ASTBuildError.missingChild("field name", parent: .fieldAccessExpr)
            }
            return .fieldAccess(obj, fieldTok.lexeme)

        case .arrayLiteralExpr:
            let exprChildren = node.children.filter { $0.kind.isExpression }
            let elements = try exprChildren.map { try buildExpression($0) }
            return .arrayLiteral(elements)

        case .parenExpr:
            let exprChildren = node.children.filter { $0.kind.isExpression }
            guard let inner = exprChildren.first else {
                throw ASTBuildError.missingChild("inner expression", parent: .parenExpr)
            }
            return try buildExpression(inner)

        default:
            throw ASTBuildError.unexpectedKind(node.kind)
        }
    }

    // MARK: - Helpers

    private func buildBlock(_ node: SyntaxNode) throws -> [Statement] {
        guard node.kind == .block else {
            return [try buildStatement(node)]
        }
        return try node.children.map { try buildStatement($0) }
    }

    private func buildParameterList(_ node: SyntaxNode?) throws -> [Parameter] {
        guard let paramList = node else { return [] }
        return try paramList.children(ofKind: .parameter).map { paramNode in
            let name = identifierName(in: paramNode)
            let type = try buildDataType(paramNode.firstChild(ofKind: .typeAnnotation))
            return Parameter(name: name, type: type)
        }
    }

    private func buildArgumentList(_ node: SyntaxNode?) throws -> [Expression] {
        guard let argList = node else { return [] }
        let exprChildren = argList.children.filter { $0.kind.isExpression }
        return try exprChildren.map { try buildExpression($0) }
    }

    private func buildDataType(_ node: SyntaxNode?) throws -> DataType {
        guard let typeNode = node else {
            throw ASTBuildError.missingChild("type", parent: .typeAnnotation)
        }
        guard let firstToken = typeNode.children.first, let tok = tokenAt(firstToken) else {
            throw ASTBuildError.missingChild("type token", parent: .typeAnnotation)
        }

        if let basicType = DataType(tokenType: tok.type) {
            return basicType
        }

        if tok.type == .identifier {
            let typeName = tok.lexeme.lowercased()
            switch typeName {
            case "integer", "int", "整数型", "整数":
                return .integer
            case "real", "double", "float", "実数型", "実数":
                return .real
            case "string", "str", "文字列型", "文字列":
                return .string
            case "character", "char", "文字型", "文字":
                return .character
            case "boolean", "bool", "論理型", "論理", "ブール":
                return .boolean
            case "array", "配列型", "配列":
                let nestedTypes = typeNode.children(ofKind: .typeAnnotation)
                if let nested = nestedTypes.first {
                    return .array(try buildDataType(nested))
                }
                return .array(.integer)
            case "record", "レコード型", "レコード":
                let identTokens = typeNode.children.filter { $0.isToken && tokenAt($0)?.type == .identifier }
                if let nameToken = identTokens.dropFirst().first, let nameTok = tokenAt(nameToken) {
                    return .record(nameTok.lexeme)
                }
                return .record(tok.lexeme)
            default:
                return .record(tok.lexeme)
            }
        }

        if tok.type == .arrayType {
            let nestedTypes = typeNode.children(ofKind: .typeAnnotation)
            if let nested = nestedTypes.first {
                return .array(try buildDataType(nested))
            }
            return .array(.integer)
        }
        if tok.type == .recordType {
            let identTokens = typeNode.children.filter { $0.isToken && tokenAt($0)?.type == .identifier }
            if let nameToken = identTokens.first, let nameTok = tokenAt(nameToken) {
                return .record(nameTok.lexeme)
            }
        }

        throw ASTBuildError.unknownType(tok.lexeme)
    }

    private func tokenAt(_ node: SyntaxNode?) -> Token? {
        guard let syntaxNode = node, let idx = syntaxNode.tokenIndex, idx < tokens.count else { return nil }
        return tokens[idx]
    }

    private func tokenLexeme(_ node: SyntaxNode) -> String {
        if let idx = node.tokenIndex, idx < tokens.count {
            return tokens[idx].lexeme
        }
        if let first = node.children.first {
            return tokenLexeme(first)
        }
        return ""
    }

    private func identifierName(in node: SyntaxNode) -> String {
        for child in node.children {
            if child.isToken, let tok = tokenAt(child), tok.type == .identifier {
                return tok.lexeme
            }
        }
        return ""
    }
}

// MARK: - ASTBuildError

public enum ASTBuildError: Error, Equatable, Sendable {
    case expectedKind(SyntaxKind, got: SyntaxKind)
    case unexpectedKind(SyntaxKind)
    case missingChild(String, parent: SyntaxKind)
    case invalidLiteral(String)
    case unknownType(String)
}

extension ASTBuildError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .expectedKind(let expected, let got):
            return "Expected CST node kind '\(expected)' but got '\(got)'"
        case .unexpectedKind(let kind):
            return "Unexpected CST node kind '\(kind)'"
        case .missingChild(let desc, parent: let parent):
            return "Missing \(desc) in \(parent) node"
        case .invalidLiteral(let text):
            return "Invalid literal: '\(text)'"
        case .unknownType(let name):
            return "Unknown type: '\(name)'"
        }
    }
}
