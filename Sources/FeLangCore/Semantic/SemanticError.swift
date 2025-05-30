import Foundation

/// Errors that can occur during semantic analysis.
public enum SemanticError: Error, Equatable, Sendable {
    // Type-related errors
    case typeMismatch(expected: FeType, actual: FeType, position: SourcePosition)
    case incompatibleTypes(FeType, FeType, operation: String, position: SourcePosition)
    case unknownType(String, position: SourcePosition)
    case invalidTypeConversion(from: FeType, targetType: FeType, position: SourcePosition)

    // Variable/scope-related errors
    case undeclaredVariable(String, position: SourcePosition)
    case variableAlreadyDeclared(String, position: SourcePosition)
    case variableNotInitialized(String, position: SourcePosition)
    case constantReassignment(String, position: SourcePosition)
    case invalidAssignmentTarget(position: SourcePosition)

    // Function-related errors
    case undeclaredFunction(String, position: SourcePosition)
    case functionAlreadyDeclared(String, position: SourcePosition)
    case incorrectArgumentCount(function: String, expected: Int, actual: Int, position: SourcePosition)
    case argumentTypeMismatch(function: String, paramIndex: Int, expected: FeType, actual: FeType, position: SourcePosition)
    case missingReturnStatement(function: String, position: SourcePosition)
    case returnTypeMismatch(function: String, expected: FeType, actual: FeType, position: SourcePosition)
    case voidFunctionReturnsValue(function: String, position: SourcePosition)

    // Control flow errors
    case unreachableCode(position: SourcePosition)
    case breakOutsideLoop(position: SourcePosition)
    case returnOutsideFunction(position: SourcePosition)

    // Array/indexing errors
    case invalidArrayAccess(position: SourcePosition)
    case arrayIndexTypeMismatch(expected: FeType, actual: FeType, position: SourcePosition)
    case invalidArrayDimension(position: SourcePosition)

    // Record/field errors
    case undeclaredField(fieldName: String, recordType: String, position: SourcePosition)
    case invalidFieldAccess(position: SourcePosition)

    // Analysis limitations
    case cyclicDependency([String], position: SourcePosition)
    case analysisDepthExceeded(position: SourcePosition)
    case tooManyErrors(count: Int)
}

/// Type system for FE language semantic analysis.
public indirect enum FeType: Equatable, Sendable, CustomStringConvertible {
    case integer
    case real
    case string
    case character
    case boolean
    case array(elementType: FeType, dimensions: [Int])
    case record(name: String, fields: [String: FeType])
    case function(parameters: [FeType], returnType: FeType?)
    case void
    case unknown
    case error // Used for error recovery

    public var description: String {
        switch self {
        case .integer:
            return "integer"
        case .real:
            return "real"
        case .string:
            return "string"
        case .character:
            return "character"
        case .boolean:
            return "boolean"
        case .array(let elementType, let dimensions):
            let dimStr = dimensions.map { "[\($0)]" }.joined()
            return "array\(dimStr) of \(elementType)"
        case .record(let name, _):
            return "record \(name)"
        case .function(let params, let returnType):
            let paramStr = params.map { $0.description }.joined(separator: ", ")
            if let ret = returnType {
                return "function(\(paramStr)) -> \(ret)"
            } else {
                return "procedure(\(paramStr))"
            }
        case .void:
            return "void"
        case .unknown:
            return "unknown"
        case .error:
            return "error"
        }
    }

    /// Check if this type is compatible with another type.
    public func isCompatible(with other: FeType) -> Bool {
        switch (self, other) {
        case (.error, _), (_, .error):
            return true // Error type is compatible with everything for recovery
        case (.unknown, _), (_, .unknown):
            return true // Unknown type is compatible during inference
        case (.integer, .integer), (.real, .real), (.string, .string),
             (.character, .character), (.boolean, .boolean), (.void, .void):
            return true
        case (.integer, .real), (.real, .integer):
            return true // Numeric types are compatible
        case (.character, .string):
            return true // Character can be assigned to string
        case (.array(let elementType1, let dimensions1), .array(let elementType2, let dimensions2)):
            return elementType1.isCompatible(with: elementType2) && dimensions1 == dimensions2
        case (.record(let name1, let fields1), .record(let name2, let fields2)):
            return name1 == name2 && fields1 == fields2
        case (.function(let params1, let returnType1), .function(let params2, let returnType2)):
            return params1.count == params2.count &&
                   zip(params1, params2).allSatisfy { $0.0.isCompatible(with: $0.1) } &&
                   compatibleReturnTypes(returnType1, returnType2)
        default:
            return false
        }
    }

    /// Check if this type can be assigned to another type.
    public func canAssignTo(_ target: FeType) -> Bool {
        switch (self, target) {
        case (.error, _), (_, .error):
            return true // Error type for recovery
        case (.unknown, _), (_, .unknown):
            return true // Unknown type during inference
        case (.integer, .real):
            return true // Implicit integer to real conversion
        case (.character, .string):
            return true // Implicit character to string conversion
        case (.array(let srcElement, let srcDims), .array(let targetElement, let targetDims)):
            // Arrays must have compatible element types and same dimensions
            return srcElement.canAssignTo(targetElement) && srcDims == targetDims
        default:
            return self.isCompatible(with: target)
        }
    }

    private func compatibleReturnTypes(_ returnType1: FeType?, _ returnType2: FeType?) -> Bool {
        switch (returnType1, returnType2) {
        case (.none, .none):
            return true
        case (.some(let type1), .some(let type2)):
            return type1.isCompatible(with: type2)
        default:
            return false
        }
    }
}

extension SemanticError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .typeMismatch(let expected, let actual, let position):
            return "Type mismatch at \(position): expected '\(expected)', got '\(actual)'"
        case .incompatibleTypes(let type1, let type2, let operation, let position):
            return "Incompatible types '\(type1)' and '\(type2)' for operation '\(operation)' at \(position)"
        case .unknownType(let name, let position):
            return "Unknown type '\(name)' at \(position)"
        case .invalidTypeConversion(let from, let targetType, let position):
            return "Invalid type conversion from '\(from)' to '\(targetType)' at \(position)"
        case .undeclaredVariable(let name, let position):
            return "Undeclared variable '\(name)' at \(position)"
        case .variableAlreadyDeclared(let name, let position):
            return "Variable '\(name)' already declared at \(position)"
        case .variableNotInitialized(let name, let position):
            return "Variable '\(name)' used before initialization at \(position)"
        case .constantReassignment(let name, let position):
            return "Cannot reassign constant '\(name)' at \(position)"
        case .invalidAssignmentTarget(let position):
            return "Invalid assignment target at \(position)"
        case .undeclaredFunction(let name, let position):
            return "Undeclared function '\(name)' at \(position)"
        case .functionAlreadyDeclared(let name, let position):
            return "Function '\(name)' already declared at \(position)"
        case .incorrectArgumentCount:
            return "Function argument count error"
        case .argumentTypeMismatch:
            return "Function argument type mismatch"
        case .missingReturnStatement:
            return "Missing return statement"
        case .returnTypeMismatch:
            return "Return type mismatch"
        case .voidFunctionReturnsValue:
            return "Void function returns value"
        case .unreachableCode(let position):
            return "Unreachable code at \(position)"
        case .breakOutsideLoop(let position):
            return "Break statement outside loop at \(position)"
        case .returnOutsideFunction(let position):
            return "Return statement outside function at \(position)"
        case .invalidArrayAccess(let position):
            return "Invalid array access at \(position)"
        case .arrayIndexTypeMismatch(let expected, let actual, let position):
            return "Array index type mismatch: expected '\(expected)', got '\(actual)' at \(position)"
        case .invalidArrayDimension(let position):
            return "Invalid array dimension at \(position)"
        case .undeclaredField:
            return "Undeclared field error"
        case .invalidFieldAccess(let position):
            return "Invalid field access at \(position)"
        case .cyclicDependency:
            return "Cyclic dependency detected"
        case .analysisDepthExceeded(let position):
            return "Analysis depth exceeded at \(position)"
        case .tooManyErrors:
            return "Too many semantic errors, stopping analysis"
        }
    }
}

/// Represents the result of semantic analysis.
public struct SemanticAnalysisResult: Sendable {
    public let isSuccessful: Bool
    public let errors: [SemanticError]
    public let warnings: [SemanticWarning]
    public let symbolTable: SymbolTable

    public init(
        isSuccessful: Bool,
        errors: [SemanticError] = [],
        warnings: [SemanticWarning] = [],
        symbolTable: SymbolTable
    ) {
        self.isSuccessful = isSuccessful
        self.errors = errors
        self.warnings = warnings
        self.symbolTable = symbolTable
    }

    /// Whether there are any errors.
    public var hasErrors: Bool {
        return !errors.isEmpty
    }

    /// Whether there are any warnings.
    public var hasWarnings: Bool {
        return !warnings.isEmpty
    }

    /// Total number of issues (errors + warnings).
    public var issueCount: Int {
        return errors.count + warnings.count
    }
}

/// Warnings that can occur during semantic analysis.
public enum SemanticWarning: Equatable, Sendable {
    case unusedVariable(String, position: SourcePosition)
    case unusedFunction(String, position: SourcePosition)
    case unreachableCode(position: SourcePosition)
    case implicitTypeConversion(from: FeType, targetType: FeType, position: SourcePosition)
    case shadowedVariable(String, position: SourcePosition)
    case inefficientOperation(description: String, position: SourcePosition)
}

extension SemanticWarning {
    public var description: String {
        switch self {
        case .unusedVariable(let name, let position):
            return "Unused variable '\(name)' at \(position)"
        case .unusedFunction(let name, let position):
            return "Unused function '\(name)' at \(position)"
        case .unreachableCode(let position):
            return "Unreachable code at \(position)"
        case .implicitTypeConversion(let from, let targetType, let position):
            return "Implicit type conversion from '\(from)' to '\(targetType)' at \(position)"
        case .shadowedVariable(let name, let position):
            return "Variable '\(name)' shadows variable in outer scope at \(position)"
        case .inefficientOperation(let description, let position):
            return "Inefficient operation: \(description) at \(position)"
        }
    }
}

// MARK: - Semantic Error Reporting Configuration

/// Configuration options for semantic error reporting.
public struct SemanticErrorReportingConfig: Sendable {
    /// Maximum number of errors to collect before stopping analysis.
    public let maxErrorCount: Int

    /// Whether to enable error deduplication at same source positions.
    public let enableDeduplication: Bool

    /// Whether to enable error correlation analysis.
    public let enableErrorCorrelation: Bool

    /// Whether to enable verbose output with detailed error information.
    public let verboseOutput: Bool

    /// Initialize with configuration options.
    public init(
        maxErrorCount: Int = 100,
        enableDeduplication: Bool = true,
        enableErrorCorrelation: Bool = false,
        verboseOutput: Bool = false
    ) {
        self.maxErrorCount = maxErrorCount
        self.enableDeduplication = enableDeduplication
        self.enableErrorCorrelation = enableErrorCorrelation
        self.verboseOutput = verboseOutput
    }

    /// Default configuration with standard settings.
    public static let `default` = SemanticErrorReportingConfig()

    /// Strict configuration with high error limit and all features enabled.
    public static let strict = SemanticErrorReportingConfig(
        maxErrorCount: 1000,
        enableDeduplication: true,
        enableErrorCorrelation: true,
        verboseOutput: true
    )

    /// Fast configuration optimized for performance with minimal features.
    public static let fast = SemanticErrorReportingConfig(
        maxErrorCount: 50,
        enableDeduplication: false,
        enableErrorCorrelation: false,
        verboseOutput: false
    )
}

// MARK: - Semantic Error Reporter

/// Thread-safe error reporter for collecting semantic analysis errors.
public final class SemanticErrorReporter: @unchecked Sendable {
    private let config: SemanticErrorReportingConfig
    private var errors: [SemanticError] = []
    private var warnings: [SemanticWarning] = []
    private var errorPositions: Set<String> = []
    private let lock = NSLock()
    private var isFinalized = false

    /// Initialize with configuration.
    public init(config: SemanticErrorReportingConfig = .default) {
        self.config = config
    }

    /// Collect a single semantic error.
    /// 
    /// When the error count reaches `maxErrorCount`, a single `tooManyErrors` error is appended
    /// and all subsequent errors are silently dropped to prevent memory issues during analysis.
    public func collect(_ error: SemanticError) {
        lock.lock()
        defer { lock.unlock() }

        guard !isFinalized else { return }
        guard errors.count < config.maxErrorCount else {
            // Append tooManyErrors marker only once when limit is first reached
            if errors.count == config.maxErrorCount {
                errors.append(.tooManyErrors(count: config.maxErrorCount))
            }
            // Silently drop all subsequent errors to prevent memory exhaustion
            return
        }

        if config.enableDeduplication {
            let positionKey = extractPositionKey(from: error)
            if errorPositions.contains(positionKey) {
                return // Skip duplicate error at same position
            }
            errorPositions.insert(positionKey)
        }

        errors.append(error)
    }

    /// Collect multiple semantic errors.
    public func collect(_ errors: [SemanticError]) {
        for error in errors {
            collect(error)
        }
    }

    /// Collect a semantic warning.
    public func collect(_ warning: SemanticWarning) {
        lock.lock()
        defer { lock.unlock() }

        guard !isFinalized else { return }
        warnings.append(warning)
    }

    /// Collect multiple semantic warnings.
    public func collect(_ warnings: [SemanticWarning]) {
        for warning in warnings {
            collect(warning)
        }
    }

    /// Finalize error collection and create analysis result.
    public func finalize(with symbolTable: SymbolTable) -> SemanticAnalysisResult {
        lock.lock()
        defer { lock.unlock() }

        guard !isFinalized else {
            return SemanticAnalysisResult(
                isSuccessful: false,
                errors: errors,
                warnings: warnings,
                symbolTable: symbolTable
            )
        }

        isFinalized = true

        // Generate unused symbol warnings when error correlation is enabled
        // This analyzes the symbol table to find declared but unused variables, functions, etc.
        // and converts them to semantic warnings for code quality feedback
        if config.enableErrorCorrelation {
            let unusedSymbols = symbolTable.getUnusedSymbols()
            for symbol in unusedSymbols {
                switch symbol.kind {
                case .variable, .constant, .parameter:
                    // Convert unused variables/constants/parameters to warnings
                    warnings.append(.unusedVariable(symbol.name, position: symbol.position))
                case .function, .procedure:
                    // Convert unused functions/procedures to warnings
                    warnings.append(.unusedFunction(symbol.name, position: symbol.position))
                default:
                    // Skip other symbol types (e.g., types) that don't need unused warnings
                    break
                }
            }
        }

        let isSuccessful = errors.isEmpty

        return SemanticAnalysisResult(
            isSuccessful: isSuccessful,
            errors: errors,
            warnings: warnings,
            symbolTable: symbolTable
        )
    }

    /// Get current error count.
    public var errorCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return errors.count
    }

    /// Get current warning count.
    public var warningCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return warnings.count
    }

    /// Check if error limit has been reached.
    public var hasReachedErrorLimit: Bool {
        lock.lock()
        defer { lock.unlock() }
        return errors.count >= config.maxErrorCount
    }

    /// Reset the error reporter for reuse.
    public func reset() {
        lock.lock()
        defer { lock.unlock() }

        errors.removeAll()
        warnings.removeAll()
        errorPositions.removeAll()
        isFinalized = false
    }

    // MARK: - Private Methods

    private func extractPositionKey(from error: SemanticError) -> String {
        let position: SourcePosition

        switch error {
        case .typeMismatch(_, _, let position),
             .incompatibleTypes(_, _, _, let position),
             .unknownType(_, let position),
             .invalidTypeConversion(_, _, let position),
             .undeclaredVariable(_, let position),
             .variableAlreadyDeclared(_, let position),
             .variableNotInitialized(_, let position),
             .constantReassignment(_, let position),
             .invalidAssignmentTarget(let position),
             .undeclaredFunction(_, let position),
             .functionAlreadyDeclared(_, let position),
             .incorrectArgumentCount(_, _, _, let position),
             .argumentTypeMismatch(_, _, _, _, let position),
             .missingReturnStatement(_, let position),
             .returnTypeMismatch(_, _, _, let position),
             .voidFunctionReturnsValue(_, let position),
             .unreachableCode(let position),
             .breakOutsideLoop(let position),
             .returnOutsideFunction(let position),
             .invalidArrayAccess(let position),
             .arrayIndexTypeMismatch(_, _, let position),
             .invalidArrayDimension(let position),
             .undeclaredField(_, _, let position),
             .invalidFieldAccess(let position),
             .cyclicDependency(_, let position),
             .analysisDepthExceeded(let position):
            return "\(position.line):\(position.column)"
        case .tooManyErrors:
            return "tooManyErrors" // Special key for this error type
        }
    }
}
