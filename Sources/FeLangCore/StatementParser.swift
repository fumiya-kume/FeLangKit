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
            // Skip newlines and whitespace
            if token.type == .newline || token.type == .whitespace {
                parser.advance()
                continue
            }

            // Track nesting depth for security
            switch token.type {
            case .ifKeyword, .whileKeyword, .forKeyword, .functionKeyword, .procedureKeyword:
                nestingDepth += 1
                guard nestingDepth <= maxNestingDepth else {
                    throw StatementParsingError.nestingTooDeep
                }
            case .endifKeyword, .endwhileKeyword, .endforKeyword, .endfunctionKeyword, .endprocedureKeyword:
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
    private func parseStatement(_ parser: inout TokenStream) throws -> Statement {
        guard let token = parser.peek() else {
            throw StatementParsingError.unexpectedEndOfInput
        }

        switch token.type {
        case .ifKeyword:
            return .ifStatement(try parseIfStatement(&parser))
        case .whileKeyword:
            return .whileStatement(try parseWhileStatement(&parser))
        case .forKeyword:
            return .forStatement(try parseForStatement(&parser))
        case .functionKeyword:
            return .functionDeclaration(try parseFunctionDeclaration(&parser))
        case .procedureKeyword:
            return .procedureDeclaration(try parseProcedureDeclaration(&parser))
        case .returnKeyword:
            return .returnStatement(try parseReturnStatement(&parser))
        case .breakKeyword:
            parser.advance() // consume 'break'
            return .breakStatement
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
    private func parseIfStatement(_ parser: inout TokenStream) throws -> IfStatement {
        try expectToken(&parser, .ifKeyword) // consume 'if'

        let condition = try parseExpression(&parser)
        try expectToken(&parser, .thenKeyword) // consume 'then'

        let thenBody = try parseBlock(&parser, until: [.elseKeyword, .elifKeyword, .endifKeyword])

        var elseIfs: [IfStatement.ElseIf] = []
        var elseBody: [Statement]?

        // Handle ELIF clauses
        while parser.peek()?.type == .elifKeyword {
            parser.advance() // consume 'elif'
            let elifCondition = try parseExpression(&parser)
            try expectToken(&parser, .thenKeyword) // consume 'then'
            let elifBody = try parseBlock(&parser, until: [.elseKeyword, .elifKeyword, .endifKeyword])
            elseIfs.append(IfStatement.ElseIf(condition: elifCondition, body: elifBody))
        }

        // Handle optional ELSE clause
        if parser.peek()?.type == .elseKeyword {
            parser.advance() // consume 'else'
            elseBody = try parseBlock(&parser, until: [.endifKeyword])
        }

        try expectToken(&parser, .endifKeyword) // consume 'endif'

        return IfStatement(condition: condition, thenBody: thenBody, elseIfs: elseIfs, elseBody: elseBody)
    }

    /// Parses a WHILE statement (while-do-endwhile).
    private func parseWhileStatement(_ parser: inout TokenStream) throws -> WhileStatement {
        try expectToken(&parser, .whileKeyword) // consume 'while'

        let condition = try parseExpression(&parser)
        try expectToken(&parser, .doKeyword) // consume 'do'

        let body = try parseBlock(&parser, until: [.endwhileKeyword])

        try expectToken(&parser, .endwhileKeyword) // consume 'endwhile'

        return WhileStatement(condition: condition, body: body)
    }

    /// Parses a FOR statement (range-based or forEach).
    private func parseForStatement(_ parser: inout TokenStream) throws -> ForStatement {
        try expectToken(&parser, .forKeyword) // consume 'for'

        guard let varToken = parser.advance(), varToken.type == .identifier else {
            throw StatementParsingError.expectedIdentifier
        }
        let variable = varToken.lexeme

        // Check if it's a range-based FOR (variable ← start to end) or forEach (variable in iterable)
        if parser.peek()?.type == .assign {
            // Range-based FOR: for i ← 1 to 10 step 1 do
            parser.advance() // consume '←'

            let start = try parseExpression(&parser)
            try expectToken(&parser, .toKeyword) // consume 'to'
            let end = try parseExpression(&parser)

            // Optional step clause
            var step: Expression?
            if parser.peek()?.type == .stepKeyword {
                parser.advance() // consume 'step'
                step = try parseExpression(&parser)
            }

            try expectToken(&parser, .doKeyword) // consume 'do'
            let body = try parseBlock(&parser, until: [.endforKeyword])
            try expectToken(&parser, .endforKeyword) // consume 'endfor'

            let rangeFor = ForStatement.RangeFor(variable: variable, start: start, end: end, step: step, body: body)
            return .range(rangeFor)
        } else if parser.peek()?.type == .inKeyword {
            // ForEach: for item in array do
            parser.advance() // consume 'in'

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

        // Not an assignment, parse as expression
        let expression = try parseExpression(&parser)
        return .expressionStatement(expression)
    }

    /// Parses an assignment statement (variable ← expression or array[index] ← expression).
    private func parseAssignment(_ parser: inout TokenStream) throws -> Assignment {
        guard let identifierToken = parser.advance(), identifierToken.type == .identifier else {
            throw StatementParsingError.expectedIdentifier
        }
        let identifier = identifierToken.lexeme

        // Check if it's array element assignment
        if parser.peek()?.type == .leftBracket {
            // Array element assignment: array[index] ← expression
            parser.advance() // consume '['
            let indexExpr = try parseExpression(&parser)
            try expectToken(&parser, .rightBracket) // consume ']'
            try expectToken(&parser, .assign) // consume '←'
            let valueExpr = try parseExpression(&parser)

            let arrayAccess = Assignment.ArrayAccess(array: .identifier(identifier), index: indexExpr)
            return .arrayElement(arrayAccess, valueExpr)
        } else if parser.peek()?.type == .assign {
            // Variable assignment: variable ← expression
            parser.advance() // consume '←'
            let valueExpr = try parseExpression(&parser)
            return .variable(identifier, valueExpr)
        } else {
            throw StatementParsingError.expectedToken(.assign)
        }
    }

    // MARK: - Function/Procedure Parsing

    /// Parses a function declaration.
    private func parseFunctionDeclaration(_ parser: inout TokenStream) throws -> FunctionDeclaration {
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
            parser.advance() // consume ':'
            returnType = try parseDataType(&parser)
        }

        // Parse local variable declarations and body
        let (localVariables, body) = try parseFunctionBody(&parser, endToken: .endfunctionKeyword)

        try expectToken(&parser, .endfunctionKeyword) // consume 'endfunction'

        return FunctionDeclaration(name: name, parameters: parameters, returnType: returnType, localVariables: localVariables, body: body)
    }

    /// Parses a procedure declaration.
    private func parseProcedureDeclaration(_ parser: inout TokenStream) throws -> ProcedureDeclaration {
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

        return ProcedureDeclaration(name: name, parameters: parameters, localVariables: localVariables, body: body)
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

    // MARK: - Helper Parsing Methods

    /// Parses a block of statements until one of the end tokens is encountered.
    private func parseBlock(_ parser: inout TokenStream, until endTokens: [TokenType]) throws -> [Statement] {
        var statements: [Statement] = []

        while let token = parser.peek(), !endTokens.contains(token.type) && token.type != .eof {
            // Skip newlines and whitespace
            if token.type == .newline || token.type == .whitespace {
                parser.advance()
                continue
            }

            let statement = try parseStatement(&parser)
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
            parser.advance() // consume ','
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

    /// Parses a data type.
    private func parseDataType(_ parser: inout TokenStream) throws -> DataType {
        guard let typeToken = parser.advance() else {
            throw StatementParsingError.unexpectedEndOfInput
        }

        if let basicType = DataType(tokenType: typeToken.type) {
            return basicType
        }

        // Handle array types properly
        if typeToken.type == .arrayType {
            // Expect "of" keyword followed by element type
            if parser.peek()?.lexeme == "of" {
                parser.advance() // consume "of"
                let elementType = try parseDataType(&parser)
                return .array(elementType)
            } else {
                // Default to integer array for backwards compatibility
                return .array(.integer)
            }
        }

        // Handle record types properly  
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
        var localVariables: [VariableDeclaration] = []
        var statements: [Statement] = []

        // Parse local variable declarations (simplified for now)
        // In a full implementation, this would parse actual variable declaration syntax

        // Parse statements until end token
        while let token = parser.peek(), token.type != endToken && token.type != .eof {
            // Skip newlines and whitespace
            if token.type == .newline || token.type == .whitespace {
                parser.advance()
                continue
            }

            let statement = try parseStatement(&parser)
            statements.append(statement)
        }

        return (localVariables, statements)
    }

    /// Parses an expression using the ExpressionParser.
    /// This method creates a substream of tokens and delegates to ExpressionParser.
    private func parseExpression(_ parser: inout TokenStream) throws -> Expression {
        // Collect tokens until we find a statement boundary or EOF
        var expressionTokens: [Token] = []
        let startIndex = parser.index
        
        // Look ahead to find the end of the expression
        var parenDepth = 0
        var bracketDepth = 0
        
        while let token = parser.peek() {
            switch token.type {
            case .leftParen:
                parenDepth += 1
                expressionTokens.append(token)
                parser.advance()
            case .rightParen:
                if parenDepth > 0 {
                    parenDepth -= 1
                    expressionTokens.append(token)
                    parser.advance()
                } else {
                    break
                }
            case .leftBracket:
                bracketDepth += 1
                expressionTokens.append(token)
                parser.advance()
            case .rightBracket:
                if bracketDepth > 0 {
                    bracketDepth -= 1
                    expressionTokens.append(token)
                    parser.advance()
                } else {
                    break
                }
            case .comma, .thenKeyword, .doKeyword, .endifKeyword, .endwhileKeyword, .endforKeyword, 
                 .endfunctionKeyword, .endprocedureKeyword, .elseKeyword, .elifKeyword, .newline, .eof:
                if parenDepth == 0 && bracketDepth == 0 {
                    break
                }
                expressionTokens.append(token)
                parser.advance()
            default:
                expressionTokens.append(token)
                parser.advance()
            }
        }
        
        // Add EOF token if not present
        if expressionTokens.last?.type != .eof {
            let lastPosition = expressionTokens.last?.position ?? 
                SourcePosition(line: 1, column: 1, offset: 0)
            expressionTokens.append(Token(type: .eof, lexeme: "", position: lastPosition))
        }
        
        // Parse the expression tokens using ExpressionParser
        do {
            return try expressionParser.parseExpression(from: expressionTokens)
        } catch {
            // Convert ExpressionParser errors to StatementParser errors
            switch error {
            case ParsingError.unexpectedEndOfInput:
                throw StatementParsingError.unexpectedEndOfInput
            case ParsingError.unexpectedToken(let token, let expected):
                throw StatementParsingError.unexpectedToken(token, expected: expected)
            case ParsingError.expectedPrimaryExpression(let token):
                throw StatementParsingError.expectedPrimaryExpression(token)
            case ParsingError.expectedIdentifier:
                throw StatementParsingError.expectedIdentifier
            default:
                throw error
            }
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
        }
    }
}
