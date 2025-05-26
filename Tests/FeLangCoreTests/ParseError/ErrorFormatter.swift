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

    /// Formats any parsing-related or semantic error into a standardized string representation.
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

// MARK: - Semantic Error Support

extension ErrorFormatter {
    /// Formats a semantic error with detailed context information.
    /// Includes error type, position information, and type details where applicable.
    ///
    /// - Parameters:
    ///   - error: The semantic error to format
    ///   - symbolTable: Optional symbol table for additional context
    /// - Returns: A comprehensive error message with context
    public static func formatSemanticError(_ error: SemanticError, symbolTable: SymbolTable? = nil) -> String {
        let basicFormat = format(error)
        
        // Add symbol table context if available and relevant
        if let symbolTable = symbolTable {
            let contextInfo = extractSemanticContext(from: error, symbolTable: symbolTable)
            if !contextInfo.isEmpty {
                return basicFormat + "\n" + contextInfo
            }
        }
        
        return basicFormat
    }
    
    private static func extractSemanticContext(from error: SemanticError, symbolTable: SymbolTable) -> String {
        switch error {
        case .undeclaredVariable(let name, _):
            // Find similar variable names for suggestions
            let suggestions = symbolTable.findSimilarNames(to: name, limit: 3)
            if !suggestions.isEmpty {
                let suggestionList = suggestions.joined(separator: ", ")
                return "  Did you mean: \(suggestionList)?"
            }
            
        case .undeclaredFunction(let name, _):
            // Find similar function names for suggestions
            let suggestions = symbolTable.findSimilarNames(to: name, limit: 3)
            if !suggestions.isEmpty {
                let suggestionList = suggestions.joined(separator: ", ")
                return "  Did you mean: \(suggestionList)?"
            }
            
        case .typeMismatch(let expected, let actual, _):
            // Provide conversion suggestions for compatible types
            if expected == .real && actual == .integer {
                return "  Note: Integer values are automatically converted to real"
            } else if expected == .integer && actual == .real {
                return "  Note: Use explicit conversion to convert real to integer"
            }
            
        default:
            break
        }
        
        return ""
    }
}

extension SemanticError {
    /// Converts the semantic error to a common pattern for unified formatting.
    var commonPattern: CommonErrorPattern {
        switch self {
        case .typeMismatch(let expected, let actual, let pos):
            return .complex(message: "Type mismatch", details: [
                ("Expected", "\(expected)"),
                ("Found", "\(actual)"),
                ("Position", ErrorFormatter.formatPosition(pos))
            ])
            
        case .incompatibleTypes(let t1, let t2, let op, let pos):
            return .complex(message: "Incompatible types for operation", details: [
                ("Operation", "'\(op)'"),
                ("Left type", "\(t1)"),
                ("Right type", "\(t2)"),
                ("Position", ErrorFormatter.formatPosition(pos))
            ])
            
        case .unknownType(let name, let pos):
            return .complex(message: "Unknown type", details: [
                ("Type name", "'\(name)'"),
                ("Position", ErrorFormatter.formatPosition(pos)),
                ("Note", "Type must be declared before use")
            ])
            
        case .invalidTypeConversion(let from, let to, let pos):
            return .complex(message: "Invalid type conversion", details: [
                ("From", "\(from)"),
                ("To", "\(to)"),
                ("Position", ErrorFormatter.formatPosition(pos))
            ])
            
        case .undeclaredVariable(let name, let pos):
            return .complex(message: "Undeclared variable", details: [
                ("Variable", "'\(name)'"),
                ("Position", ErrorFormatter.formatPosition(pos)),
                ("Note", "Variable must be declared before use")
            ])
            
        case .variableAlreadyDeclared(let name, let pos):
            return .complex(message: "Variable already declared", details: [
                ("Variable", "'\(name)'"),
                ("Position", ErrorFormatter.formatPosition(pos)),
                ("Note", "Each variable can only be declared once in the same scope")
            ])
            
        case .variableNotInitialized(let name, let pos):
            return .complex(message: "Variable used before initialization", details: [
                ("Variable", "'\(name)'"),
                ("Position", ErrorFormatter.formatPosition(pos)),
                ("Note", "Variables must be initialized before use")
            ])
            
        case .constantReassignment(let name, let pos):
            return .complex(message: "Cannot reassign constant", details: [
                ("Constant", "'\(name)'"),
                ("Position", ErrorFormatter.formatPosition(pos)),
                ("Note", "Constants cannot be modified after declaration")
            ])
            
        case .invalidAssignmentTarget(let pos):
            return .simple(message: "Invalid assignment target", detail: "at \(ErrorFormatter.formatPosition(pos))\n  Note: Can only assign to variables, not expressions")
            
        case .undeclaredFunction(let name, let pos):
            return .complex(message: "Undeclared function", details: [
                ("Function", "'\(name)'"),
                ("Position", ErrorFormatter.formatPosition(pos)),
                ("Note", "Function must be declared before use")
            ])
            
        case .functionAlreadyDeclared(let name, let pos):
            return .complex(message: "Function already declared", details: [
                ("Function", "'\(name)'"),
                ("Position", ErrorFormatter.formatPosition(pos)),
                ("Note", "Each function can only be declared once")
            ])
            
        case .incorrectArgumentCount(let function, let expected, let actual, let pos):
            return .complex(message: "Incorrect argument count", details: [
                ("Function", "'\(function)'"),
                ("Expected", "\(expected) arguments"),
                ("Found", "\(actual) arguments"),
                ("Position", ErrorFormatter.formatPosition(pos))
            ])
            
        case .argumentTypeMismatch(let function, let paramIndex, let expected, let actual, let pos):
            return .complex(message: "Argument type mismatch", details: [
                ("Function", "'\(function)'"),
                ("Parameter", "#\(paramIndex + 1)"),
                ("Expected", "\(expected)"),
                ("Found", "\(actual)"),
                ("Position", ErrorFormatter.formatPosition(pos))
            ])
            
        case .missingReturnStatement(let function, let pos):
            return .complex(message: "Missing return statement", details: [
                ("Function", "'\(function)'"),
                ("Position", ErrorFormatter.formatPosition(pos)),
                ("Note", "Functions with return type must return a value")
            ])
            
        case .returnTypeMismatch(let function, let expected, let actual, let pos):
            return .complex(message: "Return type mismatch", details: [
                ("Function", "'\(function)'"),
                ("Expected", "\(expected)"),
                ("Found", "\(actual)"),
                ("Position", ErrorFormatter.formatPosition(pos))
            ])
            
        case .voidFunctionReturnsValue(let function, let pos):
            return .complex(message: "Void function returns value", details: [
                ("Function", "'\(function)'"),
                ("Position", ErrorFormatter.formatPosition(pos)),
                ("Note", "Procedures (void functions) cannot return values")
            ])
            
        case .unreachableCode(let pos):
            return .simple(message: "Unreachable code", detail: "at \(ErrorFormatter.formatPosition(pos))\n  Note: Code after return statements is never executed")
            
        case .breakOutsideLoop(let pos):
            return .simple(message: "Break statement outside loop", detail: "at \(ErrorFormatter.formatPosition(pos))\n  Note: Break can only be used inside loops")
            
        case .returnOutsideFunction(let pos):
            return .simple(message: "Return statement outside function", detail: "at \(ErrorFormatter.formatPosition(pos))\n  Note: Return can only be used inside functions")
            
        case .invalidArrayAccess(let pos):
            return .simple(message: "Invalid array access", detail: "at \(ErrorFormatter.formatPosition(pos))\n  Note: Array access requires valid array expression and index")
            
        case .arrayIndexTypeMismatch(let expected, let actual, let pos):
            return .complex(message: "Array index type mismatch", details: [
                ("Expected", "\(expected)"),
                ("Found", "\(actual)"),
                ("Position", ErrorFormatter.formatPosition(pos)),
                ("Note", "Array indices must be integers")
            ])
            
        case .invalidArrayDimension(let pos):
            return .simple(message: "Invalid array dimension", detail: "at \(ErrorFormatter.formatPosition(pos))\n  Note: Array dimensions must be positive integers")
            
        case .undeclaredField(let fieldName, let recordType, let pos):
            return .complex(message: "Undeclared field", details: [
                ("Field", "'\(fieldName)'"),
                ("Record type", "'\(recordType)'"),
                ("Position", ErrorFormatter.formatPosition(pos)),
                ("Note", "Field does not exist in this record type")
            ])
            
        case .invalidFieldAccess(let pos):
            return .simple(message: "Invalid field access", detail: "at \(ErrorFormatter.formatPosition(pos))\n  Note: Field access requires a record expression")
            
        case .cyclicDependency(let variables, let pos):
            let varList = variables.joined(separator: " -> ")
            return .complex(message: "Cyclic dependency detected", details: [
                ("Dependency chain", varList),
                ("Position", ErrorFormatter.formatPosition(pos)),
                ("Note", "Variables cannot depend on themselves")
            ])
            
        case .analysisDepthExceeded(let pos):
            return .simple(message: "Analysis depth exceeded", detail: "at \(ErrorFormatter.formatPosition(pos))\n  Note: Expression or type structure too complex")
            
        case .tooManyErrors(let count):
            return .simple(message: "Too many semantic errors", detail: "Analysis stopped after \(count) errors\n  Note: Fix some errors and try again")
        }
    }
}
