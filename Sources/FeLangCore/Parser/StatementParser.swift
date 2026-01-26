import Foundation

/// A parser for FE pseudo-language statements using recursive descent parsing.
/// This parser handles control structures, assignments, function/procedure declarations,
/// and integrates with the ExpressionParser for expressions.
public struct StatementParser {
    private let expressionParser: ExpressionParser

    public init() {
        self.expressionParser = ExpressionParser()
    }

    /// Parses a list of statements from an array of tokens.
    /// 
    /// This method processes a sequence of tokens and returns an array of parsed statements.
    /// It handles control flow statements (IF, WHILE, FOR), function/procedure declarations,
    /// assignments, and expression statements.
    /// 
    /// - Parameter tokens: Array of tokens to parse, typically from a tokenizer
    /// - Returns: Array of parsed Statement objects
    /// - Throws: StatementParsingError if parsing fails due to syntax errors
    /// 
    /// Example:
    /// ```swift
    /// let tokens = try tokenizer.tokenize("x ← 5")
    /// let statements = try parser.parseStatements(from: tokens)
    /// ```
    public func parseStatements(from tokens: [Token]) throws -> [Statement] {
        // Input validation for security and robustness
        guard tokens.count <= 100_000 else {
            throw StatementParsingError.inputTooLarge
        }

        var parser = TokenStream(tokens)
        var statements: [Statement] = []
        var nestingDepth = 0
        let maxNestingDepth = 100  // Prevent stack overflow attacks

        while let token = parser.peek(), token.type != .eof {
            // Skip whitespace
            if token.type == .whitespace {
                _ = parser.advance()
                continue
            }

            // Skip standalone newlines (they serve as statement separators)
            if token.type == .newline {
                _ = parser.advance()
                continue
            }

            // Track nesting depth for security
            // Note: doKeyword is not included because do-while loops don't have an enddo keyword
            // (they terminate with 'while (condition)'), so the depth would never be decremented
            switch token.type {
            case .ifKeyword, .whileKeyword, .forKeyword, .functionKeyword, .procedureKeyword, .classKeyword:
                nestingDepth += 1
                guard nestingDepth <= maxNestingDepth else {
                    throw StatementParsingError.nestingTooDeep
                }
            case .endifKeyword, .endwhileKeyword, .endforKeyword, .endfunctionKeyword, .endprocedureKeyword, .endclassKeyword:
                nestingDepth = max(0, nestingDepth - 1)
            default:
                break
            }

            let statement = try parseStatement(&parser)
            statements.append(statement)
        }

        return statements
    }

    /// Parses a single statement from the token stream.
    private func parseStatement(_ parser: inout TokenStream, nestingDepth: Int = 0) throws -> Statement {
        guard let token = parser.peek() else {
            throw StatementParsingError.unexpectedEndOfInput
        }

        switch token.type {
        case .ifKeyword:
            return .ifStatement(try parseIfStatement(&parser, nestingDepth: nestingDepth))
        case .whileKeyword:
            return .whileStatement(try parseWhileStatement(&parser, nestingDepth: nestingDepth))
        case .doKeyword:
            return .doWhileStatement(try parseDoWhileStatement(&parser, nestingDepth: nestingDepth))
        case .forKeyword:
            return .forStatement(try parseForStatement(&parser, nestingDepth: nestingDepth))
        case .variableKeyword:
            return .variableDeclaration(try parseVariableDeclaration(&parser))
        case .constantKeyword:
            return .constantDeclaration(try parseConstantDeclaration(&parser))
        case .globalKeyword:
            return .globalDeclaration(try parseGlobalDeclaration(&parser))
        case .functionKeyword:
            return .functionDeclaration(try parseFunctionDeclaration(&parser, nestingDepth: nestingDepth))
        case .procedureKeyword:
            return .procedureDeclaration(try parseProcedureDeclaration(&parser, nestingDepth: nestingDepth))
        case .classKeyword:
            return .classDeclaration(try parseClassDeclaration(&parser, nestingDepth: nestingDepth))
        case .returnKeyword:
            return .returnStatement(try parseReturnStatement(&parser))
        case .breakKeyword:
            _ = parser.advance() // consume 'break'
            return .breakStatement
        case .continueKeyword:
            _ = parser.advance() // consume 'continue'
            return .continueStatement
        case .identifier:
            // Could be assignment or expression statement
            return try parseAssignmentOrExpressionStatement(&parser)
        default:
            // Try to parse as expression statement
            let expression = try parseExpression(&parser)
            return .expressionStatement(expression)
        }
    }

    // MARK: - Control Flow Parsing

    /// Parses an IF statement (if-then-endif, if-then-else-endif, if-then-elif-else-endif).
    private func parseIfStatement(_ parser: inout TokenStream, nestingDepth: Int = 0) throws -> IfStatement {
        try expectToken(&parser, .ifKeyword) // consume 'if'

        let condition = try parseExpression(&parser)
        try expectToken(&parser, .thenKeyword) // consume 'then'

        let thenBody = try parseBlock(&parser, until: [.elseKeyword, .elifKeyword, .elseifKeyword, .endifKeyword], nestingDepth: nestingDepth)

        var elseIfs: [IfStatement.ElseIf] = []
        var elseBody: [Statement]?

        // Handle ELIF/ELSEIF clauses
        while parser.peek()?.type == .elifKeyword || parser.peek()?.type == .elseifKeyword {
            _ = parser.advance() // consume 'elif' or 'elseif'
            let elifCondition = try parseExpression(&parser)
            try expectToken(&parser, .thenKeyword) // consume 'then'
            let elifBody = try parseBlock(&parser, until: [.elseKeyword, .elifKeyword, .elseifKeyword, .endifKeyword], nestingDepth: nestingDepth)
            elseIfs.append(IfStatement.ElseIf(condition: elifCondition, body: elifBody))
        }

        // Handle optional ELSE clause
        if parser.peek()?.type == .elseKeyword {
            _ = parser.advance() // consume 'else'
            elseBody = try parseBlock(&parser, until: [.endifKeyword], nestingDepth: nestingDepth)
        }

        try expectToken(&parser, .endifKeyword) // consume 'endif'

        return IfStatement(condition: condition, thenBody: thenBody, elseIfs: elseIfs, elseBody: elseBody)
    }

    /// Parses a WHILE statement (while-do-endwhile).
    private func parseWhileStatement(_ parser: inout TokenStream, nestingDepth: Int = 0) throws -> WhileStatement {
        try expectToken(&parser, .whileKeyword) // consume 'while'

        let condition = try parseExpression(&parser)
        try expectToken(&parser, .doKeyword) // consume 'do'

        let body = try parseBlock(&parser, until: [.endwhileKeyword], nestingDepth: nestingDepth)

        try expectToken(&parser, .endwhileKeyword) // consume 'endwhile'

        return WhileStatement(condition: condition, body: body)
    }

    /// Parses a DO-WHILE statement (do ... while (condition)).
    /// The body is executed at least once, then the condition is checked.
    /// Uses lookahead to distinguish terminating `while (` from nested `while condition do`.
    private func parseDoWhileStatement(_ parser: inout TokenStream, nestingDepth: Int = 0) throws -> DoWhileStatement {
        try expectToken(&parser, .doKeyword) // consume 'do'

        let body = try parseDoWhileBody(&parser, nestingDepth: nestingDepth)

        try expectToken(&parser, .whileKeyword) // consume 'while'
        try expectToken(&parser, .leftParen) // consume '('
        let condition = try parseExpression(&parser)
        try expectToken(&parser, .rightParen) // consume ')'

        return DoWhileStatement(body: body, condition: condition)
    }

    /// Parses the body of a do-while statement until the terminating `while (` is found.
    /// Distinguishes between terminating `while (` and nested `while condition do` using lookahead.
    private func parseDoWhileBody(_ parser: inout TokenStream, nestingDepth: Int = 0) throws -> [Statement] {
        // Check nesting depth for security
        guard nestingDepth < 100 else {
            throw StatementParsingError.nestingTooDeep
        }

        var statements: [Statement] = []

        while let token = parser.peek(), token.type != .eof {
            // Skip newlines and whitespace
            if token.type == .newline || token.type == .whitespace {
                _ = parser.advance()
                continue
            }

            // Check if this is the terminating `while (` of the do-while
            // The terminating while is followed by `(`, while a nested while loop
            // is followed by a condition expression and then `do`
            if token.type == .whileKeyword {
                // Lookahead to check if next token is `(`
                if let nextToken = parser.peek(offset: 1), nextToken.type == .leftParen {
                    // This is the terminating `while (` - stop parsing body
                    break
                }
                // Otherwise, this is a nested while loop - continue parsing as statement
            }

            let statement = try parseStatement(&parser, nestingDepth: nestingDepth + 1)
            statements.append(statement)
        }

        return statements
    }

    /// Parses a FOR statement (range-based or forEach).
    private func parseForStatement(_ parser: inout TokenStream, nestingDepth: Int = 0) throws -> ForStatement {
        try expectToken(&parser, .forKeyword) // consume 'for'

        guard let varToken = parser.advance(), varToken.type == .identifier else {
            throw StatementParsingError.expectedIdentifier
        }
        let variable = varToken.lexeme

        // Check if it's a range-based FOR (variable ← start to end) or forEach (variable in iterable)
        if parser.peek()?.type == .assign {
            // Range-based FOR: for i ← 1 to 10 step 1 do
            _ = parser.advance() // consume '←'

            let start = try parseExpression(&parser)
            try expectToken(&parser, .toKeyword) // consume 'to'
            let end = try parseExpression(&parser)

            // Optional step clause
            var step: Expression?
            if parser.peek()?.type == .stepKeyword {
                _ = parser.advance() // consume 'step'
                step = try parseExpression(&parser)
            }

            try expectToken(&parser, .doKeyword) // consume 'do'
            let body = try parseBlock(&parser, until: [.endforKeyword])
            try expectToken(&parser, .endforKeyword) // consume 'endfor'

            let rangeFor = ForStatement.RangeFor(variable: variable, start: start, end: end, step: step, body: body)
            return .range(rangeFor)
        } else if parser.peek()?.type == .inKeyword {
            // ForEach: for item in array do
            _ = parser.advance() // consume 'in'

            let iterable = try parseExpression(&parser)
            try expectToken(&parser, .doKeyword) // consume 'do'
            let body = try parseBlock(&parser, until: [.endforKeyword])
            try expectToken(&parser, .endforKeyword) // consume 'endfor'

            let forEach = ForStatement.ForEachLoop(variable: variable, iterable: iterable, body: body)
            return .forEach(forEach)
        } else {
            throw StatementParsingError.expectedTokens([.assign, .inKeyword])
        }
    }

    // MARK: - Assignment Parsing

    /// Parses assignment or expression statement using lookahead instead of backtracking.
    private func parseAssignmentOrExpressionStatement(_ parser: inout TokenStream) throws -> Statement {
        // Use lookahead to determine if this is an assignment
        guard let firstToken = parser.peek(), firstToken.type == .identifier else {
            // Not an identifier, must be expression
            let expression = try parseExpression(&parser)
            return .expressionStatement(expression)
        }

        // Use efficient lookahead to determine assignment pattern
        // Check for simple variable assignment: identifier ←
        if let nextToken = parser.peek(offset: 1), nextToken.type == .assign {
            return .assignment(try parseAssignment(&parser))
        }

        // Check for array access assignment: identifier[...] ←
        if let nextToken = parser.peek(offset: 1), nextToken.type == .leftBracket {
            // Skip to matching right bracket using balanced counting
            var offset = 2  // Start after the '['
            var bracketCount = 1

            while bracketCount > 0, let token = parser.peek(offset: offset) {
                switch token.type {
                case .leftBracket:
                    bracketCount += 1
                case .rightBracket:
                    bracketCount -= 1
                default:
                    break
                }
                offset += 1
            }

            // Check if followed by assignment operator
            if let assignToken = parser.peek(offset: offset), assignToken.type == .assign {
                return .assignment(try parseAssignment(&parser))
            }
        }

        // Check for field access assignment: identifier.field ←
        if let nextToken = parser.peek(offset: 1), nextToken.type == .dot {
            // Skip through field accesses (could be chained like a.b.c)
            var offset = 2  // Start after the '.'

            while let token = parser.peek(offset: offset) {
                if token.type == .identifier {
                    offset += 1
                    // Check if followed by another dot (chained access)
                    if let nextDot = parser.peek(offset: offset), nextDot.type == .dot {
                        offset += 1
                        continue
                    }
                    break
                } else {
                    break
                }
            }

            // Check if followed by assignment operator
            if let assignToken = parser.peek(offset: offset), assignToken.type == .assign {
                return .assignment(try parseAssignment(&parser))
            }
        }

        // Not an assignment, parse as expression
        let expression = try parseExpression(&parser)
        return .expressionStatement(expression)
    }

    /// Parses an assignment statement (variable ← expression, array[index] ← expression, or object.field ← expression).
    private func parseAssignment(_ parser: inout TokenStream) throws -> Assignment {
        guard let identifierToken = parser.advance(), identifierToken.type == .identifier else {
            throw StatementParsingError.expectedIdentifier
        }
        let identifier = identifierToken.lexeme

        // Check if it's array element assignment
        if parser.peek()?.type == .leftBracket {
            // Array element assignment: array[index] ← expression or array[row, col] ← expression
            _ = parser.advance() // consume '['
            let firstIndexExpr = try parseExpression(&parser)
            var arrayExpr: Expression = .arrayAccess(.identifier(identifier), firstIndexExpr)

            // Handle comma-separated indices for multi-dimensional array access
            // e.g., matrix[1, 2] ← value is desugared to matrix[1][2] ← value
            while parser.peek()?.type == .comma {
                _ = parser.advance() // consume ','
                let nextIndexExpr = try parseExpression(&parser)
                arrayExpr = .arrayAccess(arrayExpr, nextIndexExpr)
            }

            try expectToken(&parser, .rightBracket) // consume ']'
            try expectToken(&parser, .assign) // consume '←'
            let valueExpr = try parseExpression(&parser)

            // Extract the final array access for the assignment.
            // At this point, arrayExpr is guaranteed to be .arrayAccess because it is
            // initialized as .arrayAccess above and only ever wrapped into further
            // .arrayAccess cases in the loop. If this assumption is violated in the
            // future, treat it as an internal parser logic error rather than a
            // user-facing syntax error.
            if case let .arrayAccess(array, index) = arrayExpr {
                let arrayAccessStruct = Assignment.ArrayAccess(array: array, index: index)
                return .arrayElement(arrayAccessStruct, valueExpr)
            } else {
                preconditionFailure("Internal parser error: expected final arrayExpr to be .arrayAccess")
            }
        } else if parser.peek()?.type == .dot {
            // Field access assignment: object.field ← expression (possibly chained like a.b.c)
            var currentExpr: Expression = .identifier(identifier)

            while parser.peek()?.type == .dot {
                _ = parser.advance() // consume '.'
                guard let fieldToken = parser.advance(), fieldToken.type == .identifier else {
                    throw StatementParsingError.expectedIdentifier
                }
                currentExpr = .fieldAccess(currentExpr, fieldToken.lexeme)
            }

            try expectToken(&parser, .assign) // consume '←'
            let valueExpr = try parseExpression(&parser)

            // Extract the final field access for the assignment
            guard case .fieldAccess(let objectExpr, let fieldName) = currentExpr else {
                throw StatementParsingError.expectedToken(.assign)
            }

            let fieldAccess = Assignment.FieldAccess(object: objectExpr, field: fieldName)
            return .fieldAccess(fieldAccess, valueExpr)
        } else if parser.peek()?.type == .assign {
            // Variable assignment: variable ← expression
            _ = parser.advance() // consume '←'
            let valueExpr = try parseExpression(&parser)
            return .variable(identifier, valueExpr)
        } else {
            throw StatementParsingError.expectedToken(.assign)
        }
    }

    // MARK: - Declaration Parsing

    /// Common declaration components extracted from parsing
    private struct DeclarationComponents {
        let name: String
        let type: DataType
        let initialValue: Expression?
        let position: SourcePosition?
    }

    /// Parses the common declaration pattern: keyword name: type [← value]
    /// This helper consolidates shared parsing logic between variable and constant declarations.
    /// - Parameters:
    ///   - parser: Token stream to parse from
    ///   - keywordType: Expected declaration keyword (.variableKeyword or .constantKeyword)
    ///   - requiresInitialValue: Whether initial value is required (true for constants)
    /// - Returns: Parsed declaration components
    private func parseDeclarationComponents(
        _ parser: inout TokenStream,
        keywordType: TokenType,
        requiresInitialValue: Bool
    ) throws -> DeclarationComponents {
        // Get position from keyword token before consuming
        let position = parser.peek()?.position

        // Consume declaration keyword
        try expectToken(&parser, keywordType)

        // Parse identifier name
        guard let nameToken = parser.advance(), nameToken.type == .identifier else {
            throw StatementParsingError.expectedIdentifier
        }
        let name = nameToken.lexeme

        // Parse type annotation
        try expectToken(&parser, .colon) // consume ':'
        let type = try parseDataType(&parser)

        // Parse initial value (optional for variables, required for constants)
        var initialValue: Expression?
        if parser.peek()?.type == .assign {
            _ = parser.advance() // consume '←'
            initialValue = try parseExpression(&parser)
        } else if requiresInitialValue {
            throw StatementParsingError.expectedToken(.assign)
        }

        return DeclarationComponents(name: name, type: type, initialValue: initialValue, position: position)
    }

    /// Parses a variable declaration (変数 name: type ← initialValue).
    private func parseVariableDeclaration(_ parser: inout TokenStream) throws -> VariableDeclaration {
        let components = try parseDeclarationComponents(
            &parser,
            keywordType: .variableKeyword,
            requiresInitialValue: false
        )

        return VariableDeclaration(
            name: components.name,
            type: components.type,
            initialValue: components.initialValue,
            position: components.position
        )
    }

    /// Parses a constant declaration (定数 name: type ← value).
    private func parseConstantDeclaration(_ parser: inout TokenStream) throws -> ConstantDeclaration {
        let components = try parseDeclarationComponents(
            &parser,
            keywordType: .constantKeyword,
            requiresInitialValue: true
        )

        // requiresInitialValue: true guarantees initialValue exists
        guard let initialValue = components.initialValue else {
            throw StatementParsingError.expectedToken(.assign)
        }
        return ConstantDeclaration(
            name: components.name,
            type: components.type,
            initialValue: initialValue,
            position: components.position
        )
    }

    /// Parses a global variable declaration (大域: 型: 変数名 [← 初期値]).
    private func parseGlobalDeclaration(_ parser: inout TokenStream) throws -> GlobalDeclaration {
        let position = parser.peek()?.position

        try expectToken(&parser, .globalKeyword)
        try expectToken(&parser, .colon)

        let type = try parseDataType(&parser)
        try expectToken(&parser, .colon)

        guard let nameToken = parser.advance(), nameToken.type == .identifier else {
            throw StatementParsingError.expectedIdentifier
        }
        let name = nameToken.lexeme

        var initialValue: Expression?
        if parser.peek()?.type == .assign {
            _ = parser.advance()
            initialValue = try parseExpression(&parser)
        }

        return GlobalDeclaration(
            name: name,
            type: type,
            initialValue: initialValue,
            position: position
        )
    }

    // MARK: - Function/Procedure Parsing

    /// Parses a function declaration.
    private func parseFunctionDeclaration(_ parser: inout TokenStream, nestingDepth: Int = 0) throws -> FunctionDeclaration {
        // Get position from function keyword before consuming
        let position = parser.peek()?.position

        try expectToken(&parser, .functionKeyword) // consume 'function'

        guard let nameToken = parser.advance(), nameToken.type == .identifier else {
            throw StatementParsingError.expectedIdentifier
        }
        let name = nameToken.lexeme

        try expectToken(&parser, .leftParen) // consume '('
        let parameters = try parseParameterList(&parser)
        try expectToken(&parser, .rightParen) // consume ')'

        // Optional return type
        var returnType: DataType?
        if parser.peek()?.type == .colon {
            _ = parser.advance() // consume ':'
            returnType = try parseDataType(&parser)
        }

        // Parse local variable declarations and body
        let (localVariables, body) = try parseFunctionBody(&parser, endToken: .endfunctionKeyword)

        try expectToken(&parser, .endfunctionKeyword) // consume 'endfunction'

        return FunctionDeclaration(
            name: name,
            parameters: parameters,
            returnType: returnType,
            localVariables: localVariables,
            body: body,
            position: position
        )
    }

    /// Parses a procedure declaration.
    private func parseProcedureDeclaration(_ parser: inout TokenStream, nestingDepth: Int = 0) throws -> ProcedureDeclaration {
        // Get position from procedure keyword before consuming
        let position = parser.peek()?.position

        try expectToken(&parser, .procedureKeyword) // consume 'procedure'

        guard let nameToken = parser.advance(), nameToken.type == .identifier else {
            throw StatementParsingError.expectedIdentifier
        }
        let name = nameToken.lexeme

        try expectToken(&parser, .leftParen) // consume '('
        let parameters = try parseParameterList(&parser)
        try expectToken(&parser, .rightParen) // consume ')'

        // Parse local variable declarations and body
        let (localVariables, body) = try parseFunctionBody(&parser, endToken: .endprocedureKeyword)

        try expectToken(&parser, .endprocedureKeyword) // consume 'endprocedure'

        return ProcedureDeclaration(
            name: name,
            parameters: parameters,
            localVariables: localVariables,
            body: body,
            position: position
        )
    }

    /// Parses a return statement.
    private func parseReturnStatement(_ parser: inout TokenStream) throws -> ReturnStatement {
        try expectToken(&parser, .returnKeyword) // consume 'return'

        // Optional expression
        var expression: Expression?
        if let token = parser.peek(), token.type != .newline && token.type != .eof {
            expression = try parseExpression(&parser)
        }

        return ReturnStatement(expression: expression)
    }

    /// Parses a class declaration.
    /// Syntax: class ClassName
    ///           member1: Type1
    ///           member2: Type2
    ///           ClassName(param1: Type1, param2: Type2)
    ///             body
    ///         endclass
    private func parseClassDeclaration(_ parser: inout TokenStream, nestingDepth: Int = 0) throws -> ClassDeclaration {
        let position = parser.peek()?.position

        try expectToken(&parser, .classKeyword) // consume 'class'

        guard let nameToken = parser.advance(), nameToken.type == .identifier else {
            throw StatementParsingError.expectedIdentifier
        }
        let className = nameToken.lexeme

        var members: [MemberDeclaration] = []
        var constructor: ConstructorDeclaration?
        var methods: [MethodDeclaration] = []

        // Parse class body until endclass
        while let token = parser.peek(), token.type != .endclassKeyword && token.type != .eof {
            // Skip newlines and whitespace
            if token.type == .newline || token.type == .whitespace {
                _ = parser.advance()
                continue
            }

            // Check if this is a constructor (identifier matching class name followed by '(')
            if token.type == .identifier && token.lexeme == className {
                if let nextToken = parser.peek(offset: 1), nextToken.type == .leftParen {
                    constructor = try parseConstructorDeclaration(&parser, className: className)
                    continue
                }
            }

            // Check if this is a method (function keyword)
            if token.type == .functionKeyword {
                methods.append(try parseMethodDeclaration(&parser, nestingDepth: nestingDepth))
                continue
            }

            // Otherwise, try to parse as member declaration (name: Type)
            if token.type == .identifier {
                if let nextToken = parser.peek(offset: 1), nextToken.type == .colon {
                    members.append(try parseMemberDeclaration(&parser))
                    continue
                }
            }

            // Unknown token in class body
            throw StatementParsingError.unexpectedToken(token, expected: .endclassKeyword)
        }

        try expectToken(&parser, .endclassKeyword) // consume 'endclass'

        return ClassDeclaration(
            name: className,
            superclass: nil,
            members: members,
            constructor: constructor,
            methods: methods,
            position: position
        )
    }

    /// Parses a member declaration (name: Type).
    private func parseMemberDeclaration(_ parser: inout TokenStream) throws -> MemberDeclaration {
        guard let nameToken = parser.advance(), nameToken.type == .identifier else {
            throw StatementParsingError.expectedIdentifier
        }
        let name = nameToken.lexeme

        try expectToken(&parser, .colon) // consume ':'
        let type = try parseDataType(&parser)

        return MemberDeclaration(name: name, type: type)
    }

    /// Parses a constructor declaration (ClassName(params) body).
    private func parseConstructorDeclaration(_ parser: inout TokenStream, className: String) throws -> ConstructorDeclaration {
        // Consume constructor name (same as class name)
        guard let nameToken = parser.advance(), nameToken.type == .identifier && nameToken.lexeme == className else {
            throw StatementParsingError.expectedIdentifier
        }

        try expectToken(&parser, .leftParen) // consume '('
        let parameters = try parseParameterList(&parser)
        try expectToken(&parser, .rightParen) // consume ')'

        // Parse constructor body until we hit another member, method, or endclass
        let body = try parseClassMemberBody(&parser)

        return ConstructorDeclaration(parameters: parameters, body: body)
    }

    /// Parses a method declaration (function name(params): ReturnType body endfunction).
    private func parseMethodDeclaration(_ parser: inout TokenStream, nestingDepth: Int = 0) throws -> MethodDeclaration {
        try expectToken(&parser, .functionKeyword) // consume 'function'

        guard let nameToken = parser.advance(), nameToken.type == .identifier else {
            throw StatementParsingError.expectedIdentifier
        }
        let name = nameToken.lexeme

        try expectToken(&parser, .leftParen) // consume '('
        let parameters = try parseParameterList(&parser)
        try expectToken(&parser, .rightParen) // consume ')'

        // Optional return type
        var returnType: DataType?
        if parser.peek()?.type == .colon {
            _ = parser.advance() // consume ':'
            returnType = try parseDataType(&parser)
        }

        // Parse method body
        let body = try parseBlock(&parser, until: [.endfunctionKeyword], nestingDepth: nestingDepth)
        try expectToken(&parser, .endfunctionKeyword) // consume 'endfunction'

        return MethodDeclaration(name: name, parameters: parameters, returnType: returnType, body: body)
    }

    /// Parses a constructor body (statements until next member/method/endclass).
    private func parseClassMemberBody(_ parser: inout TokenStream) throws -> [Statement] {
        var statements: [Statement] = []

        while let token = parser.peek() {
            // Skip newlines and whitespace
            if token.type == .newline || token.type == .whitespace {
                _ = parser.advance()
                continue
            }

            // Stop at endclass or function keyword (method) or identifier followed by colon (member) or identifier followed by '(' (constructor)
            if token.type == .endclassKeyword || token.type == .functionKeyword {
                break
            }

            // Check for member declaration (identifier followed by colon)
            if token.type == .identifier {
                if let nextToken = parser.peek(offset: 1) {
                    if nextToken.type == .colon || nextToken.type == .leftParen {
                        break
                    }
                }
            }

            if token.type == .eof {
                break
            }

            let statement = try parseStatement(&parser)
            statements.append(statement)
        }

        return statements
    }

    // MARK: - Helper Parsing Methods

    /// Parses a block of statements until one of the end tokens is encountered.
    private func parseBlock(_ parser: inout TokenStream, until endTokens: [TokenType], nestingDepth: Int = 0) throws -> [Statement] {
        // Check nesting depth for security
        guard nestingDepth < 100 else {
            throw StatementParsingError.nestingTooDeep
        }

        var statements: [Statement] = []

        while let token = parser.peek(), !endTokens.contains(token.type) && token.type != .eof {
            // Skip newlines and whitespace
            if token.type == .newline || token.type == .whitespace {
                _ = parser.advance()
                continue
            }

            let statement = try parseStatement(&parser, nestingDepth: nestingDepth + 1)
            statements.append(statement)
        }

        return statements
    }

    /// Parses a parameter list for functions and procedures.
    private func parseParameterList(_ parser: inout TokenStream) throws -> [Parameter] {
        var parameters: [Parameter] = []

        // Handle empty parameter list
        if parser.peek()?.type == .rightParen {
            return parameters
        }

        // Parse first parameter
        parameters.append(try parseParameter(&parser))

        // Parse remaining parameters
        while parser.peek()?.type == .comma {
            _ = parser.advance() // consume ','
            parameters.append(try parseParameter(&parser))
        }

        return parameters
    }

    /// Parses a single parameter.
    private func parseParameter(_ parser: inout TokenStream) throws -> Parameter {
        guard let nameToken = parser.advance(), nameToken.type == .identifier else {
            throw StatementParsingError.expectedIdentifier
        }
        let name = nameToken.lexeme

        try expectToken(&parser, .colon) // consume ':'
        let type = try parseDataType(&parser)

        return Parameter(name: name, type: type)
    }

    /// Parses a data type with full support for basic types, arrays, and records.
    /// Supports both English and Japanese keywords for internationalization.
    private func parseDataType(_ parser: inout TokenStream) throws -> DataType {
        guard let typeToken = parser.advance() else {
            throw StatementParsingError.unexpectedEndOfInput
        }

        // Handle basic types first
        if let basicType = DataType(tokenType: typeToken.type) {
            return basicType
        }

        // Handle identifier-based type names (for extended type support)
        if typeToken.type == .identifier {
            let typeName = typeToken.lexeme.lowercased()

            // Support multiple variants of basic types with bilingual (English/Japanese) keywords
            // This enables FE pseudo-language to be used in both English and Japanese environments
            switch typeName {
            // Integer types: supports English variants and Japanese equivalents
            case "integer", "int", "整数型", "整数":
                return .integer

            // Real number types: supports floating-point number variants
            case "real", "double", "float", "実数型", "実数":
                return .real

            // String types: supports text/string variants
            case "string", "str", "文字列型", "文字列":
                return .string

            // Character types: supports single character types
            case "character", "char", "文字型", "文字":
                return .character

            // Boolean types: supports logical/boolean variants including Japanese "ブール"
            case "boolean", "bool", "論理型", "論理", "ブール":
                return .boolean

            // Array types: supports both English "array of type" and Japanese "配列型"
            case "array", "配列型", "配列":
                // Handle array type with element specification: "array of integer" or "配列 の 整数"
                if parser.peek()?.lexeme == "of" || parser.peek()?.lexeme == "の" {
                    _ = parser.advance() // consume "of" or "の"
                    let elementType = try parseDataType(&parser)
                    return .array(elementType)
                } else {
                    // Default to integer array for backwards compatibility
                    return .array(.integer)
                }

            // Record types: supports structured data types with custom names
            case "record", "レコード型", "レコード":
                // Handle record type with name: "record PersonRecord"
                guard let nameToken = parser.advance(), nameToken.type == .identifier else {
                    throw StatementParsingError.expectedIdentifier
                }
                return .record(nameToken.lexeme)

            default:
                // Treat unknown identifiers as custom record types for extensibility
                return .record(typeToken.lexeme)
            }
        }

        // Handle array types using array keyword
        if typeToken.type == .arrayType {
            // Expect "of" keyword followed by element type
            if parser.peek()?.lexeme == "of" || parser.peek()?.lexeme == "の" {
                _ = parser.advance() // consume "of" or "の"
                let elementType = try parseDataType(&parser)
                return .array(elementType)
            } else {
                // Default to integer array for backwards compatibility
                return .array(.integer)
            }
        }

        // Handle record types using record keyword
        if typeToken.type == .recordType {
            // Expect record name
            guard let nameToken = parser.advance(), nameToken.type == .identifier else {
                throw StatementParsingError.expectedIdentifier
            }
            return .record(nameToken.lexeme)
        }

        throw StatementParsingError.expectedDataType
    }

    /// Parses function/procedure body with local variable declarations.
    private func parseFunctionBody(_ parser: inout TokenStream, endToken: TokenType) throws -> ([VariableDeclaration], [Statement]) {
        let localVariables: [VariableDeclaration] = []
        var statements: [Statement] = []

        // Parse local variable declarations (simplified for now)
        // In a full implementation, this would parse actual variable declaration syntax

        // Parse statements until end token
        while let token = parser.peek(), token.type != endToken && token.type != .eof {
            // Skip newlines and whitespace
            if token.type == .newline || token.type == .whitespace {
                _ = parser.advance()
                continue
            }

            let statement = try parseStatement(&parser)
            statements.append(statement)
        }

        return (localVariables, statements)
    }

    /// Parses an expression by delegating to ExpressionParser.
    /// This creates a bounded token stream and delegates to ExpressionParser.
    private func parseExpression(_ parser: inout TokenStream) throws -> Expression {
        // Get the starting position
        let startIndex = parser.index

        // Find the end of the expression using balanced parentheses/brackets/braces
        var endIndex = startIndex
        var parenDepth = 0
        var bracketDepth = 0
        var braceDepth = 0

        // Scan forward to find expression boundary
        var scanIndex = startIndex
        while scanIndex < parser.tokens.count {
            let token = parser.tokens[scanIndex]
            let tokenType = token.type

            // Handle EOF
            if tokenType == .eof {
                endIndex = scanIndex
                break
            }

            // Track parentheses, bracket, and brace depth
            if tokenType == .leftParen {
                parenDepth += 1
            } else if tokenType == .rightParen {
                parenDepth -= 1
                if parenDepth < 0 {
                    endIndex = scanIndex
                    break
                }
            } else if tokenType == .leftBracket {
                bracketDepth += 1
            } else if tokenType == .rightBracket {
                bracketDepth -= 1
                if bracketDepth < 0 {
                    endIndex = scanIndex
                    break
                }
            } else if tokenType == .leftBrace {
                braceDepth += 1
            } else if tokenType == .rightBrace {
                braceDepth -= 1
                if braceDepth < 0 {
                    endIndex = scanIndex
                    break
                }
            }

            // Stop at statement terminators only when we're not inside parentheses/brackets/braces
            if parenDepth == 0 && bracketDepth == 0 && braceDepth == 0 && isStatementTerminator(tokenType) {
                endIndex = scanIndex
                break
            }

            // Also stop if we detect the start of a new statement (when newlines are filtered out)
            if parenDepth == 0 && bracketDepth == 0 && braceDepth == 0 && scanIndex > startIndex && isStartOfNewStatement(parser, at: scanIndex) {
                endIndex = scanIndex
                break
            }

            scanIndex += 1
        }

        // Create expression tokens from start to end
        let expressionTokens = Array(parser.tokens[startIndex..<endIndex]) + [
            Token(type: .eof, lexeme: "", position: SourcePosition(line: 0, column: 0, offset: 0))
        ]

        // Advance the parser to the end of the expression
        parser.index = endIndex

        // Parse expression using dedicated ExpressionParser
        do {
            return try expressionParser.parseExpression(from: expressionTokens)
        } catch let error as ParsingError {
            // Convert ParsingError to StatementParsingError
            throw convertParsingError(error)
        }
    }

    /// Checks if a token type indicates the end of an expression (statement boundary).
    private func isStatementTerminator(_ tokenType: TokenType) -> Bool {
        switch tokenType {
        // Basic terminators
        case .newline, .eof:
            return true

        // Control flow keywords that end expressions and start new statement blocks
        case .thenKeyword,      // IF condition ends, THEN block begins
             .elseKeyword,      // Previous block ends, ELSE block begins
             .elifKeyword,      // Previous block ends, ELIF condition begins
             .elseifKeyword,    // Previous block ends, ELSEIF condition begins
             .doKeyword:        // WHILE/FOR condition ends, DO block begins
            return true

        // Block termination keywords that end expressions and close statement blocks
        case .endifKeyword,     // IF statement block ends
             .endwhileKeyword,  // WHILE statement block ends
             .endforKeyword,    // FOR statement block ends
             .endfunctionKeyword,   // FUNCTION declaration block ends
             .endprocedureKeyword,  // PROCEDURE declaration block ends
             .endclassKeyword:      // CLASS declaration block ends
            return true

        // FOR loop specific keywords that separate expression components
        case .toKeyword,        // Separates start and end expressions: FOR i ← 1 TO 10
             .stepKeyword,      // Separates end and step expressions: TO 10 STEP 2
             .inKeyword:        // Separates variable and iterable: FOR item IN array
            return true

        // General expression separators
        case .comma:            // Separates function arguments, parameter lists
            return true

        default:
            return false
        }
    }

    /// Checks if a token type indicates expression continuation (operator, opening bracket, comma, etc.)
    /// Used to distinguish between function calls as new statements vs function calls within expressions
    private func isExpressionContinuationToken(_ tokenType: TokenType) -> Bool {
        switch tokenType {
        case .plus, .minus, .multiply, .divide, .modulo, .modKeyword,
             .equal, .notEqual, .less, .greater, .lessEqual, .greaterEqual,
             .andKeyword, .orKeyword,
             .leftParen, .leftBracket, .comma, .dot,
             .assign:
            return true
        default:
            return false
        }
    }

    /// Checks if a token sequence indicates the start of a new statement.
    /// This helps detect statement boundaries when newlines are filtered out.
    private func isStartOfNewStatement(_ parser: TokenStream, at index: Int) -> Bool {
        guard index < parser.tokens.count else { return false }

        let token = parser.tokens[index]

        // Check for assignment pattern: identifier ←
        // This detects variable assignments like "x ← 5" or array assignments like "arr[i] ← value"
        if token.type == .identifier && index + 1 < parser.tokens.count {
            let nextToken = parser.tokens[index + 1]
            if nextToken.type == .assign {
                return true
            }
            // Check for function call pattern: identifier(
            // This detects function calls like "println(x)" as new statements
            // But NOT if preceded by an operator (expression continuation like "a + f(x)")
            if nextToken.type == .leftParen {
                if index > 0 && isExpressionContinuationToken(parser.tokens[index - 1].type) {
                    return false
                }
                return true
            }
            // Check for array element assignment pattern: identifier[...]←
            // This detects array assignments like "arr[0] ← 10" or "arr[i] ← value"
            // But also check for expression continuation after array access
            if nextToken.type == .leftBracket {
                var offset = 2
                var bracketCount = 1
                while bracketCount > 0, index + offset < parser.tokens.count {
                    let scanToken = parser.tokens[index + offset]
                    if scanToken.type == .leftBracket { bracketCount += 1 } else if scanToken.type == .rightBracket { bracketCount -= 1 }
                    offset += 1
                }
                if index + offset < parser.tokens.count {
                    let afterBracket = parser.tokens[index + offset]
                    if afterBracket.type == .assign {
                        return true  // Array assignment is a new statement
                    }
                    // Expression continuation after array access is NOT a new statement
                    if isExpressionContinuationToken(afterBracket.type) {
                        return false
                    }
                }
            }
        }

        // Check for statement-starting keywords
        switch token.type {
        // Control flow statements
        case .ifKeyword,        // IF-THEN-ELSE conditional statements
             .whileKeyword,     // WHILE-DO loop statements
             .doKeyword,        // DO-WHILE loop statements
             .forKeyword:       // FOR loop statements (range or forEach)
            return true

        // Declaration statements
        case .variableKeyword,  // Variable declarations: 変数 name: type ← value
             .constantKeyword,  // Constant declarations: 定数 name: type ← value
             .globalKeyword:    // Global declarations: 大域: 型: 変数名
            return true

        // Function/procedure/class declarations
        case .functionKeyword,  // FUNCTION declarations with return values
             .procedureKeyword, // PROCEDURE declarations without return values
             .classKeyword:     // CLASS declarations
            return true

        // Flow control statements
        case .returnKeyword,    // RETURN statements (with or without values)
             .breakKeyword,     // BREAK statements for loop termination
             .continueKeyword:  // CONTINUE statements to skip to next iteration
            return true

        default:
            return false
        }
    }

    /// Converts ExpressionParser errors to StatementParser errors.
    private func convertParsingError(_ error: ParsingError) -> StatementParsingError {
        switch error {
        case .unexpectedEndOfInput:
            return .unexpectedEndOfInput
        case .unexpectedToken(let token, let expected):
            return .unexpectedToken(token, expected: expected)
        case .expectedPrimaryExpression(let token):
            return .expectedPrimaryExpression(token)
        case .expectedIdentifier:
            return .expectedIdentifier
        }
    }

    /// Expects a specific token type and consumes it.
    private func expectToken(_ parser: inout TokenStream, _ expectedType: TokenType) throws {
        guard let token = parser.advance() else {
            throw StatementParsingError.unexpectedEndOfInput
        }

        guard token.type == expectedType else {
            throw StatementParsingError.unexpectedToken(token, expected: expectedType)
        }
    }
}

// MARK: - TokenStream Helper

/// An optimized token stream for parsing that provides efficient token access.
private struct TokenStream {
    let tokens: [Token]
    var index: Int = 0

    /// Cache for faster boundary checking
    private let endIndex: Int

    init(_ tokens: [Token]) {
        self.tokens = tokens
        self.endIndex = tokens.count
    }

    /// Peeks at the current token without consuming it.
    /// - Returns: Current token or nil if at end
    @inline(__always)
    mutating func peek() -> Token? {
        guard index < endIndex else { return nil }
        return tokens[index]
    }

    /// Peeks at a token at the specified offset from current position.
    /// - Parameter offset: Number of tokens to look ahead (0 = current token)
    /// - Returns: Token at offset position or nil if out of bounds
    @inline(__always)
    func peek(offset: Int) -> Token? {
        let targetIndex = index + offset
        guard targetIndex >= 0 && targetIndex < endIndex else { return nil }
        return tokens[targetIndex]
    }

    /// Advances to the next token and returns the current one.
    /// - Returns: Current token before advancing, or nil if at end
    @inline(__always)
    mutating func advance() -> Token? {
        guard index < endIndex else { return nil }
        let token = tokens[index]
        index += 1
        return token
    }

    /// Returns true if at end of token stream
    var isAtEnd: Bool {
        return index >= endIndex
    }

    /// Returns remaining token count
    var remainingCount: Int {
        return max(0, endIndex - index)
    }
}

// MARK: - Statement Parsing Errors

/// Errors that can occur during statement parsing.
public enum StatementParsingError: Error, Equatable {
    case unexpectedEndOfInput
    case unexpectedToken(Token, expected: TokenType)
    case expectedTokens([TokenType])
    case expectedIdentifier
    case expectedDataType
    case expectedToken(TokenType)
    case expectedPrimaryExpression(Token)
    case inputTooLarge
    case nestingTooDeep
    case identifierTooLong(String)
    case expressionTooComplex
    case invalidArrayDimension
    case invalidFunctionArity(String, expected: Int, actual: Int)
    case undeclaredVariable(String)
    case cyclicDependency([String])
}

extension StatementParsingError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unexpectedEndOfInput:
            return "Unexpected end of input"
        case .unexpectedToken(let token, let expected):
            return "Unexpected token '\(token.lexeme)' at \(token.position), expected \(expected)"
        case .expectedTokens(let expected):
            return "Expected one of: \(expected.map { $0.rawValue }.joined(separator: ", "))"
        case .expectedIdentifier:
            return "Expected identifier"
        case .expectedDataType:
            return "Expected data type"
        case .expectedToken(let expected):
            return "Expected token: \(expected)"
        case .expectedPrimaryExpression(let token):
            return "Expected primary expression at \(token.position), got '\(token.lexeme)'"
        case .inputTooLarge:
            return "Input too large for safe processing"
        case .nestingTooDeep:
            return "Nesting depth too deep, maximum allowed is 100 levels"
        case .identifierTooLong(let name):
            return "Identifier '\(name.prefix(20))...' is too long, maximum length is 255 characters"
        case .expressionTooComplex:
            return "Expression is too complex for safe evaluation"
        case .invalidArrayDimension:
            return "Invalid array dimension specification"
        case .invalidFunctionArity(let function, let expected, let actual):
            return "Function '\(function)' expects \(expected) arguments but received \(actual)"
        case .undeclaredVariable(let name):
            return "Undeclared variable '\(name)'"
        case .cyclicDependency(let cycle):
            return "Cyclic dependency detected: \(cycle.joined(separator: " -> "))"
        }
    }
}
