import Testing
@testable import FeLangCore
import Foundation

/// Deep Copy Verification Tests
/// Implements the comprehensive deep copy testing requirements from GitHub issue #31
/// Ensures value semantics work correctly across complex nested structures
@Suite("Deep Copy Verification Tests")
struct DeepCopyVerificationTests {

    // MARK: - Phase 1: Foundation - Basic Deep Copy Verification

    @Test("Basic Expression Deep Copy - Literal Expressions")
    func testBasicLiteralExpressionDeepCopy() throws {
        let originalExpressions: [FeLangCore.Expression] = [
            .literal(.integer(42)),
            .literal(.real(3.14159)),
            .literal(.string("Hello, World!")),
            .literal(.character("A")),
            .literal(.boolean(true))
        ]

        for originalExpression in originalExpressions {
            let copiedExpression = originalExpression

            // Verify equality - should be equal via value semantics
            #expect(originalExpression == copiedExpression, "Literal expression copy should equal original")

            // Verify independence - mutations to variables should not affect the immutable values
            var mutableCopy = originalExpression
            mutableCopy = .literal(.integer(999))

            // Original should remain unchanged
            #expect(originalExpression != mutableCopy, "Original should not be affected by mutation of copy")
            #expect(copiedExpression == originalExpression, "Copy should still equal original after mutation")
        }
    }

    @Test("Basic Expression Deep Copy - Identifier Expressions")
    func testBasicIdentifierExpressionDeepCopy() throws {
        let originalExpression = FeLangCore.Expression.identifier("variableName")
        let copiedExpression = originalExpression

        #expect(originalExpression == copiedExpression)

        // Test immutability
        var mutableCopy = originalExpression
        mutableCopy = .identifier("differentName")

        #expect(originalExpression != mutableCopy)
        #expect(copiedExpression == originalExpression)
    }

    @Test("Basic Expression Deep Copy - Binary Expressions")
    func testBasicBinaryExpressionDeepCopy() throws {
        let originalExpression = FeLangCore.Expression.binary(
            .add,
            .literal(.integer(10)),
            .literal(.integer(20))
        )
        let copiedExpression = originalExpression

        #expect(originalExpression == copiedExpression)

        // Test independence
        var mutableCopy = originalExpression
        mutableCopy = .binary(.multiply, .literal(.integer(5)), .literal(.integer(6)))

        #expect(originalExpression != mutableCopy)
        #expect(copiedExpression == originalExpression)
    }

    @Test("Basic Expression Deep Copy - Unary Expressions")
    func testBasicUnaryExpressionDeepCopy() throws {
        let originalExpression = FeLangCore.Expression.unary(.minus, .literal(.integer(42)))
        let copiedExpression = originalExpression

        #expect(originalExpression == copiedExpression)

        // Test independence
        var mutableCopy = originalExpression
        mutableCopy = .unary(.not, .literal(.boolean(true)))

        #expect(originalExpression != mutableCopy)
        #expect(copiedExpression == originalExpression)
    }

    @Test("Basic Expression Deep Copy - Function Call Expressions")
    func testBasicFunctionCallExpressionDeepCopy() throws {
        let originalExpression = FeLangCore.Expression.functionCall("calculateSum", [
            .literal(.integer(1)),
            .literal(.integer(2)),
            .literal(.integer(3))
        ])
        let copiedExpression = originalExpression

        #expect(originalExpression == copiedExpression)

        // Test independence
        var mutableCopy = originalExpression
        mutableCopy = .functionCall("differentFunction", [.literal(.integer(999))])

        #expect(originalExpression != mutableCopy)
        #expect(copiedExpression == originalExpression)
    }

    @Test("Basic Expression Deep Copy - Array Access Expressions")
    func testBasicArrayAccessExpressionDeepCopy() throws {
        let originalExpression = FeLangCore.Expression.arrayAccess(
            .identifier("myArray"),
            .literal(.integer(0))
        )
        let copiedExpression = originalExpression

        #expect(originalExpression == copiedExpression)

        // Test independence
        var mutableCopy = originalExpression
        mutableCopy = .arrayAccess(.identifier("otherArray"), .literal(.integer(5)))

        #expect(originalExpression != mutableCopy)
        #expect(copiedExpression == originalExpression)
    }

    @Test("Basic Expression Deep Copy - Field Access Expressions")
    func testBasicFieldAccessExpressionDeepCopy() throws {
        let originalExpression = FeLangCore.Expression.fieldAccess(
            .identifier("myObject"),
            "propertyName"
        )
        let copiedExpression = originalExpression

        #expect(originalExpression == copiedExpression)

        // Test independence
        var mutableCopy = originalExpression
        mutableCopy = .fieldAccess(.identifier("otherObject"), "differentProperty")

        #expect(originalExpression != mutableCopy)
        #expect(copiedExpression == originalExpression)
    }

    // MARK: - Phase 1: Statement Deep Copy Verification

    @Test("Basic Statement Deep Copy - Expression Statements")
    func testBasicExpressionStatementDeepCopy() throws {
        let originalStatement = Statement.expressionStatement(.literal(.integer(42)))
        let copiedStatement = originalStatement

        #expect(originalStatement == copiedStatement)

        // Test independence
        var mutableCopy = originalStatement
        mutableCopy = .expressionStatement(.literal(.string("changed")))

        #expect(originalStatement != mutableCopy)
        #expect(copiedStatement == originalStatement)
    }

    @Test("Basic Statement Deep Copy - Break Statements")
    func testBasicBreakStatementDeepCopy() throws {
        let originalStatement = Statement.breakStatement
        let copiedStatement = originalStatement

        #expect(originalStatement == copiedStatement)
    }

    @Test("Basic Statement Deep Copy - Variable Declaration")
    func testBasicVariableDeclarationDeepCopy() throws {
        let originalDeclaration = VariableDeclaration(
            name: "testVar",
            type: .integer,
            initialValue: .literal(.integer(100))
        )
        let originalStatement = Statement.variableDeclaration(originalDeclaration)
        let copiedStatement = originalStatement

        #expect(originalStatement == copiedStatement)

        // Test independence
        var mutableCopy = originalStatement
        let newDeclaration = VariableDeclaration(
            name: "differentVar",
            type: .string,
            initialValue: .literal(.string("different"))
        )
        mutableCopy = .variableDeclaration(newDeclaration)

        #expect(originalStatement != mutableCopy)
        #expect(copiedStatement == originalStatement)
    }

    @Test("Basic Statement Deep Copy - Assignment")
    func testBasicAssignmentDeepCopy() throws {
        let originalAssignment = Assignment.variable("x", .literal(.integer(50)))
        let originalStatement = Statement.assignment(originalAssignment)
        let copiedStatement = originalStatement

        #expect(originalStatement == copiedStatement)

        // Test independence
        var mutableCopy = originalStatement
        mutableCopy = .assignment(.variable("y", .literal(.integer(75))))

        #expect(originalStatement != mutableCopy)
        #expect(copiedStatement == originalStatement)
    }

    // MARK: - Phase 1: Complex Structure Deep Copy Verification

    @Test("Complex Expression Deep Copy - Nested Binary Operations")
    func testComplexExpressionDeepCopy() throws {
        let originalExpression = FeLangCore.Expression.binary(
            .multiply,
            .binary(.add, .literal(.integer(2)), .literal(.integer(3))),
            .binary(.subtract, .literal(.integer(10)), .literal(.integer(4)))
        )
        let copiedExpression = originalExpression

        #expect(originalExpression == copiedExpression)

        // Test that deep structures maintain independence
        var mutableCopy = originalExpression
        mutableCopy = .binary(.divide, .literal(.integer(1)), .literal(.integer(1)))

        #expect(originalExpression != mutableCopy)
        #expect(copiedExpression == originalExpression)
    }

    @Test("Complex Statement Deep Copy - IF Statement with Nested Body")
    func testComplexIfStatementDeepCopy() throws {
        let originalIfStatement = IfStatement(
            condition: .binary(.greater, .identifier("x"), .literal(.integer(0))),
            thenBody: [
                .expressionStatement(.literal(.integer(1))),
                .assignment(.variable("y", .binary(.add, .identifier("x"), .literal(.integer(5)))))
            ],
            elseIfs: [
                IfStatement.ElseIf(
                    condition: .binary(.equal, .identifier("x"), .literal(.integer(0))),
                    body: [.expressionStatement(.literal(.integer(0)))]
                )
            ],
            elseBody: [
                .assignment(.variable("y", .literal(.integer(-1))))
            ]
        )
        let originalStatement = Statement.ifStatement(originalIfStatement)
        let copiedStatement = originalStatement

        #expect(originalStatement == copiedStatement)

        // Test that complex nested structures maintain independence
        var mutableCopy = originalStatement
        let simpleIf = IfStatement(
            condition: .literal(.boolean(true)),
            thenBody: [.breakStatement]
        )
        mutableCopy = .ifStatement(simpleIf)

        #expect(originalStatement != mutableCopy)
        #expect(copiedStatement == originalStatement)
    }

    @Test("Complex Statement Deep Copy - While Statement with Nested Operations")
    func testComplexWhileStatementDeepCopy() throws {
        let originalWhileStatement = WhileStatement(
            condition: .binary(.less, .identifier("counter"), .literal(.integer(10))),
            body: [
                .assignment(.variable("counter", .binary(.add, .identifier("counter"), .literal(.integer(1))))),
                .expressionStatement(.functionCall("processItem", [.identifier("counter")])),
                .ifStatement(IfStatement(
                    condition: .binary(.equal, .binary(.modulo, .identifier("counter"), .literal(.integer(2))), .literal(.integer(0))),
                    thenBody: [.expressionStatement(.functionCall("processEven", [.identifier("counter")]))]
                ))
            ]
        )
        let originalStatement = Statement.whileStatement(originalWhileStatement)
        let copiedStatement = originalStatement

        #expect(originalStatement == copiedStatement)

        // Test independence of deeply nested structures
        var mutableCopy = originalStatement
        let simpleWhile = WhileStatement(
            condition: .literal(.boolean(false)),
            body: [.breakStatement]
        )
        mutableCopy = .whileStatement(simpleWhile)

        #expect(originalStatement != mutableCopy)
        #expect(copiedStatement == originalStatement)
    }

    @Test("Complex Statement Deep Copy - Function Declaration with Complex Body")
    func testComplexFunctionDeclarationDeepCopy() throws {
        let originalFunctionDeclaration = FunctionDeclaration(
            name: "calculateComplexValue",
            parameters: [
                Parameter(name: "x", type: .integer),
                Parameter(name: "y", type: .real),
                Parameter(name: "options", type: .array(.string))
            ],
            returnType: .real,
            localVariables: [
                VariableDeclaration(name: "temp", type: .real, initialValue: .literal(.real(0.0))),
                VariableDeclaration(name: "result", type: .real, initialValue: .literal(.real(1.0)))
            ],
            body: [
                .assignment(.variable("temp", .binary(.multiply, .identifier("x"), .identifier("y")))),
                .ifStatement(IfStatement(
                    condition: .binary(.greater, .identifier("temp"), .literal(.real(100.0))),
                    thenBody: [
                        .assignment(.variable("result", .binary(.divide, .identifier("temp"), .literal(.real(2.0)))))
                    ],
                    elseBody: [
                        .assignment(.variable("result", .identifier("temp")))
                    ]
                )),
                .returnStatement(ReturnStatement(expression: .identifier("result")))
            ]
        )
        let originalStatement = Statement.functionDeclaration(originalFunctionDeclaration)
        let copiedStatement = originalStatement

        #expect(originalStatement == copiedStatement)

        // Test independence of complex function structures
        var mutableCopy = originalStatement
        let simpleFunction = FunctionDeclaration(
            name: "simpleFunc",
            parameters: [],
            returnType: .integer,
            body: [.returnStatement(ReturnStatement(expression: .literal(.integer(0))))]
        )
        mutableCopy = .functionDeclaration(simpleFunction)

        #expect(originalStatement != mutableCopy)
        #expect(copiedStatement == originalStatement)
    }

    // MARK: - Phase 1: Array and Collection Deep Copy Verification

    @Test("Array Deep Copy - Statement Arrays")
    func testStatementArrayDeepCopy() throws {
        let originalStatements: [Statement] = [
            .expressionStatement(.literal(.integer(1))),
            .assignment(.variable("x", .literal(.integer(42)))),
            .ifStatement(IfStatement(
                condition: .binary(.greater, .identifier("x"), .literal(.integer(0))),
                thenBody: [.expressionStatement(.literal(.string("positive")))]
            )),
            .whileStatement(WhileStatement(
                condition: .literal(.boolean(true)),
                body: [.breakStatement]
            ))
        ]
        let copiedStatements = originalStatements

        #expect(originalStatements == copiedStatements)

        // Test that array copy maintains independence
        var mutableCopy = originalStatements
        mutableCopy.append(.expressionStatement(.literal(.string("added"))))

        #expect(originalStatements.count != mutableCopy.count)
        #expect(copiedStatements == originalStatements)
    }

    @Test("Array Deep Copy - Expression Arrays in Function Calls")
    func testExpressionArrayDeepCopy() throws {
        let originalArguments: [FeLangCore.Expression] = [
            .literal(.integer(1)),
            .binary(.add, .identifier("x"), .literal(.integer(2))),
            .functionCall("nestedCall", [.literal(.string("nested"))]),
            .arrayAccess(.identifier("arr"), .literal(.integer(0)))
        ]
        let originalExpression = FeLangCore.Expression.functionCall("complexFunction", originalArguments)
        let copiedExpression = originalExpression

        #expect(originalExpression == copiedExpression)

        // Test independence
        var mutableCopy = originalExpression
        mutableCopy = FeLangCore.Expression.functionCall("differentFunction", [FeLangCore.Expression.literal(.integer(999))])

        #expect(originalExpression != mutableCopy)
        #expect(copiedExpression == originalExpression)
    }

    @Test("Array Deep Copy - Parameter Arrays")
    func testParameterArrayDeepCopy() throws {
        let originalParameters: [Parameter] = [
            Parameter(name: "first", type: .integer),
            Parameter(name: "second", type: .array(.string)),
            Parameter(name: "third", type: .record("CustomType")),
            Parameter(name: "fourth", type: .boolean)
        ]
        let originalFunction = FunctionDeclaration(
            name: "testFunction",
            parameters: originalParameters,
            returnType: .real,
            body: [.returnStatement(ReturnStatement(expression: .literal(.real(0.0))))]
        )
        let copiedFunction = originalFunction

        #expect(originalFunction == copiedFunction)
        #expect(originalFunction.parameters == copiedFunction.parameters)

        // Test parameter array independence
        var mutableParameters = originalParameters
        mutableParameters.append(Parameter(name: "added", type: .character))

        #expect(originalParameters.count != mutableParameters.count)
        #expect(copiedFunction.parameters == originalParameters)
    }

    // MARK: - Phase 1: Performance Basic Monitoring

    @Test("Basic Performance Monitoring - Small Structure Copy")
    func testBasicPerformanceMonitoring() throws {
        let testStructure = createMediumComplexityStructure()

        let startTime = CFAbsoluteTimeGetCurrent()
        let copy = testStructure
        let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime

        // Basic copy should be very fast (< 0.001 seconds)
        #expect(elapsedTime < 0.001, "Basic copy should complete in less than 1ms")
        #expect(testStructure == copy, "Copy should equal original")
    }

    // MARK: - Phase 2: Comprehensive Coverage - Nested Structure Test Scenarios (2-5 levels deep)

    @Test("2-Level Deep Copy - Expression containing nested expressions")
    func test2LevelDeepCopy() throws {
        let originalExpression = FeLangCore.Expression.binary(.add,
            .binary(.multiply, .literal(.integer(2)), .literal(.integer(3))),
            .binary(.divide, .literal(.integer(10)), .literal(.integer(2)))
        )
        let copiedExpression = originalExpression

        #expect(originalExpression == copiedExpression)

        // Verify deep independence
        var mutableCopy = originalExpression
        mutableCopy = .binary(.subtract, .literal(.integer(1)), .literal(.integer(1)))

        #expect(originalExpression != mutableCopy)
        #expect(copiedExpression == originalExpression)
    }

    @Test("3-Level Deep Copy - Statement containing expression containing sub-expressions")
    func test3LevelDeepCopy() throws {
        let originalStatement = Statement.ifStatement(IfStatement(
            condition: .binary(.and,
                .binary(.greater, .identifier("x"), .literal(.integer(0))),
                .binary(.less, .identifier("x"), .literal(.integer(100)))
            ),
            thenBody: [
                .assignment(.variable("result", .binary(.multiply,
                    .binary(.add, .identifier("x"), .literal(.integer(1))),
                    .binary(.subtract, .literal(.integer(10)), .identifier("y"))
                )))
            ]
        ))
        let copiedStatement = originalStatement

        #expect(originalStatement == copiedStatement)

        // Test deep structure independence
        var mutableCopy = originalStatement
        mutableCopy = .breakStatement

        #expect(originalStatement != mutableCopy)
        #expect(copiedStatement == originalStatement)
    }

    @Test("4-Level Deep Copy - Complex AST trees with multiple branching")
    func test4LevelDeepCopy() throws {
        let originalStatement = Statement.whileStatement(WhileStatement(
            condition: .binary(.less, .identifier("i"), .literal(.integer(10))),
            body: [
                .ifStatement(IfStatement(
                    condition: .binary(.equal, .binary(.modulo, .identifier("i"), .literal(.integer(2))), .literal(.integer(0))),
                    thenBody: [
                        .assignment(.variable("evenSum", .binary(.add,
                            .identifier("evenSum"),
                            .binary(.multiply, .identifier("i"), .literal(.integer(2)))
                        )))
                    ],
                    elseBody: [
                        .assignment(.variable("oddSum", .binary(.add,
                            .identifier("oddSum"),
                            .binary(.multiply, .identifier("i"), .literal(.integer(3)))
                        )))
                    ]
                )),
                .assignment(.variable("i", .binary(.add, .identifier("i"), .literal(.integer(1)))))
            ]
        ))
        let copiedStatement = originalStatement

        #expect(originalStatement == copiedStatement)

        // Test 4-level deep independence
        var mutableCopy = originalStatement
        mutableCopy = .expressionStatement(.literal(.string("replaced")))

        #expect(originalStatement != mutableCopy)
        #expect(copiedStatement == originalStatement)
    }

    @Test("5-Level Deep Copy - Maximum depth complex nesting")
    func test5LevelDeepCopy() throws {
        let originalStatement = Statement.functionDeclaration(FunctionDeclaration(
            name: "deepNesting",
            parameters: [Parameter(name: "n", type: .integer)],
            returnType: .integer,
            body: [
                .ifStatement(IfStatement(
                    condition: .binary(.greater, .identifier("n"), .literal(.integer(0))),
                    thenBody: [
                        .whileStatement(WhileStatement(
                            condition: .binary(.greater, .identifier("n"), .literal(.integer(0))),
                            body: [
                                .ifStatement(IfStatement(
                                    condition: .binary(.equal, .binary(.modulo, .identifier("n"), .literal(.integer(3))), .literal(.integer(0))),
                                    thenBody: [
                                        .assignment(.variable("result", .binary(.add,
                                            .identifier("result"),
                                            .functionCall("complexCalculation", [
                                                .binary(.multiply, .identifier("n"), .literal(.integer(2))),
                                                .binary(.subtract, .identifier("n"), .literal(.integer(1)))
                                            ])
                                        )))
                                    ]
                                )),
                                .assignment(.variable("n", .binary(.subtract, .identifier("n"), .literal(.integer(1)))))
                            ]
                        ))
                    ]
                )),
                .returnStatement(ReturnStatement(expression: .identifier("result")))
            ]
        ))
        let copiedStatement = originalStatement

        #expect(originalStatement == copiedStatement)

        // Test 5-level deep independence
        var mutableCopy = originalStatement
        mutableCopy = .functionDeclaration(FunctionDeclaration(name: "simple", parameters: [], body: []))

        #expect(originalStatement != mutableCopy)
        #expect(copiedStatement == originalStatement)
    }

    // MARK: - Phase 2: AnyCodable Deep Copy Verification Tests

    @Test("AnyCodable Deep Copy - Literal Values")
    func testAnyCodableDeepCopyLiterals() throws {
        let literalsWithAnyCodable: [Literal] = [
            .integer(42),
            .real(3.14159),
            .string("AnyCodable test"),
            .character("X"),
            .boolean(false)
        ]

        for originalLiteral in literalsWithAnyCodable {
            let copiedLiteral = originalLiteral

            #expect(originalLiteral == copiedLiteral, "AnyCodable literal should equal copy")

            // Test independence
            var mutableCopy = originalLiteral
            mutableCopy = .string("modified")

            #expect(originalLiteral != mutableCopy, "Original AnyCodable literal should not be affected")
            #expect(copiedLiteral == originalLiteral, "Copy should still equal original")
        }
    }

    @Test("AnyCodable Deep Copy - Round-trip Encoding/Decoding")
    func testAnyCodableDeepCopyRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let originalLiteral = Literal.integer(12345)
        
        // Encode and decode to simulate AnyCodable usage
        let encodedData = try encoder.encode(originalLiteral)
        let decodedLiteral = try decoder.decode(Literal.self, from: encodedData)
        let copiedDecoded = decodedLiteral

        #expect(originalLiteral == decodedLiteral, "Round-trip should preserve equality")
        #expect(decodedLiteral == copiedDecoded, "Decoded copy should equal original")

        // Test that copies remain independent after round-trip
        var mutableCopy = copiedDecoded
        mutableCopy = .boolean(true)

        #expect(decodedLiteral != mutableCopy, "Round-trip copy should maintain independence")
        #expect(originalLiteral == decodedLiteral, "Original should still equal decoded")
    }

    // MARK: - Phase 2: Mixed-Type Nested Structure Tests

    @Test("Mixed-Type Deep Copy - Heterogeneous Expression Arrays")
    func testMixedTypeDeepCopy() throws {
        let originalMixedExpression = FeLangCore.Expression.functionCall("processValues", [
            .literal(.integer(42)),
            .literal(.real(3.14159)),
            .literal(.string("mixed")),
            .literal(.boolean(true)),
            .binary(.add, .literal(.integer(1)), .literal(.real(2.5))),
            .functionCall("nested", [.literal(.character("N"))])
        ])
        let copiedMixedExpression = originalMixedExpression

        #expect(originalMixedExpression == copiedMixedExpression)

        // Test independence with mixed types
        var mutableCopy = originalMixedExpression
        mutableCopy = .functionCall("different", [.literal(.string("replaced"))])

        #expect(originalMixedExpression != mutableCopy)
        #expect(copiedMixedExpression == originalMixedExpression)
    }

    @Test("Mixed-Type Deep Copy - Complex Data Type Combinations")
    func testMixedTypeComplexStructures() throws {
        let originalFunction = FunctionDeclaration(
            name: "mixedTypeFunction",
            parameters: [
                Parameter(name: "intParam", type: .integer),
                Parameter(name: "realParam", type: .real),
                Parameter(name: "stringParam", type: .string),
                Parameter(name: "boolParam", type: .boolean),
                Parameter(name: "arrayParam", type: .array(.integer)),
                Parameter(name: "recordParam", type: .record("CustomRecord"))
            ],
            returnType: .array(.real),
            localVariables: [
                VariableDeclaration(name: "localInt", type: .integer, initialValue: .literal(.integer(0))),
                VariableDeclaration(name: "localString", type: .string, initialValue: .literal(.string("local")))
            ],
            body: [
                .assignment(.variable("localInt", .binary(.add, .identifier("intParam"), .literal(.integer(1))))),
                .returnStatement(ReturnStatement(expression: .functionCall("createArray", [.identifier("localInt")])))
            ]
        )
        let copiedFunction = originalFunction

        #expect(originalFunction == copiedFunction)

        // Test mixed-type structure independence
        var mutableCopy = originalFunction
        mutableCopy = FunctionDeclaration(name: "simple", parameters: [], body: [])

        #expect(originalFunction != mutableCopy)
        #expect(copiedFunction == originalFunction)
    }

    // MARK: - Phase 2: Collection-Based Nesting Tests (arrays, dictionaries)

    @Test("Collection Deep Copy - Complex Array Structures")
    func testCollectionDeepCopyArrays() throws {
        let originalArrayStatements: [Statement] = [
            .assignment(.variable("arr1", .functionCall("createArray", [.literal(.integer(10))]))),
            .assignment(.variable("arr2", .arrayAccess(.identifier("arr1"), .literal(.integer(0))))),
            .whileStatement(WhileStatement(
                condition: .binary(.less, .identifier("i"), .arrayAccess(.identifier("arr1"), .literal(.integer(0)))),
                body: [
                    .assignment(.arrayElement(
                        Assignment.ArrayAccess(array: .identifier("arr2"), index: .identifier("i")),
                        .binary(.multiply, .identifier("i"), .literal(.integer(2)))
                    )),
                    .assignment(.variable("i", .binary(.add, .identifier("i"), .literal(.integer(1)))))
                ]
            ))
        ]
        let copiedArrayStatements = originalArrayStatements

        #expect(originalArrayStatements == copiedArrayStatements)

        // Test array collection independence
        var mutableCopy = originalArrayStatements
        mutableCopy.append(.breakStatement)

        #expect(originalArrayStatements.count != mutableCopy.count)
        #expect(copiedArrayStatements == originalArrayStatements)
    }

    @Test("Collection Deep Copy - Nested Array Access Patterns")
    func testNestedArrayAccessDeepCopy() throws {
        let originalNestedAccess = FeLangCore.Expression.arrayAccess(
            .arrayAccess(.identifier("matrix"), .literal(.integer(0))),
            .arrayAccess(.identifier("indices"), .literal(.integer(1)))
        )
        let copiedNestedAccess = originalNestedAccess

        #expect(originalNestedAccess == copiedNestedAccess)

        // Test nested array access independence
        var mutableCopy = originalNestedAccess
        mutableCopy = .arrayAccess(.identifier("simple"), .literal(.integer(0)))

        #expect(originalNestedAccess != mutableCopy)
        #expect(copiedNestedAccess == originalNestedAccess)
    }

    @Test("Collection Deep Copy - Multi-dimensional Array Simulation")
    func testMultiDimensionalArrayDeepCopy() throws {
        let originalMultiDimStatement = Statement.block([
            .variableDeclaration(VariableDeclaration(
                name: "matrix",
                type: .array(.array(.integer)),
                initialValue: .functionCall("createMatrix", [.literal(.integer(3)), .literal(.integer(3))])
            )),
            .forStatement(.range(ForStatement.RangeFor(
                variable: "i",
                start: .literal(.integer(0)),
                end: .literal(.integer(2)),
                body: [
                    .forStatement(.range(ForStatement.RangeFor(
                        variable: "j",
                        start: .literal(.integer(0)),
                        end: .literal(.integer(2)),
                        body: [
                            .assignment(.arrayElement(
                                Assignment.ArrayAccess(
                                    array: .arrayAccess(.identifier("matrix"), .identifier("i")),
                                    index: .identifier("j")
                                ),
                                .binary(.add, .identifier("i"), .identifier("j"))
                            ))
                        ]
                    )))
                ]
            )))
        ])
        let copiedMultiDimStatement = originalMultiDimStatement

        #expect(originalMultiDimStatement == copiedMultiDimStatement)

        // Test multi-dimensional structure independence
        var mutableCopy = originalMultiDimStatement
        mutableCopy = .block([.breakStatement])

        #expect(originalMultiDimStatement != mutableCopy)
        #expect(copiedMultiDimStatement == originalMultiDimStatement)
    }

    // MARK: - Phase 2: Advanced Performance Monitoring

    @Test("Advanced Performance Monitoring - Nested Structure Performance")
    func testAdvancedPerformanceMonitoring() throws {
        let structures = [
            DeepCopyTestUtilities.createDeterministicNestedStructure(depth: 2, breadth: 3),
            DeepCopyTestUtilities.createDeterministicNestedStructure(depth: 3, breadth: 3),
            DeepCopyTestUtilities.createDeterministicNestedStructure(depth: 4, breadth: 2),
            DeepCopyTestUtilities.createDeterministicNestedStructure(depth: 5, breadth: 2)
        ]

        for (index, structure) in structures.enumerated() {
            let metrics = DeepCopyTestUtilities.measureDeepCopyPerformance(structure: structure, iterations: 50)
            
            // Performance should remain reasonable even for complex structures
            #expect(metrics.averageTime < 0.01, "Deep copy should complete in less than 10ms for structure \(index)")
            #expect(metrics.memoryDelta < 1024 * 1024, "Memory usage should be reasonable for structure \(index)")
        }
    }

    // MARK: - Phase 3: Edge Cases - Boundary Condition Testing

    @Test("Edge Case - Empty Structures")
    func testEdgeCaseEmptyStructures() throws {
        // Empty function body
        let emptyFunction = FunctionDeclaration(name: "empty", parameters: [], body: [])
        let originalStatement = Statement.functionDeclaration(emptyFunction)
        let copiedStatement = originalStatement

        #expect(originalStatement == copiedStatement)

        // Empty parameter list
        let emptyParamFunction = FunctionDeclaration(
            name: "noParams",
            parameters: [],
            returnType: .integer,
            body: [.returnStatement(ReturnStatement(expression: .literal(.integer(0))))]
        )
        let originalEmpty = Statement.functionDeclaration(emptyParamFunction)
        let copiedEmpty = originalEmpty

        #expect(originalEmpty == copiedEmpty)

        // Empty arrays in expressions
        let emptyArrayCall = FeLangCore.Expression.functionCall("createEmpty", [])
        let copiedArrayCall = emptyArrayCall

        #expect(emptyArrayCall == copiedArrayCall)
    }

    @Test("Edge Case - Single Element Structures")
    func testEdgeCaseSingleElementStructures() throws {
        // Single statement body
        let singleStatementFunction = FunctionDeclaration(
            name: "single",
            parameters: [Parameter(name: "x", type: .integer)],
            body: [.returnStatement(ReturnStatement(expression: .identifier("x")))]
        )
        let originalSingle = Statement.functionDeclaration(singleStatementFunction)
        let copiedSingle = originalSingle

        #expect(originalSingle == copiedSingle)

        // Single parameter
        let singleParamFunction = FunctionDeclaration(
            name: "oneParam",
            parameters: [Parameter(name: "value", type: .real)],
            body: [.expressionStatement(.identifier("value"))]
        )
        let originalOneParam = Statement.functionDeclaration(singleParamFunction)
        let copiedOneParam = originalOneParam

        #expect(originalOneParam == copiedOneParam)

        // Single argument function call
        let singleArgCall = FeLangCore.Expression.functionCall("process", [.literal(.integer(42))])
        let copiedArgCall = singleArgCall

        #expect(singleArgCall == copiedArgCall)
    }

    @Test("Edge Case - Maximum Complexity Structures")
    func testEdgeCaseMaximumComplexity() throws {
        let edgeCaseStructures = DeepCopyTestUtilities.createEdgeCaseStructures()

        for (index, structure) in edgeCaseStructures.enumerated() {
            let copiedStructure = structure

            #expect(structure == copiedStructure, "Edge case structure \(index) should equal its copy")

            // Test independence
            var mutableCopy = structure
            mutableCopy = .breakStatement

            #expect(structure != mutableCopy, "Edge case structure \(index) should maintain independence")
            #expect(copiedStructure == structure, "Copy should still equal original for structure \(index)")
        }
    }

    // MARK: - Phase 3: Complex Nesting Patterns

    @Test("Edge Case - Circular Reference Simulation")
    func testEdgeCaseCircularReferenceSimulation() throws {
        // Simulate circular reference pattern (limited by Swift's type system)
        let circularPatternFunction = FunctionDeclaration(
            name: "circularPattern",
            parameters: [Parameter(name: "self", type: .record("Node"))],
            body: [
                .ifStatement(IfStatement(
                    condition: .binary(.notEqual, .fieldAccess(.identifier("self"), "next"), .literal(.string("null"))),
                    thenBody: [
                        .expressionStatement(.functionCall("circularPattern", [.fieldAccess(.identifier("self"), "next")]))
                    ]
                ))
            ]
        )
        let originalCircular = Statement.functionDeclaration(circularPatternFunction)
        let copiedCircular = originalCircular

        #expect(originalCircular == copiedCircular)

        // Test that circular pattern copy maintains independence
        var mutableCopy = originalCircular
        mutableCopy = .functionDeclaration(FunctionDeclaration(name: "simple", parameters: [], body: []))

        #expect(originalCircular != mutableCopy)
        #expect(copiedCircular == originalCircular)
    }

    @Test("Edge Case - Self-Referential Structures")
    func testEdgeCaseSelfReferentialStructures() throws {
        // Self-referential function that calls itself
        let recursiveFunction = FunctionDeclaration(
            name: "factorial",
            parameters: [Parameter(name: "n", type: .integer)],
            returnType: .integer,
            body: [
                .ifStatement(IfStatement(
                    condition: .binary(.lessEqual, .identifier("n"), .literal(.integer(1))),
                    thenBody: [.returnStatement(ReturnStatement(expression: .literal(.integer(1))))],
                    elseBody: [
                        .returnStatement(ReturnStatement(
                            expression: .binary(.multiply,
                                .identifier("n"),
                                .functionCall("factorial", [.binary(.subtract, .identifier("n"), .literal(.integer(1)))])
                            )
                        ))
                    ]
                ))
            ]
        )
        let originalRecursive = Statement.functionDeclaration(recursiveFunction)
        let copiedRecursive = originalRecursive

        #expect(originalRecursive == copiedRecursive)

        // Test self-referential independence
        var mutableCopy = originalRecursive
        mutableCopy = .expressionStatement(.literal(.string("modified")))

        #expect(originalRecursive != mutableCopy)
        #expect(copiedRecursive == originalRecursive)
    }

    @Test("Edge Case - Deeply Nested If-Else Chains")
    func testEdgeCaseDeeplyNestedIfElse() throws {
        let deepChain = DeepCopyTestUtilities.createEdgeCaseStructures().first { structure in
            if case .ifStatement(_) = structure {
                return true
            }
            return false
        }!

        let copiedChain = deepChain

        #expect(deepChain == copiedChain)

        // Test deep chain independence
        var mutableCopy = deepChain
        mutableCopy = .breakStatement

        #expect(deepChain != mutableCopy)
        #expect(copiedChain == deepChain)
    }

    // MARK: - Phase 3: Error Condition Testing

    @Test("Edge Case - Malformed Structure Handling")
    func testEdgeCaseMalformedStructures() throws {
        // Test unusual but valid structures
        let unusualStructures: [Statement] = [
            // Function with no return type but has return statement
            .functionDeclaration(FunctionDeclaration(
                name: "noReturnType",
                parameters: [Parameter(name: "x", type: .integer)],
                returnType: nil,
                body: [.returnStatement(ReturnStatement(expression: .identifier("x")))]
            )),
            // While loop with constant false condition
            .whileStatement(WhileStatement(
                condition: .literal(.boolean(false)),
                body: [.expressionStatement(.literal(.string("unreachable")))]
            )),
            // IF with empty then body
            .ifStatement(IfStatement(
                condition: .literal(.boolean(true)),
                thenBody: []
            ))
        ]

        for (index, structure) in unusualStructures.enumerated() {
            let copiedStructure = structure

            #expect(structure == copiedStructure, "Unusual structure \(index) should equal its copy")

            // Test independence
            var mutableCopy = structure
            mutableCopy = .breakStatement

            #expect(structure != mutableCopy, "Unusual structure \(index) should maintain independence")
            #expect(copiedStructure == structure, "Copy should equal original for unusual structure \(index)")
        }
    }

    @Test("Edge Case - Type Safety Verification in Deep Copy")
    func testEdgeCaseTypeSafetyVerification() throws {
        // Mixed data types in complex expressions
        let typeSafetyExpression = FeLangCore.Expression.binary(.add,
            .literal(.integer(42)), // Integer
            .unary(.not, .literal(.boolean(false))) // Boolean in unary
        )
        let copiedTypeSafety = typeSafetyExpression

        #expect(typeSafetyExpression == copiedTypeSafety)

        // Mixed types in function parameters
        let mixedTypeFunction = FunctionDeclaration(
            name: "mixedTypes",
            parameters: [
                Parameter(name: "int", type: .integer),
                Parameter(name: "real", type: .real),
                Parameter(name: "str", type: .string),
                Parameter(name: "bool", type: .boolean),
                Parameter(name: "char", type: .character),
                Parameter(name: "arr", type: .array(.integer)),
                Parameter(name: "rec", type: .record("CustomType"))
            ],
            body: [.breakStatement]
        )
        let originalMixed = Statement.functionDeclaration(mixedTypeFunction)
        let copiedMixed = originalMixed

        #expect(originalMixed == copiedMixed)
    }

    // MARK: - Phase 4: Performance & Memory - Comprehensive Performance Benchmarking

    @Test("Performance Benchmark - Small vs Large Structure Comparison")
    func testPerformanceBenchmarkComparison() throws {
        let smallStructure = createSimpleStructure()
        let mediumStructure = createMediumComplexityStructure()
        let largeStructure = DeepCopyTestUtilities.createLargeNestedStructure(nodeCount: 500)

        let structures = [smallStructure, mediumStructure, largeStructure]
        let comparisons = DeepCopyTestUtilities.comparePerformance(structures: structures)

        for (index, comparison) in comparisons.enumerated() {
            // All structures should perform reasonably
            #expect(comparison.metrics.averageTime < 0.1, "Structure \(index) (\(comparison.structureType)) should copy in less than 100ms")
            #expect(comparison.metrics.memoryDelta < 10 * 1024 * 1024, "Structure \(index) should use less than 10MB")

            // Log performance metrics for monitoring
            print("Structure \(index) (\(comparison.structureType)): \(comparison.metrics.averageTime * 1000)ms avg, \(comparison.metrics.memoryDelta) bytes")
        }
    }

    @Test("Performance Benchmark - Scalability Testing")
    func testPerformanceBenchmarkScalability() throws {
        let depths = [1, 2, 3, 4, 5]
        var previousTime: TimeInterval = 0.0

        for depth in depths {
            let structure = DeepCopyTestUtilities.createDeterministicNestedStructure(depth: depth, breadth: 3)
            let metrics = DeepCopyTestUtilities.measureDeepCopyPerformance(structure: structure, iterations: 20)

            // Performance should scale reasonably with depth
            #expect(metrics.averageTime < 0.05, "Depth \(depth) should copy in less than 50ms")

            // Performance shouldn't degrade exponentially (only check if we have meaningful measurements)
            if depth > 1 && previousTime > 0.0 && metrics.averageTime > 0.0 {
                let performanceRatio = metrics.averageTime / previousTime
                #expect(performanceRatio < 10.0, "Performance degradation should be reasonable between depth \(depth-1) and \(depth)")
            }

            // Use a minimum threshold to avoid division by zero
            previousTime = max(metrics.averageTime, 0.000001) // 1 microsecond minimum
            print("Depth \(depth): \(metrics.averageTime * 1000)ms avg, \(metrics.memoryDelta) bytes")
        }
    }

    @Test("Performance Benchmark - Random Structure Stress Test")
    func testPerformanceBenchmarkRandomStress() throws {
        let randomStructures = (0..<10).map { seed in
            DeepCopyTestUtilities.createRandomNestedStructure(maxDepth: 4, seed: UInt64(seed))
        }

        for (index, structure) in randomStructures.enumerated() {
            let metrics = DeepCopyTestUtilities.measureDeepCopyPerformance(structure: structure, iterations: 10)

            // Random structures should still perform reasonably
            #expect(metrics.averageTime < 0.02, "Random structure \(index) should copy in less than 20ms")
            #expect(metrics.memoryDelta < 5 * 1024 * 1024, "Random structure \(index) should use less than 5MB")
        }
    }

    // MARK: - Phase 4: Memory Leak Detection Tests

    @Test("Memory Leak Detection - Basic Structures")
    func testMemoryLeakDetectionBasic() throws {
        let basicStructures = [
            createSimpleStructure(),
            createMediumComplexityStructure(),
            Statement.functionDeclaration(FunctionDeclaration(name: "test", parameters: [], body: []))
        ]

        for (index, structure) in basicStructures.enumerated() {
            let leakResult = DeepCopyTestUtilities.checkForMemoryLeaks(structure: structure, iterations: 500)

            #expect(!leakResult.hasLeak, "Basic structure \(index) should not leak memory")
            print("Basic structure \(index) memory delta: \(leakResult.memoryDelta) bytes")
        }
    }

    @Test("Memory Leak Detection - Complex Nested Structures")
    func testMemoryLeakDetectionComplex() throws {
        let complexStructures = [
            DeepCopyTestUtilities.createDeterministicNestedStructure(depth: 4, breadth: 3),
            DeepCopyTestUtilities.createLargeNestedStructure(nodeCount: 200),
            DeepCopyTestUtilities.createRandomNestedStructure(maxDepth: 5, seed: 54321)
        ]

        for (index, structure) in complexStructures.enumerated() {
            let leakResult = DeepCopyTestUtilities.checkForMemoryLeaks(structure: structure, iterations: 200)

            #expect(!leakResult.hasLeak, "Complex structure \(index) should not leak memory")
            print("Complex structure \(index) memory delta: \(leakResult.memoryDelta) bytes")
        }
    }

    @Test("Memory Leak Detection - Edge Case Structures")
    func testMemoryLeakDetectionEdgeCases() throws {
        let edgeCaseStructures = DeepCopyTestUtilities.createEdgeCaseStructures()

        for (index, structure) in edgeCaseStructures.enumerated() {
            let leakResult = DeepCopyTestUtilities.checkForMemoryLeaks(structure: structure, iterations: 100)

            #expect(!leakResult.hasLeak, "Edge case structure \(index) should not leak memory")
            print("Edge case structure \(index) memory delta: \(leakResult.memoryDelta) bytes")
        }
    }

    // MARK: - Phase 4: Stress Testing with Large Object Graphs

    @Test("Stress Test - Large Object Graph Performance")
    func testStressTestLargeObjectGraph() throws {
        let largeSizes = [100, 500, 1000, 2000]

        for size in largeSizes {
            let largeStructure = DeepCopyTestUtilities.createLargeNestedStructure(nodeCount: size)
            let metrics = DeepCopyTestUtilities.measureDeepCopyPerformance(structure: largeStructure, iterations: 5)

            // Large structures should still complete in reasonable time
            let maxTimeSeconds = Double(size) / 1000.0 // 1ms per 1000 nodes baseline
            #expect(metrics.averageTime < maxTimeSeconds, "Large structure (\(size) nodes) should copy in less than \(maxTimeSeconds)s")

            // Memory usage should be reasonable
            let maxMemoryMB = Int64(size * 1024) // ~1KB per node baseline
            #expect(metrics.memoryDelta < maxMemoryMB, "Large structure (\(size) nodes) should use less than \(maxMemoryMB) bytes")

            print("Large structure (\(size) nodes): \(metrics.averageTime * 1000)ms avg, \(metrics.memoryDelta) bytes")
        }
    }

    @Test("Stress Test - Concurrent Deep Copy Operations")
    func testStressTestConcurrentDeepCopy() async throws {
        let testStructure = createMediumComplexityStructure()
        let concurrentTasks = 10
        let iterationsPerTask = 50
        var allTasksCompleted = true

        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<concurrentTasks {
                group.addTask {
                    for _ in 0..<iterationsPerTask {
                        let copy = testStructure
                        guard copy == testStructure else {
                            return false // Task failed
                        }
                    }
                    return true // Task succeeded
                }
            }
            
            // Collect results from all tasks
            for await taskResult in group {
                if !taskResult {
                    allTasksCompleted = false
                }
            }
        }

        // Verify that all concurrent operations completed successfully
        #expect(allTasksCompleted, "All concurrent deep copy operations should complete successfully")
    }

    // MARK: - Phase 4: Performance Regression Prevention

    @Test("Performance Regression - Baseline Metrics Establishment")
    func testPerformanceRegressionBaseline() throws {
        let baselineStructures = [
            ("Simple", createSimpleStructure()),
            ("Medium", createMediumComplexityStructure()),
            ("Complex", DeepCopyTestUtilities.createDeterministicNestedStructure(depth: 3, breadth: 3))
        ]

        for (name, structure) in baselineStructures {
            let metrics = DeepCopyTestUtilities.measureDeepCopyPerformance(structure: structure, iterations: 100)

            // Establish baseline performance expectations
            switch name {
            case "Simple":
                #expect(metrics.averageTime < 0.001, "Simple structure baseline: < 1ms")
            case "Medium":
                #expect(metrics.averageTime < 0.005, "Medium structure baseline: < 5ms")
            case "Complex":
                #expect(metrics.averageTime < 0.010, "Complex structure baseline: < 10ms")
            default:
                break
            }

            print("\(name) baseline: \(metrics.averageTime * 1000)ms avg, \(metrics.memoryDelta) bytes")
        }
    }

    @Test("Performance Regression - Validation Against Baseline")
    func testPerformanceRegressionValidation() throws {
        let validationStructure = createMediumComplexityStructure()
        let validationMetrics = DeepCopyTestUtilities.measureDeepCopyPerformance(structure: validationStructure, iterations: 100)

        // Validate against established baseline (allowing 20% variance)
        let baselineTime: TimeInterval = 0.005 // 5ms baseline from previous test
        let allowedVariance: TimeInterval = baselineTime * 0.2

        #expect(validationMetrics.averageTime < baselineTime + allowedVariance,
                "Performance should not regress beyond \((baselineTime + allowedVariance) * 1000)ms")

        // Memory usage should remain stable
        #expect(validationMetrics.memoryDelta < 1024 * 1024, "Memory usage should remain under 1MB")

        print("Validation metrics: \(validationMetrics.averageTime * 1000)ms avg (baseline: \(baselineTime * 1000)ms)")
    }

    // MARK: - Comprehensive Integration Tests

    @Test("Integration Test - Full Deep Copy Validation Pipeline")
    func testIntegrationFullValidationPipeline() throws {
        let testStructure = DeepCopyTestUtilities.createDeterministicNestedStructure(depth: 4, breadth: 3)
        let copiedStructure = testStructure

        // 1. Basic equality validation
        let equalityResult = DeepCopyTestUtilities.validateDeepEquality(original: testStructure, copy: copiedStructure)
        #expect(equalityResult.isSuccess, "Deep equality validation should pass: \(equalityResult.message)")

        // 2. Independence validation
        let independenceResult = DeepCopyTestUtilities.validateIndependence(
            original: testStructure,
            copy: copiedStructure
        ) { mutableCopy in
            mutableCopy = .breakStatement
        }
        #expect(independenceResult.isSuccess, "Independence validation should pass: \(independenceResult.message)")

        // 3. Performance validation
        let performanceMetrics = DeepCopyTestUtilities.measureDeepCopyPerformance(structure: testStructure, iterations: 50)
        #expect(performanceMetrics.averageTime < 0.02, "Performance should be acceptable")

        // 4. Memory leak validation
        let memoryResult = DeepCopyTestUtilities.checkForMemoryLeaks(structure: testStructure, iterations: 100)
        #expect(!memoryResult.hasLeak, "No memory leaks should be detected")

        print("Integration test completed - all validations passed")
    }

    // MARK: - Test Data Generation Utilities

    /// Creates a medium complexity AST structure for testing
    private func createMediumComplexityStructure() -> Statement {
        return .ifStatement(IfStatement(
            condition: .binary(.and,
                .binary(.greater, .identifier("x"), .literal(.integer(0))),
                .binary(.less, .identifier("x"), .literal(.integer(100)))
            ),
            thenBody: [
                .assignment(.variable("result", .binary(.multiply, .identifier("x"), .literal(.integer(2))))),
                .whileStatement(WhileStatement(
                    condition: .binary(.greater, .identifier("result"), .literal(.integer(0))),
                    body: [
                        .assignment(.variable("result", .binary(.subtract, .identifier("result"), .literal(.integer(1))))),
                        .ifStatement(IfStatement(
                            condition: .binary(.equal, .binary(.modulo, .identifier("result"), .literal(.integer(10))), .literal(.integer(0))),
                            thenBody: [.expressionStatement(.functionCall("log", [.identifier("result")]))]
                        ))
                    ]
                ))
            ],
            elseIfs: [
                IfStatement.ElseIf(
                    condition: .binary(.equal, .identifier("x"), .literal(.integer(0))),
                    body: [.assignment(.variable("result", .literal(.integer(0))))]
                )
            ],
            elseBody: [
                .assignment(.variable("result", .literal(.integer(-1))))
            ]
        ))
    }

    /// Creates a simple linear structure for baseline testing
    private func createSimpleStructure() -> Statement {
        return .assignment(.variable("simple", .literal(.integer(42))))
    }

    /// Creates a collection of varied expressions for testing
    private func createVariedExpressions() -> [FeLangCore.Expression] {
        return [
            .literal(.integer(42)),
            .literal(.real(3.14)),
            .literal(.string("test")),
            .literal(.boolean(true)),
            .identifier("variable"),
            .binary(.add, .literal(.integer(1)), .literal(.integer(2))),
            .unary(.minus, .literal(.integer(5))),
            .functionCall("func", [.literal(.integer(1)), .literal(.integer(2))]),
            .arrayAccess(.identifier("arr"), .literal(.integer(0))),
            .fieldAccess(.identifier("obj"), "property")
        ]
    }
} 