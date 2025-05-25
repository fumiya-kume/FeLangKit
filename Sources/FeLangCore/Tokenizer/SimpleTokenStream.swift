import Foundation

// MARK: - TokenStream Protocol (from GitHub Issue #9)

/// A protocol for tokenizers that support streaming processing of source code
/// with pull-based token generation and backpressure support
public protocol TokenStreamProtocol: Sendable {
    /// Returns the next token from the stream, or nil if at end
    mutating func nextToken() throws -> Token?

    /// Peeks at the next token without consuming it
    mutating func peek() throws -> Token?

    /// Returns the current position in the source
    func position() -> SourcePosition
}

// MARK: - Source Reader Protocol (Simplified)

/// A simplified source reader for streaming processing
public protocol SourceReader: Sendable {
    /// Reads the next character, or nil if at end
    mutating func readChar() -> Character?

    /// Peeks at the next character without consuming it
    func peekChar(offset: Int) -> Character?

    /// Returns true if at end of input
    var isAtEnd: Bool { get }

    /// Current position in source
    var position: SourcePosition { get }
}

// MARK: - String Source Reader (Simplified)

/// A simple string-based source reader
public struct SimpleStringReader: SourceReader {
    private let source: String
    private var currentIndex: String.Index
    private var _position: SourcePosition

    public init(source: String) {
        self.source = source
        self.currentIndex = source.startIndex
        self._position = SourcePosition(line: 1, column: 1, offset: 0)
    }

    public mutating func readChar() -> Character? {
        guard currentIndex < source.endIndex else { return nil }

        let char = source[currentIndex]
        currentIndex = source.index(after: currentIndex)

        // Update position
        if char == "\n" {
            _position = SourcePosition(
                line: _position.line + 1,
                column: 1,
                offset: _position.offset + 1
            )
        } else {
            _position = SourcePosition(
                line: _position.line,
                column: _position.column + 1,
                offset: _position.offset + 1
            )
        }

        return char
    }

    public func peekChar(offset: Int = 0) -> Character? {
        let targetIndex = source.index(currentIndex, offsetBy: offset, limitedBy: source.endIndex)
        guard let index = targetIndex, index < source.endIndex else { return nil }
        return source[index]
    }

    public var isAtEnd: Bool {
        return currentIndex >= source.endIndex
    }

    public var position: SourcePosition {
        return _position
    }
}

// MARK: - Circular Buffer (Simplified)

/// A simple circular buffer for character buffering
public struct CircularBuffer<Element>: Sendable where Element: Sendable {
    private var buffer: [Element?]
    private var head: Int = 0
    private var tail: Int = 0
    private var count: Int = 0
    public let capacity: Int

    public init(capacity: Int) {
        self.capacity = capacity
        self.buffer = Array(repeating: nil, count: capacity)
    }

    public var isEmpty: Bool { count == 0 } // swiftlint:disable:this empty_count
    public var isFull: Bool { count == capacity }
    public var size: Int { count }

    @discardableResult
    public mutating func push(_ element: Element) -> Bool {
        guard !isFull else { return false }

        buffer[tail] = element
        tail = (tail + 1) % capacity
        count += 1
        return true
    }

    public mutating func pop() -> Element? {
        guard !isEmpty else { return nil }

        let element = buffer[head]
        buffer[head] = nil
        head = (head + 1) % capacity
        count -= 1
        return element
    }

    public func peek(offset: Int = 0) -> Element? {
        guard offset >= 0 && offset < count else { return nil }
        let index = (head + offset) % capacity
        return buffer[index]
    }
}

// MARK: - Stream Tokenizer Implementation

/// Implementation of TokenStreamProtocol as specified in GitHub Issue #9
public final class SimpleStreamingTokenizer: TokenStreamProtocol, @unchecked Sendable {
    private nonisolated(unsafe) var reader: any SourceReader
    private nonisolated(unsafe) var buffer: CircularBuffer<Character>
    private nonisolated(unsafe) var lookahead: Token?
    private nonisolated(unsafe) var currentPosition: SourcePosition

    /// Creates a new streaming tokenizer
    /// - Parameters:
    ///   - reader: The source reader to read from
    ///   - bufferSize: Size of the internal character buffer (default 8192 as in issue)
    public init(reader: any SourceReader, bufferSize: Int = 8192) {
        self.reader = reader
        self.buffer = CircularBuffer(capacity: bufferSize)
        self.currentPosition = SourcePosition(line: 1, column: 1, offset: 0)
    }

    /// Convenience initializer for string input
    public convenience init(source: String, bufferSize: Int = 8192) {
        let reader = SimpleStringReader(source: source)
        self.init(reader: reader, bufferSize: bufferSize)
    }

    // MARK: - TokenStreamProtocol Implementation

    public func nextToken() throws -> Token? {
        if let token = lookahead {
            lookahead = nil
            return token
        }

        return try parseNextToken()
    }

    public func peek() throws -> Token? {
        if lookahead == nil {
            lookahead = try parseNextToken()
        }
        return lookahead
    }

    public func position() -> SourcePosition {
        return currentPosition
    }

    // MARK: - Private Implementation

    /// Fill the buffer with characters from the reader
    private func fillBuffer() {
        while !buffer.isFull && !reader.isAtEnd {
            if let char = reader.readChar() {
                buffer.push(char)
            }
        }
    }

    /// Get the next character from buffer or reader
    private func nextChar() -> Character? {
        if buffer.isEmpty {
            fillBuffer()
        }

        guard let char = buffer.pop() else { return nil }

        // Update position
        if char == "\n" {
            currentPosition = SourcePosition(
                line: currentPosition.line + 1,
                column: 1,
                offset: currentPosition.offset + 1
            )
        } else {
            currentPosition = SourcePosition(
                line: currentPosition.line,
                column: currentPosition.column + 1,
                offset: currentPosition.offset + 1
            )
        }

        return char
    }

    /// Peek at a character at the given offset
    private func peekChar(offset: Int = 0) -> Character? {
        // Ensure buffer has enough characters
        while buffer.size <= offset && !reader.isAtEnd {
            if let char = reader.readChar() {
                buffer.push(char)
            } else {
                break
            }
        }
        return buffer.peek(offset: offset)
    }

    /// Parse the next token from the input
    private func parseNextToken() throws -> Token? {
        // Skip whitespace
        while let char = peekChar(), char.isWhitespace {
            _ = nextChar()
        }

        // Check for end of input
        guard let firstChar = peekChar() else {
            return Token(type: .eof, lexeme: "", position: currentPosition)
        }

        let startPosition = currentPosition

        // Parse different token types
        if firstChar.isLetter || firstChar == "_" {
            return parseIdentifierOrKeyword(startPosition: startPosition)
        } else if firstChar.isNumber {
            return parseNumber(startPosition: startPosition)
        } else if firstChar == "\"" {
            return parseStringLiteral(startPosition: startPosition)
        } else if firstChar == "'" {
            return parseCharacterLiteral(startPosition: startPosition)
        } else if firstChar == "/" {
            if peekChar(offset: 1) == "/" {
                return parseLineComment(startPosition: startPosition)
            } else if peekChar(offset: 1) == "*" {
                return parseBlockComment(startPosition: startPosition)
            } else {
                return parseOperator(startPosition: startPosition)
            }
        } else {
            return parseOperator(startPosition: startPosition)
        }
    }

    /// Parse an identifier or keyword
    private func parseIdentifierOrKeyword(startPosition: SourcePosition) -> Token {
        var lexeme = ""

        while let char = peekChar(), char.isLetter || char.isNumber || char == "_" {
            lexeme.append(char)
            _ = nextChar()
        }

        // Check if it's a keyword
        let tokenType = TokenType.allCases.first { $0.rawValue == lexeme } ?? .identifier

        return Token(type: tokenType, lexeme: lexeme, position: startPosition)
    }

    /// Parse a numeric literal
    private func parseNumber(startPosition: SourcePosition) -> Token {
        var lexeme = ""
        var hasDecimalPoint = false

        while let char = peekChar() {
            if char.isNumber {
                lexeme.append(char)
                _ = nextChar()
            } else if char == "." && !hasDecimalPoint && peekChar(offset: 1)?.isNumber == true {
                hasDecimalPoint = true
                lexeme.append(char)
                _ = nextChar()
            } else {
                break
            }
        }

        let tokenType: TokenType = hasDecimalPoint ? .realLiteral : .integerLiteral
        return Token(type: tokenType, lexeme: lexeme, position: startPosition)
    }

    /// Parse a string literal
    private func parseStringLiteral(startPosition: SourcePosition) -> Token {
        var lexeme = ""
        _ = nextChar() // consume opening quote
        lexeme.append("\"")

        while let char = peekChar(), char != "\"" && char != "\n" {
            if char == "\\" {
                // Handle escape sequences
                _ = nextChar()
                lexeme.append(char)
                if let escapedChar = nextChar() {
                    lexeme.append(escapedChar)
                }
            } else {
                lexeme.append(char)
                _ = nextChar()
            }
        }

        // Consume closing quote if present
        if let char = peekChar(), char == "\"" {
            lexeme.append(char)
            _ = nextChar()
        }

        return Token(type: .stringLiteral, lexeme: lexeme, position: startPosition)
    }

    /// Parse a character literal
    private func parseCharacterLiteral(startPosition: SourcePosition) -> Token {
        var lexeme = ""
        _ = nextChar() // consume opening quote
        lexeme.append("'")

        if let char = peekChar(), char != "'" && char != "\n" {
            if char == "\\" {
                // Handle escape sequences
                _ = nextChar()
                lexeme.append(char)
                if let escapedChar = nextChar() {
                    lexeme.append(escapedChar)
                }
            } else {
                lexeme.append(char)
                _ = nextChar()
            }
        }

        // Consume closing quote if present
        if let char = peekChar(), char == "'" {
            lexeme.append(char)
            _ = nextChar()
        }

        return Token(type: .characterLiteral, lexeme: lexeme, position: startPosition)
    }

    /// Parse a line comment
    private func parseLineComment(startPosition: SourcePosition) -> Token {
        var lexeme = ""

        // Consume "//"
        _ = nextChar()
        _ = nextChar()
        lexeme.append("//")

        // Read until end of line
        while let char = peekChar(), char != "\n" {
            lexeme.append(char)
            _ = nextChar()
        }

        return Token(type: .comment, lexeme: lexeme, position: startPosition)
    }

    /// Parse a block comment
    private func parseBlockComment(startPosition: SourcePosition) -> Token {
        var lexeme = ""

        // Consume "/*"
        _ = nextChar()
        _ = nextChar()
        lexeme.append("/*")

        // Read until "*/"
        while !reader.isAtEnd {
            if let char = peekChar() {
                lexeme.append(char)
                _ = nextChar()

                if char == "*" && peekChar() == "/" {
                    lexeme.append("/")
                    _ = nextChar()
                    break
                }
            } else {
                break
            }
        }

        return Token(type: .comment, lexeme: lexeme, position: startPosition)
    }

        /// Parse operators and punctuation
    private func parseOperator(startPosition: SourcePosition) -> Token {
        guard let char = nextChar() else {
            return Token(type: .eof, lexeme: "", position: startPosition)
        }

        var lexeme = String(char)
        let tokenType = determineOperatorType(char: char, lexeme: &lexeme)

        return Token(type: tokenType, lexeme: lexeme, position: startPosition)
    }

    /// Determine the token type for an operator character
    private func determineOperatorType(char: Character, lexeme: inout String) -> TokenType {
        // Handle arithmetic and assignment operators
        if let arithmeticType = getArithmeticOperatorType(char) {
            return arithmeticType
        }

        // Handle comparison operators
        if let comparisonType = getComparisonOperatorType(char, lexeme: &lexeme) {
            return comparisonType
        }

        // Handle delimiters
        if let delimiterType = getDelimiterType(char) {
            return delimiterType
        }

        return .identifier // fallback for unknown characters
    }

    /// Get arithmetic operator type
    private func getArithmeticOperatorType(_ char: Character) -> TokenType? {
        switch char {
        case "←": return .assign
        case "+": return .plus
        case "-": return .minus
        case "*": return .multiply
        case "/": return .divide
        case "%": return .modulo
        default: return nil
        }
    }

    /// Get comparison operator type
    private func getComparisonOperatorType(_ char: Character, lexeme: inout String) -> TokenType? {
        // Handle Unicode comparison operators
        if let unicodeType = getUnicodeComparisonType(char) {
            return unicodeType
        }

        // Handle ASCII comparison operators with potential multi-character variants
        switch char {
        case "=": return .equal
        case ">": return handleGreaterThan(lexeme: &lexeme)
        case "<": return handleLessThan(lexeme: &lexeme)
        case "!": return handleExclamation(lexeme: &lexeme)
        default: return nil
        }
    }

    /// Get Unicode comparison operator type
    private func getUnicodeComparisonType(_ char: Character) -> TokenType? {
        switch char {
        case "≠": return .notEqual
        case "≧": return .greaterEqual
        case "≦": return .lessEqual
        default: return nil
        }
    }

    /// Get delimiter type
    private func getDelimiterType(_ char: Character) -> TokenType? {
        // Handle bracket types
        if let bracketType = getBracketType(char) {
            return bracketType
        }

        // Handle punctuation types
        return getPunctuationType(char)
    }

    /// Get bracket delimiter type
    private func getBracketType(_ char: Character) -> TokenType? {
        switch char {
        case "(": return .leftParen
        case ")": return .rightParen
        case "[": return .leftBracket
        case "]": return .rightBracket
        case "{": return .leftBrace
        case "}": return .rightBrace
        default: return nil
        }
    }

    /// Get punctuation delimiter type
    private func getPunctuationType(_ char: Character) -> TokenType? {
        switch char {
        case ",": return .comma
        case ".": return .dot
        case ";": return .semicolon
        case ":": return .colon
        default: return nil
        }
    }

    /// Handle greater than operator and its variants
    private func handleGreaterThan(lexeme: inout String) -> TokenType {
        if peekChar() == "=" {
            lexeme.append("=")
            _ = nextChar()
            return .greaterEqual
        } else {
            return .greater
        }
    }

    /// Handle less than operator and its variants
    private func handleLessThan(lexeme: inout String) -> TokenType {
        if peekChar() == "=" {
            lexeme.append("=")
            _ = nextChar()
            return .lessEqual
        } else {
            return .less
        }
    }

    /// Handle exclamation mark and its variants
    private func handleExclamation(lexeme: inout String) -> TokenType {
        if peekChar() == "=" {
            lexeme.append("=")
            _ = nextChar()
            return .notEqual
        } else {
            return .notKeyword
        }
    }
}
