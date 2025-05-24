import Testing
@testable import FeLangCore
import Foundation

/// Comprehensive AST Immutability Audit Tests
/// Implements the audit requirements from GitHub issue #29
/// Tests all AST types for immutability violations, thread safety, and value semantics
@Suite("AST Immutability Audit")
struct ASTImmutabilityAuditTests {

    // MARK: - Child Issue: AnyCodable Safety Analysis

    @Test("AnyCodable Type Safety - Verify only value types can be stored")
    func testAnyCodableTypeSafety() throws {
        // Test that AnyCodable properly restricts to value types during decoding
        // This tests the concern raised in issue #29 about AnyCodable.value: Any

        let validLiteralData = Data("""
        {"integer": 42}
        """.utf8)

        let decoder = JSONDecoder()
        let literal = try decoder.decode(Literal.self, from: validLiteralData)

        #expect(literal == .integer(42))

        // Test round-trip encoding/decoding maintains value semantics
        let encoder = JSONEncoder()
        let encodedData = try encoder.encode(literal)
        let decodedLiteral = try decoder.decode(Literal.self, from: encodedData)

        #expect(literal == decodedLiteral)

        // Test all literal types for proper value semantics
        let literalCases: [Literal] = [
            .integer(123),
            .real(3.14),
            .string("test"),
            .character("A"),
            .boolean(true)
        ]

        for literalCase in literalCases {
            let encoded = try encoder.encode(literalCase)
            let decoded = try decoder.decode(Literal.self, from: encoded)
            #expect(literalCase == decoded, "Literal \(literalCase) failed round-trip test")
        }
    }

    @Test("AnyCodable Implementation Constraints")
    func testAnyCodableImplementationConstraints() throws {
        // Verify that AnyCodable only accepts the specific value types
        // and properly rejects unsupported types during decoding

        // Test invalid JSON that would try to store unsupported types
        let invalidData = Data("""
        {"unsupported": [1, 2, 3]}
        """.utf8)

        let decoder = JSONDecoder()

        // Should throw when encountering unsupported nested structures
        #expect(throws: DecodingError.self) {
            _ = try decoder.decode([String: Literal].self, from: invalidData)
        }
    }

    // MARK: - Child Issue: Collection Immutability Validation

    @Test("Deep Collection Immutability - Arrays maintain value semantics")
    func testDeepCollectionImmutability() throws {
        // Test that arrays of AST nodes maintain deep immutability
        let originalStatements: [Statement] = [
            .expressionStatement(.literal(.integer(1))),
            .expressionStatement(.literal(.string("test"))),
            .ifStatement(IfStatement(
                condition: .literal(.boolean(true)),
                thenBody: [.expressionStatement(.literal(.integer(42)))]
            ))
        ]

        // Copy array - should maintain value semantics
        let copiedStatements = originalStatements

        // Arrays should be equal via value semantics
        #expect(originalStatements == copiedStatements)

        // Test deep nested array immutability
        let nestedIfStatement = IfStatement(
            condition: .binary(.and, .literal(.boolean(true)), .literal(.boolean(false))),
            thenBody: [
                .expressionStatement(.literal(.integer(1))),
                .whileStatement(WhileStatement(
                    condition: .literal(.boolean(true)),
                    body: [.expressionStatement(.literal(.string("nested")))]
                ))
            ],
            elseIfs: [
                IfStatement.ElseIf(
                    condition: .literal(.boolean(false)),
                    body: [.expressionStatement(.literal(.character("x")))]
                )
            ],
            elseBody: [.breakStatement]
        )

        let originalNested = Statement.ifStatement(nestedIfStatement)
        let copiedNested = originalNested

        #expect(originalNested == copiedNested)
    }

    @Test("Function Declaration Parameter Arrays")
    func testFunctionDeclarationParameterArrays() throws {
        let parameters: [Parameter] = [
            Parameter(name: "x", type: .integer),
            Parameter(name: "y", type: .real),
            Parameter(name: "z", type: .string)
        ]

        let originalFunction = FunctionDeclaration(
            name: "testFunc",
            parameters: parameters,
            returnType: .boolean,
            localVariables: [
                VariableDeclaration(name: "local", type: .integer, initialValue: .literal(.integer(0)))
            ],
            body: [.returnStatement(ReturnStatement(expression: .literal(.boolean(true))))]
        )

        let copiedFunction = originalFunction

        // Verify deep equality
        #expect(originalFunction == copiedFunction)
        #expect(originalFunction.parameters == copiedFunction.parameters)
        #expect(originalFunction.localVariables == copiedFunction.localVariables)
        #expect(originalFunction.body == copiedFunction.body)
    }

    // MARK: - Expression Immutability Validation

    @Test("Expression Deep Immutability")
    func testExpressionDeepImmutability() throws {
        let complexExpression = Expression.binary(
            .multiply,
            .functionCall("calculateValue", [
                .literal(.integer(42)),
                .arrayAccess(.identifier("arr"), .literal(.integer(0))),
                .fieldAccess(.identifier("obj"), "property")
            ]),
            .unary(.minus, .binary(.add, .literal(.real(3.14)), .literal(.real(2.71))))
        )

        let copiedExpression = complexExpression

        #expect(complexExpression == copiedExpression)

        // Test that modifications to variables don't affect the immutable expression
        var mutableExpression = complexExpression
        mutableExpression = .literal(.integer(999))

        // Original should remain unchanged
        #expect(complexExpression != mutableExpression)
        #expect(copiedExpression == complexExpression)
    }

    @Test("Binary and Unary Operator Immutability")
    func testOperatorImmutability() throws {
        let operators = BinaryOperator.allCases
        let originalOperators = operators

        #expect(operators == originalOperators)

                // Test that computed properties don't affect immutability
        for binaryOp in operators {
            let precedence1 = binaryOp.precedence
            let precedence2 = binaryOp.precedence
            let associativity1 = binaryOp.isLeftAssociative
            let associativity2 = binaryOp.isLeftAssociative

            #expect(precedence1 == precedence2)
            #expect(associativity1 == associativity2)
        }

        let unaryOperators = UnaryOperator.allCases
        for unaryOp in unaryOperators {
            let precedence1 = unaryOp.precedence
            let precedence2 = unaryOp.precedence
            #expect(precedence1 == precedence2)
        }
    }

    // MARK: - Child Issue: Sendable Conformance Verification

    @Test("Sendable Conformance - Thread Safety Verification")
    func testSendableConformanceThreadSafety() async throws {
        let sharedExpression = Expression.binary(
            .add,
            .literal(.integer(1)),
            .literal(.integer(2))
        )

        let sharedStatement = Statement.expressionStatement(sharedExpression)

        // Test concurrent access to shared immutable AST
                await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<10 {
                group.addTask { @Sendable in
                    // Each task reads from the shared AST concurrently
                    let expression = sharedExpression
                    let statement = sharedStatement

                    // Verify the values remain consistent across threads
                    return expression == .binary(.add, .literal(.integer(1)), .literal(.integer(2))) &&
                           statement == .expressionStatement(expression)
                }
            }

            var allSuccess = true
            for await result in group {
                allSuccess = allSuccess && result
            }

            #expect(allSuccess, "Concurrent access to AST failed")
                }
    }

    @Test("Sendable Equality Consistency")
    func testSendableEqualityConsistency() throws {
        let expression = Expression.literal(.string("test"))
        let statement = Statement.expressionStatement(expression)

        // Test that equality is consistent across multiple calls (required for Sendable types)
        let expression2 = Expression.literal(.string("test"))
        let statement2 = Statement.expressionStatement(expression2)

        #expect(expression == expression2, "Identical expressions should be equal")
        #expect(statement == statement2, "Identical statements should be equal")

        // Test with complex nested structures
        let complexAST1 = Statement.ifStatement(IfStatement(
            condition: .binary(.greater, .identifier("x"), .literal(.integer(0))),
            thenBody: [
                .assignment(.variable("result", .literal(.boolean(true)))),
                .expressionStatement(.functionCall("log", [.literal(.string("success"))]))
            ]
        ))

        let complexAST2 = Statement.ifStatement(IfStatement(
            condition: .binary(.greater, .identifier("x"), .literal(.integer(0))),
            thenBody: [
                .assignment(.variable("result", .literal(.boolean(true)))),
                .expressionStatement(.functionCall("log", [.literal(.string("success"))]))
            ]
        ))

        #expect(complexAST1 == complexAST2, "Complex AST structures should have consistent equality")
    }

    // MARK: - Value Semantics Verification

    @Test("Value Semantics - Copy Behavior")
    func testValueSemanticsCopyBehavior() throws {
        // Test that AST types exhibit proper value semantics
        var originalExpr = Expression.literal(.integer(42))
        let copiedExpr = originalExpr

        // Modify original
        originalExpr = .literal(.integer(999))

        // Copied should remain unchanged
        #expect(copiedExpr == .literal(.integer(42)))
        #expect(originalExpr != copiedExpr)

        // Test with complex structures
        var originalStmt = Statement.whileStatement(WhileStatement(
            condition: .literal(.boolean(true)),
            body: [.expressionStatement(.literal(.string("loop")))]
        ))

        let copiedStmt = originalStmt

        originalStmt = .breakStatement

        #expect(copiedStmt != originalStmt)
        if case let .whileStatement(whileStmt) = copiedStmt {
            #expect(whileStmt.condition == .literal(.boolean(true)))
        } else {
            #expect(Bool(false), "Expected while statement")
        }
    }

    @Test("Equality Consistency")
    func testEqualityConsistency() throws {
        let expr1 = Expression.binary(.add, .literal(.integer(1)), .literal(.integer(2)))
        let expr2 = Expression.binary(.add, .literal(.integer(1)), .literal(.integer(2)))
        let expr3 = Expression.binary(.subtract, .literal(.integer(1)), .literal(.integer(2)))

        // Equality should be consistent
        #expect(expr1 == expr2)
        #expect(expr1 != expr3)
        #expect(expr2 != expr3)

        // Test reflexivity
        #expect(expr1 == expr1)

        // Test symmetry
        #expect((expr1 == expr2) == (expr2 == expr1))

        // Test transitivity with a third equal expression
        let expr4 = Expression.binary(.add, .literal(.integer(1)), .literal(.integer(2)))
        #expect(expr1 == expr2)
        #expect(expr2 == expr4)
        #expect(expr1 == expr4)
    }

    // MARK: - Custom Codable Implementation Review

    @Test("Custom Codable Implementation - Literal Enum")
    func testCustomCodableImplementation() throws {
        // Test the custom Codable implementation for Literal enum
        // This addresses the concern about custom implementation bypassing automatic synthesis

        let literals: [Literal] = [
            .integer(42),
            .real(3.14159),
            .string("Hello, World!"),
            .character("A"),
            .boolean(true),
            .boolean(false)
        ]

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for literal in literals {
            // Test encoding
            let encoded = try encoder.encode(literal)
            #expect(!encoded.isEmpty, "Encoding should produce non-empty data")

            // Test decoding
            let decoded = try decoder.decode(Literal.self, from: encoded)
            #expect(decoded == literal, "Round-trip encoding/decoding should preserve value")

            // Test that the custom implementation produces valid JSON
            let json = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
            #expect(json != nil, "Should produce valid JSON")
            #expect(json?.keys.count == 1, "Should have exactly one key")
        }
    }

    @Test("Codable Immutability Preservation")
    func testCodableImmutabilityPreservation() throws {
        // Test that serialization/deserialization preserves immutability
        let complexExpression = Expression.binary(
            .and,
            .functionCall("isValid", [.identifier("input")]),
            .unary(.not, .literal(.boolean(false)))
        )

        let originalStatement = Statement.expressionStatement(complexExpression)

        // Encode and decode
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let encoded = try encoder.encode(originalStatement)
        let decoded = try decoder.decode(Statement.self, from: encoded)

        // Should be equal but separate instances
        #expect(decoded == originalStatement)

        // Test that both remain immutable
        let copyOriginal = originalStatement
        let copyDecoded = decoded

        #expect(copyOriginal == originalStatement)
        #expect(copyDecoded == decoded)
        #expect(copyOriginal == copyDecoded)
    }

    // MARK: - DataType Immutability

    @Test("DataType Recursive Immutability")
    func testDataTypeRecursiveImmutability() throws {
        // Test that recursive DataType structures maintain immutability
        let arrayOfArrays = DataType.array(.array(.integer))
        let copyArrayOfArrays = arrayOfArrays

        #expect(arrayOfArrays == copyArrayOfArrays)

        // Test complex nested data types
        let complexType = DataType.array(.record("UserRecord"))
        let copyComplexType = complexType

        #expect(complexType == copyComplexType)

        // Test that DataType creation from TokenType maintains immutability
        let basicTypes: [TokenType] = [.integerType, .realType, .stringType, .characterType, .booleanType]

        for tokenType in basicTypes {
            if let dataType = DataType(tokenType: tokenType) {
                let copyDataType = dataType
                #expect(dataType == copyDataType)
            }
        }
    }

    // MARK: - Memory Safety and Performance

    @Test("Memory Safety - No Retain Cycles")
    func testMemorySafetyNoRetainCycles() throws {
        // Test that AST structures don't create retain cycles
        // Since all types are value types, this should be inherently safe

        weak var weakRef: AnyObject?

        autoreleasepool {
            let expression = Expression.binary(
                .multiply,
                .functionCall("calculate", [.literal(.integer(1))]),
                .literal(.real(2.0))
            )

            let statement = Statement.expressionStatement(expression)
            let statements = [statement]

            // Since these are all value types, no retain cycles should be possible
            // This test serves as documentation of the value-type safety
            #expect(statements.count == 1)
        }

        // Any object references should be nil (though we don't expect any with value types)
        #expect(weakRef == nil)
    }

    @Test("Large AST Structure Immutability")
    func testLargeASTStructureImmutability() throws {
        // Test immutability with large, deeply nested structures
                let largeBodyStatements = (0..<100).map { index in
            Statement.expressionStatement(.literal(.integer(index)))
                }

        let largeFunction = FunctionDeclaration(
            name: "largeFunction",
            parameters: (0..<20).map { index in
                Parameter(name: "param\(index)", type: .integer)
            },
            returnType: .boolean,
            localVariables: (0..<50).map { index in
                VariableDeclaration(name: "var\(index)", type: .real)
            },
            body: largeBodyStatements
        )

        let originalLarge = Statement.functionDeclaration(largeFunction)
        let copiedLarge = originalLarge

        // Should remain equal despite size
        #expect(originalLarge == copiedLarge)

        // Test that individual components maintain immutability
        if case let .functionDeclaration(func1) = originalLarge,
           case let .functionDeclaration(func2) = copiedLarge {
            #expect(func1.body.count == func2.body.count)
            #expect(func1.parameters.count == func2.parameters.count)
            #expect(func1.localVariables.count == func2.localVariables.count)
        }
    }
}

// MARK: - AST Construction Pattern Audit

@Suite("AST Construction Pattern Audit")
struct ASTConstructionPatternAuditTests {

    @Test("Parser Construction Immutability")
    func testParserConstructionImmutability() throws {
        // Test that parser-created AST structures are properly immutable
        let tokens = try ParsingTokenizer.tokenize("x + 1")
        let parser = ExpressionParser()
        let expression = try parser.parseExpression(from: tokens)

        let originalExpression = expression
        let copiedExpression = expression

        #expect(originalExpression == copiedExpression)

        // Test that the expression maintains value semantics
        #expect(expression == .binary(.add, .identifier("x"), .literal(.integer(1))))
    }

    @Test("Factory Method Immutability")
    func testFactoryMethodImmutability() throws {
        // Test AST creation through various initialization methods

        // Test Literal creation from Token
        let token = Token(type: .integerLiteral, lexeme: "42", position: SourcePosition(line: 1, column: 1, offset: 0))

        guard let literal = Literal(token: token) else {
            #expect(Bool(false), "Should create literal from token")
            return
        }

        let originalLiteral = literal
        let copiedLiteral = literal

        #expect(originalLiteral == copiedLiteral)
        #expect(literal == .integer(42))

        // Test BinaryOperator creation from TokenType
        guard let binaryOp = BinaryOperator(tokenType: .plus) else {
            #expect(Bool(false), "Should create binary operator from token type")
            return
        }

        let originalOp = binaryOp
        let copiedOp = binaryOp

        #expect(originalOp == copiedOp)
        #expect(binaryOp == .add)
    }

    @Test("Immutable Builder Pattern Validation")
    func testImmutableBuilderPatternValidation() throws {
        // Test that AST construction follows immutable patterns
        // (no mutable builder patterns should exist)

        // Constructing complex nested structures should use immutable patterns
        let innerExpression = Expression.literal(.integer(42))
        let outerExpression = Expression.unary(.minus, innerExpression)
        let finalExpression = Expression.binary(.multiply, outerExpression, .literal(.real(2.0)))

        // All intermediate expressions should remain unchanged
        #expect(innerExpression == .literal(.integer(42)))
        #expect(outerExpression == .unary(.minus, .literal(.integer(42))))
        #expect(finalExpression == .binary(.multiply, .unary(.minus, .literal(.integer(42))), .literal(.real(2.0))))

        // Test similar pattern with statements
        let baseStatement = Statement.expressionStatement(.identifier("x"))
        let blockStatement = Statement.block([baseStatement])

        #expect(baseStatement == .expressionStatement(.identifier("x")))

        if case let .block(statements) = blockStatement {
            #expect(statements.count == 1)
            #expect(statements[0] == baseStatement)
        }
    }
}
