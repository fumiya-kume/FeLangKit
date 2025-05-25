import Foundation

// MARK: - TokenStream Adapter

/// Adapter to maintain backward compatibility while introducing TokenStream
/// This allows gradual migration from existing tokenizers to the new streaming architecture
public struct TokenStreamAdapter {

    /// Converts a TokenStreamProtocol to an array of tokens for backward compatibility
    /// - Parameter tokenStream: The token stream to convert
    /// - Returns: An array containing all tokens from the stream
    /// - Throws: Any errors from the token stream
    public static func collectTokens(from tokenStream: inout any TokenStreamProtocol) throws -> [Token] {
        var tokens: [Token] = []
        var iterationCount = 0
        let emergencyLimit = 100_000 // Emergency safety limit to prevent infinite loops

        while iterationCount < emergencyLimit {
            if let token = try tokenStream.nextToken() {
                tokens.append(token)
                iterationCount += 1

                // Proper termination: check for EOF token
                if token.type == .eof {
                    // Validate that this is indeed the final token
                    let nextToken = try tokenStream.nextToken()
                    assert(nextToken == nil || nextToken?.type == .eof,
                           "Tokenizer returned tokens after EOF - this violates the protocol contract")
                    break
                }
            } else {
                // nextToken() returned nil without an EOF token
                // This indicates improper tokenizer implementation
                assertionFailure("Tokenizer returned nil without EOF token - this violates the protocol contract")

                // Add an EOF token to maintain consistency
                let position = tokens.last?.position ?? SourcePosition(line: 1, column: 1, offset: 0)
                tokens.append(Token(type: .eof, lexeme: "", position: position))
                break
            }
        }

        // Assert proper behavior
        assert(iterationCount < emergencyLimit,
               "Tokenizer hit emergency limit - likely infinite loop or missing EOF token")
        assert(!tokens.isEmpty,
               "Tokenizer should produce at least one token (EOF)")
        assert(tokens.last?.type == .eof,
               "Tokenizer must always terminate with EOF token")

        return tokens
    }

    /// Creates a TokenStream from an existing token array
    /// - Parameter tokens: Array of tokens to stream
    /// - Returns: A token stream that yields the provided tokens
    public static func createStream(from tokens: [Token]) -> ArrayTokenStream {
        return ArrayTokenStream(tokens: tokens)
    }

    /// Converts any existing tokenizer to use the TokenStreamProtocol interface
    /// - Parameter source: Source code to tokenize
    /// - Returns: A TokenStreamProtocol implementation
    public static func streamFromSource(_ source: String) -> any TokenStreamProtocol {
        return SimpleStreamingTokenizer(source: source)
    }
}

// MARK: - Array Token Stream

/// A TokenStreamProtocol implementation that wraps an array of tokens
/// Useful for testing and backward compatibility
public struct ArrayTokenStream: TokenStreamProtocol {
    private let tokens: [Token]
    private var currentIndex: Int = 0
    private var peekedToken: Token?

    public init(tokens: [Token]) {
        self.tokens = tokens
    }

    public mutating func nextToken() throws -> Token? {
        if let peeked = peekedToken {
            peekedToken = nil
            return peeked
        }

        guard currentIndex < tokens.count else { return nil }
        let token = tokens[currentIndex]
        currentIndex += 1
        return token
    }

    public mutating func peek() throws -> Token? {
        if peekedToken == nil {
            peekedToken = try nextToken()
        }
        return peekedToken
    }

    public func position() -> SourcePosition {
        if currentIndex < tokens.count {
            return tokens[currentIndex].position
        } else if !tokens.isEmpty {
            return tokens.last!.position
        } else {
            return SourcePosition(line: 1, column: 1, offset: 0)
        }
    }
}

// MARK: - Enhanced TokenStream Extensions

extension TokenStreamProtocol {

    /// Collects all remaining tokens into an array
    /// - Returns: Array of all remaining tokens
    /// - Throws: Any tokenization errors
    public mutating func collectAll() throws -> [Token] {
        var stream: any TokenStreamProtocol = self
        return try TokenStreamAdapter.collectTokens(from: &stream)
    }

    /// Filters tokens by type, returning a new stream
    /// - Parameter predicate: Function to test each token
    /// - Returns: A filtered token stream
    public func filter(_ predicate: @escaping @Sendable (Token) -> Bool) -> FilteredTokenStream {
        return FilteredTokenStream(source: self, predicate: predicate)
    }

    /// Maps tokens to a different type
    /// - Parameter transform: Function to transform each token
    /// - Returns: A mapped sequence
    public func map<T>(_ transform: @escaping (Token) throws -> T) -> MappedTokenSequence<T> {
        return MappedTokenSequence(source: self, transform: transform)
    }

    /// Skips tokens of specified types
    /// - Parameter types: Token types to skip
    /// - Returns: A filtered token stream
    public func skipping(_ types: Set<TokenType>) -> FilteredTokenStream {
        return filter { !types.contains($0.type) }
    }

    /// Convenience method to skip whitespace and comments
    /// - Returns: A filtered token stream without whitespace and comments
    public func skippingTrivia() -> FilteredTokenStream {
        return skipping([.whitespace, .comment, .newline])
    }
}

// MARK: - Filtered Token Stream

/// A token stream that filters tokens based on a predicate
public struct FilteredTokenStream: TokenStreamProtocol {
    private var source: any TokenStreamProtocol
    private let predicate: @Sendable (Token) -> Bool
    private var peekedToken: Token?

    public init(source: any TokenStreamProtocol, predicate: @escaping @Sendable (Token) -> Bool) {
        self.source = source
        self.predicate = predicate
    }

    public mutating func nextToken() throws -> Token? {
        if let peeked = peekedToken {
            peekedToken = nil
            return peeked
        }

        while let token = try source.nextToken() {
            if predicate(token) {
                return token
            }
        }

        return nil
    }

    public mutating func peek() throws -> Token? {
        if peekedToken == nil {
            peekedToken = try nextToken()
        }
        return peekedToken
    }

    public func position() -> SourcePosition {
        return source.position()
    }
}

// MARK: - Mapped Token Sequence

/// A sequence that transforms tokens from a TokenStream
public struct MappedTokenSequence<T>: Sequence {
    public typealias Element = T
    public typealias Iterator = MappedTokenSequence<T>.TokenIterator

    private var source: any TokenStreamProtocol
    private let transform: (Token) throws -> T

    public init(source: any TokenStreamProtocol, transform: @escaping (Token) throws -> T) {
        self.source = source
        self.transform = transform
    }

    public func makeIterator() -> TokenIterator {
        return TokenIterator(source: source, transform: transform)
    }

    public struct TokenIterator: IteratorProtocol {
        public typealias Element = T

        private var source: any TokenStreamProtocol
        private let transform: (Token) throws -> T

        init(source: any TokenStreamProtocol, transform: @escaping (Token) throws -> T) {
            self.source = source
            self.transform = transform
        }

        public mutating func next() -> T? {
            do {
                if let token = try source.nextToken() {
                    return try transform(token)
                }
                return nil
            } catch {
                // In case of error, we'll return nil to conform to IteratorProtocol
                // In a production system, you might want to log the error
                return nil
            }
        }
    }
}

// MARK: - Performance Monitoring

/// Performance metrics for TokenStream operations
public struct TokenStreamMetrics: Sendable {
    public let tokensProcessed: Int
    public let processingTime: TimeInterval
    public let memoryUsage: Int // Estimated bytes

    public var throughput: Double {
        guard processingTime > 0 else { return 0 }
        return Double(tokensProcessed) / processingTime
    }

    public init(tokensProcessed: Int, processingTime: TimeInterval, memoryUsage: Int = 0) {
        self.tokensProcessed = tokensProcessed
        self.processingTime = processingTime
        self.memoryUsage = memoryUsage
    }
}

/// A TokenStream wrapper that measures performance
public struct MeasuredTokenStream: TokenStreamProtocol {
    private var source: any TokenStreamProtocol
    private var metrics: TokenStreamMetrics
    private let startTime: CFAbsoluteTime
    private var tokenCounter: Int // Tracks tokens since last metrics update
    private let updateThreshold: Int // Number of tokens to process before updating metrics

    public init(source: any TokenStreamProtocol, updateThreshold: Int = 100) {
        self.source = source
        self.startTime = CFAbsoluteTimeGetCurrent()
        self.metrics = TokenStreamMetrics(tokensProcessed: 0, processingTime: 0)
        self.tokenCounter = 0
        self.updateThreshold = updateThreshold
    }

    public mutating func nextToken() throws -> Token? {
        let token = try source.nextToken()
        if token != nil {
            tokenCounter += 1
            if tokenCounter >= updateThreshold {
                let elapsed = CFAbsoluteTimeGetCurrent() - startTime
                metrics = TokenStreamMetrics(
                    tokensProcessed: metrics.tokensProcessed + tokenCounter,
                    processingTime: elapsed,
                    memoryUsage: metrics.memoryUsage
                )
                tokenCounter = 0
            }
        } else if tokenCounter > 0 {
            // Final update when the stream is exhausted
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            metrics = TokenStreamMetrics(
                tokensProcessed: metrics.tokensProcessed + tokenCounter,
                processingTime: elapsed,
                memoryUsage: metrics.memoryUsage
            )
            tokenCounter = 0
        }
        return token
    }

    public mutating func peek() throws -> Token? {
        return try source.peek()
    }

    public func position() -> SourcePosition {
        return source.position()
    }

    /// Get current performance metrics
    public func getMetrics() -> TokenStreamMetrics {
        return metrics
    }
}

// MARK: - Integration Helpers

extension SimpleStreamingTokenizer {

    /// Creates a streaming tokenizer with the same interface as existing tokenizers
    /// for easy migration
    /// - Parameter input: Source code to tokenize
    /// - Returns: Array of tokens for backward compatibility
    /// - Throws: Tokenization errors
    public static func tokenize(_ input: String) throws -> [Token] {
        var tokenizer: any TokenStreamProtocol = SimpleStreamingTokenizer(source: input)
        return try TokenStreamAdapter.collectTokens(from: &tokenizer)
    }

    /// Creates a measured tokenizer for performance analysis
    /// - Parameters:
    ///   - source: Source code to tokenize
    ///   - bufferSize: Buffer size for the tokenizer
    /// - Returns: A measured token stream
    public static func createMeasured(source: String, bufferSize: Int = 8192) -> MeasuredTokenStream {
        let tokenizer = SimpleStreamingTokenizer(source: source, bufferSize: bufferSize)
        return MeasuredTokenStream(source: tokenizer)
    }
}
