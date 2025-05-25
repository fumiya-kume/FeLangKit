import Foundation

// MARK: - Streaming Tokenizer Protocol

/// A protocol for tokenizers that support streaming processing of source code
public protocol StreamingTokenizer: Sendable {
    /// Tokenizes an async sequence of characters, producing an async stream of tokens
    func tokenize<S: AsyncSequence & Sendable>(
        _ input: S
    ) async throws -> AsyncStream<Token> where S.Element == Character

    /// Tokenizes a buffer of bytes with specified encoding
    func tokenize(
        bytes: Data,
        encoding: String.Encoding
    ) async throws -> AsyncStream<Token>

    /// Resumes tokenization from a saved state
    func resume(
        from state: TokenizerState
    ) async throws -> AsyncStream<Token>
}

// MARK: - Tokenizer State

/// Represents the state of a tokenizer that can be saved and restored
public struct TokenizerState: Codable, Sendable, Equatable {
    /// Current position in the source
    public let position: SourcePosition

    /// Internal lexer state
    public let lexerState: LexerState

    /// Partially tokenized content if any
    public let partialToken: PartialToken?

    /// Current buffer offset
    public let bufferOffset: Int

    /// Buffered content waiting to be processed
    public let bufferedContent: String

    public init(
        position: SourcePosition,
        lexerState: LexerState,
        partialToken: PartialToken? = nil,
        bufferOffset: Int = 0,
        bufferedContent: String = ""
    ) {
        self.position = position
        self.lexerState = lexerState
        self.partialToken = partialToken
        self.bufferOffset = bufferOffset
        self.bufferedContent = bufferedContent
    }
}

// MARK: - Lexer State

/// Internal state of the lexer
public struct LexerState: Codable, Sendable, Equatable {
    /// Whether we're inside a string literal
    public let inStringLiteral: Bool

    /// Whether we're inside a comment
    public let inComment: Bool

    /// Type of comment if inside one
    public let commentType: CommentType?

    /// Escape sequence state
    public let inEscapeSequence: Bool

    public init(
        inStringLiteral: Bool = false,
        inComment: Bool = false,
        commentType: CommentType? = nil,
        inEscapeSequence: Bool = false
    ) {
        self.inStringLiteral = inStringLiteral
        self.inComment = inComment
        self.commentType = commentType
        self.inEscapeSequence = inEscapeSequence
    }

    /// Default initial state
    public static let initial = LexerState()
}

// MARK: - Comment Type

/// Type of comment being processed
public enum CommentType: String, Codable, Sendable, CaseIterable {
    case singleLine = "//"
    case multiLine = "/*"
}

// MARK: - Partial Token

/// Represents a partially constructed token during streaming
public struct PartialToken: Codable, Sendable, Equatable {
    /// The token type being constructed
    public let type: TokenType

    /// Content accumulated so far
    public let content: String

    /// Starting position of the token
    public let startPosition: SourcePosition

    public init(type: TokenType, content: String, startPosition: SourcePosition) {
        self.type = type
        self.content = content
        self.startPosition = startPosition
    }
}

// MARK: - Chunk Processor

/// Processes chunks of input data for streaming tokenization
public struct ChunkProcessor: Sendable {
    public let chunkSize: Int
    public let overlapSize: Int

    public init(chunkSize: Int = 8192, overlapSize: Int = 1024) {
        self.chunkSize = chunkSize
        self.overlapSize = overlapSize
    }

    /// Splits input into overlapping chunks for safe processing
    public func createChunks(from input: String) -> [ChunkInfo] {
        var chunks: [ChunkInfo] = []
        let totalLength = input.count
        var startIndex = input.startIndex
        var globalOffset = 0

        while startIndex < input.endIndex {
            let remainingLength = input.distance(from: startIndex, to: input.endIndex)
            let currentChunkSize = min(chunkSize, remainingLength)

            let endIndex = input.index(startIndex, offsetBy: currentChunkSize)
            let content = String(input[startIndex..<endIndex])

            let chunk = ChunkInfo(
                content: content,
                startOffset: globalOffset,
                endOffset: globalOffset + currentChunkSize,
                isLast: endIndex == input.endIndex
            )

            chunks.append(chunk)

            // Move to next chunk with overlap
            if endIndex == input.endIndex {
                break
            }

            let nextStartOffset = max(currentChunkSize - overlapSize, 1)
            startIndex = input.index(startIndex, offsetBy: nextStartOffset)
            globalOffset += nextStartOffset
        }

        return chunks
    }
}

// MARK: - Chunk Info

/// Information about a chunk of input data
public struct ChunkInfo: Sendable, Equatable {
    /// Content of the chunk
    public let content: String

    /// Starting offset in the original input
    public let startOffset: Int

    /// Ending offset in the original input
    public let endOffset: Int

    /// Whether this is the last chunk
    public let isLast: Bool

    public init(content: String, startOffset: Int, endOffset: Int, isLast: Bool) {
        self.content = content
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.isLast = isLast
    }
}

// MARK: - Buffer Manager

/// Manages buffering for streaming tokenization
public actor BufferManager {
    private var buffer: String = ""
    private var capacity: Int

    public init(capacity: Int = 16384) {
        self.capacity = capacity
    }

    /// Adds content to the buffer
    public func append(_ content: String) {
        buffer.append(content)

        // Trim buffer if it exceeds capacity
        if buffer.count > capacity * 2 {
            let trimIndex = buffer.index(buffer.startIndex, offsetBy: capacity)
            buffer = String(buffer[trimIndex...])
        }
    }

    /// Gets the current buffer content
    public func getContent() -> String {
        return buffer
    }

    /// Clears processed content from the buffer
    public func clearProcessed(upTo index: String.Index) {
        if index < buffer.endIndex {
            buffer = String(buffer[index...])
        } else {
            buffer = ""
        }
    }

    /// Checks if buffer has enough content for tokenization
    public func hasMinimumContent() -> Bool {
        return buffer.count >= 1024 // Minimum content threshold
    }
}

// MARK: - Tokenizer Performance Metrics

/// Metrics for tracking tokenizer performance
public struct TokenizerMetrics: Sendable {
    /// Total characters processed
    public let charactersProcessed: Int

    /// Total tokens produced
    public let tokensProduced: Int

    /// Processing time in seconds
    public let processingTime: TimeInterval

    /// Peak memory usage in bytes (estimated)
    public let peakMemoryUsage: Int

    /// Throughput in characters per second
    public var throughput: Double {
        guard processingTime > 0 else { return 0 }
        return Double(charactersProcessed) / processingTime
    }

    public init(
        charactersProcessed: Int,
        tokensProduced: Int,
        processingTime: TimeInterval,
        peakMemoryUsage: Int
    ) {
        self.charactersProcessed = charactersProcessed
        self.tokensProduced = tokensProduced
        self.processingTime = processingTime
        self.peakMemoryUsage = peakMemoryUsage
    }
}
