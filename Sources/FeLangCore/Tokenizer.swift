import Foundation

/// A tokenizer for FE pseudo-language that converts source code into tokens.
public final class Tokenizer {
    private let input: String
    private let source: String.UnicodeScalarView
    private var current: String.UnicodeScalarView.Index
    private var line: Int = 1
    private var column: Int = 1
    private var offset: Int = 0

    /// Mapping of keywords to their token types
    private static let keywords: [String: TokenType] = [
        "整数型": .integerType,
        "実数型": .realType,
        "文字型": .characterType,
        "文字列型": .stringType,
        "論理型": .booleanType,
        "レコード": .recordType,
        "配列": .arrayType,
        "if": .ifKeyword,
        "while": .whileKeyword,
        "for": .forKeyword,
        "and": .andKeyword,
        "or": .orKeyword,
        "not": .notKeyword,
        "return": .returnKeyword,
        "break": .breakKeyword,
        "true": .trueKeyword,
        "false": .falseKeyword
    ]

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
        guard !isAtEnd else { return UnicodeScalar(0) ?? UnicodeScalar(32) }

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
        guard !isAtEnd else { return UnicodeScalar(0) ?? UnicodeScalar(32) }
        return source[current]
    }

    /// Peeks at the next character without advancing
    private func peekNext() -> UnicodeScalar {
        let next = source.index(after: current)
        guard next < source.endIndex else { return UnicodeScalar(0) ?? UnicodeScalar(32) }
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
        let char = advance()

        switch char {
        case " ", "\t":
            return scanWhitespace(position)
        case "\n":
            return scanNewline(position)
        case "/":
            return try scanSlashOrComment(position)
        case "+":
            return Token(type: .plus, lexeme: "+", position: position)
        case "-":
            return scanMinusOrNumber(position)
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
            return scanDotOrNumber(position)
        case ";":
            return Token(type: .semicolon, lexeme: ";", position: position)
        case ":":
            return Token(type: .colon, lexeme: ":", position: position)
        case "'":
            return try scanStringOrCharacterLiteral(position)
        default:
            if char.isNumber {
                return scanNumber(position)
            } else if isIdentifierStart(char) {
                return scanIdentifier(position)
            } else {
                throw TokenizerError.unexpectedCharacter(char, position)
            }
        }
    }

    /// Scans whitespace characters
    private func scanWhitespace(_ position: SourcePosition) -> Token {
        let startIndex = source.index(source.startIndex, offsetBy: position.offset)
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
    private func scanSlashOrComment(_ position: SourcePosition) throws -> Token {
        if match("/") {
            // Single-line comment
            return scanSingleLineComment(position)
        } else if match("*") {
            // Multi-line comment
            return try scanMultiLineComment(position)
        } else {
            return Token(type: .divide, lexeme: "/", position: position)
        }
    }

    /// Scans a single-line comment
    private func scanSingleLineComment(_ position: SourcePosition) -> Token {
        let startIndex = source.index(source.startIndex, offsetBy: position.offset)
        while !isAtEnd && peek() != "\n" {
            _ = advance()
        }

        let lexeme = String(source[startIndex..<current])
        return Token(type: .comment, lexeme: lexeme, position: position)
    }

    /// Scans a multi-line comment
    private func scanMultiLineComment(_ position: SourcePosition) throws -> Token {
        let startIndex = source.index(source.startIndex, offsetBy: position.offset)
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
    private func scanMinusOrNumber(_ position: SourcePosition) -> Token {
        if !isAtEnd && peek().isNumber {
            return scanNumber(position)
        } else {
            return Token(type: .minus, lexeme: "-", position: position)
        }
    }

    /// Scans either a dot or a decimal number
    private func scanDotOrNumber(_ position: SourcePosition) -> Token {
        if !isAtEnd && peek().isNumber {
            return scanLeadingDotNumber(position)
        } else {
            return Token(type: .dot, lexeme: ".", position: position)
        }
    }

    /// Scans a decimal number that starts with a dot (e.g., .5, .25)
    private func scanLeadingDotNumber(_ position: SourcePosition) -> Token {
        let startIndex = source.index(source.startIndex, offsetBy: position.offset)

        // We already know the next character is a digit
        while !isAtEnd && peek().isNumber {
            _ = advance()
        }

        let lexeme = String(source[startIndex..<current])
        return Token(type: .realLiteral, lexeme: lexeme, position: position)
    }

    /// Scans a string or character literal
    private func scanStringOrCharacterLiteral(_ position: SourcePosition) throws -> Token {
        let lexemeStartIndex = source.index(source.startIndex, offsetBy: position.offset)
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
        let lexeme = String(source[lexemeStartIndex..<current])

        if content.count == 1 {
            return Token(type: .characterLiteral, lexeme: lexeme, position: position)
        } else {
            return Token(type: .stringLiteral, lexeme: lexeme, position: position)
        }
    }

    /// Scans a number (integer or real)
    private func scanNumber(_ position: SourcePosition) -> Token {
        let startIndex = source.index(source.startIndex, offsetBy: position.offset)
        while !isAtEnd && peek().isNumber {
            _ = advance()
        }

        var isReal = false

        // Check for decimal point
        if !isAtEnd && peek() == "." && peekNext().isNumber {
            isReal = true
            _ = advance() // consume '.'

            while !isAtEnd && peek().isNumber {
                _ = advance()
            }
        }

        let lexeme = String(source[startIndex..<current])
        let tokenType: TokenType = isReal ? .realLiteral : .integerLiteral

        return Token(type: tokenType, lexeme: lexeme, position: position)
    }

    /// Scans an identifier or keyword
    private func scanIdentifier(_ position: SourcePosition) -> Token {
        let startIndex = source.index(source.startIndex, offsetBy: position.offset)
        while !isAtEnd && isIdentifierContinue(peek()) {
            _ = advance()
        }

        let lexeme = String(source[startIndex..<current])
        let tokenType = Self.keywords[lexeme] ?? .identifier

        return Token(type: tokenType, lexeme: lexeme, position: position)
    }

    /// Checks if a character can start an identifier
    private func isIdentifierStart(_ char: UnicodeScalar) -> Bool {
        return char.isLetter || char == "_" || isJapaneseCharacter(char)
    }

    /// Checks if a character can continue an identifier
    private func isIdentifierContinue(_ char: UnicodeScalar) -> Bool {
        return char.isLetter || char.isNumber || char == "_" || isJapaneseCharacter(char)
    }

    /// Checks if a character is a Japanese character (Hiragana, Katakana, or Kanji)
    private func isJapaneseCharacter(_ char: UnicodeScalar) -> Bool {
        let value = char.value
        return (value >= 0x3040 && value <= 0x309F) ||  // Hiragana
               (value >= 0x30A0 && value <= 0x30FF) ||  // Katakana
               (value >= 0x4E00 && value <= 0x9FAF)     // CJK Unified Ideographs
    }
}

extension UnicodeScalar {
    /// Returns true if this scalar represents a letter
    var isLetter: Bool {
        return CharacterSet.letters.contains(self)
    }

    /// Returns true if this scalar represents a number
    var isNumber: Bool {
        return CharacterSet.decimalDigits.contains(self)
    }
}
