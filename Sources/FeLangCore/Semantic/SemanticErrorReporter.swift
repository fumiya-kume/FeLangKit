import Foundation

/// Configuration for semantic error reporting behavior.
public struct SemanticErrorReportingConfig: Sendable {
    public let maxErrorCount: Int
    public let enableDeduplication: Bool
    public let enableErrorCorrelation: Bool
    public let verboseOutput: Bool

    public init(
        maxErrorCount: Int = 100,
        enableDeduplication: Bool = true,
        enableErrorCorrelation: Bool = true,
        verboseOutput: Bool = false
    ) {
        self.maxErrorCount = maxErrorCount
        self.enableDeduplication = enableDeduplication
        self.enableErrorCorrelation = enableErrorCorrelation
        self.verboseOutput = verboseOutput
    }

    /// Default configuration for semantic error reporting.
    public static let `default` = SemanticErrorReportingConfig()
}

/// Core semantic error reporting infrastructure that provides comprehensive error collection,
/// formatting, and reporting capabilities for semantic analysis.
public final class SemanticErrorReporter: @unchecked Sendable {

    // MARK: - Properties

    private let config: SemanticErrorReportingConfig
    private var collectedErrors: [SemanticError] = []
    private var errorPositions: Set<String> = [] // For deduplication
    private let lock = NSLock()
    private var isFinalized = false

    // MARK: - Initialization

    public init(config: SemanticErrorReportingConfig = .default) {
        self.config = config
    }

    // MARK: - Public Interface

    /// Collect a single semantic error.
    public func collect(_ error: SemanticError) {
        lock.lock()
        defer { lock.unlock() }

        guard !isFinalized else { return }
        guard !isFull else { return }

        if config.enableDeduplication && isDuplicate(error) {
            return
        }

        collectedErrors.append(error)

        if config.enableDeduplication {
            recordErrorPosition(error)
        }

        // If we've hit the threshold, add a tooManyErrors marker
        if collectedErrors.count >= config.maxErrorCount {
            collectedErrors.append(.tooManyErrors(count: config.maxErrorCount))
        }
    }

    /// Collect multiple semantic errors.
    public func collect(_ errors: [SemanticError]) {
        for error in errors {
            collect(error)
            if isFull {
                break
            }
        }
    }

    /// Finalize error collection and generate SemanticAnalysisResult.
    public func finalize(with symbolTable: SymbolTable) -> SemanticAnalysisResult {
        lock.lock()
        defer { lock.unlock() }

        isFinalized = true

        let finalErrors = processErrors()
        let isSuccessful = finalErrors.isEmpty

        return SemanticAnalysisResult(
            isSuccessful: isSuccessful,
            errors: finalErrors,
            warnings: [], // Warnings to be implemented separately
            symbolTable: symbolTable
        )
    }

    /// Clear all collected errors and reset state.
    public func clear() {
        lock.lock()
        defer { lock.unlock() }

        collectedErrors.removeAll()
        errorPositions.removeAll()
        isFinalized = false
    }

    /// Number of errors currently collected.
    public var errorCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return collectedErrors.count
    }

    /// Whether any errors have been collected.
    public var hasErrors: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !collectedErrors.isEmpty
    }

    /// Whether the error threshold has been reached.
    public var isFull: Bool {
        lock.lock()
        defer { lock.unlock() }
        return collectedErrors.count >= config.maxErrorCount
    }

    // MARK: - Private Implementation

    /// Check if an error is a duplicate based on position and type.
    private func isDuplicate(_ error: SemanticError) -> Bool {
        let key = errorKey(for: error)
        return errorPositions.contains(key)
    }

    /// Record an error's position for deduplication.
    private func recordErrorPosition(_ error: SemanticError) {
        let key = errorKey(for: error)
        errorPositions.insert(key)
    }

    /// Generate a unique key for an error based on its type and position.
    private func errorKey(for error: SemanticError) -> String {
        return generateErrorKey(for: error)
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func generateErrorKey(for error: SemanticError) -> String {
        switch error {
        case .typeMismatch(let expected, let actual, let position):
            return "typeMismatch:\(expected):\(actual):\(position)"
        case .incompatibleTypes(let type1, let type2, let operation, let position):
            return "incompatibleTypes:\(type1):\(type2):\(operation):\(position)"
        case .unknownType(let name, let position):
            return "unknownType:\(name):\(position)"
        case .invalidTypeConversion(let from, let target, let position):
            return "invalidTypeConversion:\(from):\(target):\(position)"
        case .undeclaredVariable(let name, let position):
            return "undeclaredVariable:\(name):\(position)"
        case .variableAlreadyDeclared(let name, let position):
            return "variableAlreadyDeclared:\(name):\(position)"
        case .variableNotInitialized(let name, let position):
            return "variableNotInitialized:\(name):\(position)"
        case .constantReassignment(let name, let position):
            return "constantReassignment:\(name):\(position)"
        case .invalidAssignmentTarget(let position):
            return "invalidAssignmentTarget:\(position)"
        case .undeclaredFunction(let name, let position):
            return "undeclaredFunction:\(name):\(position)"
        case .functionAlreadyDeclared(let name, let position):
            return "functionAlreadyDeclared:\(name):\(position)"
        case .incorrectArgumentCount(let function, let expected, let actual, let position):
            return "incorrectArgumentCount:\(function):\(expected):\(actual):\(position)"
        case .argumentTypeMismatch(let function, let paramIndex, let expected, let actual, let position):
            return "argumentTypeMismatch:\(function):\(paramIndex):\(expected):\(actual):\(position)"
        case .missingReturnStatement(let function, let position):
            return "missingReturnStatement:\(function):\(position)"
        case .returnTypeMismatch(let function, let expected, let actual, let position):
            return "returnTypeMismatch:\(function):\(expected):\(actual):\(position)"
        case .voidFunctionReturnsValue(let function, let position):
            return "voidFunctionReturnsValue:\(function):\(position)"
        case .unreachableCode(let position):
            return "unreachableCode:\(position)"
        case .breakOutsideLoop(let position):
            return "breakOutsideLoop:\(position)"
        case .returnOutsideFunction(let position):
            return "returnOutsideFunction:\(position)"
        case .invalidArrayAccess(let position):
            return "invalidArrayAccess:\(position)"
        case .arrayIndexTypeMismatch(let expected, let actual, let position):
            return "arrayIndexTypeMismatch:\(expected):\(actual):\(position)"
        case .invalidArrayDimension(let position):
            return "invalidArrayDimension:\(position)"
        case .undeclaredField(let fieldName, let recordType, let position):
            return "undeclaredField:\(fieldName):\(recordType):\(position)"
        case .invalidFieldAccess(let position):
            return "invalidFieldAccess:\(position)"
        case .cyclicDependency(let deps, let position):
            return "cyclicDependency:\(deps.joined(separator: ",")):\(position)"
        case .analysisDepthExceeded(let position):
            return "analysisDepthExceeded:\(position)"
        case .tooManyErrors(let count):
            return "tooManyErrors:\(count)"
        }
    }

    /// Process collected errors for final output, applying correlation if enabled.
    private func processErrors() -> [SemanticError] {
        var errors = collectedErrors

        if config.enableErrorCorrelation {
            errors = correlateErrors(errors)
        }

        return errors
    }

    /// Group related errors when possible to reduce noise.
    private func correlateErrors(_ errors: [SemanticError]) -> [SemanticError] {
        // For now, return errors as-is. Future enhancement could group related errors
        // like multiple type mismatches for the same variable or function.
        return errors
    }
}
