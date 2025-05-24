import Testing
@testable import FeLangCore
import Foundation

/// Utilities for concurrent testing patterns
/// Provides standardized helpers for thread safety validation
public enum ConcurrencyTestHelpers {

    /// Standard concurrency levels for different test scenarios
    public enum ConcurrencyLevel {
        case light  // 10 concurrent tasks
        case medium // 50 concurrent tasks  
        case high   // 100 concurrent tasks
        case stress // 1000 concurrent tasks

        var taskCount: Int {
            switch self {
            case .light: return 10
            case .medium: return 50
            case .high: return 100
            case .stress: return 1000
            }
        }
    }

    /// Result of a concurrent test execution
    public struct ConcurrentTestResult {
        public let success: Bool
        public let executionTime: TimeInterval
        public let tasksCompleted: Int
        public let errors: [Error]
        public let metadata: [String: Any]

        public init(success: Bool, executionTime: TimeInterval, tasksCompleted: Int, errors: [Error] = [], metadata: [String: Any] = [:]) {
            self.success = success
            self.executionTime = executionTime
            self.tasksCompleted = tasksCompleted
            self.errors = errors
            self.metadata = metadata
        }
    }

    /// Performs concurrent read-only access testing
    /// - Parameters:
    ///   - level: Concurrency level for the test
    ///   - operation: The operation to perform concurrently
    /// - Returns: Result of the concurrent test
    public static func performConcurrentReadTest<T: Sendable>(
        level: ConcurrencyLevel = .medium,
        operation: @escaping @Sendable () async throws -> T
    ) async -> ConcurrentTestResult {
        let startTime = Date()
        var completedTasks = 0
        let errorCollector = ErrorCollector()

        let allSuccess = await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<level.taskCount {
                group.addTask { @Sendable in
                    do {
                        _ = try await operation()
                        return true
                    } catch {
                        await errorCollector.addError(error)
                        return false
                    }
                }
            }

            var allSucceeded = true
            for await result in group {
                completedTasks += 1
                allSucceeded = allSucceeded && result
            }

            return allSucceeded
        }

        let executionTime = Date().timeIntervalSince(startTime)
        let collectedErrors = await errorCollector.getErrors()

        return ConcurrentTestResult(
            success: allSuccess,
            executionTime: executionTime,
            tasksCompleted: completedTasks,
            errors: collectedErrors,
            metadata: ["concurrencyLevel": level.taskCount]
        )
    }

    /// Performs concurrent validation testing with result collection
    /// - Parameters:
    ///   - level: Concurrency level for the test
    ///   - validator: The validation operation to perform concurrently
    /// - Returns: Result of the concurrent validation test
    public static func performConcurrentValidationTest<T: Sendable>(
        level: ConcurrencyLevel = .medium,
        validator: @escaping @Sendable () async throws -> T
    ) async -> ConcurrentTestResult {
        let startTime = Date()
        var completedTasks = 0
        var collectedErrors: [Error] = []
        var results: [T] = []

        await withTaskGroup(of: Result<T, Error>.self) { group in
            for _ in 0..<level.taskCount {
                group.addTask { @Sendable in
                    do {
                        let result = try await validator()
                        return .success(result)
                    } catch {
                        return .failure(error)
                    }
                }
            }

            for await result in group {
                completedTasks += 1
                switch result {
                case .success(let value):
                    results.append(value)
                case .failure(let error):
                    collectedErrors.append(error)
                }
            }
        }

        let executionTime = Date().timeIntervalSince(startTime)
        let success = collectedErrors.isEmpty

        return ConcurrentTestResult(
            success: success,
            executionTime: executionTime,
            tasksCompleted: completedTasks,
            errors: collectedErrors,
            metadata: [
                "concurrencyLevel": level.taskCount,
                "resultsCollected": results.count,
                "errorCount": collectedErrors.count
            ]
        )
    }

    /// Performs stress testing with repeated operations
    /// - Parameters:
    ///   - iterations: Number of stress test iterations
    ///   - concurrencyLevel: Level of concurrency per iteration
    ///   - operation: The operation to stress test
    /// - Returns: Aggregated stress test results
    public static func performStressTest<T: Sendable>(
        iterations: Int = 100,
        concurrencyLevel: ConcurrencyLevel = .medium,
        operation: @escaping @Sendable () async throws -> T
    ) async -> ConcurrentTestResult {
        let startTime = Date()
        var totalCompletedTasks = 0
        var allErrors: [Error] = []
        var allIterationsSuccess = true

        for iteration in 0..<iterations {
            let iterationResult = await performConcurrentReadTest(
                level: concurrencyLevel,
                operation: operation
            )

            totalCompletedTasks += iterationResult.tasksCompleted
            allErrors.append(contentsOf: iterationResult.errors)
            allIterationsSuccess = allIterationsSuccess && iterationResult.success
        }

        let totalExecutionTime = Date().timeIntervalSince(startTime)

        return ConcurrentTestResult(
            success: allIterationsSuccess,
            executionTime: totalExecutionTime,
            tasksCompleted: totalCompletedTasks,
            errors: allErrors,
            metadata: [
                "iterations": iterations,
                "concurrencyLevel": concurrencyLevel.taskCount,
                "totalOperations": iterations * concurrencyLevel.taskCount
            ]
        )
    }

    /// Validates that all results from concurrent operations are identical
    /// - Parameters:
    ///   - level: Concurrency level for the test
    ///   - operation: Operation that should produce identical results
    /// - Returns: Whether all concurrent results were identical
    public static func validateConcurrentConsistency<T: Sendable & Equatable>(
        level: ConcurrencyLevel = .medium,
        operation: @escaping @Sendable () async throws -> T
    ) async -> Bool {
        var results: [T] = []

        await withTaskGroup(of: T?.self) { group in
            for _ in 0..<level.taskCount {
                group.addTask { @Sendable in
                    do {
                        return try await operation()
                    } catch {
                        return nil
                    }
                }
            }

            for await result in group {
                if let result = result {
                    results.append(result)
                }
            }
        }

        // All results should be identical
        guard let firstResult = results.first else { return false }
        return results.allSatisfy { $0 == firstResult }
    }

    /// Measures performance impact of concurrent operations
    /// - Parameters:
    ///   - baseline: Single-threaded baseline operation
    ///   - concurrent: Concurrent operation to measure
    ///   - level: Concurrency level for measurement
    /// - Returns: Performance metrics comparing baseline to concurrent
    public static func measureConcurrentPerformance<T: Sendable>(
        baseline: @escaping @Sendable () async throws -> T,
        concurrent: @escaping @Sendable () async throws -> T,
        level: ConcurrencyLevel = .medium
    ) async -> PerformanceMetrics {
        // Measure baseline performance
        let baselineStart = Date()
        do {
            _ = try await baseline()
        } catch {
            // Handle error if needed
        }
        let baselineTime = Date().timeIntervalSince(baselineStart)

        // Measure concurrent performance
        let concurrentResult = await performConcurrentReadTest(level: level, operation: concurrent)

        return PerformanceMetrics(
            baselineTime: baselineTime,
            concurrentTime: concurrentResult.executionTime,
            tasksExecuted: concurrentResult.tasksCompleted,
            success: concurrentResult.success
        )
    }
}

/// Performance metrics for concurrent operations
public struct PerformanceMetrics {
    public let baselineTime: TimeInterval
    public let concurrentTime: TimeInterval
    public let tasksExecuted: Int
    public let success: Bool

    /// Performance overhead percentage (positive = slower, negative = faster)
    public var overheadPercentage: Double {
        guard baselineTime > 0 else { return 0 }
        return ((concurrentTime - baselineTime) / baselineTime) * 100
    }

    /// Throughput improvement factor
    public var throughputFactor: Double {
        guard concurrentTime > 0 else { return 0 }
        let concurrentThroughput = Double(tasksExecuted) / concurrentTime
        let baselineThroughput = 1.0 / baselineTime
        return concurrentThroughput / baselineThroughput
    }

    public init(baselineTime: TimeInterval, concurrentTime: TimeInterval, tasksExecuted: Int, success: Bool) {
        self.baselineTime = baselineTime
        self.concurrentTime = concurrentTime
        self.tasksExecuted = tasksExecuted
        self.success = success
    }
}

/// Actor for thread-safe test result collection
public actor ThreadSafeTestCollector {
    private var results: [Any] = []
    private var errors: [Error] = []
    private var completedCount = 0

    public init() {}

    public func addResult<T>(_ result: T) {
        results.append(result)
        completedCount += 1
    }

    public func addError(_ error: Error) {
        errors.append(error)
        completedCount += 1
    }

    public func getCompletedCount() -> Int {
        return completedCount
    }

    public func getErrors() -> [Error] {
        return errors
    }

    public func hasErrors() -> Bool {
        return !errors.isEmpty
    }

    public func getResultCount() -> Int {
        return results.count
    }
}

/// Actor for thread-safe error collection during concurrent testing
private actor ErrorCollector {
    private var errors: [Error] = []

    func addError(_ error: Error) {
        errors.append(error)
    }

    func getErrors() -> [Error] {
        return errors
    }

    func clearErrors() {
        errors.removeAll()
    }
}
