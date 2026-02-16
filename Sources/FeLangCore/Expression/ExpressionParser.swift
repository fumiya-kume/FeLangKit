import Foundation

/// A parser for FE pseudo-language expressions using precedence climbing.
/// This parser correctly handles operator precedence and left-associativity.
public struct ExpressionParser {

    public init() {}

    /// Parses an expression from an array of tokens using precedence climbing.
    /// 
    /// This method processes tokens and returns a parsed Expression object using 
    /// the precedence climbing algorithm for correct operator precedence and associativity.
    /// Supports arithmetic, logical, comparison operators, function calls, array/field access.
    /// 
    /// - Parameter tokens: Array of tokens to parse, including an EOF token
    /// - Returns: Parsed Expression object representing the expression tree
    /// - Throws: ParsingError for syntax errors, unexpected tokens, or malformed expressions
    /// 
    /// Example:
    /// ```swift
    /// let tokens = try tokenizer.tokenize("a + b * c")
    /// let expr = try parser.parseExpression(from: tokens)
    /// // Returns: binary(.add, identifier("a"), binary(.multiply, identifier("b"), identifier("c")))
    /// ```
    public func parseExpression(from tokens: [Token]) throws -> Expression {
        var parser = TokenStream(tokens)
        let expression = try parseExpression(&parser)

        // Check if we've consumed all tokens (except EOF)
        if let remaining = parser.peek(), remaining.type != .eof {
            throw ParsingError.unexpectedToken(remaining, expected: .eof)
        }

        return expression
    }

    /// Parses an expression from a slice of a token array without copying.
    /// Returns the parsed expression and the index after the last consumed token.
    public func parseExpression(from tokens: [Token], startingAt startIndex: Int, endingBefore endIndex: Int) throws -> (Expression, Int) {
        guard startIndex >= 0, endIndex <= tokens.count, startIndex <= endIndex else {
            throw ParsingError.unexpectedEndOfInput
        }
        var parser = TokenStream(tokens, startIndex: startIndex, endIndex: endIndex)
        let expression = try parseExpression(&parser)

        // Check if we've consumed all tokens in the range (except EOF)
        if let remaining = parser.peek(), remaining.type != .eof {
            throw ParsingError.unexpectedToken(remaining, expected: .eof)
        }

        return (expression, parser.index)
    }

    /// Parses an expression with minimum precedence of 0.
    private func parseExpression(_ parser: inout TokenStream) throws -> Expression {
        return try parseExpression(&parser, minPrecedence: 0)
    }

    /// Parses an expression with the specified minimum precedence.
    /// This implements the precedence climbing algorithm.
    private func parseExpression(_ parser: inout TokenStream, minPrecedence: Int) throws -> Expression {
        // Parse left operand
        var leftExpr = try parseUnaryExpression(&parser)

        // Parse operators and right operands
        while let binaryOp = tryParseBinaryOperator(&parser, minPrecedence: minPrecedence) {
            // For left-associative operators, increase precedence by 1
            let nextMinPrec = binaryOp.isLeftAssociative ? binaryOp.precedence + 1 : binaryOp.precedence
            let rightExpr = try parseExpression(&parser, minPrecedence: nextMinPrec)

            // Combine into binary expression
            leftExpr = Expression.binary(binaryOp, leftExpr, rightExpr)
        }

        return leftExpr
    }

    /// Parses a unary expression.
    private func parseUnaryExpression(_ parser: inout TokenStream) throws -> Expression {
        // Try to parse unary operators
        if let unaryOp = tryParseUnaryOperator(&parser) {
            let expr = try parseUnaryExpression(&parser)
            return Expression.unary(unaryOp, expr)
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
                // Array access: expr[index] or expr[row, col] for 2D arrays
                _ = parser.advance() // consume '['
                let firstIndexExpr = try parseExpression(&parser)
                expr = Expression.arrayAccess(expr, firstIndexExpr)

                // Handle comma-separated indices for multi-dimensional array access
                // e.g., matrix[1, 2] is desugared to matrix[1][2]
                while parser.peek()?.type == .comma {
                    _ = parser.advance() // consume ','
                    let nextIndexExpr = try parseExpression(&parser)
                    expr = Expression.arrayAccess(expr, nextIndexExpr)
                }

                try expectToken(&parser, .rightBracket)
            } else if parser.peek()?.type == .dot {
                // Field access or method call: expr.field or expr.method(args)
                _ = parser.advance() // consume '.'
                guard let fieldToken = parser.advance(), fieldToken.type == .identifier else {
                    throw ParsingError.expectedIdentifier
                }
                // Check if this is a method call (followed by '(')
                if parser.peek()?.type == .leftParen {
                    _ = parser.advance() // consume '('
                    let args = try parseArgumentList(&parser)
                    try expectToken(&parser, .rightParen)
                    expr = Expression.methodCall(expr, fieldToken.lexeme, args)
                } else {
                    expr = Expression.fieldAccess(expr, fieldToken.lexeme)
                }
            } else if parser.peek()?.type == .leftParen,
                      case .identifier(let name) = expr {
                // Function call: identifier(args...)
                _ = parser.advance() // consume '('
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

    /// Parses primary expressions (literals, identifiers, parentheses, lambda, object, callable ref).
    private func parsePrimaryExpression(_ parser: inout TokenStream) throws -> Expression {
        guard let token = parser.advance() else {
            throw ParsingError.unexpectedEndOfInput
        }

        // Lambda literal: lambda(params): ReturnType { bodyExpr } or lambda { bodyExpr }
        if token.type == .lambdaKeyword {
            return try parseLambdaLiteral(&parser)
        }

        // Object literal: object { field ← expr, ... }
        if token.type == .objectKeyword {
            try expectToken(&parser, .leftBrace)
            return try parseObjectLiteral(&parser)
        }

        // Callable reference: ::functionName
        if token.type == .doubleColon {
            guard let nameToken = parser.advance(), nameToken.type == .identifier else {
                throw ParsingError.expectedIdentifier
            }
            return Expression.callableRef(nameToken.lexeme)
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
            let expr = try parseExpression(&parser)
            try expectToken(&parser, .rightParen)
            return expr
        }

        // Array literal expressions [e1, e2, ...] or {e1, e2, ...} (FE pseudo-language syntax)
        if token.type == .leftBracket {
            return try parseArrayLiteral(&parser, closingToken: .rightBracket)
        }

        if token.type == .leftBrace {
            return try parseArrayLiteral(&parser, closingToken: .rightBrace)
        }

        throw ParsingError.expectedPrimaryExpression(token)
    }

    /// Parses a lambda literal after consuming the `lambda` keyword.
    private func parseLambdaLiteral(_ parser: inout TokenStream) throws -> Expression {
        var parameters: [Parameter] = []
        var returnType: DataType?

        // Optional parameter list: (param: Type, ...)
        if parser.peek()?.type == .leftParen {
            _ = parser.advance() // consume '('
            parameters = try parseLambdaParameters(&parser)
            try expectToken(&parser, .rightParen)
        }

        // Optional return type: : Type
        if parser.peek()?.type == .colon {
            _ = parser.advance() // consume ':'
            returnType = try parseLambdaReturnType(&parser)
        }

        // Body expression in braces: { expr }
        try expectToken(&parser, .leftBrace)
        let body = try parseExpression(&parser)
        try expectToken(&parser, .rightBrace)

        return Expression.lambdaLiteral(parameters, returnType, body)
    }

    /// Parses lambda parameter list.
    private func parseLambdaParameters(_ parser: inout TokenStream) throws -> [Parameter] {
        var params: [Parameter] = []
        if parser.peek()?.type == .rightParen {
            return params
        }
        params.append(try parseSingleParameter(&parser))
        while parser.peek()?.type == .comma {
            _ = parser.advance() // consume ','
            params.append(try parseSingleParameter(&parser))
        }
        return params
    }

    /// Parses a single parameter: name: Type
    private func parseSingleParameter(_ parser: inout TokenStream) throws -> Parameter {
        guard let nameToken = parser.advance(), nameToken.type == .identifier else {
            throw ParsingError.expectedIdentifier
        }
        try expectToken(&parser, .colon)
        let dataType = try parseLambdaReturnType(&parser)
        return Parameter(name: nameToken.lexeme, type: dataType)
    }

    /// Parses a data type token.
    private func parseLambdaReturnType(_ parser: inout TokenStream) throws -> DataType {
        guard let typeToken = parser.advance() else {
            throw ParsingError.unexpectedEndOfInput
        }
        guard let dataType = DataType(tokenType: typeToken.type) else {
            throw ParsingError.unexpectedToken(typeToken, expected: .integerType)
        }
        return dataType
    }

    /// Parses an object literal after consuming `object {`.
    private func parseObjectLiteral(_ parser: inout TokenStream) throws -> Expression {
        var fields: [ObjectLiteralField] = []
        if parser.peek()?.type == .rightBrace {
            _ = parser.advance()
            return Expression.objectLiteral(fields)
        }
        fields.append(try parseObjectField(&parser))
        while parser.peek()?.type == .comma {
            _ = parser.advance() // consume ','
            fields.append(try parseObjectField(&parser))
        }
        try expectToken(&parser, .rightBrace)
        return Expression.objectLiteral(fields)
    }

    /// Parses a single object field: name ← expr
    private func parseObjectField(_ parser: inout TokenStream) throws -> ObjectLiteralField {
        guard let nameToken = parser.advance(), nameToken.type == .identifier else {
            throw ParsingError.expectedIdentifier
        }
        try expectToken(&parser, .assign)
        let value = try parseExpression(&parser)
        return ObjectLiteralField(name: nameToken.lexeme, value: value)
    }

    // MARK: - Helper Methods

    /// Tries to parse a binary operator with minimum precedence.
    private func tryParseBinaryOperator(_ parser: inout TokenStream, minPrecedence: Int) -> BinaryOperator? {
        guard let token = parser.peek(),
              let binaryOp = BinaryOperator(tokenType: token.type),
              binaryOp.precedence >= minPrecedence else {
            return nil
        }

        _ = parser.advance() // consume the operator
        return binaryOp
    }

    /// Tries to parse a unary operator.
    private func tryParseUnaryOperator(_ parser: inout TokenStream) -> UnaryOperator? {
        guard let token = parser.peek(),
              let unaryOp = UnaryOperator(tokenType: token.type) else {
            return nil
        }

        _ = parser.advance() // consume the operator
        return unaryOp
    }

    /// Expects a specific token type and consumes it.
    private func expectToken(_ parser: inout TokenStream, _ expectedType: TokenType) throws {
        guard let token = parser.advance() else {
            throw ParsingError.unexpectedEndOfInput
        }

        guard token.type == expectedType else {
            throw ParsingError.unexpectedToken(token, expected: expectedType)
        }
    }

    /// Parses an array literal with comma-separated elements until the closing token.
    private func parseArrayLiteral(_ parser: inout TokenStream, closingToken: TokenType) throws -> Expression {
        var elements: [Expression] = []

        // Handle empty array literal
        if parser.peek()?.type == closingToken {
            _ = parser.advance()
            return Expression.arrayLiteral(elements)
        }

        // Parse first element
        elements.append(try parseExpression(&parser))

        // Parse remaining elements
        while parser.peek()?.type == .comma {
            _ = parser.advance() // consume ','
            elements.append(try parseExpression(&parser))
        }

        try expectToken(&parser, closingToken)
        return Expression.arrayLiteral(elements)
    }

    /// Parses an argument list for function calls.
    private func parseArgumentList(_ parser: inout TokenStream) throws -> [Expression] {
        var arguments: [Expression] = []

        // Handle empty argument list
        if parser.peek()?.type == .rightParen {
            return arguments
        }

        // Parse first argument
        arguments.append(try parseExpression(&parser))

        // Parse remaining arguments
        while parser.peek()?.type == .comma {
            _ = parser.advance() // consume ','
            arguments.append(try parseExpression(&parser))
        }

        return arguments
    }
}

// MARK: - TokenStream Helper

/// A simple token stream for parsing.
private struct TokenStream {
    let tokens: [Token]
    var index: Int = 0
    private let endIndex: Int

    init(_ tokens: [Token]) {
        self.tokens = tokens
        self.endIndex = tokens.count
        // Placeholder value; unbounded streams always hit the real EOF token
        self.syntheticEOF = Token(type: .eof, lexeme: "", position: SourcePosition(line: 0, column: 0, offset: 0))
    }

    init(_ tokens: [Token], startIndex: Int, endIndex: Int) {
        self.tokens = tokens
        self.index = startIndex
        self.endIndex = endIndex

        // Derive position from the boundary token (or last token) for accurate error messages
        let boundaryPosition: SourcePosition
        if endIndex < tokens.count {
            boundaryPosition = tokens[endIndex].position
        } else if let lastToken = tokens.last {
            boundaryPosition = lastToken.position
        } else {
            boundaryPosition = SourcePosition(line: 1, column: 1, offset: 0)
        }
        self.syntheticEOF = Token(type: .eof, lexeme: "", position: boundaryPosition)
    }

    /// Synthetic EOF token returned at the boundary of a bounded stream.
    private let syntheticEOF: Token

    /// Peeks at the current token without consuming it.
    func peek() -> Token? {
        guard index < endIndex else {
            // Return synthetic EOF at boundary to match previous copy+append behavior
            return index < tokens.count ? syntheticEOF : nil
        }
        return tokens[index]
    }

    /// Advances to the next token and returns the current one.
    mutating func advance() -> Token? {
        guard index < endIndex else {
            return index < tokens.count ? syntheticEOF : nil
        }
        let token = tokens[index]
        index += 1
        return token
    }
}

// MARK: - Parsing Errors

/// Errors that can occur during expression parsing.
public enum ParsingError: Error, Equatable {
    case unexpectedEndOfInput
    case unexpectedToken(Token, expected: TokenType)
    case expectedPrimaryExpression(Token)
    case expectedIdentifier
}

extension ParsingError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unexpectedEndOfInput:
            return "Unexpected end of input"
        case .unexpectedToken(let token, let expected):
            return "Unexpected token '\(token.lexeme)' at \(token.position), expected \(expected)"
        case .expectedPrimaryExpression(let token):
            return "Expected primary expression at \(token.position), got '\(token.lexeme)'"
        case .expectedIdentifier:
            return "Expected identifier"
        }
    }
}
