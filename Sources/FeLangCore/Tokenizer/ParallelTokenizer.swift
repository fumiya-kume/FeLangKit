import Foundation

// MARK: - Parallel Tokenizer

/// A tokenizer that uses parallel processing for large files
public actor ParallelTokenizer: StreamingTokenizer {
    private let pool: TokenizerPool
    private let chunkProcessor: ChunkProcessor
    private let coordinator: TokenizationCoordinator

    public init(
        poolSize: Int = ProcessInfo.processInfo.processorCount,
        chunkSize: Int = 8192
    ) {
        self.pool = TokenizerPool(size: poolSize)
        self.chunkProcessor = ChunkProcessor(chunkSize: chunkSize)
        self.coordinator = TokenizationCoordinator()
    }

    // MARK: - StreamingTokenizer Implementation

    public func tokenize<S: AsyncSequence & Sendable>(
        _ input: S
    ) async throws -> AsyncStream<Token> where S.Element == Character {
        let bufferManager = BufferManager()
        var currentState = TokenizerState(
            position: SourcePosition(line: 1, column: 1, offset: 0),
            lexerState: .initial
        )

        return AsyncStream(Token.self) { continuation in
            Task {
                do {
                    for try await character in input {
                        await bufferManager.append(String(character))

                        if await bufferManager.hasMinimumContent() {
                            let content = await bufferManager.getContent()
                            let tokens = try await processChunk(content, state: currentState)

                            for token in tokens.tokens {
                                continuation.yield(token)
                            }

                            currentState = tokens.finalState
                            await bufferManager.clearProcessed(upTo: content.endIndex)
                        }
                    }

                    // Process remaining content
                    let remainingContent = await bufferManager.getContent()
                    if !remainingContent.isEmpty {
                        let tokens = try await processChunk(remainingContent, state: currentState)
                        for token in tokens.tokens {
                            continuation.yield(token)
                        }
                    }

                    continuation.finish()
                } catch {
                    // AsyncStream doesn't support throwing errors in the continuation
                    continuation.finish()
                }
            }
        }
    }

    public func tokenize(
        bytes: Data,
        encoding: String.Encoding
    ) async throws -> AsyncStream<Token> {
        guard let string = String(data: bytes, encoding: encoding) else {
            throw TokenizerError.invalidEncoding
        }

        return try await tokenizeInParallel(string)
    }

    public func resume(
        from state: TokenizerState
    ) async throws -> AsyncStream<Token> {
        // For resumption, we start with the buffered content from the state
        let input = state.bufferedContent.async
        return try await tokenize(input)
    }

    // MARK: - Parallel Processing

    /// Tokenizes a large string using parallel processing
    public func tokenizeInParallel(
        _ input: String,
        chunkSize: Int? = nil
    ) async throws -> AsyncStream<Token> {
        let effectiveChunkSize = chunkSize ?? chunkProcessor.chunkSize

        // For small inputs, use single-threaded processing
        if input.count < effectiveChunkSize * 2 {
            return AsyncStream(Token.self) { continuation in
                Task {
                    do {
                        let tokenizer = await pool.borrowTokenizer()
                        let tokens = try tokenizer.tokenize(input)
                        await pool.returnTokenizer(tokenizer)

                        for token in tokens {
                            continuation.yield(token)
                        }
                        continuation.finish()
                    } catch {
                        // AsyncStream doesn't support throwing errors in the continuation
                        continuation.finish()
                    }
                }
            }
        }

        // Split into chunks for parallel processing
        let chunks = chunkProcessor.createChunks(from: input)

        return AsyncStream(Token.self) { continuation in
            Task {
                do {
                    let results = try await coordinator.processChunksInParallel(
                        chunks: chunks,
                        using: pool
                    )

                    // Merge results and stream tokens in order
                    let mergedTokens = try await coordinator.mergeResults(results)

                    for token in mergedTokens {
                        continuation.yield(token)
                    }
                    continuation.finish()
                } catch {
                    // AsyncStream doesn't support throwing errors in the continuation
                    continuation.finish()
                }
            }
        }
    }

    // MARK: - Private Methods

    private func processChunk(
        _ content: String,
        state: TokenizerState
    ) async throws -> ChunkTokenizationResult {
        let tokenizer = await pool.borrowTokenizer()
        defer { Task { await pool.returnTokenizer(tokenizer) } }

        let tokens = try tokenizer.tokenize(content)

        // Calculate final state after processing this chunk
        let finalState = calculateFinalState(from: state, after: tokens, content: content)

        return ChunkTokenizationResult(tokens: tokens, finalState: finalState)
    }

    private func calculateFinalState(
        from initialState: TokenizerState,
        after tokens: [Token],
        content: String
    ) -> TokenizerState {
        // Find the last token's position
        let lastPosition = tokens.last?.position ?? initialState.position

        // Update lexer state based on the last token
        var newLexerState = initialState.lexerState

        // Check if we ended inside a string or comment
        if let lastToken = tokens.last {
            switch lastToken.type {
            case .stringLiteral:
                // Check if string is properly closed
                if !lastToken.lexeme.hasSuffix("'") {
                    newLexerState = LexerState(inStringLiteral: true)
                }
            case .comment:
                // Check if comment is properly closed
                if lastToken.lexeme.hasPrefix("/*") && !lastToken.lexeme.hasSuffix("*/") {
                    newLexerState = LexerState(inComment: true, commentType: .multiLine)
                }
            default:
                newLexerState = .initial
            }
        }

        return TokenizerState(
            position: lastPosition,
            lexerState: newLexerState,
            bufferOffset: initialState.bufferOffset + content.count
        )
    }
}

// MARK: - Tokenizer Pool

/// Actor that manages a pool of tokenizers for parallel processing
public actor TokenizerPool {
    private var availableTokenizers: [ParsingTokenizer] = []
    private var busyCount: Int = 0
    private let maxSize: Int

    public init(size: Int) {
        self.maxSize = size

        // Pre-populate the pool
        for _ in 0..<size {
            availableTokenizers.append(ParsingTokenizer())
        }
    }

    /// Borrows a tokenizer from the pool
    public func borrowTokenizer() async -> ParsingTokenizer {
        if availableTokenizers.isEmpty {
            // Create a new tokenizer if pool is exhausted
            busyCount += 1
            return ParsingTokenizer()
        }

        let tokenizer = availableTokenizers.removeLast()
        busyCount += 1
        return tokenizer
    }

    /// Returns a tokenizer to the pool
    public func returnTokenizer(_ tokenizer: ParsingTokenizer) {
        busyCount = max(0, busyCount - 1)

        if availableTokenizers.count < maxSize {
            availableTokenizers.append(tokenizer)
        }
        // If pool is full, let the tokenizer be deallocated
    }

    /// Gets current pool statistics
    public func getStatistics() -> PoolStatistics {
        return PoolStatistics(
            available: availableTokenizers.count,
            busy: busyCount,
            maxSize: maxSize
        )
    }
}

// MARK: - Tokenization Coordinator

/// Coordinates parallel tokenization and merging of results
public actor TokenizationCoordinator {

    /// Processes chunks in parallel and returns ordered results
    public func processChunksInParallel(
        chunks: [ChunkInfo],
        using pool: TokenizerPool
    ) async throws -> [ChunkTokenizationResult] {
        // Process chunks concurrently
        let tasks = chunks.enumerated().map { (index, chunk) in
            Task<(Int, ChunkTokenizationResult), Error> {
                let tokenizer = await pool.borrowTokenizer()
                defer { Task { await pool.returnTokenizer(tokenizer) } }

                let tokens = try tokenizer.tokenize(chunk.content)
                let adjustedTokens = adjustTokenPositions(
                    tokens: tokens,
                    baseOffset: chunk.startOffset
                )

                let result = ChunkTokenizationResult(
                    tokens: adjustedTokens,
                    finalState: TokenizerState(
                        position: adjustedTokens.last?.position ?? SourcePosition(line: 1, column: 1, offset: 0),
                        lexerState: .initial
                    )
                )

                return (index, result)
            }
        }

        // Collect results in order
        var results: [ChunkTokenizationResult?] = Array(repeating: nil, count: chunks.count)

        for task in tasks {
            let (index, result) = try await task.value
            results[index] = result
        }

        return results.compactMap { $0 }
    }

    /// Merges tokenization results from multiple chunks
    public func mergeResults(
        _ results: [ChunkTokenizationResult]
    ) async throws -> [Token] {
        var mergedTokens: [Token] = []
        var overlappingBoundaries: [TokenBoundary] = []

        for (index, result) in results.enumerated() {
            if index == 0 {
                // First chunk - add all tokens
                mergedTokens.append(contentsOf: result.tokens)
            } else {
                // Subsequent chunks - handle overlaps
                let previousChunk = results[index - 1]
                let boundary = detectBoundary(
                    previous: previousChunk,
                    current: result
                )

                overlappingBoundaries.append(boundary)

                // Add tokens after removing overlap
                let nonOverlappingTokens = removeOverlap(
                    tokens: result.tokens,
                    boundary: boundary
                )

                mergedTokens.append(contentsOf: nonOverlappingTokens)
            }
        }

        // Post-process to fix any boundary issues
        return fixBoundaryTokens(mergedTokens, boundaries: overlappingBoundaries)
    }

    // MARK: - Private Methods

    private func adjustTokenPositions(
        tokens: [Token],
        baseOffset: Int
    ) -> [Token] {
        return tokens.map { token in
            let adjustedPosition = SourcePosition(
                line: token.position.line,
                column: token.position.column,
                offset: token.position.offset + baseOffset
            )

            return Token(
                type: token.type,
                lexeme: token.lexeme,
                position: adjustedPosition
            )
        }
    }

    private func detectBoundary(
        previous: ChunkTokenizationResult,
        current: ChunkTokenizationResult
    ) -> TokenBoundary {
        // Detect where the overlap begins between chunks
        let overlapThreshold = 512 // Character overlap size

        return TokenBoundary(
            overlapStart: max(0, previous.tokens.count - 10), // Last 10 tokens of previous
            overlapEnd: min(10, current.tokens.count), // First 10 tokens of current
            characterThreshold: overlapThreshold
        )
    }

    private func removeOverlap(
        tokens: [Token],
        boundary: TokenBoundary
    ) -> [Token] {
        // Remove tokens that are likely overlapping with the previous chunk
        return Array(tokens.dropFirst(boundary.overlapEnd))
    }

    private func fixBoundaryTokens(
        _ tokens: [Token],
        boundaries: [TokenBoundary]
    ) -> [Token] {
        // Post-process to fix any tokenization inconsistencies at chunk boundaries
        // This is a simplified implementation - in practice, you might need more sophisticated merging
        return tokens
    }
}

// MARK: - Supporting Types

/// Result of tokenizing a chunk
public struct ChunkTokenizationResult: Sendable {
    /// Tokens produced from the chunk
    public let tokens: [Token]

    /// Final state after processing the chunk
    public let finalState: TokenizerState

    public init(tokens: [Token], finalState: TokenizerState) {
        self.tokens = tokens
        self.finalState = finalState
    }
}

/// Information about token boundaries between chunks
public struct TokenBoundary: Sendable {
    /// Start index of overlap in previous chunk
    public let overlapStart: Int

    /// End index of overlap in current chunk
    public let overlapEnd: Int

    /// Character threshold for overlap detection
    public let characterThreshold: Int

    public init(overlapStart: Int, overlapEnd: Int, characterThreshold: Int) {
        self.overlapStart = overlapStart
        self.overlapEnd = overlapEnd
        self.characterThreshold = characterThreshold
    }
}

/// Statistics about the tokenizer pool
public struct PoolStatistics: Sendable {
    /// Number of available tokenizers
    public let available: Int

    /// Number of busy tokenizers
    public let busy: Int

    /// Maximum pool size
    public let maxSize: Int

    /// Current utilization ratio
    public var utilization: Double {
        guard maxSize > 0 else { return 0 }
        return Double(busy) / Double(maxSize)
    }

    public init(available: Int, busy: Int, maxSize: Int) {
        self.available = available
        self.busy = busy
        self.maxSize = maxSize
    }
}

// MARK: - Extensions

extension String {
    /// Creates an async sequence of characters
    var async: AsyncCharacterSequence {
        AsyncCharacterSequence(string: self)
    }
}

/// Async sequence wrapper for String characters
public struct AsyncCharacterSequence: AsyncSequence, Sendable {
    public typealias Element = Character

    private let string: String

    init(string: String) {
        self.string = string
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(string: string)
    }

    public struct AsyncIterator: AsyncIteratorProtocol, Sendable {
        private var iterator: String.Iterator

        init(string: String) {
            self.iterator = string.makeIterator()
        }

        public mutating func next() async -> Character? {
            return iterator.next()
        }
    }
}

// MARK: - Error Extensions

extension TokenizerError {
    static let invalidEncoding = TokenizerError.unexpectedCharacter(
        UnicodeScalar(0)!,
        SourcePosition(line: 0, column: 0, offset: 0)
    )
}
