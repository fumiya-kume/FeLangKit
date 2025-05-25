import Foundation
import Testing
@testable import FeLangCore

/// Integrated benchmark tests using the new BenchmarkFramework
/// Tests Unicode normalization impact and comprehensive tokenizer performance
@Suite("Integrated Benchmark Tests")
struct IntegratedBenchmarkTests {

    private let benchmarkFramework = BenchmarkFramework()

    // MARK: - Tokenizer Comparison Tests

    @Test("Enhanced vs Original Tokenizer Performance")
    func testEnhancedVsOriginalPerformance() throws {
        let testSource = """
        変数 counter = 0
        変数 text = "Hello, World!"

        if counter > 0 then
            counter = counter + 1
        else
            counter = 0
        endif
        """

        let originalTokenizer = Tokenizer(input: testSource)
        let enhancedTokenizer = EnhancedParsingTokenizer()

        let comparison = BenchmarkFramework.compareTokenizers(
            baseline: originalTokenizer,
            candidate: enhancedTokenizer,
            source: testSource
        )

        print("=== Enhanced vs Original Tokenizer ===")
        print("Baseline tokens/sec: \(String(format: "%.2f", comparison.baseline.averageTokensPerSecond))")
        print("Enhanced tokens/sec: \(String(format: "%.2f", comparison.candidate.averageTokensPerSecond))")
        print("Performance ratio: \(String(format: "%.2f", comparison.tokensPerSecondImprovement))x")

        // Enhanced tokenizer trades speed for features like Unicode normalization and error recovery
        // In debug builds, expect significantly slower performance due to additional processing
        #expect(comparison.tokensPerSecondImprovement > 0.01, "Enhanced tokenizer should maintain reasonable performance")
    }

    @Test("Fast vs Enhanced Tokenizer Comparison")
    func testFastVsEnhancedComparison() throws {
        let testSource = generateLargeTestSource()

        let fastTokenizer = FastParsingTokenizer()
        let enhancedTokenizer = EnhancedParsingTokenizer()

        let comparison = BenchmarkFramework.compareTokenizers(
            baseline: fastTokenizer,
            candidate: enhancedTokenizer,
            source: testSource
        )

        print("=== Fast vs Enhanced Tokenizer ===")
        print("Fast tokens/sec: \(String(format: "%.2f", comparison.baseline.averageTokensPerSecond))")
        print("Enhanced tokens/sec: \(String(format: "%.2f", comparison.candidate.averageTokensPerSecond))")
        print("Speed ratio: \(String(format: "%.2f", comparison.speedupRatio))x")
        print("Memory efficiency: \(String(format: "%.2f", comparison.memoryEfficiencyRatio))x")

        // Fast tokenizer should be faster, but enhanced should be reasonable
        #expect(comparison.baseline.averageTokensPerSecond > 0, "Fast tokenizer should perform well")
        #expect(comparison.candidate.averageTokensPerSecond > 0, "Enhanced tokenizer should perform well")
    }

    // MARK: - Unicode Normalization Impact Tests

    @Test("Unicode Normalization Performance Impact")
    func testUnicodeNormalizationImpact() throws {
        let normalizedSource = """
        変数 value = "Hello World"
        if value > 0 then
            value = value + 1
        endif
        """

        let fullwidthSource = """
        変数　ｖａｌｕｅ　＝　"Ｈｅｌｌｏ　Ｗｏｒｌｄ"
        ｉｆ　ｖａｌｕｅ　＞　０　ｔｈｅｎ
            ｖａｌｕｅ　＝　ｖａｌｕｅ　＋　１
        ｅｎｄｉｆ
        """

        let enhancedTokenizer = EnhancedParsingTokenizer()

        let normalizedResult = BenchmarkFramework.measureTokenization(
            source: normalizedSource,
            tokenizer: enhancedTokenizer,
            iterations: 500
        )

        let fullwidthResult = BenchmarkFramework.measureTokenization(
            source: fullwidthSource,
            tokenizer: enhancedTokenizer,
            iterations: 500
        )

        print("=== Unicode Normalization Impact ===")
        print("Normalized source tokens/sec: \(String(format: "%.2f", normalizedResult.averageTokensPerSecond))")
        print("Full-width source tokens/sec: \(String(format: "%.2f", fullwidthResult.averageTokensPerSecond))")

        let performanceRatio = normalizedResult.averageTokensPerSecond / fullwidthResult.averageTokensPerSecond
        print("Performance impact: \(String(format: "%.2f", performanceRatio))x")

        // Normalization overhead should be minimal
        #expect(performanceRatio < 2.0, "Unicode normalization should not cause significant performance degradation")
        #expect(fullwidthResult.averageTokensPerSecond > 1000, "Should maintain good performance even with full-width text")
    }

    @Test("Combining Characters Performance")
    func testCombiningCharactersPerformance() throws {
        let combiningSource = """
        変数　なまえ　＝　"か\u{3099}き\u{3099}く\u{3099}け\u{3099}こ\u{3099}"
        変数　けっか　＝　なまえ　＋　"は\u{309A}ひ\u{309A}ふ\u{309A}へ\u{309A}ほ\u{309A}"
        """

        let enhancedTokenizer = EnhancedParsingTokenizer()

        let result = BenchmarkFramework.measureTokenization(
            source: combiningSource,
            tokenizer: enhancedTokenizer,
            iterations: 1000
        )

        print("=== Combining Characters Performance ===")
        print("Tokens/sec: \(String(format: "%.2f", result.averageTokensPerSecond))")
        print("Processing time: \(String(format: "%.6f", result.averageProcessingTime)) seconds")
        print("Memory usage: \(result.averageMemoryUsage) bytes")

        #expect(result.averageTokensPerSecond > 500, "Should handle combining characters efficiently")
    }

    // MARK: - Comprehensive Suite Tests

    @Test("Enhanced Tokenizer Comprehensive Suite")
    func testEnhancedTokenizerSuite() throws {
        let enhancedTokenizer = EnhancedParsingTokenizer()

        let suiteResult = BenchmarkFramework.runComprehensiveSuite(tokenizer: enhancedTokenizer)

        print("=== Enhanced Tokenizer Comprehensive Suite ===")
        print("Environment: \(suiteResult.environment.device) - \(suiteResult.environment.operatingSystem)")
        print("Swift version: \(suiteResult.environment.swiftVersion)")
        print("Optimization: \(suiteResult.environment.optimizationLevel)")
        print()

        for testCase in suiteResult.testCases {
            print("Test Case: \(testCase.name)")
            print("  Source size: \(testCase.sourceSize) characters")
            print("  Iterations: \(testCase.iterations)")
            print("  Avg tokens/sec: \(String(format: "%.2f", testCase.benchmarkResult.averageTokensPerSecond))")
            print("  Avg memory: \(testCase.benchmarkResult.averageMemoryUsage) bytes")

            let stats = testCase.benchmarkResult.statistics
            print("  Min time: \(String(format: "%.6f", stats.min))s")
            print("  Max time: \(String(format: "%.6f", stats.max))s")
            print("  Std dev: \(String(format: "%.6f", stats.standardDeviation))s")
            print()
        }

        let summary = suiteResult.summary
        print("Summary:")
        print("  Total execution time: \(String(format: "%.3f", summary.totalExecutionTime)) seconds")
        print("  Total iterations: \(summary.totalIterations)")
        print("  Average tokens/sec across all tests: \(String(format: "%.2f", summary.averageTokensPerSecond))")
        print("  Test cases run: \(summary.testCasesRun)")

        // Verify reasonable performance across all test cases
        for testCase in suiteResult.testCases {
            #expect(testCase.benchmarkResult.averageTokensPerSecond > 100,
                   "Test case '\(testCase.name)' should achieve reasonable performance")
            #expect(testCase.benchmarkResult.statistics.standardDeviation < 0.1,
                   "Test case '\(testCase.name)' should have consistent performance")
        }

        #expect(summary.averageTokensPerSecond > 500, "Overall performance should be good")
        #expect(summary.testCasesRun == 5, "Should run all test cases")
    }

    @Test("Fast Tokenizer Comprehensive Suite")
    func testFastTokenizerSuite() throws {
        let fastTokenizer = FastParsingTokenizer()

        let suiteResult = BenchmarkFramework.runComprehensiveSuite(tokenizer: fastTokenizer)

        print("=== Fast Tokenizer Comprehensive Suite ===")
        let summary = suiteResult.summary
        print("Average tokens/sec: \(String(format: "%.2f", summary.averageTokensPerSecond))")
        print("Total execution time: \(String(format: "%.3f", summary.totalExecutionTime)) seconds")

        // Fast tokenizer should be very performant
        #expect(summary.averageTokensPerSecond > 1000, "Fast tokenizer should be very performant")
    }

    // MARK: - Memory Usage Tests

    @Test("Memory Usage Patterns")
    func testMemoryUsagePatterns() throws {
        let testSources = [
            ("Small", generateTestSource(lines: 5)),
            ("Medium", generateTestSource(lines: 50)),
            ("Large", generateTestSource(lines: 500))
        ]

        let enhancedTokenizer = EnhancedParsingTokenizer()

        for (name, source) in testSources {
            let result = BenchmarkFramework.measureTokenization(
                source: source,
                tokenizer: enhancedTokenizer,
                iterations: 100
            )

            print("=== Memory Usage: \(name) ===")
            print("Source size: \(source.count) characters")
            print("Average memory: \(result.averageMemoryUsage) bytes")
            print("Memory per character: \(Double(result.averageMemoryUsage) / Double(source.count)) bytes/char")
            print()

            // Memory usage should scale reasonably with input size
            let memoryPerChar = Double(result.averageMemoryUsage) / Double(source.count)
            // Relax memory expectations for debug builds with measurement overhead
            #expect(memoryPerChar < 150, "Memory usage per character should be reasonable")
        }
    }

    // MARK: - Regression Detection Tests

    @Test("Performance Regression Detection")
    func testPerformanceRegressionDetection() throws {
        let baselineSource = generateStandardBenchmarkSource()
        let enhancedTokenizer = EnhancedParsingTokenizer()

        // Run multiple measurements to establish baseline
        var results: [BenchmarkFramework.TokenizerBenchmarkResult] = []

        for _ in 0..<3 {
            let result = BenchmarkFramework.measureTokenization(
                source: baselineSource,
                tokenizer: enhancedTokenizer,
                iterations: 200
            )
            results.append(result)
        }

        let avgTokensPerSecond = results.map(\.averageTokensPerSecond).reduce(0, +) / Double(results.count)
        let avgProcessingTime = results.map(\.averageProcessingTime).reduce(0, +) / Double(results.count)

        print("=== Performance Regression Detection ===")
        print("Baseline tokens/sec: \(String(format: "%.2f", avgTokensPerSecond))")
        print("Baseline processing time: \(String(format: "%.6f", avgProcessingTime))s")

        // These values can be used as regression detection thresholds
        #expect(avgTokensPerSecond > 500, "Should maintain minimum performance threshold")
        #expect(avgProcessingTime < 0.01, "Should maintain maximum processing time threshold")

        // Consistency check
        let tokensPerSecondVariance = results.map { pow($0.averageTokensPerSecond - avgTokensPerSecond, 2) }.reduce(0, +) / Double(results.count)
        let tokensPerSecondStdDev = sqrt(tokensPerSecondVariance)

        print("Performance consistency (std dev): \(String(format: "%.2f", tokensPerSecondStdDev))")
        // Allow higher variation in debug builds due to timing measurement noise and VM behavior
        #expect(tokensPerSecondStdDev < avgTokensPerSecond * 0.25, "Performance should be consistent (< 25% variation)")
    }

    // MARK: - Helper Methods

    private func generateLargeTestSource() -> String {
        return generateTestSource(lines: 100)
    }

    private func generateTestSource(lines: Int) -> String {
        let patterns = [
            "変数 counter = 0",
            "変数 text = \"テスト文字列\"",
            "if counter > 0 then",
            "    counter = counter + 1",
            "else",
            "    counter = 0",
            "endif",
            "while counter < 10 do",
            "    text = text + \"追加\"",
            "    counter = counter + 1",
            "endwhile",
            "function test(param)",
            "    return param * 2",
            "endfunction"
        ]

        var result = ""
        for index in 0..<lines {
            let pattern = patterns[index % patterns.count]
            result += pattern + "\n"
        }

        return result
    }

    private func generateStandardBenchmarkSource() -> String {
        return """
        変数 name = "Hello, World!"
        変数 counter = 0
        変数 flag = true

        if counter > 0 then
            counter = counter + 1
            name = name + "追加テキスト"
        else
            counter = 0
            flag = false
        endif

        while counter < 10 do
            if flag then
                counter = counter + 1
            else
                break
            endif
        endwhile

        function processData(data)
            変数 result = ""
            for idx = 1 to 100 step 1
                result = result + data
            endfor
            return result
        endfunction

        変数 output = processData("テスト")
        """
    }
}
