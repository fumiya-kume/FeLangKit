import Testing
@testable import FeLangCore
import Foundation

/// Simple performance tests with basic syntax only
/// Focus on getting baseline measurements without complex language features
@Suite("Simple Performance Tests")
struct SimplePerformanceTest {

    @Test("Basic Tokenizer Performance")
    func testBasicTokenizerPerformance() throws {
        // Simple statements that should parse cleanly
        let simpleCode = """
        変数 x: 整数型
        x ← 42
        変数 y: 実数型
        y ← 3.14
        変数 result: 整数型
        result ← x + 10
        """

        let startTime = CFAbsoluteTimeGetCurrent()
        let tokens = try ParsingTokenizer().tokenize(simpleCode)
        let tokenizeDuration = CFAbsoluteTimeGetCurrent() - startTime

        print("Basic Tokenization: \(String(format: "%.4f", tokenizeDuration))s for \(tokens.count) tokens")

        #expect(tokenizeDuration < 1.0, "Basic tokenization should be fast")
        #expect(tokens.count > 10, "Should produce multiple tokens")
        #expect(!tokens.isEmpty, "Should produce tokens")
    }

    @Test("Basic Parser Performance")
    func testBasicParserPerformance() throws {
        let simpleCode = """
        変数 x: 整数型
        x ← 42
        変数 y: 実数型
        y ← 3.14
        """

        let tokens = try ParsingTokenizer().tokenize(simpleCode)

        let startTime = CFAbsoluteTimeGetCurrent()
        let statements = try StatementParser().parseStatements(from: tokens)
        let parseDuration = CFAbsoluteTimeGetCurrent() - startTime

        print("Basic Parsing: \(String(format: "%.4f", parseDuration))s for \(statements.count) statements")

        #expect(parseDuration < 1.0, "Basic parsing should be fast")
        #expect(statements.count >= 2, "Should parse 2 variable declarations")
    }

    @Test("Repeated Simple Expressions")
    func testRepeatedSimpleExpressions() throws {
        let expressions = Array(1...100).map { "result\($0) ← \($0) + \($0 * 2)" }
        let code = expressions.joined(separator: "\n")

        let startTime = CFAbsoluteTimeGetCurrent()
        let tokens = try ParsingTokenizer().tokenize(code)
        let statements = try StatementParser().parseStatements(from: tokens)
        let totalDuration = CFAbsoluteTimeGetCurrent() - startTime

        print("100 Simple Expressions: \(String(format: "%.4f", totalDuration))s")
        print("Tokens: \(tokens.count), Statements: \(statements.count)")

        #expect(totalDuration < 2.0, "100 simple expressions should parse quickly")
        #expect(statements.count == 100, "Should parse 100 statements")
    }

    @Test("Scaling Test - Basic Statements")
    func testScalingBasicStatements() throws {
        let sizes = [10, 50, 100, 200]

        for size in sizes {
            let statements = Array(1...size).map { "x\($0) ← \($0)" }
            let code = statements.joined(separator: "\n")

            let startTime = CFAbsoluteTimeGetCurrent()
            let tokens = try ParsingTokenizer().tokenize(code)
            let parsedStatements = try StatementParser().parseStatements(from: tokens)
            let duration = CFAbsoluteTimeGetCurrent() - startTime

            print("Size \(size): \(String(format: "%.4f", duration))s")

            #expect(duration < 5.0, "Size \(size) should parse in reasonable time")
            #expect(parsedStatements.count == size, "Should parse \(size) statements")
        }
    }

    @Test("Tokenizer vs Parser Performance Split")
    func testTokenizerVsParserSplit() throws {
        // Generate reasonable size test case
        let statements = Array(1...500).map { "value\($0) ← \($0) * 2 + 1" }
        let code = statements.joined(separator: "\n")

        // Test tokenizer only
        let tokenizerStart = CFAbsoluteTimeGetCurrent()
        let tokens = try ParsingTokenizer().tokenize(code)
        let tokenizerDuration = CFAbsoluteTimeGetCurrent() - tokenizerStart

        // Test parser only (on pre-tokenized input)
        let parserStart = CFAbsoluteTimeGetCurrent()
        let parsedStatements = try StatementParser().parseStatements(from: tokens)
        let parserDuration = CFAbsoluteTimeGetCurrent() - parserStart

        let totalTime = tokenizerDuration + parserDuration

        print("Performance Split (500 statements):")
        print("  Tokenizer: \(String(format: "%.4f", tokenizerDuration))s (\(String(format: "%.1f", tokenizerDuration/totalTime*100))%)")
        print("  Parser: \(String(format: "%.4f", parserDuration))s (\(String(format: "%.1f", parserDuration/totalTime*100))%)")
        print("  Total: \(String(format: "%.4f", totalTime))s")

        #expect(totalTime < 5.0, "500 statements should parse in reasonable time")
        #expect(parsedStatements.count == 500, "Should parse all 500 statements")
        #expect(tokenizerDuration > 0, "Tokenizer should take measurable time")
        #expect(parserDuration > 0, "Parser should take measurable time")
    }
}
