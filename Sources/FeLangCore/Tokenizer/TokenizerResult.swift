import Foundation

/// Result of tokenization including tokens, errors, and warnings
public struct TokenizerResult: Sendable {
    public let tokens: [Token]
    public let errors: [EnhancedTokenizerError]
    public let warnings: [TokenizerWarning]

    public init(
        tokens: [Token],
        errors: [EnhancedTokenizerError] = [],
        warnings: [TokenizerWarning] = []
    ) {
        self.tokens = tokens
        self.errors = errors
        self.warnings = warnings
    }

    /// Whether tokenization was successful (no fatal errors)
    public var isSuccessful: Bool {
        return !errors.contains { $0.severity == .fatal }
    }

    /// Whether there are any errors (including non-fatal ones)
    public var hasErrors: Bool {
        return !errors.isEmpty
    }

    /// Whether there are any warnings
    public var hasWarnings: Bool {
        return !warnings.isEmpty
    }

    /// Get all errors of a specific severity
    public func errors(withSeverity severity: ErrorSeverity) -> [EnhancedTokenizerError] {
        return errors.filter { $0.severity == severity }
    }

    /// Get fatal errors only
    public var fatalErrors: [EnhancedTokenizerError] {
        return errors(withSeverity: .fatal)
    }

    /// Get recoverable errors only
    public var recoverableErrors: [EnhancedTokenizerError] {
        return errors(withSeverity: .error)
    }

    /// Summary statistics
    public var errorCount: Int { errors.count }
    public var warningCount: Int { warnings.count }
    public var tokenCount: Int { tokens.count }
}

/// Error collector for accumulating errors during tokenization
public final class ErrorCollector: @unchecked Sendable {
    private var _errors: [EnhancedTokenizerError] = []
    private var _warnings: [TokenizerWarning] = []
    private let lock = NSLock()

    public init() {
        // Arrays are already initialized
    }

    /// Add an error to the collection
    public func addError(_ error: EnhancedTokenizerError) {
        lock.lock()
        defer { lock.unlock() }
        _errors.append(error)
    }

    /// Add a warning to the collection
    public func addWarning(_ warning: TokenizerWarning) {
        lock.lock()
        defer { lock.unlock() }
        _warnings.append(warning)
    }

    /// Add a legacy error (for backward compatibility)
    public func addLegacyError(_ error: TokenizerError) {
        let enhancedError = EnhancedTokenizerError(from: error)
        addError(enhancedError)
    }

    /// Create error directly with parameters
    public func addError(
        type: EnhancedErrorType,
        range: SourceRange,
        message: String,
        suggestions: [String] = [],
        severity: ErrorSeverity = .error,
        context: String? = nil
    ) {
        let error = EnhancedTokenizerError(
            type: type,
            range: range,
            message: message,
            suggestions: suggestions,
            severity: severity,
            context: context
        )
        addError(error)
    }

    /// Create warning directly with parameters
    public func addWarning(
        type: WarningType,
        range: SourceRange,
        message: String,
        suggestions: [String] = []
    ) {
        let warning = TokenizerWarning(
            type: type,
            range: range,
            message: message,
            suggestions: suggestions
        )
        addWarning(warning)
    }

    /// Get current errors (thread-safe copy)
    public var errors: [EnhancedTokenizerError] {
        lock.lock()
        defer { lock.unlock() }
        return _errors
    }

    /// Get current warnings (thread-safe copy)
    public var warnings: [TokenizerWarning] {
        lock.lock()
        defer { lock.unlock() }
        return _warnings
    }

    /// Check if there are any fatal errors
    public var hasFatalErrors: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _errors.contains { $0.severity == .fatal }
    }

    /// Clear all collected errors and warnings
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        _errors.removeAll()
        _warnings.removeAll()
    }

    /// Create a TokenizerResult from collected errors and warnings
    public func createResult(with tokens: [Token]) -> TokenizerResult {
        return TokenizerResult(
            tokens: tokens,
            errors: errors,
            warnings: warnings
        )
    }
}

/// Recovery strategy for error handling
public enum RecoveryStrategy: Sendable {
    case skipCharacter          // Skip the invalid character and continue
    case synchronizeToNewline   // Skip to next newline
    case synchronizeToSemicolon // Skip to next semicolon
    case synchronizeToKeyword   // Skip to next recognized keyword
    case assumeToken(TokenType) // Assume a missing token and continue
    case stopProcessing         // Stop processing (for fatal errors)
}

/// Recovery manager for handling error recovery during tokenization
public struct RecoveryManager: Sendable {

    /// Determine appropriate recovery strategy for an error
    public static func recoveryStrategy(for error: EnhancedErrorType) -> RecoveryStrategy {
        switch error {
        case .unexpectedCharacter:
            return .skipCharacter

        case .unterminatedString:
            return .synchronizeToNewline

        case .unterminatedComment:
            return .synchronizeToNewline

        case .invalidNumberFormat, .invalidDigitForBase, .invalidUnderscorePlacement:
            return .skipCharacter

        case .invalidEscapeSequence:
            return .skipCharacter

        case .mismatchedDelimiters:
            return .synchronizeToSemicolon

        case .invalidCharacterInContext:
            return .skipCharacter

        case .invalidIdentifier:
            return .synchronizeToKeyword

        default:
            return .skipCharacter
        }
    }

    /// Check if error should trigger immediate stop
    public static func shouldStopProcessing(for error: EnhancedErrorType) -> Bool {
        switch error {
        case .invalidCharacterInContext(_, "critical"),
             .mismatchedDelimiters where false: // Add conditions for critical mismatches
            return true
        default:
            return false
        }
    }

    /// Suggest recovery action based on context
    public static func suggestRecoveryMessage(for strategy: RecoveryStrategy) -> String {
        switch strategy {
        case .skipCharacter:
            return "Skipping invalid character and continuing"
        case .synchronizeToNewline:
            return "Synchronizing to next line"
        case .synchronizeToSemicolon:
            return "Synchronizing to next statement"
        case .synchronizeToKeyword:
            return "Synchronizing to next keyword"
        case .assumeToken(let tokenType):
            return "Assuming missing \(tokenType.rawValue)"
        case .stopProcessing:
            return "Stopping due to fatal error"
        }
    }
}
