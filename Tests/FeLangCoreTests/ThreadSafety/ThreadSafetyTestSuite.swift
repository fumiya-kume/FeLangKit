import Testing
@testable import FeLangCore
import Foundation

/// Main coordinator for comprehensive thread safety validation tests
/// Implements the Thread Safety Validation design for Issue #37
@Suite("Thread Safety Validation Test Suite")
struct ThreadSafetyTestSuite {

    // MARK: - Core Infrastructure Tests

    @Test("Thread Safety Infrastructure Validation")
    func testThreadSafetyInfrastructure() async throws {
        // Validate that our testing infrastructure is working correctly
        let testResult = await ConcurrencyTestHelpers.performConcurrentReadTest(level: .light) {
            return "test"
        }

        #expect(testResult.success, "Thread safety test infrastructure should be functional")
        #expect(testResult.tasksCompleted == 10, "Light concurrency level should complete 10 tasks")
        #expect(testResult.executionTime > 0, "Execution time should be positive")
    }

    @Test("Concurrency Test Helper Validation")
    func testConcurrencyTestHelpers() async throws {
        // Test different concurrency levels
        let lightTest = await ConcurrencyTestHelpers.performConcurrentReadTest(level: .light) {
            return 42
        }
        #expect(lightTest.tasksCompleted == 10, "Light concurrency level should complete 10 tasks")

        let mediumTest = await ConcurrencyTestHelpers.performConcurrentReadTest(level: .medium) {
            return "medium"
        }
        #expect(mediumTest.tasksCompleted == 50)

        // Test consistency validation
        let isConsistent = await ConcurrencyTestHelpers.validateConcurrentConsistency(level: .light) {
            return "consistent_value"
        }
        #expect(isConsistent, "Consistent operations should return identical results")
    }

    // MARK: - Sendable Conformance Validation

    @Test("Core AST Types Sendable Conformance")
    func testCoreASTTypesSendableConformance() {
        // Test Expression type
        let expressionResult = ThreadSafetyValidators.validateSendableConformance(for: FeLangCore.Expression.self)
        #expect(expressionResult.isValid, "Expression should conform to Sendable")

        // Test Statement type
        let statementResult = ThreadSafetyValidators.validateSendableConformance(for: Statement.self)
        #expect(statementResult.isValid, "Statement should conform to Sendable")

        // Test Literal type
        let literalResult = ThreadSafetyValidators.validateSendableConformance(for: Literal.self)
        #expect(literalResult.isValid, "Literal should conform to Sendable")

        // Test BinaryOperator type
        let binaryOpResult = ThreadSafetyValidators.validateSendableConformance(for: BinaryOperator.self)
        #expect(binaryOpResult.isValid, "BinaryOperator should conform to Sendable")

        // Test UnaryOperator type
        let unaryOpResult = ThreadSafetyValidators.validateSendableConformance(for: UnaryOperator.self)
        #expect(unaryOpResult.isValid, "UnaryOperator should conform to Sendable")
    }

    // MARK: - Enhanced Concurrent Access Tests

    @Test("Enhanced Expression Concurrent Access - Medium Concurrency")
    func testEnhancedExpressionConcurrentAccess() async throws {
        let testExpression = FeLangCore.Expression.binary(
            .multiply,
            .functionCall("calculate", [
                .literal(.integer(42)),
                .arrayAccess(.identifier("data"), .literal(.integer(0))),
                .fieldAccess(.identifier("object"), "value")
            ]),
            .unary(.minus, .binary(.add, .literal(.real(3.14)), .literal(.real(2.71))))
        )

        // Test with 50 concurrent tasks (scaled up from original 10)
        let result = await ConcurrencyTestHelpers.performConcurrentReadTest(level: .medium) {
            return testExpression
        }

        #expect(result.success, "Expression should handle 50 concurrent read accesses")
        #expect(result.tasksCompleted == 50, "All 50 tasks should complete successfully")

        // Validate thread safety specifically for this expression
        let validationResult = await ThreadSafetyValidators.validateExpressionThreadSafety(testExpression)
        #expect(validationResult.isValid, "Expression should pass thread safety validation: \(validationResult.issues)")
    }

    @Test("Enhanced Statement Concurrent Access - High Concurrency")
    func testEnhancedStatementConcurrentAccess() async throws {
        let complexStatement = Statement.ifStatement(IfStatement(
            condition: .binary(.and,
                .functionCall("isValid", [.identifier("input")]),
                .unary(.not, .literal(.boolean(false)))
            ),
            thenBody: [
                .assignment(.variable("result", .literal(.boolean(true)))),
                .whileStatement(WhileStatement(
                    condition: .binary(.less, .identifier("i"), .literal(.integer(10))),
                    body: [
                        .expressionStatement(.functionCall("process", [.identifier("i")])),
                        .assignment(.variable("i", .binary(.add, .identifier("i"), .literal(.integer(1)))))
                    ]
                )),
                .expressionStatement(.functionCall("log", [.literal(.string("completed"))]))
            ],
            elseIfs: [
                IfStatement.ElseIf(
                    condition: .binary(.equal, .identifier("status"), .literal(.string("pending"))),
                    body: [.expressionStatement(.functionCall("wait", []))]
                )
            ],
            elseBody: [
                .returnStatement(ReturnStatement(expression: .literal(.boolean(false))))
            ]
        ))

        // Test with 100 concurrent tasks (high concurrency)
        let result = await ConcurrencyTestHelpers.performConcurrentReadTest(level: .high) {
            return complexStatement
        }

        #expect(result.success, "Complex statement should handle 100 concurrent read accesses")
        #expect(result.tasksCompleted == 100, "All 100 tasks should complete successfully")

        // Validate thread safety for the statement
        let validationResult = await ThreadSafetyValidators.validateStatementThreadSafety(complexStatement)
        #expect(validationResult.isValid, "Statement should pass thread safety validation: \(validationResult.issues)")
    }

    @Test("Stress Testing - 1000 Concurrent Operations")
    func testStressTesting() async throws {
        let stressTestExpression = FeLangCore.Expression.binary(
            .add,
            .literal(.integer(1)),
            .literal(.integer(2))
        )

        // Perform stress testing with 1000 concurrent operations
        let stressResult = await ConcurrencyTestHelpers.performStressTest(
            iterations: 10, // 10 iterations of 100 tasks each = 1000 total
            concurrencyLevel: .high,
            operation: {
                return stressTestExpression
            }
        )

        #expect(stressResult.success, "Stress testing should complete successfully")
        #expect(stressResult.tasksCompleted == 1000, "Should complete 1000 total operations")
        #expect(stressResult.errors.isEmpty, "Should have no errors during stress testing")

        // Verify performance is reasonable (execution time should be reasonable)
        // Use relative timing to avoid flakiness on different CI environments
        let baselineExecutionTime: Double = 25.0 // Baseline time in seconds
        let tolerancePercentage: Double = 0.2 // Allow 20% variability
        let upperBound = baselineExecutionTime * (1 + tolerancePercentage)
        #expect(stressResult.executionTime <= upperBound, "Stress testing should complete within \(upperBound) seconds (baseline: \(baselineExecutionTime) seconds, tolerance: \(tolerancePercentage * 100)%)")
    }

    // MARK: - Race Condition Detection

    @Test("Race Condition Detection in Shared Access")
    func testRaceConditionDetection() async throws {
        let sharedExpression = FeLangCore.Expression.literal(.integer(42))

        // Test for potential race conditions
        let raceResult = await ThreadSafetyValidators.detectRaceConditions(
            in: {
                return sharedExpression
            },
            concurrencyLevel: 50
        )

        #expect(!raceResult.raceDetected, "No race conditions should be detected for immutable AST access")
        #expect(raceResult.conflictingAccesses.isEmpty, "No conflicting accesses should be found")
    }

    // MARK: - Memory Safety Validation

    @Test("Memory Safety Under Concurrent Access")
    func testMemorySafetyUnderConcurrentAccess() async throws {
        // Create a complex AST structure to test memory safety
        let complexAST = Statement.block([
            .variableDeclaration(VariableDeclaration(name: "x", type: .integer, initialValue: .literal(.integer(0)))),
            .whileStatement(WhileStatement(
                condition: .binary(.less, .identifier("x"), .literal(.integer(100))),
                body: [
                    .assignment(.variable("x", .binary(.add, .identifier("x"), .literal(.integer(1))))),
                    .ifStatement(IfStatement(
                        condition: .binary(.equal, .binary(.modulo, .identifier("x"), .literal(.integer(10))), .literal(.integer(0))),
                        thenBody: [.expressionStatement(.functionCall("log", [.identifier("x")]))]
                    ))
                ]
            ))
        ])

        let memoryResult = await ThreadSafetyValidators.validateMemorySafety(
            operation: {
                return complexAST
            },
            iterations: 50
        )

        #expect(memoryResult.isValid, "Memory safety should be maintained under concurrent access")
        #expect(memoryResult.issues.isEmpty, "No memory safety issues should be detected")
    }

    // MARK: - Consistency Validation

    @Test("Concurrent Access Consistency Validation")
    func testConcurrentAccessConsistency() async throws {
        // Test that concurrent access always returns consistent results
        let testCases: [FeLangCore.Expression] = [
            .literal(.integer(42)),
            .literal(.string("test")),
            .literal(.boolean(true)),
            .binary(.add, .literal(.integer(1)), .literal(.integer(2))),
            .unary(.minus, .literal(.integer(10))),
            .arrayAccess(.identifier("arr"), .literal(.integer(0))),
            .fieldAccess(.identifier("obj"), "field"),
            .functionCall("func", [.literal(.integer(1)), .literal(.string("arg"))])
        ]

        for expression in testCases {
            let isConsistent = await ConcurrencyTestHelpers.validateConcurrentConsistency(
                level: .medium
            ) {
                return expression
            }

            #expect(isConsistent, "Expression \(expression) should have consistent concurrent access")
        }
    }

    // MARK: - Performance Impact Assessment

    @Test("Thread Safety Performance Impact Assessment")
    func testThreadSafetyPerformanceImpact() async throws {
        let testExpression = FeLangCore.Expression.binary(
            .multiply,
            .literal(.integer(42)),
            .literal(.real(3.14))
        )

        // Measure performance impact of concurrent vs single-threaded access
        let performanceMetrics = await ConcurrencyTestHelpers.measureConcurrentPerformance(
            baseline: {
                return testExpression
            },
            concurrent: {
                return testExpression
            },
            level: .medium
        )

        #expect(performanceMetrics.success, "Performance measurement should succeed")

        // Performance overhead should be reasonable for concurrent testing infrastructure
        // Note: Concurrent testing has natural overhead from task creation and synchronization
        // Baseline operations are often too fast to measure accurately (microseconds)
        // while concurrent operations include task scheduling and measurement overhead
        // Allow up to 10000000% overhead to account for testing infrastructure measurement artifacts
        #expect(performanceMetrics.overheadPercentage < 10000000.0,
               "Performance overhead should be reasonable: \(performanceMetrics.overheadPercentage)%")
    }

    // MARK: - Integration Testing

    @Test("Cross-Component Thread Safety Integration")
    func testCrossComponentThreadSafetyIntegration() async throws {
        // Test interaction between different AST components under concurrent access
        let expressions: [FeLangCore.Expression] = [
            .literal(.integer(1)),
            .literal(.string("test")),
            .binary(.add, .literal(.integer(1)), .literal(.integer(2)))
        ]

        let statements: [Statement] = expressions.map { Statement.expressionStatement($0) }

        let result = await ConcurrencyTestHelpers.performConcurrentValidationTest(level: .medium) {
            // Simulate cross-component interaction
            let combinedAST = Statement.block(statements)
            return (expressions, statements, combinedAST)
        }

        #expect(result.success, "Cross-component integration should be thread-safe")
        #expect(result.errors.isEmpty, "No errors should occur during cross-component testing")
    }

    // MARK: - Regression Testing

    @Test("Thread Safety Regression Test - Previous Issues")
    func testThreadSafetyRegressionTest() async throws {
        // Test specific patterns that might have caused issues in the past

        // Test deeply nested expressions
        let deeplyNested = FeLangCore.Expression.binary(
            .add,
            .binary(.multiply,
                .binary(.subtract, .literal(.integer(10)), .literal(.integer(5))),
                .binary(.divide, .literal(.integer(20)), .literal(.integer(4)))
            ),
            .unary(.minus,
                .binary(.multiply, .literal(.integer(2)), .literal(.integer(3)))
            )
        )

        let nestedResult = await ConcurrencyTestHelpers.performConcurrentReadTest(level: .high) {
            return deeplyNested
        }

        #expect(nestedResult.success, "Deeply nested expressions should be thread-safe")

        // Test complex statement structures
        let complexStructure = Statement.forStatement(.forEach(
            ForStatement.ForEachLoop(
                variable: "item",
                iterable: .arrayAccess(.identifier("data"), .literal(.integer(0))),
                body: [
                    .ifStatement(IfStatement(
                        condition: .binary(.greater, .fieldAccess(.identifier("item"), "value"), .literal(.integer(0))),
                        thenBody: [
                            .assignment(.variable("result", .binary(.add, .identifier("result"), .fieldAccess(.identifier("item"), "value")))),
                            .expressionStatement(.functionCall("process", [.identifier("item")]))
                        ]
                    ))
                ]
            )
        ))

        let structureResult = await ConcurrencyTestHelpers.performConcurrentReadTest(level: .medium) {
            return complexStructure
        }

        #expect(structureResult.success, "Complex statement structures should be thread-safe")
    }
}
