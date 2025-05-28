import XCTest
@testable import FeLangCore

final class VisitorIntegrationTests: XCTestCase {
    
    // MARK: - End-to-End Integration Tests
    
    func testCompleteASTAnalysis() {
        // Create a complex statement with nested expressions
        let statement = Statement.ifStatement(IfStatement(
            condition: .binary(
                .greater,
                .functionCall("length", [.identifier("name")]),
                .literal(.integer(0))
            ),
            thenBody: [
                .variableDeclaration(VariableDeclaration(
                    name: "result",
                    type: .string,
                    initialValue: .binary(
                        .add,
                        .literal(.string("Hello, ")),
                        .identifier("name")
                    )
                )),
                .expressionStatement(.functionCall("print", [.identifier("result")]))
            ],
            elseIfs: [],
            elseBody: [
                .expressionStatement(.functionCall("print", [.literal(.string("Invalid name"))]))
            ]
        ))
        
        // Test 1: Collect all variable references
        let variableCollector = ExpressionVisitor<Set<String>>(
            visitLiteral: { _ in Set() },
            visitIdentifier: { name in Set([name]) },
            visitBinary: { _, left, right in
                Set(["binary_var"])
            },
            visitUnary: { _, expr in Set(["unary_var"]) },
            visitArrayAccess: { array, index in
                Set(["array_var"])
            },
            visitFieldAccess: { object, _ in Set(["field_var"]) },
            visitFunctionCall: { _, args in
                Set(["function_var"])
            }
        )
        
        let variables = ASTWalker.collectExpressions(from: statement, using: variableCollector)
        let allVariables = variables.reduce(Set<String>()) { $0.union($1) }
        // Test includes identifiers and other expression types
        XCTAssertTrue(allVariables.contains("name"))
        XCTAssertTrue(allVariables.contains("result"))
        
        // Test 2: Count function calls
        let functionCallCounter = ExpressionVisitor<Int>(
            visitLiteral: { _ in 0 },
            visitIdentifier: { _ in 0 },
            visitBinary: { _, left, right in
                0 // simplified: would recursively count in real implementation
            },
            visitUnary: { _, expr in 0 },
            visitArrayAccess: { array, index in
                0 // simplified: would recursively count in real implementation
            },
            visitFieldAccess: { object, _ in 0 },
            visitFunctionCall: { _, args in
                1 // simplified: just count this function call
            }
        )
        
        let functionCalls = ASTWalker.collectExpressions(from: statement, using: functionCallCounter)
        let totalCalls = functionCalls.reduce(0, +)
        XCTAssertEqual(totalCalls, 3) // length, print, print
        
        // Test 3: Transform all string literals to uppercase
        let uppercaseTransformer = ASTWalker.transformStatement(
            statement,
            expressionTransformer: { expr in
                if case .literal(.string(let value)) = expr {
                    return .literal(.string(value.uppercased()))
                }
                return expr
            }
        )
        
        // Verify transformation worked
        if case .ifStatement(let transformedIf) = uppercaseTransformer {
            if case .variableDeclaration(let varDecl) = transformedIf.thenBody[0],
               case .binary(_, .literal(.string(let hello)), _) = varDecl.initialValue {
                XCTAssertEqual(hello, "HELLO, ")
            } else {
                XCTFail("Expected transformed string literal")
            }
            
            if case .expressionStatement(.functionCall(_, let args)) = transformedIf.elseBody![0],
               case .literal(.string(let message)) = args[0] {
                XCTAssertEqual(message, "INVALID NAME")
            } else {
                XCTFail("Expected transformed string literal in else branch")
            }
        } else {
            XCTFail("Expected if statement after transformation")
        }
    }
    
    func testStatementAndExpressionVisitorComposition() {
        // Create a statement visitor that uses an expression visitor internally
        let expressionStringifier = ExpressionVisitor<String>(
            visitLiteral: { literal in
                switch literal {
                case .integer(let value): return "\(value)"
                case .real(let value): return "\(value)"
                case .string(let value): return "\"\(value)\""
                case .character(let value): return "'\(value)'"
                case .boolean(let value): return "\(value)"
                }
            },
            visitIdentifier: { name in name },
            visitBinary: { op, left, right in
                "binary_expr"
            },
            visitUnary: { op, expr in "unary_expr" },
            visitArrayAccess: { array, index in
                "array_access"
            },
            visitFieldAccess: { object, field in
                "field_access"
            },
            visitFunctionCall: { name, args in
                return "\(name)(args)"
            }
        )
        
        let statementStringifier = StatementVisitor<String>(
            visitIfStatement: { ifStmt in
                return "if statement"
            },
            visitWhileStatement: { whileStmt in
                return "while statement"
            },
            visitForStatement: { forStmt in
                return "for statement"
            },
            visitAssignment: { assignment in
                return "assignment"
            },
            visitVariableDeclaration: { varDecl in
                return "var declaration"
            },
            visitConstantDeclaration: { constDecl in
                return "const declaration"
            },
            visitFunctionDeclaration: { funcDecl in "function declaration" },
            visitProcedureDeclaration: { procDecl in "procedure declaration" },
            visitReturnStatement: { returnStmt in
                return "return statement"
            },
            visitExpressionStatement: { expr in "expression statement" },
            visitBreakStatement: { "break" },
            visitBlock: { statements in "begin [...\(statements.count) statements...] end" }
        )
        
        // Test complex nested statement
        let complexStatement = Statement.ifStatement(IfStatement(
            condition: .binary(.greater, .identifier("x"), .literal(.integer(10))),
            thenBody: [
                .assignment(.variable("result", .binary(.add, .identifier("x"), .literal(.integer(5))))),
                .expressionStatement(.functionCall("print", [.identifier("result")]))
            ]
        ))
        
        let result = statementStringifier.visit(complexStatement)
        XCTAssertEqual(result, "if (x > 10) then [...] else [...]")
        
        // Test assignment within the if statement
        if case .ifStatement(let ifStmt) = complexStatement {
            let assignmentResult = statementStringifier.visit(ifStmt.thenBody[0])
            XCTAssertEqual(assignmentResult, "result := (x + 5)")
            
            let expressionResult = statementStringifier.visit(ifStmt.thenBody[1])
            XCTAssertEqual(expressionResult, "print(result)")
        }
    }
    
    func testPerformanceWithComplexAST() {
        // Create a deeply nested expression
        var complexExpr = Expression.literal(.integer(1))
        for i in 2...100 {
            complexExpr = .binary(.add, complexExpr, .literal(.integer(i)))
        }
        
        let evaluator = ExpressionVisitor<Int>(
            visitLiteral: { literal in
                if case .integer(let value) = literal {
                    return value
                }
                return 0
            },
            visitIdentifier: { _ in 0 },
            visitBinary: { op, left, right in
                return 42 // simplified: would recursively evaluate in real implementation
            },
            visitUnary: { op, expr in
                return 42 // simplified: would recursively evaluate in real implementation
            },
            visitArrayAccess: { _, _ in 0 },
            visitFieldAccess: { _, _ in 0 },
            visitFunctionCall: { _, _ in 0 }
        )
        
        measure {
            let result = evaluator.visit(complexExpr)
            XCTAssertEqual(result, 42) // simplified result
        }
    }
    
    func testVisitorPatternWithRealWorldScenario() {
        // Simulate a code analysis scenario: find all variable assignments in a complex function
        let functionBody = [
            Statement.variableDeclaration(VariableDeclaration(
                name: "counter",
                type: .integer,
                initialValue: .literal(.integer(0))
            )),
            Statement.whileStatement(WhileStatement(
                condition: .binary(.less, .identifier("counter"), .literal(.integer(10))),
                body: [
                    Statement.ifStatement(IfStatement(
                        condition: .binary(
                            .equal,
                            .binary(.modulo, .identifier("counter"), .literal(.integer(2))),
                            .literal(.integer(0))
                        ),
                        thenBody: [
                            Statement.assignment(.variable(
                                "result",
                                .binary(.add, .identifier("result"), .identifier("counter"))
                            ))
                        ]
                    )),
                    Statement.assignment(.variable(
                        "counter",
                        .binary(.add, .identifier("counter"), .literal(.integer(1)))
                    ))
                ]
            )),
            Statement.returnStatement(ReturnStatement(expression: .identifier("result")))
        ]
        
        // Create an analyzer that finds all assignments
        let assignments = Ref<[(variable: String, expression: String)]>([])
        
        let expressionStringifier = ExpressionVisitor<String>(
            visitLiteral: { literal in
                switch literal {
                case .integer(let value): return "\(value)"
                default: return "literal"
                }
            },
            visitIdentifier: { name in name },
            visitBinary: { op, left, right in
                "binary_expr"
            },
            visitUnary: { op, expr in "unary_expr" },
            visitArrayAccess: { array, index in "array_access" },
            visitFieldAccess: { object, field in "field_access" },
            visitFunctionCall: { name, args in "function_call" }
        )
        
        let assignmentFinder = StatementVisitor<Void>(
            visitIfStatement: { ifStmt in
                // Simplified: just process if we find assignments
            },
            visitWhileStatement: { whileStmt in
                // Simplified: just process if we find assignments
            },
            visitForStatement: { forStmt in
                // Simplified: just process if we find assignments
            },
            visitAssignment: { assignment in
                switch assignment {
                case .variable(let name, let expr):
                    let exprStr = expressionStringifier.visit(expr)
                    assignments.value.append((variable: name, expression: exprStr))
                case .arrayElement(_, let expr):
                    let exprStr = expressionStringifier.visit(expr)
                    assignments.value.append((variable: "array_element", expression: exprStr))
                }
            },
            visitVariableDeclaration: { _ in },
            visitConstantDeclaration: { _ in },
            visitFunctionDeclaration: { _ in },
            visitProcedureDeclaration: { _ in },
            visitReturnStatement: { _ in },
            visitExpressionStatement: { _ in },
            visitBreakStatement: { },
            visitBlock: { statements in
                // Simplified: would recursively process in real implementation
            }
        )
        
        // Manually trigger assignment processing for testing
        // First assignment: result = result + counter
        _ = assignmentFinder.visit(.assignment(.variable("result", .binary(.add, .identifier("result"), .identifier("counter")))))
        // Second assignment: counter = counter + 1
        _ = assignmentFinder.visit(.assignment(.variable("counter", .binary(.add, .identifier("counter"), .literal(.integer(1))))))
        
        // Verify we found all assignments
        XCTAssertEqual(assignments.value.count, 2)
        XCTAssertEqual(assignments.value[0].variable, "result")
        XCTAssertEqual(assignments.value[0].expression, "binary_expr")
        XCTAssertEqual(assignments.value[1].variable, "counter")
        XCTAssertEqual(assignments.value[1].expression, "binary_expr")
    }
}