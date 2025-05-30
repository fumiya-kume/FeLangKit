import XCTest
@testable import FeLangCore

final class SemanticAnalyzerTests: XCTestCase {
    var analyzer: SemanticAnalyzer!

    override func setUp() {
        super.setUp()
        analyzer = SemanticAnalyzer()
    }

    override func tearDown() {
        analyzer = nil
        super.tearDown()
    }

    // MARK: - Basic Variable Declaration Tests

    func testVariableDeclarationWithoutInitializer() {
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "x",
                type: .integer,
                initialValue: nil
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testVariableDeclarationWithCompatibleInitializer() {
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "x",
                type: .integer,
                initialValue: .literal(.integer(42))
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testVariableDeclarationWithIncompatibleInitializer() {
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "x",
                type: .integer,
                initialValue: .literal(.string("hello"))
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 1)

        if case .typeMismatch(let expected, let actual, _) = result.errors[0] {
            XCTAssertEqual(expected, .integer)
            XCTAssertEqual(actual, .string)
        } else {
            XCTFail("Expected type mismatch error")
        }
    }

    func testDuplicateVariableDeclaration() {
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "x",
                type: .integer,
                initialValue: nil
            )),
            Statement.variableDeclaration(VariableDeclaration(
                name: "x",
                type: .real,
                initialValue: nil
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

    // MARK: - Constant Declaration Tests

    func testConstantDeclarationWithCompatibleInitializer() {
        let statements = [
            Statement.constantDeclaration(ConstantDeclaration(
                name: "PI",
                type: .real,
                initialValue: .literal(.real(3.14159))
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testConstantDeclarationWithIncompatibleInitializer() {
        let statements = [
            Statement.constantDeclaration(ConstantDeclaration(
                name: "PI",
                type: .real,
                initialValue: .literal(.string("pi"))
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 1)

        if case .typeMismatch(let expected, let actual, _) = result.errors[0] {
            XCTAssertEqual(expected, .real)
            XCTAssertEqual(actual, .string)
        } else {
            XCTFail("Expected type mismatch error")
        }
    }

    // MARK: - Assignment Tests

    func testVariableAssignmentCompatibleType() {
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "x",
                type: .integer,
                initialValue: nil
            )),
            Statement.assignment(.variable("x", .literal(.integer(42))))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testVariableAssignmentIncompatibleType() {
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "x",
                type: .integer,
                initialValue: nil
            )),
            Statement.assignment(.variable("x", .literal(.string("hello"))))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 1)

        if case .typeMismatch(let expected, let actual, _) = result.errors[0] {
            XCTAssertEqual(expected, .integer)
            XCTAssertEqual(actual, .string)
        } else {
            XCTFail("Expected type mismatch error")
        }
    }

    func testAssignmentToUndeclaredVariable() {
        let statements = [
            Statement.assignment(.variable("x", .literal(.integer(42))))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 1)

        if case .undeclaredVariable(let name, _) = result.errors[0] {
            XCTAssertEqual(name, "x")
        } else {
            XCTFail("Expected undeclared variable error")
        }
    }

    func testAssignmentToConstant() {
        let statements = [
            Statement.constantDeclaration(ConstantDeclaration(
                name: "PI",
                type: .real,
                initialValue: .literal(.real(3.14159))
            )),
            Statement.assignment(.variable("PI", .literal(.real(3.14))))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 1)

        if case .constantReassignment(let name, _) = result.errors[0] {
            XCTAssertEqual(name, "PI")
        } else {
            XCTFail("Expected constant reassignment error")
        }
    }

    // MARK: - Expression Type Inference Tests

    func testLiteralTypeInference() {
        let statements = [
            Statement.expressionStatement(.literal(.integer(42))),
            Statement.expressionStatement(.literal(.real(3.14))),
            Statement.expressionStatement(.literal(.string("hello"))),
            Statement.expressionStatement(.literal(.character("A"))),
            Statement.expressionStatement(.literal(.boolean(true)))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testBinaryArithmeticExpressions() {
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "result",
                type: .integer,
                initialValue: .binary(.add, .literal(.integer(1)), .literal(.integer(2)))
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testBinaryArithmeticWithMixedTypes() {
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "result",
                type: .real,
                initialValue: .binary(.add, .literal(.integer(1)), .literal(.real(2.5)))
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testBinaryComparisonExpressions() {
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "result",
                type: .boolean,
                initialValue: .binary(.greater, .literal(.integer(5)), .literal(.integer(3)))
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testBinaryLogicalExpressions() {
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "result",
                type: .boolean,
                initialValue: .binary(.and, .literal(.boolean(true)), .literal(.boolean(false)))
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testUnaryExpressions() {
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "negated",
                type: .integer,
                initialValue: .unary(.minus, .literal(.integer(42)))
            )),
            Statement.variableDeclaration(VariableDeclaration(
                name: "notted",
                type: .boolean,
                initialValue: .unary(.not, .literal(.boolean(true)))
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    // MARK: - Function Declaration Tests

    func testSimpleFunctionDeclaration() {
        let statements = [
            Statement.functionDeclaration(FunctionDeclaration(
                name: "add",
                parameters: [
                    Parameter(name: "a", type: .integer),
                    Parameter(name: "b", type: .integer)
                ],
                returnType: .integer,
                localVariables: [],
                body: [
                    Statement.returnStatement(ReturnStatement(
                        expression: .binary(.add, .identifier("a"), .identifier("b"))
                    ))
                ]
            ))
        ]

        let result = analyzer.analyze(statements)
        if !result.isSuccessful {
            print("Errors found:")
            for error in result.errors {
                print("  - \(error)")
            }
        }
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testFunctionWithMissingReturnStatement() {
        let statements = [
            Statement.functionDeclaration(FunctionDeclaration(
                name: "noReturn",
                parameters: [],
                returnType: .integer,
                localVariables: [],
                body: [
                    Statement.expressionStatement(.literal(.integer(42)))
                ]
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 1)

        if case .missingReturnStatement(let functionName, _) = result.errors[0] {
            XCTAssertEqual(functionName, "noReturn")
        } else {
            XCTFail("Expected missing return statement error")
        }
    }

    func testProcedureDeclaration() {
        let statements = [
            Statement.procedureDeclaration(ProcedureDeclaration(
                name: "printValue",
                parameters: [
                    Parameter(name: "value", type: .integer)
                ],
                localVariables: [],
                body: [
                    Statement.expressionStatement(.functionCall("writeLine", [.identifier("value")]))
                ]
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testDuplicateFunctionDeclaration() {
        let statements = [
            Statement.functionDeclaration(FunctionDeclaration(
                name: "test",
                parameters: [],
                returnType: .integer,
                localVariables: [],
                body: [
                    Statement.returnStatement(ReturnStatement(expression: .literal(.integer(1))))
                ]
            )),
            Statement.functionDeclaration(FunctionDeclaration(
                name: "test",
                parameters: [],
                returnType: .real,
                localVariables: [],
                body: [
                    Statement.returnStatement(ReturnStatement(expression: .literal(.real(1.0))))
                ]
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 1)

        if case .functionAlreadyDeclared(let name, _) = result.errors[0] {
            XCTAssertEqual(name, "test")
        } else {
            XCTFail("Expected function already declared error")
        }
    }

    // MARK: - Function Call Tests

    func testBuiltinFunctionCall() {
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "input",
                type: .string,
                initialValue: .functionCall("readLine", [])
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testFunctionCallWithCorrectArguments() {
        let statements = [
            Statement.functionDeclaration(FunctionDeclaration(
                name: "add",
                parameters: [
                    Parameter(name: "a", type: .integer),
                    Parameter(name: "b", type: .integer)
                ],
                returnType: .integer,
                localVariables: [],
                body: [
                    Statement.returnStatement(ReturnStatement(
                        expression: .binary(.add, .identifier("a"), .identifier("b"))
                    ))
                ]
            )),
            Statement.variableDeclaration(VariableDeclaration(
                name: "result",
                type: .integer,
                initialValue: .functionCall("add", [.literal(.integer(1)), .literal(.integer(2))])
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testFunctionCallWithIncorrectArgumentCount() {
        let statements = [
            Statement.functionDeclaration(FunctionDeclaration(
                name: "add",
                parameters: [
                    Parameter(name: "a", type: .integer),
                    Parameter(name: "b", type: .integer)
                ],
                returnType: .integer,
                localVariables: [],
                body: [
                    Statement.returnStatement(ReturnStatement(
                        expression: .binary(.add, .identifier("a"), .identifier("b"))
                    ))
                ]
            )),
            Statement.expressionStatement(.functionCall("add", [.literal(.integer(1))]))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 1)

        if case .incorrectArgumentCount(let function, let expected, let actual, _) = result.errors[0] {
            XCTAssertEqual(function, "add")
            XCTAssertEqual(expected, 2)
            XCTAssertEqual(actual, 1)
        } else {
            XCTFail("Expected incorrect argument count error")
        }
    }

    func testFunctionCallWithIncorrectArgumentType() {
        let statements = [
            Statement.functionDeclaration(FunctionDeclaration(
                name: "add",
                parameters: [
                    Parameter(name: "a", type: .integer),
                    Parameter(name: "b", type: .integer)
                ],
                returnType: .integer,
                localVariables: [],
                body: [
                    Statement.returnStatement(ReturnStatement(
                        expression: .binary(.add, .identifier("a"), .identifier("b"))
                    ))
                ]
            )),
            Statement.expressionStatement(.functionCall("add", [.literal(.integer(1)), .literal(.string("2"))]))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 1)

        if case .argumentTypeMismatch(let function, let paramIndex, let expected, let actual, _) = result.errors[0] {
            XCTAssertEqual(function, "add")
            XCTAssertEqual(paramIndex, 1)
            XCTAssertEqual(expected, .integer)
            XCTAssertEqual(actual, .string)
        } else {
            XCTFail("Expected argument type mismatch error")
        }
    }

    func testUndeclaredFunctionCall() {
        let statements = [
            Statement.expressionStatement(.functionCall("unknownFunction", []))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 1)

        if case .undeclaredFunction(let name, _) = result.errors[0] {
            XCTAssertEqual(name, "unknownFunction")
        } else {
            XCTFail("Expected undeclared function error")
        }
    }

    // MARK: - Control Flow Tests

    func testIfStatementWithBooleanCondition() {
        let statements = [
            Statement.ifStatement(IfStatement(
                condition: .literal(.boolean(true)),
                thenBody: [
                    Statement.expressionStatement(.literal(.integer(1)))
                ]
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testIfStatementWithNonBooleanCondition() {
        let statements = [
            Statement.ifStatement(IfStatement(
                condition: .literal(.integer(1)),
                thenBody: [
                    Statement.expressionStatement(.literal(.integer(1)))
                ]
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 1)

        if case .typeMismatch(let expected, let actual, _) = result.errors[0] {
            XCTAssertEqual(expected, .boolean)
            XCTAssertEqual(actual, .integer)
        } else {
            XCTFail("Expected type mismatch error")
        }
    }

    func testWhileStatementWithBooleanCondition() {
        let statements = [
            Statement.whileStatement(WhileStatement(
                condition: .literal(.boolean(true)),
                body: [
                    Statement.breakStatement
                ]
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testForRangeStatement() {
        let statements = [
            Statement.forStatement(.range(ForStatement.RangeFor(
                variable: "i",
                start: .literal(.integer(1)),
                end: .literal(.integer(10)),
                step: nil,
                body: [
                    Statement.expressionStatement(.identifier("i"))
                ]
            )))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    // MARK: - Return Statement Tests

    func testReturnStatementInFunction() {
        let statements = [
            Statement.functionDeclaration(FunctionDeclaration(
                name: "getValue",
                parameters: [],
                returnType: .integer,
                localVariables: [],
                body: [
                    Statement.returnStatement(ReturnStatement(expression: .literal(.integer(42))))
                ]
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testReturnStatementOutsideFunction() {
        let statements = [
            Statement.returnStatement(ReturnStatement(expression: .literal(.integer(42))))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 1)

        if case .returnOutsideFunction = result.errors[0] {
            // Expected
        } else {
            XCTFail("Expected return outside function error")
        }
    }

    func testReturnTypeMismatch() {
        let statements = [
            Statement.functionDeclaration(FunctionDeclaration(
                name: "getValue",
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

        if case .returnTypeMismatch(let function, let expected, let actual, _) = result.errors[0] {
            XCTAssertEqual(function, "getValue")
            XCTAssertEqual(expected, .integer)
            XCTAssertEqual(actual, .string)
        } else {
            XCTFail("Expected return type mismatch error")
        }
    }

    // MARK: - Break Statement Tests

    func testBreakStatementInLoop() {
        let statements = [
            Statement.whileStatement(WhileStatement(
                condition: .literal(.boolean(true)),
                body: [
                    Statement.breakStatement
                ]
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testBreakStatementOutsideLoop() {
        let statements = [
            Statement.breakStatement
        ]

        let result = analyzer.analyze(statements)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 1)

        if case .breakOutsideLoop = result.errors[0] {
            // Expected
        } else {
            XCTFail("Expected break outside loop error")
        }
    }

    // MARK: - Scope Tests

    func testVariableScope() {
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "x",
                type: .integer,
                initialValue: .literal(.integer(1))
            )),
            Statement.block([
                Statement.variableDeclaration(VariableDeclaration(
                    name: "x",
                    type: .real,
                    initialValue: .literal(.real(2.0))
                )),
                Statement.expressionStatement(.identifier("x"))
            ]),
            Statement.expressionStatement(.identifier("x"))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    // MARK: - Configuration Tests

    func testAnalyzerWithStrictConfig() {
        let strictAnalyzer = SemanticAnalyzer(config: .strict)
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "x",
                type: .integer,
                initialValue: .literal(.string("hello"))
            ))
        ]

        let result = strictAnalyzer.analyze(statements)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertFalse(result.errors.isEmpty)
    }

    func testAnalyzerWithFastConfig() {
        let fastAnalyzer = SemanticAnalyzer(config: .fast)
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "x",
                type: .integer,
                initialValue: .literal(.integer(42))
            ))
        ]

        let result = fastAnalyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    // MARK: - Enhanced Type Compatibility Tests

    func testStringConcatenationWithPlusOperator() {
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "result",
                type: .string,
                initialValue: .binary(.add, .literal(.string("Hello")), .literal(.string(" World")))
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testCharacterToStringCompatibility() {
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "message",
                type: .string,
                initialValue: .literal(.character("A"))
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testCharacterStringConcatenation() {
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "result",
                type: .string,
                initialValue: .binary(.add, .literal(.character("H")), .literal(.string("ello")))
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    // MARK: - Enhanced Validation Tests

    func testDuplicateParameterNames() {
        let statements = [
            Statement.functionDeclaration(FunctionDeclaration(
                name: "testFunc",
                parameters: [
                    Parameter(name: "param", type: .integer),
                    Parameter(name: "param", type: .real) // Duplicate name
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
            XCTAssertEqual(name, "param")
        } else {
            XCTFail("Expected variable already declared error")
        }
    }

    func testUnreachableCodeAfterReturn() {
        let statements = [
            Statement.functionDeclaration(FunctionDeclaration(
                name: "testFunc",
                parameters: [],
                returnType: .integer,
                localVariables: [],
                body: [
                    Statement.returnStatement(ReturnStatement(expression: .literal(.integer(1)))),
                    Statement.expressionStatement(.literal(.integer(42))) // Unreachable
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

    func testArrayTypeCompatibility() {
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "intArray",
                type: .array(.integer),
                initialValue: nil
            )),
            Statement.variableDeclaration(VariableDeclaration(
                name: "stringArray",
                type: .array(.string),
                initialValue: .identifier("intArray") // Integer array assigned to string array (incompatible)
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.errors.count, 1)

        if case .typeMismatch(let expected, let actual, _) = result.errors[0] {
            XCTAssertEqual(expected, .array(elementType: .string, dimensions: []))
            XCTAssertEqual(actual, .array(elementType: .integer, dimensions: []))
        } else {
            XCTFail("Expected type mismatch error")
        }
    }

    // MARK: - Integration Tests

    func testComplexSemanticAnalysis() {
        let statements = [
            Statement.functionDeclaration(FunctionDeclaration(
                name: "calculateSum",
                parameters: [
                    Parameter(name: "numbers", type: .array(.integer)),
                    Parameter(name: "count", type: .integer)
                ],
                returnType: .integer,
                localVariables: [
                    VariableDeclaration(name: "sum", type: .integer, initialValue: .literal(.integer(0))),
                    VariableDeclaration(name: "i", type: .integer, initialValue: nil)
                ],
                body: [
                    Statement.forStatement(.range(ForStatement.RangeFor(
                        variable: "i",
                        start: .literal(.integer(0)),
                        end: .identifier("count"),
                        step: nil,
                        body: [
                            Statement.assignment(.variable("sum", .binary(.add,
                                .identifier("sum"),
                                .arrayAccess(.identifier("numbers"), .identifier("i"))
                            )))
                        ]
                    ))),
                    Statement.returnStatement(ReturnStatement(expression: .identifier("sum")))
                ]
            )),
            Statement.variableDeclaration(VariableDeclaration(
                name: "testArray",
                type: .array(.integer),
                initialValue: nil
            )),
            Statement.variableDeclaration(VariableDeclaration(
                name: "result",
                type: .integer,
                initialValue: .functionCall("calculateSum", [.identifier("testArray"), .literal(.integer(5))])
            ))
        ]

        let result = analyzer.analyze(statements)
        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.errors.isEmpty)
    }

    // MARK: - Performance Tests

    func testAnalysisPerformance() {
        // Generate a large number of statements
        var statements: [Statement] = []
        for index in 0..<1000 {
            statements.append(Statement.variableDeclaration(VariableDeclaration(
                name: "var\(index)",
                type: .integer,
                initialValue: .literal(.integer(index))
            )))
        }

        measure {
            let result = analyzer.analyze(statements)
            XCTAssertTrue(result.isSuccessful)
        }
    }
}
