import Testing
@testable import FeLangCore

@Suite("ParsingTokenizer Position Tests")
struct ParsingTokenizerPositionTests {

    private func tokenize(_ input: String) throws -> [Token] {
        try ParsingTokenizer.tokenize(input)
    }

    // MARK: - Basic Position Tests

    @Test func testEmptyInputEOFPosition() throws {
        let tokens = try tokenize("")
        #expect(tokens.count == 1)
        #expect(tokens[0].type == .eof)
        #expect(tokens[0].position.line == 1)
        #expect(tokens[0].position.column == 1)
        #expect(tokens[0].position.offset == 0)
    }

    @Test func testSingleTokenPosition() throws {
        let tokens = try tokenize("42")
        #expect(tokens.count == 2) // integerLiteral + EOF
        #expect(tokens[0].type == .integerLiteral)
        #expect(tokens[0].position.line == 1)
        #expect(tokens[0].position.column == 1)
        #expect(tokens[0].position.offset == 0)

        // EOF after "42"
        #expect(tokens[1].type == .eof)
        #expect(tokens[1].position.column == 3)
        #expect(tokens[1].position.offset == 2)
    }

    // MARK: - Multi-Line Tests

    @Test func testMultiLineTokenPositions() throws {
        let tokens = try tokenize("x\ny\nz")
        // x, y, z identifiers + EOF
        let identifiers = tokens.filter { $0.type == .identifier }
        #expect(identifiers.count == 3)

        #expect(identifiers[0].position.line == 1)
        #expect(identifiers[0].position.column == 1)

        #expect(identifiers[1].position.line == 2)
        #expect(identifiers[1].position.column == 1)

        #expect(identifiers[2].position.line == 3)
        #expect(identifiers[2].position.column == 1)
    }

    @Test func testUnicodeTokenPositionOffset() throws {
        let tokens = try tokenize("整数型 x")
        // 整数型 (keyword) + x (identifier) + EOF
        #expect(tokens.count >= 3)

        // First token: 整数型 keyword at start
        #expect(tokens[0].position.line == 1)
        #expect(tokens[0].position.column == 1)
        #expect(tokens[0].position.offset == 0)

        // Second token: x after "整数型 " (3 chars + 1 space = column 5)
        let xToken = tokens.first { $0.type == .identifier }
        #expect(xToken != nil)
        #expect(xToken?.position.column == 5)
    }

    // MARK: - Comment Position Tests

    @Test func testPositionAfterSingleLineComment() throws {
        let tokens = try tokenize("// comment\nx")
        let xToken = tokens.first { $0.type == .identifier }
        #expect(xToken != nil)
        #expect(xToken?.position.line == 2)
        #expect(xToken?.position.column == 1)
    }

    @Test func testPositionAfterMultiLineComment() throws {
        let tokens = try tokenize("/* line1\nline2 */\nx")
        let xToken = tokens.first { $0.type == .identifier }
        #expect(xToken != nil)
        #expect(xToken?.position.line == 3)
        #expect(xToken?.position.column == 1)
    }

    // MARK: - Consecutive Token Tests

    @Test func testPositionWithConsecutiveTokens() throws {
        let tokens = try tokenize("a + b")
        // a (identifier), + (plus), b (identifier), EOF
        let nonEOF = tokens.filter { $0.type != .eof }
        #expect(nonEOF.count == 3)

        #expect(nonEOF[0].position.column == 1) // "a" at col 1
        #expect(nonEOF[1].position.column == 3) // "+" at col 3
        #expect(nonEOF[2].position.column == 5) // "b" at col 5
    }

    @Test func testEOFPositionAtEndOfInput() throws {
        let tokens = try tokenize("abc")
        guard let eof = tokens.last else {
            Issue.record("Expected tokens")
            return
        }
        #expect(eof.type == .eof)
        #expect(eof.position.line == 1)
        #expect(eof.position.column == 4)
        #expect(eof.position.offset == 3)
    }
}
