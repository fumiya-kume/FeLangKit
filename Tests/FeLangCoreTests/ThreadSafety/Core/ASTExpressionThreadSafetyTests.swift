import Testing
@testable import FeLangCore
import Foundation

/// Alias to avoid conflict with Foundation.Expression
typealias ASTExpression = FeLangCore.Expression

/// Comprehensive thread safety tests for AST Expression types
/// Implements enhanced concurrent access testing as outlined in Issue #37
@Suite("AST Expression Thread Safety Tests")
struct ASTExpressionThreadSafetyTests {
    
    // MARK: - Literal Expression Thread Safety
    
    @Test("Literal Expressions Concurrent Access - High Concurrency")
    func testLiteralExpressionsConcurrentAccess() async throws {
        let literalExpressions: [ASTExpression] = [
            .literal(.integer(42)),
            .literal(.real(3.14159)),
            .literal(.string("Hello, Thread Safety!")),
            .literal(.character("T")),
            .literal(.boolean(true)),
            .literal(.boolean(false))
        ]
        
        for literalExpr in literalExpressions {
            // Test with 100 concurrent tasks
            let result = await ConcurrencyTestHelpers.performConcurrentReadTest(level: .high) {
                return literalExpr
            }
            
            #expect(result.success, "Literal expression \(literalExpr) should handle 100 concurrent accesses")
            #expect(result.tasksCompleted == 100, "All 100 tasks should complete for literal \(literalExpr)")
            
            // Validate consistency across concurrent access
            let isConsistent = await ConcurrencyTestHelpers.validateConcurrentConsistency(level: .high) {
                return literalExpr
            }
            #expect(isConsistent, "Literal expression \(literalExpr) should be consistent across concurrent access")
        }
    }
    
    @Test("Identifier Expressions Thread Safety")
    func testIdentifierExpressionsThreadSafety() async throws {
        let identifierExpressions: [ASTExpression] = [
            .identifier("variable"),
            .identifier("functionName"),
            .identifier("arrayName"),
            .identifier("objectName"),
            .identifier("x"),
            .identifier("y"),
            .identifier("result"),
            .identifier("count"),
            .identifier("index"),
            .identifier("value")
        ]
        
        for identifierExpr in identifierExpressions {
            let result = await ConcurrencyTestHelpers.performConcurrentReadTest(level: .high) {
                return identifierExpr
            }
            
            #expect(result.success, "Identifier expression \(identifierExpr) should be thread-safe")
            
            // Test specific thread safety validation
            let validationResult = await ThreadSafetyValidators.validateExpressionThreadSafety(identifierExpr)
            #expect(validationResult.isValid, "Identifier expression should pass validation: \(validationResult.issues)")
        }
    }
    
    // MARK: - Binary Expression Thread Safety
    
    @Test("Binary Expressions Comprehensive Thread Safety")
    func testBinaryExpressionsComprehensiveThreadSafety() async throws {
        let binaryOperators: [BinaryOperator] = [
            .add, .subtract, .multiply, .divide, .modulo,
            .equal, .notEqual, .less, .lessEqual, .greater, .greaterEqual,
            .and, .or
        ]
        
        for op in binaryOperators {
            let binaryExpr = ASTExpression.binary(
                op,
                .literal(.integer(10)),
                .literal(.integer(5))
            )
            
            // Test high concurrency (100 tasks)
            let result = await ConcurrencyTestHelpers.performConcurrentReadTest(level: .high) {
                return binaryExpr
            }
            
            #expect(result.success, "Binary expression with \(op) should handle 100 concurrent accesses")
            #expect(result.tasksCompleted == 100, "All tasks should complete for binary operator \(op)")
            
            // Test consistency
            let isConsistent = await ConcurrencyTestHelpers.validateConcurrentConsistency(level: .medium) {
                return binaryExpr
            }
            #expect(isConsistent, "Binary expression with \(op) should be consistent")
        }
    }
    
    @Test("Nested Binary Expressions Thread Safety")
    func testNestedBinaryExpressionsThreadSafety() async throws {
        let deeplyNestedExpr = ASTExpression.binary(
            .add,
            .binary(.multiply,
                .binary(.subtract, .literal(.integer(100)), .literal(.integer(25))),
                .binary(.divide, .literal(.integer(80)), .literal(.integer(4)))
            ),
            .binary(.modulo,
                .binary(.add, .literal(.integer(17)), .literal(.integer(7))),
                .literal(.integer(3))
            )
        )
        
        // Stress test with high concurrency
        let stressResult = await ConcurrencyTestHelpers.performStressTest(
            iterations: 20,
            concurrencyLevel: .high,
            operation: {
                return deeplyNestedExpr
            }
        )
        
        #expect(stressResult.success, "Deeply nested binary expressions should pass stress testing")
        #expect(stressResult.tasksCompleted == 2000, "Should complete 2000 total operations")
        
        // Validate thread safety
        let validationResult = await ThreadSafetyValidators.validateExpressionThreadSafety(deeplyNestedExpr)
        #expect(validationResult.isValid, "Nested binary expression should pass thread safety validation")
    }
    
    // MARK: - Unary Expression Thread Safety
    
    @Test("Unary Expressions Thread Safety")
    func testUnaryExpressionsThreadSafety() async throws {
        let unaryOperators: [UnaryOperator] = [.plus, .minus, .not]
        
        let testExpressions: [ASTExpression] = [
            .literal(.integer(42)),
            .literal(.real(-3.14)),
            .literal(.boolean(true)),
            .binary(.add, .literal(.integer(1)), .literal(.integer(2))),
            .identifier("value")
        ]
        
        for op in unaryOperators {
            for expr in testExpressions {
                let unaryExpr = ASTExpression.unary(op, expr)
                
                let result = await ConcurrencyTestHelpers.performConcurrentReadTest(level: .medium) {
                    return unaryExpr
                }
                
                #expect(result.success, "Unary expression \(op) with \(expr) should be thread-safe")
                
                // Test consistency
                let isConsistent = await ConcurrencyTestHelpers.validateConcurrentConsistency(level: .medium) {
                    return unaryExpr
                }
                #expect(isConsistent, "Unary expression should be consistent across concurrent access")
            }
        }
    }
    
    // MARK: - Function Call Expression Thread Safety
    
    @Test("Function Call Expressions Thread Safety")
    func testFunctionCallExpressionsThreadSafety() async throws {
        let functionCallExpressions: [ASTExpression] = [
            .functionCall("simpleFunction", []),
            .functionCall("add", [.literal(.integer(1)), .literal(.integer(2))]),
            .functionCall("process", [
                .identifier("data"),
                .literal(.string("parameter")),
                .literal(.boolean(true))
            ]),
            .functionCall("complexCalculation", [
                .binary(.add, .literal(.integer(10)), .literal(.integer(5))),
                .unary(.minus, .literal(.integer(3))),
                .arrayAccess(.identifier("array"), .literal(.integer(0))),
                .fieldAccess(.identifier("object"), "property")
            ]),
            .functionCall("nestedCall", [
                .functionCall("innerFunction", [.literal(.integer(42))]),
                .functionCall("anotherFunction", [.literal(.string("nested"))])
            ])
        ]
        
        for funcCall in functionCallExpressions {
            // Test high concurrency
            let result = await ConcurrencyTestHelpers.performConcurrentReadTest(level: .high) {
                return funcCall
            }
            
            #expect(result.success, "Function call \(funcCall) should handle 100 concurrent accesses")
            
            // Validate thread safety
            let validationResult = await ThreadSafetyValidators.validateExpressionThreadSafety(funcCall)
            #expect(validationResult.isValid, "Function call should pass thread safety validation")
            
            // Test consistency
            let isConsistent = await ConcurrencyTestHelpers.validateConcurrentConsistency(level: .medium) {
                return funcCall
            }
            #expect(isConsistent, "Function call should be consistent across concurrent access")
        }
    }
    
    // MARK: - Array Access Expression Thread Safety
    
    @Test("Array Access Expressions Thread Safety")
    func testArrayAccessExpressionsThreadSafety() async throws {
        let arrayAccessExpressions: [ASTExpression] = [
            .arrayAccess(.identifier("simpleArray"), .literal(.integer(0))),
            .arrayAccess(.identifier("data"), .identifier("index")),
            .arrayAccess(
                .functionCall("getArray", [.literal(.string("parameter"))]),
                .binary(.add, .identifier("baseIndex"), .literal(.integer(1)))
            ),
            .arrayAccess(
                .arrayAccess(.identifier("matrix"), .literal(.integer(0))),
                .literal(.integer(1))
            ),
            .arrayAccess(
                .fieldAccess(.identifier("object"), "arrayProperty"),
                .unary(.minus, .literal(.integer(-2)))
            )
        ]
        
        for arrayAccess in arrayAccessExpressions {
            // Test medium to high concurrency
            let result = await ConcurrencyTestHelpers.performConcurrentReadTest(level: .high) {
                return arrayAccess
            }
            
            #expect(result.success, "Array access \(arrayAccess) should be thread-safe")
            
            // Validate thread safety
            let validationResult = await ThreadSafetyValidators.validateExpressionThreadSafety(arrayAccess)
            #expect(validationResult.isValid, "Array access should pass thread safety validation")
        }
    }
    
    // MARK: - Field Access Expression Thread Safety
    
    @Test("Field Access Expressions Thread Safety")
    func testFieldAccessExpressionsThreadSafety() async throws {
        let fieldAccessExpressions: [ASTExpression] = [
            .fieldAccess(.identifier("object"), "property"),
            .fieldAccess(.identifier("person"), "name"),
            .fieldAccess(.identifier("point"), "x"),
            .fieldAccess(.identifier("config"), "value"),
            .fieldAccess(
                .functionCall("getObject", [.literal(.string("key"))]),
                "resultProperty"
            ),
            .fieldAccess(
                .arrayAccess(.identifier("objects"), .literal(.integer(0))),
                "field"
            ),
            .fieldAccess(
                .fieldAccess(.identifier("nested"), "inner"),
                "deepProperty"
            )
        ]
        
        for fieldAccess in fieldAccessExpressions {
            // Test high concurrency
            let result = await ConcurrencyTestHelpers.performConcurrentReadTest(level: .high) {
                return fieldAccess
            }
            
            #expect(result.success, "Field access \(fieldAccess) should handle 100 concurrent accesses")
            
            // Test consistency
            let isConsistent = await ConcurrencyTestHelpers.validateConcurrentConsistency(level: .medium) {
                return fieldAccess
            }
            #expect(isConsistent, "Field access should be consistent across concurrent access")
        }
    }
    
    // MARK: - Complex Combined Expression Thread Safety
    
    @Test("Complex Combined Expressions Thread Safety")
    func testComplexCombinedExpressionsThreadSafety() async throws {
        let complexExpressions: [ASTExpression] = [
            // Mathematical expression with multiple operators
            .binary(.add,
                .binary(.multiply,
                    .functionCall("sqrt", [.literal(.integer(64))]),
                    .unary(.minus, .literal(.real(2.5)))
                ),
                .binary(.divide,
                    .arrayAccess(.identifier("values"), .literal(.integer(3))),
                    .fieldAccess(.identifier("config"), "divisor")
                )
            ),
            
            // Logical expression with complex conditions
            .binary(.and,
                .binary(.or,
                    .binary(.greater, .identifier("x"), .literal(.integer(0))),
                    .binary(.less, .identifier("y"), .literal(.integer(100)))
                ),
                .unary(.not,
                    .binary(.equal,
                        .functionCall("checkStatus", [.identifier("item")]),
                        .literal(.string("invalid"))
                    )
                )
            ),
            
            // Nested function calls and array/field access
            .functionCall("processResult", [
                .arrayAccess(
                    .functionCall("getData", [
                        .fieldAccess(.identifier("context"), "source"),
                        .literal(.boolean(true))
                    ]),
                    .binary(.add, .identifier("index"), .literal(.integer(1)))
                ),
                .fieldAccess(
                    .functionCall("getMetadata", [.identifier("item")]),
                    "timestamp"
                )
            ])
        ]
        
        for complexExpr in complexExpressions {
            // Perform stress testing with high concurrency
            let stressResult = await ConcurrencyTestHelpers.performStressTest(
                iterations: 15,
                concurrencyLevel: .high,
                operation: {
                    return complexExpr
                }
            )
            
            #expect(stressResult.success, "Complex expression should pass stress testing")
            #expect(stressResult.errors.isEmpty, "No errors should occur during stress testing")
            
            // Validate thread safety
            let validationResult = await ThreadSafetyValidators.validateExpressionThreadSafety(complexExpr)
            #expect(validationResult.isValid, "Complex expression should pass thread safety validation")
            
            // Test memory safety
            let memoryResult = await ThreadSafetyValidators.validateMemorySafety(
                operation: {
                    return complexExpr
                },
                iterations: 30
            )
            #expect(memoryResult.isValid, "Complex expression should be memory-safe under concurrent access")
        }
    }
    
    // MARK: - Race Condition Detection
    
    @Test("Expression Race Condition Detection")
    func testExpressionRaceConditionDetection() async throws {
        let testExpressions: [ASTExpression] = [
            .binary(.add, .literal(.integer(1)), .literal(.integer(2))),
            .functionCall("test", [.literal(.string("param"))]),
            .arrayAccess(.identifier("arr"), .literal(.integer(0))),
            .fieldAccess(.identifier("obj"), "field")
        ]
        
        for expr in testExpressions {
            let raceResult = await ThreadSafetyValidators.detectRaceConditions(
                in: {
                    return expr
                },
                concurrencyLevel: 75
            )
            
            #expect(!raceResult.raceDetected, "No race conditions should be detected for expression \(expr)")
            #expect(raceResult.conflictingAccesses.isEmpty, "No conflicting accesses should be found")
        }
    }
    
    // MARK: - Performance Impact Assessment
    
    @Test("Expression Thread Safety Performance Impact")
    func testExpressionThreadSafetyPerformanceImpact() async throws {
        let performanceTestExpressions: [ASTExpression] = [
            .literal(.integer(42)),
            .binary(.add, .literal(.integer(1)), .literal(.integer(2))),
            .functionCall("func", [.literal(.string("test"))]),
            .arrayAccess(.identifier("array"), .literal(.integer(0)))
        ]
        
        for expr in performanceTestExpressions {
            let performanceMetrics = await ConcurrencyTestHelpers.measureConcurrentPerformance(
                baseline: {
                    return expr
                },
                concurrent: {
                    return expr
                },
                level: .medium
            )
            
            #expect(performanceMetrics.success, "Performance measurement should succeed for \(expr)")
            
            // Performance overhead should be reasonable for immutable value types
            #expect(performanceMetrics.overheadPercentage < 1000.0, 
                   "Performance overhead should be reasonable for \(expr): \(performanceMetrics.overheadPercentage)%")
        }
    }
    
    // MARK: - Immutability Validation
    
    @Test("Expression Immutability Under Concurrent Access")
    func testExpressionImmutabilityUnderConcurrentAccess() async throws {
        let testExpression = ASTExpression.binary(
            .multiply,
            .functionCall("calculate", [
                .literal(.integer(42)),
                .arrayAccess(.identifier("data"), .literal(.integer(0))),
                .fieldAccess(.identifier("config"), "multiplier")
            ]),
            .unary(.minus, .literal(.real(2.5)))
        )
        
        // Test immutability validation
        let immutabilityResult = ThreadSafetyValidators.validateImmutability(of: testExpression)
        #expect(immutabilityResult.isValid, "Expression should maintain immutability")
        
        // Test that concurrent access doesn't modify the expression
        let collector = ThreadSafeTestCollector()
        
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<50 {
                group.addTask { @Sendable in
                    let accessedExpression = testExpression
                    await collector.addResult(accessedExpression)
                }
            }
        }
        
        let resultCount = await collector.getResultCount()
        let hasErrors = await collector.hasErrors()
        
        #expect(resultCount == 50, "Should collect 50 results")
        #expect(!hasErrors, "Should have no errors during concurrent access")
    }
} 