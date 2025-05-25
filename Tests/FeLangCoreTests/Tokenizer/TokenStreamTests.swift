import Testing
@testable import FeLangCore

/// Tests for the TokenStream protocol implementation from GitHub Issue #9
struct TokenStreamTests {

    @Test("TokenStream protocol basic functionality")
    func testTokenStreamBasicFunctionality() throws {
        let source = "変数 x: 整数型 ← 42"
        var tokenizer = SimpleStreamingTokenizer(source: source)

        // Test nextToken()
        var tokens: [Token] = []
        while let token = try tokenizer.nextToken() {
            tokens.append(token)
            if token.type == .eof {
                break
            }
        }

        #expect(tokens.count == 7, "Should produce 7 tokens including EOF")
        #expect(tokens[0].type == .variableKeyword, "First token should be 変数")
        #expect(tokens[1].type == .identifier, "Second token should be identifier x")
        #expect(tokens[2].type == .colon, "Third token should be colon")
        #expect(tokens[3].type == .integerType, "Fourth token should be 整数型")
        #expect(tokens[4].type == .assign, "Fifth token should be assignment ←")
        #expect(tokens[5].type == .integerLiteral, "Sixth token should be integer 42")
        #expect(tokens[6].type == .eof, "Last token should be EOF")
    }

    @Test("TokenStream peek functionality")
    func testTokenStreamPeek() throws {
        let source = "if x = 5"
        var tokenizer = SimpleStreamingTokenizer(source: source)

        // Test peek without consuming
        let peeked1 = try tokenizer.peek()
        let peeked2 = try tokenizer.peek()
        #expect(peeked1?.type == .ifKeyword, "First peek should return 'if'")
        #expect(peeked2?.type == .ifKeyword, "Second peek should return same token")
        #expect(peeked1?.lexeme == peeked2?.lexeme, "Peek should return identical tokens")

        // Test that nextToken returns the peeked token
        let next = try tokenizer.nextToken()
        #expect(next?.type == .ifKeyword, "Next token should be the peeked token")
        #expect(next?.lexeme == "if", "Token lexeme should be 'if'")

        // Test peek after consuming
        let nextPeek = try tokenizer.peek()
        #expect(nextPeek?.type == .identifier, "Next peek should be identifier 'x'")
    }

    @Test("TokenStream position tracking")
    func testTokenStreamPosition() throws {
        let source = "x\ny"
        var tokenizer = SimpleStreamingTokenizer(source: source)

        let initialPos = tokenizer.position()
        #expect(initialPos.line == 1, "Initial position should be line 1")
        #expect(initialPos.column == 1, "Initial position should be column 1")

        _ = try tokenizer.nextToken() // consume 'x'

        let afterFirstToken = tokenizer.position()
        #expect(afterFirstToken.line == 1, "After first token should still be line 1")
        #expect(afterFirstToken.column == 2, "After first token should be column 2")

        _ = try tokenizer.nextToken() // consume 'y' (after newline)

        let afterSecondToken = tokenizer.position()
        #expect(afterSecondToken.line == 2, "After newline should be line 2")
        #expect(afterSecondToken.column == 2, "After second token should be column 2")
    }

    @Test("Circular buffer functionality")
    func testCircularBuffer() {
        var buffer = CircularBuffer<Int>(capacity: 3)

        #expect(buffer.isEmpty, "New buffer should be empty")
        #expect(!buffer.isFull, "New buffer should not be full")
        #expect(buffer.size == 0, "New buffer size should be 0")

        // Test pushing elements
        let push1 = buffer.push(1)
        #expect(push1, "Should be able to push first element")
        let push2 = buffer.push(2)
        #expect(push2, "Should be able to push second element")
        let push3 = buffer.push(3)
        #expect(push3, "Should be able to push third element")
        let push4 = buffer.push(4)
        #expect(!push4, "Should not be able to push when full")

        #expect(buffer.isFull, "Buffer should be full")
        #expect(buffer.size == 3, "Buffer size should be 3")

        // Test peeking
        #expect(buffer.peek() == 1, "First peek should return 1")
        #expect(buffer.peek(offset: 1) == 2, "Peek with offset 1 should return 2")
        #expect(buffer.peek(offset: 2) == 3, "Peek with offset 2 should return 3")

        // Test popping
        #expect(buffer.pop() == 1, "First pop should return 1")
        #expect(buffer.pop() == 2, "Second pop should return 2")
        #expect(buffer.size == 1, "Buffer size should be 1 after two pops")

        // Test circular behavior
        let push4Again = buffer.push(4)
        #expect(push4Again, "Should be able to push after popping")
        let push5 = buffer.push(5)
        #expect(push5, "Should be able to push second element")
        #expect(buffer.size == 3, "Buffer should be full again")
    }

    @Test("String source reader functionality")
    func testStringSourceReader() {
        var reader = SimpleStringReader(source: "ab\nc")

        #expect(!reader.isAtEnd, "Reader should not be at end initially")
        #expect(reader.position.line == 1, "Initial position should be line 1")
        #expect(reader.position.column == 1, "Initial position should be column 1")

        // Test character reading
        let char1 = reader.readChar()
        #expect(char1 == "a", "First character should be 'a'")
        #expect(reader.position.column == 2, "Position should advance to column 2")

        let char2 = reader.readChar()
        #expect(char2 == "b", "Second character should be 'b'")

        let char3 = reader.readChar()
        #expect(char3 == "\n", "Third character should be newline")
        #expect(reader.position.line == 2, "Position should advance to line 2")
        #expect(reader.position.column == 1, "Column should reset to 1 after newline")

        // Test peeking
        let peeked = reader.peekChar()
        #expect(peeked == "c", "Peek should return 'c'")

        let char4 = reader.readChar()
        #expect(char4 == "c", "Reading after peek should return 'c'")

        let char5 = reader.readChar()
        #expect(char5 == nil, "Reading beyond end should return nil")
        #expect(reader.isAtEnd, "Reader should be at end")
    }

    @Test("Complex tokenization with streaming")
    func testComplexTokenization() throws {
        let source = """
        // コメント
        function fibonacci(n: 整数型): 整数型
            if n ≦ 1 then
                return n
            else
                return fibonacci(n-1) + fibonacci(n-2)
            endif
        endfunction
        """

        var tokenizer = SimpleStreamingTokenizer(source: source)
        var tokens: [Token] = []

        while let token = try tokenizer.nextToken() {
            tokens.append(token)
            if token.type == .eof {
                break
            }
        }

        // Verify we get reasonable tokens
        #expect(!tokens.isEmpty, "Should produce tokens")
        #expect(tokens.last?.type == .eof, "Last token should be EOF")

        // Check for specific tokens
        let tokenTypes = tokens.map(\.type)
        #expect(tokenTypes.contains(.comment), "Should contain comment token")
        #expect(tokenTypes.contains(.functionKeyword), "Should contain function keyword")
        #expect(tokenTypes.contains(.identifier), "Should contain identifiers")
        #expect(tokenTypes.contains(.integerType), "Should contain integer type")
        #expect(tokenTypes.contains(.lessEqual), "Should contain ≦ operator")
        #expect(tokenTypes.contains(.returnKeyword), "Should contain return keyword")
    }

    @Test("Empty input handling")
    func testEmptyInput() throws {
        var tokenizer = SimpleStreamingTokenizer(source: "")

        let token = try tokenizer.nextToken()
        #expect(token?.type == .eof, "Empty input should return EOF token")

        let peek = try tokenizer.peek()
        #expect(peek?.type == .eof, "Peek on empty input should return EOF")
    }

    @Test("Whitespace-only input handling")
    func testWhitespaceOnlyInput() throws {
        var tokenizer = SimpleStreamingTokenizer(source: "   \n\t  \n  ")

        let token = try tokenizer.nextToken()
        #expect(token?.type == .eof, "Whitespace-only input should return EOF token")
    }

    @Test("Unicode support in streaming")
    func testUnicodeSupport() throws {
        let source = "変数 émoji: 文字列型 ← \"🚀Hello\""
        var tokenizer = SimpleStreamingTokenizer(source: source)

        var tokens: [Token] = []
        while let token = try tokenizer.nextToken() {
            tokens.append(token)
            if token.type == .eof {
                break
            }
        }

        #expect(tokens.count >= 6, "Should handle Unicode characters properly")
        #expect(tokens[0].lexeme == "変数", "Should preserve Japanese characters")
        #expect(tokens[1].lexeme == "émoji", "Should preserve accented characters")
        #expect(tokens[5].lexeme.contains("🚀"), "Should preserve emoji in string literals")
    }

    @Test("Error recovery in streaming")
    func testErrorRecovery() throws {
        // Test with invalid characters that should be handled gracefully
        let source = "valid_identifier @ invalid_char + another_valid"
        var tokenizer = SimpleStreamingTokenizer(source: source)

        var tokens: [Token] = []
        var tokenCount = 0

        // Should not crash and should produce some tokens
        while let token = try tokenizer.nextToken(), tokenCount < 10 {
            tokens.append(token)
            tokenCount += 1
            if token.type == .eof {
                break
            }
        }

        #expect(!tokens.isEmpty, "Should produce some tokens even with invalid characters")
        #expect(tokens.last?.type == .eof, "Should eventually reach EOF")
    }

    @Test("Memory efficiency with large buffer")
    func testMemoryEfficiencyWithLargeBuffer() throws {
        // Create a large input to test memory efficiency
        let largeSource = String(repeating: "x ", count: 5000) // 10k characters
        var tokenizer = SimpleStreamingTokenizer(source: largeSource, bufferSize: 1024)

        var tokenCount = 0
        while let token = try tokenizer.nextToken() {
            if token.type == .eof {
                break
            }
            tokenCount += 1

            // Stop after reasonable number to avoid infinite loops in tests
            if tokenCount > 10000 {
                break
            }
        }

        #expect(tokenCount == 5000, "Should process all tokens from large input")
    }
}
