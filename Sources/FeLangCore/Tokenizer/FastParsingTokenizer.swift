import Foundation

/// High-performance tokenizer optimized for speed
/// Implements Phase 2 optimizations from Issue #26 performance plan
/// Uses hybrid approach: UTF-8 byte processing for ASCII, String operations for Unicode
public struct FastParsingTokenizer {

    // MARK: - Static Lookup Tables

    /// Lookup table for single-byte ASCII operators/delimiters.
    /// Maps byte values to (TokenType, lexeme) pairs for O(1) lookup.
    ///
    /// This table is the first tier of a two-tier operator lookup strategy:
    /// 1. **Tier 1 (this table)**: Fast O(1) lookup for single-character ASCII operators
    /// 2. **Tier 2 (`TokenizerUtilities.operators`)**: Fallback for multi-character
    ///    operators (e.g., `<=`, `>=`, `==`) and Unicode operators (e.g., `←`, `≤`)
    ///
    /// The tokenizer first checks this table for common single-byte operators,
    /// then falls back to `parseUnicodeOperatorFast` for anything not found here.
    private static let asciiOperatorTable: [UInt8: (TokenType, String)] = [
        40: (.leftParen, "("),      // '('
        41: (.rightParen, ")"),     // ')'
        91: (.leftBracket, "["),    // '['
        93: (.rightBracket, "]"),   // ']'
        123: (.leftBrace, "{"),     // '{'
        125: (.rightBrace, "}"),    // '}'
        44: (.comma, ","),          // ','
        46: (.dot, "."),            // '.'
        59: (.semicolon, ";"),      // ';'
        58: (.colon, ":"),          // ':'
        43: (.plus, "+"),           // '+'
        45: (.minus, "-"),          // '-'
        42: (.multiply, "*"),       // '*'
        47: (.divide, "/"),         // '/'
        37: (.modulo, "%"),         // '%'
        61: (.equal, "="),          // '='
        62: (.greater, ">"),        // '>'
        60: (.less, "<")            // '<'
    ]

    public init() {}

    public func tokenize(_ input: String) throws -> [Token] {
        // Use UTF-8 view for efficient processing
        let utf8 = input.utf8
        let utf8Array = Array(utf8)

        var tokens: [Token] = []
        tokens.reserveCapacity(utf8Array.count / 8) // Estimate token count

        var bytePosition = 0
        var stringIndex = input.startIndex
        let startIndex = stringIndex

        while bytePosition < utf8Array.count {
            // Skip whitespace efficiently
            if isWhitespace(utf8Array[bytePosition]) {
                bytePosition += 1
                stringIndex = input.index(after: stringIndex)
                continue
            }

            let position = sourcePosition(from: input, startIndex: startIndex, currentIndex: stringIndex)
            let beforePosition = bytePosition
            _ = stringIndex

            if let token = try parseNextTokenFast(from: input, utf8: utf8Array, bytePosition: &bytePosition, stringIndex: &stringIndex, startIndex: startIndex) {
                let tokenWithPosition = Token(
                    type: token.type,
                    lexeme: token.lexeme,
                    position: position
                )
                tokens.append(tokenWithPosition)
            } else {
                // Check if position moved (comment was skipped)
                if bytePosition > beforePosition {
                    continue
                }

                // Unexpected character
                guard let scalar = String(input[stringIndex]).unicodeScalars.first else {
                    bytePosition += 1
                    stringIndex = input.index(after: stringIndex)
                    continue
                }
                throw TokenizerError.unexpectedCharacter(scalar, position)
            }

            // Safety check to prevent infinite loops
            if bytePosition == beforePosition {
                bytePosition += 1
                if stringIndex < input.endIndex {
                    stringIndex = input.index(after: stringIndex)
                }
            }
        }

        // Add EOF token
        let finalPosition = sourcePosition(from: input, startIndex: startIndex, currentIndex: stringIndex)
        tokens.append(Token(type: .eof, lexeme: "", position: finalPosition))

        return tokens
    }

    // MARK: - Fast Parsing Methods

    private func parseNextTokenFast(from input: String, utf8: [UInt8], bytePosition: inout Int, stringIndex: inout String.Index, startIndex: String.Index) throws -> TokenData? {
        // Try comments first
        if try parseCommentFast(from: input, utf8: utf8, bytePosition: &bytePosition, stringIndex: &stringIndex, startIndex: startIndex) != nil {
            return nil // Comments are skipped
        }

        // Fast path for ASCII characters
        let byte = utf8[bytePosition]

        // Numbers (0-9 or .)
        if (byte >= 48 && byte <= 57) || byte == 46 { // '0'-'9' or '.'
            if let token = parseNumberFast(from: input, utf8: utf8, bytePosition: &bytePosition, stringIndex: &stringIndex) {
                return token
            }
        }

        // ASCII identifiers and keywords (a-z, A-Z, _)
        if (byte >= 97 && byte <= 122) || (byte >= 65 && byte <= 90) || byte == 95 {
            if let token = parseASCIIIdentifierFast(from: input, utf8: utf8, bytePosition: &bytePosition, stringIndex: &stringIndex) {
                return token
            }
        }

        // Unicode identifiers (Japanese characters, etc.)
        if byte >= 128 || TokenizerUtilities.isIdentifierStart(input[stringIndex]) {
            if let token = parseUnicodeIdentifierFast(from: input, stringIndex: &stringIndex) {
                // Update byte position to match string index accurately for Unicode
                if let utf8Index = stringIndex.samePosition(in: input.utf8) {
                    bytePosition = input.utf8.distance(from: input.utf8.startIndex, to: utf8Index)
                }
                return token
            }
        }

        // Strings (' or ")
        if byte == 39 || byte == 34 { // '\'' or '\"'
            if let token = try parseStringFast(from: input, stringIndex: &stringIndex, startIndex: startIndex) {
                // Update byte position accurately for strings with Unicode/escapes
                if let utf8Index = stringIndex.samePosition(in: input.utf8) {
                    bytePosition = input.utf8.distance(from: input.utf8.startIndex, to: utf8Index)
                }
                return token
            }
        }

        // ASCII operators and delimiters
        if let token = parseASCIIOperatorFast(from: utf8, bytePosition: &bytePosition) {
            stringIndex = input.index(stringIndex, offsetBy: token.lexeme.count)
            return token
        }

        // Unicode operators
        if let token = parseUnicodeOperatorFast(from: input, stringIndex: &stringIndex) {
            // Update byte position accurately for multi-byte operators
            if let utf8Index = stringIndex.samePosition(in: input.utf8) {
                bytePosition = input.utf8.distance(from: input.utf8.startIndex, to: utf8Index)
            }
            return token
        }

        return nil
    }

    private func parseCommentFast(from input: String, utf8: [UInt8], bytePosition: inout Int, stringIndex: inout String.Index, startIndex: String.Index) throws -> TokenData? {
        guard bytePosition < utf8.count else { return nil }

        // Single line comment "//"
        if bytePosition + 1 < utf8.count && utf8[bytePosition] == 47 && utf8[bytePosition + 1] == 47 { // "//"
            let start = stringIndex
            bytePosition += 2
            stringIndex = input.index(stringIndex, offsetBy: 2)

            // Read until newline
            while bytePosition < utf8.count && utf8[bytePosition] != 10 { // '\n'
                bytePosition += 1
                stringIndex = input.index(after: stringIndex)
            }

            let lexeme = String(input[start..<stringIndex])
            return TokenData(type: .comment, lexeme: lexeme)
        }

        // Multi-line comment "/*"
        if bytePosition + 1 < utf8.count && utf8[bytePosition] == 47 && utf8[bytePosition + 1] == 42 { // "/*"
            let commentStart = stringIndex
            let position = sourcePosition(from: input, startIndex: startIndex, currentIndex: stringIndex)
            bytePosition += 2
            stringIndex = input.index(stringIndex, offsetBy: 2)

            // Read until "*/"
            var foundTerminator = false
            while bytePosition + 1 < utf8.count {
                if utf8[bytePosition] == 42 && utf8[bytePosition + 1] == 47 { // "*/"
                    bytePosition += 2
                    stringIndex = input.index(stringIndex, offsetBy: 2)
                    foundTerminator = true
                    break
                }
                bytePosition += 1
                stringIndex = input.index(after: stringIndex)
            }

            if !foundTerminator {
                throw TokenizerError.unterminatedComment(position)
            }

            let lexeme = String(input[commentStart..<stringIndex])
            return TokenData(type: .comment, lexeme: lexeme)
        }

        return nil
    }

    private func parseASCIIIdentifierFast(from input: String, utf8: [UInt8], bytePosition: inout Int, stringIndex: inout String.Index) -> TokenData? {
        guard bytePosition < utf8.count else { return nil }

        let start = stringIndex

        // Fast ASCII path
        while bytePosition < utf8.count {
            let byte = utf8[bytePosition]
            if (byte >= 97 && byte <= 122) || // a-z
               (byte >= 65 && byte <= 90) ||  // A-Z
               (byte >= 48 && byte <= 57) ||  // 0-9
               byte == 95 {                   // _
                bytePosition += 1
                stringIndex = input.index(after: stringIndex)
            } else {
                break
            }
        }

        guard stringIndex > start else { return nil }

        let lexeme = String(input[start..<stringIndex])

        // Fast keyword lookup
        if let tokenType = TokenizerUtilities.keywordMap[lexeme] {
            return TokenData(type: tokenType, lexeme: lexeme)
        }

        return TokenData(type: .identifier, lexeme: lexeme)
    }

    private func parseUnicodeIdentifierFast(from input: String, stringIndex: inout String.Index) -> TokenData? {
        guard stringIndex < input.endIndex && TokenizerUtilities.isIdentifierStart(input[stringIndex]) else { return nil }

        let start = stringIndex
        stringIndex = input.index(after: stringIndex)

        // Read remaining identifier characters
        while stringIndex < input.endIndex && TokenizerUtilities.isIdentifierContinue(input[stringIndex]) {
            stringIndex = input.index(after: stringIndex)
        }

        let lexeme = String(input[start..<stringIndex])

        // Fast keyword lookup
        if let tokenType = TokenizerUtilities.keywordMap[lexeme] {
            return TokenData(type: tokenType, lexeme: lexeme)
        }

        return TokenData(type: .identifier, lexeme: lexeme)
    }

    private func parseNumberFast(from input: String, utf8: [UInt8], bytePosition: inout Int, stringIndex: inout String.Index) -> TokenData? {
        guard bytePosition < utf8.count else { return nil }

        let start = stringIndex

        // Check for leading dot decimal
        if let result = parseLeadingDotNumber(from: input, utf8: utf8, bytePosition: &bytePosition, stringIndex: &stringIndex, start: start) {
            return result
        }

        // Must start with digit
        guard isDigit(utf8[bytePosition]) else { return nil }

        // Read integer part
        consumeDigits(from: input, utf8: utf8, bytePosition: &bytePosition, stringIndex: &stringIndex)

        // Check for decimal point and read fractional part if present
        let hasDecimal = tryParseDecimalPart(from: input, utf8: utf8, bytePosition: &bytePosition, stringIndex: &stringIndex)

        let lexeme = String(input[start..<stringIndex])
        let tokenType = hasDecimal ? TokenType.realLiteral : TokenType.integerLiteral
        return TokenData(type: tokenType, lexeme: lexeme)
    }

    /// Parse a number starting with a leading decimal point (e.g., ".123")
    private func parseLeadingDotNumber(from input: String, utf8: [UInt8], bytePosition: inout Int, stringIndex: inout String.Index, start: String.Index) -> TokenData? {
        guard utf8[bytePosition] == 46 else { return nil } // '.'
        guard bytePosition + 1 < utf8.count && isDigit(utf8[bytePosition + 1]) else { return nil }

        bytePosition += 1
        stringIndex = input.index(after: stringIndex)
        consumeDigits(from: input, utf8: utf8, bytePosition: &bytePosition, stringIndex: &stringIndex)

        let lexeme = String(input[start..<stringIndex])
        return TokenData(type: .realLiteral, lexeme: lexeme)
    }

    /// Try to parse the decimal part of a number. Returns true if decimal was found.
    private func tryParseDecimalPart(from input: String, utf8: [UInt8], bytePosition: inout Int, stringIndex: inout String.Index) -> Bool {
        guard bytePosition < utf8.count && utf8[bytePosition] == 46 else { return false }
        guard bytePosition + 1 < utf8.count && isDigit(utf8[bytePosition + 1]) else { return false }

        bytePosition += 1
        stringIndex = input.index(after: stringIndex)
        consumeDigits(from: input, utf8: utf8, bytePosition: &bytePosition, stringIndex: &stringIndex)
        return true
    }

    /// Consume consecutive digit characters
    private func consumeDigits(from input: String, utf8: [UInt8], bytePosition: inout Int, stringIndex: inout String.Index) {
        while bytePosition < utf8.count && isDigit(utf8[bytePosition]) {
            bytePosition += 1
            stringIndex = input.index(after: stringIndex)
        }
    }

    /// Check if a byte is an ASCII digit (0-9)
    private func isDigit(_ byte: UInt8) -> Bool {
        byte >= 48 && byte <= 57
    }

    private func parseStringFast(from input: String, stringIndex: inout String.Index, startIndex: String.Index) throws -> TokenData? {
        guard stringIndex < input.endIndex else { return nil }

        let quoteChar = input[stringIndex]
        guard quoteChar == "'" || quoteChar == "\"" else { return nil }

        let start = stringIndex
        let position = sourcePosition(from: input, startIndex: startIndex, currentIndex: stringIndex)
        stringIndex = input.index(after: stringIndex) // Skip opening quote

        // Read until closing quote, handling escape sequences
        try consumeStringContent(from: input, stringIndex: &stringIndex, quoteChar: quoteChar, position: position)

        // Must have closing quote
        guard stringIndex < input.endIndex else {
            throw TokenizerError.unterminatedString(position)
        }

        stringIndex = input.index(after: stringIndex) // Skip closing quote

        let lexeme = String(input[start..<stringIndex])
        let content = String(lexeme.dropFirst().dropLast())

        // Process escape sequences in the content for token type determination
        return try createStringToken(lexeme: lexeme, content: content, position: position)
    }

    /// Consume string content until closing quote, handling escape sequences
    private func consumeStringContent(from input: String, stringIndex: inout String.Index, quoteChar: Character, position: SourcePosition) throws {
        while stringIndex < input.endIndex && input[stringIndex] != quoteChar {
            if input[stringIndex] == "\\" {
                try consumeEscapeSequence(from: input, stringIndex: &stringIndex, position: position)
            } else {
                stringIndex = input.index(after: stringIndex)
            }
        }
    }

    /// Consume an escape sequence starting at the backslash
    private func consumeEscapeSequence(from input: String, stringIndex: inout String.Index, position: SourcePosition) throws {
        stringIndex = input.index(after: stringIndex) // consume backslash

        guard stringIndex < input.endIndex else {
            throw TokenizerError.invalidEscapeSequenceWithMessage("Incomplete escape sequence at end of string", position)
        }

        let escapedChar = input[stringIndex]
        stringIndex = input.index(after: stringIndex) // consume escaped character

        if escapedChar == "u" {
            try consumeUnicodeEscapeSequence(from: input, stringIndex: &stringIndex, position: position)
        } else {
            try validateBasicEscapeChar(escapedChar, position: position)
        }
    }

    /// Consume Unicode escape sequence \u{XXXX}
    private func consumeUnicodeEscapeSequence(from input: String, stringIndex: inout String.Index, position: SourcePosition) throws {
        guard stringIndex < input.endIndex && input[stringIndex] == "{" else {
            throw TokenizerError.invalidUnicodeEscape("Expected '{' after \\u", position)
        }
        stringIndex = input.index(after: stringIndex) // consume '{'

        // Scan hex digits
        var hexDigitCount = 0
        while stringIndex < input.endIndex && input[stringIndex] != "}" && hexDigitCount < 8 {
            guard let scalar = String(input[stringIndex]).unicodeScalars.first,
                  TokenizerUtilities.isHexDigit(scalar) else {
                throw TokenizerError.invalidUnicodeEscape("Invalid hex digit in Unicode escape", position)
            }
            stringIndex = input.index(after: stringIndex)
            hexDigitCount += 1
        }

        guard stringIndex < input.endIndex else {
            throw TokenizerError.invalidUnicodeEscape("Unterminated Unicode escape sequence", position)
        }

        guard input[stringIndex] == "}" else {
            throw TokenizerError.invalidUnicodeEscape("Unicode escape sequence too long (max 8 hex digits)", position)
        }

        guard hexDigitCount > 0 else {
            throw TokenizerError.invalidUnicodeEscape("Unicode escape sequence must have at least one hex digit", position)
        }

        stringIndex = input.index(after: stringIndex) // consume '}'
    }

    /// Validate basic escape character
    private func validateBasicEscapeChar(_ char: Character, position: SourcePosition) throws {
        switch char {
        case "n", "t", "r", "\\", "\"", "'":
            break // Valid escape sequences
        default:
            throw TokenizerError.invalidEscapeSequenceWithMessage("Unknown escape sequence \\\(char)", position)
        }
    }

    /// Create string token from lexeme and processed content
    private func createStringToken(lexeme: String, content: String, position: SourcePosition) throws -> TokenData {
        do {
            let processedContent = try StringEscapeUtilities.processEscapeSequences(content)
            let tokenType = TokenizerUtilities.stringLiteralTokenType(content: processedContent)
            return TokenData(type: tokenType, lexeme: lexeme)
        } catch let error as StringEscapeUtilities.EscapeSequenceError {
            throw TokenizerError.invalidEscapeSequenceWithMessage(error.message, position)
        }
    }

    private func parseASCIIOperatorFast(from utf8: [UInt8], bytePosition: inout Int) -> TokenData? {
        guard bytePosition < utf8.count else { return nil }

        let byte = utf8[bytePosition]

        // Use lookup table for O(1) operator matching
        guard let (tokenType, lexeme) = Self.asciiOperatorTable[byte] else {
            return nil
        }

        bytePosition += 1
        return TokenData(type: tokenType, lexeme: lexeme)
    }

    private func parseUnicodeOperatorFast(from input: String, stringIndex: inout String.Index) -> TokenData? {
        // Check multi-byte operators
        for (operatorString, tokenType) in TokenizerUtilities.operators
            where TokenizerUtilities.matchString(operatorString, in: input, at: stringIndex) {
            stringIndex = input.index(stringIndex, offsetBy: operatorString.count)
            return TokenData(type: tokenType, lexeme: operatorString)
        }

        // Check delimiters
        for (delimiter, tokenType) in TokenizerUtilities.delimiters
            where TokenizerUtilities.matchString(delimiter, in: input, at: stringIndex) {
            stringIndex = input.index(stringIndex, offsetBy: delimiter.count)
            return TokenData(type: tokenType, lexeme: delimiter)
        }

        return nil
    }

    // MARK: - Helper Methods

    private func isWhitespace(_ byte: UInt8) -> Bool {
        return byte == 32 || byte == 9 || byte == 10 || byte == 13 // space, tab, newline, carriage return
    }

    private func sourcePosition(from input: String, startIndex: String.Index, currentIndex: String.Index) -> SourcePosition {
        let processed = String(input[startIndex..<currentIndex])
        let lines = processed.components(separatedBy: "\n")
        let line = lines.count
        let column = (lines.last?.count ?? 0) + 1
        let offset = input.distance(from: startIndex, to: currentIndex)

        return SourcePosition(line: line, column: column, offset: offset)
    }
}

// MARK: - Helper Types

private struct TokenData {
    let type: TokenType
    let lexeme: String
}
