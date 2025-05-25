import Testing
@testable import FeLangCore
import Foundation

@Suite("Streaming Tokenizer Tests")
struct StreamingTokenizerTests {

    @Test("Basic streaming tokenization")
    func testBasicStreamingTokenization() async throws {
        let parallelTokenizer = ParallelTokenizer()
        let input = "変数 x: 整数型\nx ← 42"

        var tokens: [Token] = []
        for try await token in try await parallelTokenizer.tokenizeInParallel(input) {
            tokens.append(token)
        }

        #expect(!tokens.isEmpty, "Should produce tokens")
        #expect(tokens.contains { $0.type == .identifier }, "Should contain identifier tokens")
        #expect(tokens.contains { $0.type == .assign }, "Should contain assignment token")
        #expect(tokens.contains { $0.type == .integerLiteral }, "Should contain number token")
    }

    @Test("Async sequence tokenization")
    func testAsyncSequenceTokenization() async throws {
        let parallelTokenizer = ParallelTokenizer()
        let input = "x ← 1 + 2"
        let asyncInput = input.async

        var tokens: [Token] = []
        for try await token in try await parallelTokenizer.tokenize(asyncInput) {
            tokens.append(token)
        }

        #expect(tokens.count >= 5, "Should produce at least 5 tokens")

        // Verify token types in order
        let tokenTypes = tokens.map(\.type)
        #expect(tokenTypes.contains(.identifier), "Should contain identifier")
        #expect(tokenTypes.contains(.assign), "Should contain assignment")
        #expect(tokenTypes.contains(.integerLiteral), "Should contain numbers")
        #expect(tokenTypes.contains(.plus), "Should contain plus operator")
    }

    @Test("Buffer tokenization")
    func testBufferTokenization() async throws {
        let parallelTokenizer = ParallelTokenizer()
        let input = "変数 test: 文字列型"
        let data = input.data(using: .utf8)!

        let tokens = try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    var tokenList: [Token] = []
                    for try await token in try await parallelTokenizer.tokenize(
                        bytes: data,
                        encoding: .utf8
                    ) {
                        tokenList.append(token)
                    }
                    continuation.resume(returning: tokenList)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        #expect(!tokens.isEmpty, "Should produce tokens from buffer")
    }

    @Test("State preservation and resumption")
    func testStatePreservationAndResumption() async throws {
        let parallelTokenizer = ParallelTokenizer()
        let state = TokenizerState(
            position: SourcePosition(line: 1, column: 1, offset: 0),
            lexerState: .initial,
            bufferedContent: "x ← 42"
        )

        var tokens: [Token] = []
        for try await token in try await parallelTokenizer.resume(from: state) {
            tokens.append(token)
        }

        #expect(!tokens.isEmpty, "Should resume tokenization from state")
    }

    @Test("Large file streaming")
    func testLargeFileStreaming() async throws {
        let parallelTokenizer = ParallelTokenizer()

        // Generate a large input
        var largeInput = ""
        for index in 0..<1000 {
            largeInput += "変数 var\(index): 整数型 ← \(index)\n"
        }

        var tokenCount = 0
        let startTime = CFAbsoluteTimeGetCurrent()

        for try await _ in try await parallelTokenizer.tokenizeInParallel(largeInput) {
            tokenCount += 1
        }

        let duration = CFAbsoluteTimeGetCurrent() - startTime

        #expect(tokenCount > 1000, "Should produce many tokens")
        #expect(duration < 5.0, "Should complete within reasonable time")
    }

    @Test("Chunk processor")
    func testChunkProcessor() {
        let processor = ChunkProcessor(chunkSize: 100, overlapSize: 20)
        let input = String(repeating: "a", count: 250)

        let chunks = processor.createChunks(from: input)

        #expect(chunks.count >= 2, "Should create multiple chunks")
        #expect(chunks.first?.startOffset == 0, "First chunk should start at 0")
        #expect(chunks.last?.isLast == true, "Last chunk should be marked as last")

        // Verify overlap
        for index in 1..<chunks.count {
            let prevEnd = chunks[index-1].endOffset
            let currentStart = chunks[index].startOffset
            #expect(prevEnd > currentStart, "Chunks should overlap")
        }
    }

    @Test("Buffer manager")
    func testBufferManager() async {
        let bufferManager = BufferManager(capacity: 2048)

        await bufferManager.append("Hello")
        let content1 = await bufferManager.getContent()
        #expect(content1 == "Hello", "Should store appended content")

        await bufferManager.append(" World")
        let content2 = await bufferManager.getContent()
        #expect(content2 == "Hello World", "Should append content")

        let hasMinimum = await bufferManager.hasMinimumContent()
        #expect(!hasMinimum, "Should not have minimum content yet")

        // Add enough content to exceed minimum (1024 threshold)
        await bufferManager.append(String(repeating: "x", count: 1025))
        let hasMinimumNow = await bufferManager.hasMinimumContent()
        #expect(hasMinimumNow, "Should have minimum content now")
    }

    @Test("Tokenizer state serialization")
    func testTokenizerStateSerialization() throws {
        let originalState = TokenizerState(
            position: SourcePosition(line: 5, column: 10, offset: 42),
            lexerState: LexerState(inStringLiteral: true, inComment: false),
            partialToken: PartialToken(
                type: .stringLiteral,
                content: "partial string",
                startPosition: SourcePosition(line: 5, column: 1, offset: 35)
            ),
            bufferOffset: 100,
            bufferedContent: "some buffered content"
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(originalState)
        let decodedState = try decoder.decode(TokenizerState.self, from: data)

        #expect(decodedState == originalState, "State should serialize and deserialize correctly")
    }

    @Test("Lexer state transitions")
    func testLexerStateTransitions() {
        let initialState = LexerState.initial
        #expect(!initialState.inStringLiteral, "Should start outside string")
        #expect(!initialState.inComment, "Should start outside comment")

        let stringState = LexerState(inStringLiteral: true)
        #expect(stringState.inStringLiteral, "Should be in string literal")

        let commentState = LexerState(inComment: true, commentType: .singleLine)
        #expect(commentState.inComment, "Should be in comment")
        #expect(commentState.commentType == .singleLine, "Should track comment type")
    }

    @Test("Partial token construction")
    func testPartialTokenConstruction() {
        let startPos = SourcePosition(line: 1, column: 1, offset: 0)
        let partialToken = PartialToken(
            type: .identifier,
            content: "partialIdent",
            startPosition: startPos
        )

        #expect(partialToken.type == .identifier, "Should preserve token type")
        #expect(partialToken.content == "partialIdent", "Should preserve content")
        #expect(partialToken.startPosition == startPos, "Should preserve start position")
    }

    @Test("Comment type enumeration")
    func testCommentTypeEnumeration() {
        #expect(CommentType.singleLine.rawValue == "//", "Single line comment should have correct value")
        #expect(CommentType.multiLine.rawValue == "/*", "Multi line comment should have correct value")

        let allTypes = CommentType.allCases
        #expect(allTypes.count == 2, "Should have exactly 2 comment types")
        #expect(allTypes.contains(.singleLine), "Should contain single line type")
        #expect(allTypes.contains(.multiLine), "Should contain multi line type")
    }

    @Test("Chunk info validation")
    func testChunkInfoValidation() {
        let chunk = ChunkInfo(
            content: "test content",
            startOffset: 10,
            endOffset: 22,
            isLast: false
        )

        #expect(chunk.content == "test content", "Should preserve content")
        #expect(chunk.startOffset == 10, "Should preserve start offset")
        #expect(chunk.endOffset == 22, "Should preserve end offset")
        #expect(!chunk.isLast, "Should preserve last flag")

        let lastChunk = ChunkInfo(
            content: "final chunk",
            startOffset: 20,
            endOffset: 31,
            isLast: true
        )

        #expect(lastChunk.isLast, "Last chunk should be marked correctly")
    }

    @Test("Tokenizer metrics calculation")
    func testTokenizerMetricsCalculation() {
        let metrics = TokenizerMetrics(
            charactersProcessed: 1000,
            tokensProduced: 200,
            processingTime: 0.5,
            peakMemoryUsage: 1024
        )

        #expect(metrics.charactersProcessed == 1000, "Should preserve character count")
        #expect(metrics.tokensProduced == 200, "Should preserve token count")
        #expect(metrics.processingTime == 0.5, "Should preserve processing time")
        #expect(metrics.peakMemoryUsage == 1024, "Should preserve memory usage")

        let expectedThroughput = 2000.0 // 1000 chars / 0.5 seconds
        #expect(abs(metrics.throughput - expectedThroughput) < 0.001, "Should calculate throughput correctly")
    }

    @Test("Empty input handling")
    func testEmptyInputHandling() async throws {
        let parallelTokenizer = ParallelTokenizer()
        let emptyInput = ""

        var tokens: [Token] = []
        for try await token in try await parallelTokenizer.tokenizeInParallel(emptyInput) {
            tokens.append(token)
        }

        // Should produce exactly one EOF token
        #expect(tokens.count == 1, "Should produce exactly one token for empty input")
        #expect(tokens.first?.type == .eof, "The single token should be an EOF token")
    }

    @Test("Unicode handling in streaming")
    func testUnicodeHandlingInStreaming() async throws {
        let parallelTokenizer = ParallelTokenizer()
        let unicodeInput = "変数 émojis: 文字列型 ← '🚀🌟'"

        var tokens: [Token] = []
        for try await token in try await parallelTokenizer.tokenizeInParallel(unicodeInput) {
            tokens.append(token)
        }

        #expect(!tokens.isEmpty, "Should handle Unicode characters")

        // Verify that Unicode characters are preserved in lexemes
        let lexemes = tokens.map(\.lexeme)
        #expect(lexemes.contains("変数"), "Should preserve Japanese characters")
        #expect(lexemes.contains("émojis"), "Should preserve accented characters")
        #expect(lexemes.contains { $0.contains("🚀") }, "Should preserve emoji characters")
    }
}
