import Foundation

/// Errors that can occur during semantic analysis.
public enum SemanticError: Error, Equatable, Sendable {
    // Type-related errors
    case typeMismatch(expected: FeType, actual: FeType, at: SourcePosition)
    case incompatibleTypes(FeType, FeType, operation: String, at: SourcePosition)
    case unknownType(String, at: SourcePosition)
    case invalidTypeConversion(from: FeType, to: FeType, at: SourcePosition)

    // Variable/scope-related errors
    case undeclaredVariable(String, at: SourcePosition)
    case variableAlreadyDeclared(String, at: SourcePosition)
    case variableNotInitialized(String, at: SourcePosition)
    case constantReassignment(String, at: SourcePosition)
    case invalidAssignmentTarget(at: SourcePosition)

    // Function-related errors
    case undeclaredFunction(String, at: SourcePosition)
    case functionAlreadyDeclared(String, at: SourcePosition)
    case incorrectArgumentCount(function: String, expected: Int, actual: Int, at: SourcePosition)
    case argumentTypeMismatch(function: String, paramIndex: Int, expected: FeType, actual: FeType, at: SourcePosition)
    case missingReturnStatement(function: String, at: SourcePosition)
    case returnTypeMismatch(function: String, expected: FeType, actual: FeType, at: SourcePosition)
    case voidFunctionReturnsValue(function: String, at: SourcePosition)

    // Control flow errors
    case unreachableCode(at: SourcePosition)
    case breakOutsideLoop(at: SourcePosition)
    case returnOutsideFunction(at: SourcePosition)

    // Array/indexing errors
    case invalidArrayAccess(at: SourcePosition)
    case arrayIndexTypeMismatch(expected: FeType, actual: FeType, at: SourcePosition)
    case invalidArrayDimension(at: SourcePosition)

    // Record/field errors
    case undeclaredField(fieldName: String, recordType: String, at: SourcePosition)
    case invalidFieldAccess(at: SourcePosition)

    // Analysis limitations
    case cyclicDependency([String], at: SourcePosition)
    case analysisDepthExceeded(at: SourcePosition)
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
        case (.array(let e1, let d1), .array(let e2, let d2)):
            return e1.isCompatible(with: e2) && d1 == d2
        case (.record(let n1, let f1), .record(let n2, let f2)):
            return n1 == n2 && f1 == f2
        case (.function(let p1, let r1), .function(let p2, let r2)):
            return p1.count == p2.count &&
                   zip(p1, p2).allSatisfy { $0.0.isCompatible(with: $0.1) } &&
                   compatibleReturnTypes(r1, r2)
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
        default:
            return self.isCompatible(with: target)
        }
    }

    private func compatibleReturnTypes(_ r1: FeType?, _ r2: FeType?) -> Bool {
        switch (r1, r2) {
        case (.none, .none):
            return true
        case (.some(let t1), .some(let t2)):
            return t1.isCompatible(with: t2)
        default:
            return false
        }
    }
}

extension SemanticError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .typeMismatch(let expected, let actual, let pos):
            return "Type mismatch at \(pos): expected '\(expected)', got '\(actual)'"
        case .incompatibleTypes(let t1, let t2, let op, let pos):
            return "Incompatible types '\(t1)' and '\(t2)' for operation '\(op)' at \(pos)"
        case .unknownType(let name, let pos):
            return "Unknown type '\(name)' at \(pos)"
        case .invalidTypeConversion(let from, let to, let pos):
            return "Invalid type conversion from '\(from)' to '\(to)' at \(pos)"
        case .undeclaredVariable(let name, let pos):
            return "Undeclared variable '\(name)' at \(pos)"
        case .variableAlreadyDeclared(let name, let pos):
            return "Variable '\(name)' already declared at \(pos)"
        case .variableNotInitialized(let name, let pos):
            return "Variable '\(name)' used before initialization at \(pos)"
        case .constantReassignment(let name, let pos):
            return "Cannot reassign constant '\(name)' at \(pos)"
        case .invalidAssignmentTarget(let pos):
            return "Invalid assignment target at \(pos)"
        case .undeclaredFunction(let name, let pos):
            return "Undeclared function '\(name)' at \(pos)"
        case .functionAlreadyDeclared(let name, let pos):
            return "Function '\(name)' already declared at \(pos)"
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
        case .unreachableCode(let pos):
            return "Unreachable code at \(pos)"
        case .breakOutsideLoop(let pos):
            return "Break statement outside loop at \(pos)"
        case .returnOutsideFunction(let pos):
            return "Return statement outside function at \(pos)"
        case .invalidArrayAccess(let pos):
            return "Invalid array access at \(pos)"
        case .arrayIndexTypeMismatch(let expected, let actual, let pos):
            return "Array index type mismatch: expected '\(expected)', got '\(actual)' at \(pos)"
        case .invalidArrayDimension(let pos):
            return "Invalid array dimension at \(pos)"
        case .undeclaredField:
            return "Undeclared field error"
        case .invalidFieldAccess(let pos):
            return "Invalid field access at \(pos)"
        case .cyclicDependency:
            return "Cyclic dependency detected"
        case .analysisDepthExceeded(let pos):
            return "Analysis depth exceeded at \(pos)"
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
    case unusedVariable(String, at: SourcePosition)
    case unusedFunction(String, at: SourcePosition)
    case unreachableCode(at: SourcePosition)
    case implicitTypeConversion(from: FeType, to: FeType, at: SourcePosition)
    case shadowedVariable(String, at: SourcePosition)
    case inefficientOperation(description: String, at: SourcePosition)
}

extension SemanticWarning {
    public var description: String {
        switch self {
        case .unusedVariable(let name, let pos):
            return "Unused variable '\(name)' at \(pos)"
        case .unusedFunction(let name, let pos):
            return "Unused function '\(name)' at \(pos)"
        case .unreachableCode(let pos):
            return "Unreachable code at \(pos)"
        case .implicitTypeConversion(let from, let to, let pos):
            return "Implicit type conversion from '\(from)' to '\(to)' at \(pos)"
        case .shadowedVariable(let name, let pos):
            return "Variable '\(name)' shadows variable in outer scope at \(pos)"
        case .inefficientOperation(let desc, let pos):
            return "Inefficient operation: \(desc) at \(pos)"
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
    public func collect(_ error: SemanticError) {
        lock.lock()
        defer { lock.unlock() }

        guard !isFinalized else { return }
        guard errors.count < config.maxErrorCount else {
            if errors.count == config.maxErrorCount {
                errors.append(.tooManyErrors(count: config.maxErrorCount))
            }
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

        // Add unused variable warnings if correlation is enabled
        if config.enableErrorCorrelation {
            let unusedSymbols = symbolTable.getUnusedSymbols()
            for symbol in unusedSymbols {
                switch symbol.kind {
                case .variable, .constant, .parameter:
                    warnings.append(.unusedVariable(symbol.name, at: symbol.position))
                case .function, .procedure:
                    warnings.append(.unusedFunction(symbol.name, at: symbol.position))
                default:
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
            position = pos
        case .tooManyErrors:
            return "tooManyErrors" // Special key for this error type
        }

        return "\(position.line):\(position.column)"
    }
}
