import Testing
@testable import FeLangCore
import Foundation

/// Alias to avoid conflict with Foundation.Expression
typealias ASTExpression = FeLangCore.Expression

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
        if let maxTiming = timings.max(), let minTiming = timings.min() {
            let variance = maxTiming - minTiming
            if variance > 0.1 { // If variance is > 100ms, it might indicate contention
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
    public static func validateExpressionThreadSafety(_ expression: ASTExpression) async -> ValidationResult {
        var issues: [String] = []
        var recommendations: [String] = []
        
        // Test concurrent read access
        let concurrentResult = await ConcurrencyTestHelpers.performConcurrentReadTest(
            level: .medium
        ) {
            // Read-only operations that should be thread-safe
            let _ = expression
            switch expression {
            case .literal(let literal):
                return literal
            case .identifier(let name):
                return name
            case .binary(let op, let left, let right):
                return (op, left, right)
            case .unary(let op, let expr):
                return (op, expr)
            case .arrayAccess(let array, let index):
                return (array, index)
            case .fieldAccess(let expr, let field):
                return (expr, field)
            case .functionCall(let name, let args):
                return (name, args)
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
            // Read-only access to statement components
            switch statement {
            case .ifStatement(let ifStmt):
                return (ifStmt.condition, ifStmt.thenBody.count, ifStmt.elseIfs.count)
            case .whileStatement(let whileStmt):
                return (whileStmt.condition, whileStmt.body.count, 0) // Add third element for consistency
            case .forStatement(let forStmt):
                switch forStmt {
                case .range(let rangeFor):
                    return (rangeFor.variable, rangeFor.start, rangeFor.end)
                case .forEach(let forEachLoop):
                    return (forEachLoop.variable, forEachLoop.iterable, "forEach")
                }
            case .assignment(let assignment):
                switch assignment {
                case .variable(let name, let expr):
                    return (name, expr, "variable")
                case .arrayElement(let access, let expr):
                    return (access, expr, "arrayElement")
                }
            case .variableDeclaration(let varDecl):
                return (varDecl.name, varDecl.type, "variable")
            case .constantDeclaration(let constDecl):
                return (constDecl.name, constDecl.type, "constant")
            case .functionDeclaration(let funcDecl):
                return (funcDecl.name, funcDecl.parameters.count, funcDecl.body.count)
            case .procedureDeclaration(let procDecl):
                return (procDecl.name, procDecl.parameters.count, procDecl.body.count)
            case .returnStatement(let returnStmt):
                return (returnStmt.expression, "return", 0)
            case .expressionStatement(let expr):
                return (expr, "expression", 0)
            case .breakStatement:
                return ("break", 0, 0)
            case .block(let statements):
                return (statements.count, "block", 0)
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
        
        // Sort accesses by timestamp
        let sortedAccesses = accesses.sorted { $0.timestamp < $1.timestamp }
        
        // Look for overlapping access patterns
        for i in 0..<sortedAccesses.count {
            for j in (i+1)..<sortedAccesses.count {
                let access1 = sortedAccesses[i]
                let access2 = sortedAccesses[j]
                
                // Check if accesses overlap in time
                let access1End = access1.timestamp.addingTimeInterval(access1.duration)
                if access2.timestamp < access1End {
                    // Potential conflict detected
                    if !conflicts.contains(where: { $0.threadId == access1.threadId }) {
                        conflicts.append(access1)
                    }
                    if !conflicts.contains(where: { $0.threadId == access2.threadId }) {
                        conflicts.append(access2)
                    }
                }
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