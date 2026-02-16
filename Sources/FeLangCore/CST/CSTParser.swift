import Foundation

/// Parses a token stream into a concrete syntax tree (CST).
///
/// Unlike `StatementParser` which directly builds AST nodes, `CSTParser`
/// preserves the full token structure so that an `ASTBuilder` can later
/// convert the tree without re-scanning the token stream.
public struct CSTParser {

    public init() {}

    // MARK: - Public API

    /// Parses tokens into a CST rooted at a `sourceFile` node.
    ///
    /// The source file is structured as:
    /// ```
    /// sourceFile {
    ///   importList { ... }      // top-level declarations (variable, constant, global)
    ///   declarationList { ... } // function, procedure, class declarations
    /// }
    /// ```
    public func parse(_ tokens: [Token]) throws -> SyntaxNode {
        guard tokens.count <= 100_000 else {
            throw CSTParsingError.inputTooLarge
        }

        var stream = CSTTokenStream(tokens)
        var importChildren: [SyntaxNode] = []
        var declChildren: [SyntaxNode] = []
        var nestingDepth = 0
        let maxNestingDepth = 100

        while let token = stream.peek(), token.type != .eof {
            if token.type == .whitespace || token.type == .newline {
                _ = stream.advance()
                continue
            }

            switch token.type {
            case .ifKeyword, .whileKeyword, .forKeyword,
                 .functionKeyword, .procedureKeyword, .classKeyword:
                nestingDepth += 1
                guard nestingDepth <= maxNestingDepth else {
                    throw CSTParsingError.nestingTooDeep
                }
            case .endifKeyword, .endwhileKeyword, .endforKeyword,
                 .endfunctionKeyword, .endprocedureKeyword, .endclassKeyword:
                nestingDepth = max(0, nestingDepth - 1)
            default:
                break
            }

            let isTopLevelDecl = token.type == .variableKeyword
                || token.type == .constantKeyword
                || token.type == .globalKeyword
            let isFuncOrClass = token.type == .functionKeyword
                || token.type == .procedureKeyword
                || token.type == .classKeyword

            if isTopLevelDecl && declChildren.isEmpty {
                let node = try parseStatement(&stream, nestingDepth: nestingDepth)
                importChildren.append(node)
            } else if isFuncOrClass {
                let node = try parseStatement(&stream, nestingDepth: nestingDepth)
                declChildren.append(node)
            } else {
                let node = try parseStatement(&stream, nestingDepth: nestingDepth)
                declChildren.append(node)
            }
        }

        let importList = SyntaxNode(
            kind: .importList,
            children: importChildren,
            startTokenIndex: 0,
            endTokenIndex: importChildren.last?.endTokenIndex ?? 0
        )
        let declList = SyntaxNode(
            kind: .declarationList,
            children: declChildren,
            startTokenIndex: importList.endTokenIndex,
            endTokenIndex: declChildren.last?.endTokenIndex ?? importList.endTokenIndex
        )

        return SyntaxNode(
            kind: .sourceFile,
            children: [importList, declList],
            startTokenIndex: 0,
            endTokenIndex: stream.index
        )
    }

    // MARK: - Statement Parsing

    private func parseStatement(_ stream: inout CSTTokenStream, nestingDepth: Int = 0) throws -> SyntaxNode {
        guard let token = stream.peek() else {
            throw CSTParsingError.unexpectedEndOfInput
        }

        switch token.type {
        case .ifKeyword:
            return try parseIfStatement(&stream, nestingDepth: nestingDepth)
        case .whileKeyword:
            return try parseWhileStatement(&stream, nestingDepth: nestingDepth)
        case .doKeyword:
            return try parseDoWhileStatement(&stream, nestingDepth: nestingDepth)
        case .forKeyword:
            return try parseForStatement(&stream, nestingDepth: nestingDepth)
        case .variableKeyword:
            return try parseVariableDeclaration(&stream)
        case .constantKeyword:
            return try parseConstantDeclaration(&stream)
        case .globalKeyword:
            return try parseGlobalDeclaration(&stream)
        case .functionKeyword:
            return try parseFunctionDeclaration(&stream, nestingDepth: nestingDepth)
        case .procedureKeyword:
            return try parseProcedureDeclaration(&stream, nestingDepth: nestingDepth)
        case .classKeyword:
            return try parseClassDeclaration(&stream, nestingDepth: nestingDepth)
        case .returnKeyword:
            return try parseReturnStatement(&stream)
        case .breakKeyword:
            let idx = stream.index
            _ = stream.advance()
            return SyntaxNode(kind: .breakStatement, children: [SyntaxNode(token: idx)])
        case .continueKeyword:
            let idx = stream.index
            _ = stream.advance()
            return SyntaxNode(kind: .continueStatement, children: [SyntaxNode(token: idx)])
        case .identifier:
            return try parseAssignmentOrExpressionStatement(&stream)
        default:
            return try parseExpressionStatement(&stream)
        }
    }

    // MARK: - Control Flow

    private func parseIfStatement(_ stream: inout CSTTokenStream, nestingDepth: Int) throws -> SyntaxNode {
        var children: [SyntaxNode] = []
        children.append(try consumeToken(&stream, .ifKeyword))

        let condition = try parseExpression(&stream)
        children.append(SyntaxNode(kind: .conditionClause, children: [condition]))

        children.append(try consumeToken(&stream, .thenKeyword))

        let thenBody = try parseBlock(&stream,
                                       until: [.elseKeyword, .elifKeyword, .elseifKeyword, .endifKeyword],
                                       nestingDepth: nestingDepth)
        children.append(SyntaxNode(kind: .thenClause, children: [thenBody]))

        while stream.peek()?.type == .elifKeyword || stream.peek()?.type == .elseifKeyword {
            var elseIfChildren: [SyntaxNode] = []
            elseIfChildren.append(SyntaxNode(token: stream.index))
            _ = stream.advance()
            let elifCond = try parseExpression(&stream)
            elseIfChildren.append(SyntaxNode(kind: .conditionClause, children: [elifCond]))
            elseIfChildren.append(try consumeToken(&stream, .thenKeyword))
            let elifBody = try parseBlock(&stream,
                                           until: [.elseKeyword, .elifKeyword, .elseifKeyword, .endifKeyword],
                                           nestingDepth: nestingDepth)
            elseIfChildren.append(SyntaxNode(kind: .thenClause, children: [elifBody]))
            children.append(SyntaxNode(kind: .elseIfClause, children: elseIfChildren))
        }

        if stream.peek()?.type == .elseKeyword {
            var elseChildren: [SyntaxNode] = []
            elseChildren.append(SyntaxNode(token: stream.index))
            _ = stream.advance()
            let elseBody = try parseBlock(&stream, until: [.endifKeyword], nestingDepth: nestingDepth)
            elseChildren.append(elseBody)
            children.append(SyntaxNode(kind: .elseClause, children: elseChildren))
        }

        children.append(try consumeToken(&stream, .endifKeyword))

        return SyntaxNode(kind: .ifStatement, children: children)
    }

    private func parseWhileStatement(_ stream: inout CSTTokenStream, nestingDepth: Int) throws -> SyntaxNode {
        var children: [SyntaxNode] = []
        children.append(try consumeToken(&stream, .whileKeyword))
        let cond = try parseExpression(&stream)
        children.append(SyntaxNode(kind: .conditionClause, children: [cond]))
        children.append(try consumeToken(&stream, .doKeyword))
        let body = try parseBlock(&stream, until: [.endwhileKeyword], nestingDepth: nestingDepth)
        children.append(body)
        children.append(try consumeToken(&stream, .endwhileKeyword))
        return SyntaxNode(kind: .whileStatement, children: children)
    }

    private func parseDoWhileStatement(_ stream: inout CSTTokenStream, nestingDepth: Int) throws -> SyntaxNode {
        var children: [SyntaxNode] = []
        children.append(try consumeToken(&stream, .doKeyword))
        let body = try parseDoWhileBody(&stream, nestingDepth: nestingDepth)
        children.append(body)
        children.append(try consumeToken(&stream, .whileKeyword))
        children.append(try consumeToken(&stream, .leftParen))
        let cond = try parseExpression(&stream)
        children.append(SyntaxNode(kind: .conditionClause, children: [cond]))
        children.append(try consumeToken(&stream, .rightParen))
        return SyntaxNode(kind: .doWhileStatement, children: children)
    }

    private func parseDoWhileBody(_ stream: inout CSTTokenStream, nestingDepth: Int) throws -> SyntaxNode {
        guard nestingDepth < 100 else { throw CSTParsingError.nestingTooDeep }
        var stmts: [SyntaxNode] = []
        while let token = stream.peek(), token.type != .eof {
            if token.type == .newline || token.type == .whitespace {
                _ = stream.advance()
                continue
            }
            if token.type == .whileKeyword {
                if let next = stream.peek(offset: 1), next.type == .leftParen {
                    break
                }
            }
            stmts.append(try parseStatement(&stream, nestingDepth: nestingDepth + 1))
        }
        return SyntaxNode(kind: .block, children: stmts)
    }

    private func parseForStatement(_ stream: inout CSTTokenStream, nestingDepth: Int) throws -> SyntaxNode {
        var children: [SyntaxNode] = []
        children.append(try consumeToken(&stream, .forKeyword))

        guard let varToken = stream.peek(), varToken.type == .identifier else {
            throw CSTParsingError.expectedIdentifier
        }
        children.append(SyntaxNode(token: stream.index))
        _ = stream.advance()

        if stream.peek()?.type == .assign {
            var rangeChildren: [SyntaxNode] = []
            rangeChildren.append(SyntaxNode(token: stream.index))
            _ = stream.advance()
            rangeChildren.append(try parseExpression(&stream))
            rangeChildren.append(try consumeToken(&stream, .toKeyword))
            rangeChildren.append(try parseExpression(&stream))
            if stream.peek()?.type == .stepKeyword {
                rangeChildren.append(SyntaxNode(token: stream.index))
                _ = stream.advance()
                rangeChildren.append(try parseExpression(&stream))
            }
            children.append(SyntaxNode(kind: .forRangeClause, children: rangeChildren))
        } else if stream.peek()?.type == .inKeyword {
            var forEachChildren: [SyntaxNode] = []
            forEachChildren.append(SyntaxNode(token: stream.index))
            _ = stream.advance()
            forEachChildren.append(try parseExpression(&stream))
            children.append(SyntaxNode(kind: .forEachClause, children: forEachChildren))
        } else {
            throw CSTParsingError.expectedToken(.assign)
        }

        children.append(try consumeToken(&stream, .doKeyword))
        let body = try parseBlock(&stream, until: [.endforKeyword], nestingDepth: nestingDepth)
        children.append(body)
        children.append(try consumeToken(&stream, .endforKeyword))

        return SyntaxNode(kind: .forStatement, children: children)
    }

    // MARK: - Declarations

    private func parseVariableDeclaration(_ stream: inout CSTTokenStream) throws -> SyntaxNode {
        var children: [SyntaxNode] = []
        children.append(try consumeToken(&stream, .variableKeyword))
        guard stream.peek()?.type == .identifier else { throw CSTParsingError.expectedIdentifier }
        children.append(SyntaxNode(token: stream.index))
        _ = stream.advance()
        children.append(try consumeToken(&stream, .colon))
        children.append(try parseTypeAnnotation(&stream))
        if stream.peek()?.type == .assign {
            children.append(SyntaxNode(token: stream.index))
            _ = stream.advance()
            children.append(try parseExpression(&stream))
        }
        return SyntaxNode(kind: .variableDeclaration, children: children)
    }

    private func parseConstantDeclaration(_ stream: inout CSTTokenStream) throws -> SyntaxNode {
        var children: [SyntaxNode] = []
        children.append(try consumeToken(&stream, .constantKeyword))
        guard stream.peek()?.type == .identifier else { throw CSTParsingError.expectedIdentifier }
        children.append(SyntaxNode(token: stream.index))
        _ = stream.advance()
        children.append(try consumeToken(&stream, .colon))
        children.append(try parseTypeAnnotation(&stream))
        children.append(try consumeToken(&stream, .assign))
        children.append(try parseExpression(&stream))
        return SyntaxNode(kind: .constantDeclaration, children: children)
    }

    private func parseGlobalDeclaration(_ stream: inout CSTTokenStream) throws -> SyntaxNode {
        var children: [SyntaxNode] = []
        children.append(try consumeToken(&stream, .globalKeyword))
        children.append(try consumeToken(&stream, .colon))
        children.append(try parseTypeAnnotation(&stream))
        children.append(try consumeToken(&stream, .colon))
        guard stream.peek()?.type == .identifier else { throw CSTParsingError.expectedIdentifier }
        children.append(SyntaxNode(token: stream.index))
        _ = stream.advance()
        if stream.peek()?.type == .assign {
            children.append(SyntaxNode(token: stream.index))
            _ = stream.advance()
            children.append(try parseExpression(&stream))
        }
        return SyntaxNode(kind: .globalDeclaration, children: children)
    }

    private func parseFunctionDeclaration(_ stream: inout CSTTokenStream, nestingDepth: Int) throws -> SyntaxNode {
        var children: [SyntaxNode] = []
        children.append(try consumeToken(&stream, .functionKeyword))
        guard stream.peek()?.type == .identifier else { throw CSTParsingError.expectedIdentifier }
        children.append(SyntaxNode(token: stream.index))
        _ = stream.advance()
        children.append(try consumeToken(&stream, .leftParen))
        children.append(try parseParameterList(&stream))
        children.append(try consumeToken(&stream, .rightParen))
        if stream.peek()?.type == .colon {
            children.append(SyntaxNode(token: stream.index))
            _ = stream.advance()
            children.append(try parseTypeAnnotation(&stream))
        }
        let body = try parseFunctionBody(&stream, endToken: .endfunctionKeyword, nestingDepth: nestingDepth)
        children.append(body)
        children.append(try consumeToken(&stream, .endfunctionKeyword))
        return SyntaxNode(kind: .functionDeclaration, children: children)
    }

    private func parseProcedureDeclaration(_ stream: inout CSTTokenStream, nestingDepth: Int) throws -> SyntaxNode {
        var children: [SyntaxNode] = []
        children.append(try consumeToken(&stream, .procedureKeyword))
        guard stream.peek()?.type == .identifier else { throw CSTParsingError.expectedIdentifier }
        children.append(SyntaxNode(token: stream.index))
        _ = stream.advance()
        children.append(try consumeToken(&stream, .leftParen))
        children.append(try parseParameterList(&stream))
        children.append(try consumeToken(&stream, .rightParen))
        let body = try parseFunctionBody(&stream, endToken: .endprocedureKeyword, nestingDepth: nestingDepth)
        children.append(body)
        children.append(try consumeToken(&stream, .endprocedureKeyword))
        return SyntaxNode(kind: .procedureDeclaration, children: children)
    }

    private func parseClassDeclaration(_ stream: inout CSTTokenStream, nestingDepth: Int) throws -> SyntaxNode {
        var children: [SyntaxNode] = []
        children.append(try consumeToken(&stream, .classKeyword))
        guard stream.peek()?.type == .identifier else { throw CSTParsingError.expectedIdentifier }
        let className = stream.peek()!.lexeme
        children.append(SyntaxNode(token: stream.index))
        _ = stream.advance()

        while let token = stream.peek(), token.type != .endclassKeyword && token.type != .eof {
            if token.type == .newline || token.type == .whitespace {
                _ = stream.advance()
                continue
            }
            if token.type == .identifier && token.lexeme == className {
                if let next = stream.peek(offset: 1), next.type == .leftParen {
                    children.append(try parseConstructorDecl(&stream))
                    continue
                }
            }
            if token.type == .functionKeyword {
                children.append(try parseMethodDecl(&stream, nestingDepth: nestingDepth))
                continue
            }
            if token.type == .identifier {
                if let next = stream.peek(offset: 1), next.type == .colon {
                    children.append(try parseMemberDecl(&stream))
                    continue
                }
            }
            throw CSTParsingError.unexpectedToken(token)
        }

        children.append(try consumeToken(&stream, .endclassKeyword))
        return SyntaxNode(kind: .classDeclaration, children: children)
    }

    private func parseMemberDecl(_ stream: inout CSTTokenStream) throws -> SyntaxNode {
        var children: [SyntaxNode] = []
        children.append(SyntaxNode(token: stream.index))
        _ = stream.advance()
        children.append(try consumeToken(&stream, .colon))
        children.append(try parseTypeAnnotation(&stream))
        return SyntaxNode(kind: .memberDeclaration, children: children)
    }

    private func parseConstructorDecl(_ stream: inout CSTTokenStream) throws -> SyntaxNode {
        var children: [SyntaxNode] = []
        children.append(SyntaxNode(token: stream.index))
        _ = stream.advance()
        children.append(try consumeToken(&stream, .leftParen))
        children.append(try parseParameterList(&stream))
        children.append(try consumeToken(&stream, .rightParen))
        let body = try parseClassMemberBody(&stream)
        children.append(body)
        return SyntaxNode(kind: .constructorDeclaration, children: children)
    }

    private func parseMethodDecl(_ stream: inout CSTTokenStream, nestingDepth: Int) throws -> SyntaxNode {
        var children: [SyntaxNode] = []
        children.append(try consumeToken(&stream, .functionKeyword))
        guard stream.peek()?.type == .identifier else { throw CSTParsingError.expectedIdentifier }
        children.append(SyntaxNode(token: stream.index))
        _ = stream.advance()
        children.append(try consumeToken(&stream, .leftParen))
        children.append(try parseParameterList(&stream))
        children.append(try consumeToken(&stream, .rightParen))
        if stream.peek()?.type == .colon {
            children.append(SyntaxNode(token: stream.index))
            _ = stream.advance()
            children.append(try parseTypeAnnotation(&stream))
        }
        let body = try parseBlock(&stream, until: [.endfunctionKeyword], nestingDepth: nestingDepth)
        children.append(body)
        children.append(try consumeToken(&stream, .endfunctionKeyword))
        return SyntaxNode(kind: .methodDeclaration, children: children)
    }

    private func parseClassMemberBody(_ stream: inout CSTTokenStream) throws -> SyntaxNode {
        var stmts: [SyntaxNode] = []
        while let token = stream.peek() {
            if token.type == .newline || token.type == .whitespace {
                _ = stream.advance()
                continue
            }
            if token.type == .endclassKeyword || token.type == .functionKeyword || token.type == .eof {
                break
            }
            if token.type == .identifier {
                if let next = stream.peek(offset: 1) {
                    if next.type == .colon || next.type == .leftParen { break }
                }
            }
            stmts.append(try parseStatement(&stream))
        }
        return SyntaxNode(kind: .block, children: stmts)
    }

    private func parseReturnStatement(_ stream: inout CSTTokenStream) throws -> SyntaxNode {
        var children: [SyntaxNode] = []
        children.append(try consumeToken(&stream, .returnKeyword))
        if let token = stream.peek(), token.type != .newline && token.type != .eof {
            children.append(try parseExpression(&stream))
        }
        return SyntaxNode(kind: .returnStatement, children: children)
    }

    // MARK: - Assignment / Expression Statement

    private func parseAssignmentOrExpressionStatement(_ stream: inout CSTTokenStream) throws -> SyntaxNode {
        guard let first = stream.peek(), first.type == .identifier else {
            return try parseExpressionStatement(&stream)
        }

        if let next = stream.peek(offset: 1), next.type == .assign {
            return try parseAssignment(&stream)
        }

        if let next = stream.peek(offset: 1), next.type == .leftBracket {
            if isArrayAssignment(&stream) {
                return try parseAssignment(&stream)
            }
        }

        if let next = stream.peek(offset: 1), next.type == .dot {
            if isFieldAssignment(&stream) {
                return try parseAssignment(&stream)
            }
        }

        return try parseExpressionStatement(&stream)
    }

    private func isArrayAssignment(_ stream: inout CSTTokenStream) -> Bool {
        var offset = 2
        var bracketCount = 1
        while bracketCount > 0 {
            guard let token = stream.peek(offset: offset) else { return false }
            if token.type == .leftBracket { bracketCount += 1 }
            if token.type == .rightBracket { bracketCount -= 1 }
            offset += 1
        }
        return stream.peek(offset: offset)?.type == .assign
    }

    private func isFieldAssignment(_ stream: inout CSTTokenStream) -> Bool {
        var offset = 2
        while let token = stream.peek(offset: offset) {
            if token.type == .identifier {
                offset += 1
                if stream.peek(offset: offset)?.type == .dot {
                    offset += 1
                    continue
                }
                break
            } else {
                break
            }
        }
        return stream.peek(offset: offset)?.type == .assign
    }

    private func parseAssignment(_ stream: inout CSTTokenStream) throws -> SyntaxNode {
        var children: [SyntaxNode] = []

        children.append(SyntaxNode(token: stream.index))
        _ = stream.advance()

        if stream.peek()?.type == .leftBracket {
            children.append(SyntaxNode(token: stream.index))
            _ = stream.advance()
            children.append(try parseExpression(&stream))
            while stream.peek()?.type == .comma {
                children.append(SyntaxNode(token: stream.index))
                _ = stream.advance()
                children.append(try parseExpression(&stream))
            }
            children.append(try consumeToken(&stream, .rightBracket))
        } else if stream.peek()?.type == .dot {
            while stream.peek()?.type == .dot {
                children.append(SyntaxNode(token: stream.index))
                _ = stream.advance()
                guard stream.peek()?.type == .identifier else { throw CSTParsingError.expectedIdentifier }
                children.append(SyntaxNode(token: stream.index))
                _ = stream.advance()
            }
        }

        children.append(try consumeToken(&stream, .assign))
        children.append(try parseExpression(&stream))

        return SyntaxNode(kind: .assignmentStatement, children: children)
    }

    private func parseExpressionStatement(_ stream: inout CSTTokenStream) throws -> SyntaxNode {
        let expr = try parseExpression(&stream)
        return SyntaxNode(kind: .expressionStatement, children: [expr])
    }

    // MARK: - Expression Parsing

    private func parseExpression(_ stream: inout CSTTokenStream) throws -> SyntaxNode {
        return try parseExpressionWithPrecedence(&stream, minPrecedence: 0)
    }

    private func parseExpressionWithPrecedence(_ stream: inout CSTTokenStream, minPrecedence: Int) throws -> SyntaxNode {
        var left = try parseUnaryExpression(&stream)

        while let token = stream.peek(),
              let op = BinaryOperator(tokenType: token.type),
              op.precedence >= minPrecedence {
            let opNode = SyntaxNode(token: stream.index)
            _ = stream.advance()
            let nextMin = op.isLeftAssociative ? op.precedence + 1 : op.precedence
            let right = try parseExpressionWithPrecedence(&stream, minPrecedence: nextMin)
            left = SyntaxNode(kind: .binaryExpr, children: [left, opNode, right])
        }

        return left
    }

    private func parseUnaryExpression(_ stream: inout CSTTokenStream) throws -> SyntaxNode {
        if let token = stream.peek(), UnaryOperator(tokenType: token.type) != nil {
            let opNode = SyntaxNode(token: stream.index)
            _ = stream.advance()
            let operand = try parseUnaryExpression(&stream)
            return SyntaxNode(kind: .unaryExpr, children: [opNode, operand])
        }
        return try parsePostfixExpression(&stream)
    }

    private func parsePostfixExpression(_ stream: inout CSTTokenStream) throws -> SyntaxNode {
        var expr = try parsePrimaryExpression(&stream)

        while true {
            if stream.peek()?.type == .leftBracket {
                var children: [SyntaxNode] = [expr]
                children.append(SyntaxNode(token: stream.index))
                _ = stream.advance()
                children.append(try parseExpression(&stream))
                while stream.peek()?.type == .comma {
                    children.append(SyntaxNode(token: stream.index))
                    _ = stream.advance()
                    children.append(try parseExpression(&stream))
                }
                children.append(try consumeToken(&stream, .rightBracket))
                expr = SyntaxNode(kind: .arrayAccessExpr, children: children)
            } else if stream.peek()?.type == .dot {
                let dotNode = SyntaxNode(token: stream.index)
                _ = stream.advance()
                guard let field = stream.peek(), field.type == .identifier else {
                    throw CSTParsingError.expectedIdentifier
                }
                let fieldNode = SyntaxNode(token: stream.index)
                _ = stream.advance()

                if stream.peek()?.type == .leftParen {
                    var children: [SyntaxNode] = [expr, dotNode, fieldNode]
                    children.append(SyntaxNode(token: stream.index))
                    _ = stream.advance()
                    children.append(try parseArgumentList(&stream))
                    children.append(try consumeToken(&stream, .rightParen))
                    expr = SyntaxNode(kind: .methodCallExpr, children: children)
                } else {
                    expr = SyntaxNode(kind: .fieldAccessExpr, children: [expr, dotNode, fieldNode])
                }
            } else if stream.peek()?.type == .leftParen,
                      case .identifierExpr = expr.kind {
                var children: [SyntaxNode] = [expr]
                children.append(SyntaxNode(token: stream.index))
                _ = stream.advance()
                children.append(try parseArgumentList(&stream))
                children.append(try consumeToken(&stream, .rightParen))
                expr = SyntaxNode(kind: .callExpr, children: children)
            } else {
                break
            }
        }

        return expr
    }

    private func parsePrimaryExpression(_ stream: inout CSTTokenStream) throws -> SyntaxNode {
        guard let token = stream.peek() else {
            throw CSTParsingError.unexpectedEndOfInput
        }

        if Literal(token: token) != nil {
            let node = SyntaxNode(kind: .literalExpr, children: [SyntaxNode(token: stream.index)])
            _ = stream.advance()
            return node
        }

        if token.type == .identifier {
            let node = SyntaxNode(kind: .identifierExpr, children: [SyntaxNode(token: stream.index)])
            _ = stream.advance()
            return node
        }

        if token.type == .leftParen {
            var children: [SyntaxNode] = []
            children.append(SyntaxNode(token: stream.index))
            _ = stream.advance()
            children.append(try parseExpression(&stream))
            children.append(try consumeToken(&stream, .rightParen))
            return SyntaxNode(kind: .parenExpr, children: children)
        }

        if token.type == .leftBracket {
            return try parseArrayLiteral(&stream, closing: .rightBracket)
        }
        if token.type == .leftBrace {
            return try parseArrayLiteral(&stream, closing: .rightBrace)
        }

        throw CSTParsingError.expectedExpression(token)
    }

    private func parseArrayLiteral(_ stream: inout CSTTokenStream, closing: TokenType) throws -> SyntaxNode {
        var children: [SyntaxNode] = []
        children.append(SyntaxNode(token: stream.index))
        _ = stream.advance()

        if stream.peek()?.type != closing {
            children.append(try parseExpression(&stream))
            while stream.peek()?.type == .comma {
                children.append(SyntaxNode(token: stream.index))
                _ = stream.advance()
                children.append(try parseExpression(&stream))
            }
        }

        children.append(try consumeToken(&stream, closing))
        return SyntaxNode(kind: .arrayLiteralExpr, children: children)
    }

    // MARK: - Helpers

    private func parseBlock(
        _ stream: inout CSTTokenStream,
        until endTokens: [TokenType],
        nestingDepth: Int = 0
    ) throws -> SyntaxNode {
        guard nestingDepth < 100 else { throw CSTParsingError.nestingTooDeep }
        var stmts: [SyntaxNode] = []
        while let token = stream.peek(), !endTokens.contains(token.type) && token.type != .eof {
            if token.type == .newline || token.type == .whitespace {
                _ = stream.advance()
                continue
            }
            stmts.append(try parseStatement(&stream, nestingDepth: nestingDepth + 1))
        }
        return SyntaxNode(kind: .block, children: stmts)
    }

    private func parseFunctionBody(
        _ stream: inout CSTTokenStream,
        endToken: TokenType,
        nestingDepth: Int
    ) throws -> SyntaxNode {
        guard nestingDepth < 100 else { throw CSTParsingError.nestingTooDeep }
        var stmts: [SyntaxNode] = []
        while let token = stream.peek(), token.type != endToken && token.type != .eof {
            if token.type == .newline || token.type == .whitespace {
                _ = stream.advance()
                continue
            }
            stmts.append(try parseStatement(&stream, nestingDepth: nestingDepth + 1))
        }
        return SyntaxNode(kind: .block, children: stmts)
    }

    private func parseParameterList(_ stream: inout CSTTokenStream) throws -> SyntaxNode {
        let start = stream.index
        var params: [SyntaxNode] = []
        if stream.peek()?.type == .rightParen {
            return SyntaxNode(kind: .parameterList, children: [], startTokenIndex: start, endTokenIndex: start)
        }
        params.append(try parseParameter(&stream))
        while stream.peek()?.type == .comma {
            params.append(SyntaxNode(token: stream.index))
            _ = stream.advance()
            params.append(try parseParameter(&stream))
        }
        return SyntaxNode(kind: .parameterList, children: params)
    }

    private func parseParameter(_ stream: inout CSTTokenStream) throws -> SyntaxNode {
        var children: [SyntaxNode] = []
        guard stream.peek()?.type == .identifier else { throw CSTParsingError.expectedIdentifier }
        children.append(SyntaxNode(token: stream.index))
        _ = stream.advance()
        children.append(try consumeToken(&stream, .colon))
        children.append(try parseTypeAnnotation(&stream))
        return SyntaxNode(kind: .parameter, children: children)
    }

    private func parseTypeAnnotation(_ stream: inout CSTTokenStream) throws -> SyntaxNode {
        guard let token = stream.peek() else {
            throw CSTParsingError.unexpectedEndOfInput
        }
        var children: [SyntaxNode] = []
        children.append(SyntaxNode(token: stream.index))
        _ = stream.advance()

        if token.type == .arrayType || (token.type == .identifier && isArrayTypeName(token.lexeme)) {
            if stream.peek()?.lexeme == "of" || stream.peek()?.lexeme == "の" {
                children.append(SyntaxNode(token: stream.index))
                _ = stream.advance()
                children.append(try parseTypeAnnotation(&stream))
            }
        } else if token.type == .recordType || (token.type == .identifier && isRecordTypeName(token.lexeme)) {
            if stream.peek()?.type == .identifier {
                children.append(SyntaxNode(token: stream.index))
                _ = stream.advance()
            }
        }

        return SyntaxNode(kind: .typeAnnotation, children: children)
    }

    private func isArrayTypeName(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower == "array" || lower == "配列型" || lower == "配列"
    }

    private func isRecordTypeName(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower == "record" || lower == "レコード型" || lower == "レコード"
    }

    private func parseArgumentList(_ stream: inout CSTTokenStream) throws -> SyntaxNode {
        let start = stream.index
        var args: [SyntaxNode] = []
        if stream.peek()?.type == .rightParen {
            return SyntaxNode(kind: .argumentList, children: [], startTokenIndex: start, endTokenIndex: start)
        }
        args.append(try parseExpression(&stream))
        while stream.peek()?.type == .comma {
            args.append(SyntaxNode(token: stream.index))
            _ = stream.advance()
            args.append(try parseExpression(&stream))
        }
        return SyntaxNode(kind: .argumentList, children: args)
    }

    @discardableResult
    private func consumeToken(_ stream: inout CSTTokenStream, _ expected: TokenType) throws -> SyntaxNode {
        guard let token = stream.peek() else {
            throw CSTParsingError.unexpectedEndOfInput
        }
        guard token.type == expected else {
            throw CSTParsingError.unexpectedTokenExpecting(token, expected: expected)
        }
        let node = SyntaxNode(token: stream.index)
        _ = stream.advance()
        return node
    }
}

// MARK: - CSTTokenStream

/// Token stream used by CSTParser that exposes index for CST node construction.
public struct CSTTokenStream: Sendable {
    public let tokens: [Token]
    public var index: Int = 0
    private let endIndex: Int

    public init(_ tokens: [Token]) {
        self.tokens = tokens
        self.endIndex = tokens.count
    }

    @inline(__always)
    public func peek() -> Token? {
        guard index < endIndex else { return nil }
        return tokens[index]
    }

    @inline(__always)
    public func peek(offset: Int) -> Token? {
        let target = index + offset
        guard target >= 0 && target < endIndex else { return nil }
        return tokens[target]
    }

    @inline(__always)
    @discardableResult
    public mutating func advance() -> Token? {
        guard index < endIndex else { return nil }
        let token = tokens[index]
        index += 1
        return token
    }
}

// MARK: - CSTParsingError

public enum CSTParsingError: Error, Equatable, Sendable {
    case unexpectedEndOfInput
    case unexpectedToken(Token)
    case unexpectedTokenExpecting(Token, expected: TokenType)
    case expectedIdentifier
    case expectedExpression(Token)
    case expectedToken(TokenType)
    case inputTooLarge
    case nestingTooDeep
}

extension CSTParsingError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unexpectedEndOfInput:
            return "Unexpected end of input"
        case .unexpectedToken(let token):
            return "Unexpected token '\(token.lexeme)' at \(token.position)"
        case .unexpectedTokenExpecting(let token, let expected):
            return "Expected \(expected) but found '\(token.lexeme)' at \(token.position)"
        case .expectedIdentifier:
            return "Expected identifier"
        case .expectedExpression(let token):
            return "Expected expression at \(token.position), got '\(token.lexeme)'"
        case .expectedToken(let expected):
            return "Expected token: \(expected)"
        case .inputTooLarge:
            return "Input too large for safe processing"
        case .nestingTooDeep:
            return "Nesting depth too deep"
        }
    }
}
