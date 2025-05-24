import Foundation

/// A parser for FE pseudo-language expressions using precedence climbing.
/// This parser correctly handles operator precedence and left-associativity.
public struct ExpressionParser {

    public init() {}

    /// Parses an expression from an array of tokens.
    /// - Parameter tokens: Array of tokens to parse
    /// - Returns: Parsed expression
    /// - Throws: ParsingError if parsing fails
    public func parseExpression(from tokens: [Token]) throws -> Expression {
        var parser = TokenStream(tokens)
        let expression = try parseExpression(&parser)

        // Check if we've consumed all tokens (except EOF)
        if let remaining = parser.peek(), remaining.type != .eof {
            throw ParsingError.unexpectedToken(remaining, expected: .eof)
        }

        return expression
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
        while let op = tryParseBinaryOperator(&parser, minPrecedence: minPrecedence) {
            // For left-associative operators, increase precedence by 1
            let nextMinPrec = op.isLeftAssociative ? op.precedence + 1 : op.precedence
            let rightExpr = try parseExpression(&parser, minPrecedence: nextMinPrec)

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

    /// Parses postfix expressions (array access and function calls).
    private func parsePostfixExpression(_ parser: inout TokenStream) throws -> Expression {
        var expr = try parsePrimaryExpression(&parser)

        // Parse postfix operations
        while true {
            if parser.peek()?.type == .leftBracket {
                // Array access: expr[index]
                parser.advance() // consume '['
                let indexExpr = try parseExpression(&parser)
                try expectToken(&parser, .rightBracket)
                expr = Expression.arrayAccess(expr, indexExpr)
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
            throw ParsingError.unexpectedEndOfInput
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

        throw ParsingError.expectedPrimaryExpression(token)
    }

    // MARK: - Helper Methods

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

    /// Expects a specific token type and consumes it.
    private func expectToken(_ parser: inout TokenStream, _ expectedType: TokenType) throws {
        guard let token = parser.advance() else {
            throw ParsingError.unexpectedEndOfInput
        }

        guard token.type == expectedType else {
            throw ParsingError.unexpectedToken(token, expected: expectedType)
        }
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
            parser.advance() // consume ','
            arguments.append(try parseExpression(&parser))
        }

        return arguments
    }
}

// MARK: - TokenStream Helper

/// A simple token stream for parsing.
private struct TokenStream {
    private let tokens: [Token]
    private var index: Int = 0

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

// MARK: - Parsing Errors

/// Errors that can occur during expression parsing.
public enum ParsingError: Error, Equatable {
    case unexpectedEndOfInput
    case unexpectedToken(Token, expected: TokenType)
    case expectedPrimaryExpression(Token)
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
        }
    }
}
