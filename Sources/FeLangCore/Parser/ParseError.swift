import Foundation

/// A unified parse error type that provides detailed position information and context.
/// This error type is used across all parser modules for consistent error reporting.
public struct ParseError: Error, CustomStringConvertible, Equatable, Sendable {
    public let message: String
    public let line: Int
    public let column: Int
    public let context: ErrorContext?

    public init(message: String, line: Int, column: Int, context: ErrorContext? = nil) {
        self.message = message
        self.line = line
        self.column = column
        self.context = context
    }

    public var description: String {
        if let context = context {
            return "ParseError: \(message)\n  at line \(line), column \(column)\n\(context.description)"
        } else {
            return "ParseError: \(message)\n  at line \(line), column \(column)"
        }
    }

    /// Additional context information for error reporting
    public struct ErrorContext: Equatable, Sendable {
        public let sourceText: String?
        public let expectedTokens: [String]?
        public let foundToken: String?

        public init(sourceText: String? = nil, expectedTokens: [String]? = nil, foundToken: String? = nil) {
            self.sourceText = sourceText
            self.expectedTokens = expectedTokens
            self.foundToken = foundToken
        }

        public var description: String {
            var result = ""

            if let expected = expectedTokens, !expected.isEmpty {
                result += "  Expected: \(expected.joined(separator: ", "))\n"
            }

            if let found = foundToken {
                result += "  Found: '\(found)'\n"
            }

            if let source = sourceText {
                result += "  Source context:\n\(source)"
            }

            return result
        }
    }
}

// MARK: - Conversion Utilities

extension ParseError {
    /// Creates a ParseError from a StatementParsingError
    public static func from(_ error: StatementParsingError, at token: Token? = nil) -> ParseError {
        let (line, column) = token?.position.lineColumn ?? (0, 0)
        let message: String

        switch error {
        case .unexpectedEndOfInput:
            message = "Unexpected end of input"
        case .unexpectedToken(let token, let expected):
            return ParseError(
                message: "Unexpected token '\(token.lexeme)'",
                line: token.position.line,
                column: token.position.column,
                context: ErrorContext(
                    expectedTokens: [String(describing: expected)],
                    foundToken: token.lexeme
                )
            )
        case .expectedTokens(let expected):
            message = "Expected one of: \(expected.map { String(describing: $0) }.joined(separator: ", "))"
        case .expectedIdentifier:
            message = "Expected identifier"
        case .expectedDataType:
            message = "Expected data type"
        case .expectedToken(let expected):
            message = "Expected token: \(String(describing: expected))"
        case .expectedPrimaryExpression(let token):
            return ParseError(
                message: "Expected primary expression",
                line: token.position.line,
                column: token.position.column,
                context: ErrorContext(foundToken: token.lexeme)
            )
        case .inputTooLarge:
            message = "Input too large for safe processing"
        case .nestingTooDeep:
            message = "Nesting depth too deep"
        case .identifierTooLong(let name):
            message = "Identifier '\(name.prefix(20))...' is too long"
        case .expressionTooComplex:
            message = "Expression is too complex for safe evaluation"
        case .invalidArrayDimension:
            message = "Invalid array dimension specification"
        case .invalidFunctionArity(let function, let expected, let actual):
            message = "Function '\(function)' expects \(expected) arguments but received \(actual)"
        case .undeclaredVariable(let name):
            message = "Undeclared variable '\(name)'"
        case .cyclicDependency(let cycle):
            message = "Cyclic dependency detected: \(cycle.joined(separator: " -> "))"
        }

        return ParseError(message: message, line: line, column: column)
    }

    /// Creates a ParseError from a ParsingError
    public static func from(_ error: ParsingError, at token: Token? = nil) -> ParseError {
        let (line, column) = token?.position.lineColumn ?? (0, 0)
        let message: String

        switch error {
        case .unexpectedEndOfInput:
            message = "Unexpected end of input"
        case .unexpectedToken(let token, let expected):
            return ParseError(
                message: "Unexpected token '\(token.lexeme)'",
                line: token.position.line,
                column: token.position.column,
                context: ErrorContext(
                    expectedTokens: [String(describing: expected)],
                    foundToken: token.lexeme
                )
            )
        case .expectedPrimaryExpression(let token):
            return ParseError(
                message: "Expected primary expression",
                line: token.position.line,
                column: token.position.column,
                context: ErrorContext(foundToken: token.lexeme)
            )
        case .expectedIdentifier:
            message = "Expected identifier"
        }

        return ParseError(message: message, line: line, column: column)
    }
}

// MARK: - Position Extensions

extension SourcePosition {
    var lineColumn: (Int, Int) {
        return (line, column)
    }
}
