import Foundation
import Testing
@testable import FeLangCore

@Suite("ParsingBoundaryDetection Tests")
struct ParsingBoundaryDetectionTests {

    // MARK: - Statement Terminator Tests

    @Test func testNewlineAsTerminator() throws {
        #expect(ParsingBoundaryDetection.isStatementTerminator(.newline) == true)
    }

    @Test func testEOFAsTerminator() throws {
        #expect(ParsingBoundaryDetection.isStatementTerminator(.eof) == true)
    }

    @Test func testThenKeywordAsTerminator() throws {
        #expect(ParsingBoundaryDetection.isStatementTerminator(.thenKeyword) == true)
    }

    @Test func testElseKeywordAsTerminator() throws {
        #expect(ParsingBoundaryDetection.isStatementTerminator(.elseKeyword) == true)
    }

    @Test func testDoKeywordAsTerminator() throws {
        #expect(ParsingBoundaryDetection.isStatementTerminator(.doKeyword) == true)
    }

    @Test func testBlockEndKeywordsAsTerminators() throws {
        #expect(ParsingBoundaryDetection.isStatementTerminator(.endifKeyword) == true)
        #expect(ParsingBoundaryDetection.isStatementTerminator(.endwhileKeyword) == true)
        #expect(ParsingBoundaryDetection.isStatementTerminator(.endforKeyword) == true)
        #expect(ParsingBoundaryDetection.isStatementTerminator(.endfunctionKeyword) == true)
        #expect(ParsingBoundaryDetection.isStatementTerminator(.endprocedureKeyword) == true)
    }

    @Test func testForLoopKeywordsAsTerminators() throws {
        #expect(ParsingBoundaryDetection.isStatementTerminator(.toKeyword) == true)
        #expect(ParsingBoundaryDetection.isStatementTerminator(.stepKeyword) == true)
        #expect(ParsingBoundaryDetection.isStatementTerminator(.inKeyword) == true)
    }

    @Test func testCommaAsTerminator() throws {
        #expect(ParsingBoundaryDetection.isStatementTerminator(.comma) == true)
    }

    @Test func testNonTerminatorTokens() throws {
        #expect(ParsingBoundaryDetection.isStatementTerminator(.identifier) == false)
        #expect(ParsingBoundaryDetection.isStatementTerminator(.integerLiteral) == false)
        #expect(ParsingBoundaryDetection.isStatementTerminator(.plus) == false)
        #expect(ParsingBoundaryDetection.isStatementTerminator(.leftParen) == false)
    }

    // MARK: - Statement Start Detection Tests

    @Test func testAssignmentPatternDetection() throws {
        let tokens = [
            Token(type: .identifier, lexeme: "x", position: SourcePosition(line: 1, column: 1, offset: 0)),
            Token(type: .assign, lexeme: "←", position: SourcePosition(line: 1, column: 3, offset: 2)),
            Token(type: .integerLiteral, lexeme: "42", position: SourcePosition(line: 1, column: 5, offset: 4))
        ]

        #expect(ParsingBoundaryDetection.isStartOfNewStatement(tokens, at: 0) == true)
    }

    @Test func testControlFlowKeywordsStartStatement() throws {
        let ifToken = [Token(type: .ifKeyword, lexeme: "if", position: SourcePosition(line: 1, column: 1, offset: 0))]
        let whileToken = [Token(type: .whileKeyword, lexeme: "while", position: SourcePosition(line: 1, column: 1, offset: 0))]
        let forToken = [Token(type: .forKeyword, lexeme: "for", position: SourcePosition(line: 1, column: 1, offset: 0))]

        #expect(ParsingBoundaryDetection.isStartOfNewStatement(ifToken, at: 0) == true)
        #expect(ParsingBoundaryDetection.isStartOfNewStatement(whileToken, at: 0) == true)
        #expect(ParsingBoundaryDetection.isStartOfNewStatement(forToken, at: 0) == true)
    }

    @Test func testDeclarationKeywordsStartStatement() throws {
        let varToken = [Token(type: .variableKeyword, lexeme: "変数", position: SourcePosition(line: 1, column: 1, offset: 0))]
        let constToken = [Token(type: .constantKeyword, lexeme: "定数", position: SourcePosition(line: 1, column: 1, offset: 0))]
        let funcToken = [Token(type: .functionKeyword, lexeme: "関数", position: SourcePosition(line: 1, column: 1, offset: 0))]
        let procToken = [Token(type: .procedureKeyword, lexeme: "手続き", position: SourcePosition(line: 1, column: 1, offset: 0))]

        #expect(ParsingBoundaryDetection.isStartOfNewStatement(varToken, at: 0) == true)
        #expect(ParsingBoundaryDetection.isStartOfNewStatement(constToken, at: 0) == true)
        #expect(ParsingBoundaryDetection.isStartOfNewStatement(funcToken, at: 0) == true)
        #expect(ParsingBoundaryDetection.isStartOfNewStatement(procToken, at: 0) == true)
    }

    @Test func testFlowControlKeywordsStartStatement() throws {
        let returnToken = [Token(type: .returnKeyword, lexeme: "return", position: SourcePosition(line: 1, column: 1, offset: 0))]
        let breakToken = [Token(type: .breakKeyword, lexeme: "break", position: SourcePosition(line: 1, column: 1, offset: 0))]

        #expect(ParsingBoundaryDetection.isStartOfNewStatement(returnToken, at: 0) == true)
        #expect(ParsingBoundaryDetection.isStartOfNewStatement(breakToken, at: 0) == true)
    }

    // MARK: - Expression Boundary Detection Tests

    @Test func testFindExpressionBoundarySimple() throws {
        let tokens = [
            Token(type: .identifier, lexeme: "x", position: SourcePosition(line: 1, column: 1, offset: 0)),
            Token(type: .plus, lexeme: "+", position: SourcePosition(line: 1, column: 3, offset: 2)),
            Token(type: .integerLiteral, lexeme: "1", position: SourcePosition(line: 1, column: 5, offset: 4)),
            Token(type: .eof, lexeme: "", position: SourcePosition(line: 1, column: 6, offset: 5))
        ]

        let boundary = ParsingBoundaryDetection.findExpressionBoundary(in: tokens, startingAt: 0)
        #expect(boundary == 3) // EOF position
    }

    @Test func testFindExpressionBoundaryWithParentheses() throws {
        let tokens = [
            Token(type: .leftParen, lexeme: "(", position: SourcePosition(line: 1, column: 1, offset: 0)),
            Token(type: .identifier, lexeme: "x", position: SourcePosition(line: 1, column: 2, offset: 1)),
            Token(type: .plus, lexeme: "+", position: SourcePosition(line: 1, column: 4, offset: 3)),
            Token(type: .integerLiteral, lexeme: "1", position: SourcePosition(line: 1, column: 6, offset: 5)),
            Token(type: .rightParen, lexeme: ")", position: SourcePosition(line: 1, column: 7, offset: 6)),
            Token(type: .thenKeyword, lexeme: "then", position: SourcePosition(line: 1, column: 9, offset: 8)),
            Token(type: .eof, lexeme: "", position: SourcePosition(line: 1, column: 13, offset: 12))
        ]

        let boundary = ParsingBoundaryDetection.findExpressionBoundary(in: tokens, startingAt: 0)
        #expect(boundary == 5) // then keyword position
    }

    @Test func testFindExpressionBoundaryNested() throws {
        let tokens = [
            Token(type: .leftParen, lexeme: "(", position: SourcePosition(line: 1, column: 1, offset: 0)),
            Token(type: .leftParen, lexeme: "(", position: SourcePosition(line: 1, column: 2, offset: 1)),
            Token(type: .identifier, lexeme: "x", position: SourcePosition(line: 1, column: 3, offset: 2)),
            Token(type: .rightParen, lexeme: ")", position: SourcePosition(line: 1, column: 4, offset: 3)),
            Token(type: .rightParen, lexeme: ")", position: SourcePosition(line: 1, column: 5, offset: 4)),
            Token(type: .eof, lexeme: "", position: SourcePosition(line: 1, column: 6, offset: 5))
        ]

        let boundary = ParsingBoundaryDetection.findExpressionBoundary(in: tokens, startingAt: 0)
        #expect(boundary == 5) // EOF position
    }

    // MARK: - Balance Validation Tests

    @Test func testBalancedParentheses() throws {
        let tokens: ArraySlice<Token> = [
            Token(type: .leftParen, lexeme: "(", position: SourcePosition(line: 1, column: 1, offset: 0)),
            Token(type: .identifier, lexeme: "x", position: SourcePosition(line: 1, column: 2, offset: 1)),
            Token(type: .rightParen, lexeme: ")", position: SourcePosition(line: 1, column: 3, offset: 2))
        ][...]

        #expect(ParsingBoundaryDetection.hasBalancedParentheses(tokens) == true)
    }

    @Test func testUnbalancedParentheses() throws {
        let tokens: ArraySlice<Token> = [
            Token(type: .leftParen, lexeme: "(", position: SourcePosition(line: 1, column: 1, offset: 0)),
            Token(type: .identifier, lexeme: "x", position: SourcePosition(line: 1, column: 2, offset: 1))
        ][...]

        #expect(ParsingBoundaryDetection.hasBalancedParentheses(tokens) == false)
    }

    @Test func testBalancedBrackets() throws {
        let tokens: ArraySlice<Token> = [
            Token(type: .leftBracket, lexeme: "[", position: SourcePosition(line: 1, column: 1, offset: 0)),
            Token(type: .integerLiteral, lexeme: "0", position: SourcePosition(line: 1, column: 2, offset: 1)),
            Token(type: .rightBracket, lexeme: "]", position: SourcePosition(line: 1, column: 3, offset: 2))
        ][...]

        #expect(ParsingBoundaryDetection.hasBalancedBrackets(tokens) == true)
    }

    @Test func testValidBalancedExpression() throws {
        let tokens: ArraySlice<Token> = [
            Token(type: .leftParen, lexeme: "(", position: SourcePosition(line: 1, column: 1, offset: 0)),
            Token(type: .identifier, lexeme: "arr", position: SourcePosition(line: 1, column: 2, offset: 1)),
            Token(type: .leftBracket, lexeme: "[", position: SourcePosition(line: 1, column: 5, offset: 4)),
            Token(type: .integerLiteral, lexeme: "0", position: SourcePosition(line: 1, column: 6, offset: 5)),
            Token(type: .rightBracket, lexeme: "]", position: SourcePosition(line: 1, column: 7, offset: 6)),
            Token(type: .rightParen, lexeme: ")", position: SourcePosition(line: 1, column: 8, offset: 7))
        ][...]

        #expect(ParsingBoundaryDetection.isValidBalancedExpression(tokens) == true)
    }

    @Test func testInvalidUnbalancedExpression() throws {
        let tokens: ArraySlice<Token> = [
            Token(type: .leftParen, lexeme: "(", position: SourcePosition(line: 1, column: 1, offset: 0)),
            Token(type: .leftBracket, lexeme: "[", position: SourcePosition(line: 1, column: 2, offset: 1)),
            Token(type: .rightParen, lexeme: ")", position: SourcePosition(line: 1, column: 3, offset: 2))
        ][...]

        #expect(ParsingBoundaryDetection.isValidBalancedExpression(tokens) == false)
    }

    // MARK: - Block Structure Tests

    @Test func testBlockStartTokens() throws {
        #expect(ParsingBoundaryDetection.isBlockStartToken(.ifKeyword) == true)
        #expect(ParsingBoundaryDetection.isBlockStartToken(.whileKeyword) == true)
        #expect(ParsingBoundaryDetection.isBlockStartToken(.forKeyword) == true)
        #expect(ParsingBoundaryDetection.isBlockStartToken(.functionKeyword) == true)
        #expect(ParsingBoundaryDetection.isBlockStartToken(.procedureKeyword) == true)
    }

    @Test func testBlockEndTokens() throws {
        #expect(ParsingBoundaryDetection.isBlockEndToken(.endifKeyword) == true)
        #expect(ParsingBoundaryDetection.isBlockEndToken(.endwhileKeyword) == true)
        #expect(ParsingBoundaryDetection.isBlockEndToken(.endforKeyword) == true)
        #expect(ParsingBoundaryDetection.isBlockEndToken(.endfunctionKeyword) == true)
        #expect(ParsingBoundaryDetection.isBlockEndToken(.endprocedureKeyword) == true)
    }

    @Test func testNonBlockTokens() throws {
        #expect(ParsingBoundaryDetection.isBlockStartToken(.identifier) == false)
        #expect(ParsingBoundaryDetection.isBlockEndToken(.identifier) == false)
        #expect(ParsingBoundaryDetection.isBlockStartToken(.returnKeyword) == false)
        #expect(ParsingBoundaryDetection.isBlockEndToken(.returnKeyword) == false)
    }

    @Test func testFindMatchingBlockEnd() throws {
        let tokens = [
            Token(type: .ifKeyword, lexeme: "if", position: SourcePosition(line: 1, column: 1, offset: 0)),
            Token(type: .identifier, lexeme: "x", position: SourcePosition(line: 1, column: 4, offset: 3)),
            Token(type: .thenKeyword, lexeme: "then", position: SourcePosition(line: 1, column: 6, offset: 5)),
            Token(type: .identifier, lexeme: "y", position: SourcePosition(line: 1, column: 11, offset: 10)),
            Token(type: .endifKeyword, lexeme: "endif", position: SourcePosition(line: 1, column: 13, offset: 12))
        ]

        let endIndex = ParsingBoundaryDetection.findMatchingBlockEnd(in: tokens, startingAt: 0)
        #expect(endIndex == 4)
    }

    @Test func testFindMatchingBlockEndNested() throws {
        let tokens = [
            Token(type: .ifKeyword, lexeme: "if", position: SourcePosition(line: 1, column: 1, offset: 0)),
            Token(type: .identifier, lexeme: "x", position: SourcePosition(line: 1, column: 4, offset: 3)),
            Token(type: .thenKeyword, lexeme: "then", position: SourcePosition(line: 1, column: 6, offset: 5)),
            Token(type: .ifKeyword, lexeme: "if", position: SourcePosition(line: 2, column: 1, offset: 10)),
            Token(type: .identifier, lexeme: "y", position: SourcePosition(line: 2, column: 4, offset: 13)),
            Token(type: .thenKeyword, lexeme: "then", position: SourcePosition(line: 2, column: 6, offset: 15)),
            Token(type: .identifier, lexeme: "z", position: SourcePosition(line: 2, column: 11, offset: 20)),
            Token(type: .endifKeyword, lexeme: "endif", position: SourcePosition(line: 2, column: 13, offset: 22)),
            Token(type: .endifKeyword, lexeme: "endif", position: SourcePosition(line: 3, column: 1, offset: 28))
        ]

        let endIndex = ParsingBoundaryDetection.findMatchingBlockEnd(in: tokens, startingAt: 0)
        #expect(endIndex == 8)
    }

    @Test func testFindMatchingBlockEndMismatch() throws {
        let tokens = [
            Token(type: .ifKeyword, lexeme: "if", position: SourcePosition(line: 1, column: 1, offset: 0)),
            Token(type: .identifier, lexeme: "x", position: SourcePosition(line: 1, column: 4, offset: 3)),
            Token(type: .endwhileKeyword, lexeme: "endwhile", position: SourcePosition(line: 1, column: 6, offset: 5))
        ]

        let endIndex = ParsingBoundaryDetection.findMatchingBlockEnd(in: tokens, startingAt: 0)
        #expect(endIndex == nil)
    }

    // MARK: - Context Analysis Tests

    @Test func testAnalyzeParsingContextAtStart() throws {
        let tokens = [
            Token(type: .identifier, lexeme: "x", position: SourcePosition(line: 1, column: 1, offset: 0)),
            Token(type: .eof, lexeme: "", position: SourcePosition(line: 1, column: 2, offset: 1))
        ]

        let context = ParsingBoundaryDetection.analyzeParsingContext(in: tokens, at: 0)
        #expect(context.parenthesesDepth == 0)
        #expect(context.bracketDepth == 0)
        #expect(context.braceDepth == 0)
        #expect(context.blockDepth == 0)
        #expect(context.canStartNewStatement == true)
        #expect(context.isAtTopLevel == true)
    }

    @Test func testAnalyzeParsingContextInsideParens() throws {
        let tokens = [
            Token(type: .leftParen, lexeme: "(", position: SourcePosition(line: 1, column: 1, offset: 0)),
            Token(type: .identifier, lexeme: "x", position: SourcePosition(line: 1, column: 2, offset: 1)),
            Token(type: .rightParen, lexeme: ")", position: SourcePosition(line: 1, column: 3, offset: 2))
        ]

        let context = ParsingBoundaryDetection.analyzeParsingContext(in: tokens, at: 2)
        #expect(context.parenthesesDepth == 1)
        #expect(context.canStartNewStatement == false)
        #expect(context.isInsideNestedStructure == true)
    }

    @Test func testAnalyzeParsingContextInsideBlock() throws {
        let tokens = [
            Token(type: .ifKeyword, lexeme: "if", position: SourcePosition(line: 1, column: 1, offset: 0)),
            Token(type: .identifier, lexeme: "x", position: SourcePosition(line: 1, column: 4, offset: 3)),
            Token(type: .thenKeyword, lexeme: "then", position: SourcePosition(line: 1, column: 6, offset: 5)),
            Token(type: .identifier, lexeme: "y", position: SourcePosition(line: 1, column: 11, offset: 10))
        ]

        let context = ParsingBoundaryDetection.analyzeParsingContext(in: tokens, at: 4)
        #expect(context.blockDepth == 1)
        #expect(context.isAtTopLevel == false)
    }

    @Test func testIsInsideNestedStructure() throws {
        let tokens = [
            Token(type: .leftParen, lexeme: "(", position: SourcePosition(line: 1, column: 1, offset: 0)),
            Token(type: .leftBracket, lexeme: "[", position: SourcePosition(line: 1, column: 2, offset: 1)),
            Token(type: .identifier, lexeme: "x", position: SourcePosition(line: 1, column: 3, offset: 2))
        ]

        let context = ParsingBoundaryDetection.analyzeParsingContext(in: tokens, at: 3)
        #expect(context.isInsideNestedStructure == true)
        #expect(context.parenthesesDepth == 1)
        #expect(context.bracketDepth == 1)
    }

    @Test func testIsAtTopLevel() throws {
        let tokens = [
            Token(type: .identifier, lexeme: "x", position: SourcePosition(line: 1, column: 1, offset: 0)),
            Token(type: .assign, lexeme: "←", position: SourcePosition(line: 1, column: 3, offset: 2)),
            Token(type: .integerLiteral, lexeme: "42", position: SourcePosition(line: 1, column: 5, offset: 4))
        ]

        let context = ParsingBoundaryDetection.analyzeParsingContext(in: tokens, at: 3)
        #expect(context.isAtTopLevel == true)
        #expect(context.blockDepth == 0)
        #expect(context.isInsideNestedStructure == false)
    }

}
