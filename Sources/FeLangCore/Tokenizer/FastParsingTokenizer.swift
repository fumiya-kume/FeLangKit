import Foundation

/// High-performance tokenizer optimized for speed
/// Implements Phase 2 optimizations from Issue #26 performance plan
/// Uses hybrid approach: UTF-8 byte processing for ASCII, String operations for Unicode
public struct FastParsingTokenizer {

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
                // Update byte position to match string index
                let newBytePos = input.utf8.distance(from: input.utf8.startIndex, to: input.utf8.index(input.utf8.startIndex, offsetBy: input.distance(from: input.startIndex, to: stringIndex)))
                bytePosition = newBytePos
                return token
            }
        }

        // Strings (' or ")
        if byte == 39 || byte == 34 { // '\'' or '\"'
            if let token = try parseStringFast(from: input, stringIndex: &stringIndex, startIndex: startIndex) {
                // Update byte position
                let newBytePos = input.utf8.distance(from: input.utf8.startIndex, to: input.utf8.index(input.utf8.startIndex, offsetBy: input.distance(from: input.startIndex, to: stringIndex)))
                bytePosition = newBytePos
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
            // Update byte position
            let newBytePos = input.utf8.distance(from: input.utf8.startIndex, to: input.utf8.index(input.utf8.startIndex, offsetBy: input.distance(from: input.startIndex, to: stringIndex)))
            bytePosition = newBytePos
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
        var hasDecimal = false

        // Check for leading dot decimal
        if utf8[bytePosition] == 46 { // '.'
            if bytePosition + 1 < utf8.count && utf8[bytePosition + 1] >= 48 && utf8[bytePosition + 1] <= 57 {
                hasDecimal = true
                bytePosition += 1
                stringIndex = input.index(after: stringIndex)

                // Read fractional part
                while bytePosition < utf8.count && utf8[bytePosition] >= 48 && utf8[bytePosition] <= 57 {
                    bytePosition += 1
                    stringIndex = input.index(after: stringIndex)
                }

                let lexeme = String(input[start..<stringIndex])
                return TokenData(type: .realLiteral, lexeme: lexeme)
            } else {
                return nil
            }
        }

        // Must start with digit
        guard utf8[bytePosition] >= 48 && utf8[bytePosition] <= 57 else { return nil }

        // Read integer part
        while bytePosition < utf8.count && utf8[bytePosition] >= 48 && utf8[bytePosition] <= 57 {
            bytePosition += 1
            stringIndex = input.index(after: stringIndex)
        }

        // Check for decimal point
        if bytePosition < utf8.count && utf8[bytePosition] == 46 {
            if bytePosition + 1 < utf8.count && utf8[bytePosition + 1] >= 48 && utf8[bytePosition + 1] <= 57 {
                hasDecimal = true
                bytePosition += 1
                stringIndex = input.index(after: stringIndex)

                // Read fractional part
                while bytePosition < utf8.count && utf8[bytePosition] >= 48 && utf8[bytePosition] <= 57 {
                    bytePosition += 1
                    stringIndex = input.index(after: stringIndex)
                }
            }
        }

        let lexeme = String(input[start..<stringIndex])
        let tokenType = hasDecimal ? TokenType.realLiteral : TokenType.integerLiteral
        return TokenData(type: tokenType, lexeme: lexeme)
    }

    private func parseStringFast(from input: String, stringIndex: inout String.Index, startIndex: String.Index) throws -> TokenData? {
        guard stringIndex < input.endIndex else { return nil }

        let quoteChar = input[stringIndex]
        guard quoteChar == "'" || quoteChar == "\"" else { return nil }

        let start = stringIndex
        let position = sourcePosition(from: input, startIndex: startIndex, currentIndex: stringIndex)
        stringIndex = input.index(after: stringIndex) // Skip opening quote

        // Read until closing quote
        while stringIndex < input.endIndex && input[stringIndex] != quoteChar {
            if input[stringIndex] == "\\" {
                stringIndex = input.index(after: stringIndex) // Skip backslash
                if stringIndex < input.endIndex {
                    stringIndex = input.index(after: stringIndex) // Skip escaped character
                }
            } else {
                stringIndex = input.index(after: stringIndex)
            }
        }

        // Must have closing quote
        guard stringIndex < input.endIndex else {
            throw TokenizerError.unterminatedString(position)
        }

        stringIndex = input.index(after: stringIndex) // Skip closing quote

        let lexeme = String(input[start..<stringIndex])
        let content = String(lexeme.dropFirst().dropLast())

        // Validate escape sequences
        guard StringEscapeUtilities.validateEscapeSequences(content) else {
            throw TokenizerError.invalidEscapeSequence(position)
        }

        let tokenType = content.count == 1 ? TokenType.characterLiteral : TokenType.stringLiteral
        return TokenData(type: tokenType, lexeme: lexeme)
    }

    private func parseASCIIOperatorFast(from utf8: [UInt8], bytePosition: inout Int) -> TokenData? {
        guard bytePosition < utf8.count else { return nil }

        let byte = utf8[bytePosition]

        // Fast path for single-byte ASCII operators/delimiters
        switch byte {
        case 40: // '('
            bytePosition += 1
            return TokenData(type: .leftParen, lexeme: "(")
        case 41: // ')'
            bytePosition += 1
            return TokenData(type: .rightParen, lexeme: ")")
        case 91: // '['
            bytePosition += 1
            return TokenData(type: .leftBracket, lexeme: "[")
        case 93: // ']'
            bytePosition += 1
            return TokenData(type: .rightBracket, lexeme: "]")
        case 123: // '{'
            bytePosition += 1
            return TokenData(type: .leftBrace, lexeme: "{")
        case 125: // '}'
            bytePosition += 1
            return TokenData(type: .rightBrace, lexeme: "}")
        case 44: // ','
            bytePosition += 1
            return TokenData(type: .comma, lexeme: ",")
        case 46: // '.' (if not part of number)
            bytePosition += 1
            return TokenData(type: .dot, lexeme: ".")
        case 59: // ';'
            bytePosition += 1
            return TokenData(type: .semicolon, lexeme: ";")
        case 58: // ':'
            bytePosition += 1
            return TokenData(type: .colon, lexeme: ":")
        case 43: // '+'
            bytePosition += 1
            return TokenData(type: .plus, lexeme: "+")
        case 45: // '-'
            bytePosition += 1
            return TokenData(type: .minus, lexeme: "-")
        case 42: // '*'
            bytePosition += 1
            return TokenData(type: .multiply, lexeme: "*")
        case 47: // '/'
            bytePosition += 1
            return TokenData(type: .divide, lexeme: "/")
        case 37: // '%'
            bytePosition += 1
            return TokenData(type: .modulo, lexeme: "%")
        case 61: // '='
            bytePosition += 1
            return TokenData(type: .equal, lexeme: "=")
        case 62: // '>'
            bytePosition += 1
            return TokenData(type: .greater, lexeme: ">")
        case 60: // '<'
            bytePosition += 1
            return TokenData(type: .less, lexeme: "<")
        default:
            return nil
        }
    }

    private func parseUnicodeOperatorFast(from input: String, stringIndex: inout String.Index) -> TokenData? {
        // Check multi-byte operators
        for (operatorString, tokenType) in TokenizerUtilities.operators {
            if TokenizerUtilities.matchString(operatorString, in: input, at: stringIndex) {
                stringIndex = input.index(stringIndex, offsetBy: operatorString.count)
                return TokenData(type: tokenType, lexeme: operatorString)
            }
        }

        // Check delimiters
        for (delimiter, tokenType) in TokenizerUtilities.delimiters {
            if TokenizerUtilities.matchString(delimiter, in: input, at: stringIndex) {
                stringIndex = input.index(stringIndex, offsetBy: delimiter.count)
                return TokenData(type: tokenType, lexeme: delimiter)
            }
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
