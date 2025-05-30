import XCTest
@testable import FeLangCore

final class SemanticErrorFormatterTests: XCTestCase {

    // MARK: - Basic Formatting Tests

    func testFormatTypeMismatch() {
        let error = SemanticError.typeMismatch(
            expected: .integer,
            actual: .string,
            at: SourcePosition(line: 1, column: 5, offset: 4)
        )

        let formatted = SemanticErrorFormatter.format(error)

        XCTAssertTrue(formatted.contains("SemanticError:"))
        XCTAssertTrue(formatted.contains("Type mismatch"))
        XCTAssertTrue(formatted.contains("expected 'integer'"))
        XCTAssertTrue(formatted.contains("got 'string'"))
        XCTAssertTrue(formatted.contains("line 1, column 5"))
    }

    func testFormatUndeclaredVariable() {
        let error = SemanticError.undeclaredVariable(
            "count",
            at: SourcePosition(line: 2, column: 10, offset: 25)
        )

        let formatted = SemanticErrorFormatter.format(error)

        XCTAssertTrue(formatted.contains("SemanticError:"))
        XCTAssertTrue(formatted.contains("Symbol 'count' not found"))
        XCTAssertTrue(formatted.contains("line 2, column 10"))
        XCTAssertTrue(formatted.contains("Variable must be declared before use"))
    }

    func testFormatIncorrectArgumentCount() {
        let error = SemanticError.incorrectArgumentCount(
            function: "calculateSum",
            expected: 2,
            actual: 3,
            at: SourcePosition(line: 3, column: 1, offset: 50)
        )

        let formatted = SemanticErrorFormatter.format(error)

        XCTAssertTrue(formatted.contains("SemanticError:"))
        XCTAssertTrue(formatted.contains("Incorrect argument count"))
        XCTAssertTrue(formatted.contains("calculateSum"))
        XCTAssertTrue(formatted.contains("Expected: 2 arguments"))
        XCTAssertTrue(formatted.contains("Actual: 3 arguments"))
        XCTAssertTrue(formatted.contains("line 3, column 1"))
    }

    func testFormatArgumentTypeMismatch() {
        let error = SemanticError.argumentTypeMismatch(
            function: "pow",
            paramIndex: 1,
            expected: .real,
            actual: .string,
            at: SourcePosition(line: 4, column: 8, offset: 75)
        )

        let formatted = SemanticErrorFormatter.format(error)

        XCTAssertTrue(formatted.contains("SemanticError:"))
        XCTAssertTrue(formatted.contains("Argument type mismatch"))
        XCTAssertTrue(formatted.contains("function 'pow'"))
        XCTAssertTrue(formatted.contains("Parameter: #2"))
        XCTAssertTrue(formatted.contains("Expected: real"))
        XCTAssertTrue(formatted.contains("Actual: string"))
    }

    func testFormatIncompatibleTypes() {
        let error = SemanticError.incompatibleTypes(
            .boolean,
            .integer,
            operation: "addition",
            at: SourcePosition(line: 5, column: 15, offset: 100)
        )

        let formatted = SemanticErrorFormatter.format(error)

        XCTAssertTrue(formatted.contains("SemanticError:"))
        XCTAssertTrue(formatted.contains("Incompatible types"))
        XCTAssertTrue(formatted.contains("addition"))
        XCTAssertTrue(formatted.contains("Left type: boolean"))
        XCTAssertTrue(formatted.contains("Right type: integer"))
    }

    func testFormatCyclicDependency() {
        let error = SemanticError.cyclicDependency(
            ["varA", "varB", "varC", "varA"],
            at: SourcePosition(line: 9, column: 1, offset: 200)
        )

        let formatted = SemanticErrorFormatter.format(error)

        XCTAssertTrue(formatted.contains("SemanticError:"))
        XCTAssertTrue(formatted.contains("Cyclic dependency"))
        XCTAssertTrue(formatted.contains("varA -> varB -> varC -> varA"))
        XCTAssertTrue(formatted.contains("line 9, column 1"))
    }

    // MARK: - Context Formatting Tests

    func testFormatWithSymbolTableContext() {
        let symbolTable = SymbolTable()

        // Add some similar symbols to test suggestion functionality
        _ = symbolTable.declare(
            name: "counter",
            type: .integer,
            kind: .variable,
            position: SourcePosition(line: 1, column: 1, offset: 0)
        )
        _ = symbolTable.declare(
            name: "compute",
            type: .function(parameters: [], returnType: .integer),
            kind: .function,
            position: SourcePosition(line: 2, column: 1, offset: 10)
        )

        let error = SemanticError.undeclaredVariable(
            "count",
            at: SourcePosition(line: 3, column: 5, offset: 20)
        )

        let formatted = SemanticErrorFormatter.formatWithContext(error, symbolTable: symbolTable)

        XCTAssertTrue(formatted.contains("SemanticError:"))
        XCTAssertTrue(formatted.contains("Symbol 'count' not found"))
        // Should suggest similar symbol "counter"
        XCTAssertTrue(formatted.contains("Suggestion:") || formatted.contains("counter"))
    }

    func testFormatWithoutContext() {
        let error = SemanticError.undeclaredVariable(
            "count",
            at: SourcePosition(line: 2, column: 10, offset: 25)
        )

        let formattedWithoutContext = SemanticErrorFormatter.format(error)
        let formattedWithNilContext = SemanticErrorFormatter.formatWithContext(error, symbolTable: nil)

        XCTAssertEqual(formattedWithoutContext, formattedWithNilContext)
    }

    // MARK: - Error Report Formatting Tests

    func testFormatEmptyErrorReport() {
        let report = SemanticErrorFormatter.formatErrorReport([])

        XCTAssertEqual(report, "No semantic errors found.")
    }

    func testFormatSingleErrorReport() {
        let error = SemanticError.undeclaredVariable(
            "x",
            at: SourcePosition(line: 1, column: 1, offset: 0)
        )

        let report = SemanticErrorFormatter.formatErrorReport([error])

        XCTAssertTrue(report.contains("Semantic Analysis Errors (1 total):"))
        XCTAssertTrue(report.contains("1. SemanticError:"))
        XCTAssertTrue(report.contains("Symbol 'x' not found"))
    }

    func testFormatMultipleErrorReport() {
        let errors = [
            SemanticError.undeclaredVariable("x", at: SourcePosition(line: 1, column: 1, offset: 0)),
            SemanticError.typeMismatch(expected: .integer, actual: .string, at: SourcePosition(line: 2, column: 5, offset: 10)),
            SemanticError.functionAlreadyDeclared("test", at: SourcePosition(line: 3, column: 1, offset: 20))
        ]

        let report = SemanticErrorFormatter.formatErrorReport(errors)

        XCTAssertTrue(report.contains("Semantic Analysis Errors (3 total):"))
        XCTAssertTrue(report.contains("1. SemanticError:"))
        XCTAssertTrue(report.contains("2. SemanticError:"))
        XCTAssertTrue(report.contains("3. SemanticError:"))
    }

    // MARK: - Special Cases Tests

    func testFormatTooManyErrors() {
        let error = SemanticError.tooManyErrors(count: 100)

        let formatted = SemanticErrorFormatter.format(error)

        XCTAssertTrue(formatted.contains("SemanticError:"))
        XCTAssertTrue(formatted.contains("Too many semantic errors (100)"))
        XCTAssertTrue(formatted.contains("stopping analysis"))
    }

    func testFormatArrayTypes() {
        let arrayType = FeType.array(elementType: .integer, dimensions: [10, 20])
        let error = SemanticError.typeMismatch(
            expected: arrayType,
            actual: .string,
            at: SourcePosition(line: 1, column: 1, offset: 0)
        )

        let formatted = SemanticErrorFormatter.format(error)

        XCTAssertTrue(formatted.contains("array[10][20] of integer"))
        XCTAssertTrue(formatted.contains("string"))
    }

    func testFormatFunctionTypes() {
        let functionType = FeType.function(parameters: [.integer, .real], returnType: .boolean)
        let error = SemanticError.typeMismatch(
            expected: functionType,
            actual: .string,
            at: SourcePosition(line: 1, column: 1, offset: 0)
        )

        let formatted = SemanticErrorFormatter.format(error)

        XCTAssertTrue(formatted.contains("function(integer, real) -> boolean"))
    }

    func testFormatRecordTypes() {
        let recordType = FeType.record(name: "Person", fields: ["name": .string, "age": .integer])
        let error = SemanticError.typeMismatch(
            expected: recordType,
            actual: .string,
            at: SourcePosition(line: 1, column: 1, offset: 0)
        )

        let formatted = SemanticErrorFormatter.format(error)

        XCTAssertTrue(formatted.contains("record Person"))
    }

    // MARK: - Position Formatting Tests

    func testPositionFormatting() {
        let position = SourcePosition(line: 42, column: 13, offset: 1000)
        let formatted = SemanticErrorFormatter.formatPosition(position)

        XCTAssertEqual(formatted, "line 42, column 13")
    }

    // MARK: - Primary Message Tests

    func testPrimaryMessages() {
        let testCases: [(SemanticError, String)] = [
            (.undeclaredVariable("x", at: SourcePosition(line: 1, column: 1, offset: 0)), "Undeclared variable 'x'"),
            (.typeMismatch(expected: .integer, actual: .string, at: SourcePosition(line: 1, column: 1, offset: 0)), "Type mismatch: expected 'integer', got 'string'"),
            (.functionAlreadyDeclared("test", at: SourcePosition(line: 1, column: 1, offset: 0)), "Function 'test' already declared")
        ]

        for (error, expectedMessage) in testCases {
            XCTAssertEqual(error.primaryMessage, expectedMessage)
        }
    }

    // MARK: - Performance Tests

    func testFormattingPerformance() {
        let errors = (0..<1000).map { index in
            SemanticError.undeclaredVariable(
                "var\(index)",
                at: SourcePosition(line: index + 1, column: 1, offset: index * 10)
            )
        }

        measure {
            for error in errors {
                _ = SemanticErrorFormatter.format(error)
            }
        }
    }

    func testReportFormattingPerformance() {
        let errors = (0..<100).map { index in
            SemanticError.undeclaredVariable(
                "var\(index)",
                at: SourcePosition(line: index + 1, column: 1, offset: index * 10)
            )
        }

        measure {
            _ = SemanticErrorFormatter.formatErrorReport(errors)
        }
    }
}
