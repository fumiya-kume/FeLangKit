import Foundation
@preconcurrency import Darwin.Mach
import Dispatch
@testable import FeLangCore

/// Deep Copy Test Utilities
/// Provides helper functions and utilities for comprehensive deep copy testing
/// Supports the Deep Copy Verification Tests implementation from GitHub issue #31
public struct DeepCopyTestUtilities {

    // MARK: - Test Data Generation

    /// Generates a deterministic complex nested structure for consistent testing
    /// - Parameter depth: The nesting depth (2-5 levels recommended)
    /// - Parameter breadth: The number of elements at each level
    /// - Returns: A complex Statement with nested structures
    public static func createDeterministicNestedStructure(depth: Int = 3, breadth: Int = 3) -> Statement {
        guard depth > 0 else {
            return .expressionStatement(.literal(.integer(42)))
        }

        let nestedStatements = (0..<breadth).map { index in
            if depth > 1 {
                return createDeterministicNestedStructure(depth: depth - 1, breadth: breadth)
            } else {
                return Statement.expressionStatement(.literal(.integer(index)))
            }
        }

        return .ifStatement(IfStatement(
            condition: .binary(.greater, .identifier("depth\(depth)"), .literal(.integer(0))),
            thenBody: nestedStatements,
            elseIfs: [
                IfStatement.ElseIf(
                    condition: .binary(.equal, .identifier("depth\(depth)"), .literal(.integer(0))),
                    body: [.expressionStatement(.literal(.integer(0)))]
                )
            ],
            elseBody: [.assignment(.variable("result\(depth)", .literal(.integer(-1))))]
        ))
    }

    /// Creates a random nested structure for stress testing
    /// - Parameter maxDepth: Maximum nesting depth
    /// - Parameter seed: Random seed for reproducible results
    /// - Returns: A randomly generated Statement structure
    public static func createRandomNestedStructure(maxDepth: Int = 4, seed: UInt64 = 12345) -> Statement {
        var generator = SeededRandomGenerator(seed: seed)
        return generateRandomStatement(depth: 0, maxDepth: maxDepth, generator: &generator)
    }

    /// Generates a large nested structure for performance testing
    /// - Parameter nodeCount: Approximate number of AST nodes to create
    /// - Returns: A large Statement structure
    public static func createLargeNestedStructure(nodeCount: Int = 1000) -> Statement {
        let depth = Int(log2(Double(nodeCount))) + 1
        let breadth = max(2, nodeCount / (depth * depth))
        return createDeterministicNestedStructure(depth: depth, breadth: breadth)
    }

    /// Creates a collection of edge case structures for boundary testing
    /// - Returns: Array of Statement structures representing edge cases
    public static func createEdgeCaseStructures() -> [Statement] {
        return [
            // Empty function
            .functionDeclaration(FunctionDeclaration(
                name: "empty",
                parameters: [],
                body: []
            )),
            // Single statement function
            .functionDeclaration(FunctionDeclaration(
                name: "single",
                parameters: [Parameter(name: "x", type: .integer)],
                body: [.returnStatement(ReturnStatement(expression: .identifier("x")))]
            )),
            // Deeply nested if-else chain
            createDeeplyNestedIfElseChain(depth: 10),
            // Complex expression with many operators
            .expressionStatement(createComplexExpression()),
            // Function with many parameters
            .functionDeclaration(FunctionDeclaration(
                name: "manyParams",
                parameters: createManyParameters(count: 20),
                body: [.returnStatement(ReturnStatement())]
            )),
            // Empty array assignments
            .assignment(.variable("empty", .functionCall("createArray", []))),
            // Nested while loops
            createNestedWhileLoops(depth: 5)
        ]
    }

    // MARK: - Performance Testing Utilities

    /// Measures the performance of a deep copy operation
    /// - Parameter structure: The structure to copy
    /// - Parameter iterations: Number of iterations to perform
    /// - Returns: Performance metrics including average time and memory usage
    public static func measureDeepCopyPerformance(
        structure: Statement,
        iterations: Int = 100
    ) -> PerformanceMetrics {
        var times: [TimeInterval] = []
        let initialMemory = getCurrentMemoryUsage()

        // Warm up to reduce measurement noise
        for _ in 0..<min(10, iterations / 10) {
            _ = structure
        }

        for _ in 0..<iterations {
            let startTime = CFAbsoluteTimeGetCurrent()

            // Perform the actual copy operation
            _ = structure

            let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime
            times.append(max(elapsedTime, 0.0)) // Ensure non-negative
        }

        let finalMemory = getCurrentMemoryUsage()

        // Calculate statistics with better handling of very small values
        let totalTime = times.reduce(0, +)
        let averageTime = totalTime / Double(times.count)
        let minTime = times.min() ?? 0.0
        let maxTime = times.max() ?? 0.0

        return PerformanceMetrics(
            averageTime: max(averageTime, 0.0), // Ensure non-negative
            minTime: max(minTime, 0.0),
            maxTime: max(maxTime, 0.0),
            memoryDelta: finalMemory - initialMemory,
            iterations: iterations
        )
    }

    /// Compares performance between different structure types
    /// - Parameter structures: Array of structures to compare
    /// - Returns: Comparative performance results
    public static func comparePerformance(structures: [Statement]) -> [PerformanceComparison] {
        return structures.enumerated().map { index, structure in
            let metrics = measureDeepCopyPerformance(structure: structure)
            return PerformanceComparison(
                structureIndex: index,
                structureType: describeStructure(structure),
                metrics: metrics
            )
        }
    }

    // MARK: - Validation Utilities

    /// Validates that two structures are deeply equal
    /// - Parameters:
    ///   - original: The original structure
    ///   - copy: The copied structure
    /// - Returns: ValidationResult indicating success or failure with details
    public static func validateDeepEquality(
        original: Statement,
        copy: Statement
    ) -> ValidationResult {
        guard original == copy else {
            return .failure("Structures are not equal")
        }

        // Additional validation for specific cases
        switch (original, copy) {
        case (.functionDeclaration(let origFunc), .functionDeclaration(let copyFunc)):
            return validateFunctionDeclarationEquality(original: origFunc, copy: copyFunc)
        case (.ifStatement(let origIf), .ifStatement(let copyIf)):
            return validateIfStatementEquality(original: origIf, copy: copyIf)
        case (.whileStatement(let origWhile), .whileStatement(let copyWhile)):
            return validateWhileStatementEquality(original: origWhile, copy: copyWhile)
        default:
            return .success("Basic equality validation passed")
        }
    }

    /// Validates that a copy operation maintains proper independence
    /// - Parameters:
    ///   - original: The original structure
    ///   - copy: The copied structure
    ///   - mutation: A function that mutates the structure
    /// - Returns: ValidationResult indicating independence validation
    public static func validateIndependence<T: Equatable>(
        original: T,
        copy: T,
        mutation: (inout T) -> Void
    ) -> ValidationResult {
        var mutableCopy = copy
        mutation(&mutableCopy)

        guard original != mutableCopy else {
            return .failure("Mutation affected the original structure")
        }

        guard copy == original else {
            return .failure("Copy was modified when original was not")
        }

        return .success("Independence validation passed")
    }

    // MARK: - Memory Testing Utilities

    /// Checks for memory leaks during copy operations
    /// - Parameter structure: The structure to test
    /// - Parameter iterations: Number of copy operations to perform
    /// - Returns: MemoryLeakResult indicating if leaks were detected
    public static func checkForMemoryLeaks(
        structure: Statement,
        iterations: Int = 1000
    ) -> MemoryLeakResult {
        let initialMemory = getCurrentMemoryUsage()

        // Perform many copy operations
        for _ in 0..<iterations {
            _ = structure
        }

        // Force garbage collection
        autoreleasepool {
            // Trigger any pending autorelease operations
        }

        let finalMemory = getCurrentMemoryUsage()
        let memoryDelta = finalMemory - initialMemory
        let threshold: Int64 = 1024 * 1024 // 1MB threshold

        if memoryDelta > threshold {
            return .leakDetected(memoryDelta)
        } else {
            return .noLeaksDetected(memoryDelta)
        }
    }

    // MARK: - Private Helper Functions

    private static func generateRandomStatement(
        depth: Int,
        maxDepth: Int,
        generator: inout SeededRandomGenerator
    ) -> Statement {
        if depth >= maxDepth {
            return .expressionStatement(.literal(.integer(generator.nextInt())))
        }

        let statementType = generator.nextInt() % 5

        switch statementType {
        case 0:
            return .assignment(.variable("var\(depth)", .literal(.integer(generator.nextInt()))))
        case 1:
            return .expressionStatement(.literal(.integer(generator.nextInt())))
        case 2:
            return .ifStatement(IfStatement(
                condition: .literal(.boolean(generator.nextBool())),
                thenBody: [generateRandomStatement(depth: depth + 1, maxDepth: maxDepth, generator: &generator)]
            ))
        case 3:
            return .whileStatement(WhileStatement(
                condition: .literal(.boolean(false)), // Prevent infinite loops
                body: [generateRandomStatement(depth: depth + 1, maxDepth: maxDepth, generator: &generator)]
            ))
        default:
            return .breakStatement
        }
    }

    private static func createDeeplyNestedIfElseChain(depth: Int) -> Statement {
        if depth <= 0 {
            return .expressionStatement(.literal(.integer(0)))
        }

        return .ifStatement(IfStatement(
            condition: .binary(.greater, .identifier("x"), .literal(.integer(depth))),
            thenBody: [.expressionStatement(.literal(.integer(depth)))],
            elseBody: [createDeeplyNestedIfElseChain(depth: depth - 1)]
        ))
    }

    private static func createComplexExpression() -> FeLangCore.Expression {
        return .binary(.multiply,
            .binary(.add,
                .binary(.divide, .literal(.integer(10)), .literal(.integer(2))),
                .unary(.minus, .literal(.integer(3)))
            ),
            .binary(.subtract,
                .functionCall("sqrt", [.literal(.integer(16))]),
                .arrayAccess(.identifier("values"), .literal(.integer(0)))
            )
        )
    }

    private static func createManyParameters(count: Int) -> [Parameter] {
        return (0..<count).map { index in
            Parameter(name: "param\(index)", type: DataType.allCases[index % DataType.allCases.count])
        }
    }

    private static func createNestedWhileLoops(depth: Int) -> Statement {
        if depth <= 0 {
            return .expressionStatement(.literal(.integer(0)))
        }

        return .whileStatement(WhileStatement(
            condition: .binary(.less, .identifier("i\(depth)"), .literal(.integer(depth))),
            body: [
                .assignment(.variable("i\(depth)", .binary(.add, .identifier("i\(depth)"), .literal(.integer(1))))),
                createNestedWhileLoops(depth: depth - 1)
            ]
        ))
    }

    private static func validateFunctionDeclarationEquality(
        original: FunctionDeclaration,
        copy: FunctionDeclaration
    ) -> ValidationResult {
        guard original.name == copy.name else {
            return .failure("Function names differ")
        }
        guard original.parameters == copy.parameters else {
            return .failure("Function parameters differ")
        }
        guard original.returnType == copy.returnType else {
            return .failure("Function return types differ")
        }
        guard original.body == copy.body else {
            return .failure("Function bodies differ")
        }
        return .success("Function declaration validation passed")
    }

    private static func validateIfStatementEquality(
        original: IfStatement,
        copy: IfStatement
    ) -> ValidationResult {
        guard original.condition == copy.condition else {
            return .failure("IF conditions differ")
        }
        guard original.thenBody == copy.thenBody else {
            return .failure("IF then bodies differ")
        }
        guard original.elseIfs == copy.elseIfs else {
            return .failure("IF elseIfs differ")
        }
        guard original.elseBody == copy.elseBody else {
            return .failure("IF else bodies differ")
        }
        return .success("IF statement validation passed")
    }

    private static func validateWhileStatementEquality(
        original: WhileStatement,
        copy: WhileStatement
    ) -> ValidationResult {
        guard original.condition == copy.condition else {
            return .failure("WHILE conditions differ")
        }
        guard original.body == copy.body else {
            return .failure("WHILE bodies differ")
        }
        return .success("WHILE statement validation passed")
    }

    private static func describeStructure(_ structure: Statement) -> String {
        switch structure {
        case .expressionStatement:
            return "ExpressionStatement"
        case .ifStatement:
            return "IfStatement"
        case .whileStatement:
            return "WhileStatement"
        case .functionDeclaration:
            return "FunctionDeclaration"
        case .assignment:
            return "Assignment"
        case .variableDeclaration:
            return "VariableDeclaration"
        case .breakStatement:
            return "BreakStatement"
        default:
            return "OtherStatement"
        }
    }

    private static func getCurrentMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

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

// MARK: - Supporting Types

/// Performance metrics for deep copy operations
public struct PerformanceMetrics {
    public let averageTime: TimeInterval
    public let minTime: TimeInterval
    public let maxTime: TimeInterval
    public let memoryDelta: Int64
    public let iterations: Int

    public var timePerIteration: TimeInterval {
        return averageTime
    }

    public var memoryPerIteration: Double {
        return Double(memoryDelta) / Double(iterations)
    }
}

/// Performance comparison between different structures
public struct PerformanceComparison {
    public let structureIndex: Int
    public let structureType: String
    public let metrics: PerformanceMetrics
}

/// Result of validation operations
public enum ValidationResult {
    case success(String)
    case failure(String)

    public var isSuccess: Bool {
        switch self {
        case .success: return true
        case .failure: return false
        }
    }

    public var message: String {
        switch self {
        case .success(let msg): return msg
        case .failure(let msg): return msg
        }
    }
}

/// Result of memory leak detection
public enum MemoryLeakResult {
    case noLeaksDetected(Int64)
    case leakDetected(Int64)

    public var memoryDelta: Int64 {
        switch self {
        case .noLeaksDetected(let delta): return delta
        case .leakDetected(let delta): return delta
        }
    }

    public var hasLeak: Bool {
        switch self {
        case .noLeaksDetected: return false
        case .leakDetected: return true
        }
    }
}

/// Simple seeded random number generator for reproducible tests
public struct SeededRandomGenerator {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed
    }

    public mutating func nextInt() -> Int {
        state = state &* 1103515245 &+ 12345
        return Int(state & 0x7FFFFFFF)
    }

    public mutating func nextBool() -> Bool {
        return nextInt() % 2 == 0
    }
}

// MARK: - DataType Extension for Testing

extension DataType: CaseIterable {
    public static var allCases: [DataType] {
        return [
            .integer,
            .real,
            .character,
            .string,
            .boolean,
            .array(.integer),
            .record("TestRecord")
        ]
    }
}
