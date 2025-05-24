import Foundation

/// Errors that can occur during tokenization.
public enum TokenizerError: Error, Equatable, Sendable {
    /// An unexpected character was encountered
    case unexpectedCharacter(UnicodeScalar, SourcePosition)

    /// A string literal was not properly terminated
    case unterminatedString(SourcePosition)

    /// A comment was not properly terminated
    case unterminatedComment(SourcePosition)

    /// An invalid escape sequence was found in a string literal
    case invalidEscapeSequence(SourcePosition)

    /// An invalid number format was encountered
    case invalidNumberFormat(String, SourcePosition)

    /// An invalid digit for the number base was encountered
    case invalidDigitForBase(String, String, SourcePosition) // digit, base, position

    /// An invalid position for underscore separator in number
    case invalidUnderscorePlacement(SourcePosition)
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
        case .invalidEscapeSequence(let pos):
            return "Invalid escape sequence in string literal at line \(pos.line), column \(pos.column)"
        case .invalidNumberFormat(let format, let pos):
            return "Invalid number format '\(format)' at line \(pos.line), column \(pos.column)"
        case .invalidDigitForBase(let digit, let base, let pos):
            return "Invalid digit '\(digit)' for \(base) number at line \(pos.line), column \(pos.column)"
        case .invalidUnderscorePlacement(let pos):
            return "Invalid underscore placement in number at line \(pos.line), column \(pos.column)"
        }
    }
}

extension TokenizerError: LocalizedError {
    public var errorDescription: String? {
        return description
    }
}
