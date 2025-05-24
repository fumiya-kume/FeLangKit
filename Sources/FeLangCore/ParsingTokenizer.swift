import Foundation

/// A tokenizer for FE pseudo-language with a focus on simplicity and correctness.
/// This implementation prioritizes the same functionality as the original tokenizer
/// while being easier to extend and maintain.
public struct ParsingTokenizer {

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
            if let token = parseNextToken(from: input, at: &index) {
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

    private func parseNextToken(from input: String, at index: inout String.Index) -> TokenData? {
        // Try to parse comments first (skip them, don't return tokens)
        if parseComment(from: input, at: &index) != nil {
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
        if let token = parseString(from: input, at: &index) {
            return token
        }

        // Try to parse identifiers
        if let token = parseIdentifier(from: input, at: &index) {
            return token
        }

        return nil
    }

    // MARK: - Parsing Methods

    private func parseComment(from input: String, at index: inout String.Index) -> TokenData? {
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
            let start = index
            index = input.index(index, offsetBy: 2)

            // Read until */
            while index < input.endIndex {
                if TokenizerUtilities.matchString("*/", in: input, at: index) {
                    index = input.index(index, offsetBy: 2)
                    break
                }
                index = input.index(after: index)
            }

            let lexeme = String(input[start..<index])
            return TokenData(type: .comment, lexeme: lexeme)
        }

        return nil
    }

    private func parseKeyword(from input: String, at index: inout String.Index) -> TokenData? {
        for (keyword, tokenType) in TokenizerUtilities.keywords where TokenizerUtilities.matchString(keyword, in: input, at: index) {
            // Check if it's a complete word (not part of identifier)
            let endIndex = input.index(index, offsetBy: keyword.count)
            if TokenizerUtilities.isValidKeywordBoundary(in: input, at: endIndex) {
                index = endIndex
                return TokenData(type: tokenType, lexeme: keyword)
            }
        }

        return nil
    }

    private func parseOperator(from input: String, at index: inout String.Index) -> TokenData? {
        for (operatorString, tokenType) in TokenizerUtilities.operators where TokenizerUtilities.matchString(operatorString, in: input, at: index) {
            index = input.index(index, offsetBy: operatorString.count)
            return TokenData(type: tokenType, lexeme: operatorString)
        }

        return nil
    }

    private func parseDelimiter(from input: String, at index: inout String.Index) -> TokenData? {
        for (delimiter, tokenType) in TokenizerUtilities.delimiters where TokenizerUtilities.matchString(delimiter, in: input, at: index) {
            index = input.index(index, offsetBy: delimiter.count)
            return TokenData(type: tokenType, lexeme: delimiter)
        }

        return nil
    }

    private func parseNumber(from input: String, at index: inout String.Index) -> TokenData? {
        let start = index
        var hasDecimal = false

        // Check for leading dot decimal (e.g., .5, .25)
        if index < input.endIndex && input[index] == "." {
            let nextIndex = input.index(after: index)
            if nextIndex < input.endIndex && input[nextIndex].isNumber {
                hasDecimal = true
                index = nextIndex

                // Read fractional part
                while index < input.endIndex && input[index].isNumber {
                    index = input.index(after: index)
                }

                let lexeme = String(input[start..<index])
                return TokenData(type: .realLiteral, lexeme: lexeme)
            } else {
                return nil // Just a dot, not a number
            }
        }

        // Only parse positive numbers - minus will be handled as an operator
        // Must have at least one digit
        guard index < input.endIndex && input[index].isNumber else {
            return nil
        }

        // Read digits
        while index < input.endIndex && input[index].isNumber {
            index = input.index(after: index)
        }

        // Check for decimal point
        if index < input.endIndex && input[index] == "." {
            // Look ahead for more digits
            let nextIndex = input.index(after: index)
            if nextIndex < input.endIndex && input[nextIndex].isNumber {
                hasDecimal = true
                index = nextIndex

                // Read fractional part
                while index < input.endIndex && input[index].isNumber {
                    index = input.index(after: index)
                }
            }
        }

        let lexeme = String(input[start..<index])
        let tokenType = TokenizerUtilities.numberTokenType(hasDecimal: hasDecimal)
        return TokenData(type: tokenType, lexeme: lexeme)
    }

    private func parseString(from input: String, at index: inout String.Index) -> TokenData? {
        guard index < input.endIndex && input[index] == "'" else { return nil }

        let start = index
        index = input.index(after: index) // Skip opening quote

        // Read until closing quote
        while index < input.endIndex && input[index] != "'" {
            index = input.index(after: index)
        }

        // Must have closing quote
        guard index < input.endIndex else {
            index = start
            return nil
        }

        index = input.index(after: index) // Skip closing quote

        let lexeme = String(input[start..<index])
        let content = String(lexeme.dropFirst().dropLast()) // Remove quotes
        let tokenType = TokenizerUtilities.stringLiteralTokenType(content: content)

        return TokenData(type: tokenType, lexeme: lexeme)
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
