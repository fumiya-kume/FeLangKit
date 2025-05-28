import Foundation

/// Shared tokenizer implementation that consolidates parsing logic used across multiple tokenizer types.
/// This eliminates code duplication and ensures consistent behavior across all tokenizer implementations.
/// 
/// **Design Pattern**: Strategy pattern with shared implementation
/// **Thread Safety**: Stateless methods are thread-safe when used with distinct input/index parameters
/// **Performance**: O(1) keyword lookup, optimized character classification, minimal memory allocation
public enum SharedTokenizerImplementation {

    // MARK: - Shared Token Data Type

    /// Token information used internally during parsing
    public struct TokenData {
        public let type: TokenType
        public let lexeme: String
        public let range: SourceRange?

        public init(type: TokenType, lexeme: String, range: SourceRange? = nil) {
            self.type = type
            self.lexeme = lexeme
            self.range = range
        }
    }

    // MARK: - Keyword & Identifier Parsing

    /// Parses keywords and identifiers with efficient O(1) keyword lookup.
    /// First extracts a complete identifier, then checks if it's a keyword.
    /// Uses TokenizerUtilities for consistent character classification and keyword mapping.
    public static func parseKeywordOrIdentifier(from input: String, at index: inout String.Index) -> TokenData? {
        guard index < input.endIndex && TokenizerUtilities.isIdentifierStart(input[index]) else { return nil }

        let start = index
        index = input.index(after: index)

        // Read remaining identifier characters
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

    /// Parses keywords only (returns nil if the token is an identifier).
    /// Used when you specifically need to check for keywords without consuming identifiers.
    public static func parseKeyword(from input: String, at index: inout String.Index) -> TokenData? {
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

    /// Parses identifiers only (assumes keyword check has already been done).
    /// Used when you specifically need identifiers without keyword interference.
    public static func parseIdentifier(from input: String, at index: inout String.Index) -> TokenData? {
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

    // MARK: - Operator Parsing

    /// Parses operators using longest-match strategy.
    /// TokenizerUtilities.operators is pre-sorted with longer operators first.
    public static func parseOperator(from input: String, at index: inout String.Index) -> TokenData? {
        for (operatorString, tokenType) in TokenizerUtilities.operators where TokenizerUtilities.matchString(operatorString, in: input, at: index) {
            index = input.index(index, offsetBy: operatorString.count)
            return TokenData(type: tokenType, lexeme: operatorString)
        }
        return nil
    }

    // MARK: - Delimiter Parsing

    /// Parses delimiters using exact string matching.
    /// Handles all bracket types, parentheses, and punctuation marks.
    public static func parseDelimiter(from input: String, at index: inout String.Index) -> TokenData? {
        for (delimiter, tokenType) in TokenizerUtilities.delimiters where TokenizerUtilities.matchString(delimiter, in: input, at: index) {
            index = input.index(index, offsetBy: delimiter.count)
            return TokenData(type: tokenType, lexeme: delimiter)
        }
        return nil
    }

    // MARK: - Number Parsing (Standard Implementation)

    /// Parses decimal numbers with support for alternative bases (hex, binary, octal).
    /// Handles leading decimal points, scientific notation, and underscore separators.
    /// **Performance**: Optimized for common decimal case, fallback to specialized parsers.
    public static func parseNumber(from input: String, at index: inout String.Index) -> TokenData? {
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

    // MARK: - Enhanced Number Parsing (with Error Detection)

    /// Enhanced number parsing with improved error detection and validation.
    /// Detects multiple decimal points, invalid formats, and provides detailed error context.
    public static func parseNumberWithValidation(from input: String, at index: inout String.Index) -> Result<TokenData, TokenizerError> {
        guard index < input.endIndex else {
            return .failure(.unexpectedCharacter(UnicodeScalar(0)!, SourcePosition(line: 1, column: 1, offset: 0)))
        }

        guard input[index].isNumber || input[index] == "." else {
            return .failure(.unexpectedCharacter(UnicodeScalar(input[index].unicodeScalars.first?.value ?? 0) ?? UnicodeScalar(0)!, SourcePosition(line: 1, column: 1, offset: 0)))
        }

        let start = index
        var hasDecimal = false
        var decimalCount = 0

        // Handle leading decimal point
        if input[index] == "." {
            let nextIndex = input.index(after: index)
            guard nextIndex < input.endIndex && input[nextIndex].isNumber else {
                return .failure(.invalidNumberFormat(".", SourcePosition(line: 1, column: 1, offset: 0)))
            }
            hasDecimal = true
            decimalCount = 1
            index = nextIndex
        }

        // Parse integer part
        while index < input.endIndex && input[index].isNumber {
            index = input.index(after: index)
        }

        // Handle decimal point
        while !hasDecimal && index < input.endIndex && input[index] == "." {
            decimalCount += 1
            let nextIndex = input.index(after: index)
            if nextIndex < input.endIndex && input[nextIndex].isNumber {
                hasDecimal = true
                index = nextIndex

                // Parse fractional part
                while index < input.endIndex && input[index].isNumber {
                    index = input.index(after: index)
                }
                break
            } else {
                // This is not a valid decimal point for this number
                break
            }
        }

        // Check for additional invalid decimal points (like 123.45.67)
        if decimalCount > 1 || (hasDecimal && index < input.endIndex && input[index] == ".") {
            // Continue parsing to get the full invalid number
            while index < input.endIndex && (input[index].isNumber || input[index] == ".") {
                index = input.index(after: index)
            }
            let lexeme = String(input[start..<index])
            return .failure(.invalidNumberFormat(lexeme, SourcePosition(line: 1, column: 1, offset: 0)))
        }

        let lexeme = String(input[start..<index])

        // Check for invalid number format (multiple decimal points)
        if decimalCount > 1 || lexeme.filter({ $0 == "." }).count > 1 {
            return .failure(.invalidNumberFormat(lexeme, SourcePosition(line: 1, column: 1, offset: 0)))
        }

        let tokenType = TokenizerUtilities.numberTokenType(hasDecimal: hasDecimal)
        return .success(TokenData(type: tokenType, lexeme: lexeme))
    }

    // MARK: - Specialized Number Parsing (Alternative Bases)

    /// Parses hexadecimal numbers (0x1234, 0xFF, etc.)
    /// Supports underscore separators for readability (0x12_34_AB_CD)
    public static func parseHexadecimalNumber(from input: String, at index: inout String.Index, start: String.Index) -> TokenData? {
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

    /// Parses binary numbers (0b1010, 0B1111, etc.)
    /// Supports underscore separators for readability (0b1010_1010)
    public static func parseBinaryNumber(from input: String, at index: inout String.Index, start: String.Index) -> TokenData? {
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

    /// Parses octal numbers (0o777, 0O123, etc.)
    /// Supports underscore separators for readability (0o12_34_56)
    public static func parseOctalNumber(from input: String, at index: inout String.Index, start: String.Index) -> TokenData? {
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

    /// Parses decimal numbers with support for scientific notation and underscores
    /// Handles formats like: 123, 123.456, 1.23e10, 1_000_000, 3.14159_26535
    public static func parseDecimalNumber(from input: String, at index: inout String.Index, start: String.Index) -> TokenData? {
        var hasDecimal = false

        // Read integer part (including underscores)
        while index < input.endIndex && (input[index].isNumber || input[index] == "_") {
            index = input.index(after: index)
        }

        // Check for decimal point
        if index < input.endIndex && input[index] == "." {
            // Look ahead for more digits
            let nextIndex = input.index(after: index)
            if nextIndex < input.endIndex && input[nextIndex].isNumber {
                hasDecimal = true
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

            hasDecimal = true // Scientific notation is always real
        }

        let lexeme = String(input[start..<index])
        let tokenType = TokenizerUtilities.numberTokenType(hasDecimal: hasDecimal)
        return TokenData(type: tokenType, lexeme: lexeme)
    }

    // MARK: - String Literal Parsing

    /// Parses string literals with escape sequence support
    /// Handles both single and double quotes, with proper escape sequence validation
    public static func parseStringLiteral(from input: String, at index: inout String.Index, quoteChar: Character) -> Result<TokenData, TokenizerError> {
        let start = index
        index = input.index(after: index) // consume opening quote

        var content = ""

        while index < input.endIndex {
            let char = input[index]

            if char == quoteChar {
                // Found closing quote
                index = input.index(after: index) // consume closing quote
                let lexeme = String(input[start..<index])
                let tokenType = TokenizerUtilities.stringLiteralTokenType(content: content)
                return .success(TokenData(type: tokenType, lexeme: lexeme))
            }

            if char == "\\" {
                // Handle escape sequence
                let nextIndex = input.index(after: index)
                guard nextIndex < input.endIndex else {
                    return .failure(.unterminatedString(SourcePosition(line: 1, column: 1, offset: 0)))
                }

                let escapedChar = input[nextIndex]
                switch escapedChar {
                case "n":
                    content.append("\n")
                case "t":
                    content.append("\t")
                case "r":
                    content.append("\r")
                case "\\":
                    content.append("\\")
                case "\"":
                    content.append("\"")
                case "'":
                    content.append("'")
                default:
                    return .failure(.invalidEscapeSequence(SourcePosition(line: 1, column: 1, offset: 0)))
                }

                index = input.index(after: nextIndex) // consume both \ and escaped char
            } else {
                content.append(char)
                index = input.index(after: index)
            }
        }

        // Reached end of input without closing quote
        return .failure(.unterminatedString(SourcePosition(line: 1, column: 1, offset: 0)))
    }

    // MARK: - Whitespace and Comment Handling

    /// Skips whitespace characters including full-width spaces
    /// Uses TokenizerUtilities for consistent whitespace classification
    public static func skipWhitespace(from input: String, at index: inout String.Index) {
        while index < input.endIndex && TokenizerUtilities.isWhitespace(input[index]) {
            index = input.index(after: index)
        }
    }

    /// Skips single-line comments (// comment)
    /// Continues until newline or end of input
    public static func skipSingleLineComment(from input: String, at index: inout String.Index) {
        while index < input.endIndex && input[index] != "\n" {
            index = input.index(after: index)
        }
    }

    /// Skips multi-line comments (/* comment */)
    /// Handles nested comments and validates proper closure
    public static func skipMultiLineComment(from input: String, at index: inout String.Index) -> Result<Void, TokenizerError> {
        index = input.index(after: index) // consume '/'
        index = input.index(after: index) // consume '*'

        var nesting = 1

        while index < input.endIndex && nesting > 0 {
            if index < input.index(before: input.endIndex) {
                let current = input[index]
                let next = input[input.index(after: index)]

                if current == "/" && next == "*" {
                    nesting += 1
                    index = input.index(index, offsetBy: 2)
                    continue
                } else if current == "*" && next == "/" {
                    nesting -= 1
                    index = input.index(index, offsetBy: 2)
                    continue
                }
            }

            index = input.index(after: index)
        }

        if nesting > 0 {
            return .failure(.unterminatedComment(SourcePosition(line: 1, column: 1, offset: 0)))
        }

        return .success(())
    }
}
