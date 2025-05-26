import Foundation

// MARK: - Infrastructure Components

/// Component-based error message building infrastructure.
/// Represents individual components that can be composed to create error messages.
public enum ErrorMessageComponent {
    case prefix(String)
    case message(String)
    case position(SourcePosition)
    case expected(String)
    case found(String)
    case keyValue(key: String, value: String)
    case detail(String)
    case suggestion(String)
    case typeInfo(expected: FeType?, actual: FeType?)
}

/// Flexible error message builder that composes components into formatted strings.
public struct ErrorMessageBuilder {
    private var components: [ErrorMessageComponent] = []

    /// Adds a component to the builder.
    /// - Parameter component: The component to add
    /// - Returns: Self for method chaining
    @discardableResult
    public mutating func add(_ component: ErrorMessageComponent) -> Self {
        components.append(component)
        return self
    }

    /// Builds the final error message string.
    /// - Returns: Formatted error message
    public func build() -> String {
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
            case .suggestion(let text):
                details.append("Suggestion: \(text)")
            case .typeInfo(let expected, let actual):
                if let exp = expected, let act = actual {
                    details.append("Expected type: \(exp)")
                    details.append("Actual type: \(act)")
                }
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
public enum CommonErrorPattern {
    case tokenBased(TokenBasedErrorInfo)
    case simple(message: String, detail: String?)
    case complex(message: String, details: [(String, String)])
    case endOfInput(context: String)
    case semantic(SemanticErrorInfo)
}

/// Protocol for token-based error information.
public protocol TokenBasedErrorInfo {
    var token: Token { get }
    var expectedDescription: String { get }
    var context: String? { get }
}

/// Concrete implementation of token-based error info.
public struct TokenBasedError: TokenBasedErrorInfo {
    public let token: Token
    public let expectedDescription: String
    public let context: String?

    public init(token: Token, expected: String, context: String? = nil) {
        self.token = token
        self.expectedDescription = expected
        self.context = context
    }
}

/// Information for formatting semantic errors.
public struct SemanticErrorInfo {
    public let error: SemanticError
    public let context: String?
    public let suggestion: String?
    
    public init(error: SemanticError, context: String? = nil, suggestion: String? = nil) {
        self.error = error
        self.context = context
        self.suggestion = suggestion
    }
}

/// Provides consistent error message formatting for all FeLangCore error types.
/// This formatter ensures that error messages are standardized across parsing and semantic analysis
/// and provides clear, actionable feedback for all types of compilation failures.
public struct ErrorFormatter {

    // MARK: - Public Interface

    /// Formats any FeLangCore error into a standardized string representation.
    /// This method handles parsing errors, semantic errors, and tokenizer errors,
    /// ensuring consistent formatting across all error scenarios.
    ///
    /// - Parameter error: The error to format
    /// - Returns: A formatted error string suitable for display or golden file comparison
    public static func format(_ error: Error) -> String {
        switch error {
        case let semanticError as SemanticError:
            return formatSemanticError(semanticError)
        case let parsingError as ParsingError:
            return formatCommonPattern(parsingError.commonPattern, prefix: "ParseError")
        case let statementError as StatementParsingError:
            return formatCommonPattern(statementError.commonPattern, prefix: "StatementParseError")
        case let tokenizerError as TokenizerError:
            return formatTokenizerError(tokenizerError)
        default:
            return "UnknownError: \(error.localizedDescription)"
        }
    }

    /// Formats an error with detailed context information including source code.
    /// Includes error type, position information, and source context when available.
    ///
    /// - Parameters:
    ///   - error: The error to format
    ///   - input: Optional input source for additional context
    ///   - symbolTable: Optional symbol table for semantic context
    /// - Returns: A comprehensive error message with source context
    public static func formatWithContext(
        _ error: Error, 
        input: String? = nil, 
        symbolTable: SymbolTable? = nil
    ) -> String {
        let basicFormat = format(error)

        guard let input = input else {
            return basicFormat
        }

        // Add source context if position information is available
        if let position = extractPosition(from: error) {
            let contextLines = extractSourceContext(input: input, position: position)
            var result = basicFormat + "\n" + contextLines
            
            // Add symbol table context for semantic errors
            if let semanticError = error as? SemanticError,
               let symbolTable = symbolTable {
                if let symbolContext = extractSymbolContext(semanticError, symbolTable: symbolTable) {
                    result += "\n" + symbolContext
                }
            }
            
            return result
        }

        return basicFormat
    }

    /// Formats a semantic error specifically.
    /// - Parameter error: The semantic error to format
    /// - Returns: Formatted semantic error message
    public static func formatSemanticError(_ error: SemanticError) -> String {
        let info = SemanticErrorInfo(
            error: error,
            context: generateSemanticContext(for: error),
            suggestion: generateSemanticSuggestion(for: error)
        )
        return formatCommonPattern(.semantic(info), prefix: "SemanticError")
    }

    /// Formats a semantic error with symbol table context.
    /// - Parameters:
    ///   - error: The semantic error to format
    ///   - symbolTable: Symbol table for additional context
    /// - Returns: Formatted semantic error message with symbol context
    public static func formatSemanticErrorWithContext(
        _ error: SemanticError,
        symbolTable: SymbolTable
    ) -> String {
        let basicFormat = formatSemanticError(error)
        
        if let symbolContext = extractSymbolContext(error, symbolTable: symbolTable) {
            return basicFormat + "\n" + symbolContext
        }
        
        return basicFormat
    }

    // MARK: - Unified Formatting Functions

    /// Formats common error patterns using a centralized approach.
    /// - Parameters:
    ///   - pattern: The common error pattern to format
    ///   - prefix: The error type prefix (e.g., "ParseError", "SemanticError")
    /// - Returns: Formatted error message
    public static func formatCommonPattern(_ pattern: CommonErrorPattern, prefix: String) -> String {
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
            formatSemanticErrorDetails(info, builder: &builder)
        }

        return builder.build()
    }
    
    // MARK: - Semantic Error Formatting
    
    private static func formatSemanticErrorDetails(_ info: SemanticErrorInfo, builder: inout ErrorMessageBuilder) {
        let error = info.error
        
        switch error {
        case .typeMismatch(let expected, let actual, let pos):
            builder.add(.message("Type mismatch"))
            builder.add(.position(pos))
            builder.add(.typeInfo(expected: expected, actual: actual))
            
        case .incompatibleTypes(let t1, let t2, let operation, let pos):
            builder.add(.message("Incompatible types for operation '\(operation)'"))
            builder.add(.position(pos))
            builder.add(.keyValue(key: "Left type", value: "\(t1)"))
            builder.add(.keyValue(key: "Right type", value: "\(t2)"))
            
        case .unknownType(let name, let pos):
            builder.add(.message("Unknown type '\(name)'"))
            builder.add(.position(pos))
            builder.add(.suggestion("Check spelling or import the required module"))
            
        case .invalidTypeConversion(let from, let to, let pos):
            builder.add(.message("Invalid type conversion"))
            builder.add(.position(pos))
            builder.add(.keyValue(key: "From", value: "\(from)"))
            builder.add(.keyValue(key: "To", value: "\(to)"))
            
        case .undeclaredVariable(let name, let pos):
            builder.add(.message("Undeclared variable '\(name)'"))
            builder.add(.position(pos))
            builder.add(.suggestion("Declare the variable before using it"))
            
        case .variableAlreadyDeclared(let name, let pos):
            builder.add(.message("Variable '\(name)' already declared"))
            builder.add(.position(pos))
            builder.add(.suggestion("Use a different name or remove the duplicate declaration"))
            
        case .variableNotInitialized(let name, let pos):
            builder.add(.message("Variable '\(name)' used before initialization"))
            builder.add(.position(pos))
            builder.add(.suggestion("Initialize the variable before using it"))
            
        case .constantReassignment(let name, let pos):
            builder.add(.message("Cannot reassign constant '\(name)'"))
            builder.add(.position(pos))
            builder.add(.suggestion("Use a variable instead of a constant"))
            
        case .invalidAssignmentTarget(let pos):
            builder.add(.message("Invalid assignment target"))
            builder.add(.position(pos))
            builder.add(.suggestion("Assignment target must be a variable or field"))
            
        case .undeclaredFunction(let name, let pos):
            builder.add(.message("Undeclared function '\(name)'"))
            builder.add(.position(pos))
            builder.add(.suggestion("Check function name spelling or import the required module"))
            
        case .functionAlreadyDeclared(let name, let pos):
            builder.add(.message("Function '\(name)' already declared"))
            builder.add(.position(pos))
            builder.add(.suggestion("Use a different name or remove the duplicate declaration"))
            
        case .incorrectArgumentCount(let function, let expected, let actual, let pos):
            builder.add(.message("Incorrect argument count for function '\(function)'"))
            builder.add(.position(pos))
            builder.add(.keyValue(key: "Expected", value: "\(expected) arguments"))
            builder.add(.keyValue(key: "Actual", value: "\(actual) arguments"))
            
        case .argumentTypeMismatch(let function, let paramIndex, let expected, let actual, let pos):
            builder.add(.message("Argument type mismatch for function '\(function)'"))
            builder.add(.position(pos))
            builder.add(.keyValue(key: "Parameter", value: "\(paramIndex + 1)"))
            builder.add(.typeInfo(expected: expected, actual: actual))
            
        case .missingReturnStatement(let function, let pos):
            builder.add(.message("Missing return statement in function '\(function)'"))
            builder.add(.position(pos))
            builder.add(.suggestion("Add a return statement or change function to procedure"))
            
        case .returnTypeMismatch(let function, let expected, let actual, let pos):
            builder.add(.message("Return type mismatch in function '\(function)'"))
            builder.add(.position(pos))
            builder.add(.typeInfo(expected: expected, actual: actual))
            
        case .voidFunctionReturnsValue(let function, let pos):
            builder.add(.message("Procedure '\(function)' cannot return a value"))
            builder.add(.position(pos))
            builder.add(.suggestion("Change to function or remove return value"))
            
        case .unreachableCode(let pos):
            builder.add(.message("Unreachable code"))
            builder.add(.position(pos))
            builder.add(.suggestion("Remove unreachable code or fix control flow"))
            
        case .breakOutsideLoop(let pos):
            builder.add(.message("Break statement outside loop"))
            builder.add(.position(pos))
            builder.add(.suggestion("Use break only inside while or for loops"))
            
        case .returnOutsideFunction(let pos):
            builder.add(.message("Return statement outside function"))
            builder.add(.position(pos))
            builder.add(.suggestion("Use return only inside functions or procedures"))
            
        case .invalidArrayAccess(let pos):
            builder.add(.message("Invalid array access"))
            builder.add(.position(pos))
            builder.add(.suggestion("Check array variable and index expression"))
            
        case .arrayIndexTypeMismatch(let expected, let actual, let pos):
            builder.add(.message("Array index type mismatch"))
            builder.add(.position(pos))
            builder.add(.typeInfo(expected: expected, actual: actual))
            
        case .invalidArrayDimension(let pos):
            builder.add(.message("Invalid array dimension"))
            builder.add(.position(pos))
            builder.add(.suggestion("Array dimensions must be positive integers"))
            
        case .undeclaredField(let fieldName, let recordType, let pos):
            builder.add(.message("Undeclared field '\(fieldName)' in record type '\(recordType)'"))
            builder.add(.position(pos))
            builder.add(.suggestion("Check field name spelling or record type definition"))
            
        case .invalidFieldAccess(let pos):
            builder.add(.message("Invalid field access"))
            builder.add(.position(pos))
            builder.add(.suggestion("Field access requires a record type"))
            
        case .cyclicDependency(let variables, let pos):
            let cycle = variables.joined(separator: " -> ")
            builder.add(.message("Cyclic dependency detected"))
            builder.add(.position(pos))
            builder.add(.keyValue(key: "Cycle", value: cycle))
            
        case .analysisDepthExceeded(let pos):
            builder.add(.message("Analysis depth exceeded"))
            builder.add(.position(pos))
            builder.add(.suggestion("Simplify complex expressions or reduce nesting"))
            
        case .tooManyErrors(let count):
            builder.add(.message("Too many semantic errors (\(count)), stopping analysis"))
            builder.add(.suggestion("Fix initial errors and re-run analysis"))
        }
        
        if let context = info.context {
            builder.add(.detail(context))
        }
        
        if let suggestion = info.suggestion {
            builder.add(.suggestion(suggestion))
        }
    }

    // MARK: - Tokenizer Error Formatting
    
    private static func formatTokenizerError(_ error: TokenizerError) -> String {
        var builder = ErrorMessageBuilder()
        builder.add(.prefix("TokenizerError: "))
        
        switch error {
        case .unexpectedCharacter(let char, let pos):
            builder.add(.message("Unexpected character '\(char)'"))
            builder.add(.position(pos))
        case .unterminatedString(let pos):
            builder.add(.message("Unterminated string literal"))
            builder.add(.position(pos))
        case .unterminatedComment(let pos):
            builder.add(.message("Unterminated comment"))
            builder.add(.position(pos))
        case .invalidEscapeSequence(let pos):
            builder.add(.message("Invalid escape sequence"))
            builder.add(.position(pos))
        case .invalidEscapeSequenceWithMessage(let message, let pos):
            builder.add(.message("Invalid escape sequence: \(message)"))
            builder.add(.position(pos))
        case .invalidUnicodeEscape(let details, let pos):
            builder.add(.message("Invalid Unicode escape sequence: \(details)"))
            builder.add(.position(pos))
        case .invalidNumberFormat(let format, let pos):
            builder.add(.message("Invalid number format '\(format)'"))
            builder.add(.position(pos))
        case .invalidDigitForBase(let digit, let base, let pos):
            builder.add(.message("Invalid digit '\(digit)' for \(base) number"))
            builder.add(.position(pos))
        case .invalidUnderscorePlacement(let pos):
            builder.add(.message("Invalid underscore placement in number"))
            builder.add(.position(pos))
        }
        
        return builder.build()
    }

    // MARK: - Position Formatting

    public static func formatPosition(_ position: SourcePosition) -> String {
        return "line \(position.line), column \(position.column)"
    }

    // MARK: - Context Extraction

    private static func extractPosition(from error: Error) -> SourcePosition? {
        switch error {
        case let semanticError as SemanticError:
            return extractPositionFromSemanticError(semanticError)
        case let parsingError as ParsingError:
            return extractPositionFromParsingError(parsingError)
        case let statementError as StatementParsingError:
            return extractPositionFromStatementError(statementError)
        case let tokenizerError as TokenizerError:
            return extractPositionFromTokenizerError(tokenizerError)
        default:
            return nil
        }
    }
    
    private static func extractPositionFromSemanticError(_ error: SemanticError) -> SourcePosition? {
        switch error {
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
        case .tooManyErrors(_):
            return nil
        }
    }

    private static func extractPositionFromParsingError(_ error: ParsingError) -> SourcePosition? {
        switch error {
        case .unexpectedToken(let token, _),
             .expectedPrimaryExpression(let token):
            return token.position
        default:
            return nil
        }
    }
    
    private static func extractPositionFromStatementError(_ error: StatementParsingError) -> SourcePosition? {
        switch error {
        case .unexpectedToken(let token, _),
             .expectedPrimaryExpression(let token):
            return token.position
        default:
            return nil
        }
    }
    
    private static func extractPositionFromTokenizerError(_ error: TokenizerError) -> SourcePosition? {
        switch error {
        case .unexpectedCharacter(_, let pos),
             .unterminatedString(let pos),
             .unterminatedComment(let pos),
             .invalidEscapeSequence(let pos),
             .invalidEscapeSequenceWithMessage(_, let pos),
             .invalidUnicodeEscape(_, let pos),
             .invalidNumberFormat(_, let pos),
             .invalidDigitForBase(_, _, let pos),
             .invalidUnderscorePlacement(let pos):
            return pos
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
    
    private static func extractSymbolContext(_ error: SemanticError, symbolTable: SymbolTable) -> String? {
        switch error {
        case .undeclaredVariable(let name, _):
            // Look for similar variable names
            let similarNames = symbolTable.findSimilarNames(to: name, type: .variable)
            if !similarNames.isEmpty {
                let suggestions = similarNames.prefix(3).joined(separator: ", ")
                return "  Similar variables: \(suggestions)"
            }
            
        case .undeclaredFunction(let name, _):
            // Look for similar function names
            let similarNames = symbolTable.findSimilarNames(to: name, type: .function)
            if !similarNames.isEmpty {
                let suggestions = similarNames.prefix(3).joined(separator: ", ")
                return "  Similar functions: \(suggestions)"
            }
            
        case .typeMismatch(let expected, let actual, _):
            if let conversion = symbolTable.suggestTypeConversion(from: actual, to: expected) {
                return "  Suggestion: \(conversion)"
            }
            
        default:
            break
        }
        
        return nil
    }
    
    // MARK: - Semantic Context Generation
    
    private static func generateSemanticContext(for error: SemanticError) -> String? {
        switch error {
        case .typeMismatch(_, _, _):
            return "Type checking ensures type safety in expressions"
        case .undeclaredVariable(_, _):
            return "All variables must be declared before use"
        case .undeclaredFunction(_, _):
            return "All functions must be declared before calling"
        default:
            return nil
        }
    }
    
    private static func generateSemanticSuggestion(for error: SemanticError) -> String? {
        switch error {
        case .invalidTypeConversion(.integer, .string, _):
            return "Use string interpolation or conversion functions"
        case .incorrectArgumentCount(_, _, _, _):
            return "Check function signature and provide correct number of arguments"
        default:
            return nil
        }
    }
}

// MARK: - Error Extensions for Common Patterns

extension ParsingError {
    /// Converts the error to a common pattern for unified formatting.
    public var commonPattern: CommonErrorPattern {
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
    public var commonPattern: CommonErrorPattern {
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

extension SemanticError {
    /// Converts the error to a common pattern for unified formatting.
    public var commonPattern: CommonErrorPattern {
        return .semantic(SemanticErrorInfo(error: self))
    }
}