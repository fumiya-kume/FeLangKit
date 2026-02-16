import XCTest
@testable import FeLangCore

final class ABILoweringTests: XCTestCase {

    // MARK: - TypeTag Tests

    func testTypeTagForPrimitives() {
        XCTAssertEqual(ABILowering.typeTag(for: .integer), .integer)
        XCTAssertEqual(ABILowering.typeTag(for: .real), .real)
        XCTAssertEqual(ABILowering.typeTag(for: .string), .string)
        XCTAssertEqual(ABILowering.typeTag(for: .character), .character)
        XCTAssertEqual(ABILowering.typeTag(for: .boolean), .boolean)
    }

    func testTypeTagForCompoundTypes() {
        XCTAssertEqual(ABILowering.typeTag(for: .array(elementType: .integer, dimensions: [])), .array)
        XCTAssertEqual(ABILowering.typeTag(for: .record(name: "Point", fields: [:])), .record)
    }

    func testTypeTagForNullable() {
        XCTAssertEqual(ABILowering.typeTag(for: .nullable(.integer)), .integer)
        XCTAssertEqual(ABILowering.typeTag(for: .nullable(.string)), .string)
    }

    func testTypeTagForVoidAndUnknown() {
        XCTAssertEqual(ABILowering.typeTag(for: .void), .null)
        XCTAssertEqual(ABILowering.typeTag(for: .unknown), .null)
    }

    // MARK: - Boxing Needs Tests

    func testNeedsBoxingPrimitiveToAny() {
        XCTAssertTrue(ABILowering.needsBoxing(source: .integer, target: .any))
        XCTAssertTrue(ABILowering.needsBoxing(source: .real, target: .any))
        XCTAssertTrue(ABILowering.needsBoxing(source: .string, target: .any))
        XCTAssertTrue(ABILowering.needsBoxing(source: .boolean, target: .any))
    }

    func testNeedsBoxingPrimitiveToNullable() {
        XCTAssertTrue(ABILowering.needsBoxing(source: .integer, target: .nullable(.integer)))
        XCTAssertTrue(ABILowering.needsBoxing(source: .string, target: .nullable(.string)))
    }

    func testNoBoxingSameType() {
        XCTAssertFalse(ABILowering.needsBoxing(source: .integer, target: .integer))
        XCTAssertFalse(ABILowering.needsBoxing(source: .string, target: .string))
    }

    // MARK: - Unboxing Needs Tests

    func testNeedsUnboxingAnyToPrimitive() {
        XCTAssertTrue(ABILowering.needsUnboxing(source: .any, target: .integer))
        XCTAssertTrue(ABILowering.needsUnboxing(source: .any, target: .real))
        XCTAssertTrue(ABILowering.needsUnboxing(source: .any, target: .string))
        XCTAssertTrue(ABILowering.needsUnboxing(source: .any, target: .boolean))
    }

    func testNeedsUnboxingNullableToPrimitive() {
        XCTAssertTrue(ABILowering.needsUnboxing(source: .nullable(.integer), target: .integer))
        XCTAssertTrue(ABILowering.needsUnboxing(source: .nullable(.string), target: .string))
    }

    func testNoUnboxingSameType() {
        XCTAssertFalse(ABILowering.needsUnboxing(source: .integer, target: .integer))
        XCTAssertFalse(ABILowering.needsUnboxing(source: .string, target: .string))
    }

    func testNoUnboxingAnyToAny() {
        XCTAssertFalse(ABILowering.needsUnboxing(source: .any, target: .any))
    }

    func testNoUnboxingAnyToNullable() {
        XCTAssertFalse(ABILowering.needsUnboxing(source: .any, target: .nullable(.integer)))
    }

    // MARK: - Analyze Statements Tests

    func testAnalyzeEmptyStatements() {
        let lowering = ABILowering()
        let result = lowering.analyze([])
        XCTAssertFalse(result.requiresBoxing)
        XCTAssertTrue(result.boundaries.isEmpty)
    }

    func testAnalyzeNullableVariableDeclaration() {
        let lowering = ABILowering()
        let statements: [Statement] = [
            .variableDeclaration(VariableDeclaration(
                name: "x",
                type: .nullable(.integer),
                initialValue: nil,
                position: SourcePosition(line: 1, column: 1, offset: 0)
            ))
        ]
        let result = lowering.analyze(statements)
        XCTAssertTrue(result.requiresBoxing)
        XCTAssertEqual(result.boundaries.count, 1)
        if case .box(let sourceType) = result.boundaries[0].kind {
            XCTAssertEqual(sourceType, .integer)
        } else {
            XCTFail("Expected box boundary")
        }
    }

    func testAnalyzeAnyVariableDeclaration() {
        let lowering = ABILowering()
        let statements: [Statement] = [
            .variableDeclaration(VariableDeclaration(
                name: "x",
                type: .any,
                initialValue: nil,
                position: SourcePosition(line: 1, column: 1, offset: 0)
            ))
        ]
        let result = lowering.analyze(statements)
        XCTAssertTrue(result.requiresBoxing)
        XCTAssertEqual(result.boundaries.count, 1)
    }

    func testAnalyzePlainVariableDeclaration() {
        let lowering = ABILowering()
        let statements: [Statement] = [
            .variableDeclaration(VariableDeclaration(
                name: "x",
                type: .integer,
                initialValue: nil,
                position: SourcePosition(line: 1, column: 1, offset: 0)
            ))
        ]
        let result = lowering.analyze(statements)
        XCTAssertFalse(result.requiresBoxing)
        XCTAssertTrue(result.boundaries.isEmpty)
    }

    func testAnalyzeFunctionWithNullableParameter() {
        let lowering = ABILowering()
        let statements: [Statement] = [
            .functionDeclaration(FunctionDeclaration(
                name: "test",
                parameters: [Parameter(name: "x", type: .nullable(.integer))],
                returnType: .integer,
                localVariables: [],
                body: [
                    .returnStatement(ReturnStatement(expression: .literal(.integer(0))))
                ],
                position: SourcePosition(line: 1, column: 1, offset: 0)
            ))
        ]
        let result = lowering.analyze(statements)
        XCTAssertTrue(result.requiresBoxing)
        XCTAssertGreaterThanOrEqual(result.boundaries.count, 1)
    }

    func testAnalyzeFunctionWithAnyReturnType() {
        let lowering = ABILowering()
        let statements: [Statement] = [
            .functionDeclaration(FunctionDeclaration(
                name: "test",
                parameters: [],
                returnType: .any,
                localVariables: [],
                body: [
                    .returnStatement(ReturnStatement(expression: .literal(.integer(0))))
                ],
                position: SourcePosition(line: 1, column: 1, offset: 0)
            ))
        ]
        let result = lowering.analyze(statements)
        XCTAssertTrue(result.requiresBoxing)
    }

    // MARK: - BoxingOperations Tests

    func testBoxDescription() {
        let desc = BoxingOperations.boxDescription(value: "42", sourceType: .integer)
        XCTAssertTrue(desc.contains("box"))
        XCTAssertTrue(desc.contains("42"))
    }

    func testUnboxDescription() {
        let desc = BoxingOperations.unboxDescription(value: "boxed", targetType: .integer)
        XCTAssertTrue(desc.contains("unbox"))
        XCTAssertTrue(desc.contains("boxed"))
    }

    // MARK: - FeType Nullable/Any Tests

    func testFeTypeNullableDescription() {
        let type = FeType.nullable(.integer)
        XCTAssertEqual(type.description, "integer?")
    }

    func testFeTypeAnyDescription() {
        let type = FeType.any
        XCTAssertEqual(type.description, "Any")
    }

    func testFeTypeNullableIsNullable() {
        XCTAssertTrue(FeType.nullable(.integer).isNullable)
        XCTAssertTrue(FeType.any.isNullable)
        XCTAssertFalse(FeType.integer.isNullable)
    }

    func testFeTypeUnwrappedType() {
        XCTAssertEqual(FeType.nullable(.integer).unwrappedType, .integer)
        XCTAssertEqual(FeType.integer.unwrappedType, .integer)
    }

    func testFeTypeAnyCompatibility() {
        XCTAssertTrue(FeType.any.isCompatible(with: .integer))
        XCTAssertTrue(FeType.any.isCompatible(with: .string))
        XCTAssertTrue(FeType.integer.isCompatible(with: .any))
    }

    func testFeTypeNullableCompatibility() {
        XCTAssertTrue(FeType.nullable(.integer).isCompatible(with: .nullable(.integer)))
        XCTAssertTrue(FeType.integer.isCompatible(with: .nullable(.integer)))
        XCTAssertTrue(FeType.nullable(.integer).isCompatible(with: .integer))
    }

    func testFeTypeCanAssignToAny() {
        XCTAssertTrue(FeType.integer.canAssignTo(.any))
        XCTAssertTrue(FeType.string.canAssignTo(.any))
        XCTAssertTrue(FeType.boolean.canAssignTo(.any))
    }

    func testFeTypeCanAssignToNullable() {
        XCTAssertTrue(FeType.integer.canAssignTo(.nullable(.integer)))
        XCTAssertTrue(FeType.string.canAssignTo(.nullable(.string)))
    }

    func testFeTypeNullableCanAssignToInner() {
        XCTAssertTrue(FeType.nullable(.integer).canAssignTo(.integer))
    }

    // MARK: - DataType Nullable/Any Tests

    func testDataTypeNullableEquality() {
        XCTAssertEqual(DataType.nullable(.integer), DataType.nullable(.integer))
        XCTAssertNotEqual(DataType.nullable(.integer), DataType.nullable(.string))
    }

    func testDataTypeAnyEquality() {
        XCTAssertEqual(DataType.any, DataType.any)
        XCTAssertNotEqual(DataType.any, DataType.integer)
    }
}
