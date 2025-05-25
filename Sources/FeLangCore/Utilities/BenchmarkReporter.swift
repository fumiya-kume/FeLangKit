import Foundation

// Forward declarations for types from BenchmarkFramework
public typealias BenchmarkSuiteResult = BenchmarkFramework.BenchmarkSuiteResult
public typealias BenchmarkEnvironment = BenchmarkFramework.BenchmarkEnvironment
public typealias TestCaseResult = BenchmarkFramework.TestCaseResult
public typealias SuiteSummary = BenchmarkFramework.SuiteSummary
public typealias BenchmarkStatistics = BenchmarkFramework.BenchmarkStatistics
public typealias TokenizerBenchmarkResult = BenchmarkFramework.TokenizerBenchmarkResult

/// Generates reports from benchmark results in various formats
/// Supports CI/CD integration with JSON, CSV, and Markdown outputs
public struct BenchmarkReporter {
    
    public init() {}
    
    /// Generates a comprehensive report in the specified format
    /// - Parameters:
    ///   - result: Benchmark suite result to report
    ///   - format: Output format for the report
    /// - Returns: Formatted report string
    public func generateReport(from result: BenchmarkSuiteResult, format: ReportFormat) -> String {
        switch format {
        case .json:
            return generateJSONReport(from: result)
        case .csv:
            return generateCSVReport(from: result)
        case .markdown:
            return generateMarkdownReport(from: result)
        case .console:
            return generateConsoleReport(from: result)
        }
    }
    
    /// Generates a comparison report between two benchmark results
    /// - Parameters:
    ///   - baseline: Baseline benchmark result
    ///   - current: Current benchmark result to compare
    ///   - format: Output format for the report
    /// - Returns: Formatted comparison report
    public func generateComparisonReport(
        baseline: BenchmarkSuiteResult,
        current: BenchmarkSuiteResult,
        format: ReportFormat
    ) -> String {
        switch format {
        case .json:
            return generateJSONComparisonReport(baseline: baseline, current: current)
        case .csv:
            return generateCSVComparisonReport(baseline: baseline, current: current)
        case .markdown:
            return generateMarkdownComparisonReport(baseline: baseline, current: current)
        case .console:
            return generateConsoleComparisonReport(baseline: baseline, current: current)
        }
    }
    
    /// Checks for performance regressions based on thresholds
    /// - Parameters:
    ///   - baseline: Baseline performance
    ///   - current: Current performance
    ///   - thresholds: Performance regression thresholds
    /// - Returns: Regression analysis result
    public func analyzeRegressions(
        baseline: BenchmarkSuiteResult,
        current: BenchmarkSuiteResult,
        thresholds: RegressionThresholds = .default
    ) -> RegressionAnalysis {
        var regressions: [RegressionIssue] = []
        var improvements: [PerformanceImprovement] = []
        
        for (baselineCase, currentCase) in zip(baseline.testCases, current.testCases) {
            guard baselineCase.name == currentCase.name else { continue }
            
            let speedRatio = currentCase.benchmarkResult.averageTokensPerSecond / 
                           baselineCase.benchmarkResult.averageTokensPerSecond
            
            let _ = currentCase.benchmarkResult.averageProcessingTime /
                          baselineCase.benchmarkResult.averageProcessingTime
            
            if speedRatio < (1.0 - thresholds.speedRegressionThreshold) {
                regressions.append(RegressionIssue(
                    testCase: currentCase.name,
                    type: .performance,
                    severity: speedRatio < (1.0 - thresholds.criticalRegressionThreshold) ? .critical : .warning,
                    baselineValue: baselineCase.benchmarkResult.averageTokensPerSecond,
                    currentValue: currentCase.benchmarkResult.averageTokensPerSecond,
                    changePercentage: (speedRatio - 1.0) * 100,
                    description: "Performance regression detected: \(String(format: "%.1f", (1.0 - speedRatio) * 100))% slower"
                ))
            } else if speedRatio > (1.0 + thresholds.improvementThreshold) {
                improvements.append(PerformanceImprovement(
                    testCase: currentCase.name,
                    type: .performance,
                    baselineValue: baselineCase.benchmarkResult.averageTokensPerSecond,
                    currentValue: currentCase.benchmarkResult.averageTokensPerSecond,
                    changePercentage: (speedRatio - 1.0) * 100,
                    description: "Performance improvement: \(String(format: "%.1f", (speedRatio - 1.0) * 100))% faster"
                ))
            }
            
            // Check memory usage
            let memoryRatio = Double(currentCase.benchmarkResult.averageMemoryUsage) /
                            Double(baselineCase.benchmarkResult.averageMemoryUsage)
            
            if memoryRatio > (1.0 + thresholds.memoryRegressionThreshold) {
                regressions.append(RegressionIssue(
                    testCase: currentCase.name,
                    type: .memory,
                    severity: memoryRatio > (1.0 + thresholds.criticalRegressionThreshold) ? .critical : .warning,
                    baselineValue: Double(baselineCase.benchmarkResult.averageMemoryUsage),
                    currentValue: Double(currentCase.benchmarkResult.averageMemoryUsage),
                    changePercentage: (memoryRatio - 1.0) * 100,
                    description: "Memory usage regression: \(String(format: "%.1f", (memoryRatio - 1.0) * 100))% more memory"
                ))
            }
        }
        
        return RegressionAnalysis(
            timestamp: Date(),
            baseline: baseline,
            current: current,
            regressions: regressions,
            improvements: improvements,
            overallStatus: regressions.isEmpty ? .passed : (regressions.contains { $0.severity == .critical } ? .failed : .warning)
        )
    }
}

// MARK: - Private Report Generation Methods

private extension BenchmarkReporter {
    
    func generateJSONReport(from result: BenchmarkSuiteResult) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let report = JSONReport(
            timestamp: result.timestamp,
            environment: result.environment,
            summary: JSONSummary(from: result.summary),
            testCases: result.testCases.map { JSONTestCase(from: $0) }
        )
        
        do {
            let data = try encoder.encode(report)
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return "Error generating JSON report: \(error)"
        }
    }
    
    func generateCSVReport(from result: BenchmarkSuiteResult) -> String {
        var csv = "Test Case,Source Size,Iterations,Avg Tokens/Sec,Avg Processing Time,Avg Memory,Min Time,Max Time,Std Dev\n"
        
        for testCase in result.testCases {
            let stats = testCase.benchmarkResult.statistics
            csv += "\"\(testCase.name)\","
            csv += "\(testCase.sourceSize),"
            csv += "\(testCase.iterations),"
            csv += "\(String(format: "%.2f", testCase.benchmarkResult.averageTokensPerSecond)),"
            csv += "\(String(format: "%.6f", testCase.benchmarkResult.averageProcessingTime)),"
            csv += "\(testCase.benchmarkResult.averageMemoryUsage),"
            csv += "\(String(format: "%.6f", stats.min)),"
            csv += "\(String(format: "%.6f", stats.max)),"
            csv += "\(String(format: "%.6f", stats.standardDeviation))\n"
        }
        
        return csv
    }
    
    func generateMarkdownReport(from result: BenchmarkSuiteResult) -> String {
        var markdown = "# Benchmark Report\n\n"
        
        // Environment information
        markdown += "## Environment\n\n"
        markdown += "- **Device**: \(result.environment.device)\n"
        markdown += "- **OS**: \(result.environment.os)\n"
        markdown += "- **Swift Version**: \(result.environment.swiftVersion)\n"
        markdown += "- **Optimization**: \(result.environment.optimizationLevel)\n"
        markdown += "- **Timestamp**: \(DateFormatter.iso8601.string(from: result.timestamp))\n\n"
        
        // Summary
        let summary = result.summary
        markdown += "## Summary\n\n"
        markdown += "- **Total Execution Time**: \(String(format: "%.3f", summary.totalExecutionTime))s\n"
        markdown += "- **Total Iterations**: \(summary.totalIterations)\n"
        markdown += "- **Average Tokens/Sec**: \(String(format: "%.2f", summary.averageTokensPerSecond))\n"
        markdown += "- **Test Cases Run**: \(summary.testCasesRun)\n\n"
        
        // Detailed results
        markdown += "## Detailed Results\n\n"
        markdown += "| Test Case | Source Size | Iterations | Avg Tokens/Sec | Avg Memory | Min Time | Max Time | Std Dev |\n"
        markdown += "|-----------|-------------|------------|----------------|------------|----------|----------|----------|\n"
        
        for testCase in result.testCases {
            let stats = testCase.benchmarkResult.statistics
            markdown += "| \(testCase.name) "
            markdown += "| \(testCase.sourceSize) "
            markdown += "| \(testCase.iterations) "
            markdown += "| \(String(format: "%.2f", testCase.benchmarkResult.averageTokensPerSecond)) "
            markdown += "| \(testCase.benchmarkResult.averageMemoryUsage) "
            markdown += "| \(String(format: "%.6f", stats.min))s "
            markdown += "| \(String(format: "%.6f", stats.max))s "
            markdown += "| \(String(format: "%.6f", stats.standardDeviation)) |\n"
        }
        
        return markdown
    }
    
    func generateConsoleReport(from result: BenchmarkSuiteResult) -> String {
        var output = "╔══════════════════════════════════════════════════════════════════╗\n"
        output += "║                           BENCHMARK REPORT                      ║\n"
        output += "╚══════════════════════════════════════════════════════════════════╝\n\n"
        
        // Environment
        output += "Environment:\n"
        output += "  Device: \(result.environment.device)\n"
        output += "  OS: \(result.environment.os)\n"
        output += "  Swift: \(result.environment.swiftVersion) (\(result.environment.optimizationLevel))\n"
        output += "  Time: \(DateFormatter.console.string(from: result.timestamp))\n\n"
        
        // Summary
        let summary = result.summary
        output += "Summary:\n"
        output += "  Total time: \(String(format: "%.3f", summary.totalExecutionTime))s\n"
        output += "  Iterations: \(summary.totalIterations)\n"
        output += "  Avg tokens/sec: \(String(format: "%.2f", summary.averageTokensPerSecond))\n"
        output += "  Test cases: \(summary.testCasesRun)\n\n"
        
        // Test cases
        output += "Test Cases:\n"
        for testCase in result.testCases {
            output += "  \(testCase.name):\n"
            output += "    Tokens/sec: \(String(format: "%.2f", testCase.benchmarkResult.averageTokensPerSecond))\n"
            output += "    Memory: \(testCase.benchmarkResult.averageMemoryUsage) bytes\n"
            output += "    Consistency: σ = \(String(format: "%.6f", testCase.benchmarkResult.statistics.standardDeviation))\n"
        }
        
        return output
    }
    
    func generateJSONComparisonReport(baseline: BenchmarkSuiteResult, current: BenchmarkSuiteResult) -> String {
        let analysis = analyzeRegressions(baseline: baseline, current: current)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let data = try encoder.encode(analysis)
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return "Error generating JSON comparison report: \(error)"
        }
    }
    
    func generateCSVComparisonReport(baseline: BenchmarkSuiteResult, current: BenchmarkSuiteResult) -> String {
        var csv = "Test Case,Baseline Tokens/Sec,Current Tokens/Sec,Change %,Baseline Memory,Current Memory,Memory Change %\n"
        
        for (baselineCase, currentCase) in zip(baseline.testCases, current.testCases) {
            guard baselineCase.name == currentCase.name else { continue }
            
            let speedChange = (currentCase.benchmarkResult.averageTokensPerSecond / baselineCase.benchmarkResult.averageTokensPerSecond - 1.0) * 100
            let memoryChange = (Double(currentCase.benchmarkResult.averageMemoryUsage) / Double(baselineCase.benchmarkResult.averageMemoryUsage) - 1.0) * 100
            
            csv += "\"\(currentCase.name)\","
            csv += "\(String(format: "%.2f", baselineCase.benchmarkResult.averageTokensPerSecond)),"
            csv += "\(String(format: "%.2f", currentCase.benchmarkResult.averageTokensPerSecond)),"
            csv += "\(String(format: "%.2f", speedChange)),"
            csv += "\(baselineCase.benchmarkResult.averageMemoryUsage),"
            csv += "\(currentCase.benchmarkResult.averageMemoryUsage),"
            csv += "\(String(format: "%.2f", memoryChange))\n"
        }
        
        return csv
    }
    
    func generateMarkdownComparisonReport(baseline: BenchmarkSuiteResult, current: BenchmarkSuiteResult) -> String {
        let analysis = analyzeRegressions(baseline: baseline, current: current)
        
        var markdown = "# Benchmark Comparison Report\n\n"
        
        // Status
        let statusEmoji = analysis.overallStatus == .passed ? "✅" : (analysis.overallStatus == .failed ? "❌" : "⚠️")
        markdown += "**Status**: \(statusEmoji) \(analysis.overallStatus.rawValue.capitalized)\n\n"
        
        // Summary
        markdown += "## Summary\n\n"
        if !analysis.regressions.isEmpty {
            markdown += "**⚠️ Regressions Found**: \(analysis.regressions.count)\n"
        }
        if !analysis.improvements.isEmpty {
            markdown += "**🚀 Improvements Found**: \(analysis.improvements.count)\n"
        }
        markdown += "\n"
        
        // Regressions
        if !analysis.regressions.isEmpty {
            markdown += "## Regressions\n\n"
            for regression in analysis.regressions {
                let severityEmoji = regression.severity == .critical ? "🔴" : "🟡"
                markdown += "- \(severityEmoji) **\(regression.testCase)** (\(regression.type.rawValue)): \(regression.description)\n"
            }
            markdown += "\n"
        }
        
        // Improvements
        if !analysis.improvements.isEmpty {
            markdown += "## Improvements\n\n"
            for improvement in analysis.improvements {
                markdown += "- 🟢 **\(improvement.testCase)** (\(improvement.type.rawValue)): \(improvement.description)\n"
            }
            markdown += "\n"
        }
        
        // Detailed comparison
        markdown += "## Detailed Comparison\n\n"
        markdown += "| Test Case | Baseline Tokens/Sec | Current Tokens/Sec | Change | Memory Change |\n"
        markdown += "|-----------|---------------------|-------------------|---------|---------------|\n"
        
        for (baselineCase, currentCase) in zip(baseline.testCases, current.testCases) {
            guard baselineCase.name == currentCase.name else { continue }
            
            let speedChange = (currentCase.benchmarkResult.averageTokensPerSecond / baselineCase.benchmarkResult.averageTokensPerSecond - 1.0) * 100
            let memoryChange = (Double(currentCase.benchmarkResult.averageMemoryUsage) / Double(baselineCase.benchmarkResult.averageMemoryUsage) - 1.0) * 100
            
            let speedEmoji = speedChange > 0 ? "🟢" : (speedChange < -5 ? "🔴" : "")
            let memoryEmoji = memoryChange > 10 ? "🔴" : (memoryChange < -5 ? "🟢" : "")
            
            markdown += "| \(currentCase.name) "
            markdown += "| \(String(format: "%.2f", baselineCase.benchmarkResult.averageTokensPerSecond)) "
            markdown += "| \(String(format: "%.2f", currentCase.benchmarkResult.averageTokensPerSecond)) "
            markdown += "| \(speedEmoji)\(String(format: "%+.1f", speedChange))% "
            markdown += "| \(memoryEmoji)\(String(format: "%+.1f", memoryChange))% |\n"
        }
        
        return markdown
    }
    
    func generateConsoleComparisonReport(baseline: BenchmarkSuiteResult, current: BenchmarkSuiteResult) -> String {
        let analysis = analyzeRegressions(baseline: baseline, current: current)
        
        var output = "╔══════════════════════════════════════════════════════════════════╗\n"
        output += "║                       COMPARISON REPORT                          ║\n"
        output += "╚══════════════════════════════════════════════════════════════════╝\n\n"
        
        // Status
        let statusSymbol = analysis.overallStatus == .passed ? "✓" : (analysis.overallStatus == .failed ? "✗" : "⚠")
        output += "Status: \(statusSymbol) \(analysis.overallStatus.rawValue.uppercased())\n\n"
        
        // Issues summary
        if !analysis.regressions.isEmpty {
            output += "Regressions: \(analysis.regressions.count)\n"
            for regression in analysis.regressions {
                let symbol = regression.severity == .critical ? "✗" : "⚠"
                output += "  \(symbol) \(regression.testCase): \(regression.description)\n"
            }
        }
        
        if !analysis.improvements.isEmpty {
            output += "\nImprovements: \(analysis.improvements.count)\n"
            for improvement in analysis.improvements {
                output += "  ✓ \(improvement.testCase): \(improvement.description)\n"
            }
        }
        
        return output
    }
}

// MARK: - Supporting Types

public enum ReportFormat {
    case json
    case csv
    case markdown
    case console
}

public struct RegressionThresholds: Sendable {
    public let speedRegressionThreshold: Double      // e.g., 0.05 for 5% slower
    public let memoryRegressionThreshold: Double     // e.g., 0.10 for 10% more memory
    public let criticalRegressionThreshold: Double   // e.g., 0.20 for 20% regression = critical
    public let improvementThreshold: Double          // e.g., 0.05 for 5% improvement
    
    public static let `default` = RegressionThresholds(
        speedRegressionThreshold: 0.05,
        memoryRegressionThreshold: 0.10,
        criticalRegressionThreshold: 0.20,
        improvementThreshold: 0.05
    )
    
    public init(speedRegressionThreshold: Double, memoryRegressionThreshold: Double, criticalRegressionThreshold: Double, improvementThreshold: Double) {
        self.speedRegressionThreshold = speedRegressionThreshold
        self.memoryRegressionThreshold = memoryRegressionThreshold
        self.criticalRegressionThreshold = criticalRegressionThreshold
        self.improvementThreshold = improvementThreshold
    }
}

public struct RegressionAnalysis: Codable {
    public let timestamp: Date
    public let baseline: BenchmarkSuiteResult
    public let current: BenchmarkSuiteResult
    public let regressions: [RegressionIssue]
    public let improvements: [PerformanceImprovement]
    public let overallStatus: AnalysisStatus
}

public struct RegressionIssue: Codable {
    public let testCase: String
    public let type: RegressionType
    public let severity: RegressionSeverity
    public let baselineValue: Double
    public let currentValue: Double
    public let changePercentage: Double
    public let description: String
}

public struct PerformanceImprovement: Codable {
    public let testCase: String
    public let type: RegressionType
    public let baselineValue: Double
    public let currentValue: Double
    public let changePercentage: Double
    public let description: String
}

public enum RegressionType: String, Codable {
    case performance
    case memory
}

public enum RegressionSeverity: String, Codable {
    case warning
    case critical
}

public enum AnalysisStatus: String, Codable {
    case passed
    case warning
    case failed
}

// MARK: - JSON Report Types

private struct JSONReport: Codable {
    let timestamp: Date
    let environment: BenchmarkEnvironment
    let summary: JSONSummary
    let testCases: [JSONTestCase]
}

private struct JSONSummary: Codable {
    let totalExecutionTime: Double
    let totalIterations: Int
    let averageTokensPerSecond: Double
    let testCasesRun: Int
    
    init(from summary: SuiteSummary) {
        self.totalExecutionTime = summary.totalExecutionTime
        self.totalIterations = summary.totalIterations
        self.averageTokensPerSecond = summary.averageTokensPerSecond
        self.testCasesRun = summary.testCasesRun
    }
}

private struct JSONTestCase: Codable {
    let name: String
    let sourceSize: Int
    let iterations: Int
    let averageTokensPerSecond: Double
    let averageProcessingTime: Double
    let averageMemoryUsage: UInt64
    let statistics: JSONStatistics
    
    init(from testCase: TestCaseResult) {
        self.name = testCase.name
        self.sourceSize = testCase.sourceSize
        self.iterations = testCase.iterations
        self.averageTokensPerSecond = testCase.benchmarkResult.averageTokensPerSecond
        self.averageProcessingTime = testCase.benchmarkResult.averageProcessingTime
        self.averageMemoryUsage = testCase.benchmarkResult.averageMemoryUsage
        self.statistics = JSONStatistics(from: testCase.benchmarkResult.statistics)
    }
}

private struct JSONStatistics: Codable {
    let min: Double
    let max: Double
    let median: Double
    let standardDeviation: Double
    
    init(from stats: BenchmarkStatistics) {
        self.min = stats.min
        self.max = stats.max
        self.median = stats.median
        self.standardDeviation = stats.standardDeviation
    }
}

// MARK: - Date Formatters

private extension DateFormatter {
    static let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    static let console: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
}

// MARK: - Codable Extensions

extension BenchmarkSuiteResult: Codable {
    enum CodingKeys: String, CodingKey {
        case timestamp, testCases, environment
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(testCases, forKey: .testCases)
        try container.encode(environment, forKey: .environment)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        testCases = try container.decode([TestCaseResult].self, forKey: .testCases)
        environment = try container.decode(BenchmarkEnvironment.self, forKey: .environment)
    }
}

// Codable conformance is handled in BenchmarkFramework.swift 