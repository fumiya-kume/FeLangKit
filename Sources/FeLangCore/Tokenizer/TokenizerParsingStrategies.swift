import Foundation

/// Shared parsing strategies for tokenizer implementations to eliminate code duplication
/// and ensure consistent behavior across different tokenizer types.
public enum TokenizerParsingStrategies {

    // MARK: - Shared Data Types

    /// Internal data structure for token information
    public struct TokenData {
        public let type: TokenType
        public let lexeme: String

        public init(type: TokenType, lexeme: String) {
            self.type = type
            self.lexeme = lexeme
        }
    }

    // MARK: - Keyword Parsing

    /// Parses keywords and identifiers with efficient O(1) keyword lookup
    /// This method first extracts a complete identifier, then checks if it's a keyword
    public static func parseKeywordOrIdentifier(from input: String, at index: inout String.Index) -> TokenData? {
        guard index < input.endIndex && TokenizerUtilities.isIdentifierStart(input[index]) else {
            return nil
        }

        let start = index
        index = input.index(after: index)

        while index < input.endIndex && TokenizerUtilities.isIdentifierContinue(input[index]) {
            index = input.index(after: index)
        }

        let lexeme = String(input[start..<index])

        // Check if it's a keyword using O(1) lookup
        if let tokenType = TokenizerUtilities.keywordMap[lexeme] {
            return TokenData(type: tokenType, lexeme: lexeme)
        }

        // Otherwise it's an identifier
        return TokenData(type: .identifier, lexeme: lexeme)
    }

    /// Parses only keywords (not identifiers) with backtracking
    /// Used when tokenizers need to specifically differentiate keywords from identifiers
    public static func parseKeywordOnly(from input: String, at index: inout String.Index) -> TokenData? {
        guard index < input.endIndex && TokenizerUtilities.isIdentifierStart(input[index]) else {
            return nil
        }

        let start = index
        index = input.index(after: index)

        while index < input.endIndex && TokenizerUtilities.isIdentifierContinue(input[index]) {
            index = input.index(after: index)
        }

        let lexeme = String(input[start..<index])

        if let tokenType = TokenizerUtilities.keywordMap[lexeme] {
            return TokenData(type: tokenType, lexeme: lexeme)
        }

        // Reset index if not a keyword
        index = start
        return nil
    }

    /// Parses only identifiers (not keywords)
    /// Used by tokenizers that handle keywords and identifiers separately
    public static func parseIdentifierOnly(from input: String, at index: inout String.Index) -> TokenData? {
        guard index < input.endIndex && TokenizerUtilities.isIdentifierStart(input[index]) else {
            return nil
        }

        let start = index
        index = input.index(after: index)

        while index < input.endIndex && TokenizerUtilities.isIdentifierContinue(input[index]) {
            index = input.index(after: index)
        }

        let lexeme = String(input[start..<index])
        return TokenData(type: .identifier, lexeme: lexeme)
    }

    // MARK: - Operator Parsing

    /// Parses operators using longest-match strategy
    /// Checks operators in order of length (longest first) to ensure proper matching
    public static func parseOperator(from input: String, at index: inout String.Index) -> TokenData? {
        for (operatorString, tokenType) in TokenizerUtilities.operators {
            if TokenizerUtilities.matchString(operatorString, in: input, at: index) {
                index = input.index(index, offsetBy: operatorString.count)
                return TokenData(type: tokenType, lexeme: operatorString)
            }
        }
        return nil
    }

    // MARK: - Delimiter Parsing

    /// Parses delimiters (parentheses, brackets, punctuation)
    /// Uses the same longest-match strategy as operators
    public static func parseDelimiter(from input: String, at index: inout String.Index) -> TokenData? {
        for (delimiter, tokenType) in TokenizerUtilities.delimiters {
            if TokenizerUtilities.matchString(delimiter, in: input, at: index) {
                index = input.index(index, offsetBy: delimiter.count)
                return TokenData(type: tokenType, lexeme: delimiter)
            }
        }
        return nil
    }

    // MARK: - Basic Number Parsing

    /// Parses basic decimal numbers with support for leading decimal points
    /// This is the core number parsing logic used by most tokenizers
    public static func parseBasicNumber(from input: String, at index: inout String.Index) -> TokenData? {
        let start = index

        // Check for leading dot decimal (e.g., .5, .25)
        if index < input.endIndex && input[index] == "." {
            let nextIndex = input.index(after: index)
            if nextIndex < input.endIndex && input[nextIndex].isNumber {
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

        // Must start with digit for regular numbers
        guard index < input.endIndex && input[index].isNumber else {
            return nil
        }

        var hasDecimal = false

        // Read integer part
        while index < input.endIndex && input[index].isNumber {
            index = input.index(after: index)
        }

        // Check for decimal point
        if index < input.endIndex && input[index] == "." {
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

    // MARK: - String Parsing

    /// Parses string literals with basic escape sequence support
    /// Returns nil if the string is unterminated or invalid
    public static func parseBasicString(from input: String, at index: inout String.Index) -> TokenData? {
        guard index < input.endIndex else { return nil }

        let quoteChar = input[index]
        guard quoteChar == "\"" || quoteChar == "'" else { return nil }

        let start = index
        index = input.index(after: index) // Skip opening quote

        var content = ""
        var foundClosing = false

        while index < input.endIndex {
            let char = input[index]

            if char == quoteChar {
                foundClosing = true
                index = input.index(after: index) // Skip closing quote
                break
            } else if char == "\n" {
                // Unterminated string at newline
                break
            } else if char == "\\" {
                // Handle basic escape sequences
                let nextIndex = input.index(after: index)
                if nextIndex < input.endIndex {
                    let nextChar = input[nextIndex]
                    switch nextChar {
                    case "n":
                        content.append("\n")
                        index = input.index(after: nextIndex)
                    case "t":
                        content.append("\t")
                        index = input.index(after: nextIndex)
                    case "r":
                        content.append("\r")
                        index = input.index(after: nextIndex)
                    case "\\":
                        content.append("\\")
                        index = input.index(after: nextIndex)
                    case "\"":
                        content.append("\"")
                        index = input.index(after: nextIndex)
                    case "'":
                        content.append("'")
                        index = input.index(after: nextIndex)
                    default:
                        content.append(nextChar)
                        index = input.index(after: nextIndex)
                    }
                } else {
                    index = nextIndex
                }
            } else {
                content.append(char)
                index = input.index(after: index)
            }
        }

        // Return nil if unterminated (let caller handle the error)
        guard foundClosing else { return nil }

        let lexeme = String(input[start..<index])
        let tokenType = TokenizerUtilities.stringLiteralTokenType(content: content)
        return TokenData(type: tokenType, lexeme: lexeme)
    }

    // MARK: - Comment Parsing

    /// Parses comments (single-line // and multi-line /* */)
    /// Returns nil if no comment is found, skips over complete comments
    public static func parseComment(from input: String, at index: inout String.Index) -> TokenData? {
        guard index < input.endIndex && input[index] == "/" else { return nil }

        let nextIndex = input.index(after: index)
        guard nextIndex < input.endIndex else { return nil }

        let nextChar = input[nextIndex]

        if nextChar == "/" {
            // Single-line comment
            let start = index
            index = nextIndex
            index = input.index(after: index)

            while index < input.endIndex && input[index] != "\n" {
                index = input.index(after: index)
            }

            let lexeme = String(input[start..<index])
            return TokenData(type: .comment, lexeme: lexeme)

        } else if nextChar == "*" {
            // Multi-line comment
            let start = index
            index = nextIndex
            index = input.index(after: index)

            while index < input.endIndex {
                if input[index] == "*" {
                    let nextIndex = input.index(after: index)
                    if nextIndex < input.endIndex && input[nextIndex] == "/" {
                        index = input.index(after: nextIndex)
                        break
                    }
                }
                index = input.index(after: index)
            }

            let lexeme = String(input[start..<index])
            return TokenData(type: .comment, lexeme: lexeme)
        }

        return nil
    }

    // MARK: - Validation Utilities

    /// Validates that a parsed token maintains proper word boundaries
    /// Ensures keywords aren't part of larger identifiers
    public static func isValidTokenBoundary(in input: String, at endIndex: String.Index) -> Bool {
        return endIndex == input.endIndex || !TokenizerUtilities.isIdentifierContinue(input[endIndex])
    }

    /// Checks if the current position is at a valid token start
    public static func canStartToken(at char: Character) -> Bool {
        return TokenizerUtilities.isIdentifierStart(char) ||
               char.isNumber ||
               char == "." ||
               char == "\"" ||
               char == "'" ||
               char == "/" ||
               isOperatorOrDelimiterChar(char)
    }

    /// Checks if a character can be part of an operator or delimiter
    private static func isOperatorOrDelimiterChar(_ char: Character) -> Bool {
        let operatorChars: Set<Character> = ["←", "≠", "≧", "≦", "+", "-", "*", "/", "%", "=", ">", "<"]
        let delimiterChars: Set<Character> = ["(", ")", "[", "]", "{", "}", ",", ".", ";", ":"]
        return operatorChars.contains(char) || delimiterChars.contains(char)
    }
}
