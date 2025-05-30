import Testing
@testable import FeLangCore

@Suite("SemanticAnalyzer Tests")
struct SemanticAnalyzerTests {

    func createAnalyzer() -> SemanticAnalyzer {
        return SemanticAnalyzer()
    }

    // MARK: - Basic Variable Declaration Tests

    @Test func variableDeclarationWithoutInitializer() {
        let analyzer = createAnalyzer()
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "x",
                type: .integer,
                initialValue: nil
            ))
        ]

        let result = analyzer.analyze(statements)
        #expect(result.isSuccessful)
        #expect(result.errors.isEmpty)
    }

    @Test func variableDeclarationWithCompatibleInitializer() {
        let analyzer = createAnalyzer()
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "x",
                type: .integer,
                initialValue: .literal(.integer(42))
            ))
        ]

        let result = analyzer.analyze(statements)
        #expect(result.isSuccessful)
        #expect(result.errors.isEmpty)
    }

    @Test func variableDeclarationWithIncompatibleInitializer() {
        let analyzer = createAnalyzer()
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "x",
                type: .integer,
                initialValue: .literal(.string("hello"))
            ))
        ]

        let result = analyzer.analyze(statements)
        #expect(!result.isSuccessful)
        #expect(result.errors.count == 1)

        if case .typeMismatch(let expected, let actual, _) = result.errors[0] {
            #expect(expected == .integer)
            #expect(actual == .string)
        } else {
            Issue.record("Expected type mismatch error")
        }
    }

    @Test func duplicateVariableDeclaration() {
        let analyzer = createAnalyzer()
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
        #expect(!result.isSuccessful)
        #expect(result.errors.count == 1)

        if case .variableAlreadyDeclared(let name, _) = result.errors[0] {
            #expect(name == "x")
        } else {
            Issue.record("Expected variable already declared error")
        }
    }

    // MARK: - Constant Declaration Tests

    @Test func constantDeclarationWithCompatibleInitializer() {
        let analyzer = createAnalyzer()
        let statements = [
            Statement.constantDeclaration(ConstantDeclaration(
                name: "PI",
                type: .real,
                initialValue: .literal(.real(3.14159))
            ))
        ]

        let result = analyzer.analyze(statements)
        #expect(result.isSuccessful)
        #expect(result.errors.isEmpty)
    }

    @Test func constantDeclarationWithIncompatibleInitializer() {
        let analyzer = createAnalyzer()
        let statements = [
            Statement.constantDeclaration(ConstantDeclaration(
                name: "PI",
                type: .real,
                initialValue: .literal(.string("pi"))
            ))
        ]

        let result = analyzer.analyze(statements)
        #expect(!result.isSuccessful)
        #expect(result.errors.count == 1)

        if case .typeMismatch(let expected, let actual, _) = result.errors[0] {
            #expect(expected == .real)
            #expect(actual == .string)
        } else {
            Issue.record("Expected type mismatch error")
        }
    }

    // MARK: - Assignment Tests

    @Test func variableAssignmentCompatibleType() {
        let analyzer = createAnalyzer()
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "x",
                type: .integer,
                initialValue: nil
            )),
            Statement.assignment(.variable("x", .literal(.integer(42))))
        ]

        let result = analyzer.analyze(statements)
        #expect(result.isSuccessful)
        #expect(result.errors.isEmpty)
    }

    @Test func variableAssignmentIncompatibleType() {
        let analyzer = createAnalyzer()
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "x",
                type: .integer,
                initialValue: nil
            )),
            Statement.assignment(.variable("x", .literal(.string("hello"))))
        ]

        let result = analyzer.analyze(statements)
        #expect(!result.isSuccessful)
        #expect(result.errors.count == 1)

        if case .typeMismatch(let expected, let actual, _) = result.errors[0] {
            #expect(expected == .integer)
            #expect(actual == .string)
        } else {
            Issue.record("Expected type mismatch error")
        }
    }

    @Test func assignmentToUndeclaredVariable() {
        let analyzer = createAnalyzer()
        let statements = [
            Statement.assignment(.variable("x", .literal(.integer(42))))
        ]

        let result = analyzer.analyze(statements)
        #expect(!result.isSuccessful)
        #expect(result.errors.count == 1)

        if case .undeclaredVariable(let name, _) = result.errors[0] {
            #expect(name == "x")
        } else {
            Issue.record("Expected undeclared variable error")
        }
    }

    @Test func assignmentToConstant() {
        let analyzer = createAnalyzer()
        let statements = [
            Statement.constantDeclaration(ConstantDeclaration(
                name: "PI",
                type: .real,
                initialValue: .literal(.real(3.14159))
            )),
            Statement.assignment(.variable("PI", .literal(.real(3.14))))
        ]

        let result = analyzer.analyze(statements)
        #expect(!result.isSuccessful)
        #expect(result.errors.count == 1)

        if case .constantReassignment(let name, _) = result.errors[0] {
            #expect(name == "PI")
        } else {
            Issue.record("Expected constant reassignment error")
        }
    }

    // MARK: - Expression Type Inference Tests

    @Test func literalTypeInference() {
        let analyzer = createAnalyzer()
        let statements = [
            Statement.expressionStatement(.literal(.integer(42))),
            Statement.expressionStatement(.literal(.real(3.14))),
            Statement.expressionStatement(.literal(.string("hello"))),
            Statement.expressionStatement(.literal(.character("A"))),
            Statement.expressionStatement(.literal(.boolean(true)))
        ]

        let result = analyzer.analyze(statements)
        #expect(result.isSuccessful)
        #expect(result.errors.isEmpty)
    }

    @Test func binaryArithmeticExpressions() {
        let analyzer = createAnalyzer()
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "result",
                type: .integer,
                initialValue: .binary(.add, .literal(.integer(1)), .literal(.integer(2)))
            ))
        ]

        let result = analyzer.analyze(statements)
        #expect(result.isSuccessful)
        #expect(result.errors.isEmpty)
    }

    @Test func binaryArithmeticWithMixedTypes() {
        let analyzer = createAnalyzer()
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "result",
                type: .real,
                initialValue: .binary(.add, .literal(.integer(1)), .literal(.real(2.5)))
            ))
        ]

        let result = analyzer.analyze(statements)
        #expect(result.isSuccessful)
        #expect(result.errors.isEmpty)
    }

    @Test func binaryComparisonExpressions() {
        let analyzer = createAnalyzer()
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "result",
                type: .boolean,
                initialValue: .binary(.greater, .literal(.integer(5)), .literal(.integer(3)))
            ))
        ]

        let result = analyzer.analyze(statements)
        #expect(result.isSuccessful)
        #expect(result.errors.isEmpty)
    }

    @Test func binaryLogicalExpressions() {
        let analyzer = createAnalyzer()
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "result",
                type: .boolean,
                initialValue: .binary(.and, .literal(.boolean(true)), .literal(.boolean(false)))
            ))
        ]

        let result = analyzer.analyze(statements)
        #expect(result.isSuccessful)
        #expect(result.errors.isEmpty)
    }

    @Test func unaryExpressions() {
        let analyzer = createAnalyzer()
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
        #expect(result.isSuccessful)
        #expect(result.errors.isEmpty)
    }

    // MARK: - Function Declaration Tests

    @Test func simpleFunctionDeclaration() {
        let analyzer = createAnalyzer()
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
        #expect(result.isSuccessful)
        #expect(result.errors.isEmpty)
    }

    @Test func functionWithMissingReturnStatement() {
        let analyzer = createAnalyzer()
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
        #expect(!result.isSuccessful)
        #expect(result.errors.count == 1)

        if case .missingReturnStatement(let functionName, _) = result.errors[0] {
            #expect(functionName == "noReturn")
        } else {
            Issue.record("Expected missing return statement error")
        }
    }

    @Test func procedureDeclaration() {
        let analyzer = createAnalyzer()
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
        #expect(result.isSuccessful)
        #expect(result.errors.isEmpty)
    }

    @Test func duplicateFunctionDeclaration() {
        let analyzer = createAnalyzer()
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
        #expect(!result.isSuccessful)
        #expect(result.errors.count == 1)

        if case .functionAlreadyDeclared(let name, _) = result.errors[0] {
            #expect(name == "test")
        } else {
            Issue.record("Expected function already declared error")
        }
    }

    // MARK: - Function Call Tests

    @Test func builtinFunctionCall() {
        let analyzer = createAnalyzer()
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "input",
                type: .string,
                initialValue: .functionCall("readLine", [])
            ))
        ]

        let result = analyzer.analyze(statements)
        #expect(result.isSuccessful)
        #expect(result.errors.isEmpty)
    }

    @Test func functionCallWithCorrectArguments() {
        let analyzer = createAnalyzer()
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
        #expect(result.isSuccessful)
        #expect(result.errors.isEmpty)
    }

    @Test func functionCallWithIncorrectArgumentCount() {
        let analyzer = createAnalyzer()
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
        #expect(!result.isSuccessful)
        #expect(result.errors.count == 1)

        if case .incorrectArgumentCount(let function, let expected, let actual, _) = result.errors[0] {
            #expect(function == "add")
            #expect(expected == 2)
            #expect(actual == 1)
        } else {
            Issue.record("Expected incorrect argument count error")
        }
    }

    @Test func functionCallWithIncorrectArgumentType() {
        let analyzer = createAnalyzer()
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
        #expect(!result.isSuccessful)
        #expect(result.errors.count == 1)

        if case .argumentTypeMismatch(let function, let paramIndex, let expected, let actual, _) = result.errors[0] {
            #expect(function == "add")
            #expect(paramIndex == 1)
            #expect(expected == .integer)
            #expect(actual == .string)
        } else {
            Issue.record("Expected argument type mismatch error")
        }
    }

    @Test func undeclaredFunctionCall() {
        let analyzer = createAnalyzer()
        let statements = [
            Statement.expressionStatement(.functionCall("unknownFunction", []))
        ]

        let result = analyzer.analyze(statements)
        #expect(!result.isSuccessful)
        #expect(result.errors.count == 1)

        if case .undeclaredFunction(let name, _) = result.errors[0] {
            #expect(name == "unknownFunction")
        } else {
            Issue.record("Expected undeclared function error")
        }
    }

    // MARK: - Control Flow Tests

    @Test func ifStatementWithBooleanCondition() {
        let analyzer = createAnalyzer()
        let statements = [
            Statement.ifStatement(IfStatement(
                condition: .literal(.boolean(true)),
                thenBody: [
                    Statement.expressionStatement(.literal(.integer(1)))
                ]
            ))
        ]

        let result = analyzer.analyze(statements)
        #expect(result.isSuccessful)
        #expect(result.errors.isEmpty)
    }

    @Test func ifStatementWithNonBooleanCondition() {
        let analyzer = createAnalyzer()
        let statements = [
            Statement.ifStatement(IfStatement(
                condition: .literal(.integer(1)),
                thenBody: [
                    Statement.expressionStatement(.literal(.integer(1)))
                ]
            ))
        ]

        let result = analyzer.analyze(statements)
        #expect(!result.isSuccessful)
        #expect(result.errors.count == 1)

        if case .typeMismatch(let expected, let actual, _) = result.errors[0] {
            #expect(expected == .boolean)
            #expect(actual == .integer)
        } else {
            Issue.record("Expected type mismatch error")
        }
    }

    @Test func whileStatementWithBooleanCondition() {
        let analyzer = createAnalyzer()
        let statements = [
            Statement.whileStatement(WhileStatement(
                condition: .literal(.boolean(true)),
                body: [
                    Statement.breakStatement
                ]
            ))
        ]

        let result = analyzer.analyze(statements)
        #expect(result.isSuccessful)
        #expect(result.errors.isEmpty)
    }

    @Test func forRangeStatement() {
        let analyzer = createAnalyzer()
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
        #expect(result.isSuccessful)
        #expect(result.errors.isEmpty)
    }

    // MARK: - Return Statement Tests

    @Test func returnStatementInFunction() {
        let analyzer = createAnalyzer()
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
        #expect(result.isSuccessful)
        #expect(result.errors.isEmpty)
    }

    @Test func returnStatementOutsideFunction() {
        let analyzer = createAnalyzer()
        let statements = [
            Statement.returnStatement(ReturnStatement(expression: .literal(.integer(42))))
        ]

        let result = analyzer.analyze(statements)
        #expect(!result.isSuccessful)
        #expect(result.errors.count == 1)

        if case .returnOutsideFunction = result.errors[0] {
            // Expected
        } else {
            Issue.record("Expected return outside function error")
        }
    }

    @Test func returnTypeMismatch() {
        let analyzer = createAnalyzer()
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
        #expect(!result.isSuccessful)
        #expect(result.errors.count == 1)

        if case .returnTypeMismatch(let function, let expected, let actual, _) = result.errors[0] {
            #expect(function == "getValue")
            #expect(expected == .integer)
            #expect(actual == .string)
        } else {
            Issue.record("Expected return type mismatch error")
        }
    }

    // MARK: - Break Statement Tests

    @Test func breakStatementInLoop() {
        let analyzer = createAnalyzer()
        let statements = [
            Statement.whileStatement(WhileStatement(
                condition: .literal(.boolean(true)),
                body: [
                    Statement.breakStatement
                ]
            ))
        ]

        let result = analyzer.analyze(statements)
        #expect(result.isSuccessful)
        #expect(result.errors.isEmpty)
    }

    @Test func breakStatementOutsideLoop() {
        let analyzer = createAnalyzer()
        let statements = [
            Statement.breakStatement
        ]

        let result = analyzer.analyze(statements)
        #expect(!result.isSuccessful)
        #expect(result.errors.count == 1)

        if case .breakOutsideLoop = result.errors[0] {
            // Expected
        } else {
            Issue.record("Expected break outside loop error")
        }
    }

    // MARK: - Scope Tests

    @Test func variableScope() {
        let analyzer = createAnalyzer()
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
        #expect(result.isSuccessful)
        #expect(result.errors.isEmpty)
    }

    // MARK: - Configuration Tests

    @Test func analyzerWithStrictConfig() {
        let strictAnalyzer = SemanticAnalyzer(config: .strict)
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "x",
                type: .integer,
                initialValue: .literal(.string("hello"))
            ))
        ]

        let result = strictAnalyzer.analyze(statements)
        #expect(!result.isSuccessful)
        #expect(!result.errors.isEmpty)
    }

    @Test func analyzerWithFastConfig() {
        let fastAnalyzer = SemanticAnalyzer(config: .fast)
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "x",
                type: .integer,
                initialValue: .literal(.integer(42))
            ))
        ]

        let result = fastAnalyzer.analyze(statements)
        #expect(result.isSuccessful)
        #expect(result.errors.isEmpty)
    }

    // MARK: - Enhanced Type Compatibility Tests

    @Test func stringConcatenationWithPlusOperator() {
        let analyzer = createAnalyzer()
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "result",
                type: .string,
                initialValue: .binary(.add, .literal(.string("Hello")), .literal(.string(" World")))
            ))
        ]

        let result = analyzer.analyze(statements)
        #expect(result.isSuccessful)
        #expect(result.errors.isEmpty)
    }

    @Test func characterToStringCompatibility() {
        let analyzer = createAnalyzer()
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "message",
                type: .string,
                initialValue: .literal(.character("A"))
            ))
        ]

        let result = analyzer.analyze(statements)
        #expect(result.isSuccessful)
        #expect(result.errors.isEmpty)
    }

    @Test func characterStringConcatenation() {
        let analyzer = createAnalyzer()
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "result",
                type: .string,
                initialValue: .binary(.add, .literal(.character("H")), .literal(.string("ello")))
            ))
        ]

        let result = analyzer.analyze(statements)
        #expect(result.isSuccessful)
        #expect(result.errors.isEmpty)
    }

    // MARK: - Enhanced Validation Tests

    @Test func duplicateParameterNames() {
        let analyzer = createAnalyzer()
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
        #expect(!result.isSuccessful)
        #expect(result.errors.count == 1)

        if case .variableAlreadyDeclared(let name, _) = result.errors[0] {
            #expect(name == "param")
        } else {
            Issue.record("Expected variable already declared error")
        }
    }

    @Test func unreachableCodeAfterReturn() {
        let analyzer = createAnalyzer()
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
        #expect(!result.isSuccessful)
        #expect(result.errors.count == 1)

        if case .unreachableCode = result.errors[0] {
            // Expected
        } else {
            Issue.record("Expected unreachable code error")
        }
    }

    @Test func arrayTypeCompatibility() {
        let analyzer = createAnalyzer()
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
        #expect(!result.isSuccessful)
        #expect(result.errors.count == 1)

        if case .typeMismatch(let expected, let actual, _) = result.errors[0] {
            #expect(expected == .array(elementType: .string, dimensions: []))
            #expect(actual == .array(elementType: .integer, dimensions: []))
        } else {
            Issue.record("Expected type mismatch error")
        }
    }

    // MARK: - Integration Tests

    @Test func complexSemanticAnalysis() {
        let analyzer = createAnalyzer()
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
        #expect(result.isSuccessful)
        #expect(result.errors.isEmpty)
    }

    // MARK: - Performance Tests

    @Test func analysisPerformance() {
        let analyzer = createAnalyzer()
        // Generate a large number of statements
        var statements: [Statement] = []
        for index in 0..<1000 {
            statements.append(Statement.variableDeclaration(VariableDeclaration(
                name: "var\(index)",
                type: .integer,
                initialValue: .literal(.integer(index))
            )))
        }

        let result = analyzer.analyze(statements)
        #expect(result.isSuccessful)
    }
}
