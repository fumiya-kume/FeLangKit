import XCTest
@testable import FeLangCore

final class SemanticErrorGoldenTests: XCTestCase {

    // MARK: - Golden File Test Cases

    func testTypeMismatchBasic() {
        let error = SemanticError.typeMismatch(
            expected: .integer,
            actual: .string,
            at: SourcePosition(line: 1, column: 5, offset: 4)
        )

        let formatted = SemanticErrorFormatter.format(error)
        let expected = """
            SemanticError: Type mismatch: expected 'integer', got 'string'
              at line 1, column 5
            """

        XCTAssertEqual(formatted, expected, "Type mismatch formatting should match golden file")
    }

    func testUndeclaredVariable() {
        let error = SemanticError.undeclaredVariable(
            "count",
            at: SourcePosition(line: 2, column: 10, offset: 25)
        )

        let formatted = SemanticErrorFormatter.format(error)
        let expected = """
            SemanticError: Symbol 'count' not found
              at line 2, column 10
              Variable must be declared before use
            """

        XCTAssertEqual(formatted, expected, "Undeclared variable formatting should match golden file")
    }

    func testFunctionArgumentCountMismatch() {
        let error = SemanticError.incorrectArgumentCount(
            function: "calculateSum",
            expected: 2,
            actual: 3,
            at: SourcePosition(line: 3, column: 1, offset: 50)
        )

        let formatted = SemanticErrorFormatter.format(error)
        let expected = """
            SemanticError: Incorrect argument count for function 'calculateSum'
              Function: 'calculateSum'
              Expected: 2 arguments
              Actual: 3 arguments
              Position: line 3, column 1
            """

        XCTAssertEqual(formatted, expected, "Function argument count mismatch formatting should match golden file")
    }

    func testFunctionArgumentTypeMismatch() {
        let error = SemanticError.argumentTypeMismatch(
            function: "pow",
            paramIndex: 1,
            expected: .real,
            actual: .string,
            at: SourcePosition(line: 4, column: 8, offset: 75)
        )

        let formatted = SemanticErrorFormatter.format(error)
        let expected = """
            SemanticError: Argument type mismatch in function 'pow'
              Parameter: #2
              Expected: real
              Actual: string
              Position: line 4, column 8
            """

        XCTAssertEqual(formatted, expected, "Function argument type mismatch formatting should match golden file")
    }

    func testIncompatibleTypesOperation() {
        let error = SemanticError.incompatibleTypes(
            .boolean,
            .integer,
            operation: "addition",
            at: SourcePosition(line: 5, column: 15, offset: 100)
        )

        let formatted = SemanticErrorFormatter.format(error)
        let expected = """
            SemanticError: Incompatible types in addition
              Left type: boolean
              Right type: integer
              Position: line 5, column 15
            """

        XCTAssertEqual(formatted, expected, "Incompatible types operation formatting should match golden file")
    }

    func testVariableAlreadyDeclared() {
        let error = SemanticError.variableAlreadyDeclared(
            "result",
            at: SourcePosition(line: 6, column: 5, offset: 125)
        )

        let formatted = SemanticErrorFormatter.format(error)
        let expected = """
            SemanticError: Variable 'result' already declared
              at line 6, column 5
            """

        XCTAssertEqual(formatted, expected, "Variable already declared formatting should match golden file")
    }

    func testFunctionAlreadyDeclared() {
        let error = SemanticError.functionAlreadyDeclared(
            "factorial",
            at: SourcePosition(line: 7, column: 1, offset: 150)
        )

        let formatted = SemanticErrorFormatter.format(error)
        let expected = """
            SemanticError: Function 'factorial' already declared
              at line 7, column 1
            """

        XCTAssertEqual(formatted, expected, "Function already declared formatting should match golden file")
    }

    func testReturnTypeMismatch() {
        let error = SemanticError.returnTypeMismatch(
            function: "getValue",
            expected: .integer,
            actual: .string,
            at: SourcePosition(line: 8, column: 12, offset: 175)
        )

        let formatted = SemanticErrorFormatter.format(error)
        let expected = """
            SemanticError: Return type mismatch in function 'getValue'
              Expected: integer
              Actual: string
              Position: line 8, column 12
            """

        XCTAssertEqual(formatted, expected, "Return type mismatch formatting should match golden file")
    }

    func testCyclicDependency() {
        let error = SemanticError.cyclicDependency(
            ["varA", "varB", "varC", "varA"],
            at: SourcePosition(line: 9, column: 1, offset: 200)
        )

        let formatted = SemanticErrorFormatter.format(error)
        let expected = """
            SemanticError: Cyclic dependency detected
              Chain: varA -> varB -> varC -> varA at line 9, column 1
            """

        XCTAssertEqual(formatted, expected, "Cyclic dependency formatting should match golden file")
    }

    func testConstantReassignment() {
        let error = SemanticError.constantReassignment(
            "PI",
            at: SourcePosition(line: 10, column: 1, offset: 225)
        )

        let formatted = SemanticErrorFormatter.format(error)
        let expected = """
            SemanticError: Cannot reassign constant 'PI'
              at line 10, column 1
            """

        XCTAssertEqual(formatted, expected, "Constant reassignment formatting should match golden file")
    }

    func testArrayIndexTypeMismatch() {
        let error = SemanticError.arrayIndexTypeMismatch(
            expected: .integer,
            actual: .string,
            at: SourcePosition(line: 11, column: 8, offset: 250)
        )

        let formatted = SemanticErrorFormatter.format(error)
        let expected = """
            SemanticError: Array index type mismatch: expected 'integer', got 'string'
              at line 11, column 8
            """

        XCTAssertEqual(formatted, expected, "Array index type mismatch formatting should match golden file")
    }

    func testUndeclaredField() {
        let error = SemanticError.undeclaredField(
            fieldName: "width",
            recordType: "Rectangle",
            at: SourcePosition(line: 12, column: 10, offset: 275)
        )

        let formatted = SemanticErrorFormatter.format(error)
        let expected = """
            SemanticError: Undeclared field 'width' in record 'Rectangle'
              at line 12, column 10
            """

        XCTAssertEqual(formatted, expected, "Undeclared field formatting should match golden file")
    }

    func testBreakOutsideLoop() {
        let error = SemanticError.breakOutsideLoop(
            at: SourcePosition(line: 13, column: 5, offset: 300)
        )

        let formatted = SemanticErrorFormatter.format(error)
        let expected = """
            SemanticError: Break statement outside loop
              at line 13, column 5
            """

        XCTAssertEqual(formatted, expected, "Break outside loop formatting should match golden file")
    }

    func testReturnOutsideFunction() {
        let error = SemanticError.returnOutsideFunction(
            at: SourcePosition(line: 14, column: 1, offset: 325)
        )

        let formatted = SemanticErrorFormatter.format(error)
        let expected = """
            SemanticError: Return statement outside function
              at line 14, column 1
            """

        XCTAssertEqual(formatted, expected, "Return outside function formatting should match golden file")
    }

    func testVariableNotInitialized() {
        let error = SemanticError.variableNotInitialized(
            "temp",
            at: SourcePosition(line: 15, column: 8, offset: 350)
        )

        let formatted = SemanticErrorFormatter.format(error)
        let expected = """
            SemanticError: Variable 'temp' used before initialization
              at line 15, column 8
            """

        XCTAssertEqual(formatted, expected, "Variable not initialized formatting should match golden file")
    }

    func testInvalidTypeConversion() {
        let error = SemanticError.invalidTypeConversion(
            from: .boolean,
            to: .integer,
            at: SourcePosition(line: 16, column: 12, offset: 375)
        )

        let formatted = SemanticErrorFormatter.format(error)
        let expected = """
            SemanticError: Invalid type conversion from 'boolean' to 'integer'
              at line 16, column 12
            """

        XCTAssertEqual(formatted, expected, "Invalid type conversion formatting should match golden file")
    }

    func testUnknownType() {
        let error = SemanticError.unknownType(
            "CustomType",
            at: SourcePosition(line: 17, column: 5, offset: 400)
        )

        let formatted = SemanticErrorFormatter.format(error)
        let expected = """
            SemanticError: Unknown type 'CustomType'
              at line 17, column 5
            """

        XCTAssertEqual(formatted, expected, "Unknown type formatting should match golden file")
    }

    func testTooManyErrors() {
        let error = SemanticError.tooManyErrors(count: 100)

        let formatted = SemanticErrorFormatter.format(error)
        let expected = """
            SemanticError: Too many semantic errors (100), stopping analysis
              at line 0, column 0
            """

        XCTAssertEqual(formatted, expected, "Too many errors formatting should match golden file")
    }

    func testMissingReturnStatement() {
        let error = SemanticError.missingReturnStatement(
            function: "compute",
            at: SourcePosition(line: 18, column: 1, offset: 425)
        )

        let formatted = SemanticErrorFormatter.format(error)
        let expected = """
            SemanticError: Function 'compute' missing return statement
              at line 18, column 1
            """

        XCTAssertEqual(formatted, expected, "Missing return statement formatting should match golden file")
    }

    func testVoidFunctionReturnsValue() {
        let error = SemanticError.voidFunctionReturnsValue(
            function: "printMessage",
            at: SourcePosition(line: 19, column: 5, offset: 450)
        )

        let formatted = SemanticErrorFormatter.format(error)
        let expected = """
            SemanticError: Void function 'printMessage' cannot return a value
              at line 19, column 5
            """

        XCTAssertEqual(formatted, expected, "Void function returns value formatting should match golden file")
    }

    // MARK: - Integration Tests with SemanticErrorReporter

    func testSemanticErrorReporterIntegration() {
        let reporter = SemanticErrorReporter()
        let symbolTable = SymbolTable()

        // Collect various types of errors
        reporter.collect(.undeclaredVariable("x", at: SourcePosition(line: 1, column: 1, offset: 0)))
        reporter.collect(.typeMismatch(expected: .integer, actual: .string, at: SourcePosition(line: 2, column: 5, offset: 10)))
        reporter.collect(.functionAlreadyDeclared("test", at: SourcePosition(line: 3, column: 1, offset: 20)))

        let result = reporter.finalize(with: symbolTable)

        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 3)

        // Test that all errors can be formatted correctly
        for error in result.errors {
            let formatted = SemanticErrorFormatter.format(error)
            XCTAssertTrue(formatted.contains("SemanticError:"))
            XCTAssertFalse(formatted.isEmpty)
        }

        // Test error report formatting
        let report = SemanticErrorFormatter.formatErrorReport(result.errors)
        XCTAssertTrue(report.contains("Semantic Analysis Errors (3 total):"))
    }

    // MARK: - Context Formatting Integration Tests

    func testFormattingWithContextualSuggestions() {
        let symbolTable = SymbolTable()

        // Add some symbols to the table
        _ = symbolTable.declare(name: "count", type: .integer, kind: .variable, position: SourcePosition(line: 1, column: 1, offset: 0))
        _ = symbolTable.declare(name: "counter", type: .integer, kind: .variable, position: SourcePosition(line: 2, column: 1, offset: 10))
        _ = symbolTable.declare(name: "computation", type: .function(parameters: [], returnType: .integer), kind: .function, position: SourcePosition(line: 3, column: 1, offset: 20))

        let error = SemanticError.undeclaredVariable("cout", at: SourcePosition(line: 4, column: 1, offset: 30))
        let formatted = SemanticErrorFormatter.formatWithContext(error, symbolTable: symbolTable)

        XCTAssertTrue(formatted.contains("SemanticError:"))
        XCTAssertTrue(formatted.contains("Symbol 'cout' not found"))
        // Should suggest similar symbols
        XCTAssertTrue(formatted.contains("Suggestion:") || formatted.contains("count"))
    }

    func testFormattingWithTypeCompatibilityHints() {
        let error = SemanticError.typeMismatch(
            expected: .real,
            actual: .integer,
            at: SourcePosition(line: 1, column: 1, offset: 0)
        )

        let formatted = SemanticErrorFormatter.formatWithContext(error, symbolTable: SymbolTable())

        XCTAssertTrue(formatted.contains("SemanticError:"))
        XCTAssertTrue(formatted.contains("Type mismatch"))
        // Should provide compatibility hint for integer -> real conversion
        XCTAssertTrue(formatted.contains("Implicit conversion") || formatted.contains("compatible"))
    }
}
