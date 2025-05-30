import Foundation

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
                details.append("at \(SemanticErrorFormatter.formatPosition(pos))")
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
    case semanticError(SemanticErrorInfo)
    case simple(message: String, detail: String?)
    case complex(message: String, details: [(String, String)])
    case typeRelated(TypeErrorInfo)
    case scopeRelated(ScopeErrorInfo)
}

/// Protocol for semantic error information.
internal protocol SemanticErrorInfo {
    var error: SemanticError { get }
    var context: String? { get }
}

/// Information for type-related semantic errors.
internal struct TypeErrorInfo {
    let expectedType: FeType
    let actualType: FeType
    let position: SourcePosition
    let operation: String?

    init(expected: FeType, actual: FeType, at position: SourcePosition, operation: String? = nil) {
        self.expectedType = expected
        self.actualType = actual
        self.position = position
        self.operation = operation
    }
}

/// Information for scope-related semantic errors.
internal struct ScopeErrorInfo {
    let symbolName: String
    let symbolType: FeType?
    let position: SourcePosition
    let scopeContext: String?

    init(symbol: String, type: FeType? = nil, at position: SourcePosition, context: String? = nil) {
        self.symbolName = symbol
        self.symbolType = type
        self.position = position
        self.scopeContext = context
    }
}

/// Concrete implementation of semantic error info.
internal struct SemanticErrorDetails: SemanticErrorInfo {
    let error: SemanticError
    let context: String?

    init(error: SemanticError, context: String? = nil) {
        self.error = error
        self.context = context
    }
}

/// Provides consistent error message formatting for semantic errors.
/// This formatter ensures that error messages are standardized and provides clear,
/// actionable feedback for semantic analysis failures.
public struct SemanticErrorFormatter {

    // MARK: - Public Interface

    /// Formats a semantic error into a standardized string representation.
    /// This method provides comprehensive formatting for all semantic error types,
    /// ensuring consistent presentation across the semantic analysis pipeline.
    ///
    /// - Parameter error: The semantic error to format
    /// - Returns: A formatted error string suitable for display
    public static func format(_ error: SemanticError) -> String {
        return formatCommonPattern(error.commonPattern, prefix: "SemanticError")
    }

    /// Formats a semantic error with detailed context information.
    /// Includes symbol table context and suggested fixes where applicable.
    ///
    /// - Parameters:
    ///   - error: The semantic error to format
    ///   - symbolTable: Optional symbol table for additional context
    /// - Returns: A comprehensive error message with contextual information
    public static func formatWithContext(
        _ error: SemanticError,
        symbolTable: SymbolTable? = nil
    ) -> String {
        let basicFormat = format(error)

        guard let symbolTable = symbolTable else {
            return basicFormat
        }

        // Add symbol table context and suggestions
        let contextInfo = extractContextualInfo(from: error, using: symbolTable)
        if !contextInfo.isEmpty {
            return basicFormat + "\n" + contextInfo
        }

        return basicFormat
    }

    /// Formats multiple semantic errors as a consolidated report.
    /// - Parameters:
    ///   - errors: Array of semantic errors to format
    ///   - symbolTable: Optional symbol table for context
    /// - Returns: Formatted error report with numbered entries
    public static func formatErrorReport(
        _ errors: [SemanticError],
        symbolTable: SymbolTable? = nil
    ) -> String {
        guard !errors.isEmpty else {
            return "No semantic errors found."
        }

        var report = "Semantic Analysis Errors (\(errors.count) total):\n"

        for (index, error) in errors.enumerated() {
            let formattedError = symbolTable != nil
                ? formatWithContext(error, symbolTable: symbolTable)
                : format(error)
            report += "\n\(index + 1). \(formattedError)"
        }

        return report
    }

    // MARK: - Unified Formatting Functions

    /// Formats common error patterns using a centralized approach.
    /// - Parameters:
    ///   - pattern: The common error pattern to format
    ///   - prefix: The error type prefix (e.g., "SemanticError")
    /// - Returns: Formatted error message
    internal static func formatCommonPattern(_ pattern: CommonErrorPattern, prefix: String) -> String {
        var builder = ErrorMessageBuilder()
        builder.add(.prefix("\(prefix): "))

        switch pattern {
        case .semanticError(let info):
            builder.add(.message(info.error.primaryMessage))
            builder.add(.position(info.error.position))
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

        case .typeRelated(let info):
            if let operation = info.operation {
                builder.add(.message("Type mismatch in \(operation)"))
                builder.add(.position(info.position))
                builder.add(.expected(info.expectedType.description))
                builder.add(.found(info.actualType.description))
            } else {
                // For basic type mismatches, use simplified format
                builder.add(.message("Type mismatch: expected '\(info.expectedType)', got '\(info.actualType)'"))
                builder.add(.position(info.position))
            }

        case .scopeRelated(let info):
            builder.add(.message("Symbol '\(info.symbolName)' not found"))
            builder.add(.position(info.position))
            if let context = info.scopeContext {
                builder.add(.detail(context))
            }
        }

        return builder.build()
    }

    // MARK: - Position Formatting

    internal static func formatPosition(_ position: SourcePosition) -> String {
        return "line \(position.line), column \(position.column)"
    }

    // MARK: - Context Extraction

    private static func extractContextualInfo(from error: SemanticError, using symbolTable: SymbolTable) -> String {
        switch error {
        case .undeclaredVariable(let name, _), .undeclaredFunction(let name, _):
            // Suggest similar names from symbol table
            let suggestions = symbolTable.findSimilarSymbols(to: name, limit: 3)
            if !suggestions.isEmpty {
                let suggestionList = suggestions.map { "'\($0)'" }.joined(separator: ", ")
                return "  Suggestion: Did you mean \(suggestionList)?"
            }

        case .typeMismatch(let expected, let actual, _):
            // Provide conversion suggestions for compatible types
            if expected.isCompatible(with: actual) {
                return "  Note: Implicit conversion from '\(actual)' to '\(expected)' may be possible"
            } else if actual == .integer && expected == .real {
                return "  Suggestion: Convert integer to real using explicit cast"
            }

        case .functionAlreadyDeclared(let name, _), .variableAlreadyDeclared(let name, _):
            // Show location of previous declaration
            if let existingSymbol = symbolTable.lookup(name) {
                return "  Note: Previously declared at \(SemanticErrorFormatter.formatPosition(existingSymbol.position))"
            }

        default:
            break
        }

        return ""
    }
}

// MARK: - SemanticError Extensions for Common Patterns

extension SemanticError {
    /// Converts the error to a common pattern for unified formatting.
    var commonPattern: CommonErrorPattern {
        switch self {
        case .typeMismatch(let expected, let actual, let pos):
            return .typeRelated(TypeErrorInfo(expected: expected, actual: actual, at: pos))

        case .incompatibleTypes(let type1, let type2, let operation, let pos):
            return .complex(message: "Incompatible types in \(operation)", details: [
                ("Left type", type1.description),
                ("Right type", type2.description),
                ("Position", SemanticErrorFormatter.formatPosition(pos))
            ])

        case .undeclaredVariable(let name, let pos):
            return .scopeRelated(ScopeErrorInfo(symbol: name, at: pos, context: "Variable must be declared before use"))

        case .undeclaredFunction(let name, let pos):
            return .scopeRelated(ScopeErrorInfo(symbol: name, at: pos, context: "Function must be declared before call"))

        case .variableAlreadyDeclared(let name, let pos):
            return .simple(message: "Variable '\(name)' already declared", detail: "at \(SemanticErrorFormatter.formatPosition(pos))")

        case .functionAlreadyDeclared(let name, let pos):
            return .simple(message: "Function '\(name)' already declared", detail: "at \(SemanticErrorFormatter.formatPosition(pos))")

        case .incorrectArgumentCount(let function, let expected, let actual, let pos):
            return .complex(message: "Incorrect argument count for function '\(function)'", details: [
                ("Function", "'\(function)'"),
                ("Expected", "\(expected) arguments"),
                ("Actual", "\(actual) arguments"),
                ("Position", SemanticErrorFormatter.formatPosition(pos))
            ])

        case .argumentTypeMismatch(let function, let paramIndex, let expected, let actual, let pos):
            return .complex(message: "Argument type mismatch in function '\(function)'", details: [
                ("Parameter", "#\(paramIndex + 1)"),
                ("Expected", expected.description),
                ("Actual", actual.description),
                ("Position", SemanticErrorFormatter.formatPosition(pos))
            ])

        case .returnTypeMismatch(let function, let expected, let actual, let pos):
            return .complex(message: "Return type mismatch in function '\(function)'", details: [
                ("Expected", expected.description),
                ("Actual", actual.description),
                ("Position", SemanticErrorFormatter.formatPosition(pos))
            ])

        case .cyclicDependency(let symbols, let pos):
            let chain = symbols.joined(separator: " -> ")
            return .simple(message: "Cyclic dependency detected", detail: "Chain: \(chain) at \(SemanticErrorFormatter.formatPosition(pos))")

        default:
            return .semanticError(SemanticErrorDetails(error: self))
        }
    }

    /// Primary message for the error (without position details).
    var primaryMessage: String {
        switch self {
        case .typeMismatch(let expected, let actual, _):
            return "Type mismatch: expected '\(expected)', got '\(actual)'"
        case .incompatibleTypes(let t1, let t2, let op, _):
            return "Incompatible types '\(t1)' and '\(t2)' for operation '\(op)'"
        case .unknownType(let name, _):
            return "Unknown type '\(name)'"
        case .invalidTypeConversion(let from, let to, _):
            return "Invalid type conversion from '\(from)' to '\(to)'"
        case .undeclaredVariable(let name, _):
            return "Undeclared variable '\(name)'"
        case .variableAlreadyDeclared(let name, _):
            return "Variable '\(name)' already declared"
        case .variableNotInitialized(let name, _):
            return "Variable '\(name)' used before initialization"
        case .constantReassignment(let name, _):
            return "Cannot reassign constant '\(name)'"
        case .invalidAssignmentTarget:
            return "Invalid assignment target"
        case .undeclaredFunction(let name, _):
            return "Undeclared function '\(name)'"
        case .functionAlreadyDeclared(let name, _):
            return "Function '\(name)' already declared"
        case .incorrectArgumentCount(let function, let expected, let actual, _):
            return "Function '\(function)' expects \(expected) arguments, got \(actual)"
        case .argumentTypeMismatch(let function, let paramIndex, let expected, let actual, _):
            return "Function '\(function)' parameter \(paramIndex + 1): expected '\(expected)', got '\(actual)'"
        case .missingReturnStatement(let function, _):
            return "Function '\(function)' missing return statement"
        case .returnTypeMismatch(let function, let expected, let actual, _):
            return "Function '\(function)' return type: expected '\(expected)', got '\(actual)'"
        case .voidFunctionReturnsValue(let function, _):
            return "Void function '\(function)' cannot return a value"
        case .unreachableCode:
            return "Unreachable code"
        case .breakOutsideLoop:
            return "Break statement outside loop"
        case .returnOutsideFunction:
            return "Return statement outside function"
        case .invalidArrayAccess:
            return "Invalid array access"
        case .arrayIndexTypeMismatch(let expected, let actual, _):
            return "Array index type mismatch: expected '\(expected)', got '\(actual)'"
        case .invalidArrayDimension:
            return "Invalid array dimension"
        case .undeclaredField(let fieldName, let recordType, _):
            return "Undeclared field '\(fieldName)' in record '\(recordType)'"
        case .invalidFieldAccess:
            return "Invalid field access"
        case .cyclicDependency(let symbols, _):
            return "Cyclic dependency: \(symbols.joined(separator: " -> "))"
        case .analysisDepthExceeded:
            return "Analysis depth exceeded"
        case .tooManyErrors(let count):
            return "Too many semantic errors (\(count)), stopping analysis"
        }
    }

    /// Source position for the error.
    var position: SourcePosition {
        switch self {
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
            return SourcePosition(line: 0, column: 0, offset: 0) // Special case
        }
    }

}
