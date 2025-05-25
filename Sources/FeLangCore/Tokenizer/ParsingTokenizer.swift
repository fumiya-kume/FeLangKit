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
        // First, extract the potential identifier/keyword
        guard index < input.endIndex && TokenizerUtilities.isIdentifierStart(input[index]) else { return nil }

        let start = index
        index = input.index(after: index)

        // Read remaining identifier characters
        while index < input.endIndex && TokenizerUtilities.isIdentifierContinue(input[index]) {
            index = input.index(after: index)
        }

        let lexeme = String(input[start..<index])

        // Use O(1) lookup to check if it's a keyword
        if let tokenType = TokenizerUtilities.keywordMap[lexeme] {
            return TokenData(type: tokenType, lexeme: lexeme)
        }

        // Not a keyword, reset index and return nil so parseIdentifier can handle it
        index = start
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

        // Check for leading dot decimal (e.g., .5, .25)
        if index < input.endIndex && input[index] == "." {
            let nextIndex = input.index(after: index)
            if nextIndex < input.endIndex && input[nextIndex].isNumber {
                index = nextIndex

                // Read fractional part (including underscores)
                while index < input.endIndex && (input[index].isNumber || input[index] == "_") {
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

        // Check for alternative number bases (0x, 0b, 0o)
        if input[index] == "0" {
            let nextIndex = input.index(after: index)
            if nextIndex < input.endIndex {
                let nextChar = input[nextIndex]
                if nextChar == "x" || nextChar == "X" {
                    return parseHexadecimalNumber(from: input, at: &index, start: start)
                } else if nextChar == "b" || nextChar == "B" {
                    return parseBinaryNumber(from: input, at: &index, start: start)
                } else if nextChar == "o" || nextChar == "O" {
                    return parseOctalNumber(from: input, at: &index, start: start)
                }
            }
        }

        // Parse regular decimal number (including scientific notation and underscores)
        return parseDecimalNumber(from: input, at: &index, start: start)
    }

    private func parseHexadecimalNumber(from input: String, at index: inout String.Index, start: String.Index) -> TokenData? {
        index = input.index(after: index) // consume '0'
        index = input.index(after: index) // consume 'x' or 'X'

        // Must have at least one hex digit
        guard index < input.endIndex,
              let firstScalar = String(input[index]).unicodeScalars.first,
              TokenizerUtilities.isHexDigit(firstScalar) || input[index] == "_" else {
            return nil
        }

        // Read hex digits and underscores
        while index < input.endIndex {
            if let scalar = String(input[index]).unicodeScalars.first,
               TokenizerUtilities.isHexDigit(scalar) || input[index] == "_" {
                index = input.index(after: index)
            } else {
                break
            }
        }

        let lexeme = String(input[start..<index])
        return TokenData(type: .integerLiteral, lexeme: lexeme)
    }

    private func parseBinaryNumber(from input: String, at index: inout String.Index, start: String.Index) -> TokenData? {
        index = input.index(after: index) // consume '0'
        index = input.index(after: index) // consume 'b' or 'B'

        // Must have at least one binary digit
        guard index < input.endIndex,
              let firstScalar = String(input[index]).unicodeScalars.first,
              TokenizerUtilities.isBinaryDigit(firstScalar) || input[index] == "_" else {
            return nil
        }

        // Read binary digits and underscores
        while index < input.endIndex {
            if let scalar = String(input[index]).unicodeScalars.first,
               TokenizerUtilities.isBinaryDigit(scalar) || input[index] == "_" {
                index = input.index(after: index)
            } else {
                break
            }
        }

        let lexeme = String(input[start..<index])
        return TokenData(type: .integerLiteral, lexeme: lexeme)
    }

    private func parseOctalNumber(from input: String, at index: inout String.Index, start: String.Index) -> TokenData? {
        index = input.index(after: index) // consume '0'
        index = input.index(after: index) // consume 'o' or 'O'

        // Must have at least one octal digit
        guard index < input.endIndex,
              let firstScalar = String(input[index]).unicodeScalars.first,
              TokenizerUtilities.isOctalDigit(firstScalar) || input[index] == "_" else {
            return nil
        }

        // Read octal digits and underscores
        while index < input.endIndex {
            if let scalar = String(input[index]).unicodeScalars.first,
               TokenizerUtilities.isOctalDigit(scalar) || input[index] == "_" {
                index = input.index(after: index)
            } else {
                break
            }
        }

        let lexeme = String(input[start..<index])
        return TokenData(type: .integerLiteral, lexeme: lexeme)
    }

    private func parseDecimalNumber(from input: String, at index: inout String.Index, start: String.Index) -> TokenData? {
        // Read integer part (including underscores)
        while index < input.endIndex && (input[index].isNumber || input[index] == "_") {
            index = input.index(after: index)
        }

        // Check for decimal point
        if index < input.endIndex && input[index] == "." {
            // Look ahead for more digits
            let nextIndex = input.index(after: index)
            if nextIndex < input.endIndex && input[nextIndex].isNumber {
                index = nextIndex

                // Read fractional part (including underscores)
                while index < input.endIndex && (input[index].isNumber || input[index] == "_") {
                    index = input.index(after: index)
                }
            }
        }

        // Check for scientific notation
        if index < input.endIndex && (input[index] == "e" || input[index] == "E") {
            index = input.index(after: index) // consume 'e' or 'E'

            // Optional sign
            if index < input.endIndex && (input[index] == "+" || input[index] == "-") {
                index = input.index(after: index)
            }

            // Must have at least one digit in exponent
            guard index < input.endIndex && (input[index].isNumber || input[index] == "_") else {
                return nil // Invalid scientific notation
            }

            // Read exponent digits (including underscores)
            while index < input.endIndex && (input[index].isNumber || input[index] == "_") {
                index = input.index(after: index)
            }
        }

        let lexeme = String(input[start..<index])
        let tokenType = TokenizerUtilities.enhancedNumberTokenType(lexeme: lexeme)
        return TokenData(type: tokenType, lexeme: lexeme)
    }

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
