import Foundation

/// A thread-safe error reporter for collecting and managing semantic analysis errors.
/// Provides error deduplication, configurable limits, and integration with the existing error formatting infrastructure.
public final class SemanticErrorReporter: @unchecked Sendable {
    
    // MARK: - Configuration
    
    /// Maximum number of errors to collect before stopping analysis.
    public static let defaultErrorLimit = 100
    
    // MARK: - Private Properties
    
    private let errorLimit: Int
    private let lock = NSLock()
    private var _errors: [SemanticError] = []
    private var _warnings: [SemanticWarning] = []
    private var errorSet: Set<String> = []
    private var warningSet: Set<String> = []
    
    // MARK: - Initialization
    
    /// Creates a new semantic error reporter.
    /// - Parameter errorLimit: Maximum number of errors to collect (default: 100)
    public init(errorLimit: Int = defaultErrorLimit) {
        self.errorLimit = errorLimit
    }
    
    // MARK: - Error Reporting
    
    /// Reports a semantic error with automatic deduplication.
    /// - Parameter error: The semantic error to report
    /// - Returns: True if the error was added, false if it was a duplicate or limit exceeded
    @discardableResult
    public func report(_ error: SemanticError) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        // Check error limit
        guard _errors.count < errorLimit else {
            if _errors.count == errorLimit {
                // Add the "too many errors" error once
                let tooManyError = SemanticError.tooManyErrors(count: errorLimit)
                _errors.append(tooManyError)
            }
            return false
        }
        
        // Create unique key for deduplication
        let errorKey = createErrorKey(for: error)
        
        // Check for duplicate
        guard !errorSet.contains(errorKey) else {
            return false
        }
        
        // Add error
        _errors.append(error)
        errorSet.insert(errorKey)
        return true
    }
    
    /// Reports a semantic warning with automatic deduplication.
    /// - Parameter warning: The semantic warning to report
    /// - Returns: True if the warning was added, false if it was a duplicate
    @discardableResult
    public func reportWarning(_ warning: SemanticWarning) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        // Create unique key for deduplication
        let warningKey = createWarningKey(for: warning)
        
        // Check for duplicate
        guard !warningSet.contains(warningKey) else {
            return false
        }
        
        // Add warning
        _warnings.append(warning)
        warningSet.insert(warningKey)
        return true
    }
    
    // MARK: - Status Queries
    
    /// Whether any errors have been reported.
    public var hasErrors: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !_errors.isEmpty
    }
    
    /// Whether any warnings have been reported.
    public var hasWarnings: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !_warnings.isEmpty
    }
    
    /// Total number of errors reported.
    public var errorCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _errors.count
    }
    
    /// Total number of warnings reported.
    public var warningCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _warnings.count
    }
    
    /// Whether the error limit has been reached.
    public var hasReachedErrorLimit: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _errors.count >= errorLimit
    }
    
    // MARK: - Error Retrieval
    
    /// Returns all errors sorted by position.
    /// - Returns: Array of semantic errors in source order
    public func getErrorsSorted() -> [SemanticError] {
        lock.lock()
        defer { lock.unlock() }
        return _errors.sorted { error1, error2 in
            let pos1 = extractPosition(from: error1)
            let pos2 = extractPosition(from: error2)
            
            if let p1 = pos1, let p2 = pos2 {
                if p1.line != p2.line {
                    return p1.line < p2.line
                }
                return p1.column < p2.column
            } else if pos1 != nil {
                return true
            } else if pos2 != nil {
                return false
            } else {
                return false
            }
        }
    }
    
    /// Returns all warnings sorted by position.
    /// - Returns: Array of semantic warnings in source order
    public func getWarningsSorted() -> [SemanticWarning] {
        lock.lock()
        defer { lock.unlock() }
        return _warnings.sorted { warning1, warning2 in
            let pos1 = extractPosition(from: warning1)
            let pos2 = extractPosition(from: warning2)
            
            if let p1 = pos1, let p2 = pos2 {
                if p1.line != p2.line {
                    return p1.line < p2.line
                }
                return p1.column < p2.column
            } else if pos1 != nil {
                return true
            } else if pos2 != nil {
                return false
            } else {
                return false
            }
        }
    }
    
    /// Creates a semantic analysis result from the collected errors and warnings.
    /// - Parameter symbolTable: The symbol table from the analysis
    /// - Returns: Complete semantic analysis result
    public func createResult(symbolTable: SymbolTable) -> SemanticAnalysisResult {
        let errors = getErrorsSorted()
        let warnings = getWarningsSorted()
        let isSuccessful = errors.isEmpty
        
        return SemanticAnalysisResult(
            isSuccessful: isSuccessful,
            errors: errors,
            warnings: warnings,
            symbolTable: symbolTable
        )
    }
    
    // MARK: - Clear and Reset
    
    /// Clears all collected errors and warnings.
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        _errors.removeAll()
        _warnings.removeAll()
        errorSet.removeAll()
        warningSet.removeAll()
    }
    
    // MARK: - Private Helpers
    
    private func createErrorKey(for error: SemanticError) -> String {
        switch error {
        case .typeMismatch(let expected, let actual, let pos):
            return "typeMismatch_\(expected)_\(actual)_\(pos.line)_\(pos.column)"
        case .incompatibleTypes(let t1, let t2, let op, let pos):
            return "incompatibleTypes_\(t1)_\(t2)_\(op)_\(pos.line)_\(pos.column)"
        case .unknownType(let name, let pos):
            return "unknownType_\(name)_\(pos.line)_\(pos.column)"
        case .invalidTypeConversion(let from, let to, let pos):
            return "invalidTypeConversion_\(from)_\(to)_\(pos.line)_\(pos.column)"
        case .undeclaredVariable(let name, let pos):
            return "undeclaredVariable_\(name)_\(pos.line)_\(pos.column)"
        case .variableAlreadyDeclared(let name, let pos):
            return "variableAlreadyDeclared_\(name)_\(pos.line)_\(pos.column)"
        case .variableNotInitialized(let name, let pos):
            return "variableNotInitialized_\(name)_\(pos.line)_\(pos.column)"
        case .constantReassignment(let name, let pos):
            return "constantReassignment_\(name)_\(pos.line)_\(pos.column)"
        case .invalidAssignmentTarget(let pos):
            return "invalidAssignmentTarget_\(pos.line)_\(pos.column)"
        case .undeclaredFunction(let name, let pos):
            return "undeclaredFunction_\(name)_\(pos.line)_\(pos.column)"
        case .functionAlreadyDeclared(let name, let pos):
            return "functionAlreadyDeclared_\(name)_\(pos.line)_\(pos.column)"
        case .incorrectArgumentCount(let function, let expected, let actual, let pos):
            return "incorrectArgumentCount_\(function)_\(expected)_\(actual)_\(pos.line)_\(pos.column)"
        case .argumentTypeMismatch(let function, let paramIndex, let expected, let actual, let pos):
            return "argumentTypeMismatch_\(function)_\(paramIndex)_\(expected)_\(actual)_\(pos.line)_\(pos.column)"
        case .missingReturnStatement(let function, let pos):
            return "missingReturnStatement_\(function)_\(pos.line)_\(pos.column)"
        case .returnTypeMismatch(let function, let expected, let actual, let pos):
            return "returnTypeMismatch_\(function)_\(expected)_\(actual)_\(pos.line)_\(pos.column)"
        case .voidFunctionReturnsValue(let function, let pos):
            return "voidFunctionReturnsValue_\(function)_\(pos.line)_\(pos.column)"
        case .unreachableCode(let pos):
            return "unreachableCode_\(pos.line)_\(pos.column)"
        case .breakOutsideLoop(let pos):
            return "breakOutsideLoop_\(pos.line)_\(pos.column)"
        case .returnOutsideFunction(let pos):
            return "returnOutsideFunction_\(pos.line)_\(pos.column)"
        case .invalidArrayAccess(let pos):
            return "invalidArrayAccess_\(pos.line)_\(pos.column)"
        case .arrayIndexTypeMismatch(let expected, let actual, let pos):
            return "arrayIndexTypeMismatch_\(expected)_\(actual)_\(pos.line)_\(pos.column)"
        case .invalidArrayDimension(let pos):
            return "invalidArrayDimension_\(pos.line)_\(pos.column)"
        case .undeclaredField(let fieldName, let recordType, let pos):
            return "undeclaredField_\(fieldName)_\(recordType)_\(pos.line)_\(pos.column)"
        case .invalidFieldAccess(let pos):
            return "invalidFieldAccess_\(pos.line)_\(pos.column)"
        case .cyclicDependency(let vars, let pos):
            return "cyclicDependency_\(vars.joined(separator: "_"))_\(pos.line)_\(pos.column)"
        case .analysisDepthExceeded(let pos):
            return "analysisDepthExceeded_\(pos.line)_\(pos.column)"
        case .tooManyErrors(let count):
            return "tooManyErrors_\(count)"
        }
    }
    
    private func createWarningKey(for warning: SemanticWarning) -> String {
        switch warning {
        case .unusedVariable(let name, let pos):
            return "unusedVariable_\(name)_\(pos.line)_\(pos.column)"
        case .unusedFunction(let name, let pos):
            return "unusedFunction_\(name)_\(pos.line)_\(pos.column)"
        case .unreachableCode(let pos):
            return "unreachableCode_\(pos.line)_\(pos.column)"
        case .implicitTypeConversion(let from, let to, let pos):
            return "implicitTypeConversion_\(from)_\(to)_\(pos.line)_\(pos.column)"
        case .shadowedVariable(let name, let pos):
            return "shadowedVariable_\(name)_\(pos.line)_\(pos.column)"
        case .inefficientOperation(let desc, let pos):
            return "inefficientOperation_\(desc)_\(pos.line)_\(pos.column)"
        }
    }
    
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
        case .tooManyErrors:
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