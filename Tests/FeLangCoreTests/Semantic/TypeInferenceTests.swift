import XCTest
@testable import FeLangCore

final class TypeInferenceTests: XCTestCase {
    var analyzer: SemanticAnalyzer!

    override func setUp() {
        super.setUp()
        analyzer = SemanticAnalyzer()
    }

    override func tearDown() {
        analyzer = nil
        super.tearDown()
    }

    // MARK: - Binary Operator Type Inference Tests

    func testArithmeticOperatorTypePromotion() {
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "integerResult",
                type: .integer,
                initialValue: .binary(.add, .literal(.integer(5)), .literal(.integer(3)))
            )),
            Statement.variableDeclaration(VariableDeclaration(
                name: "realResult",
                type: .real,
                initialValue: .binary(.multiply, .literal(.integer(5)), .literal(.real(3.5)))
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testModuloOperatorTypeRestriction() {
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "validModulo",
                type: .integer,
                initialValue: .binary(.modulo, .literal(.integer(10)), .literal(.integer(3)))
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testModuloOperatorWithInvalidTypes() {
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "invalidModulo",
                type: .real,
                initialValue: .binary(.modulo, .literal(.real(10.5)), .literal(.real(3.2)))
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 1)

        if case .incompatibleTypes(let left, let right, let operation, _) = result.errors[0] {
            XCTAssertEqual(left, .real)
            XCTAssertEqual(right, .real)
            XCTAssertEqual(operation, "modulo")
        } else {
            XCTFail("Expected incompatible types error for modulo")
        }
    }

    func testStringConcatenationWithMixedTypes() {
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "stringCharConcat",
                type: .string,
                initialValue: .binary(.add, .literal(.string("Hello")), .literal(.character("!")))
            )),
            Statement.variableDeclaration(VariableDeclaration(
                name: "charStringConcat",
                type: .string,
                initialValue: .binary(.add, .literal(.character("A")), .literal(.string("BC")))
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testInvalidStringConcatenation() {
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "invalidConcat",
                type: .string,
                initialValue: .binary(.add, .literal(.string("Hello")), .literal(.integer(42)))
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 1)

        if case .incompatibleTypes(let left, let right, let operation, _) = result.errors[0] {
            XCTAssertEqual(left, .string)
            XCTAssertEqual(right, .integer)
            XCTAssertEqual(operation, "add")
        } else {
            XCTFail("Expected incompatible types error for string concatenation")
        }
    }

    func testEqualityOperatorWithCompatibleTypes() {
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "intComparison",
                type: .boolean,
                initialValue: .binary(.equal, .literal(.integer(5)), .literal(.integer(5)))
            )),
            Statement.variableDeclaration(VariableDeclaration(
                name: "numericComparison",
                type: .boolean,
                initialValue: .binary(.equal, .literal(.integer(5)), .literal(.real(5.0)))
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testEqualityOperatorWithIncompatibleTypes() {
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "invalidComparison",
                type: .boolean,
                initialValue: .binary(.equal, .literal(.string("hello")), .literal(.integer(42)))
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 1)

        if case .incompatibleTypes(let left, let right, let operation, _) = result.errors[0] {
            XCTAssertEqual(left, .string)
            XCTAssertEqual(right, .integer)
            XCTAssertEqual(operation, "equal")
        } else {
            XCTFail("Expected incompatible types error for equality")
        }
    }

    func testComparisonOperatorWithNumericTypes() {
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "intComparison",
                type: .boolean,
                initialValue: .binary(.greater, .literal(.integer(10)), .literal(.integer(5)))
            )),
            Statement.variableDeclaration(VariableDeclaration(
                name: "mixedComparison",
                type: .boolean,
                initialValue: .binary(.lessEqual, .literal(.real(3.14)), .literal(.integer(4)))
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testComparisonOperatorWithNonNumericTypes() {
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "invalidComparison",
                type: .boolean,
                initialValue: .binary(.greater, .literal(.string("abc")), .literal(.string("def")))
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 1)

        if case .incompatibleTypes(let left, let right, let operation, _) = result.errors[0] {
            XCTAssertEqual(left, .string)
            XCTAssertEqual(right, .string)
            XCTAssertEqual(operation, "greater")
        } else {
            XCTFail("Expected incompatible types error for comparison")
        }
    }

    func testLogicalOperatorWithBooleanTypes() {
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "logicalAnd",
                type: .boolean,
                initialValue: .binary(.and, .literal(.boolean(true)), .literal(.boolean(false)))
            )),
            Statement.variableDeclaration(VariableDeclaration(
                name: "logicalOr",
                type: .boolean,
                initialValue: .binary(.or, .literal(.boolean(false)), .literal(.boolean(true)))
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testLogicalOperatorWithNonBooleanTypes() {
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "invalidLogical",
                type: .boolean,
                initialValue: .binary(.and, .literal(.integer(1)), .literal(.integer(0)))
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 1)

        if case .incompatibleTypes(let left, let right, let operation, _) = result.errors[0] {
            XCTAssertEqual(left, .integer)
            XCTAssertEqual(right, .integer)
            XCTAssertEqual(operation, "and")
        } else {
            XCTFail("Expected incompatible types error for logical operation")
        }
    }

    // MARK: - Unary Operator Type Inference Tests

    func testUnaryNotOperatorWithBoolean() {
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "negatedBoolean",
                type: .boolean,
                initialValue: .unary(.not, .literal(.boolean(true)))
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testUnaryNotOperatorWithNonBoolean() {
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "invalidNot",
                type: .boolean,
                initialValue: .unary(.not, .literal(.integer(1)))
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 1)

        if case .typeMismatch(let expected, let actual, _) = result.errors[0] {
            XCTAssertEqual(expected, .boolean)
            XCTAssertEqual(actual, .integer)
        } else {
            XCTFail("Expected type mismatch error for unary not")
        }
    }

    func testUnaryArithmeticOperators() {
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "positiveInt",
                type: .integer,
                initialValue: .unary(.plus, .literal(.integer(42)))
            )),
            Statement.variableDeclaration(VariableDeclaration(
                name: "negativeInt",
                type: .integer,
                initialValue: .unary(.minus, .literal(.integer(42)))
            )),
            Statement.variableDeclaration(VariableDeclaration(
                name: "positiveReal",
                type: .real,
                initialValue: .unary(.plus, .literal(.real(3.14)))
            )),
            Statement.variableDeclaration(VariableDeclaration(
                name: "negativeReal",
                type: .real,
                initialValue: .unary(.minus, .literal(.real(3.14)))
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testUnaryArithmeticOperatorWithInvalidType() {
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "invalidUnary",
                type: .real,
                initialValue: .unary(.minus, .literal(.string("hello")))
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 1)

        if case .typeMismatch(let expected, let actual, _) = result.errors[0] {
            XCTAssertEqual(expected, .real)
            XCTAssertEqual(actual, .string)
        } else {
            XCTFail("Expected type mismatch error for unary arithmetic")
        }
    }

    // MARK: - Array Access Type Inference Tests

    func testArrayAccessWithIntegerIndex() {
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "intArray",
                type: .array(.integer),
                initialValue: nil
            )),
            Statement.variableDeclaration(VariableDeclaration(
                name: "element",
                type: .integer,
                initialValue: .arrayAccess(.identifier("intArray"), .literal(.integer(0)))
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testArrayAccessWithNonIntegerIndex() {
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "intArray",
                type: .array(.integer),
                initialValue: nil
            )),
            Statement.variableDeclaration(VariableDeclaration(
                name: "element",
                type: .integer,
                initialValue: .arrayAccess(.identifier("intArray"), .literal(.string("0")))
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 1)

        if case .arrayIndexTypeMismatch(let expected, let actual, _) = result.errors[0] {
            XCTAssertEqual(expected, .integer)
            XCTAssertEqual(actual, .string)
        } else {
            XCTFail("Expected array index type mismatch error")
        }
    }

    func testStringAccessAsCharacterArray() {
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "text",
                type: .string,
                initialValue: .literal(.string("Hello"))
            )),
            Statement.variableDeclaration(VariableDeclaration(
                name: "firstChar",
                type: .character,
                initialValue: .arrayAccess(.identifier("text"), .literal(.integer(0)))
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testArrayAccessOnNonArrayType() {
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "number",
                type: .integer,
                initialValue: .literal(.integer(42))
            )),
            Statement.variableDeclaration(VariableDeclaration(
                name: "invalid",
                type: .integer,
                initialValue: .arrayAccess(.identifier("number"), .literal(.integer(0)))
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 1)

        if case .invalidArrayAccess = result.errors[0] {
            // Expected
        } else {
            XCTFail("Expected invalid array access error")
        }
    }

    // MARK: - Field Access Type Inference Tests

    func testFieldAccessOnNonRecordType() {
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "number",
                type: .integer,
                initialValue: .literal(.integer(42))
            )),
            Statement.variableDeclaration(VariableDeclaration(
                name: "invalid",
                type: .integer,
                initialValue: .fieldAccess(.identifier("number"), "field")
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 1)

        if case .invalidFieldAccess = result.errors[0] {
            // Expected
        } else {
            XCTFail("Expected invalid field access error")
        }
    }

    // MARK: - Complex Type Inference Tests

    func testNestedExpressionTypeInference() {
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "a",
                type: .integer,
                initialValue: .literal(.integer(10))
            )),
            Statement.variableDeclaration(VariableDeclaration(
                name: "b",
                type: .real,
                initialValue: .literal(.real(2.5))
            )),
            Statement.variableDeclaration(VariableDeclaration(
                name: "complex",
                type: .real,
                initialValue: .binary(.multiply,
                    .binary(.add, .identifier("a"), .literal(.integer(5))),
                    .binary(.divide, .identifier("b"), .literal(.real(1.25)))
                )
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testTypeInferenceWithFunctionCalls() {
        let statements = [
            Statement.functionDeclaration(FunctionDeclaration(
                name: "square",
                parameters: [Parameter(name: "x", type: .real)],
                returnType: .real,
                localVariables: [],
                body: [
                    Statement.returnStatement(ReturnStatement(
                        expression: .binary(.multiply, .identifier("x"), .identifier("x"))
                    ))
                ]
            )),
            Statement.variableDeclaration(VariableDeclaration(
                name: "result",
                type: .real,
                initialValue: .binary(.add,
                    .functionCall("square", [.literal(.real(3.0))]),
                    .functionCall("square", [.literal(.real(4.0))])
                )
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testMixedTypeArithmeticWithVariables() {
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "intVar",
                type: .integer,
                initialValue: .literal(.integer(5))
            )),
            Statement.variableDeclaration(VariableDeclaration(
                name: "realVar",
                type: .real,
                initialValue: .literal(.real(3.14))
            )),
            Statement.variableDeclaration(VariableDeclaration(
                name: "result",
                type: .real,
                initialValue: .binary(.multiply, .identifier("intVar"), .identifier("realVar"))
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }
}
