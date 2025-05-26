import XCTest
@testable import FeLangCore

final class StatementVisitorTests: XCTestCase {
    
    // MARK: - Basic Functionality Tests
    
    func testStatementVisitorBasicFunctionality() {
        let visitor = StatementVisitor<String>(
            visitIfStatement: { ifStmt in "If(\(ifStmt.condition))" },
            visitWhileStatement: { whileStmt in "While(\(whileStmt.condition))" },
            visitForStatement: { forStmt in 
                switch forStmt {
                case .range(let rangeFor):
                    return "ForRange(\(rangeFor.variable), \(rangeFor.start), \(rangeFor.end))"
                case .forEach(let forEach):
                    return "ForEach(\(forEach.variable), \(forEach.iterable))"
                }
            },
            visitAssignment: { assignment in
                switch assignment {
                case .variable(let name, let expr):
                    return "Assignment(\(name), \(expr))"
                case .arrayElement(let arrayAccess, let expr):
                    return "ArrayAssignment(\(arrayAccess.array)[\(arrayAccess.index)], \(expr))"
                }
            },
            visitVariableDeclaration: { varDecl in "VarDecl(\(varDecl.name), \(varDecl.type))" },
            visitConstantDeclaration: { constDecl in "ConstDecl(\(constDecl.name), \(constDecl.type))" },
            visitFunctionDeclaration: { funcDecl in "FuncDecl(\(funcDecl.name))" },
            visitProcedureDeclaration: { procDecl in "ProcDecl(\(procDecl.name))" },
            visitReturnStatement: { returnStmt in "Return(\(returnStmt.expression?.description ?? "void"))" },
            visitExpressionStatement: { expr in "ExprStmt(\(expr))" },
            visitBreakStatement: { "Break" },
            visitBlock: { statements in "Block(\(statements.count))" }
        )
        
        // Test if statement
        let ifStmt = IfStatement(
            condition: .literal(.boolean(true)),
            thenBody: [.breakStatement],
            elseIfs: [],
            elseBody: nil
        )
        let ifStatement = Statement.ifStatement(ifStmt)
        XCTAssertEqual(visitor.visit(ifStatement), "If(true)")
        
        // Test while statement
        let whileStmt = WhileStatement(
            condition: .identifier("condition"),
            body: [.breakStatement]
        )
        let whileStatement = Statement.whileStatement(whileStmt)
        XCTAssertEqual(visitor.visit(whileStatement), "While(condition)")
        
        // Test for statement (range)
        let rangeFor = ForStatement.RangeFor(
            variable: "i",
            start: .literal(.integer(0)),
            end: .literal(.integer(10)),
            step: nil,
            body: [.breakStatement]
        )
        let forStatement = Statement.forStatement(.range(rangeFor))
        XCTAssertEqual(visitor.visit(forStatement), "ForRange(i, 0, 10)")
        
        // Test assignment
        let assignment = Assignment.variable("x", .literal(.integer(42)))
        let assignmentStatement = Statement.assignment(assignment)
        XCTAssertEqual(visitor.visit(assignmentStatement), "Assignment(x, 42)")
        
        // Test variable declaration
        let varDecl = VariableDeclaration(name: "x", type: .integer, initialValue: .literal(.integer(0)))
        let varStatement = Statement.variableDeclaration(varDecl)
        XCTAssertEqual(visitor.visit(varStatement), "VarDecl(x, integer)")
        
        // Test constant declaration
        let constDecl = ConstantDeclaration(name: "PI", type: .real, initialValue: .literal(.real(3.14)))
        let constStatement = Statement.constantDeclaration(constDecl)
        XCTAssertEqual(visitor.visit(constStatement), "ConstDecl(PI, real)")
        
        // Test function declaration
        let funcDecl = FunctionDeclaration(name: "test", parameters: [], returnType: .integer, body: [])
        let funcStatement = Statement.functionDeclaration(funcDecl)
        XCTAssertEqual(visitor.visit(funcStatement), "FuncDecl(test)")
        
        // Test procedure declaration
        let procDecl = ProcedureDeclaration(name: "test", parameters: [], body: [])
        let procStatement = Statement.procedureDeclaration(procDecl)
        XCTAssertEqual(visitor.visit(procStatement), "ProcDecl(test)")
        
        // Test return statement
        let returnStmt = ReturnStatement(expression: .literal(.integer(42)))
        let returnStatement = Statement.returnStatement(returnStmt)
        XCTAssertEqual(visitor.visit(returnStatement), "Return(42)")
        
        // Test expression statement
        let exprStatement = Statement.expressionStatement(.identifier("x"))
        XCTAssertEqual(visitor.visit(exprStatement), "ExprStmt(x)")
        
        // Test break statement
        XCTAssertEqual(visitor.visit(.breakStatement), "Break")
        
        // Test block statement
        let blockStatement = Statement.block([.breakStatement, .breakStatement])
        XCTAssertEqual(visitor.visit(blockStatement), "Block(2)")
    }
    
    func testStatementVisitorWithDifferentResultTypes() {
        // Test with Int result type (counting nodes)
        let countingVisitor = StatementVisitor<Int>(
            visitIfStatement: { _ in 1 },
            visitWhileStatement: { _ in 1 },
            visitForStatement: { _ in 1 },
            visitAssignment: { _ in 1 },
            visitVariableDeclaration: { _ in 1 },
            visitConstantDeclaration: { _ in 1 },
            visitFunctionDeclaration: { _ in 1 },
            visitProcedureDeclaration: { _ in 1 },
            visitReturnStatement: { _ in 1 },
            visitExpressionStatement: { _ in 1 },
            visitBreakStatement: { 1 },
            visitBlock: { statements in statements.count }
        )
        
        let blockStatement = Statement.block([.breakStatement, .breakStatement, .breakStatement])
        XCTAssertEqual(countingVisitor.visit(blockStatement), 3)
        
        // Test with Bool result type (checking for specific statements)
        let hasReturnVisitor = StatementVisitor<Bool>(
            visitIfStatement: { _ in false },
            visitWhileStatement: { _ in false },
            visitForStatement: { _ in false },
            visitAssignment: { _ in false },
            visitVariableDeclaration: { _ in false },
            visitConstantDeclaration: { _ in false },
            visitFunctionDeclaration: { _ in false },
            visitProcedureDeclaration: { _ in false },
            visitReturnStatement: { _ in true },
            visitExpressionStatement: { _ in false },
            visitBreakStatement: { false },
            visitBlock: { _ in false }
        )
        
        let returnStatement = Statement.returnStatement(ReturnStatement())
        XCTAssertTrue(hasReturnVisitor.visit(returnStatement))
        XCTAssertFalse(hasReturnVisitor.visit(.breakStatement))
    }
    
    // MARK: - Complex Statement Tests
    
    func testComplexIfStatement() {
        let visitor = StatementVisitor.debugStringifier()
        
        let elseIf = IfStatement.ElseIf(
            condition: .identifier("condition2"),
            body: [.breakStatement]
        )
        
        let ifStmt = IfStatement(
            condition: .identifier("condition1"),
            thenBody: [.breakStatement],
            elseIfs: [elseIf],
            elseBody: [.breakStatement]
        )
        
        let result = visitor.visit(.ifStatement(ifStmt))
        XCTAssertTrue(result.contains("condition1"))
        XCTAssertTrue(result.contains("elif"))
        XCTAssertTrue(result.contains("else"))
    }
    
    func testForStatementVariants() {
        let visitor = StatementVisitor.debugStringifier()
        
        // Test range for
        let rangeFor = ForStatement.RangeFor(
            variable: "i",
            start: .literal(.integer(1)),
            end: .literal(.integer(10)),
            step: .literal(.integer(2)),
            body: []
        )
        let rangeStatement = Statement.forStatement(.range(rangeFor))
        let rangeResult = visitor.visit(rangeStatement)
        XCTAssertTrue(rangeResult.contains("for i = 1 to 10"))
        
        // Test forEach
        let forEach = ForStatement.ForEachLoop(
            variable: "item",
            iterable: .identifier("collection"),
            body: []
        )
        let forEachStatement = Statement.forStatement(.forEach(forEach))
        let forEachResult = visitor.visit(forEachStatement)
        XCTAssertTrue(forEachResult.contains("for item in collection"))
    }
    
    func testAssignmentVariants() {
        let visitor = StatementVisitor.debugStringifier()
        
        // Test variable assignment
        let varAssignment = Assignment.variable("x", .literal(.integer(42)))
        let varResult = visitor.visit(.assignment(varAssignment))
        XCTAssertEqual(varResult, "x = 42")
        
        // Test array element assignment
        let arrayAccess = Assignment.ArrayAccess(
            array: .identifier("arr"),
            index: .literal(.integer(0))
        )
        let arrayAssignment = Assignment.arrayElement(arrayAccess, .literal(.integer(100)))
        let arrayResult = visitor.visit(.assignment(arrayAssignment))
        XCTAssertEqual(arrayResult, "arr[0] = 100")
    }
    
    func testFunctionAndProcedureDeclarations() {
        let visitor = StatementVisitor.debugStringifier()
        
        // Test function with parameters
        let params = [
            Parameter(name: "x", type: .integer),
            Parameter(name: "y", type: .real)
        ]
        let funcDecl = FunctionDeclaration(
            name: "calculate",
            parameters: params,
            returnType: .real,
            body: []
        )
        let funcResult = visitor.visit(.functionDeclaration(funcDecl))
        XCTAssertEqual(funcResult, "function calculate(2 params)")
        
        // Test procedure with parameters
        let procDecl = ProcedureDeclaration(
            name: "process",
            parameters: params,
            body: []
        )
        let procResult = visitor.visit(.procedureDeclaration(procDecl))
        XCTAssertEqual(procResult, "procedure process(2 params)")
    }
    
    // MARK: - Visitable Protocol Tests
    
    func testVisitableProtocolConformance() {
        let visitor = StatementVisitor.debugStringifier()
        let statement = Statement.breakStatement
        
        // Test that Statement conforms to Visitable
        let result = statement.accept(visitor)
        XCTAssertEqual(result, "break")
    }
    
    func testArrayVisitableExtension() {
        let visitor = StatementVisitor<Int>(
            visitIfStatement: { _ in 1 },
            visitWhileStatement: { _ in 2 },
            visitForStatement: { _ in 3 },
            visitAssignment: { _ in 4 },
            visitVariableDeclaration: { _ in 5 },
            visitConstantDeclaration: { _ in 6 },
            visitFunctionDeclaration: { _ in 7 },
            visitProcedureDeclaration: { _ in 8 },
            visitReturnStatement: { _ in 9 },
            visitExpressionStatement: { _ in 10 },
            visitBreakStatement: { 11 },
            visitBlock: { _ in 12 }
        )
        
        let statements: [Statement] = [
            .breakStatement,
            .returnStatement(ReturnStatement())
        ]
        
        let results = statements.accept(visitor)
        XCTAssertEqual(results, [11, 9])
    }
    
    // MARK: - Custom Result Type Tests
    
    struct StatementAnalysis: Equatable, Sendable {
        let type: String
        let complexity: Int
        let hasExpression: Bool
    }
    
    func testCustomResultType() {
        let analyzer = StatementVisitor<StatementAnalysis>(
            visitIfStatement: { ifStmt in
                let complexity = 1 + ifStmt.elseIfs.count + (ifStmt.elseBody != nil ? 1 : 0)
                return StatementAnalysis(type: "if", complexity: complexity, hasExpression: true)
            },
            visitWhileStatement: { _ in
                StatementAnalysis(type: "while", complexity: 2, hasExpression: true)
            },
            visitForStatement: { _ in
                StatementAnalysis(type: "for", complexity: 3, hasExpression: true)
            },
            visitAssignment: { _ in
                StatementAnalysis(type: "assignment", complexity: 1, hasExpression: true)
            },
            visitVariableDeclaration: { varDecl in
                StatementAnalysis(type: "varDecl", complexity: 1, hasExpression: varDecl.initialValue != nil)
            },
            visitConstantDeclaration: { _ in
                StatementAnalysis(type: "constDecl", complexity: 1, hasExpression: true)
            },
            visitFunctionDeclaration: { funcDecl in
                StatementAnalysis(type: "funcDecl", complexity: funcDecl.parameters.count, hasExpression: false)
            },
            visitProcedureDeclaration: { procDecl in
                StatementAnalysis(type: "procDecl", complexity: procDecl.parameters.count, hasExpression: false)
            },
            visitReturnStatement: { returnStmt in
                StatementAnalysis(type: "return", complexity: 1, hasExpression: returnStmt.expression != nil)
            },
            visitExpressionStatement: { _ in
                StatementAnalysis(type: "expression", complexity: 1, hasExpression: true)
            },
            visitBreakStatement: {
                StatementAnalysis(type: "break", complexity: 0, hasExpression: false)
            },
            visitBlock: { statements in
                StatementAnalysis(type: "block", complexity: statements.count, hasExpression: false)
            }
        )
        
        let elseIf = IfStatement.ElseIf(condition: .literal(.boolean(true)), body: [])
        let ifStmt = IfStatement(
            condition: .literal(.boolean(true)),
            thenBody: [],
            elseIfs: [elseIf],
            elseBody: []
        )
        
        let result = analyzer.visit(.ifStatement(ifStmt))
        XCTAssertEqual(result.type, "if")
        XCTAssertEqual(result.complexity, 3) // 1 (base) + 1 (elseIf) + 1 (else)
        XCTAssertTrue(result.hasExpression)
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceComparedToDirectSwitch() {
        let statement = createComplexStatement(depth: 5)
        
        // Direct switch implementation
        func processDirectly(_ stmt: Statement) -> String {
            switch stmt {
            case .ifStatement(let ifStmt):
                return "if(\(ifStmt.condition))"
            case .whileStatement(let whileStmt):
                return "while(\(whileStmt.condition))"
            case .forStatement(let forStmt):
                switch forStmt {
                case .range(let rangeFor):
                    return "for(\(rangeFor.variable))"
                case .forEach(let forEach):
                    return "forEach(\(forEach.variable))"
                }
            case .assignment(let assignment):
                switch assignment {
                case .variable(let name, _):
                    return "assign(\(name))"
                case .arrayElement(_, _):
                    return "arrayAssign"
                }
            case .variableDeclaration(let varDecl):
                return "var(\(varDecl.name))"
            case .constantDeclaration(let constDecl):
                return "const(\(constDecl.name))"
            case .functionDeclaration(let funcDecl):
                return "func(\(funcDecl.name))"
            case .procedureDeclaration(let procDecl):
                return "proc(\(procDecl.name))"
            case .returnStatement:
                return "return"
            case .expressionStatement:
                return "expr"
            case .breakStatement:
                return "break"
            case .block(let statements):
                return "block(\(statements.count))"
            }
        }
        
        // Visitor implementation
        let visitor = StatementVisitor<String>(
            visitIfStatement: { ifStmt in "if(\(ifStmt.condition))" },
            visitWhileStatement: { whileStmt in "while(\(whileStmt.condition))" },
            visitForStatement: { forStmt in
                switch forStmt {
                case .range(let rangeFor):
                    return "for(\(rangeFor.variable))"
                case .forEach(let forEach):
                    return "forEach(\(forEach.variable))"
                }
            },
            visitAssignment: { assignment in
                switch assignment {
                case .variable(let name, _):
                    return "assign(\(name))"
                case .arrayElement(_, _):
                    return "arrayAssign"
                }
            },
            visitVariableDeclaration: { varDecl in "var(\(varDecl.name))" },
            visitConstantDeclaration: { constDecl in "const(\(constDecl.name))" },
            visitFunctionDeclaration: { funcDecl in "func(\(funcDecl.name))" },
            visitProcedureDeclaration: { procDecl in "proc(\(procDecl.name))" },
            visitReturnStatement: { _ in "return" },
            visitExpressionStatement: { _ in "expr" },
            visitBreakStatement: { "break" },
            visitBlock: { statements in "block(\(statements.count))" }
        )
        
        // Measure direct switch performance
        let directSwitchTime = measureTime {
            let _ = processDirectly(statement)
        }
        
        // Measure visitor performance
        let visitorTime = measureTime {
            let _ = visitor.visit(statement)
        }
        
        // Visitor should be within 50% of direct switch performance (allowing for test variability)
        let performanceRatio = visitorTime / directSwitchTime
        XCTAssertLessThan(performanceRatio, 1.5, "Visitor performance should be within 50% of direct switch")
    }
    
    // MARK: - Thread Safety Tests
    
    func testThreadSafety() {
        let visitor = StatementVisitor<String>(
            visitIfStatement: { _ in "if" },
            visitWhileStatement: { _ in "while" },
            visitForStatement: { _ in "for" },
            visitAssignment: { _ in "assignment" },
            visitVariableDeclaration: { _ in "var" },
            visitConstantDeclaration: { _ in "const" },
            visitFunctionDeclaration: { _ in "func" },
            visitProcedureDeclaration: { _ in "proc" },
            visitReturnStatement: { _ in "return" },
            visitExpressionStatement: { _ in "expr" },
            visitBreakStatement: { "break" },
            visitBlock: { _ in "block" }
        )
        
        let statements = (0..<100).map { i in
            Statement.assignment(.variable("x\(i)", .literal(.integer(i))))
        }
        
        let expectation = XCTestExpectation(description: "Thread safety test")
        expectation.expectedFulfillmentCount = statements.count
        
        DispatchQueue.concurrentPerform(iterations: statements.count) { index in
            let result = visitor.visit(statements[index])
            XCTAssertEqual(result, "assignment")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Debug Stringifier Tests
    
    func testDebugStringifier() {
        let visitor = StatementVisitor.debugStringifier()
        
        // Test various statements
        XCTAssertEqual(visitor.visit(.breakStatement), "break")
        
        let returnStmt = ReturnStatement(expression: .literal(.integer(42)))
        XCTAssertEqual(visitor.visit(.returnStatement(returnStmt)), "return 42")
        
        let returnVoid = ReturnStatement(expression: nil)
        XCTAssertEqual(visitor.visit(.returnStatement(returnVoid)), "return")
        
        let assignment = Assignment.variable("x", .literal(.integer(10)))
        XCTAssertEqual(visitor.visit(.assignment(assignment)), "x = 10")
        
        let varDecl = VariableDeclaration(name: "y", type: .string, initialValue: .literal(.string("hello")))
        XCTAssertEqual(visitor.visit(.variableDeclaration(varDecl)), "var y: string = \"hello\"")
    }
    
    // MARK: - Helper Methods
    
    private func createComplexStatement(depth: Int) -> Statement {
        if depth <= 0 {
            return .breakStatement
        }
        
        let ifStmt = IfStatement(
            condition: .literal(.boolean(true)),
            thenBody: [createComplexStatement(depth: depth - 1)],
            elseIfs: [],
            elseBody: [createComplexStatement(depth: depth - 1)]
        )
        
        return .ifStatement(ifStmt)
    }
    
    private func measureTime(_ block: () -> Void) -> TimeInterval {
        let startTime = CFAbsoluteTimeGetCurrent()
        block()
        let endTime = CFAbsoluteTimeGetCurrent()
        return endTime - startTime
    }
}