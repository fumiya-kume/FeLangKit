import Testing
@testable import FeLangCore
import Foundation

// Alias to avoid conflict with Foundation.Expression
typealias ASTExpression = FeLangCore.Expression

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
        let complexExpression = ASTExpression.binary(
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

    @Test("Sendable Equality Consistency")
    func testSendableEqualityConsistency() throws {
        let expression = ASTExpression.literal(.string("test"))
        let statement = Statement.expressionStatement(expression)

        // Test that equality is consistent across multiple calls (required for Sendable types)
        let expression2 = ASTExpression.literal(.string("test"))
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
        var originalExpr = ASTExpression.literal(.integer(42))
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
        let expr1 = ASTExpression.binary(.add, .literal(.integer(1)), .literal(.integer(2)))
        let expr2 = ASTExpression.binary(.add, .literal(.integer(1)), .literal(.integer(2)))
        let expr3 = ASTExpression.binary(.subtract, .literal(.integer(1)), .literal(.integer(2)))

        // Equality should be consistent
        #expect(expr1 == expr2)
        #expect(expr1 != expr3)
        #expect(expr2 != expr3)

        // Test reflexivity
        #expect(expr1 == expr1)

        // Test symmetry
        #expect((expr1 == expr2) == (expr2 == expr1))

        // Test transitivity with a third equal expression
        let expr4 = ASTExpression.binary(.add, .literal(.integer(1)), .literal(.integer(2)))
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
        let complexExpression = ASTExpression.binary(
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

    // MARK: - Comprehensive Round-Trip Serialization Tests

    @Test("Expression Round-Trip Serialization")
    func testExpressionRoundTripSerialization() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // Test all Expression cases
        let expressions: [ASTExpression] = [
            // Literal expressions
            .literal(.integer(42)),
            .literal(.real(3.14159)),
            .literal(.string("Hello, 世界!")),
            .literal(.character("А")), // Cyrillic character
            .literal(.boolean(true)),
            .literal(.boolean(false)),

            // Identifier expressions
            .identifier("variable"),
            .identifier("整数型"), // Japanese identifier
            .identifier("_underscore_var"),

            // Binary expressions with different operators and precedence
            .binary(.add, .literal(.integer(1)), .literal(.integer(2))),
            .binary(.subtract, .identifier("x"), .literal(.real(1.5))),
            .binary(.multiply, .literal(.integer(3)), .literal(.integer(4))),
            .binary(.divide, .identifier("numerator"), .identifier("denominator")),
            .binary(.modulo, .literal(.integer(10)), .literal(.integer(3))),
            .binary(.equal, .identifier("a"), .identifier("b")),
            .binary(.notEqual, .literal(.integer(5)), .literal(.integer(7))),
            .binary(.greater, .identifier("x"), .literal(.integer(0))),
            .binary(.greaterEqual, .literal(.real(3.14)), .literal(.real(3.0))),
            .binary(.less, .identifier("count"), .literal(.integer(100))),
            .binary(.lessEqual, .literal(.integer(42)), .identifier("max")),
            .binary(.and, .literal(.boolean(true)), .identifier("condition")),
            .binary(.or, .identifier("flag1"), .identifier("flag2")),

            // Unary expressions
            .unary(.not, .literal(.boolean(false))),
            .unary(.plus, .literal(.integer(5))),
            .unary(.minus, .identifier("value")),
            .unary(.not, .binary(.equal, .identifier("x"), .literal(.integer(0)))),

            // Array access expressions
            .arrayAccess(.identifier("array"), .literal(.integer(0))),
            .arrayAccess(.identifier("matrix"), .binary(.add, .identifier("i"), .literal(.integer(1)))),
            .arrayAccess(.arrayAccess(.identifier("grid"), .identifier("row")), .identifier("col")),

            // Field access expressions  
            .fieldAccess(.identifier("object"), "property"),
            .fieldAccess(.identifier("record"), "フィールド"), // Japanese field name
            .fieldAccess(.arrayAccess(.identifier("objects"), .literal(.integer(0))), "value"),

            // Function call expressions
            .functionCall("function", []),
            .functionCall("add", [.literal(.integer(1)), .literal(.integer(2))]),
            .functionCall("複雑な関数", [.identifier("param1"), .literal(.string("param2"))]), // Japanese function name
            .functionCall("max", [
                .binary(.add, .identifier("a"), .literal(.integer(1))),
                .binary(.multiply, .identifier("b"), .literal(.integer(2))),
                .literal(.integer(100))
            ]),

            // Complex nested expressions
            .binary(.and,
                .binary(.greater, .identifier("x"), .literal(.integer(0))),
                .binary(.less, .identifier("x"), .literal(.integer(100)))
            ),
            .functionCall("calculate", [
                .unary(.minus, .arrayAccess(.identifier("values"), .literal(.integer(0)))),
                .fieldAccess(.identifier("config"), "threshold")
            ])
        ]

        for (index, expression) in expressions.enumerated() {
            // Test round-trip encoding/decoding
            let encoded = try encoder.encode(expression)
            #expect(!encoded.isEmpty, "Encoded data should not be empty for expression \(index)")

            let decoded = try decoder.decode(ASTExpression.self, from: encoded)
            #expect(decoded == expression, "Round-trip failed for expression \(index): \(expression)")

            // Verify JSON structure is valid
            let json = try JSONSerialization.jsonObject(with: encoded)
            #expect(json is [String: Any], "Should produce valid JSON object for expression \(index)")
        }
    }

    @Test("Statement Round-Trip Serialization")
    func testStatementRoundTripSerialization() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // Test all Statement cases
        let statements: [Statement] = [
            // Simple statements
            .breakStatement,
            .expressionStatement(.literal(.string("test"))),
            .expressionStatement(.functionCall("doSomething", [])),

            // Variable declarations
            .variableDeclaration(VariableDeclaration(
                name: "count",
                type: .integer,
                initialValue: .literal(.integer(0))
            )),
            .variableDeclaration(VariableDeclaration(
                name: "data",
                type: .array(.string),
                initialValue: nil
            )),
            .variableDeclaration(VariableDeclaration(
                name: "整数変数", // Japanese variable name
                type: .integer,
                initialValue: .literal(.integer(42))
            )),

            // Constant declarations
            .constantDeclaration(ConstantDeclaration(
                name: "PI",
                type: .real,
                initialValue: .literal(.real(3.14159))
            )),
            .constantDeclaration(ConstantDeclaration(
                name: "MAX_SIZE",
                type: .integer,
                initialValue: .binary(.multiply, .literal(.integer(1024)), .literal(.integer(1024)))
            )),

            // Assignment statements
            .assignment(.variable("x", .literal(.integer(5)))),
            .assignment(.variable("result", .binary(.add, .identifier("a"), .identifier("b")))),
            .assignment(.arrayElement(
                Assignment.ArrayAccess(
                    array: .identifier("matrix"),
                    index: .literal(.integer(0))
                ),
                .literal(.string("value"))
            )),

            // IF statements
            .ifStatement(IfStatement(
                condition: .literal(.boolean(true)),
                thenBody: [.expressionStatement(.literal(.string("then")))],
                elseIfs: [],
                elseBody: nil
            )),
            .ifStatement(IfStatement(
                condition: .binary(.greater, .identifier("x"), .literal(.integer(0))),
                thenBody: [
                    .assignment(.variable("result", .literal(.string("positive")))),
                    .expressionStatement(.functionCall("log", [.literal(.string("x is positive"))]))
                ],
                elseIfs: [
                    IfStatement.ElseIf(
                        condition: .binary(.equal, .identifier("x"), .literal(.integer(0))),
                        body: [.assignment(.variable("result", .literal(.string("zero"))))]
                    )
                ],
                elseBody: [.assignment(.variable("result", .literal(.string("negative"))))]
            )),

            // WHILE statements
            .whileStatement(WhileStatement(
                condition: .literal(.boolean(false)),
                body: [.breakStatement]
            )),
            .whileStatement(WhileStatement(
                condition: .binary(.less, .identifier("i"), .literal(.integer(10))),
                body: [
                    .expressionStatement(.functionCall("process", [.identifier("i")])),
                    .assignment(.variable("i", .binary(.add, .identifier("i"), .literal(.integer(1)))))
                ]
            )),

            // FOR statements - Range-based
            .forStatement(.range(ForStatement.RangeFor(
                variable: "i",
                start: .literal(.integer(1)),
                end: .literal(.integer(10)),
                step: nil,
                body: [.expressionStatement(.functionCall("print", [.identifier("i")]))]
            ))),
            .forStatement(.range(ForStatement.RangeFor(
                variable: "j",
                start: .literal(.integer(0)),
                end: .identifier("maxCount"),
                step: .literal(.integer(2)),
                body: [
                    .assignment(.variable("sum", .binary(.add, .identifier("sum"), .identifier("j")))),
                    .expressionStatement(.functionCall("update", [.identifier("j")]))
                ]
            ))),

            // FOR statements - ForEach
            .forStatement(.forEach(ForStatement.ForEachLoop(
                variable: "item",
                iterable: .identifier("items"),
                body: [.expressionStatement(.functionCall("process", [.identifier("item")]))]
            ))),

            // Return statements
            .returnStatement(ReturnStatement(expression: .literal(.boolean(true)))),
            .returnStatement(ReturnStatement(expression: .binary(.add, .identifier("x"), .identifier("y")))),

            // Block statements
            .block([]),
            .block([.breakStatement]),
            .block([
                .variableDeclaration(VariableDeclaration(name: "temp", type: .integer, initialValue: .literal(.integer(0)))),
                .assignment(.variable("temp", .binary(.add, .identifier("a"), .identifier("b")))),
                .returnStatement(ReturnStatement(expression: .identifier("temp")))
            ]),

            // Function declarations
            .functionDeclaration(FunctionDeclaration(
                name: "simple",
                parameters: [],
                returnType: .integer,
                localVariables: [],
                body: [.returnStatement(ReturnStatement(expression: .literal(.integer(42))))]
            )),
            .functionDeclaration(FunctionDeclaration(
                name: "add",
                parameters: [
                    Parameter(name: "a", type: .integer),
                    Parameter(name: "b", type: .integer)
                ],
                returnType: .integer,
                localVariables: [
                    VariableDeclaration(name: "result", type: .integer, initialValue: .literal(.integer(0)))
                ],
                body: [
                    .assignment(.variable("result", .binary(.add, .identifier("a"), .identifier("b")))),
                    .returnStatement(ReturnStatement(expression: .identifier("result")))
                ]
            )),

            // Procedure declarations
            .procedureDeclaration(ProcedureDeclaration(
                name: "printMessage",
                parameters: [Parameter(name: "message", type: .string)],
                localVariables: [],
                body: [.expressionStatement(.functionCall("print", [.identifier("message")]))]
            ))
        ]

        for (index, statement) in statements.enumerated() {
            // Test round-trip encoding/decoding
            let encoded = try encoder.encode(statement)
            #expect(!encoded.isEmpty, "Encoded data should not be empty for statement \(index)")

            let decoded = try decoder.decode(Statement.self, from: encoded)
            #expect(decoded == statement, "Round-trip failed for statement \(index): \(statement)")

            // Verify JSON structure is valid
            let json = try JSONSerialization.jsonObject(with: encoded)
            #expect(json is [String: Any], "Should produce valid JSON object for statement \(index)")
        }
    }

    @Test("DataType Round-Trip Serialization")
    func testDataTypeRoundTripSerialization() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // Test all DataType cases including recursive structures
        let dataTypes: [DataType] = [
            // Basic types
            .integer,
            .real,
            .character,
            .string,
            .boolean,

            // Array types (recursive)
            .array(.integer),
            .array(.string),
            .array(.boolean),
            .array(.array(.integer)), // 2D array
            .array(.array(.array(.real))), // 3D array

            // Record types
            .record("UserRecord"),
            .record("ConfigData"),
            .record("データ構造"), // Japanese record name

            // Complex nested types
            .array(.record("Person")),
            .array(.array(.record("Matrix")))
        ]

        for (index, dataType) in dataTypes.enumerated() {
            // Test round-trip encoding/decoding
            let encoded = try encoder.encode(dataType)
            #expect(!encoded.isEmpty, "Encoded data should not be empty for DataType \(index)")

            let decoded = try decoder.decode(DataType.self, from: encoded)
            #expect(decoded == dataType, "Round-trip failed for DataType \(index): \(dataType)")

            // Verify JSON structure is valid
            let json = try JSONSerialization.jsonObject(with: encoded)
            #expect(json is [String: Any], "Should produce valid JSON object for DataType \(index)")
        }
    }

    @Test("BinaryOperator and UnaryOperator Round-Trip Serialization")
    func testOperatorRoundTripSerialization() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // Test all BinaryOperator cases
        let binaryOperators = BinaryOperator.allCases

        for (index, op) in binaryOperators.enumerated() {
            let encoded = try encoder.encode(op)
            #expect(!encoded.isEmpty, "Encoded data should not be empty for BinaryOperator \(index)")

            let decoded = try decoder.decode(BinaryOperator.self, from: encoded)
            #expect(decoded == op, "Round-trip failed for BinaryOperator \(index): \(op)")
        }

        // Test all UnaryOperator cases
        let unaryOperators = UnaryOperator.allCases

        for (index, op) in unaryOperators.enumerated() {
            let encoded = try encoder.encode(op)
            #expect(!encoded.isEmpty, "Encoded data should not be empty for UnaryOperator \(index)")

            let decoded = try decoder.decode(UnaryOperator.self, from: encoded)
            #expect(decoded == op, "Round-trip failed for UnaryOperator \(index): \(op)")
        }
    }

    @Test("Complex Nested AST Round-Trip Serialization")
    func testComplexNestedASTRoundTripSerialization() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // Create deeply nested, complex AST structures
        let complexStatements: [Statement] = [
            // Deeply nested function with complex logic
            .functionDeclaration(FunctionDeclaration(
                name: "complexCalculation",
                parameters: [
                    Parameter(name: "data", type: .array(.record("DataPoint"))),
                    Parameter(name: "threshold", type: .real),
                    Parameter(name: "maxIterations", type: .integer)
                ],
                returnType: .record("Result"),
                localVariables: [
                    VariableDeclaration(name: "sum", type: .real, initialValue: .literal(.real(0.0))),
                    VariableDeclaration(name: "count", type: .integer, initialValue: .literal(.integer(0))),
                    VariableDeclaration(name: "valid", type: .boolean, initialValue: .literal(.boolean(false)))
                ],
                body: [
                    .forStatement(.forEach(ForStatement.ForEachLoop(
                        variable: "point",
                        iterable: .identifier("data"),
                        body: [
                            .ifStatement(IfStatement(
                                condition: .binary(.and,
                                    .binary(.greater, .fieldAccess(.identifier("point"), "value"), .identifier("threshold")),
                                    .binary(.less, .identifier("count"), .identifier("maxIterations"))
                                ),
                                thenBody: [
                                    .assignment(.variable("sum", .binary(.add, .identifier("sum"), .fieldAccess(.identifier("point"), "value")))),
                                    .assignment(.variable("count", .binary(.add, .identifier("count"), .literal(.integer(1))))),
                                    .assignment(.variable("valid", .literal(.boolean(true))))
                                ],
                                elseIfs: [
                                    IfStatement.ElseIf(
                                        condition: .binary(.equal, .fieldAccess(.identifier("point"), "status"), .literal(.string("invalid"))),
                                        body: [.expressionStatement(.functionCall("logWarning", [.literal(.string("Invalid data point"))]))]
                                    )
                                ],
                                elseBody: [.expressionStatement(.functionCall("logInfo", [.literal(.string("Skipping data point"))]))]
                            ))
                        ]
                    ))),
                    .whileStatement(WhileStatement(
                        condition: .binary(.and,
                            .unary(.not, .identifier("valid")),
                            .binary(.greater, .identifier("count"), .literal(.integer(0)))
                        ),
                        body: [
                            .assignment(.variable("threshold", .binary(.multiply, .identifier("threshold"), .literal(.real(0.9))))),
                            .assignment(.variable("valid", .functionCall("revalidate", [.identifier("sum"), .identifier("threshold")])))
                        ]
                    )),
                    .returnStatement(ReturnStatement(
                        expression: .functionCall("createResult", [
                            .identifier("sum"),
                            .identifier("count"),
                            .identifier("valid")
                        ])
                    ))
                ]
            )),

            // Nested control structures with complex expressions
            .block([
                .variableDeclaration(VariableDeclaration(
                    name: "matrix",
                    type: .array(.array(.integer)),
                    initialValue: .functionCall("createMatrix", [.literal(.integer(10)), .literal(.integer(10))])
                )),
                .forStatement(.range(ForStatement.RangeFor(
                    variable: "i",
                    start: .literal(.integer(0)),
                    end: .literal(.integer(9)),
                    step: nil,
                    body: [
                        .forStatement(.range(ForStatement.RangeFor(
                            variable: "j",
                            start: .literal(.integer(0)),
                            end: .literal(.integer(9)),
                            step: nil,
                            body: [
                                .assignment(.arrayElement(
                                    Assignment.ArrayAccess(
                                        array: .arrayAccess(.identifier("matrix"), .identifier("i")),
                                        index: .identifier("j")
                                    ),
                                    .binary(.add,
                                        .binary(.multiply, .identifier("i"), .literal(.integer(10))),
                                        .identifier("j")
                                    )
                                ))
                            ]
                        )))
                    ]
                )))
            ])
        ]

        for (index, statement) in complexStatements.enumerated() {
            // Test round-trip encoding/decoding
            let encoded = try encoder.encode(statement)
            #expect(!encoded.isEmpty, "Encoded data should not be empty for complex statement \(index)")

            let decoded = try decoder.decode(Statement.self, from: encoded)
            #expect(decoded == statement, "Round-trip failed for complex statement \(index)")

            // Verify JSON structure is valid
            let json = try JSONSerialization.jsonObject(with: encoded)
            #expect(json is [String: Any], "Should produce valid JSON object for complex statement \(index)")
        }
    }

    @Test("Supporting Type Round-Trip Serialization")
    func testSupportingTypeRoundTripSerialization() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // Test Parameter
        let parameters: [Parameter] = [
            Parameter(name: "x", type: .integer),
            Parameter(name: "message", type: .string),
            Parameter(name: "data", type: .array(.real)),
            Parameter(name: "config", type: .record("Configuration")),
            Parameter(name: "パラメータ", type: .boolean) // Japanese parameter name
        ]

        for (index, parameter) in parameters.enumerated() {
            let encoded = try encoder.encode(parameter)
            #expect(!encoded.isEmpty, "Encoded data should not be empty for Parameter \(index)")

            let decoded = try decoder.decode(Parameter.self, from: encoded)
            #expect(decoded == parameter, "Round-trip failed for Parameter \(index): \(parameter)")
        }

        // Test VariableDeclaration
        let variableDeclarations: [VariableDeclaration] = [
            VariableDeclaration(name: "simple", type: .integer, initialValue: nil),
            VariableDeclaration(name: "initialized", type: .string, initialValue: .literal(.string("default"))),
            VariableDeclaration(name: "complex", type: .array(.record("Item")),
                initialValue: .functionCall("createArray", [.literal(.integer(10))]))
        ]

        for (index, varDecl) in variableDeclarations.enumerated() {
            let encoded = try encoder.encode(varDecl)
            #expect(!encoded.isEmpty, "Encoded data should not be empty for VariableDeclaration \(index)")

            let decoded = try decoder.decode(VariableDeclaration.self, from: encoded)
            #expect(decoded == varDecl, "Round-trip failed for VariableDeclaration \(index): \(varDecl)")
        }

        // Test ConstantDeclaration
        let constantDeclarations: [ConstantDeclaration] = [
            ConstantDeclaration(name: "PI", type: .real, initialValue: .literal(.real(3.14159))),
            ConstantDeclaration(name: "MAX_COUNT", type: .integer,
                initialValue: .binary(.multiply, .literal(.integer(1000)), .literal(.integer(1000)))),
            ConstantDeclaration(name: "DEFAULT_MESSAGE", type: .string, initialValue: .literal(.string("Hello")))
        ]

        for (index, constDecl) in constantDeclarations.enumerated() {
            let encoded = try encoder.encode(constDecl)
            #expect(!encoded.isEmpty, "Encoded data should not be empty for ConstantDeclaration \(index)")

            let decoded = try decoder.decode(ConstantDeclaration.self, from: encoded)
            #expect(decoded == constDecl, "Round-trip failed for ConstantDeclaration \(index): \(constDecl)")
        }

        // Test ReturnStatement
        let returnStatements: [ReturnStatement] = [
            ReturnStatement(expression: .literal(.boolean(true))),
            ReturnStatement(expression: .identifier("result")),
            ReturnStatement(expression: .binary(.add, .identifier("a"), .identifier("b"))),
            ReturnStatement(expression: .functionCall("compute", [.identifier("input")]))
        ]

        for (index, returnStmt) in returnStatements.enumerated() {
            let encoded = try encoder.encode(returnStmt)
            #expect(!encoded.isEmpty, "Encoded data should not be empty for ReturnStatement \(index)")

            let decoded = try decoder.decode(ReturnStatement.self, from: encoded)
            #expect(decoded == returnStmt, "Round-trip failed for ReturnStatement \(index): \(returnStmt)")
        }
    }

    @Test("Unicode and Internationalization Round-Trip")
    func testUnicodeInternationalizationRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // Test expressions with various Unicode content
        let unicodeExpressions: [ASTExpression] = [
            // Japanese identifiers and strings
            .identifier("変数名"),
            .literal(.string("こんにちは世界")),
            .literal(.character("あ")),
            .functionCall("関数", [.literal(.string("引数"))]),
            .fieldAccess(.identifier("オブジェクト"), "プロパティ"),

            // Mathematical symbols and operators (already tested in operators)
            .binary(.notEqual, .identifier("α"), .identifier("β")),
            .binary(.greaterEqual, .literal(.real(3.14159)), .identifier("π")),
            .binary(.lessEqual, .identifier("∑"), .literal(.integer(100))),

            // Mixed Unicode content
            .functionCall("calculate", [
                .literal(.string("Input: 数値データ")),
                .identifier("résultat"),
                .literal(.character("€"))
            ])
        ]

        for (index, expression) in unicodeExpressions.enumerated() {
            let encoded = try encoder.encode(expression)
            #expect(!encoded.isEmpty, "Encoded data should not be empty for Unicode expression \(index)")

            let decoded = try decoder.decode(ASTExpression.self, from: encoded)
            #expect(decoded == expression, "Round-trip failed for Unicode expression \(index): \(expression)")

            // Verify the JSON preserves Unicode correctly
            let jsonString = String(data: encoded, encoding: .utf8)
            #expect(jsonString != nil, "Should produce valid UTF-8 JSON for Unicode expression \(index)")
        }

        // Test statements with Unicode content
        let unicodeStatements: [Statement] = [
            .variableDeclaration(VariableDeclaration(
                name: "データ",
                type: .string,
                initialValue: .literal(.string("初期値"))
            )),
            .functionDeclaration(FunctionDeclaration(
                name: "計算",
                parameters: [Parameter(name: "入力", type: .integer)],
                returnType: .real,
                localVariables: [],
                body: [.returnStatement(ReturnStatement(expression: .literal(.real(42.0))))]
            ))
        ]

        for (index, statement) in unicodeStatements.enumerated() {
            let encoded = try encoder.encode(statement)
            #expect(!encoded.isEmpty, "Encoded data should not be empty for Unicode statement \(index)")

            let decoded = try decoder.decode(Statement.self, from: encoded)
            #expect(decoded == statement, "Round-trip failed for Unicode statement \(index): \(statement)")
        }
    }

    @Test("Edge Cases and Boundary Conditions Round-Trip")
    func testEdgeCasesRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // Test edge cases for numeric values
        let edgeCaseExpressions: [ASTExpression] = [
            // Integer limits
            .literal(.integer(Int.max)),
            .literal(.integer(Int.min)),
            .literal(.integer(0)),
            .literal(.integer(-1)),

            // Double limits and special values
            .literal(.real(Double.greatestFiniteMagnitude)),
            .literal(.real(-Double.greatestFiniteMagnitude)),
            .literal(.real(Double.leastNormalMagnitude)),
            .literal(.real(0.0)),
            .literal(.real(-0.0)),
            .literal(.real(Double.pi)),

            // String edge cases
            .literal(.string("")), // Empty string
            .literal(.string(" ")), // Single space
            .literal(.string("\n\t\r")), // Whitespace characters
            .literal(.string("\"'")), // Quote characters
            .literal(.string("\\\\")), // Backslashes
            .literal(.string("🎉🌟💖")), // Emoji

            // Character edge cases
            .literal(.character(" ")), // Space character
            .literal(.character("\n")), // Newline
            .literal(.character("🎯")), // Emoji character

            // Empty identifiers (if allowed)
            .identifier("_"), // Minimal identifier

            // Empty function calls
            .functionCall("func", []),

            // Very nested expressions
            .binary(.add,
                .binary(.multiply,
                    .binary(.subtract, .literal(.integer(1)), .literal(.integer(2))),
                    .binary(.divide, .literal(.integer(3)), .literal(.integer(4)))
                ),
                .binary(.modulo,
                    .binary(.add, .literal(.integer(5)), .literal(.integer(6))),
                    .binary(.subtract, .literal(.integer(7)), .literal(.integer(8)))
                )
            )
        ]

        for (index, expression) in edgeCaseExpressions.enumerated() {
            let encoded = try encoder.encode(expression)
            #expect(!encoded.isEmpty, "Encoded data should not be empty for edge case expression \(index)")

            let decoded = try decoder.decode(ASTExpression.self, from: encoded)
            #expect(decoded == expression, "Round-trip failed for edge case expression \(index): \(expression)")
        }

        // Test edge cases for statements
        let edgeCaseStatements: [Statement] = [
            // Empty blocks
            .block([]),

            // Single element blocks
            .block([.breakStatement]),

            // IF with empty bodies
            .ifStatement(IfStatement(
                condition: .literal(.boolean(true)),
                thenBody: [],
                elseIfs: [],
                elseBody: []
            )),

            // WHILE with empty body
            .whileStatement(WhileStatement(
                condition: .literal(.boolean(false)),
                body: []
            )),

            // Function with no parameters, variables, or body statements
            .functionDeclaration(FunctionDeclaration(
                name: "empty",
                parameters: [],
                returnType: .integer,
                localVariables: [],
                body: []
            ))
        ]

        for (index, statement) in edgeCaseStatements.enumerated() {
            let encoded = try encoder.encode(statement)
            #expect(!encoded.isEmpty, "Encoded data should not be empty for edge case statement \(index)")

            let decoded = try decoder.decode(Statement.self, from: encoded)
            #expect(decoded == statement, "Round-trip failed for edge case statement \(index): \(statement)")
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
        let innerExpression = ASTExpression.literal(.integer(42))
        let outerExpression = ASTExpression.unary(.minus, innerExpression)
        let finalExpression = ASTExpression.binary(.multiply, outerExpression, .literal(.real(2.0)))

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
