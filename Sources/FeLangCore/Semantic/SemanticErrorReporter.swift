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
        lock.lock()
        defer { lock.unlock() }

        for error in errors {
            guard !isFinalized else { return }
            guard collectedErrors.count < config.maxErrorCount else {
                // Add tooManyErrors marker if not already added
                if !collectedErrors.contains(where: {
                    if case .tooManyErrors = $0 { return true }
                    return false
                }) {
                    collectedErrors.append(.tooManyErrors(count: config.maxErrorCount))
                }
                break
            }

            if config.enableDeduplication && isDuplicate(error) {
                continue
            }

            collectedErrors.append(error)

            if config.enableDeduplication {
                recordErrorPosition(error)
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
        // Simple approach: use error type + position line/column/offset
        let errorType = String(describing: error).components(separatedBy: "(").first ?? "unknown"

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
            return "\(errorType)_\(position.line)_\(position.column)_\(position.offset)"
        case .tooManyErrors(let count):
            return "tooManyErrors_\(count)"
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
