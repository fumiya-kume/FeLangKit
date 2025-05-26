import Foundation

/// Thread-safe semantic error reporter for collecting and managing semantic analysis errors and warnings.
/// This class provides error collection with deduplication, configurable error limits, and integration
/// with the existing FeLangCore error handling infrastructure.
public final class SemanticErrorReporter: @unchecked Sendable {
    
    // MARK: - Configuration
    
    /// Maximum number of errors to collect before stopping analysis
    public static let defaultMaxErrors = 100
    
    /// Maximum number of warnings to collect
    public static let defaultMaxWarnings = 200
    
    // MARK: - Private Properties
    
    private let maxErrors: Int
    private let maxWarnings: Int
    private let queue = DispatchQueue(label: "com.felangcore.semantic-error-reporter", attributes: .concurrent)
    
    private var _errors: [SemanticError] = []
    private var _warnings: [SemanticWarning] = []
    private var _errorPositions: Set<SourcePosition> = []
    private var _stopped = false
    
    // MARK: - Initialization
    
    /// Creates a new semantic error reporter with configurable limits.
    /// - Parameters:
    ///   - maxErrors: Maximum number of errors to collect (default: 100)
    ///   - maxWarnings: Maximum number of warnings to collect (default: 200)
    public init(maxErrors: Int = defaultMaxErrors, maxWarnings: Int = defaultMaxWarnings) {
        self.maxErrors = maxErrors
        self.maxWarnings = maxWarnings
    }
    
    // MARK: - Error Reporting
    
    /// Reports a semantic error with automatic deduplication.
    /// - Parameter error: The semantic error to report
    /// - Returns: `true` if the error was added, `false` if it was a duplicate or limit exceeded
    @discardableResult
    public func report(_ error: SemanticError) -> Bool {
        return queue.sync(flags: .barrier) {
            guard !_stopped && _errors.count < maxErrors else {
                if !_stopped && _errors.count >= maxErrors {
                    _stopped = true
                    _errors.append(.tooManyErrors(count: maxErrors))
                }
                return false
            }
            
            // Extract position for deduplication
            let position = extractPosition(from: error)
            
            // Check for duplicate errors at the same position
            if let pos = position, _errorPositions.contains(pos) {
                return false
            }
            
            _errors.append(error)
            if let pos = position {
                _errorPositions.insert(pos)
            }
            
            return true
        }
    }
    
    /// Reports a semantic warning with deduplication.
    /// - Parameter warning: The semantic warning to report
    /// - Returns: `true` if the warning was added, `false` if it was a duplicate or limit exceeded
    @discardableResult
    public func reportWarning(_ warning: SemanticWarning) -> Bool {
        return queue.sync(flags: .barrier) {
            guard _warnings.count < maxWarnings else {
                return false
            }
            
            // Simple deduplication - avoid identical warnings
            guard !_warnings.contains(warning) else {
                return false
            }
            
            _warnings.append(warning)
            return true
        }
    }
    
    /// Reports multiple errors in a batch operation.
    /// - Parameter errors: Array of semantic errors to report
    /// - Returns: Number of errors successfully added
    @discardableResult
    public func reportBatch(_ errors: [SemanticError]) -> Int {
        var addedCount = 0
        for error in errors {
            if report(error) {
                addedCount += 1
            }
            if _stopped {
                break
            }
        }
        return addedCount
    }
    
    // MARK: - Status Queries
    
    /// Whether any errors have been reported.
    public var hasErrors: Bool {
        return queue.sync {
            !_errors.isEmpty
        }
    }
    
    /// Whether any warnings have been reported.
    public var hasWarnings: Bool {
        return queue.sync {
            !_warnings.isEmpty
        }
    }
    
    /// Current number of reported errors.
    public var errorCount: Int {
        return queue.sync {
            _errors.count
        }
    }
    
    /// Current number of reported warnings.
    public var warningCount: Int {
        return queue.sync {
            _warnings.count
        }
    }
    
    /// Whether error collection has been stopped due to reaching the limit.
    public var isStopped: Bool {
        return queue.sync {
            _stopped
        }
    }
    
    /// Total number of issues (errors + warnings).
    public var issueCount: Int {
        return queue.sync {
            _errors.count + _warnings.count
        }
    }
    
    // MARK: - Error Retrieval
    
    /// Returns all reported errors sorted by position.
    /// - Returns: Array of semantic errors sorted by source position
    public func getErrorsSorted() -> [SemanticError] {
        return queue.sync {
            _errors.sorted { error1, error2 in
                let pos1 = extractPosition(from: error1)
                let pos2 = extractPosition(from: error2)
                
                switch (pos1, pos2) {
                case (.some(let p1), .some(let p2)):
                    if p1.line != p2.line {
                        return p1.line < p2.line
                    }
                    return p1.column < p2.column
                case (.some(_), .none):
                    return true
                case (.none, .some(_)):
                    return false
                case (.none, .none):
                    return false
                }
            }
        }
    }
    
    /// Returns all reported warnings sorted by position.
    /// - Returns: Array of semantic warnings sorted by source position
    public func getWarningsSorted() -> [SemanticWarning] {
        return queue.sync {
            _warnings.sorted { warning1, warning2 in
                let pos1 = extractPosition(from: warning1)
                let pos2 = extractPosition(from: warning2)
                
                switch (pos1, pos2) {
                case (.some(let p1), .some(let p2)):
                    if p1.line != p2.line {
                        return p1.line < p2.line
                    }
                    return p1.column < p2.column
                case (.some(_), .none):
                    return true
                case (.none, .some(_)):
                    return false
                case (.none, .none):
                    return false
                }
            }
        }
    }
    
    /// Returns errors filtered by category/type.
    /// - Parameter predicate: Filter predicate for errors
    /// - Returns: Filtered array of semantic errors
    public func getErrors(where predicate: @escaping (SemanticError) -> Bool) -> [SemanticError] {
        return queue.sync {
            _errors.filter(predicate)
        }
    }
    
    /// Returns warnings filtered by category/type.
    /// - Parameter predicate: Filter predicate for warnings
    /// - Returns: Filtered array of semantic warnings
    public func getWarnings(where predicate: @escaping (SemanticWarning) -> Bool) -> [SemanticWarning] {
        return queue.sync {
            _warnings.filter(predicate)
        }
    }
    
    // MARK: - Analysis Results
    
    /// Creates a semantic analysis result from the current state.
    /// - Parameter symbolTable: The symbol table from semantic analysis
    /// - Returns: Complete semantic analysis result
    public func createAnalysisResult(symbolTable: SymbolTable) -> SemanticAnalysisResult {
        return queue.sync {
            SemanticAnalysisResult(
                isSuccessful: _errors.isEmpty,
                errors: _errors,
                warnings: _warnings,
                symbolTable: symbolTable
            )
        }
    }
    
    // MARK: - Utility Methods
    
    /// Clears all reported errors and warnings, resetting the reporter state.
    public func reset() {
        queue.sync(flags: .barrier) {
            _errors.removeAll()
            _warnings.removeAll()
            _errorPositions.removeAll()
            _stopped = false
        }
    }
    
    /// Creates a summary string of all errors and warnings.
    /// - Returns: Human-readable summary of issues
    public func createSummary() -> String {
        return queue.sync {
            let errorCount = _errors.count
            let warningCount = _warnings.count
            
            if errorCount == 0 && warningCount == 0 {
                return "No semantic issues found"
            }
            
            var summary = "Semantic analysis found "
            
            if errorCount > 0 {
                summary += "\(errorCount) error\(errorCount == 1 ? "" : "s")"
                if warningCount > 0 {
                    summary += " and "
                }
            }
            
            if warningCount > 0 {
                summary += "\(warningCount) warning\(warningCount == 1 ? "" : "s")"
            }
            
            if _stopped {
                summary += " (analysis stopped due to error limit)"
            }
            
            return summary
        }
    }
    
    // MARK: - Private Helpers
    
    private func extractPosition(from error: SemanticError) -> SourcePosition? {
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
    
    private func extractPosition(from warning: SemanticWarning) -> SourcePosition? {
        switch warning {
        case .unusedVariable(_, let pos),
             .unusedFunction(_, let pos),
             .unreachableCode(let pos),
             .implicitTypeConversion(_, _, let pos),
             .shadowedVariable(_, let pos),
             .inefficientOperation(_, let pos):
            return pos
        }
    }
}

// MARK: - Error Category Extensions

extension SemanticErrorReporter {
    
    /// Returns type-related errors.
    public var typeErrors: [SemanticError] {
        return getErrors { error in
            switch error {
            case .typeMismatch, .incompatibleTypes, .unknownType, .invalidTypeConversion:
                return true
            default:
                return false
            }
        }
    }
    
    /// Returns variable/scope-related errors.
    public var scopeErrors: [SemanticError] {
        return getErrors { error in
            switch error {
            case .undeclaredVariable, .variableAlreadyDeclared, .variableNotInitialized,
                 .constantReassignment, .invalidAssignmentTarget:
                return true
            default:
                return false
            }
        }
    }
    
    /// Returns function-related errors.
    public var functionErrors: [SemanticError] {
        return getErrors { error in
            switch error {
            case .undeclaredFunction, .functionAlreadyDeclared, .incorrectArgumentCount,
                 .argumentTypeMismatch, .missingReturnStatement, .returnTypeMismatch,
                 .voidFunctionReturnsValue:
                return true
            default:
                return false
            }
        }
    }
    
    /// Returns control flow errors.
    public var controlFlowErrors: [SemanticError] {
        return getErrors { error in
            switch error {
            case .unreachableCode, .breakOutsideLoop, .returnOutsideFunction:
                return true
            default:
                return false
            }
        }
    }
}