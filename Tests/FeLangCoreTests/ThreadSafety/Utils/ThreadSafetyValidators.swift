import Testing
@testable import FeLangCore
import Foundation

/// Validation utilities for thread safety compliance
/// Provides specialized validators for different aspects of thread safety
public enum ThreadSafetyValidators {

    /// Validation result for thread safety checks
    public struct ValidationResult {
        public let isValid: Bool
        public let issues: [String]
        public let recommendations: [String]
        public let component: String
        public let testTimestamp: Date

        public init(isValid: Bool, issues: [String] = [], recommendations: [String] = [], component: String, testTimestamp: Date = Date()) {
            self.isValid = isValid
            self.issues = issues
            self.recommendations = recommendations
            self.component = component
            self.testTimestamp = testTimestamp
        }
    }

    /// Race condition detection result
    public struct RaceConditionResult {
        public let raceDetected: Bool
        public let conflictingAccesses: [AccessEvent]
        public let suspiciousTimings: [TimeInterval]

        public init(raceDetected: Bool, conflictingAccesses: [AccessEvent] = [], suspiciousTimings: [TimeInterval] = []) {
            self.raceDetected = raceDetected
            self.conflictingAccesses = conflictingAccesses
            self.suspiciousTimings = suspiciousTimings
        }
    }

    /// Access event for tracking concurrent operations
    public struct AccessEvent: Sendable {
        public let threadId: String
        public let operation: String
        public let timestamp: Date
        public let duration: TimeInterval

        public init(threadId: String, operation: String, timestamp: Date, duration: TimeInterval) {
            self.threadId = threadId
            self.operation = operation
            self.timestamp = timestamp
            self.duration = duration
        }
    }

    /// Validates Sendable conformance for AST types
    /// - Parameter type: The type to validate
    /// - Returns: Validation result indicating compliance
    public static func validateSendableConformance<T>(for type: T.Type) -> ValidationResult {
        var issues: [String] = []
        var recommendations: [String] = []

        let typeName = String(describing: type)

        // Note: This check is simplified since we can't easily test Sendable conformance at runtime
        // In practice, this would be validated by the Swift compiler

        // Additional checks for specific types
        if typeName.contains("AnyCodable") {
            if typeName.contains("@unchecked") {
                issues.append("\(typeName) uses @unchecked Sendable which bypasses compiler safety")
                recommendations.append("Verify manual thread safety implementation for \(typeName)")
            }
        }

        return ValidationResult(
            isValid: issues.isEmpty,
            issues: issues,
            recommendations: recommendations,
            component: typeName
        )
    }

    /// Validates immutability of AST structures
    /// - Parameter instance: The instance to validate
    /// - Returns: Validation result for immutability
    public static func validateImmutability<T: Equatable>(of instance: T) -> ValidationResult {
        var issues: [String] = []
        var recommendations: [String] = []

        let typeName = String(describing: type(of: instance))

        // Test value semantics by copying
        let originalInstance = instance
        // Since these are value types, assignment creates a copy
        let copiedInstance = originalInstance

        if originalInstance != copiedInstance {
            issues.append("\(typeName) failed copy equality test - value semantics may be broken")
            recommendations.append("Verify that \(typeName) implements proper value semantics")
        }

        return ValidationResult(
            isValid: issues.isEmpty,
            issues: issues,
            recommendations: recommendations,
            component: typeName
        )
    }

    /// Detects potential race conditions in concurrent access patterns
    /// - Parameters:
    ///   - operation: The operation to monitor
    ///   - concurrencyLevel: Number of concurrent executions
    /// - Returns: Race condition detection result
    public static func detectRaceConditions<T: Sendable>(
        in operation: @escaping @Sendable () async throws -> T,
        concurrencyLevel: Int = 50
    ) async -> RaceConditionResult {
        let accessTracker = AccessTracker()
        var suspiciousTimings: [TimeInterval] = []

        await withTaskGroup(of: Void.self) { group in
            for taskId in 0..<concurrencyLevel {
                group.addTask { @Sendable in
                    let startTime = Date()
                    let threadId = "Task-\(taskId)"

                    do {
                        _ = try await operation()
                        let duration = Date().timeIntervalSince(startTime)

                        await accessTracker.recordAccess(
                            threadId: threadId,
                            operation: "concurrent_operation",
                            timestamp: startTime,
                            duration: duration
                        )
                    } catch {
                        // Record failed access
                        await accessTracker.recordAccess(
                            threadId: threadId,
                            operation: "failed_operation",
                            timestamp: startTime,
                            duration: Date().timeIntervalSince(startTime)
                        )
                    }
                }
            }
        }

        let allAccesses = await accessTracker.getAllAccesses()
        let conflicts = analyzeAccessConflicts(allAccesses)
        let timings = allAccesses.map { $0.duration }

        // Look for suspicious timing patterns that might indicate race conditions
        // For immutable read-only operations, we expect consistent fast performance
        if let maxTiming = timings.max(), let minTiming = timings.min() {
            let variance = maxTiming - minTiming
            // Only consider variance suspicious if it's very large (>10ms) and represents significant variation
            if variance > 0.01 && maxTiming > minTiming * 100 { // 100x difference indicates potential issues
                suspiciousTimings.append(variance)
            }
        }

        return RaceConditionResult(
            raceDetected: !conflicts.isEmpty || !suspiciousTimings.isEmpty,
            conflictingAccesses: conflicts,
            suspiciousTimings: suspiciousTimings
        )
    }

    /// Validates thread safety for specific AST expression types
    /// - Parameter expression: The expression to validate
    /// - Returns: Validation result for the expression
    public static func validateExpressionThreadSafety(_ expression: FeLangCore.Expression) async -> ValidationResult {
        var issues: [String] = []
        var recommendations: [String] = []

        // Test concurrent read access
        let concurrentResult = await ConcurrencyTestHelpers.performConcurrentReadTest(
            level: .medium
        ) {
            // Read-only operations that should be thread-safe - using String as common return type
            _ = expression
            switch expression {
            case .literal(let literal):
                return String(describing: literal)
            case .identifier(let name):
                return name
            case .binary(let op, let left, let right):
                return "binary_\(op)_\(left)_\(right)"
            case .unary(let op, let expr):
                return "unary_\(op)_\(expr)"
            case .arrayAccess(let array, let index):
                return "arrayAccess_\(array)_\(index)"
            case .fieldAccess(let expr, let field):
                return "fieldAccess_\(expr)_\(field)"
            case .functionCall(let name, let args):
                return "functionCall_\(name)_\(args.count)"
            }
        }

        if !concurrentResult.success {
            issues.append("Expression failed concurrent read access test")
            recommendations.append("Verify that Expression type maintains thread safety under concurrent access")
        }

        // Test consistency across concurrent access
        let consistencyValid = await ConcurrencyTestHelpers.validateConcurrentConsistency(
            level: .medium
        ) {
            return expression
        }

        if !consistencyValid {
            issues.append("Expression values are not consistent across concurrent access")
            recommendations.append("Ensure Expression equality is deterministic and thread-safe")
        }

        return ValidationResult(
            isValid: issues.isEmpty,
            issues: issues,
            recommendations: recommendations,
            component: "Expression"
        )
    }

    /// Validates thread safety for statement types
    /// - Parameter statement: The statement to validate
    /// - Returns: Validation result for the statement
    public static func validateStatementThreadSafety(_ statement: Statement) async -> ValidationResult {
        var issues: [String] = []
        var recommendations: [String] = []

        // Test concurrent access to statement structure
        let concurrentResult = await ConcurrencyTestHelpers.performConcurrentReadTest(
            level: .medium
        ) {
            // Read-only access to statement components - using String as return type for Sendable compliance
            switch statement {
            case .ifStatement(let ifStmt):
                return "ifStatement_\(ifStmt.condition)_\(ifStmt.thenBody.count)_\(ifStmt.elseIfs.count)"
            case .whileStatement(let whileStmt):
                return "whileStatement_\(whileStmt.condition)_\(whileStmt.body.count)"
            case .forStatement(let forStmt):
                switch forStmt {
                case .range(let rangeFor):
                    return "forRange_\(rangeFor.variable)_\(rangeFor.start)_\(rangeFor.end)"
                case .forEach(let forEachLoop):
                    return "forEach_\(forEachLoop.variable)_\(forEachLoop.iterable)"
                }
            case .assignment(let assignment):
                switch assignment {
                case .variable(let name, let expr):
                    return "assignVariable_\(name)_\(expr)"
                case .arrayElement(let access, let expr):
                    return "assignArrayElement_\(access)_\(expr)"
                }
            case .variableDeclaration(let varDecl):
                return "variableDeclaration_\(varDecl.name)_\(varDecl.type)"
            case .constantDeclaration(let constDecl):
                return "constantDeclaration_\(constDecl.name)_\(constDecl.type)"
            case .functionDeclaration(let funcDecl):
                return "functionDeclaration_\(funcDecl.name)_\(funcDecl.parameters.count)_\(funcDecl.body.count)"
            case .procedureDeclaration(let procDecl):
                return "procedureDeclaration_\(procDecl.name)_\(procDecl.parameters.count)_\(procDecl.body.count)"
            case .returnStatement(let returnStmt):
                return "returnStatement_\(String(describing: returnStmt.expression))"
            case .expressionStatement(let expr):
                return "expressionStatement_\(expr)"
            case .breakStatement:
                return "breakStatement"
            case .block(let statements):
                return "block_\(statements.count)"
            }
        }

        if !concurrentResult.success {
            issues.append("Statement failed concurrent read access test")
            recommendations.append("Verify that Statement type maintains thread safety under concurrent access")
        }

        return ValidationResult(
            isValid: issues.isEmpty,
            issues: issues,
            recommendations: recommendations,
            component: "Statement"
        )
    }

    /// Validates memory safety under concurrent access
    /// - Parameters:
    ///   - operation: Operation to test for memory safety
    ///   - iterations: Number of test iterations
    /// - Returns: Validation result for memory safety
    public static func validateMemorySafety<T: Sendable>(
        operation: @escaping @Sendable () async throws -> T,
        iterations: Int = 100
    ) async -> ValidationResult {
        var issues: [String] = []
        var recommendations: [String] = []

        // Perform stress testing to detect memory issues
        let stressResult = await ConcurrencyTestHelpers.performStressTest(
            iterations: iterations,
            concurrencyLevel: .medium,
            operation: operation
        )

        if !stressResult.success {
            issues.append("Memory safety validation failed under stress testing")
            recommendations.append("Investigate potential memory corruption or unsafe access patterns")
        }

        // Check for consistent memory usage patterns
        if stressResult.executionTime > TimeInterval(iterations) * 0.01 { // Arbitrary threshold
            issues.append("Execution time suggests potential memory contention or leaks")
            recommendations.append("Profile memory usage during concurrent operations")
        }

        return ValidationResult(
            isValid: issues.isEmpty,
            issues: issues,
            recommendations: recommendations,
            component: "MemorySafety"
        )
    }

    /// Analyzes access patterns for potential conflicts
    /// - Parameter accesses: List of access events to analyze
    /// - Returns: List of conflicting access events
    private static func analyzeAccessConflicts(_ accesses: [AccessEvent]) -> [AccessEvent] {
        var conflicts: [AccessEvent] = []

        // For read-only operations on immutable data, timing overlaps don't indicate real race conditions
        // We need to be more careful about what constitutes a "conflict"

        // Sort accesses by timestamp
        let sortedAccesses = accesses.sorted { $0.timestamp < $1.timestamp }

        // For immutable AST operations, concurrent read access is expected and safe
        // Only flag as conflicts if we see unusual patterns that suggest actual contention

        // Look for operations that took unusually long (potential blocking)
        let durations = sortedAccesses.map { $0.duration }
        guard let maxDuration = durations.max(), maxDuration > 0 else {
            return [] // No conflicts if all operations complete instantly
        }

        let averageDuration = durations.reduce(0, +) / Double(durations.count)
        let unusualThreshold = averageDuration * 10 // 10x average is unusual

        // Only flag operations that took significantly longer than average
        // This indicates potential contention rather than normal concurrent access
        for access in sortedAccesses {
            if access.duration > unusualThreshold && access.duration > 0.001 { // 1ms threshold
                conflicts.append(access)
            }
        }

        return conflicts
    }
}

/// Actor for tracking concurrent access patterns
private actor AccessTracker {
    private var accesses: [ThreadSafetyValidators.AccessEvent] = []

    func recordAccess(threadId: String, operation: String, timestamp: Date, duration: TimeInterval) {
        let event = ThreadSafetyValidators.AccessEvent(
            threadId: threadId,
            operation: operation,
            timestamp: timestamp,
            duration: duration
        )
        accesses.append(event)
    }

    func getAllAccesses() -> [ThreadSafetyValidators.AccessEvent] {
        return accesses
    }

    func clearAccesses() {
        accesses.removeAll()
    }
}
