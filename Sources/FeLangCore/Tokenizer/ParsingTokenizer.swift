import Foundation

/// A tokenizer for FE pseudo-language with a focus on simplicity and correctness.
/// This implementation prioritizes the same functionality as the original tokenizer
/// while being easier to extend and maintain.
public struct ParsingTokenizer: Sendable {

    public init() {}

    public func tokenize(_ input: String) throws -> [Token] {
        var tokens: [Token] = []
        var index = input.startIndex
        let startIndex = index

        while index < input.endIndex {
            let position = sourcePosition(from: input, startIndex: startIndex, currentIndex: index)

            // Skip whitespace and newlines
            if input[index].isWhitespace {
                index = input.index(after: index)
                continue
            }

            // Try to parse a token
            let beforeIndex = index
            if let token = try parseNextToken(from: input, at: &index, startIndex: startIndex) {
                let tokenWithPosition = Token(
                    type: token.type,
                    lexeme: token.lexeme,
                    position: position
                )
                tokens.append(tokenWithPosition)
            } else {
                // Check if index moved (could be a comment that was skipped)
                if index > beforeIndex {
                    continue // Comment was skipped, continue to next iteration
                }

                // If we can't parse a token, it's an unexpected character
                guard let scalar = String(input[index]).unicodeScalars.first else {
                    index = input.index(after: index)
                    continue
                }
                throw TokenizerError.unexpectedCharacter(scalar, position)
            }

            // Safety check to prevent infinite loops
            if index == beforeIndex {
                guard let scalar = String(input[index]).unicodeScalars.first else {
                    index = input.index(after: index)
                    continue
                }
                throw TokenizerError.unexpectedCharacter(scalar, position)
            }
        }

        // Add EOF token
        let finalPosition = sourcePosition(from: input, startIndex: startIndex, currentIndex: index)
        tokens.append(Token(type: .eof, lexeme: "", position: finalPosition))

        return tokens
    }

    private func parseNextToken(from input: String, at index: inout String.Index, startIndex: String.Index) throws -> TokenData? {
        // Try to parse comments first (skip them, don't return tokens)
        if try parseComment(from: input, at: &index, startIndex: startIndex) != nil {
            return nil // Comments are skipped
        }

        // Try to parse keywords
        if let token = parseKeyword(from: input, at: &index) {
            return token
        }

        // Try to parse operators
        if let token = parseOperator(from: input, at: &index) {
            return token
        }

        // Try to parse numbers (including leading-dot decimals) before delimiters
        if let token = parseNumber(from: input, at: &index) {
            return token
        }

        // Try to parse delimiters
        if let token = parseDelimiter(from: input, at: &index) {
            return token
        }

        // Try to parse strings
        if let token = try parseString(from: input, at: &index, startIndex: startIndex) {
            return token
        }

        // Try to parse identifiers
        if let token = parseIdentifier(from: input, at: &index) {
            return token
        }

        return nil
    }

    // MARK: - Parsing Methods

    private func parseComment(from input: String, at index: inout String.Index, startIndex: String.Index) throws -> TokenData? {
        guard index < input.endIndex else { return nil }

        // Single line comment
        if TokenizerUtilities.matchString("//", in: input, at: index) {
            let start = index
            index = input.index(index, offsetBy: 2)

            // Read until newline or end
            while index < input.endIndex && input[index] != "\n" {
                index = input.index(after: index)
            }

            let lexeme = String(input[start..<index])
            return TokenData(type: .comment, lexeme: lexeme)
        }

        // Multi-line comment
        if TokenizerUtilities.matchString("/*", in: input, at: index) {
            let commentStart = index
            let position = TokenizerUtilities.sourcePosition(from: input, startIndex: startIndex, currentIndex: index)
            index = input.index(index, offsetBy: 2)

            var foundTerminator = false
            // Read until */
            while index < input.endIndex {
                if TokenizerUtilities.matchString("*/", in: input, at: index) {
                    index = input.index(index, offsetBy: 2)
                    foundTerminator = true
                    break
                }
                index = input.index(after: index)
            }

            // Check if comment was properly terminated
            if !foundTerminator {
                throw TokenizerError.unterminatedComment(position)
            }

            let lexeme = String(input[commentStart..<index])
            return TokenData(type: .comment, lexeme: lexeme)
        }

        return nil
    }

    private func parseKeyword(from input: String, at index: inout String.Index) -> TokenData? {
        // Use shared implementation for consistent behavior across all tokenizers
        guard let sharedTokenData = SharedTokenizerImplementation.parseKeyword(from: input, at: &index) else { return nil }
        return TokenData(type: sharedTokenData.type, lexeme: sharedTokenData.lexeme)
    }

    private func parseOperator(from input: String, at index: inout String.Index) -> TokenData? {
        // Use shared implementation for consistent behavior across all tokenizers
        guard let sharedTokenData = SharedTokenizerImplementation.parseOperator(from: input, at: &index) else { return nil }
        return TokenData(type: sharedTokenData.type, lexeme: sharedTokenData.lexeme)
    }

    private func parseDelimiter(from input: String, at index: inout String.Index) -> TokenData? {
        // Use shared implementation for consistent behavior across all tokenizers
        guard let sharedTokenData = SharedTokenizerImplementation.parseDelimiter(from: input, at: &index) else { return nil }
        return TokenData(type: sharedTokenData.type, lexeme: sharedTokenData.lexeme)
    }

    private func parseNumber(from input: String, at index: inout String.Index) -> TokenData? {
        // Use shared implementation for consistent behavior across all tokenizers
        guard let sharedTokenData = SharedTokenizerImplementation.parseNumber(from: input, at: &index) else { return nil }
        return TokenData(type: sharedTokenData.type, lexeme: sharedTokenData.lexeme)
    }

    // ✅ REMOVED: Individual number parsing methods have been consolidated into SharedTokenizerImplementation
    // This eliminates ~80 lines of duplicated code while maintaining identical functionality

    private func parseString(from input: String, at index: inout String.Index, startIndex: String.Index) throws -> TokenData? {
        guard index < input.endIndex else { return nil }

        let quoteChar = input[index]
        guard quoteChar == "'" || quoteChar == "\"" else { return nil }

        let start = index
        let position = TokenizerUtilities.sourcePosition(from: input, startIndex: startIndex, currentIndex: index)
        index = input.index(after: index) // Skip opening quote

        // Read until closing quote, handling escape sequences
        while index < input.endIndex && input[index] != quoteChar {
            // Handle escape sequences
            if input[index] == "\\" {
                index = input.index(after: index) // consume backslash

                guard index < input.endIndex else {
                    throw TokenizerError.invalidEscapeSequenceWithMessage("Incomplete escape sequence at end of string", position)
                }

                let escapedChar = input[index]
                index = input.index(after: index) // consume escaped character

                // Handle Unicode escape sequences specially
                if escapedChar == "u" {
                    guard index < input.endIndex && input[index] == "{" else {
                        throw TokenizerError.invalidUnicodeEscape("Expected '{' after \\u", position)
                    }
                    index = input.index(after: index) // consume '{'

                    // Scan hex digits
                    var hexDigitCount = 0
                    while index < input.endIndex && input[index] != "}" && hexDigitCount < 8 {
                        guard let scalar = String(input[index]).unicodeScalars.first,
                              TokenizerUtilities.isHexDigit(scalar) else {
                            throw TokenizerError.invalidUnicodeEscape("Invalid hex digit in Unicode escape", position)
                        }
                        index = input.index(after: index)
                        hexDigitCount += 1
                    }

                    guard index < input.endIndex else {
                        throw TokenizerError.invalidUnicodeEscape("Unterminated Unicode escape sequence", position)
                    }

                    guard input[index] == "}" else {
                        throw TokenizerError.invalidUnicodeEscape("Unicode escape sequence too long (max 8 hex digits)", position)
                    }

                    guard hexDigitCount > 0 else {
                        throw TokenizerError.invalidUnicodeEscape("Unicode escape sequence must have at least one hex digit", position)
                    }

                    index = input.index(after: index) // consume '}'
                } else {
                    // Validate basic escape sequences
                    switch escapedChar {
                    case "n", "t", "r", "\\", "\"", "'":
                        break // Valid escape sequences
                    default:
                        throw TokenizerError.invalidEscapeSequenceWithMessage("Unknown escape sequence \\\\(escapedChar)", position)
                    }
                }
            } else {
                index = input.index(after: index)
            }
        }

        // Must have closing quote
        guard index < input.endIndex else {
            throw TokenizerError.unterminatedString(position)
        }

        index = input.index(after: index) // Skip closing quote

        let lexeme = String(input[start..<index])
        let content = String(lexeme.dropFirst().dropLast()) // Remove quotes

        // Process escape sequences in the content for token type determination
        do {
            let processedContent = try StringEscapeUtilities.processEscapeSequences(content)
            let tokenType = TokenizerUtilities.stringLiteralTokenType(content: processedContent)
            return TokenData(type: tokenType, lexeme: lexeme)
        } catch let error as StringEscapeUtilities.EscapeSequenceError {
            throw TokenizerError.invalidEscapeSequenceWithMessage(error.message, position)
        }
    }

    private func parseIdentifier(from input: String, at index: inout String.Index) -> TokenData? {
        guard index < input.endIndex && TokenizerUtilities.isIdentifierStart(input[index]) else { return nil }

        let start = index
        index = input.index(after: index)

        // Read remaining identifier characters
        while index < input.endIndex && TokenizerUtilities.isIdentifierContinue(input[index]) {
            index = input.index(after: index)
        }

        let lexeme = String(input[start..<index])
        return TokenData(type: .identifier, lexeme: lexeme)
    }

    // MARK: - Helper Methods

    private func sourcePosition(from input: String, startIndex: String.Index, currentIndex: String.Index) -> SourcePosition {
        return TokenizerUtilities.sourcePosition(from: input, startIndex: startIndex, currentIndex: currentIndex)
    }
}

// MARK: - Helper Types

private struct TokenData {
    let type: TokenType
    let lexeme: String
}

// MARK: - Public Interface

extension ParsingTokenizer {
    /// Tokenizes the given input string.
    /// - Parameter input: The source code to tokenize
    /// - Returns: An array of tokens
    /// - Throws: TokenizerError if tokenization fails
    public static func tokenize(_ input: String) throws -> [Token] {
        return try ParsingTokenizer().tokenize(input)
    }
}
