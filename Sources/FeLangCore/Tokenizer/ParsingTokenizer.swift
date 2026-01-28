import Foundation

/// A tokenizer for FE pseudo-language with a focus on simplicity and correctness.
/// This implementation prioritizes the same functionality as the original tokenizer
/// while being easier to extend and maintain.
public struct ParsingTokenizer: Sendable {

    public init() {}

    public func tokenize(_ input: String) throws -> [Token] {
        var tokens: [Token] = []
        var index = input.startIndex
        var tracker = TokenizerUtilities.PositionTracker()

        while index < input.endIndex {
            if input[index].isWhitespace {
                tracker.advance(past: input[index])
                index = input.index(after: index)
                continue
            }

            try processNextToken(from: input, at: &index, tracker: &tracker, tokens: &tokens)
        }

        tokens.append(Token(type: .eof, lexeme: "", position: tracker.currentPosition))
        return tokens
    }

    private func processNextToken(
        from input: String, at index: inout String.Index,
        tracker: inout TokenizerUtilities.PositionTracker, tokens: inout [Token]
    ) throws {
        let position = tracker.currentPosition
        let beforeIndex = index

        if let token = try parseNextToken(from: input, at: &index, startIndex: input.startIndex) {
            tracker.advance(through: input[beforeIndex..<index])
            tokens.append(Token(type: token.type, lexeme: token.lexeme, position: position))
            return
        }

        if index > beforeIndex {
            tracker.advance(through: input[beforeIndex..<index])
            return
        }

        guard let scalar = input[index].unicodeScalars.first else {
            tracker.advance(past: input[index])
            index = input.index(after: index)
            return
        }
        throw TokenizerError.unexpectedCharacter(scalar, position)
    }

    private func parseNextToken(from input: String, at index: inout String.Index, startIndex: String.Index) throws -> TokenizerCore.TokenData? {
        // Try to parse comments first (skip them, don't return tokens)
        if try parseComment(from: input, at: &index, startIndex: startIndex) != nil {
            return nil // Comments are skipped
        }

        // Try to parse keywords
        if let token = TokenizerCore.parseKeyword(from: input, at: &index) {
            return token
        }

        // Try to parse operators
        if let token = TokenizerCore.parseOperator(from: input, at: &index) {
            return token
        }

        // Try to parse numbers (including leading-dot decimals) before delimiters
        if let token = TokenizerCore.parseNumber(from: input, at: &index) {
            return token
        }

        // Try to parse delimiters
        if let token = TokenizerCore.parseDelimiter(from: input, at: &index) {
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

    private func parseComment(from input: String, at index: inout String.Index, startIndex: String.Index) throws -> TokenizerCore.TokenData? {
        guard index < input.endIndex else { return nil }

        if TokenizerUtilities.matchString("//", in: input, at: index) {
            return parseSingleLineComment(from: input, at: &index)
        }

        if TokenizerUtilities.matchString("/*", in: input, at: index) {
            return try parseMultiLineComment(from: input, at: &index, startIndex: startIndex)
        }

        return nil
    }

    private func parseSingleLineComment(from input: String, at index: inout String.Index) -> TokenizerCore.TokenData {
        let start = index
        index = input.index(index, offsetBy: 2)
        while index < input.endIndex && input[index] != "\n" {
            index = input.index(after: index)
        }
        return TokenizerCore.TokenData(type: .comment, lexeme: String(input[start..<index]))
    }

    private func parseMultiLineComment(from input: String, at index: inout String.Index, startIndex: String.Index) throws -> TokenizerCore.TokenData {
        let commentStart = index
        let position = TokenizerUtilities.sourcePosition(from: input, startIndex: startIndex, currentIndex: index)
        index = input.index(index, offsetBy: 2)

        var foundTerminator = false
        while index < input.endIndex {
            if TokenizerUtilities.matchString("*/", in: input, at: index) {
                index = input.index(index, offsetBy: 2)
                foundTerminator = true
                break
            }
            index = input.index(after: index)
        }

        if !foundTerminator {
            throw TokenizerError.unterminatedComment(position)
        }
        return TokenizerCore.TokenData(type: .comment, lexeme: String(input[commentStart..<index]))
    }

    private func parseString(from input: String, at index: inout String.Index, startIndex: String.Index) throws -> TokenizerCore.TokenData? {
        guard index < input.endIndex else { return nil }

        let quoteChar = input[index]
        guard quoteChar == "'" || quoteChar == "\"" else { return nil }

        let start = index
        let position = TokenizerUtilities.sourcePosition(from: input, startIndex: startIndex, currentIndex: index)
        index = input.index(after: index)

        while index < input.endIndex && input[index] != quoteChar {
            if input[index] == "\\" {
                try consumeEscapeSequence(from: input, at: &index, position: position)
            } else {
                index = input.index(after: index)
            }
        }

        guard index < input.endIndex else {
            throw TokenizerError.unterminatedString(position)
        }
        index = input.index(after: index)

        return try buildStringTokenData(from: input, start: start, end: index, position: position)
    }

    private func consumeEscapeSequence(from input: String, at index: inout String.Index, position: SourcePosition) throws {
        index = input.index(after: index) // consume backslash

        guard index < input.endIndex else {
            throw TokenizerError.invalidEscapeSequenceWithMessage("Incomplete escape sequence at end of string", position)
        }

        let escapedChar = input[index]
        index = input.index(after: index) // consume escaped character

        if escapedChar == "u" {
            try consumeUnicodeEscape(from: input, at: &index, position: position)
        } else {
            guard "ntr\\'\"".contains(escapedChar) else {
                throw TokenizerError.invalidEscapeSequenceWithMessage("Unknown escape sequence \\(escapedChar)", position)
            }
        }
    }

    private func consumeUnicodeEscape(from input: String, at index: inout String.Index, position: SourcePosition) throws {
        guard index < input.endIndex && input[index] == "{" else {
            throw TokenizerError.invalidUnicodeEscape("Expected '{' after \\u", position)
        }
        index = input.index(after: index)

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
        index = input.index(after: index)
    }

    private func buildStringTokenData(from input: String, start: String.Index, end: String.Index, position: SourcePosition) throws -> TokenizerCore.TokenData {
        let lexeme = String(input[start..<end])
        let content = String(lexeme.dropFirst().dropLast())

        do {
            let processedContent = try StringEscapeUtilities.processEscapeSequences(content)
            let tokenType = TokenizerUtilities.stringLiteralTokenType(content: processedContent)
            return TokenizerCore.TokenData(type: tokenType, lexeme: lexeme)
        } catch let error as StringEscapeUtilities.EscapeSequenceError {
            throw TokenizerError.invalidEscapeSequenceWithMessage(error.message, position)
        }
    }

    private func parseIdentifier(from input: String, at index: inout String.Index) -> TokenizerCore.TokenData? {
        guard index < input.endIndex && TokenizerUtilities.isIdentifierStart(input[index]) else { return nil }

        let start = index
        index = input.index(after: index)

        // Read remaining identifier characters
        while index < input.endIndex && TokenizerUtilities.isIdentifierContinue(input[index]) {
            index = input.index(after: index)
        }

        let lexeme = String(input[start..<index])
        return TokenizerCore.TokenData(type: .identifier, lexeme: lexeme)
    }

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
