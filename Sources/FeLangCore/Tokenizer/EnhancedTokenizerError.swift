import Foundation

/// Enhanced error severity levels for better error classification
public enum ErrorSeverity: String, CaseIterable, Sendable {
    case fatal       // Should stop processing
    case error       // Recoverable errors
    case warning     // Potential issues
    case info        // Informational messages
}

/// Source range representing start and end positions
public struct SourceRange: Equatable, Sendable {
    public let start: SourcePosition
    public let end: SourcePosition

    public init(start: SourcePosition, end: SourcePosition) {
        self.start = start
        self.end = end
    }

    /// Create a range from a single position (zero-width range)
    public init(at position: SourcePosition) {
        self.start = position
        self.end = position
    }

    /// Create a range spanning multiple characters from a position
    public init(position: SourcePosition, length: Int) {
        self.start = position
        self.end = SourcePosition(
            line: position.line,
            column: position.column + length,
            offset: position.offset + length
        )
    }
}

/// Enhanced error type with detailed classification
public enum EnhancedErrorType: Equatable, Sendable {
    // Character-level errors
    case unexpectedCharacter(UnicodeScalar)
    case invalidCharacterInContext(UnicodeScalar, String) // char, context

    // String and character literal errors
    case unterminatedString
    case unterminatedCharacterLiteral
    case invalidEscapeSequence(String) // the invalid sequence
    case emptyCharacterLiteral
    case multipleCharactersInLiteral

    // Comment errors
    case unterminatedComment
    case nestedCommentNotAllowed

    // Number format errors
    case invalidNumberFormat(String) // the invalid format
    case invalidDigitForBase(String, String) // digit, base name
    case invalidUnderscorePlacement
    case invalidScientificNotation
    case invalidHexadecimalFormat
    case invalidBinaryFormat
    case invalidOctalFormat

    // Token-level errors
    case invalidIdentifier(String)
    case reservedKeywordAsIdentifier(String)

    // Structural errors
    case unterminatedStructure(String) // structure type
    case mismatchedDelimiters(String, String) // expected, found

    // Recovery-related
    case recoveredAfterError
    case assumedMissingToken(String) // what was assumed to be missing
}

/// Enhanced tokenizer error with comprehensive diagnostic information
public struct EnhancedTokenizerError: Error, Equatable, Sendable {
    public let type: EnhancedErrorType
    public let range: SourceRange
    public let message: String
    public let suggestions: [String]
    public let severity: ErrorSeverity
    public let context: String?

    public init(
        type: EnhancedErrorType,
        range: SourceRange,
        message: String,
        suggestions: [String] = [],
        severity: ErrorSeverity = .error,
        context: String? = nil
    ) {
        self.type = type
        self.range = range
        self.message = message
        self.suggestions = suggestions
        self.severity = severity
        self.context = context
    }

    /// Create error from legacy TokenizerError for backward compatibility
    public init(from legacyError: TokenizerError) {
        switch legacyError {
        case .unexpectedCharacter(let char, let pos):
            self.init(
                type: .unexpectedCharacter(char),
                range: SourceRange(at: pos),
                message: "Unexpected character '\(char)'",
                suggestions: ["Remove this character", "Replace with a valid character"],
                severity: .error,
                context: "Character '\(char)' is not valid in this context"
            )

        case .unterminatedString(let pos):
            self.init(
                type: .unterminatedString,
                range: SourceRange(at: pos),
                message: "Unterminated string literal",
                suggestions: ["Add closing quote \"", "Check for missing escape sequences"],
                severity: .error,
                context: "String literals must be properly closed"
            )

        case .unterminatedComment(let pos):
            self.init(
                type: .unterminatedComment,
                range: SourceRange(at: pos),
                message: "Unterminated comment",
                suggestions: ["Add closing */", "Check for nested comments"],
                severity: .error,
                context: "Multi-line comments must be properly closed"
            )

        case .invalidEscapeSequence(let pos):
            self.init(
                type: .invalidEscapeSequence(""),
                range: SourceRange(at: pos),
                message: "Invalid escape sequence",
                suggestions: ["Use valid escape sequences like \\n, \\t, \\\\", "Escape backslash as \\\\"],
                severity: .error,
                context: "Only specific escape sequences are allowed in strings"
            )

        case .invalidNumberFormat(let format, let pos):
            self.init(
                type: .invalidNumberFormat(format),
                range: SourceRange(position: pos, length: format.count),
                message: "Invalid number format '\(format)'",
                suggestions: ["Check number syntax", "Remove invalid characters"],
                severity: .error,
                context: "Number format does not match expected pattern"
            )

        case .invalidDigitForBase(let digit, let base, let pos):
            self.init(
                type: .invalidDigitForBase(digit, base),
                range: SourceRange(at: pos),
                message: "Invalid digit '\(digit)' for \(base) number",
                suggestions: EnhancedTokenizerError.suggestionsForBase(base),
                severity: .error,
                context: "\(base.capitalized) numbers can only contain specific digits"
            )

        case .invalidUnderscorePlacement(let pos):
            self.init(
                type: .invalidUnderscorePlacement,
                range: SourceRange(at: pos),
                message: "Invalid underscore placement in number",
                suggestions: ["Place underscores between digits", "Remove underscore at start/end"],
                severity: .error,
                context: "Underscores in numbers must be between digits"
            )
        }
    }

    private static func suggestionsForBase(_ base: String) -> [String] {
        switch base.lowercased() {
        case "binary":
            return ["Use only digits 0 and 1 for binary numbers"]
        case "octal":
            return ["Use only digits 0-7 for octal numbers"]
        case "hexadecimal":
            return ["Use only digits 0-9 and letters A-F for hexadecimal numbers"]
        default:
            return ["Check the valid digits for this number base"]
        }
    }
}

/// Warning type for non-error issues
public struct TokenizerWarning: Equatable, Sendable {
    public let type: WarningType
    public let range: SourceRange
    public let message: String
    public let suggestions: [String]

    public init(
        type: WarningType,
        range: SourceRange,
        message: String,
        suggestions: [String] = []
    ) {
        self.type = type
        self.range = range
        self.message = message
        self.suggestions = suggestions
    }
}

/// Warning types for potential issues
public enum WarningType: Equatable, Sendable {
    case deprecatedSyntax(String)
    case unnecessaryEscape(String)
    case unusualIdentifier(String)
    case performanceImpact(String)
    case styleSuggestion(String)
}

extension EnhancedTokenizerError: CustomStringConvertible {
    public var description: String {
        let severityStr = severity.rawValue.uppercased()
        let locationStr = "(\(range.start.line):\(range.start.column))"
        var desc = "[\(severityStr)] \(locationStr) \(message)"

        if !suggestions.isEmpty {
            desc += "\n  Suggestions: " + suggestions.joined(separator: ", ")
        }

        if let context = context {
            desc += "\n  Context: \(context)"
        }

        return desc
    }
}

extension EnhancedTokenizerError: LocalizedError {
    public var errorDescription: String? {
        return description
    }
}
