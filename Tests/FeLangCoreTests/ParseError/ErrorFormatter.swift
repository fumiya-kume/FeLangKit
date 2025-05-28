import Foundation
@testable import FeLangCore

// MARK: - Infrastructure Components

/// Component-based error message building infrastructure.
/// Represents individual components that can be composed to create error messages.
internal enum ErrorMessageComponent {
    case prefix(String)
    case message(String)
    case position(SourcePosition)
    case expected(String)
    case found(String)
    case keyValue(key: String, value: String)
    case detail(String)
}

/// Flexible error message builder that composes components into formatted strings.
internal struct ErrorMessageBuilder {
    private var components: [ErrorMessageComponent] = []

    /// Adds a component to the builder.
    /// - Parameter component: The component to add
    /// - Returns: Self for method chaining
    @discardableResult
    mutating func add(_ component: ErrorMessageComponent) -> Self {
        components.append(component)
        return self
    }

    /// Builds the final error message string.
    /// - Returns: Formatted error message
    func build() -> String {
        var result = ""
        var details: [String] = []

        for component in components {
            switch component {
            case .prefix(let text):
                result += text
            case .message(let text):
                result += text
            case .position(let pos):
                details.append("at \(ErrorFormatter.formatPosition(pos))")
            case .expected(let text):
                details.append("Expected: \(text)")
            case .found(let text):
                details.append("Found: '\(text)'")
            case .keyValue(let key, let value):
                details.append("\(key): \(value)")
            case .detail(let text):
                details.append(text)
            }
        }

        // Append details on separate lines with proper indentation
        if !details.isEmpty {
            result += "\n  " + details.joined(separator: "\n  ")
        }

        return result
    }
}

/// Common error patterns that can be reused across different error types.
internal enum CommonErrorPattern {
    case tokenBased(TokenBasedErrorInfo)
    case simple(message: String, detail: String?)
    case complex(message: String, details: [(String, String)])
    case endOfInput(context: String)
}

/// Protocol for token-based error information.
internal protocol TokenBasedErrorInfo {
    var token: Token { get }
    var expectedDescription: String { get }
    var context: String? { get }
}

/// Concrete implementation of token-based error info.
internal struct TokenBasedError: TokenBasedErrorInfo {
    let token: Token
    let expectedDescription: String
    let context: String?

    init(token: Token, expected: String, context: String? = nil) {
        self.token = token
        self.expectedDescription = expected
        self.context = context
    }
}

/// Provides consistent error message formatting for ParseError testing.
/// This formatter ensures that error messages are standardized across the golden file test suite
/// and provides clear, actionable feedback for parsing failures.
public struct ErrorFormatter {

    // MARK: - Public Interface

    /// Formats any parsing-related error into a standardized string representation.
    /// This method handles both ExpressionParser errors and StatementParser errors,
    /// ensuring consistent formatting across all parse error scenarios.
    ///
    /// - Parameter error: The error to format (ParsingError or StatementParsingError)
    /// - Returns: A formatted error string suitable for golden file comparison
    public static func format(_ error: Error) -> String {
        switch error {
        case let parsingError as ParsingError:
            return formatCommonPattern(parsingError.commonPattern, prefix: "ParseError")
        case let statementError as StatementParsingError:
            return formatCommonPattern(statementError.commonPattern, prefix: "StatementParseError")
        default:
            return "UnknownParseError: \(error.localizedDescription)"
        }
    }

    /// Formats a parsing error with detailed context information.
    /// Includes error type, position information, and expected vs actual tokens.
    ///
    /// - Parameters:
    ///   - error: The parsing error to format
    ///   - input: Optional input source for additional context
    /// - Returns: A comprehensive error message with source context
    public static func formatWithContext(_ error: Error, input: String? = nil) -> String {
        let basicFormat = format(error)

        guard let input = input else {
            return basicFormat
        }

        // Add source context if position information is available
        if let position = extractPosition(from: error) {
            let contextLines = extractSourceContext(input: input, position: position)
            return basicFormat + "\n" + contextLines
        }

        return basicFormat
    }

    // MARK: - Unified Formatting Functions

    /// Formats common error patterns using a centralized approach.
    /// - Parameters:
    ///   - pattern: The common error pattern to format
    ///   - prefix: The error type prefix (e.g., "ParseError", "StatementParseError")
    /// - Returns: Formatted error message
    internal static func formatCommonPattern(_ pattern: CommonErrorPattern, prefix: String) -> String {
        var builder = ErrorMessageBuilder()
        builder.add(.prefix("\(prefix): "))

        switch pattern {
        case .tokenBased(let info):
            builder.add(.message("Unexpected token '\(info.token.lexeme)'"))
            builder.add(.position(info.token.position))
            builder.add(.expected(info.expectedDescription))
            if let context = info.context {
                builder.add(.detail(context))
            }

        case .simple(let message, let detail):
            builder.add(.message(message))
            if let detail = detail {
                builder.add(.detail(detail))
            }

        case .complex(let message, let details):
            builder.add(.message(message))
            for (key, value) in details {
                builder.add(.keyValue(key: key, value: value))
            }

        case .endOfInput(let context):
            builder.add(.message("Unexpected end of input"))
            builder.add(.expected(context))
        }

        return builder.build()
    }

    // MARK: - Position Formatting

    internal static func formatPosition(_ position: SourcePosition) -> String {
        return "line \(position.line), column \(position.column)"
    }

    // MARK: - Context Extraction

    private static func extractPosition(from error: Error) -> SourcePosition? {
        switch error {
        case let parsingError as ParsingError:
            switch parsingError {
            case .unexpectedToken(let token, _),
                 .expectedPrimaryExpression(let token):
                return token.position
            default:
                return nil
            }
        case let statementError as StatementParsingError:
            switch statementError {
            case .unexpectedToken(let token, _),
                 .expectedPrimaryExpression(let token):
                return token.position
            default:
                return nil
            }
        default:
            return nil
        }
    }

    private static func extractSourceContext(input: String, position: SourcePosition) -> String {
        let lines = input.components(separatedBy: .newlines)

        guard position.line > 0 && position.line <= lines.count else {
            return "  (Source context unavailable)"
        }

        let currentLine = lines[position.line - 1]
        let lineNumber = position.line

        var context = "  Source context:\n"
        context += "  \(lineNumber): \(currentLine)\n"

        // Add pointer to the error position
        let spaces = String(repeating: " ", count: position.column - 1)
        let lineNumberPadding = String(repeating: " ", count: "\(lineNumber): ".count)
        context += "  \(lineNumberPadding)\(spaces)^"

        return context
    }
}

// MARK: - Error Extensions for Common Patterns

extension ParsingError {
    /// Converts the error to a common pattern for unified formatting.
    var commonPattern: CommonErrorPattern {
        switch self {
        case .unexpectedEndOfInput:
            return .endOfInput(context: "expression or statement")

        case .unexpectedToken(let token, let expected):
            return .tokenBased(TokenBasedError(token: token, expected: "\(expected)"))

        case .expectedPrimaryExpression(let token):
            return .simple(message: "Expected primary expression", detail: "at \(ErrorFormatter.formatPosition(token.position))\n  Found: '\(token.lexeme)'")

        case .expectedIdentifier:
            return .simple(message: "Expected identifier", detail: "Found: invalid or missing identifier")
        }
    }
}

extension StatementParsingError {
    /// Converts the error to a common pattern for unified formatting.
    var commonPattern: CommonErrorPattern {
        switch self {
        case .unexpectedEndOfInput:
            return .endOfInput(context: "complete statement")

        case .unexpectedToken(let token, let expected):
            return .tokenBased(TokenBasedError(token: token, expected: "\(expected)"))

        case .expectedPrimaryExpression(let token):
            return .simple(message: "Expected primary expression", detail: "at \(ErrorFormatter.formatPosition(token.position))\n  Found: '\(token.lexeme)'")

        case .expectedIdentifier:
            return .simple(message: "Expected identifier", detail: "Found: invalid or missing identifier")

        case .expectedTokens(let expectedTokens):
            let tokenList = expectedTokens.map { "\($0)" }.joined(separator: ", ")
            return .simple(message: "Expected one of: \(tokenList)", detail: nil)

        case .expectedDataType:
            return .simple(message: "Expected data type", detail: "Expected: integer, real, string, boolean, array, or record type")

        case .expectedToken(let expected):
            return .simple(message: "Expected token '\(expected)'", detail: "Token missing or incorrect")

        case .inputTooLarge:
            return .simple(message: "Input too large for safe processing", detail: "Maximum input size exceeded (100,000 tokens)")

        case .nestingTooDeep:
            return .simple(message: "Nesting depth too deep", detail: "Maximum nesting depth exceeded (100 levels)")

        case .identifierTooLong(let name):
            let truncated = String(name.prefix(20))
            return .complex(message: "Identifier too long", details: [
                ("Identifier", "'\(truncated)...'"),
                ("Maximum length exceeded", "255 characters")
            ])

        case .expressionTooComplex:
            return .simple(message: "Expression too complex", detail: "Expression complexity exceeds safe evaluation limits")

        case .invalidArrayDimension:
            return .simple(message: "Invalid array dimension", detail: "Array dimension specification is malformed")

        case .invalidFunctionArity(let function, let expected, let actual):
            return .complex(message: "Invalid function arity", details: [
                ("Function", "'\(function)'"),
                ("Expected", "\(expected) arguments"),
                ("Actual", "\(actual) arguments")
            ])

        case .undeclaredVariable(let name):
            return .complex(message: "Undeclared variable", details: [
                ("Variable", "'\(name)'"),
                ("Note", "Variable must be declared before use")
            ])

        case .cyclicDependency(let variables):
            let varList = variables.joined(separator: " -> ")
            return .simple(message: "Cyclic dependency detected", detail: "Dependency chain: \(varList)")
        }
    }
}
