import XCTest
@testable import FeLangCore

final class SemanticValidationTests: XCTestCase {
    var analyzer: SemanticAnalyzer!

    override func setUp() {
        super.setUp()
        analyzer = SemanticAnalyzer()
    }

    override func tearDown() {
        analyzer = nil
        super.tearDown()
    }

    // MARK: - Control Flow Validation Tests

    func testBreakStatementValidation() {
        let validStatements = [
            Statement.whileStatement(WhileStatement(
                condition: .literal(.boolean(true)),
                body: [
                    Statement.breakStatement
                ]
            ))
        ]

        let validResult = analyzer.analyze(validStatements)
        XCTAssertTrue(validResult.isSuccessful)
        XCTAssertTrue(validResult.errors.isEmpty)

        let invalidStatements = [
            Statement.breakStatement
        ]

        let invalidResult = analyzer.analyze(invalidStatements)
        XCTAssertFalse(invalidResult.isSuccessful)
        XCTAssertEqual(invalidResult.errors.count, 1)

        if case .breakOutsideLoop = invalidResult.errors[0] {
            // Expected
        } else {
            XCTFail("Expected break outside loop error")
        }
    }

    func testReturnStatementValidation() {
        let validStatements = [
            Statement.functionDeclaration(FunctionDeclaration(
                name: "test",
                parameters: [],
                returnType: .integer,
                localVariables: [],
                body: [
                    Statement.returnStatement(ReturnStatement(expression: .literal(.integer(42))))
                ]
            ))
        ]

        let validResult = analyzer.analyze(validStatements)
        XCTAssertTrue(validResult.isSuccessful)
        XCTAssertTrue(validResult.errors.isEmpty)

        let invalidStatements = [
            Statement.returnStatement(ReturnStatement(expression: .literal(.integer(42))))
        ]

        let invalidResult = analyzer.analyze(invalidStatements)
        XCTAssertFalse(invalidResult.isSuccessful)
        XCTAssertEqual(invalidResult.errors.count, 1)

        if case .returnOutsideFunction = invalidResult.errors[0] {
            // Expected
        } else {
            XCTFail("Expected return outside function error")
        }
    }

    func testBreakInNestedScopes() {
        let statements = [
            Statement.whileStatement(WhileStatement(
                condition: .literal(.boolean(true)),
                body: [
                    Statement.ifStatement(IfStatement(
                        condition: .literal(.boolean(true)),
                        thenBody: [
                            Statement.block([
                                Statement.breakStatement // Should be valid - break is in a loop
                            ])
                        ]
                    ))
                ]
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testReturnInNestedScopes() {
        let statements = [
            Statement.functionDeclaration(FunctionDeclaration(
                name: "test",
                parameters: [],
                returnType: .integer,
                localVariables: [],
                body: [
                    Statement.ifStatement(IfStatement(
                        condition: .literal(.boolean(true)),
                        thenBody: [
                            Statement.block([
                                Statement.returnStatement(ReturnStatement(expression: .literal(.integer(42))))
                            ])
                        ]
                    ))
                ]
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    // MARK: - Function Validation Tests

    func testFunctionWithMissingReturnStatement() {
        let statements = [
            Statement.functionDeclaration(FunctionDeclaration(
                name: "incompleteFunction",
                parameters: [],
                returnType: .integer,
                localVariables: [],
                body: [
                    Statement.expressionStatement(.literal(.integer(42)))
                    // Missing return statement
                ]
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 1)

        if case .missingReturnStatement(let functionName, _) = result.errors[0] {
            XCTAssertEqual(functionName, "incompleteFunction")
        } else {
            XCTFail("Expected missing return statement error")
        }
    }

    func testProcedureWithReturnStatement() {
        let statements = [
            Statement.procedureDeclaration(ProcedureDeclaration(
                name: "validProcedure",
                parameters: [],
                localVariables: [],
                body: [
                    Statement.expressionStatement(.functionCall("writeLine", [.literal(.string("Hello"))])),
                    Statement.returnStatement(ReturnStatement(expression: nil)) // Valid return without value
                ]
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testProcedureWithInvalidReturnValue() {
        let statements = [
            Statement.procedureDeclaration(ProcedureDeclaration(
                name: "invalidProcedure",
                parameters: [],
                localVariables: [],
                body: [
                    Statement.returnStatement(ReturnStatement(expression: .literal(.integer(42)))) // Invalid - procedure shouldn't return value
                ]
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 1)

        if case .voidFunctionReturnsValue(let functionName, _) = result.errors[0] {
            XCTAssertEqual(functionName, "invalidProcedure")
        } else {
            XCTFail("Expected void function returns value error")
        }
    }

    func testFunctionWithReturnTypeMismatch() {
        let statements = [
            Statement.functionDeclaration(FunctionDeclaration(
                name: "typeMismatchFunction",
                parameters: [],
                returnType: .integer,
                localVariables: [],
                body: [
                    Statement.returnStatement(ReturnStatement(expression: .literal(.string("hello"))))
                ]
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 1)

        if case .returnTypeMismatch(let functionName, let expected, let actual, _) = result.errors[0] {
            XCTAssertEqual(functionName, "typeMismatchFunction")
            XCTAssertEqual(expected, .integer)
            XCTAssertEqual(actual, .string)
        } else {
            XCTFail("Expected return type mismatch error")
        }
    }

    func testUnreachableCodeDetection() {
        let statements = [
            Statement.functionDeclaration(FunctionDeclaration(
                name: "unreachableCodeFunction",
                parameters: [],
                returnType: .integer,
                localVariables: [],
                body: [
                    Statement.returnStatement(ReturnStatement(expression: .literal(.integer(42)))),
                    Statement.expressionStatement(.literal(.string("This is unreachable")))
                ]
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 1)

        if case .unreachableCode = result.errors[0] {
            // Expected
        } else {
            XCTFail("Expected unreachable code error")
        }
    }

    func testUnreachableCodeInProcedure() {
        let statements = [
            Statement.procedureDeclaration(ProcedureDeclaration(
                name: "unreachableProcedure",
                parameters: [],
                localVariables: [],
                body: [
                    Statement.returnStatement(ReturnStatement(expression: nil)),
                    Statement.expressionStatement(.functionCall("writeLine", [.literal(.string("Unreachable"))]))
                ]
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 1)

        if case .unreachableCode = result.errors[0] {
            // Expected
        } else {
            XCTFail("Expected unreachable code error")
        }
    }

    func testDuplicateParameterValidation() {
        let statements = [
            Statement.functionDeclaration(FunctionDeclaration(
                name: "duplicateParamsFunction",
                parameters: [
                    Parameter(name: "param1", type: .integer),
                    Parameter(name: "param2", type: .real),
                    Parameter(name: "param1", type: .string) // Duplicate name
                ],
                returnType: .integer,
                localVariables: [],
                body: [
                    Statement.returnStatement(ReturnStatement(expression: .literal(.integer(1))))
                ]
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 1)

        if case .variableAlreadyDeclared(let name, _) = result.errors[0] {
            XCTAssertEqual(name, "param1")
        } else {
            XCTFail("Expected variable already declared error")
        }
    }

    func testDuplicateParameterInProcedure() {
        let statements = [
            Statement.procedureDeclaration(ProcedureDeclaration(
                name: "duplicateParamsProcedure",
                parameters: [
                    Parameter(name: "x", type: .integer),
                    Parameter(name: "y", type: .real),
                    Parameter(name: "x", type: .boolean) // Duplicate name
                ],
                localVariables: [],
                body: [
                    Statement.expressionStatement(.functionCall("writeLine", [.literal(.string("Hello"))]))
                ]
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 1)

        if case .variableAlreadyDeclared(let name, _) = result.errors[0] {
            XCTAssertEqual(name, "x")
        } else {
            XCTFail("Expected variable already declared error")
        }
    }

    // MARK: - Scope Validation Tests

    func testParameterScopeValidation() {
        let statements = [
            Statement.functionDeclaration(FunctionDeclaration(
                name: "testParameterScope",
                parameters: [
                    Parameter(name: "param", type: .integer)
                ],
                returnType: .integer,
                localVariables: [],
                body: [
                    Statement.returnStatement(ReturnStatement(expression: .identifier("param")))
                ]
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testLocalVariableScopeValidation() {
        let statements = [
            Statement.functionDeclaration(FunctionDeclaration(
                name: "testLocalScope",
                parameters: [],
                returnType: .integer,
                localVariables: [
                    VariableDeclaration(name: "localVar", type: .integer, initialValue: .literal(.integer(42)))
                ],
                body: [
                    Statement.returnStatement(ReturnStatement(expression: .identifier("localVar")))
                ]
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testVariableScopeShadowing() {
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "x",
                type: .integer,
                initialValue: .literal(.integer(1))
            )),
            Statement.functionDeclaration(FunctionDeclaration(
                name: "testShadowing",
                parameters: [
                    Parameter(name: "x", type: .real) // Shadows global x
                ],
                returnType: .real,
                localVariables: [],
                body: [
                    Statement.returnStatement(ReturnStatement(expression: .identifier("x"))) // Should refer to parameter
                ]
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    // MARK: - For Loop Validation Tests

    func testForRangeLoopValidation() {
        let statements = [
            Statement.forStatement(.range(ForStatement.RangeFor(
                variable: "i",
                start: .literal(.integer(1)),
                end: .literal(.integer(10)),
                step: .literal(.integer(2)),
                body: [
                    Statement.expressionStatement(.identifier("i"))
                ]
            )))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testForRangeLoopWithInvalidStart() {
        let statements = [
            Statement.forStatement(.range(ForStatement.RangeFor(
                variable: "i",
                start: .literal(.string("not_a_number")),
                end: .literal(.integer(10)),
                step: nil,
                body: [
                    Statement.expressionStatement(.identifier("i"))
                ]
            )))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 1)

        if case .typeMismatch(let expected, let actual, _) = result.errors[0] {
            XCTAssertEqual(expected, .integer)
            XCTAssertEqual(actual, .string)
        } else {
            XCTFail("Expected type mismatch error for for loop start")
        }
    }

    func testForRangeLoopWithInvalidEnd() {
        let statements = [
            Statement.forStatement(.range(ForStatement.RangeFor(
                variable: "i",
                start: .literal(.integer(1)),
                end: .literal(.real(10.5)),
                step: nil,
                body: [
                    Statement.expressionStatement(.identifier("i"))
                ]
            )))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 1)

        if case .typeMismatch(let expected, let actual, _) = result.errors[0] {
            XCTAssertEqual(expected, .integer)
            XCTAssertEqual(actual, .real)
        } else {
            XCTFail("Expected type mismatch error for for loop end")
        }
    }

    func testForRangeLoopWithInvalidStep() {
        let statements = [
            Statement.forStatement(.range(ForStatement.RangeFor(
                variable: "i",
                start: .literal(.integer(1)),
                end: .literal(.integer(10)),
                step: .literal(.boolean(true)),
                body: [
                    Statement.expressionStatement(.identifier("i"))
                ]
            )))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 1)

        if case .typeMismatch(let expected, let actual, _) = result.errors[0] {
            XCTAssertEqual(expected, .integer)
            XCTAssertEqual(actual, .boolean)
        } else {
            XCTFail("Expected type mismatch error for for loop step")
        }
    }

    func testForEachLoopValidation() {
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "numbers",
                type: .array(.integer),
                initialValue: nil
            )),
            Statement.forStatement(.forEach(ForStatement.ForEachLoop(
                variable: "num",
                iterable: Expression.identifier("numbers"),
                body: [
                    Statement.expressionStatement(Expression.identifier("num"))
                ]
            )))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testForEachLoopWithString() {
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "text",
                type: .string,
                initialValue: .literal(.string("Hello"))
            )),
            Statement.forStatement(.forEach(ForStatement.ForEachLoop(
                variable: "char",
                iterable: Expression.identifier("text"),
                body: [
                    Statement.expressionStatement(Expression.identifier("char"))
                ]
            )))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testForEachLoopWithInvalidIterable() {
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "number",
                type: .integer,
                initialValue: .literal(.integer(42))
            )),
            Statement.forStatement(.forEach(ForStatement.ForEachLoop(
                variable: "item",
                iterable: Expression.identifier("number"),
                body: [
                    Statement.expressionStatement(Expression.identifier("item"))
                ]
            )))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 1)

        if case .typeMismatch(let expected, let actual, _) = result.errors[0] {
            XCTAssertEqual(expected, FeType.array(elementType: FeType.unknown, dimensions: []))
            XCTAssertEqual(actual, FeType.integer)
        } else {
            XCTFail("Expected type mismatch error for for-each iterable")
        }
    }

    // MARK: - If Statement Validation Tests

    func testIfStatementConditionValidation() {
        let validStatements = [
            Statement.ifStatement(IfStatement(
                condition: .literal(.boolean(true)),
                thenBody: [
                    Statement.expressionStatement(.literal(.integer(1)))
                ]
            ))
        ]

        let validResult = analyzer.analyze(validStatements)
        XCTAssertTrue(validResult.isSuccessful)
        XCTAssertTrue(validResult.errors.isEmpty)

        let invalidStatements = [
            Statement.ifStatement(IfStatement(
                condition: .literal(.integer(1)),
                thenBody: [
                    Statement.expressionStatement(.literal(.integer(1)))
                ]
            ))
        ]

        let invalidResult = analyzer.analyze(invalidStatements)
        XCTAssertFalse(invalidResult.isSuccessful)
        XCTAssertEqual(invalidResult.errors.count, 1)

        if case .typeMismatch(let expected, let actual, _) = invalidResult.errors[0] {
            XCTAssertEqual(expected, .boolean)
            XCTAssertEqual(actual, .integer)
        } else {
            XCTFail("Expected type mismatch error for if condition")
        }
    }

    func testWhileStatementConditionValidation() {
        let validStatements = [
            Statement.whileStatement(WhileStatement(
                condition: .literal(.boolean(false)),
                body: [
                    Statement.expressionStatement(.literal(.integer(1)))
                ]
            ))
        ]

        let validResult = analyzer.analyze(validStatements)
        XCTAssertTrue(validResult.isSuccessful)
        XCTAssertTrue(validResult.errors.isEmpty)

        let invalidStatements = [
            Statement.whileStatement(WhileStatement(
                condition: .literal(.string("true")),
                body: [
                    Statement.expressionStatement(.literal(.integer(1)))
                ]
            ))
        ]

        let invalidResult = analyzer.analyze(invalidStatements)
        XCTAssertFalse(invalidResult.isSuccessful)
        XCTAssertEqual(invalidResult.errors.count, 1)

        if case .typeMismatch(let expected, let actual, _) = invalidResult.errors[0] {
            XCTAssertEqual(expected, .boolean)
            XCTAssertEqual(actual, .string)
        } else {
            XCTFail("Expected type mismatch error for while condition")
        }
    }

    // MARK: - Complex Validation Scenarios

    func testComplexFunctionWithAllValidations() {
        let statements = [
            Statement.functionDeclaration(FunctionDeclaration(
                name: "complexFunction",
                parameters: [
                    Parameter(name: "array", type: .array(.integer)),
                    Parameter(name: "threshold", type: .integer)
                ],
                returnType: .integer,
                localVariables: [
                    VariableDeclaration(name: "count", type: .integer, initialValue: .literal(.integer(0))),
                    VariableDeclaration(name: "i", type: .integer, initialValue: nil)
                ],
                body: [
                    Statement.forStatement(.forEach(ForStatement.ForEachLoop(
                        variable: "element",
                        iterable: Expression.identifier("array"),
                        body: [
                            Statement.ifStatement(IfStatement(
                                condition: .binary(.greater, .identifier("element"), .identifier("threshold")),
                                thenBody: [
                                    Statement.assignment(.variable("count", .binary(.add, .identifier("count"), .literal(.integer(1)))))
                                ]
                            ))
                        ]
                    ))),
                    Statement.returnStatement(ReturnStatement(expression: .identifier("count")))
                ]
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }
}
