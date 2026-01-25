import Foundation
import Testing
@testable import FeLangCore

@Suite("TokenStreamAdapter Error Handling Tests")
struct TokenStreamAdapterErrorHandlingTests {

    // A mock token stream that throws an error after yielding some tokens
    struct ThrowingTokenStream: TokenStreamProtocol {
        let tokens: [Token]
        let errorToThrow: Error
        var index = 0
        
        mutating func nextToken() throws -> Token? {
            if index < tokens.count {
                let token = tokens[index]
                index += 1
                return token
            }
            throw errorToThrow
        }
        
        mutating func peek() throws -> Token? {
            if index < tokens.count {
                return tokens[index]
            }
            throw errorToThrow
        }
        
        func position() -> SourcePosition {
            return SourcePosition(line: 1, column: 1, offset: 0)
        }
    }
    
    struct MockError: Error, Equatable {}

    @Test func testMappedTokenSequenceSwallowsErrors() throws {
        // Setup
        let tokens = [Token(type: .integerLiteral, lexeme: "123", position: SourcePosition(line: 1, column: 1, offset: 0))]
        var stream = ThrowingTokenStream(tokens: tokens, errorToThrow: MockError())
        
        // When we map the sequence
        let sequence = stream.map { $0 }
        
        // MappedTokenSequence silently swallows errors and returns nil
        // So iterating should return the first token, then nil (error swallowed)
        var iterator = sequence.makeIterator()
        let firstToken = iterator.next()
        #expect(firstToken != nil)
        #expect(firstToken?.lexeme == "123")
        
        // The next call would trigger the error, but it's swallowed and returns nil
        let secondToken = iterator.next()
        #expect(secondToken == nil)
    }
}
