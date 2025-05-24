import Foundation

/// Errors that can occur during tokenization.
public enum TokenizerError: Error, Equatable, Sendable {
    /// An unexpected character was encountered
    case unexpectedCharacter(UnicodeScalar, SourcePosition)

    /// A string literal was not properly terminated
    case unterminatedString(SourcePosition)

    /// A comment was not properly terminated
    case unterminatedComment(SourcePosition)

    /// A number has an invalid format
    case invalidNumberFormat(String, SourcePosition)
}

extension TokenizerError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .unexpectedCharacter(let char, let pos):
            return "Unexpected character '\(char)' at line \(pos.line), column \(pos.column)"
        case .unterminatedString(let pos):
            return "Unterminated string literal at line \(pos.line), column \(pos.column)"
        case .unterminatedComment(let pos):
            return "Unterminated comment at line \(pos.line), column \(pos.column)"
        case .invalidNumberFormat(let text, let pos):
            return "Invalid number format '\(text)' at line \(pos.line), column \(pos.column)"
        }
    }
}

extension TokenizerError: LocalizedError {
    public var errorDescription: String? {
        return description
    }
}
