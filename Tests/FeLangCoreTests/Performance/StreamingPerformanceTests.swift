import Testing
@testable import FeLangCore
import Foundation

@Suite("Streaming Performance Tests")
struct StreamingPerformanceTests {

    @Test("Benchmark suite initialization")
    func testBenchmarkSuiteInitialization() {
        _ = TokenizerBenchmark()
        // TokenizerBenchmark is a struct, so it will always initialize successfully
    }

    @Test("Throughput measurement")
    func testThroughputMeasurement() async throws {
        let benchmark = TokenizerBenchmark()

        let result = try await benchmark.measureThroughput(
            fileSize: 1000,
            iterations: 10
        )

        #expect(result.fileSize == 1000, "Should record correct file size")
        #expect(result.iterations == 10, "Should record correct iteration count")
        #expect(result.durations.count == 10, "Should have duration for each iteration")
        #expect(result.tokenCounts.count == 10, "Should have token count for each iteration")
        #expect(result.averageDuration > 0, "Should have positive average duration")
        #expect(result.averageThroughput > 0, "Should have positive throughput")

        print("Throughput: \(result.averageThroughput) chars/sec")
    }

    @Test("Memory usage measurement")
    func testMemoryUsageMeasurement() async throws {
        let benchmark = TokenizerBenchmark()

        let result = try await benchmark.measureMemoryUsage(fileSize: 5000)

        #expect(result.fileSize == 5000, "Should record correct file size")
        #expect(result.tokenCount > 0, "Should produce tokens")
        #expect(result.peakMemory >= result.baselineMemory, "Peak memory should be >= baseline")
        #expect(!result.snapshots.isEmpty, "Should have memory snapshots")

        // Verify snapshots are in chronological order
        for i in 1..<result.snapshots.count {
            #expect(result.snapshots[i].timestamp >= result.snapshots[i-1].timestamp,
                   "Snapshots should be in chronological order")
        }

        print("Peak memory: \(result.peakMemory) bytes")
    }

    @Test("Incremental performance measurement")
    func testIncrementalPerformanceMeasurement() async throws {
        let benchmark = TokenizerBenchmark()

        let changes = [
            TextChange(type: .insertion, position: 10, newText: "new code"),
            TextChange(type: .replacement, position: 50, length: 5, newText: "replacement"),
            TextChange(type: .deletion, position: 100, length: 10)
        ]

        let result = try await benchmark.measureIncrementalPerformance(changes: changes)

        #expect(result.initialTokenization.duration > 0, "Should have initial tokenization time")
        #expect(result.incrementalResults.count == changes.count, "Should have result for each change")

        for incrementalResult in result.incrementalResults {
            #expect(incrementalResult.incrementalDuration > 0, "Should have incremental duration")
            #expect(incrementalResult.fullDuration > 0, "Should have full duration")
            #expect(incrementalResult.speedupRatio > 0, "Should have positive speedup ratio")
            #expect(incrementalResult.validation.sampledCount > 0, "Should validate some tokens")
        }

        let averageSpeedup = result.incrementalResults.map(\.speedupRatio).reduce(0, +) / Double(result.incrementalResults.count)
        print("Average incremental speedup: \(String(format: "%.2f", averageSpeedup))x")
    }

    @Test("Tokenizer comparison")
    func testTokenizerComparison() async throws {
        let benchmark = TokenizerBenchmark()

        let result = try await benchmark.compareTokenizers(testSizes: [1000, 5000])

        #expect(result.comparisons.count == 2, "Should have comparison for each test size")

        for comparison in result.comparisons {
            #expect(comparison.results.count >= 3, "Should compare multiple tokenizers")

            // Verify all tokenizers produced results
            for tokenizerResult in comparison.results {
                #expect(tokenizerResult.duration > 0, "Should have positive duration")
                #expect(tokenizerResult.tokenCount > 0, "Should produce tokens")
                #expect(tokenizerResult.throughput > 0, "Should have positive throughput")
            }

            // Find the fastest tokenizer for this size
            let fastest = comparison.results.max { $0.throughput < $1.throughput }
            print("Fastest tokenizer for \(comparison.testSize) chars: \(fastest?.name ?? "Unknown")")
        }
    }

    @Test("Comprehensive benchmark")
    func testComprehensiveBenchmark() async throws {
        // Use a lighter configuration for testing
        let lightConfig = BenchmarkConfiguration(
            name: "Test",
            fileSizes: [1000, 2000],
            iterations: 5
        )

        let benchmark = TokenizerBenchmark(configurations: [lightConfig])

        let result = try await benchmark.runComprehensiveBenchmark()

        #expect(result.executionTime > 0, "Should have positive execution time")
        #expect(!result.throughputResults.isEmpty, "Should have throughput results")
        #expect(!result.memoryResults.isEmpty, "Should have memory results")
        #expect(!result.incrementalResults.incrementalResults.isEmpty, "Should have incremental results")
        #expect(!result.comparisonResults.comparisons.isEmpty, "Should have comparison results")

        // Verify summary
        #expect(result.summary.averageThroughput > 0, "Should have positive average throughput")
        #expect(result.summary.peakMemoryUsage > 0, "Should have positive peak memory")
        #expect(result.summary.averageIncrementalSpeedup > 0, "Should have positive incremental speedup")
        #expect(!result.summary.recommendedTokenizer.isEmpty, "Should recommend a tokenizer")

        print("Benchmark Summary:")
        print("- Average Throughput: \(result.summary.averageThroughput) chars/sec")
        print("- Peak Memory: \(result.summary.peakMemoryUsage) bytes")
        print("- Average Incremental Speedup: \(result.summary.averageIncrementalSpeedup)x")
        print("- Recommended Tokenizer: \(result.summary.recommendedTokenizer)")
    }

    @Test("Parallel tokenizer performance")
    func testParallelTokenizerPerformance() async throws {
        let parallelTokenizer = ParallelTokenizer()

        // Generate test content
        var content = ""
        for index in 0..<1000 {
            content += "変数 var\(index): 整数型 ← \(index)\n"
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        var tokenCount = 0

        for try await _ in try await parallelTokenizer.tokenizeInParallel(content) {
            tokenCount += 1
        }

        let duration = CFAbsoluteTimeGetCurrent() - startTime
        let throughput = Double(content.count) / duration

        #expect(tokenCount > 1000, "Should produce many tokens")
        #expect(duration < 2.0, "Should complete reasonably fast")
        #expect(throughput > 10000, "Should have good throughput")

        print("Parallel tokenizer throughput: \(throughput) chars/sec")
    }

    @Test("Pool statistics")
    func testPoolStatistics() async {
        let pool = TokenizerPool(size: 4)

        let initialStats = await pool.getStatistics()
        #expect(initialStats.available == 4, "Should start with all tokenizers available")
        #expect(initialStats.busy == 0, "Should start with no busy tokenizers")
        #expect(initialStats.maxSize == 4, "Should have correct max size")
        #expect(initialStats.utilization == 0, "Should start with 0% utilization")

        // Borrow some tokenizers
        let tokenizer1 = await pool.borrowTokenizer()
        let tokenizer2 = await pool.borrowTokenizer()

        let busyStats = await pool.getStatistics()
        #expect(busyStats.available == 2, "Should have 2 available after borrowing 2")
        #expect(busyStats.busy == 2, "Should have 2 busy after borrowing 2")
        #expect(busyStats.utilization == 0.5, "Should have 50% utilization")

        // Return tokenizers
        await pool.returnTokenizer(tokenizer1)
        await pool.returnTokenizer(tokenizer2)

        let finalStats = await pool.getStatistics()
        #expect(finalStats.available == 4, "Should have all available after returning")
        #expect(finalStats.busy == 0, "Should have none busy after returning")
        #expect(finalStats.utilization == 0, "Should have 0% utilization after returning")
    }

    @Test("Streaming vs batch performance")
    func testStreamingVsBatchPerformance() async throws {
        let content = String(repeating: "変数 x: 整数型 ← 42\n", count: 500)

        // Test batch tokenization
        let batchTokenizer = ParsingTokenizer()
        let batchStart = CFAbsoluteTimeGetCurrent()
        let batchTokens = try batchTokenizer.tokenize(content)
        let batchDuration = CFAbsoluteTimeGetCurrent() - batchStart

        // Test streaming tokenization
        let streamingTokenizer = ParallelTokenizer()
        let streamStart = CFAbsoluteTimeGetCurrent()
        var streamTokens: [Token] = []

        for try await token in try await streamingTokenizer.tokenizeInParallel(content) {
            streamTokens.append(token)
        }
        let streamDuration = CFAbsoluteTimeGetCurrent() - streamStart

        #expect(batchTokens.count == streamTokens.count, "Should produce same number of tokens")

        let batchThroughput = Double(content.count) / batchDuration
        let streamThroughput = Double(content.count) / streamDuration

        print("Batch throughput: \(batchThroughput) chars/sec")
        print("Stream throughput: \(streamThroughput) chars/sec")

        // Both should have reasonable performance
        #expect(batchThroughput > 1000, "Batch should have good throughput")
        #expect(streamThroughput > 1000, "Streaming should have good throughput")
    }

    @Test("Memory efficiency under pressure")
    func testMemoryEfficiencyUnderPressure() async throws {
        let benchmark = TokenizerBenchmark()

        // Test with increasing file sizes
        let sizes = [10_000, 20_000, 30_000]
        var memoryGrowth: [Int] = []

        for size in sizes {
            let result = try await benchmark.measureMemoryUsage(fileSize: size)
            let memoryUsed = result.peakMemory - result.baselineMemory
            memoryGrowth.append(memoryUsed)

            print("Size: \(size), Memory used: \(memoryUsed) bytes")
        }

        // Memory growth should be sublinear (not growing faster than input)
        for index in 1..<memoryGrowth.count {
            let sizeRatio = Double(sizes[index]) / Double(sizes[index-1])
            let memoryRatio = Double(memoryGrowth[index]) / Double(memoryGrowth[index-1])

            // Memory should not grow much faster than input size
            #expect(memoryRatio < sizeRatio * 2, "Memory growth should be reasonable")
        }
    }

    @Test("Performance metrics calculation")
    func testPerformanceMetricsCalculation() {
        let metrics = FeLangCore.PerformanceMetrics()
        let session = metrics.startMeasurement()

        // Simulate some work
        Thread.sleep(forTimeInterval: 0.01) // 10ms

        let result = session.end()

        #expect(result.duration > 0, "Should measure positive duration")
        #expect(result.duration < 1.0, "Should measure reasonable duration")
        #expect(result.endMemory >= 0, "Should have valid memory measurement")
    }

    @Test("Tokenizer metrics validation")
    func testTokenizerMetricsValidation() {
        let metrics = TokenizerMetrics(
            charactersProcessed: 1000,
            tokensProduced: 200,
            processingTime: 0.1,
            peakMemoryUsage: 50000
        )

        #expect(metrics.charactersProcessed == 1000, "Should preserve character count")
        #expect(metrics.tokensProduced == 200, "Should preserve token count")
        #expect(metrics.processingTime == 0.1, "Should preserve processing time")
        #expect(metrics.peakMemoryUsage == 50000, "Should preserve memory usage")

        let expectedThroughput = 10000.0 // 1000 / 0.1
        #expect(abs(metrics.throughput - expectedThroughput) < 0.001, "Should calculate correct throughput")
    }

    @Test("Stress test execution")
    func testStressTestExecution() async throws {
        _ = TokenizerBenchmark()

        // This is a simplified version of stress testing for unit tests
        let parallelTokenizer = ParallelTokenizer()

        // Create a moderately large content for stress testing
        var content = ""
        for index in 0..<2000 {
            content += "変数 stress\(index): 整数型 ← \(index % 100)\n"
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        let startMemory = getCurrentMemoryUsage()

        var tokenCount = 0
        for try await _ in try await parallelTokenizer.tokenizeInParallel(content) {
            tokenCount += 1
        }

        let duration = CFAbsoluteTimeGetCurrent() - startTime
        let endMemory = getCurrentMemoryUsage()

        #expect(tokenCount > 4000, "Should produce many tokens")
        #expect(duration < 3.0, "Should complete within reasonable time")

        let throughput = Double(content.count) / duration
        #expect(throughput > 5000, "Should maintain good throughput under stress")

        print("Stress test results:")
        print("- Duration: \(duration)s")
        print("- Throughput: \(throughput) chars/sec")
        print("- Memory delta: \(endMemory - startMemory) bytes")
    }

    @Test("Incremental efficiency under repeated edits")
    func testIncrementalEfficiencyUnderRepeatedEdits() throws {
        let incrementalTokenizer = IncrementalTokenizer()
        let baseTokenizer = ParsingTokenizer()

        // Start with a medium-sized document
        var document = ""
        for index in 0..<100 {
            document += "変数 item\(index): 整数型 ← \(index)\n"
        }

        var currentTokens = try baseTokenizer.tokenize(document)
        var currentText = document
        var totalIncrementalTime: TimeInterval = 0

        // Perform many small edits
        for index in 0..<50 {
            let insertionPoint = currentText.index(currentText.startIndex, offsetBy: min(index * 20, currentText.count))
            let range = insertionPoint..<insertionPoint
            let newText = " /* edit \(index) */"

            let startTime = CFAbsoluteTimeGetCurrent()
            let result = try incrementalTokenizer.updateTokens(
                in: range,
                with: newText,
                previousTokens: currentTokens,
                originalText: currentText
            )
            totalIncrementalTime += CFAbsoluteTimeGetCurrent() - startTime

            currentText = currentText.replacingCharacters(in: range, with: newText)
            currentTokens = result.tokens

            // Efficiency should remain reasonable
            #expect(result.metrics.efficiency > 0.3, "Should maintain reasonable efficiency")
        }

        // Compare total incremental time with full re-tokenization
        let fullStartTime = CFAbsoluteTimeGetCurrent()
        let fullTokens = try baseTokenizer.tokenize(currentText)
        let fullTime = CFAbsoluteTimeGetCurrent() - fullStartTime

        #expect(currentTokens.count == fullTokens.count, "Should produce correct number of tokens")

        let efficiencyRatio = totalIncrementalTime / fullTime
        print("Cumulative efficiency ratio: \(efficiencyRatio)")

        // Even with many edits, total time should not be excessively worse than full re-tokenization
        #expect(efficiencyRatio < 10.0, "Cumulative incremental time should be reasonable")
    }

    private func getCurrentMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return result == KERN_SUCCESS ? Int(info.resident_size) : 0
    }
}
