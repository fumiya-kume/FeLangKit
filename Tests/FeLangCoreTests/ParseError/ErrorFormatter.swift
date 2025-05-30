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
    case semantic(SemanticErrorInfo)
}

/// Protocol for semantic error information.
internal protocol SemanticErrorInfo {
    var message: String { get }
    var position: SourcePosition { get }
    var details: [String] { get }
    var suggestions: [String] { get }
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
    /// This method handles ExpressionParser errors, StatementParser errors, and SemanticErrors,
    /// ensuring consistent formatting across all error scenarios.
    ///
    /// - Parameter error: The error to format (ParsingError, StatementParsingError, or SemanticError)
    /// - Returns: A formatted error string suitable for golden file comparison
    public static func format(_ error: Error) -> String {
        switch error {
        case let parsingError as ParsingError:
            return formatCommonPattern(parsingError.commonPattern, prefix: "ParseError")
        case let statementError as StatementParsingError:
            return formatCommonPattern(statementError.commonPattern, prefix: "StatementParseError")
        case let semanticError as SemanticError:
            return formatCommonPattern(semanticError.commonPattern, prefix: "SemanticError")
        default:
            return "UnknownError: \(error.localizedDescription)"
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

        case .semantic(let info):
            builder.add(.message(info.message))
            builder.add(.position(info.position))
            for detail in info.details {
                builder.add(.detail(detail))
            }
            for suggestion in info.suggestions {
                builder.add(.detail("Suggestion: \(suggestion)"))
            }
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
        case let semanticError as SemanticError:
            // Extract position from semantic errors
            switch semanticError {
            case .typeMismatch(_, _, let pos),
                 .incompatibleTypes(_, _, _, let pos),
                 .unknownType(_, let pos),
                 .invalidTypeConversion(_, _, let pos),
                 .undeclaredVariable(_, let pos),
                 .variableAlreadyDeclared(_, let pos),
                 .variableNotInitialized(_, let pos),
                 .constantReassignment(_, let pos),
                 .invalidAssignmentTarget(let pos),
                 .undeclaredFunction(_, let pos),
                 .functionAlreadyDeclared(_, let pos),
                 .incorrectArgumentCount(_, _, _, let pos),
                 .argumentTypeMismatch(_, _, _, _, let pos),
                 .missingReturnStatement(_, let pos),
                 .returnTypeMismatch(_, _, _, let pos),
                 .voidFunctionReturnsValue(_, let pos),
                 .unreachableCode(let pos),
                 .breakOutsideLoop(let pos),
                 .returnOutsideFunction(let pos),
                 .invalidArrayAccess(let pos),
                 .arrayIndexTypeMismatch(_, _, let pos),
                 .invalidArrayDimension(let pos),
                 .undeclaredField(_, _, let pos),
                 .invalidFieldAccess(let pos),
                 .cyclicDependency(_, let pos),
                 .analysisDepthExceeded(let pos):
                return pos
            case .tooManyErrors:
                return nil // This error doesn't have a position
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

// MARK: - SemanticError Extensions for Formatting

/// Concrete implementation of semantic error info.
internal struct SemanticErrorData: SemanticErrorInfo {
    let message: String
    let position: SourcePosition
    let details: [String]
    let suggestions: [String]

    init(message: String, position: SourcePosition, details: [String] = [], suggestions: [String] = []) {
        self.message = message
        self.position = position
        self.details = details
        self.suggestions = suggestions
    }
}

extension SemanticError {
    /// Converts the semantic error to a common pattern for unified formatting.
    var commonPattern: CommonErrorPattern {
        switch self {
        // Type-related errors
        case .typeMismatch(let expected, let actual, let pos):
            return .semantic(SemanticErrorData(
                message: "Type mismatch",
                position: pos,
                details: ["Expected type: \(expected)", "Actual type: \(actual)"],
                suggestions: ["Check variable declaration", "Use explicit type conversion"]
            ))

        case .incompatibleTypes(let t1, let t2, let op, let pos):
            return .semantic(SemanticErrorData(
                message: "Incompatible types for operation '\(op)'",
                position: pos,
                details: ["Left operand type: \(t1)", "Right operand type: \(t2)"],
                suggestions: ["Ensure both operands have compatible types", "Use type conversion if needed"]
            ))

        case .unknownType(let name, let pos):
            return .semantic(SemanticErrorData(
                message: "Unknown type '\(name)'",
                position: pos,
                suggestions: ["Check spelling of type name", "Ensure type is declared", "Use built-in types: integer, real, string, boolean"]
            ))

        case .invalidTypeConversion(let from, let to, let pos):
            return .semantic(SemanticErrorData(
                message: "Invalid type conversion",
                position: pos,
                details: ["From: \(from)", "To: \(to)"],
                suggestions: ["Use compatible types", "Check conversion is supported"]
            ))

        // Variable/scope-related errors
        case .undeclaredVariable(let name, let pos):
            return .semantic(SemanticErrorData(
                message: "Undeclared variable '\(name)'",
                position: pos,
                suggestions: ["Declare variable before use", "Check variable name spelling", "Ensure variable is in scope"]
            ))

        case .variableAlreadyDeclared(let name, let pos):
            return .semantic(SemanticErrorData(
                message: "Variable '\(name)' already declared",
                position: pos,
                suggestions: ["Use different variable name", "Remove duplicate declaration", "Check variable scope"]
            ))

        case .variableNotInitialized(let name, let pos):
            return .semantic(SemanticErrorData(
                message: "Variable '\(name)' used before initialization",
                position: pos,
                suggestions: ["Initialize variable before use", "Assign value to variable", "Check initialization order"]
            ))

        case .constantReassignment(let name, let pos):
            return .semantic(SemanticErrorData(
                message: "Cannot reassign constant '\(name)'",
                position: pos,
                suggestions: ["Use variable instead of constant", "Initialize constant with final value", "Create new variable for changed value"]
            ))

        case .invalidAssignmentTarget(let pos):
            return .semantic(SemanticErrorData(
                message: "Invalid assignment target",
                position: pos,
                suggestions: ["Assign to variable, not expression", "Use valid lvalue for assignment"]
            ))

        // Function-related errors
        case .undeclaredFunction(let name, let pos):
            return .semantic(SemanticErrorData(
                message: "Undeclared function '\(name)'",
                position: pos,
                suggestions: ["Declare function before use", "Check function name spelling", "Import required module"]
            ))

        case .functionAlreadyDeclared(let name, let pos):
            return .semantic(SemanticErrorData(
                message: "Function '\(name)' already declared",
                position: pos,
                suggestions: ["Use different function name", "Remove duplicate declaration", "Check function overloading rules"]
            ))

        case .incorrectArgumentCount(let function, let expected, let actual, let pos):
            return .semantic(SemanticErrorData(
                message: "Incorrect argument count for function '\(function)'",
                position: pos,
                details: ["Expected: \(expected) arguments", "Actual: \(actual) arguments"],
                suggestions: ["Provide correct number of arguments", "Check function signature"]
            ))

        case .argumentTypeMismatch(let function, let paramIndex, let expected, let actual, let pos):
            return .semantic(SemanticErrorData(
                message: "Argument type mismatch for function '\(function)'",
                position: pos,
                details: ["Parameter \(paramIndex + 1): expected \(expected), got \(actual)"],
                suggestions: ["Use correct argument type", "Apply type conversion", "Check function parameters"]
            ))

        case .missingReturnStatement(let function, let pos):
            return .semantic(SemanticErrorData(
                message: "Missing return statement in function '\(function)'",
                position: pos,
                suggestions: ["Add return statement", "Ensure all code paths return value", "Use procedure if no return needed"]
            ))

        case .returnTypeMismatch(let function, let expected, let actual, let pos):
            return .semantic(SemanticErrorData(
                message: "Return type mismatch in function '\(function)'",
                position: pos,
                details: ["Expected: \(expected)", "Actual: \(actual)"],
                suggestions: ["Return correct type", "Update function signature", "Apply type conversion"]
            ))

        case .voidFunctionReturnsValue(let function, let pos):
            return .semantic(SemanticErrorData(
                message: "Void function '\(function)' cannot return value",
                position: pos,
                suggestions: ["Remove return value", "Change function to return type", "Use procedure syntax"]
            ))

        // Control flow errors
        case .unreachableCode(let pos):
            return .semantic(SemanticErrorData(
                message: "Unreachable code detected",
                position: pos,
                suggestions: ["Remove unreachable code", "Fix control flow logic", "Check conditional statements"]
            ))

        case .breakOutsideLoop(let pos):
            return .semantic(SemanticErrorData(
                message: "Break statement outside loop",
                position: pos,
                suggestions: ["Use break only inside loops", "Remove break statement", "Use return for functions"]
            ))

        case .returnOutsideFunction(let pos):
            return .semantic(SemanticErrorData(
                message: "Return statement outside function",
                position: pos,
                suggestions: ["Use return only inside functions", "Remove return statement", "Declare function wrapper"]
            ))

        // Array/indexing errors
        case .invalidArrayAccess(let pos):
            return .semantic(SemanticErrorData(
                message: "Invalid array access",
                position: pos,
                suggestions: ["Check array variable exists", "Use valid index expression", "Ensure array is properly declared"]
            ))

        case .arrayIndexTypeMismatch(let expected, let actual, let pos):
            return .semantic(SemanticErrorData(
                message: "Array index type mismatch",
                position: pos,
                details: ["Expected: \(expected)", "Actual: \(actual)"],
                suggestions: ["Use integer index", "Convert index to correct type"]
            ))

        case .invalidArrayDimension(let pos):
            return .semantic(SemanticErrorData(
                message: "Invalid array dimension",
                position: pos,
                suggestions: ["Use valid dimension specification", "Check array declaration syntax"]
            ))

        // Record/field errors
        case .undeclaredField(let fieldName, let recordType, let pos):
            return .semantic(SemanticErrorData(
                message: "Undeclared field '\(fieldName)' in record '\(recordType)'",
                position: pos,
                suggestions: ["Check field name spelling", "Declare field in record type", "Use existing field"]
            ))

        case .invalidFieldAccess(let pos):
            return .semantic(SemanticErrorData(
                message: "Invalid field access",
                position: pos,
                suggestions: ["Access field on record variable", "Check record type has field", "Use dot notation"]
            ))

        // Analysis limitations
        case .cyclicDependency(let variables, let pos):
            let dependencyChain = variables.joined(separator: " -> ")
            return .semantic(SemanticErrorData(
                message: "Cyclic dependency detected",
                position: pos,
                details: ["Dependency chain: \(dependencyChain)"],
                suggestions: ["Break circular dependency", "Reorder declarations", "Use forward declarations"]
            ))

        case .analysisDepthExceeded(let pos):
            return .semantic(SemanticErrorData(
                message: "Analysis depth exceeded",
                position: pos,
                suggestions: ["Simplify expression structure", "Reduce nesting depth", "Break complex expressions"]
            ))

        case .tooManyErrors(let count):
            return .simple(
                message: "Too many semantic errors (\(count)), stopping analysis",
                detail: "Fix existing errors before continuing"
            )
        }
    }
}
