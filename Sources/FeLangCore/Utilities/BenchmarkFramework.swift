import Foundation
@preconcurrency import Darwin

/// Comprehensive benchmark framework for FeLangKit performance measurement
/// Implements automated benchmarking, memory profiling, and CI/CD integration
public struct BenchmarkFramework {

    // MARK: - Benchmark Configuration

    public struct BenchmarkConfig: Sendable {
        public let iterations: Int
        public let warmupIterations: Int
        public let memoryProfiling: Bool
        public let detailedTiming: Bool

        public init(
            iterations: Int = 10,
            warmupIterations: Int = 3,
            memoryProfiling: Bool = true,
            detailedTiming: Bool = false
        ) {
            self.iterations = iterations
            self.warmupIterations = warmupIterations
            self.memoryProfiling = memoryProfiling
            self.detailedTiming = detailedTiming
        }

        public static let `default` = BenchmarkConfig()
        public static let quick = BenchmarkConfig(iterations: 3, warmupIterations: 1, memoryProfiling: false)
        public static let comprehensive = BenchmarkConfig(iterations: 20, warmupIterations: 5, detailedTiming: true)
    }

    // MARK: - Benchmark Results

    public struct BenchmarkResult: Codable {
        public let testName: String
        public let sourceSize: Int
        public let tokenCount: Int
        public let averageTime: TimeInterval
        public let minTime: TimeInterval
        public let maxTime: TimeInterval
        public let standardDeviation: TimeInterval
        public let tokensPerSecond: Double
        public let memoryUsage: MemoryUsage?
        public let environment: BenchmarkEnvironment

        public var throughputMBPerSecond: Double {
            let sizeInMB = Double(sourceSize) / 1_000_000.0
            return sizeInMB / averageTime
        }

        public var formattedSummary: String {
            let memoryInfo = memoryUsage?.formattedSummary ?? "N/A"
            return """
            \(testName):
              Source: \(sourceSize) chars, Tokens: \(tokenCount)
              Time: \(String(format: "%.4f", averageTime))s (±\(String(format: "%.4f", standardDeviation))s)
              Range: \(String(format: "%.4f", minTime))s - \(String(format: "%.4f", maxTime))s
              Throughput: \(String(format: "%.0f", tokensPerSecond)) tokens/s, \(String(format: "%.2f", throughputMBPerSecond)) MB/s
              Memory: \(memoryInfo)
            """
        }
    }

    public struct MemoryUsage: Codable {
        public let peakMemory: Int64
        public let averageMemory: Int64
        public let memoryGrowth: Int64

        public var formattedSummary: String {
            return "\(peakMemory / 1_000_000)MB peak, \(averageMemory / 1_000_000)MB avg, \(memoryGrowth / 1_000_000)MB growth"
        }
    }

    public struct BenchmarkEnvironment: Codable {
        public let device: String
        public let operatingSystem: String
        public let platform: String
        public let swiftVersion: String
        public let buildConfiguration: String
        public let optimizationLevel: String
        public let timestamp: Date

        public init() {
            let processInfo = ProcessInfo.processInfo

            #if os(macOS)
            self.device = "Mac"
            self.operatingSystem = "macOS \(processInfo.operatingSystemVersionString)"
            #elseif os(iOS)
            self.device = "iOS Device"
            self.operatingSystem = "iOS \(processInfo.operatingSystemVersionString)"
            #else
            self.device = "Unknown"
            self.operatingSystem = processInfo.operatingSystemVersionString
            #endif

            self.platform = "\(processInfo.operatingSystemVersionString)"
            self.swiftVersion = processInfo.environment["SWIFT_VERSION"] ?? "Unknown"

            #if DEBUG
            self.buildConfiguration = "Debug"
            self.optimizationLevel = "Debug"
            #else
            self.buildConfiguration = "Release"
            self.optimizationLevel = "Release"
            #endif

            self.timestamp = Date()
        }
    }

    // MARK: - Test Case Definitions

    public enum TestCaseSize: String, CaseIterable, Codable {
        case small = "Small"
        case medium = "Medium"
        case large = "Large"

        public var characterCount: Int {
            switch self {
            case .small: return 100
            case .medium: return 1_000
            case .large: return 10_000
            }
        }
    }

    public struct TestCaseResult: Codable {
        public let size: TestCaseSize
        public let results: [BenchmarkResult]

        // Extended properties for comprehensive testing
        public let name: String
        public let sourceSize: Int
        public let iterations: Int
        public let benchmarkResult: TokenizerBenchmarkResult

        public var averageTokensPerSecond: Double {
            let total = results.reduce(0.0) { $0 + $1.tokensPerSecond }
            return total / Double(results.count)
        }

        public var averageThroughput: Double {
            let total = results.reduce(0.0) { $0 + $1.throughputMBPerSecond }
            return total / Double(results.count)
        }

        // Initializer for legacy usage
        public init(size: TestCaseSize, results: [BenchmarkResult]) {
            self.size = size
            self.results = results
            self.name = size.rawValue
            self.sourceSize = results.first?.sourceSize ?? 0
            self.iterations = results.count

            let avgTokensPerSec = results.map(\.tokensPerSecond).reduce(0, +) / Double(results.count)
            let avgTime = results.map(\.averageTime).reduce(0, +) / Double(results.count)
            let avgMemory = results.compactMap(\.memoryUsage?.averageMemory).reduce(0, +) / Int64(max(1, results.compactMap(\.memoryUsage).count))

            let times = results.map(\.averageTime)
            let sortedTimes = times.sorted()
            let median = sortedTimes[sortedTimes.count / 2]
            let variance = times.map { pow($0 - avgTime, 2) }.reduce(0, +) / Double(times.count)
            let stdDev = sqrt(variance)

            self.benchmarkResult = TokenizerBenchmarkResult(
                averageTokensPerSecond: avgTokensPerSec,
                averageProcessingTime: avgTime,
                averageMemoryUsage: UInt64(max(0, avgMemory)),
                statistics: BenchmarkStatistics(
                    min: sortedTimes.first ?? 0,
                    max: sortedTimes.last ?? 0,
                    median: median,
                    standardDeviation: stdDev
                )
            )
        }

        // Initializer for comprehensive testing
        public init(name: String, sourceSize: Int, iterations: Int, benchmarkResult: TokenizerBenchmarkResult) {
            self.name = name
            self.sourceSize = sourceSize
            self.iterations = iterations
            self.benchmarkResult = benchmarkResult

            // Generate legacy results for backward compatibility
            self.size = .small // Default
            self.results = []
        }
    }

    // MARK: - Tokenizer Protocol

    public protocol TokenizerProtocol {
        func tokenize(_ input: String) throws -> [Token]
        var name: String { get }
    }

    // MARK: - Benchmark Execution

    public static func benchmarkTokenizer<T: TokenizerProtocol>(
        _ tokenizer: T,
        config: BenchmarkConfig = .default
    ) -> [TestCaseResult] {
        var results: [TestCaseResult] = []

        for size in TestCaseSize.allCases {
            let testCases = generateTestCases(for: size)
            var sizeResults: [BenchmarkResult] = []

            for (testName, source) in testCases {
                let result = benchmarkSingleCase(
                    tokenizer: tokenizer,
                    testName: "\(tokenizer.name) - \(size.rawValue) - \(testName)",
                    source: source,
                    config: config
                )
                sizeResults.append(result)
            }

            results.append(TestCaseResult(size: size, results: sizeResults))
        }

        return results
    }

    public static func benchmarkSingleCase<T: TokenizerProtocol>(
        tokenizer: T,
        testName: String,
        source: String,
        config: BenchmarkConfig
    ) -> BenchmarkResult {

        // Warmup iterations
        for _ in 0..<config.warmupIterations {
            _ = try? tokenizer.tokenize(source)
        }

        var times: [TimeInterval] = []
        var memoryMeasurements: [Int64] = []
        var tokenCount = 0

        for _ in 0..<config.iterations {
            let memoryBefore = config.memoryProfiling ? getMemoryUsage() : 0

            let startTime = CFAbsoluteTimeGetCurrent()
            let tokens = (try? tokenizer.tokenize(source)) ?? []
            let endTime = CFAbsoluteTimeGetCurrent()

            let memoryAfter = config.memoryProfiling ? getMemoryUsage() : 0

            times.append(endTime - startTime)
            if config.memoryProfiling {
                memoryMeasurements.append(memoryAfter - memoryBefore)
            }
            tokenCount = tokens.count
        }

        // Calculate statistics
        let averageTime = times.reduce(0, +) / Double(times.count)
        let minTime = times.min() ?? 0
        let maxTime = times.max() ?? 0
        let variance = times.map { pow($0 - averageTime, 2) }.reduce(0, +) / Double(times.count)
        let standardDeviation = sqrt(variance)
        let tokensPerSecond = Double(tokenCount) / averageTime

        let memoryUsage: MemoryUsage?
        if config.memoryProfiling && !memoryMeasurements.isEmpty {
            let peakMemory = memoryMeasurements.max() ?? 0
            let averageMemory = memoryMeasurements.reduce(0, +) / Int64(memoryMeasurements.count)
            let memoryGrowth = memoryMeasurements.last ?? 0
            memoryUsage = MemoryUsage(
                peakMemory: peakMemory,
                averageMemory: averageMemory,
                memoryGrowth: memoryGrowth
            )
        } else {
            memoryUsage = nil
        }

        return BenchmarkResult(
            testName: testName,
            sourceSize: source.count,
            tokenCount: tokenCount,
            averageTime: averageTime,
            minTime: minTime,
            maxTime: maxTime,
            standardDeviation: standardDeviation,
            tokensPerSecond: tokensPerSecond,
            memoryUsage: memoryUsage,
            environment: BenchmarkEnvironment()
        )
    }

    // MARK: - Test Case Generation

    public static func generateTestCases(for size: TestCaseSize) -> [(String, String)] {
        let baseSize = size.characterCount

        return [
            ("Basic", generateBasicFECode(size: baseSize)),
            ("Unicode Heavy", generateUnicodeHeavyCode(size: baseSize)),
            ("Keyword Heavy", generateKeywordHeavyCode(size: baseSize)),
            ("Mixed Content", generateMixedContent(size: baseSize))
        ]
    }

    private static func generateBasicFECode(size: Int) -> String {
        let template = """
        変数 x: 整数型
        変数 y: 実数型
        x ← 10
        y ← 3.14
        if x > 5 then
            y ← y * 2
        endif
        """

        return repeatToSize(template, targetSize: size)
    }

    private static func generateUnicodeHeavyCode(size: Int) -> String {
        let template = """
        // 日本語コメント：これはテストです
        変数 データ: 文字列型
        変数 カウンタ: 整数型
        データ ← "こんにちは世界"
        カウンタ ← 0
        while カウンタ < 10 do
            データ ← データ + "！"
            カウンタ ← カウンタ + 1
        endwhile
        """

        return repeatToSize(template, targetSize: size)
    }

    private static func generateKeywordHeavyCode(size: Int) -> String {
        let template = """
        function calculate(x: 整数型, y: 整数型): 整数型
            if x > y then
                return x + y
            elif x < y then
                return x - y
            else
                return x * y
            endif
        endfunction

        procedure main()
            変数 result: 整数型
            result ← calculate(10, 20)
        endprocedure
        """

        return repeatToSize(template, targetSize: size)
    }

    private static func generateMixedContent(size: Int) -> String {
        let template = """
        // Mixed English and Japanese
        変数 name: 文字列型
        変数 age: 整数型
        name ← "田中太郎"
        age ← 25

        if age >= 20 then
            name ← name + " (adult)"
        else
            name ← name + " (minor)"
        endif

        for i ← 1 to 5 step 1 do
            // Process data
            age ← age + 1
        endfor
        """

        return repeatToSize(template, targetSize: size)
    }

    private static func repeatToSize(_ template: String, targetSize: Int) -> String {
        guard targetSize > template.count else { return String(template.prefix(targetSize)) }

        let repetitions = (targetSize / template.count) + 1
        let repeated = String(repeating: template + "\n", count: repetitions)
        return String(repeated.prefix(targetSize))
    }

    // MARK: - Memory Utilities

    private static func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }

    // MARK: - Comparison and Analysis

    public static func compareTokenizers<T1: TokenizerProtocol, T2: TokenizerProtocol>(
        _ tokenizer1: T1,
        _ tokenizer2: T2,
        config: BenchmarkConfig = .default
    ) -> TokenizerComparison {
        let results1 = benchmarkTokenizer(tokenizer1, config: config)
        let results2 = benchmarkTokenizer(tokenizer2, config: config)

        return TokenizerComparison(
            tokenizer1Name: tokenizer1.name,
            tokenizer2Name: tokenizer2.name,
            results1: results1,
            results2: results2
        )
    }

    public struct TokenizerComparison: Codable {
        public let tokenizer1Name: String
        public let tokenizer2Name: String
        public let results1: [TestCaseResult]
        public let results2: [TestCaseResult]

        public func performanceRatio(for size: TestCaseSize) -> Double {
            guard let result1 = results1.first(where: { $0.size == size }),
                  let result2 = results2.first(where: { $0.size == size }) else {
                return 1.0
            }

            return result1.averageTokensPerSecond / result2.averageTokensPerSecond
        }

        public var summary: String {
            var summary = "Tokenizer Comparison: \(tokenizer1Name) vs \(tokenizer2Name)\n"
            summary += String(repeating: "=", count: 60) + "\n"

            for size in TestCaseSize.allCases {
                let ratio = performanceRatio(for: size)
                let winner = ratio > 1.0 ? tokenizer1Name : tokenizer2Name
                let improvement = ratio > 1.0 ? ratio : 1.0 / ratio

                summary += "\(size.rawValue): \(winner) is \(String(format: "%.2f", improvement))x faster\n"
            }

            return summary
        }
    }

    // MARK: - Extended Types for Comprehensive Benchmarking

    public struct BenchmarkSuiteResult {
        public let timestamp: Date
        public let testCases: [TestCaseResult]
        public let environment: BenchmarkEnvironment

        public var summary: SuiteSummary {
            let totalTime = testCases.reduce(0.0) { $0 + $1.benchmarkResult.averageProcessingTime }
            let totalIterations = testCases.reduce(0) { $0 + $1.iterations }
            let avgTokensPerSec = testCases.map(\.benchmarkResult.averageTokensPerSecond).reduce(0, +) / Double(testCases.count)

            return SuiteSummary(
                totalExecutionTime: totalTime,
                totalIterations: totalIterations,
                averageTokensPerSecond: avgTokensPerSec,
                testCasesRun: testCases.count
            )
        }

        public init(timestamp: Date, testCases: [TestCaseResult], environment: BenchmarkEnvironment) {
            self.timestamp = timestamp
            self.testCases = testCases
            self.environment = environment
        }
    }

    public struct SuiteSummary {
        public let totalExecutionTime: Double
        public let totalIterations: Int
        public let averageTokensPerSecond: Double
        public let testCasesRun: Int
    }

    public struct TokenizerBenchmarkResult: Codable {
        public let averageTokensPerSecond: Double
        public let averageProcessingTime: Double
        public let averageMemoryUsage: UInt64
        public let statistics: BenchmarkStatistics
    }

    public struct BenchmarkStatistics: Codable {
        public let min: Double
        public let max: Double
        public let median: Double
        public let standardDeviation: Double
    }

    // MARK: - Enhanced Benchmark Methods

    public static func runComprehensiveSuite<T: TokenizerProtocol>(tokenizer: T) -> BenchmarkSuiteResult {
        let environment = BenchmarkEnvironment()
        var testCases: [TestCaseResult] = []

        let testConfigurations = [
            ("Small Basic Code", generateBasicFECode(size: 100), 100),
            ("Medium Unicode Heavy", generateUnicodeHeavyCode(size: 1000), 50),
            ("Large Keyword Heavy", generateKeywordHeavyCode(size: 5000), 20),
            ("Mixed Content", generateMixedContent(size: 2000), 30),
            ("Real World Example", generateRealWorldExample(), 40)
        ]

        for (name, source, iterations) in testConfigurations {
            let result = measureTokenization(source: source, tokenizer: tokenizer, iterations: iterations)
            let testCase = TestCaseResult(
                name: name,
                sourceSize: source.count,
                iterations: iterations,
                benchmarkResult: result
            )
            testCases.append(testCase)
        }

        return BenchmarkSuiteResult(
            timestamp: Date(),
            testCases: testCases,
            environment: environment
        )
    }

    public static func measureTokenization<T: TokenizerProtocol>(
        source: String,
        tokenizer: T,
        iterations: Int
    ) -> TokenizerBenchmarkResult {
        // Warmup
        for _ in 0..<3 {
            _ = try? tokenizer.tokenize(source)
        }

        var times: [Double] = []
        var memoryUsages: [UInt64] = []

        for _ in 0..<iterations {
            let memoryBefore = getMemoryUsage()
            let startTime = CFAbsoluteTimeGetCurrent()

            _ = try? tokenizer.tokenize(source)

            let endTime = CFAbsoluteTimeGetCurrent()
            let memoryAfter = getMemoryUsage()

            times.append(endTime - startTime)
            memoryUsages.append(UInt64(max(0, memoryAfter - memoryBefore)))
        }

        let avgTime = times.reduce(0, +) / Double(times.count)
        let avgMemory = memoryUsages.reduce(0, +) / UInt64(memoryUsages.count)
        let tokensPerSecond = Double(source.count) / avgTime // Approximate

        let sortedTimes = times.sorted()
        let median = sortedTimes[sortedTimes.count / 2]
        let variance = times.map { pow($0 - avgTime, 2) }.reduce(0, +) / Double(times.count)
        let stdDev = sqrt(variance)

        let statistics = BenchmarkStatistics(
            min: sortedTimes.first ?? 0,
            max: sortedTimes.last ?? 0,
            median: median,
            standardDeviation: stdDev
        )

        return TokenizerBenchmarkResult(
            averageTokensPerSecond: tokensPerSecond,
            averageProcessingTime: avgTime,
            averageMemoryUsage: avgMemory,
            statistics: statistics
        )
    }

    public static func compareTokenizers<T1: TokenizerProtocol, T2: TokenizerProtocol>(
        baseline: T1,
        candidate: T2,
        source: String
    ) -> TokenizerPerformanceComparison {
        let baselineResult = measureTokenization(source: source, tokenizer: baseline, iterations: 100)
        let candidateResult = measureTokenization(source: source, tokenizer: candidate, iterations: 100)

        return TokenizerPerformanceComparison(
            baseline: baselineResult,
            candidate: candidateResult
        )
    }

    public struct TokenizerPerformanceComparison {
        public let baseline: TokenizerBenchmarkResult
        public let candidate: TokenizerBenchmarkResult

        public var tokensPerSecondImprovement: Double {
            return candidate.averageTokensPerSecond / baseline.averageTokensPerSecond
        }

        public var speedupRatio: Double {
            return baseline.averageProcessingTime / candidate.averageProcessingTime
        }

        public var memoryEfficiencyRatio: Double {
            return Double(baseline.averageMemoryUsage) / Double(candidate.averageMemoryUsage)
        }
    }

    private static func generateRealWorldExample() -> String {
        return """
        // FE言語のサンプルプログラム
        変数 カウンタ: 整数型
        変数 メッセージ: 文字列型
        変数 結果: 論理型

        カウンタ ← 0
        メッセージ ← "処理開始"
        結果 ← true

        while カウンタ < 10 do
            if カウンタ % 2 = 0 then
                メッセージ ← メッセージ + "偶数"
            else
                メッセージ ← メッセージ + "奇数"
            endif
            カウンタ ← カウンタ + 1
        endwhile

        function 計算(引数1: 整数型, 引数2: 整数型): 整数型
            変数 和: 整数型
            和 ← 引数1 + 引数2
            if 和 > 100 then
                return 100
            else
                return 和
            endif
        endfunction

        procedure メイン()
            変数 x: 整数型
            変数 y: 整数型
            x ← 50
            y ← 75
            結果 ← 計算(x, y) > 100
        endprocedure
        """
    }
}
