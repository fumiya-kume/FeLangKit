import Testing
@testable import FeLangCore
import Foundation

/// Quick performance assessment optimized for development workflow
/// Uses small test sizes for fast feedback during development
@Suite("Quick Performance Assessment")
struct QuickBenchmark {

    // Development-friendly small sizes for fast tests
    private let devTestSize = 1_000      // 1KB for development
    private let mediumTestSize = 5_000   // 5KB for medium tests
    private let iterations = 100         // Reduced iterations for speed

    @Test("Fast Development Baseline - 1KB")
    func testDevelopmentBaseline() throws {
        let smallFile = generateSmallFile(size: devTestSize)

        let startTime = CFAbsoluteTimeGetCurrent()
        let tokens = try ParsingTokenizer().tokenize(smallFile)
        let statements = try StatementParser().parseStatements(from: tokens)
        let duration = CFAbsoluteTimeGetCurrent() - startTime

        print("Dev Baseline (1KB): \(String(format: "%.4f", duration))s, Tokens: \(tokens.count), Statements: \(statements.count)")

        // Very lenient for development - just ensure it works
        #expect(duration < 1.0, "1KB file should parse reasonably fast")
        #expect(!tokens.isEmpty, "Should produce tokens")
        #expect(!statements.isEmpty, "Should produce statements")
    }

    @Test("Tokenizer Performance - Original Only")
    func testTokenizerPerformanceOriginal() throws {
        let testFile = generateSmallFile(size: mediumTestSize) // Only 5KB

        // Test original tokenizer
        let originalStart = CFAbsoluteTimeGetCurrent()
        let originalTokens = try ParsingTokenizer().tokenize(testFile)
        let originalDuration = CFAbsoluteTimeGetCurrent() - originalStart

        print("Original Tokenizer (5KB): \(String(format: "%.4f", originalDuration))s, Tokens: \(originalTokens.count)")

        // Focus on correctness and basic performance
        #expect(originalDuration < 5.0, "Original tokenizer should complete 5KB reasonably")
        #expect(!originalTokens.isEmpty, "Should produce tokens")
    }

    @Test("Simple Expression Batch - Fast")
    func testSimpleExpressionBatchFast() throws {
        let simpleExpr = "result ← 1 + 2 * 3"
        let reducedIterations = 50 // Much smaller for development

        let startTime = CFAbsoluteTimeGetCurrent()
        for _ in 0..<reducedIterations {
            let tokens = try ParsingTokenizer().tokenize(simpleExpr)
            _ = try StatementParser().parseStatements(from: tokens)
        }
        let duration = CFAbsoluteTimeGetCurrent() - startTime

        print("\(reducedIterations) simple expressions: \(String(format: "%.4f", duration))s")

        // Very lenient - just ensure batch processing works
        #expect(duration < 5.0, "Batch processing should complete reasonably")
    }

    @Test("Parser Only Performance - Fast")
    func testParserOnlyFast() throws {
        let testFile = generateSmallFile(size: devTestSize) // Only 1KB
        let tokens = try ParsingTokenizer().tokenize(testFile)

        let startTime = CFAbsoluteTimeGetCurrent()
        let statements = try StatementParser().parseStatements(from: tokens)
        let duration = CFAbsoluteTimeGetCurrent() - startTime

        print("Parser Only (1KB → \(tokens.count) tokens): \(String(format: "%.4f", duration))s, Statements: \(statements.count)")

        // Focus on correctness
        #expect(duration < 1.0, "Parser should be reasonably fast")
        #expect(!statements.isEmpty, "Should produce statements")
    }

    @Test("Light Nesting Test")
    func testLightNesting() throws {
        let lightDepth = 5 // Much smaller for development
        let nestedFile = generateSimpleNested(depth: lightDepth)

        let startTime = CFAbsoluteTimeGetCurrent()
        let tokens = try ParsingTokenizer().tokenize(nestedFile)
        let statements = try StatementParser().parseStatements(from: tokens)
        let duration = CFAbsoluteTimeGetCurrent() - startTime

        print("Light Nesting (depth \(lightDepth)): \(String(format: "%.4f", duration))s")

        #expect(duration < 1.0, "Light nesting should be fast")
        #expect(!statements.isEmpty, "Should handle nesting")
    }

    @Test("Small Expression Chain")
    func testSmallExpressionChain() throws {
        let smallTerms = 50 // Much smaller for development
        let expr = generateLargeExpression(terms: smallTerms)

        let startTime = CFAbsoluteTimeGetCurrent()
        let tokens = try ParsingTokenizer().tokenize(expr)
        let statements = try StatementParser().parseStatements(from: tokens)
        let duration = CFAbsoluteTimeGetCurrent() - startTime

        print("Small Expression (\(smallTerms) terms): \(String(format: "%.4f", duration))s")

        #expect(duration < 1.0, "Small expressions should be fast")
        #expect(!statements.isEmpty, "Should parse expression")
    }

    // MARK: - Optional Heavy Tests (commented out for development)

    /*
    // Uncomment these for full performance validation
    
    @Test("Medium File Test - Optional")
    func testMediumFileOptional() throws {
        let mediumFile = generateSmallFile(size: 50_000) // 50KB
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let tokens = try ParsingTokenizer().tokenize(mediumFile)
        let statements = try StatementParser().parseStatements(from: tokens)
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        print("Medium File (50KB): \(duration)s")
        #expect(duration < 5.0, "50KB should parse in reasonable time")
    }
    
    @Test("Performance Scaling - Optional")
    func testPerformanceScalingOptional() throws {
        let sizes = [1_000, 5_000, 10_000]
        for size in sizes {
            let file = generateSmallFile(size: size)
            let time = measureTime { try parseComplete(file) }
            print("Size: \(size), Time: \(time)s")
        }
    }
    */

    // MARK: - Helper Functions

    private func generateSmallFile(size: Int) -> String {
        var content = ""
        content.reserveCapacity(size)

        let statements = [
            "変数 x: 整数型",
            "x ← 42",
            "変数 y: 実数型",
            "y ← 3.14",
            "変数 z: 整数型",
            "z ← x + 1"
        ]

        while content.count < size {
            for statement in statements {
                content += statement + "\n"
                if content.count >= size {
                    break
                }
            }
        }

        return content
    }

    private func generateSimpleNested(depth: Int) -> String {
        var content = ""

        for index in 0..<depth {
            content += String(repeating: "    ", count: index)
            content += "if x > \(index) then\n"
        }

        content += String(repeating: "    ", count: depth)
        content += "x ← x + 1\n"

        for index in (0..<depth).reversed() {
            content += String(repeating: "    ", count: index)
            content += "endif\n"
        }

        return content
    }

    private func generateLargeExpression(terms: Int) -> String {
        let numbers = Array(1...terms).map(String.init)
        return "result ← " + numbers.joined(separator: " + ") + "\n"
    }

    private func measureTime<T>(_ block: () throws -> T) rethrows -> TimeInterval {
        let start = CFAbsoluteTimeGetCurrent()
        _ = try block()
        return CFAbsoluteTimeGetCurrent() - start
    }

    private func parseComplete(_ input: String) throws -> [Statement] {
        let tokens = try ParsingTokenizer().tokenize(input)
        return try StatementParser().parseStatements(from: tokens)
    }
}

// MARK: - Development-Friendly Configuration

/// Configuration for test execution modes
enum TestMode {
    case development  // Fast tests for development workflow
    case integration  // Medium tests for integration validation  
    case performance  // Full performance validation tests

    static let current: TestMode = .development // Change this to switch modes
}
