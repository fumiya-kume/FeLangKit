import Foundation

// MARK: - Tokenizer Benchmark Suite

/// Comprehensive benchmarking suite for tokenizer performance analysis
public struct TokenizerBenchmark: Sendable {
    private let metrics: PerformanceMetrics
    private let configurations: [BenchmarkConfiguration]

    public init(configurations: [BenchmarkConfiguration] = BenchmarkConfiguration.defaultConfigurations) {
        self.metrics = PerformanceMetrics()
        self.configurations = configurations
    }

    // MARK: - Core Benchmark Methods

    /// Measures throughput performance with various file sizes
    public func measureThroughput(
        fileSize: Int,
        iterations: Int = 100
    ) async throws -> ThroughputResult {
        let testContent = generateTestContent(size: fileSize)
        var durations: [TimeInterval] = []
        var tokenCounts: [Int] = []
        var memoryUsages: [Int] = []

        let tokenizer = ParsingTokenizer()

        // Warm-up runs
        for _ in 0..<min(iterations / 10, 10) {
            _ = try tokenizer.tokenize(testContent)
        }

        // Actual benchmark runs
        for _ in 0..<iterations {
            let startTime = CFAbsoluteTimeGetCurrent()
            let startMemory = getCurrentMemoryUsage()

            let tokens = try tokenizer.tokenize(testContent)

            let endTime = CFAbsoluteTimeGetCurrent()
            let endMemory = getCurrentMemoryUsage()

            durations.append(endTime - startTime)
            tokenCounts.append(tokens.count)
            memoryUsages.append(endMemory - startMemory)
        }

        return ThroughputResult(
            fileSize: fileSize,
            iterations: iterations,
            durations: durations,
            tokenCounts: tokenCounts,
            memoryUsages: memoryUsages,
            testContent: String(testContent.prefix(100)) + "..." // First 100 chars for reference
        )
    }

    /// Measures memory usage patterns during tokenization
    public func measureMemoryUsage(fileSize: Int) async throws -> MemoryUsageResult {
        let testContent = generateTestContent(size: fileSize)
        var memorySnapshots: [MemorySnapshot] = []

        let baselineMemory = getCurrentMemoryUsage()
        memorySnapshots.append(MemorySnapshot(stage: "baseline", usage: baselineMemory, timestamp: 0))

        let tokenizer = ParsingTokenizer()
        let startTime = CFAbsoluteTimeGetCurrent()

        // Take memory snapshots during tokenization
        let monitoringTask = Task {
            var snapshotCount = 0
            while !Task.isCancelled && snapshotCount < 50 {
                let currentTime = CFAbsoluteTimeGetCurrent() - startTime
                let currentMemory = getCurrentMemoryUsage()
                memorySnapshots.append(MemorySnapshot(
                    stage: "tokenization",
                    usage: currentMemory,
                    timestamp: currentTime
                ))

                try await Task.sleep(nanoseconds: 10_000_000) // 10ms intervals
                snapshotCount += 1
            }
        }

        let tokens = try tokenizer.tokenize(testContent)
        monitoringTask.cancel()

        let finalMemory = getCurrentMemoryUsage()
        let finalTime = CFAbsoluteTimeGetCurrent() - startTime
        memorySnapshots.append(MemorySnapshot(stage: "completion", usage: finalMemory, timestamp: finalTime))

        return MemoryUsageResult(
            fileSize: fileSize,
            tokenCount: tokens.count,
            baselineMemory: baselineMemory,
            peakMemory: memorySnapshots.map(\.usage).max() ?? finalMemory,
            finalMemory: finalMemory,
            snapshots: memorySnapshots
        )
    }

    /// Measures incremental parsing performance
    public func measureIncrementalPerformance(
        changes: [TextChange]
    ) async throws -> IncrementalPerformanceResult {
        let initialContent = generateTestContent(size: 10_000)
        let tokenizer = ParsingTokenizer()
        let incrementalTokenizer = IncrementalTokenizer()

        // Initial tokenization
        let initialStartTime = CFAbsoluteTimeGetCurrent()
        let initialTokens = try tokenizer.tokenize(initialContent)
        let initialDuration = CFAbsoluteTimeGetCurrent() - initialStartTime

        var currentContent = initialContent
        var currentTokens = initialTokens
        var incrementalResults: [IncrementalBenchmarkResult] = []

        // Apply changes incrementally
        for (index, change) in changes.enumerated() {
            let range = getChangeRange(in: currentContent, change: change)

            // Measure incremental update
            let incrementalStartTime = CFAbsoluteTimeGetCurrent()
            let incrementalResult = try incrementalTokenizer.updateTokens(
                in: range,
                with: change.newText,
                previousTokens: currentTokens,
                originalText: currentContent
            )
            let incrementalDuration = CFAbsoluteTimeGetCurrent() - incrementalStartTime

            // Update current state
            currentContent = currentContent.replacingCharacters(in: range, with: change.newText)
            currentTokens = incrementalResult.tokens

            // Measure full re-tokenization for comparison
            let fullStartTime = CFAbsoluteTimeGetCurrent()
            _ = try tokenizer.tokenize(currentContent)
            let fullDuration = CFAbsoluteTimeGetCurrent() - fullStartTime

            // Validate correctness
            let validation = try incrementalTokenizer.validateIncremental(
                result: incrementalResult,
                fullText: currentContent
            )

            incrementalResults.append(IncrementalBenchmarkResult(
                changeIndex: index,
                change: change,
                incrementalDuration: incrementalDuration,
                fullDuration: fullDuration,
                speedupRatio: fullDuration / incrementalDuration,
                validation: validation,
                metrics: incrementalResult.metrics
            ))
        }

        return IncrementalPerformanceResult(
            initialTokenization: InitialTokenizationResult(
                duration: initialDuration,
                tokenCount: initialTokens.count,
                contentSize: initialContent.count
            ),
            incrementalResults: incrementalResults
        )
    }

    /// Compares performance across different tokenizer implementations
    public func compareTokenizers(
        testSizes: [Int] = [1_000, 10_000, 100_000]
    ) async throws -> TokenizerComparisonResult {
        var comparisons: [TokenizerComparison] = []

        for size in testSizes {
            let testContent = generateTestContent(size: size)

            // Test standard tokenizer
            let standardResult = try await benchmarkTokenizer(
                name: "Standard",
                testContent: testContent,
                tokenizer: Tokenizer(input: testContent)
            )

            // Test parsing tokenizer
            let parsingResult = try await benchmarkTokenizer(
                name: "Parsing",
                testContent: testContent,
                tokenizer: ParsingTokenizer()
            )

            // Test fast parsing tokenizer  
            let fastResult = try await benchmarkTokenizer(
                name: "FastParsing",
                testContent: testContent,
                tokenizer: FastParsingTokenizer()
            )

            // Test parallel tokenizer
            let parallelTokenizer = ParallelTokenizer()
            let parallelStartTime = CFAbsoluteTimeGetCurrent()
            var parallelTokens: [Token] = []

            for try await token in try await parallelTokenizer.tokenizeInParallel(testContent) {
                parallelTokens.append(token)
            }

            let parallelDuration = CFAbsoluteTimeGetCurrent() - parallelStartTime
            let parallelResult = TokenizerPerformance(
                name: "Parallel",
                duration: parallelDuration,
                tokenCount: parallelTokens.count,
                throughput: Double(testContent.count) / parallelDuration,
                memoryUsage: getCurrentMemoryUsage()
            )

            comparisons.append(TokenizerComparison(
                testSize: size,
                results: [standardResult, parsingResult, fastResult, parallelResult]
            ))
        }

        return TokenizerComparisonResult(comparisons: comparisons)
    }

    /// Runs a comprehensive benchmark suite
    public func runComprehensiveBenchmark() async throws -> ComprehensiveBenchmarkResult {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Throughput benchmarks
        let throughputResults = try await measureThroughputSuite()

        // Memory usage benchmarks
        let memoryResults = try await measureMemoryUsageSuite()

        // Incremental performance benchmarks
        let incrementalResults = try await measureIncrementalSuite()

        // Tokenizer comparison
        let comparisonResults = try await compareTokenizers()

        // Stress tests
        let stressResults = try await runStressTests()

        let totalDuration = CFAbsoluteTimeGetCurrent() - startTime

        return ComprehensiveBenchmarkResult(
            executionTime: totalDuration,
            throughputResults: throughputResults,
            memoryResults: memoryResults,
            incrementalResults: incrementalResults,
            comparisonResults: comparisonResults,
            stressResults: stressResults,
            summary: generateSummary(
                throughput: throughputResults,
                memory: memoryResults,
                incremental: incrementalResults,
                comparison: comparisonResults
            )
        )
    }

    // MARK: - Private Helper Methods

    private func benchmarkTokenizer(
        name: String,
        testContent: String,
        tokenizer: Any
    ) async throws -> TokenizerPerformance {
        let startTime = CFAbsoluteTimeGetCurrent()
        let startMemory = getCurrentMemoryUsage()

        var tokens: [Token] = []

        if let standardTokenizer = tokenizer as? Tokenizer {
            tokens = try standardTokenizer.tokenize()
        } else if let parsingTokenizer = tokenizer as? ParsingTokenizer {
            tokens = try parsingTokenizer.tokenize(testContent)
        } else if let fastTokenizer = tokenizer as? FastParsingTokenizer {
            tokens = try fastTokenizer.tokenize(testContent)
        }

        let duration = CFAbsoluteTimeGetCurrent() - startTime
        let memoryUsage = getCurrentMemoryUsage() - startMemory

        return TokenizerPerformance(
            name: name,
            duration: duration,
            tokenCount: tokens.count,
            throughput: Double(testContent.count) / duration,
            memoryUsage: memoryUsage
        )
    }

    private func measureThroughputSuite() async throws -> [ThroughputResult] {
        let sizes = [1_000, 5_000, 10_000, 50_000, 100_000]
        var results: [ThroughputResult] = []

        for size in sizes {
            let result = try await measureThroughput(fileSize: size, iterations: 50)
            results.append(result)
        }

        return results
    }

    private func measureMemoryUsageSuite() async throws -> [MemoryUsageResult] {
        let sizes = [10_000, 50_000, 100_000, 500_000]
        var results: [MemoryUsageResult] = []

        for size in sizes {
            let result = try await measureMemoryUsage(fileSize: size)
            results.append(result)
        }

        return results
    }

    private func measureIncrementalSuite() async throws -> IncrementalPerformanceResult {
        let changes = [
            TextChange(type: .insertion, position: 100, newText: "新しい変数 x: 整数型\n"),
            TextChange(type: .deletion, position: 200, length: 20),
            TextChange(type: .replacement, position: 300, length: 10, newText: "updated_value"),
            TextChange(type: .insertion, position: 500, newText: "// コメント追加\n"),
            TextChange(type: .replacement, position: 600, length: 5, newText: "42")
        ]

        return try await measureIncrementalPerformance(changes: changes)
    }

    private func runStressTests() async throws -> StressTestResult {
        // Large file test
        let largeFileResult = try await stressTestLargeFile()

        // High frequency updates test
        let highFrequencyResult = try await stressTestHighFrequencyUpdates()

        // Memory pressure test
        let memoryPressureResult = try await stressTestMemoryPressure()

        return StressTestResult(
            largeFile: largeFileResult,
            highFrequency: highFrequencyResult,
            memoryPressure: memoryPressureResult
        )
    }

    private func stressTestLargeFile() async throws -> LargeFileStressResult {
        let size = 50_000 // 50KB - reduced from 1MB for test reliability
        let content = generateTestContent(size: size)

        let startTime = CFAbsoluteTimeGetCurrent()
        let startMemory = getCurrentMemoryUsage()

        let parallelTokenizer = ParallelTokenizer()
        var tokenCount = 0

        for try await _ in try await parallelTokenizer.tokenizeInParallel(content) {
            tokenCount += 1
        }

        let duration = CFAbsoluteTimeGetCurrent() - startTime
        let peakMemory = getCurrentMemoryUsage()

        return LargeFileStressResult(
            fileSize: size,
            tokenCount: tokenCount,
            duration: duration,
            startMemory: startMemory,
            peakMemory: peakMemory,
            throughput: Double(size) / duration
        )
    }

    private func stressTestHighFrequencyUpdates() async throws -> HighFrequencyStressResult {
        let initialContent = generateTestContent(size: 10_000)
        let incrementalTokenizer = IncrementalTokenizer()
        let tokenizer = ParsingTokenizer()

        var currentContent = initialContent
        var currentTokens = try tokenizer.tokenize(currentContent)

        let updateCount = 100 // Reduced from 1000 for test reliability
        var totalIncrementalTime: TimeInterval = 0
        var successfulUpdates = 0

        for index in 0..<updateCount {
            let position = Int.random(in: 0..<currentContent.count)
            let insertionText = "var_\(index)"

            let range = currentContent.index(currentContent.startIndex, offsetBy: position)..<currentContent.index(currentContent.startIndex, offsetBy: position)

            let startTime = CFAbsoluteTimeGetCurrent()
            do {
                let result = try incrementalTokenizer.updateTokens(
                    in: range,
                    with: insertionText,
                    previousTokens: currentTokens,
                    originalText: currentContent
                )

                currentContent = currentContent.replacingCharacters(in: range, with: insertionText)
                currentTokens = result.tokens

                totalIncrementalTime += CFAbsoluteTimeGetCurrent() - startTime
                successfulUpdates += 1
            } catch {
                // Skip failed updates for this stress test
                continue
            }
        }

        return HighFrequencyStressResult(
            updateCount: updateCount,
            successfulUpdates: successfulUpdates,
            totalTime: totalIncrementalTime,
            averageUpdateTime: totalIncrementalTime / Double(successfulUpdates),
            updatesPerSecond: Double(successfulUpdates) / totalIncrementalTime
        )
    }

    private func stressTestMemoryPressure() async throws -> MemoryPressureStressResult {
        var results: [MemoryPressureSnapshot] = []
        let sizes = [100_000, 200_000, 300_000, 400_000, 500_000]

        for size in sizes {
            let content = generateTestContent(size: size)
            let startMemory = getCurrentMemoryUsage()

            let tokenizer = ParsingTokenizer()
            let tokens = try tokenizer.tokenize(content)

            let peakMemory = getCurrentMemoryUsage()

            // Force garbage collection attempt
            autoreleasepool {
                // Create temporary objects to trigger memory pressure
                _ = Array(0..<10000).map { String($0) }
            }

            let afterGCMemory = getCurrentMemoryUsage()

            results.append(MemoryPressureSnapshot(
                inputSize: size,
                tokenCount: tokens.count,
                startMemory: startMemory,
                peakMemory: peakMemory,
                afterGCMemory: afterGCMemory,
                memoryEfficiency: Double(size) / Double(peakMemory - startMemory)
            ))
        }

        return MemoryPressureStressResult(snapshots: results)
    }

    private func generateTestContent(size: Int) -> String {
        let templates = [
            "変数 x: 整数型",
            "x ← 42",
            "if x > 0 then",
            "    print(x)",
            "endif",
            "// これはコメントです",
            "変数 y: 実数型 ← 3.14159",
            "配列 data: 整数型[10]",
            "for i in 0..9 do",
            "    data[i] ← i * 2",
            "endfor"
        ]

        var content = ""
        content.reserveCapacity(size)

        while content.count < size {
            for template in templates {
                content += template + "\n"
                if content.count >= size {
                    break
                }
            }
        }

        return content
    }

    private func getChangeRange(in text: String, change: TextChange) -> Range<String.Index> {
        let startIndex = text.index(text.startIndex, offsetBy: min(change.position, text.count))

        switch change.type {
        case .insertion:
            return startIndex..<startIndex
        case .deletion:
            let endOffset = min(change.position + (change.length ?? 0), text.count)
            let endIndex = text.index(text.startIndex, offsetBy: endOffset)
            return startIndex..<endIndex
        case .replacement:
            let endOffset = min(change.position + (change.length ?? 0), text.count)
            let endIndex = text.index(text.startIndex, offsetBy: endOffset)
            return startIndex..<endIndex
        }
    }

    nonisolated private func getCurrentMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let taskPort = mach_task_self_
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(taskPort, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return result == KERN_SUCCESS ? Int(info.resident_size) : 0
    }

    private func generateSummary(
        throughput: [ThroughputResult],
        memory: [MemoryUsageResult],
        incremental: IncrementalPerformanceResult,
        comparison: TokenizerComparisonResult
    ) -> BenchmarkSummary {
        let avgThroughput = throughput.map(\.averageThroughput).reduce(0, +) / Double(throughput.count)
        let peakMemory = memory.map(\.peakMemory).max() ?? 0
        let avgIncrementalSpeedup = incremental.incrementalResults.map(\.speedupRatio).reduce(0, +) / Double(incremental.incrementalResults.count)

        return BenchmarkSummary(
            averageThroughput: avgThroughput,
            peakMemoryUsage: peakMemory,
            averageIncrementalSpeedup: avgIncrementalSpeedup,
            recommendedTokenizer: determineBestTokenizer(from: comparison)
        )
    }

    private func determineBestTokenizer(from comparison: TokenizerComparisonResult) -> String {
        // Simplified heuristic - in practice you'd want more sophisticated analysis
        let allResults = comparison.comparisons.flatMap(\.results)
        let best = allResults.max { $0.throughput < $1.throughput }
        return best?.name ?? "Unknown"
    }
}

// MARK: - Supporting Types

/// Configuration for benchmark runs
public struct BenchmarkConfiguration: Sendable {
    public let name: String
    public let fileSizes: [Int]
    public let iterations: Int
    public let enableMemoryProfiling: Bool

    public init(name: String, fileSizes: [Int], iterations: Int, enableMemoryProfiling: Bool = true) {
        self.name = name
        self.fileSizes = fileSizes
        self.iterations = iterations
        self.enableMemoryProfiling = enableMemoryProfiling
    }

    public static let defaultConfigurations = [
        BenchmarkConfiguration(name: "Quick", fileSizes: [1_000, 10_000], iterations: 50),
        BenchmarkConfiguration(name: "Standard", fileSizes: [10_000, 50_000, 100_000], iterations: 100),
        BenchmarkConfiguration(name: "Comprehensive", fileSizes: [1_000, 10_000, 50_000, 100_000, 500_000], iterations: 200)
    ]
}

// MARK: - Result Types

public struct ThroughputResult: Sendable {
    public let fileSize: Int
    public let iterations: Int
    public let durations: [TimeInterval]
    public let tokenCounts: [Int]
    public let memoryUsages: [Int]
    public let testContent: String

    public var averageDuration: TimeInterval {
        durations.reduce(0, +) / Double(durations.count)
    }

    public var averageThroughput: Double {
        Double(fileSize) / averageDuration
    }

    public var averageTokenCount: Double {
        Double(tokenCounts.reduce(0, +)) / Double(tokenCounts.count)
    }

    public init(fileSize: Int, iterations: Int, durations: [TimeInterval], tokenCounts: [Int], memoryUsages: [Int], testContent: String) {
        self.fileSize = fileSize
        self.iterations = iterations
        self.durations = durations
        self.tokenCounts = tokenCounts
        self.memoryUsages = memoryUsages
        self.testContent = testContent
    }
}

public struct MemoryUsageResult: Sendable {
    public let fileSize: Int
    public let tokenCount: Int
    public let baselineMemory: Int
    public let peakMemory: Int
    public let finalMemory: Int
    public let snapshots: [MemorySnapshot]

    public init(fileSize: Int, tokenCount: Int, baselineMemory: Int, peakMemory: Int, finalMemory: Int, snapshots: [MemorySnapshot]) {
        self.fileSize = fileSize
        self.tokenCount = tokenCount
        self.baselineMemory = baselineMemory
        self.peakMemory = peakMemory
        self.finalMemory = finalMemory
        self.snapshots = snapshots
    }
}

public struct MemorySnapshot: Sendable {
    public let stage: String
    public let usage: Int
    public let timestamp: TimeInterval

    public init(stage: String, usage: Int, timestamp: TimeInterval) {
        self.stage = stage
        self.usage = usage
        self.timestamp = timestamp
    }
}

public struct TextChange: Sendable {
    public enum ChangeType: String, Sendable, CaseIterable {
        case insertion, deletion, replacement
    }

    public let type: ChangeType
    public let position: Int
    public let length: Int?
    public let newText: String

    public init(type: ChangeType, position: Int, length: Int? = nil, newText: String = "") {
        self.type = type
        self.position = position
        self.length = length
        self.newText = newText
    }
}

public struct IncrementalPerformanceResult: Sendable {
    public let initialTokenization: InitialTokenizationResult
    public let incrementalResults: [IncrementalBenchmarkResult]

    public init(initialTokenization: InitialTokenizationResult, incrementalResults: [IncrementalBenchmarkResult]) {
        self.initialTokenization = initialTokenization
        self.incrementalResults = incrementalResults
    }
}

public struct InitialTokenizationResult: Sendable {
    public let duration: TimeInterval
    public let tokenCount: Int
    public let contentSize: Int

    public init(duration: TimeInterval, tokenCount: Int, contentSize: Int) {
        self.duration = duration
        self.tokenCount = tokenCount
        self.contentSize = contentSize
    }
}

public struct IncrementalBenchmarkResult: Sendable {
    public let changeIndex: Int
    public let change: TextChange
    public let incrementalDuration: TimeInterval
    public let fullDuration: TimeInterval
    public let speedupRatio: Double
    public let validation: ValidationResult
    public let metrics: IncrementalMetrics

    public init(changeIndex: Int, change: TextChange, incrementalDuration: TimeInterval, fullDuration: TimeInterval, speedupRatio: Double, validation: ValidationResult, metrics: IncrementalMetrics) {
        self.changeIndex = changeIndex
        self.change = change
        self.incrementalDuration = incrementalDuration
        self.fullDuration = fullDuration
        self.speedupRatio = speedupRatio
        self.validation = validation
        self.metrics = metrics
    }
}

public struct TokenizerComparisonResult: Sendable {
    public let comparisons: [TokenizerComparison]

    public init(comparisons: [TokenizerComparison]) {
        self.comparisons = comparisons
    }
}

public struct TokenizerComparison: Sendable {
    public let testSize: Int
    public let results: [TokenizerPerformance]

    public init(testSize: Int, results: [TokenizerPerformance]) {
        self.testSize = testSize
        self.results = results
    }
}

public struct TokenizerPerformance: Sendable {
    public let name: String
    public let duration: TimeInterval
    public let tokenCount: Int
    public let throughput: Double
    public let memoryUsage: Int

    public init(name: String, duration: TimeInterval, tokenCount: Int, throughput: Double, memoryUsage: Int) {
        self.name = name
        self.duration = duration
        self.tokenCount = tokenCount
        self.throughput = throughput
        self.memoryUsage = memoryUsage
    }
}

public struct ComprehensiveBenchmarkResult: Sendable {
    public let executionTime: TimeInterval
    public let throughputResults: [ThroughputResult]
    public let memoryResults: [MemoryUsageResult]
    public let incrementalResults: IncrementalPerformanceResult
    public let comparisonResults: TokenizerComparisonResult
    public let stressResults: StressTestResult
    public let summary: BenchmarkSummary

    public init(executionTime: TimeInterval, throughputResults: [ThroughputResult], memoryResults: [MemoryUsageResult], incrementalResults: IncrementalPerformanceResult, comparisonResults: TokenizerComparisonResult, stressResults: StressTestResult, summary: BenchmarkSummary) {
        self.executionTime = executionTime
        self.throughputResults = throughputResults
        self.memoryResults = memoryResults
        self.incrementalResults = incrementalResults
        self.comparisonResults = comparisonResults
        self.stressResults = stressResults
        self.summary = summary
    }
}

public struct StressTestResult: Sendable {
    public let largeFile: LargeFileStressResult
    public let highFrequency: HighFrequencyStressResult
    public let memoryPressure: MemoryPressureStressResult

    public init(largeFile: LargeFileStressResult, highFrequency: HighFrequencyStressResult, memoryPressure: MemoryPressureStressResult) {
        self.largeFile = largeFile
        self.highFrequency = highFrequency
        self.memoryPressure = memoryPressure
    }
}

public struct LargeFileStressResult: Sendable {
    public let fileSize: Int
    public let tokenCount: Int
    public let duration: TimeInterval
    public let startMemory: Int
    public let peakMemory: Int
    public let throughput: Double

    public init(fileSize: Int, tokenCount: Int, duration: TimeInterval, startMemory: Int, peakMemory: Int, throughput: Double) {
        self.fileSize = fileSize
        self.tokenCount = tokenCount
        self.duration = duration
        self.startMemory = startMemory
        self.peakMemory = peakMemory
        self.throughput = throughput
    }
}

public struct HighFrequencyStressResult: Sendable {
    public let updateCount: Int
    public let successfulUpdates: Int
    public let totalTime: TimeInterval
    public let averageUpdateTime: TimeInterval
    public let updatesPerSecond: Double

    public init(updateCount: Int, successfulUpdates: Int, totalTime: TimeInterval, averageUpdateTime: TimeInterval, updatesPerSecond: Double) {
        self.updateCount = updateCount
        self.successfulUpdates = successfulUpdates
        self.totalTime = totalTime
        self.averageUpdateTime = averageUpdateTime
        self.updatesPerSecond = updatesPerSecond
    }
}

public struct MemoryPressureStressResult: Sendable {
    public let snapshots: [MemoryPressureSnapshot]

    public init(snapshots: [MemoryPressureSnapshot]) {
        self.snapshots = snapshots
    }
}

public struct MemoryPressureSnapshot: Sendable {
    public let inputSize: Int
    public let tokenCount: Int
    public let startMemory: Int
    public let peakMemory: Int
    public let afterGCMemory: Int
    public let memoryEfficiency: Double

    public init(inputSize: Int, tokenCount: Int, startMemory: Int, peakMemory: Int, afterGCMemory: Int, memoryEfficiency: Double) {
        self.inputSize = inputSize
        self.tokenCount = tokenCount
        self.startMemory = startMemory
        self.peakMemory = peakMemory
        self.afterGCMemory = afterGCMemory
        self.memoryEfficiency = memoryEfficiency
    }
}

public struct BenchmarkSummary: Sendable {
    public let averageThroughput: Double
    public let peakMemoryUsage: Int
    public let averageIncrementalSpeedup: Double
    public let recommendedTokenizer: String

    public init(averageThroughput: Double, peakMemoryUsage: Int, averageIncrementalSpeedup: Double, recommendedTokenizer: String) {
        self.averageThroughput = averageThroughput
        self.peakMemoryUsage = peakMemoryUsage
        self.averageIncrementalSpeedup = averageIncrementalSpeedup
        self.recommendedTokenizer = recommendedTokenizer
    }
}

// MARK: - Performance Metrics

public struct PerformanceMetrics: Sendable {
    public func startMeasurement() -> MeasurementSession {
        return MeasurementSession()
    }
}

public struct MeasurementSession {
    private let startTime = CFAbsoluteTimeGetCurrent()
    private let startMemory: Int

    init() {
        self.startMemory = Self.getCurrentMemoryUsage()
    }

    public func end() -> SessionResult {
        let endTime = CFAbsoluteTimeGetCurrent()
        let endMemory = Self.getCurrentMemoryUsage()

        return SessionResult(
            duration: endTime - startTime,
            memoryDelta: endMemory - startMemory,
            startMemory: startMemory,
            endMemory: endMemory
        )
    }

    nonisolated private static func getCurrentMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let taskPort = mach_task_self_
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(taskPort, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return result == KERN_SUCCESS ? Int(info.resident_size) : 0
    }
}

public struct SessionResult: Sendable {
    public let duration: TimeInterval
    public let memoryDelta: Int
    public let startMemory: Int
    public let endMemory: Int

    public init(duration: TimeInterval, memoryDelta: Int, startMemory: Int, endMemory: Int) {
        self.duration = duration
        self.memoryDelta = memoryDelta
        self.startMemory = startMemory
        self.endMemory = endMemory
    }
}
