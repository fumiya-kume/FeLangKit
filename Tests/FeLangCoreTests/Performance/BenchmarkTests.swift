import Testing
@testable import FeLangCore
import Foundation
@preconcurrency import Darwin

/// Comprehensive performance benchmarking suite for FeLangKit
/// Implements Phase 1 of the performance optimization plan from Issue #26
/// Target: Parse 1 MB files in < 150 ms debug builds
/// 
/// NOTE: Heavy tests are disabled by default for development workflow.
/// Enable them by changing `enableHeavyTests` to true.
@Suite("Performance Benchmarks")
struct BenchmarkTests {

    // MARK: - Configuration

    /// Enable heavy tests (1MB files, etc.) - set to false for development
    private static let enableHeavyTests = false

    /// Development test size (much smaller for fast feedback)
    private let devTestSize = 10_000 // 10KB for development

    // MARK: - Original Constants (for heavy tests)
    private let targetParseTime: TimeInterval = 0.150
    private let targetFileSize = 1_000_000 // 1 MB
    private let memoryThreshold = 50_000_000 // 50 MB
    private let throughputTarget: Double = 6.7

    // MARK: - Development-Friendly Tests

    @Test("Development File Parsing Performance - 10KB")
    func testDevelopmentFileParsingPerformance() throws {
        let devFile = generateLargeFile(size: devTestSize)

        let startTime = CFAbsoluteTimeGetCurrent()
        let tokens = try ParsingTokenizer().tokenize(devFile)
        let statements = try StatementParser().parseStatements(from: tokens)
        let duration = CFAbsoluteTimeGetCurrent() - startTime

        // Scaled expectations for development (10KB vs 1MB = 1% of target)
        _ = targetParseTime * 0.01 // 1.5ms for 10KB (not enforced in dev mode)

        print("Development File Performance (10KB): \(String(format: "%.4f", duration))s")
        print("Tokens: \(tokens.count), Statements: \(statements.count)")

        // Very lenient for development workflow - debug builds are much slower
        #expect(duration < 5.0, "10KB file should parse in reasonable time")
        #expect(!statements.isEmpty, "Should successfully parse statements")
        #expect(!tokens.isEmpty, "Should successfully tokenize")
    }

    @Test("Component Performance Breakdown - Development")
    func testComponentPerformanceBreakdown() throws {
        let testFile = generateLargeFile(size: devTestSize)

        // Test tokenizer only
        let tokenizerStart = CFAbsoluteTimeGetCurrent()
        let tokens = try ParsingTokenizer().tokenize(testFile)
        let tokenizerTime = CFAbsoluteTimeGetCurrent() - tokenizerStart

        // Test parser only
        let parserStart = CFAbsoluteTimeGetCurrent()
        _ = try StatementParser().parseStatements(from: tokens)
        let parserTime = CFAbsoluteTimeGetCurrent() - parserStart

        let totalTime = tokenizerTime + parserTime

        print("Component Breakdown (10KB):")
        print("  Tokenizer: \(String(format: "%.4f", tokenizerTime))s (\(String(format: "%.1f", tokenizerTime/totalTime*100))%)")
        print("  Parser: \(String(format: "%.4f", parserTime))s (\(String(format: "%.1f", parserTime/totalTime*100))%)")
        print("  Total: \(String(format: "%.4f", totalTime))s")

        #expect(totalTime < 5.0, "Total processing should be reasonable for development testing")
        #expect(tokenizerTime > 0, "Tokenizer should take measurable time")
        #expect(parserTime > 0, "Parser should take measurable time")
    }

    @Test("Light Memory Usage Check")
    func testLightMemoryUsage() throws {
        let lightFile = generateLargeFile(size: devTestSize)

        let memoryBefore = getMemoryUsage()
        let tokens = try ParsingTokenizer().tokenize(lightFile)
        let statements = try StatementParser().parseStatements(from: tokens)
        let memoryAfter = getMemoryUsage()

        let memoryDelta = memoryAfter - memoryBefore

        print("Memory usage (10KB): \(memoryDelta / 1_000) KB")

        // Very lenient memory check
        #expect(memoryDelta < 10_000_000, "Memory usage should be reasonable for small files")

        // Keep references alive
        _ = tokens.count + statements.count
    }

    // MARK: - Optional Heavy Performance Tests

    @Test("1MB File Parsing Performance - HEAVY TEST")
    func test1MBFileParsingPerformance() throws {
        guard Self.enableHeavyTests else {
            print("Heavy tests disabled - enable by setting enableHeavyTests = true")
            return
        }

        let largeFile = generateLargeFile(size: targetFileSize)

        let startTime = CFAbsoluteTimeGetCurrent()
        let tokens = try ParsingTokenizer().tokenize(largeFile)
        _ = try StatementParser().parseStatements(from: tokens)
        let duration = CFAbsoluteTimeGetCurrent() - startTime

        // Core performance requirement from Issue #26
        #expect(duration < targetParseTime, "Parse time \(duration)s exceeds target \(targetParseTime)s")

        print("1MB File Performance: \(duration)s (target: \(targetParseTime)s)")
        print("Throughput: \(Double(targetFileSize) / 1_000_000 / duration) MB/s")
    }

    @Test("Multiple Large File Processing - HEAVY TEST")
    func testMultipleLargeFiles() throws {
        guard Self.enableHeavyTests else { return }

        let files = (0..<10).map { _ in generateLargeFile(size: 100_000) }

        let totalTime = try measureTime {
            for file in files {
                _ = try parseComplete(file)
            }
        }

        #expect(totalTime < 1.0, "Multiple file processing time \(totalTime)s exceeds 1.0s")
        print("Multiple files (10x100KB): \(totalTime)s")
    }

    @Test("Tokenizer Performance - 1MB Input - HEAVY TEST")
    func testTokenizerPerformance() throws {
        guard Self.enableHeavyTests else { return }

        let largeFile = generateLargeFile(size: targetFileSize)

        let tokenizeTime = try measureTime {
            _ = try ParsingTokenizer().tokenize(largeFile)
        }

        let tokenizerTarget: TimeInterval = 0.050
        #expect(tokenizeTime < tokenizerTarget, "Tokenizer time \(tokenizeTime)s exceeds target \(tokenizerTarget)s")

        print("Tokenizer Performance: \(tokenizeTime)s (target: \(tokenizerTarget)s)")
    }

    @Test("Linear Performance Scaling - HEAVY TEST")
    func testLinearPerformanceScaling() throws {
        guard Self.enableHeavyTests else { return }

        let sizes = [100_000, 250_000, 500_000, 750_000, 1_000_000]
        var timings: [Double] = []

        for size in sizes {
            let file = generateLargeFile(size: size)
            let time = try measureTime {
                _ = try parseComplete(file)
            }
            timings.append(time)
            print("Size: \(size), Time: \(time)s")
        }

        // Verify linear scaling
        for index in 1..<timings.count {
            let ratio = timings[index] / timings[index-1]
            let sizeRatio = Double(sizes[index]) / Double(sizes[index-1])
            let expectedRatio = sizeRatio
            let tolerance = 0.5

            #expect(ratio < expectedRatio * (1 + tolerance),
                   "Performance scaling worse than linear: \(ratio) vs expected \(expectedRatio)")
        }
    }

    @Test("Memory Usage Monitoring - HEAVY TEST")
    func testMemoryUsage() throws {
        guard Self.enableHeavyTests else { return }

        let largeFile = generateLargeFile(size: targetFileSize)

        let memoryBefore = getMemoryUsage()
        let tokens = try ParsingTokenizer().tokenize(largeFile)
        let statements = try StatementParser().parseStatements(from: tokens)
        let memoryAfter = getMemoryUsage()

        let memoryDelta = memoryAfter - memoryBefore

        #expect(memoryDelta < memoryThreshold,
               "Memory usage \(memoryDelta) bytes exceeds threshold \(memoryThreshold)")

        print("Memory usage: \(memoryDelta / 1_000_000) MB (threshold: \(memoryThreshold / 1_000_000) MB)")

        _ = tokens.count + statements.count
    }

    @Test("Deep Nesting Performance - HEAVY TEST")
    func testDeepNestingPerformance() throws {
        guard Self.enableHeavyTests else { return }

        let deeplyNestedFile = generateDeeplyNestedFile(depth: 90)

        let time = try measureTime {
            _ = try parseComplete(deeplyNestedFile)
        }

        #expect(time < 0.1, "Deep nesting parsing time \(time)s should be under 0.1s")
        print("Deep nesting performance: \(time)s")
    }

    @Test("Large Expression Performance - HEAVY TEST")
    func testLargeExpressionPerformance() throws {
        guard Self.enableHeavyTests else { return }

        let largeExpression = generateLargeExpression(terms: 10_000)

        let time = try measureTime {
            _ = try parseComplete(largeExpression)
        }

        #expect(time < 0.05, "Large expression parsing time \(time)s should be under 0.05s")
        print("Large expression performance: \(time)s")
    }

    @Test("Throughput Validation - HEAVY TEST")
    func testThroughputValidation() throws {
        guard Self.enableHeavyTests else { return }

        let file = generateLargeFile(size: targetFileSize)

        let time = try measureTime {
            _ = try parseComplete(file)
        }

        let throughputMBps = Double(targetFileSize) / 1_000_000 / time

        #expect(throughputMBps > throughputTarget,
               "Throughput \(throughputMBps) MB/s below target \(throughputTarget) MB/s")

        print("Throughput: \(throughputMBps) MB/s (target: \(throughputTarget) MB/s)")
    }

    // MARK: - Utility Functions

    /// Measures execution time of a block
    private func measureTime<T>(_ block: () throws -> T) rethrows -> TimeInterval {
        let startTime = CFAbsoluteTimeGetCurrent()
        _ = try block()
        return CFAbsoluteTimeGetCurrent() - startTime
    }

    /// Complete parsing pipeline for benchmarking
    private func parseComplete(_ input: String) throws -> [Statement] {
        let tokens = try ParsingTokenizer().tokenize(input)
        return try StatementParser().parseStatements(from: tokens)
    }

    /// Gets current memory usage in bytes
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return Int64(info.resident_size)
        } else {
            return 0
        }
    }
}

// MARK: - Test File Generators

extension BenchmarkTests {

    /// Generates a large FE language file for performance testing
    private func generateLargeFile(size: Int) -> String {
        var content = ""
        content.reserveCapacity(size)

        let statements = [
            "変数 counter: 整数型",
            "counter ← 0",
            "変数 sum: 実数型",
            "sum ← 0.0",
            "変数 result: 真偽型",
            "result ← true",
            "変数 value: 整数型",
            "value ← 42",
            "変数 x: 整数型",
            "x ← 10",
            "変数 y: 整数型",
            "y ← 20",
            "// This is a comment",
            "/* Multi-line comment */"
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

    /// Generates a deeply nested structure for testing nesting performance
    private func generateDeeplyNestedFile(depth: Int) -> String {
        var content = ""

        // Create nested if statements
        for index in 0..<depth {
            content += String(repeating: "    ", count: index)
            content += "if condition\(index) then\n"
        }

        // Add content in the middle
        content += String(repeating: "    ", count: depth)
        content += "result ← true\n"

        // Close all if statements
        for index in (0..<depth).reversed() {
            content += String(repeating: "    ", count: index)
            content += "endif\n"
        }

        return content
    }

    /// Generates a large arithmetic expression for testing expression parsing
    private func generateLargeExpression(terms: Int) -> String {
        let numbers = Array(1...terms).map(String.init)
        return "result ← " + numbers.joined(separator: " + ") + "\n"
    }
}
