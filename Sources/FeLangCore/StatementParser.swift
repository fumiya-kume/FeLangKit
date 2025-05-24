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
    /// - Parameter tokens: Array of tokens to parse
    /// - Returns: Parsed statements
    /// - Throws: StatementParsingError if parsing fails
    public func parseStatements(from tokens: [Token]) throws -> [Statement] {
        var parser = TokenStream(tokens)
        var statements: [Statement] = []

        while let token = parser.peek(), token.type != .eof {
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

        // Look ahead to see if this is an assignment pattern
        var lookaheadIndex = parser.index + 1

        // Check for array access assignment: identifier[...] ←
        if lookaheadIndex < parser.tokens.count && parser.tokens[lookaheadIndex].type == .leftBracket {
            // Skip to matching right bracket
            var bracketCount = 1
            lookaheadIndex += 1
            while lookaheadIndex < parser.tokens.count && bracketCount > 0 {
                switch parser.tokens[lookaheadIndex].type {
                case .leftBracket:
                    bracketCount += 1
                case .rightBracket:
                    bracketCount -= 1
                default:
                    break
                }
                lookaheadIndex += 1
            }

            // Check if followed by assignment operator
            if lookaheadIndex < parser.tokens.count && parser.tokens[lookaheadIndex].type == .assign {
                return .assignment(try parseAssignment(&parser))
            }
        }

        // Check for simple variable assignment: identifier ←
        if lookaheadIndex < parser.tokens.count && parser.tokens[lookaheadIndex].type == .assign {
            return .assignment(try parseAssignment(&parser))
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
    private func parseExpression(_ parser: inout TokenStream) throws -> Expression {
        // For now, use the internal parsing until we can better integrate ExpressionParser
        // TODO: Improve integration by making ExpressionParser return consumed token count
        return try parseExpressionInternal(&parser)
    }

    /// Internal expression parsing that works with our token stream.
    private func parseExpressionInternal(_ parser: inout TokenStream) throws -> Expression {
        return try parseExpressionWithPrecedence(&parser, minPrecedence: 0)
    }

    /// Parses an expression with the specified minimum precedence.
    private func parseExpressionWithPrecedence(_ parser: inout TokenStream, minPrecedence: Int) throws -> Expression {
        // Parse left operand
        var leftExpr = try parseUnaryExpression(&parser)

        // Parse operators and right operands
        while let op = tryParseBinaryOperator(&parser, minPrecedence: minPrecedence) {
            // For left-associative operators, increase precedence by 1
            let nextMinPrec = op.isLeftAssociative ? op.precedence + 1 : op.precedence
            let rightExpr = try parseExpressionWithPrecedence(&parser, minPrecedence: nextMinPrec)

            // Combine into binary expression
            leftExpr = Expression.binary(op, leftExpr, rightExpr)
        }

        return leftExpr
    }

    /// Parses a unary expression.
    private func parseUnaryExpression(_ parser: inout TokenStream) throws -> Expression {
        // Try to parse unary operators
        if let op = tryParseUnaryOperator(&parser) {
            let expr = try parseUnaryExpression(&parser)
            return Expression.unary(op, expr)
        }

        // Parse postfix expressions
        return try parsePostfixExpression(&parser)
    }

    /// Parses postfix expressions (array access, field access, and function calls).
    private func parsePostfixExpression(_ parser: inout TokenStream) throws -> Expression {
        var expr = try parsePrimaryExpression(&parser)

        // Parse postfix operations
        while true {
            if parser.peek()?.type == .leftBracket {
                // Array access: expr[index]
                parser.advance() // consume '['
                let indexExpr = try parseExpressionWithPrecedence(&parser, minPrecedence: 0)
                try expectToken(&parser, .rightBracket)
                expr = Expression.arrayAccess(expr, indexExpr)
            } else if parser.peek()?.type == .dot {
                // Field access: expr.field
                parser.advance() // consume '.'
                guard let fieldToken = parser.advance(), fieldToken.type == .identifier else {
                    throw StatementParsingError.expectedIdentifier
                }
                expr = Expression.fieldAccess(expr, fieldToken.lexeme)
            } else if parser.peek()?.type == .leftParen,
                      case .identifier(let name) = expr {
                // Function call: identifier(args...)
                parser.advance() // consume '('
                let args = try parseArgumentList(&parser)
                try expectToken(&parser, .rightParen)
                expr = Expression.functionCall(name, args)
            } else {
                // No more postfix operations
                break
            }
        }

        return expr
    }

    /// Parses primary expressions (literals, identifiers, parentheses).
    private func parsePrimaryExpression(_ parser: inout TokenStream) throws -> Expression {
        guard let token = parser.advance() else {
            throw StatementParsingError.unexpectedEndOfInput
        }

        // Literal expressions
        if let literal = Literal(token: token) {
            return Expression.literal(literal)
        }

        // Identifier expressions
        if token.type == .identifier {
            return Expression.identifier(token.lexeme)
        }

        // Parenthesized expressions
        if token.type == .leftParen {
            let expr = try parseExpressionWithPrecedence(&parser, minPrecedence: 0)
            try expectToken(&parser, .rightParen)
            return expr
        }

        throw StatementParsingError.expectedPrimaryExpression(token)
    }

    /// Tries to parse a binary operator with minimum precedence.
    private func tryParseBinaryOperator(_ parser: inout TokenStream, minPrecedence: Int) -> BinaryOperator? {
        guard let token = parser.peek(),
              let op = BinaryOperator(tokenType: token.type),
              op.precedence >= minPrecedence else {
            return nil
        }

        parser.advance() // consume the operator
        return op
    }

    /// Tries to parse a unary operator.
    private func tryParseUnaryOperator(_ parser: inout TokenStream) -> UnaryOperator? {
        guard let token = parser.peek(),
              let op = UnaryOperator(tokenType: token.type) else {
            return nil
        }

        parser.advance() // consume the operator
        return op
    }

    /// Parses an argument list for function calls.
    private func parseArgumentList(_ parser: inout TokenStream) throws -> [Expression] {
        var arguments: [Expression] = []

        // Handle empty argument list
        if parser.peek()?.type == .rightParen {
            return arguments
        }

        // Parse first argument
        arguments.append(try parseExpressionWithPrecedence(&parser, minPrecedence: 0))

        // Parse remaining arguments
        while parser.peek()?.type == .comma {
            parser.advance() // consume ','
            arguments.append(try parseExpressionWithPrecedence(&parser, minPrecedence: 0))
        }

        return arguments
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

/// A simple token stream for parsing.
private struct TokenStream {
    let tokens: [Token]
    var index: Int = 0

    init(_ tokens: [Token]) {
        self.tokens = tokens
    }

    /// Peeks at the current token without consuming it.
    mutating func peek() -> Token? {
        guard index < tokens.count else { return nil }
        return tokens[index]
    }

    /// Advances to the next token and returns the current one.
    mutating func advance() -> Token? {
        guard index < tokens.count else { return nil }
        let token = tokens[index]
        index += 1
        return token
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
        }
    }
}
