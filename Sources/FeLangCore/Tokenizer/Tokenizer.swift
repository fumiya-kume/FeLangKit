import Foundation

/// A tokenizer for FE pseudo-language that converts source code into tokens.
public final class Tokenizer {
    private let input: String
    private let source: String.UnicodeScalarView
    private var current: String.UnicodeScalarView.Index
    private var line: Int = 1
    private var column: Int = 1
    private var offset: Int = 0

    /// Sentinel value used to represent end-of-input condition
    /// Using NULL character (U+0000) which is guaranteed to exist and won't appear in normal text
    private static let endOfInputSentinel = UnicodeScalar(0x0000)! // swiftlint:disable:this force_unwrapping

    /// Mapping of keywords to their token types (using shared utilities)
    private static let keywords = TokenizerUtilities.keywordMap

    /// Creates a new tokenizer for the given input.
    /// - Parameter input: The source code to tokenize
    public init(input: String) {
        self.input = input
        self.source = input.unicodeScalars
        self.current = source.startIndex
    }

    /// Tokenizes the input and returns an array of tokens.
    /// - Returns: An array of tokens representing the input
    /// - Throws: TokenizerError if invalid syntax is encountered
    public func tokenize() throws -> [Token] {
        var tokens: [Token] = []

        while !isAtEnd {
            let token = try nextToken()
            if token.type != .whitespace && token.type != .comment {
                tokens.append(token)
            }
        }

        tokens.append(Token(type: .eof, lexeme: "", position: currentPosition()))
        return tokens
    }

    // MARK: - Private Methods

    /// Returns true if we've reached the end of the input
    private var isAtEnd: Bool {
        return current >= source.endIndex
    }

    /// Returns the current position in the source
    private func currentPosition() -> SourcePosition {
        return SourcePosition(line: line, column: column, offset: offset)
    }

    /// Advances to the next character and returns the current one
    private func advance() -> UnicodeScalar {
        guard !isAtEnd else { return Self.endOfInputSentinel }

        let char = source[current]
        current = source.index(after: current)
        offset += 1

        if char == "\n" {
            line += 1
            column = 1
        } else {
            column += 1
        }

        return char
    }

    /// Peeks at the current character without advancing
    private func peek() -> UnicodeScalar {
        guard !isAtEnd else { return Self.endOfInputSentinel }
        return source[current]
    }

    /// Peeks at the next character without advancing
    private func peekNext() -> UnicodeScalar {
        let next = source.index(after: current)
        guard next < source.endIndex else { return Self.endOfInputSentinel }
        return source[next]
    }

    /// Checks if the current character matches the expected one
    private func match(_ expected: UnicodeScalar) -> Bool {
        guard !isAtEnd else { return false }
        guard source[current] == expected else { return false }

        _ = advance()
        return true
    }

    /// Scans the next token from the input
    private func nextToken() throws -> Token { // swiftlint:disable:this cyclomatic_complexity
        let position = currentPosition()
        let startIndex = current
        let char = advance()

        switch char {
        case " ", "\t":
            return scanWhitespace(position, startIndex: startIndex)
        case "\n":
            return scanNewline(position)
        case "/":
            return try scanSlashOrComment(position, startIndex: startIndex)
        case "+":
            return Token(type: .plus, lexeme: "+", position: position)
        case "-":
            return try scanMinusOrNumber(position, startIndex: startIndex)
        case "*":
            return Token(type: .multiply, lexeme: "*", position: position)
        case "%":
            return Token(type: .modulo, lexeme: "%", position: position)
        case "←":
            return Token(type: .assign, lexeme: "←", position: position)
        case "=":
            return Token(type: .equal, lexeme: "=", position: position)
        case "≠":
            return Token(type: .notEqual, lexeme: "≠", position: position)
        case "≧":
            return Token(type: .greaterEqual, lexeme: "≧", position: position)
        case "≦":
            return Token(type: .lessEqual, lexeme: "≦", position: position)
        case ">":
            return Token(type: .greater, lexeme: ">", position: position)
        case "<":
            return Token(type: .less, lexeme: "<", position: position)
        case "(":
            return Token(type: .leftParen, lexeme: "(", position: position)
        case ")":
            return Token(type: .rightParen, lexeme: ")", position: position)
        case "[":
            return Token(type: .leftBracket, lexeme: "[", position: position)
        case "]":
            return Token(type: .rightBracket, lexeme: "]", position: position)
        case "{":
            return Token(type: .leftBrace, lexeme: "{", position: position)
        case "}":
            return Token(type: .rightBrace, lexeme: "}", position: position)
        case ",":
            return Token(type: .comma, lexeme: ",", position: position)
        case ".":
            return scanDotOrNumber(position, startIndex: startIndex)
        case ";":
            return Token(type: .semicolon, lexeme: ";", position: position)
        case ":":
            return Token(type: .colon, lexeme: ":", position: position)
        case "'":
            return try scanStringOrCharacterLiteral(position, startIndex: startIndex)
        default:
            if char.isNumber {
                return try scanNumber(position, startIndex: startIndex)
            } else if isIdentifierStart(char) {
                return scanIdentifier(position, startIndex: startIndex)
            } else {
                throw TokenizerError.unexpectedCharacter(char, position)
            }
        }
    }

    /// Scans whitespace characters
    private func scanWhitespace(_ position: SourcePosition, startIndex: String.UnicodeScalarView.Index) -> Token {
        while !isAtEnd && (peek() == " " || peek() == "\t") {
            _ = advance()
        }

        let lexeme = String(source[startIndex..<current])
        return Token(type: .whitespace, lexeme: lexeme, position: position)
    }

    /// Scans a newline character
    private func scanNewline(_ position: SourcePosition) -> Token {
        return Token(type: .newline, lexeme: "\n", position: position)
    }

    /// Scans either a division operator or a comment
    private func scanSlashOrComment(_ position: SourcePosition, startIndex: String.UnicodeScalarView.Index) throws -> Token {
        if match("/") {
            // Single-line comment
            return scanSingleLineComment(position, startIndex: startIndex)
        } else if match("*") {
            // Multi-line comment
            return try scanMultiLineComment(position, startIndex: startIndex)
        } else {
            return Token(type: .divide, lexeme: "/", position: position)
        }
    }

    /// Scans a single-line comment
    private func scanSingleLineComment(_ position: SourcePosition, startIndex: String.UnicodeScalarView.Index) -> Token {
        while !isAtEnd && peek() != "\n" {
            _ = advance()
        }

        let lexeme = String(source[startIndex..<current])
        return Token(type: .comment, lexeme: lexeme, position: position)
    }

    /// Scans a multi-line comment
    private func scanMultiLineComment(_ position: SourcePosition, startIndex: String.UnicodeScalarView.Index) throws -> Token {
        while !isAtEnd {
            if peek() == "*" && peekNext() == "/" {
                _ = advance() // consume '*'
                _ = advance() // consume '/'
                break
            }
            _ = advance()
        }

        if isAtEnd {
            throw TokenizerError.unterminatedComment(position)
        }

        let lexeme = String(source[startIndex..<current])
        return Token(type: .comment, lexeme: lexeme, position: position)
    }

    /// Scans either a minus operator or a negative number
    private func scanMinusOrNumber(_ position: SourcePosition, startIndex: String.UnicodeScalarView.Index) throws -> Token {
        if !isAtEnd && (peek().isNumber || (peek() == "." && peekNext().isNumber)) {
            return try scanNumber(position, startIndex: startIndex)
        } else {
            return Token(type: .minus, lexeme: "-", position: position)
        }
    }

    /// Scans either a dot or a decimal number
    private func scanDotOrNumber(_ position: SourcePosition, startIndex: String.UnicodeScalarView.Index) -> Token {
        if !isAtEnd && peek().isNumber {
            return scanLeadingDotNumber(position, startIndex: startIndex)
        } else {
            return Token(type: .dot, lexeme: ".", position: position)
        }
    }

    /// Scans a decimal number that starts with a dot (e.g., .5, .25)
    private func scanLeadingDotNumber(_ position: SourcePosition, startIndex: String.UnicodeScalarView.Index) -> Token {
        // We already know the next character is a digit
        while !isAtEnd && peek().isNumber {
            _ = advance()
        }

        let lexeme = String(source[startIndex..<current])
        return Token(type: .realLiteral, lexeme: lexeme, position: position)
    }

    /// Scans a string or character literal
    private func scanStringOrCharacterLiteral(_ position: SourcePosition, startIndex: String.UnicodeScalarView.Index) throws -> Token {
        let contentStartIndex = current

        while !isAtEnd && peek() != "'" {
            _ = advance()
        }

        if isAtEnd {
            throw TokenizerError.unterminatedString(position)
        }

        // Consume the closing quote
        _ = advance()

        let content = String(source[contentStartIndex..<source.index(before: current)])
        let lexeme = String(source[startIndex..<current])
        let tokenType = TokenizerUtilities.stringLiteralTokenType(content: content)

        return Token(type: tokenType, lexeme: lexeme, position: position)
    }

    /// Scans a number (integer, real, scientific notation, or alternative bases)
    private func scanNumber(_ position: SourcePosition, startIndex: String.UnicodeScalarView.Index) throws -> Token {
        // Get the first character that was already consumed
        let firstChar = source[source.index(before: current)]

        // Check for alternative number bases (0x, 0b, 0o)
        if firstChar == "0" && !isAtEnd {
            let nextChar = peek()
            if nextChar == "x" || nextChar == "X" {
                return try scanHexadecimalNumber(position, startIndex: startIndex)
            } else if nextChar == "b" || nextChar == "B" {
                return try scanBinaryNumber(position, startIndex: startIndex)
            } else if nextChar == "o" || nextChar == "O" {
                return try scanOctalNumber(position, startIndex: startIndex)
            }
        }

        // Scan regular number (decimal, integer, or scientific notation)
        return try scanDecimalNumber(position, startIndex: startIndex)
    }

    /// Scans a hexadecimal number (0xFF, 0x1A2B, etc.)
    private func scanHexadecimalNumber(_ position: SourcePosition, startIndex: String.UnicodeScalarView.Index) throws -> Token {
        // '0' was already consumed in nextToken(), now consume 'x' or 'X'
        _ = advance() // consume 'x' or 'X'

        // Must have at least one hex digit
        guard !isAtEnd else {
            let lexeme = String(source[startIndex..<current])
            throw TokenizerError.invalidNumberFormat(lexeme, position)
        }

        guard TokenizerUtilities.isHexDigit(peek()) || peek() == "_" else {
            let lexeme = String(source[startIndex..<current])
            throw TokenizerError.invalidNumberFormat(lexeme, position)
        }

        while !isAtEnd && (TokenizerUtilities.isHexDigit(peek()) || peek() == "_") {
            _ = advance()
        }

        // Check if there's an invalid character that looks like it should be part of the hex number
        if !isAtEnd && (peek().isLetter || peek().isNumber) {
            let lexeme = String(source[startIndex..<current])
            throw TokenizerError.invalidNumberFormat(lexeme, position)
        }

        let lexeme = String(source[startIndex..<current])

        // Validate the format
        try TokenizerUtilities.validateHexadecimalNumber(lexeme)

        return Token(type: .integerLiteral, lexeme: lexeme, position: position)
    }

    /// Scans a binary number (0b1010, 0B1100, etc.)
    private func scanBinaryNumber(_ position: SourcePosition, startIndex: String.UnicodeScalarView.Index) throws -> Token {
        // '0' was already consumed in nextToken(), now consume 'b' or 'B'
        _ = advance() // consume 'b' or 'B'

        // Must have at least one binary digit
        guard !isAtEnd else {
            let lexeme = String(source[startIndex..<current])
            throw TokenizerError.invalidNumberFormat(lexeme, position)
        }

        guard TokenizerUtilities.isBinaryDigit(peek()) || peek() == "_" else {
            let lexeme = String(source[startIndex..<current])
            throw TokenizerError.invalidNumberFormat(lexeme, position)
        }

        while !isAtEnd && (TokenizerUtilities.isBinaryDigit(peek()) || peek() == "_") {
            _ = advance()
        }

        // Check if there's an invalid character that looks like it should be part of the binary number
        if !isAtEnd && (peek().isLetter || peek().isNumber) {
            let lexeme = String(source[startIndex..<current])
            throw TokenizerError.invalidNumberFormat(lexeme, position)
        }

        let lexeme = String(source[startIndex..<current])

        // Validate the format
        try TokenizerUtilities.validateBinaryNumber(lexeme)

        return Token(type: .integerLiteral, lexeme: lexeme, position: position)
    }

    /// Scans an octal number (0o777, 0O123, etc.)
    private func scanOctalNumber(_ position: SourcePosition, startIndex: String.UnicodeScalarView.Index) throws -> Token {
        // '0' was already consumed in nextToken(), now consume 'o' or 'O'
        _ = advance() // consume 'o' or 'O'

        // Must have at least one octal digit
        guard !isAtEnd else {
            let lexeme = String(source[startIndex..<current])
            throw TokenizerError.invalidNumberFormat(lexeme, position)
        }

        guard TokenizerUtilities.isOctalDigit(peek()) || peek() == "_" else {
            let lexeme = String(source[startIndex..<current])
            throw TokenizerError.invalidNumberFormat(lexeme, position)
        }

        while !isAtEnd && (TokenizerUtilities.isOctalDigit(peek()) || peek() == "_") {
            _ = advance()
        }

        // Check if there's an invalid character that looks like it should be part of the octal number
        if !isAtEnd && (peek().isLetter || peek().isNumber) {
            let lexeme = String(source[startIndex..<current])
            throw TokenizerError.invalidNumberFormat(lexeme, position)
        }

        let lexeme = String(source[startIndex..<current])

        // Validate the format
        try TokenizerUtilities.validateOctalNumber(lexeme)

        return Token(type: .integerLiteral, lexeme: lexeme, position: position)
    }

    /// Scans a decimal number (including scientific notation and underscores)
    private func scanDecimalNumber(_ position: SourcePosition, startIndex: String.UnicodeScalarView.Index) throws -> Token {
        // Scan integer part (including underscores)
        while !isAtEnd && (peek().isNumber || peek() == "_") {
            _ = advance()
        }

        // Check for decimal point
        if !isAtEnd && peek() == "." && peekNext().isNumber {
            _ = advance() // consume '.'

            // Scan fractional part
            while !isAtEnd && (peek().isNumber || peek() == "_") {
                _ = advance()
            }
        }

        // Check for scientific notation
        if !isAtEnd && (peek() == "e" || peek() == "E") {
            _ = advance() // consume 'e' or 'E'

            // Optional sign
            if !isAtEnd && (peek() == "+" || peek() == "-") {
                _ = advance()
            }

            // Must have at least one digit in exponent
            guard !isAtEnd && (peek().isNumber || peek() == "_") else {
                let lexeme = String(source[startIndex..<current])
                throw TokenizerError.invalidNumberFormat(lexeme, position)
            }

            // Scan exponent digits
            while !isAtEnd && (peek().isNumber || peek() == "_") {
                _ = advance()
            }

            // Check if there's an invalid character that looks like it should be part of the scientific notation
            if !isAtEnd && (peek() == "e" || peek() == "E" || (peek().isLetter && peek() != "_")) {
                let lexeme = String(source[startIndex..<current])
                throw TokenizerError.invalidNumberFormat(lexeme, position)
            }
        }

        let lexeme = String(source[startIndex..<current])

        // Validate underscore placement and scientific notation if present
        if lexeme.contains("_") {
            _ = try TokenizerUtilities.validateAndCleanNumber(lexeme)
        }

        if lexeme.lowercased().contains("e") {
            try TokenizerUtilities.validateScientificNotation(lexeme)
        }

        let tokenType = TokenizerUtilities.enhancedNumberTokenType(lexeme: lexeme)
        return Token(type: tokenType, lexeme: lexeme, position: position)
    }

    /// Scans an identifier or keyword
    /// Keywords are properly bounded by the identifier scanning logic which ensures
    /// complete token boundaries are respected for all Unicode characters
    private func scanIdentifier(_ position: SourcePosition, startIndex: String.UnicodeScalarView.Index) -> Token {
        while !isAtEnd && isIdentifierContinue(peek()) {
            _ = advance()
        }

        let lexeme = String(source[startIndex..<current])
        let tokenType = TokenizerUtilities.keywordMap[lexeme] ?? .identifier

        return Token(type: tokenType, lexeme: lexeme, position: position)
    }

        /// Checks if a character can start an identifier
    /// Handles Unicode letters, underscore, and CJK characters robustly
    private func isIdentifierStart(_ char: UnicodeScalar) -> Bool {
        // Handle end-of-input sentinel
        if char == Self.endOfInputSentinel {
            return false
        }

        return TokenizerUtilities.isIdentifierStart(char)
    }

    /// Checks if a character can continue an identifier
    /// Handles Unicode letters, digits, underscore, and CJK characters robustly
    private func isIdentifierContinue(_ char: UnicodeScalar) -> Bool {
        // Handle end-of-input sentinel
        if char == Self.endOfInputSentinel {
            return false
        }

        return TokenizerUtilities.isIdentifierContinue(char)
    }
}
