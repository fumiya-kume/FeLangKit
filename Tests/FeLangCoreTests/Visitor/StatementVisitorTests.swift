import XCTest
@testable import FeLangCore

final class StatementVisitorTests: XCTestCase {
    
    // MARK: - Basic Statement Visitor Tests
    
    func testIfStatementVisitor() {
        let condition = Expression.literal(.boolean(true))
        let thenBody = [Statement.breakStatement]
        let ifStatement = IfStatement(condition: condition, thenBody: thenBody)
        let stmt = Statement.ifStatement(ifStatement)
        
        let visitor = StatementVisitor<String>(
            visitIfStatement: { ifStmt in
                return "If(\(ifStmt.thenBody.count) statements)"
            },
            visitWhileStatement: { _ in "" },
            visitForStatement: { _ in "" },
            visitAssignment: { _ in "" },
            visitVariableDeclaration: { _ in "" },
            visitConstantDeclaration: { _ in "" },
            visitFunctionDeclaration: { _ in "" },
            visitProcedureDeclaration: { _ in "" },
            visitReturnStatement: { _ in "" },
            visitExpressionStatement: { _ in "" },
            visitBreakStatement: { "Break" },
            visitBlock: { _ in "" }
        )
        
        let result = visitor.visit(stmt)
        XCTAssertEqual(result, "If(1 statements)")
    }
    
    func testWhileStatementVisitor() {
        let condition = Expression.literal(.boolean(true))
        let body = [Statement.breakStatement, Statement.breakStatement]
        let whileStmt = WhileStatement(condition: condition, body: body)
        let stmt = Statement.whileStatement(whileStmt)
        
        let visitor = StatementVisitor<String>(
            visitIfStatement: { _ in "" },
            visitWhileStatement: { whileStmt in
                return "While(\(whileStmt.body.count) statements)"
            },
            visitForStatement: { _ in "" },
            visitAssignment: { _ in "" },
            visitVariableDeclaration: { _ in "" },
            visitConstantDeclaration: { _ in "" },
            visitFunctionDeclaration: { _ in "" },
            visitProcedureDeclaration: { _ in "" },
            visitReturnStatement: { _ in "" },
            visitExpressionStatement: { _ in "" },
            visitBreakStatement: { "Break" },
            visitBlock: { _ in "" }
        )
        
        let result = visitor.visit(stmt)
        XCTAssertEqual(result, "While(2 statements)")
    }
    
    func testForStatementRangeVisitor() {
        let rangeFor = ForStatement.RangeFor(
            variable: "i",
            start: Expression.literal(.integer(1)),
            end: Expression.literal(.integer(10)),
            step: nil,
            body: [Statement.breakStatement]
        )
        let stmt = Statement.forStatement(.range(rangeFor))
        
        let visitor = StatementVisitor<String>(
            visitIfStatement: { _ in "" },
            visitWhileStatement: { _ in "" },
            visitForStatement: { forStmt in
                switch forStmt {
                case .range(let rangeFor):
                    return "ForRange(\(rangeFor.variable))"
                case .forEach(let forEach):
                    return "ForEach(\(forEach.variable))"
                }
            },
            visitAssignment: { _ in "" },
            visitVariableDeclaration: { _ in "" },
            visitConstantDeclaration: { _ in "" },
            visitFunctionDeclaration: { _ in "" },
            visitProcedureDeclaration: { _ in "" },
            visitReturnStatement: { _ in "" },
            visitExpressionStatement: { _ in "" },
            visitBreakStatement: { "Break" },
            visitBlock: { _ in "" }
        )
        
        let result = visitor.visit(stmt)
        XCTAssertEqual(result, "ForRange(i)")
    }
    
    func testForStatementForEachVisitor() {
        let forEach = ForStatement.ForEachLoop(
            variable: "item",
            iterable: Expression.identifier("collection"),
            body: [Statement.breakStatement]
        )
        let stmt = Statement.forStatement(.forEach(forEach))
        
        let visitor = StatementVisitor<String>(
            visitIfStatement: { _ in "" },
            visitWhileStatement: { _ in "" },
            visitForStatement: { forStmt in
                switch forStmt {
                case .range(let rangeFor):
                    return "ForRange(\(rangeFor.variable))"
                case .forEach(let forEach):
                    return "ForEach(\(forEach.variable))"
                }
            },
            visitAssignment: { _ in "" },
            visitVariableDeclaration: { _ in "" },
            visitConstantDeclaration: { _ in "" },
            visitFunctionDeclaration: { _ in "" },
            visitProcedureDeclaration: { _ in "" },
            visitReturnStatement: { _ in "" },
            visitExpressionStatement: { _ in "" },
            visitBreakStatement: { "Break" },
            visitBlock: { _ in "" }
        )
        
        let result = visitor.visit(stmt)
        XCTAssertEqual(result, "ForEach(item)")
    }
    
    func testAssignmentVisitor() {
        let assignment = Assignment.variable("x", Expression.literal(.integer(42)))
        let stmt = Statement.assignment(assignment)
        
        let visitor = StatementVisitor<String>(
            visitIfStatement: { _ in "" },
            visitWhileStatement: { _ in "" },
            visitForStatement: { _ in "" },
            visitAssignment: { assignment in
                switch assignment {
                case .variable(let name, _):
                    return "Assign(\(name))"
                case .arrayElement(_, _):
                    return "AssignArray"
                }
            },
            visitVariableDeclaration: { _ in "" },
            visitConstantDeclaration: { _ in "" },
            visitFunctionDeclaration: { _ in "" },
            visitProcedureDeclaration: { _ in "" },
            visitReturnStatement: { _ in "" },
            visitExpressionStatement: { _ in "" },
            visitBreakStatement: { "Break" },
            visitBlock: { _ in "" }
        )
        
        let result = visitor.visit(stmt)
        XCTAssertEqual(result, "Assign(x)")
    }
    
    func testVariableDeclarationVisitor() {
        let varDecl = VariableDeclaration(
            name: "x",
            type: .integer,
            initialValue: Expression.literal(.integer(0))
        )
        let stmt = Statement.variableDeclaration(varDecl)
        
        let visitor = StatementVisitor<String>(
            visitIfStatement: { _ in "" },
            visitWhileStatement: { _ in "" },
            visitForStatement: { _ in "" },
            visitAssignment: { _ in "" },
            visitVariableDeclaration: { varDecl in
                return "Var(\(varDecl.name))"
            },
            visitConstantDeclaration: { _ in "" },
            visitFunctionDeclaration: { _ in "" },
            visitProcedureDeclaration: { _ in "" },
            visitReturnStatement: { _ in "" },
            visitExpressionStatement: { _ in "" },
            visitBreakStatement: { "Break" },
            visitBlock: { _ in "" }
        )
        
        let result = visitor.visit(stmt)
        XCTAssertEqual(result, "Var(x)")
    }
    
    func testConstantDeclarationVisitor() {
        let constDecl = ConstantDeclaration(
            name: "PI",
            type: .real,
            initialValue: Expression.literal(.real(3.14))
        )
        let stmt = Statement.constantDeclaration(constDecl)
        
        let visitor = StatementVisitor<String>(
            visitIfStatement: { _ in "" },
            visitWhileStatement: { _ in "" },
            visitForStatement: { _ in "" },
            visitAssignment: { _ in "" },
            visitVariableDeclaration: { _ in "" },
            visitConstantDeclaration: { constDecl in
                return "Const(\(constDecl.name))"
            },
            visitFunctionDeclaration: { _ in "" },
            visitProcedureDeclaration: { _ in "" },
            visitReturnStatement: { _ in "" },
            visitExpressionStatement: { _ in "" },
            visitBreakStatement: { "Break" },
            visitBlock: { _ in "" }
        )
        
        let result = visitor.visit(stmt)
        XCTAssertEqual(result, "Const(PI)")
    }
    
    func testFunctionDeclarationVisitor() {
        let funcDecl = FunctionDeclaration(
            name: "add",
            parameters: [
                Parameter(name: "a", type: .integer),
                Parameter(name: "b", type: .integer)
            ],
            returnType: .integer,
            localVariables: [],
            body: [Statement.returnStatement(ReturnStatement(expression: Expression.literal(.integer(0))))]
        )
        let stmt = Statement.functionDeclaration(funcDecl)
        
        let visitor = StatementVisitor<String>(
            visitIfStatement: { _ in "" },
            visitWhileStatement: { _ in "" },
            visitForStatement: { _ in "" },
            visitAssignment: { _ in "" },
            visitVariableDeclaration: { _ in "" },
            visitConstantDeclaration: { _ in "" },
            visitFunctionDeclaration: { funcDecl in
                return "Function(\(funcDecl.name))"
            },
            visitProcedureDeclaration: { _ in "" },
            visitReturnStatement: { _ in "" },
            visitExpressionStatement: { _ in "" },
            visitBreakStatement: { "Break" },
            visitBlock: { _ in "" }
        )
        
        let result = visitor.visit(stmt)
        XCTAssertEqual(result, "Function(add)")
    }
    
    func testProcedureDeclarationVisitor() {
        let procDecl = ProcedureDeclaration(
            name: "print",
            parameters: [Parameter(name: "msg", type: .string)],
            localVariables: [],
            body: [Statement.breakStatement]
        )
        let stmt = Statement.procedureDeclaration(procDecl)
        
        let visitor = StatementVisitor<String>(
            visitIfStatement: { _ in "" },
            visitWhileStatement: { _ in "" },
            visitForStatement: { _ in "" },
            visitAssignment: { _ in "" },
            visitVariableDeclaration: { _ in "" },
            visitConstantDeclaration: { _ in "" },
            visitFunctionDeclaration: { _ in "" },
            visitProcedureDeclaration: { procDecl in
                return "Procedure(\(procDecl.name))"
            },
            visitReturnStatement: { _ in "" },
            visitExpressionStatement: { _ in "" },
            visitBreakStatement: { "Break" },
            visitBlock: { _ in "" }
        )
        
        let result = visitor.visit(stmt)
        XCTAssertEqual(result, "Procedure(print)")
    }
    
    func testReturnStatementVisitor() {
        let returnStmt = ReturnStatement(expression: Expression.literal(.integer(42)))
        let stmt = Statement.returnStatement(returnStmt)
        
        let visitor = StatementVisitor<String>(
            visitIfStatement: { _ in "" },
            visitWhileStatement: { _ in "" },
            visitForStatement: { _ in "" },
            visitAssignment: { _ in "" },
            visitVariableDeclaration: { _ in "" },
            visitConstantDeclaration: { _ in "" },
            visitFunctionDeclaration: { _ in "" },
            visitProcedureDeclaration: { _ in "" },
            visitReturnStatement: { returnStmt in
                return returnStmt.expression != nil ? "Return(value)" : "Return()"
            },
            visitExpressionStatement: { _ in "" },
            visitBreakStatement: { "Break" },
            visitBlock: { _ in "" }
        )
        
        let result = visitor.visit(stmt)
        XCTAssertEqual(result, "Return(value)")
    }
    
    func testExpressionStatementVisitor() {
        let expr = Expression.functionCall("println", [Expression.literal(.string("Hello"))])
        let stmt = Statement.expressionStatement(expr)
        
        let visitor = StatementVisitor<String>(
            visitIfStatement: { _ in "" },
            visitWhileStatement: { _ in "" },
            visitForStatement: { _ in "" },
            visitAssignment: { _ in "" },
            visitVariableDeclaration: { _ in "" },
            visitConstantDeclaration: { _ in "" },
            visitFunctionDeclaration: { _ in "" },
            visitProcedureDeclaration: { _ in "" },
            visitReturnStatement: { _ in "" },
            visitExpressionStatement: { expr in
                if case .functionCall(let name, _) = expr {
                    return "ExprStmt(\(name))"
                }
                return "ExprStmt"
            },
            visitBreakStatement: { "Break" },
            visitBlock: { _ in "" }
        )
        
        let result = visitor.visit(stmt)
        XCTAssertEqual(result, "ExprStmt(println)")
    }
    
    func testBreakStatementVisitor() {
        let stmt = Statement.breakStatement
        
        let visitor = StatementVisitor<String>(
            visitIfStatement: { _ in "" },
            visitWhileStatement: { _ in "" },
            visitForStatement: { _ in "" },
            visitAssignment: { _ in "" },
            visitVariableDeclaration: { _ in "" },
            visitConstantDeclaration: { _ in "" },
            visitFunctionDeclaration: { _ in "" },
            visitProcedureDeclaration: { _ in "" },
            visitReturnStatement: { _ in "" },
            visitExpressionStatement: { _ in "" },
            visitBreakStatement: { "Break" },
            visitBlock: { _ in "" }
        )
        
        let result = visitor.visit(stmt)
        XCTAssertEqual(result, "Break")
    }
    
    func testBlockStatementVisitor() {
        let statements = [
            Statement.breakStatement,
            Statement.returnStatement(ReturnStatement())
        ]
        let stmt = Statement.block(statements)
        
        let visitor = StatementVisitor<String>(
            visitIfStatement: { _ in "" },
            visitWhileStatement: { _ in "" },
            visitForStatement: { _ in "" },
            visitAssignment: { _ in "" },
            visitVariableDeclaration: { _ in "" },
            visitConstantDeclaration: { _ in "" },
            visitFunctionDeclaration: { _ in "" },
            visitProcedureDeclaration: { _ in "" },
            visitReturnStatement: { _ in "" },
            visitExpressionStatement: { _ in "" },
            visitBreakStatement: { "Break" },
            visitBlock: { statements in
                return "Block(\(statements.count) statements)"
            }
        )
        
        let result = visitor.visit(stmt)
        XCTAssertEqual(result, "Block(2 statements)")
    }
    
    // MARK: - Built-in Debug Visitor Tests
    
    func testDebugVisitor() {
        let stmt = Statement.breakStatement
        let result = StatementVisitor.debug.visit(stmt)
        XCTAssertEqual(result, "BreakStatement")
    }
    
    func testDebugVisitorComplexIfStatement() {
        let condition = Expression.literal(.boolean(true))
        let thenBody = [Statement.breakStatement]
        let elseIfs = [IfStatement.ElseIf(
            condition: Expression.literal(.boolean(false)),
            body: [Statement.breakStatement]
        )]
        let elseBody = [Statement.breakStatement]
        
        let ifStatement = IfStatement(
            condition: condition,
            thenBody: thenBody,
            elseIfs: elseIfs,
            elseBody: elseBody
        )
        let stmt = Statement.ifStatement(ifStatement)
        
        let result = StatementVisitor.debug.visit(stmt)
        XCTAssertTrue(result.contains("IfStatement"))
        XCTAssertTrue(result.contains("boolean(true)"))
        XCTAssertTrue(result.contains("ElseIf"))
    }
    
    // MARK: - Counter Visitor Tests
    
    func testCounterVisitor() {
        let statements = [
            Statement.breakStatement,
            Statement.breakStatement,
            Statement.returnStatement(ReturnStatement())
        ]
        let stmt = Statement.block(statements)
        
        // Count break statements
        let breakCounter = StatementVisitor.counter(for: Statement.self) { stmt in
            if case .breakStatement = stmt {
                return true
            }
            return false
        }
        
        let breakCount = breakCounter.visit(stmt)
        XCTAssertEqual(breakCount, 2)
        
        // Count all statements (including the block itself)
        let allCounter = StatementVisitor.counter(for: Statement.self) { _ in true }
        let allCount = allCounter.visit(stmt)
        XCTAssertEqual(allCount, 4) // 1 block + 2 break + 1 return
    }
    
    // MARK: - Complex Statement Tests
    
    func testComplexNestedStatement() {
        // Create a complex nested statement: if with while inside
        let whileBody = [Statement.breakStatement]
        let whileStmt = WhileStatement(
            condition: Expression.literal(.boolean(true)),
            body: whileBody
        )
        
        let ifBody = [Statement.whileStatement(whileStmt)]
        let ifStatement = IfStatement(
            condition: Expression.literal(.boolean(true)),
            thenBody: ifBody
        )
        let stmt = Statement.ifStatement(ifStatement)
        
        let result = StatementVisitor.debug.visit(stmt)
        XCTAssertTrue(result.contains("IfStatement"))
        XCTAssertTrue(result.contains("WhileStatement"))
        XCTAssertTrue(result.contains("BreakStatement"))
    }
    
    // MARK: - Thread Safety Tests
    
    func testVisitorThreadSafety() {
        let stmt = Statement.breakStatement
        let visitor = StatementVisitor.debug
        
        // Test concurrent access
        let expectation = self.expectation(description: "Concurrent visitor access")
        expectation.expectedFulfillmentCount = 10
        
        for _ in 0..<10 {
            DispatchQueue.global().async {
                let result = visitor.visit(stmt)
                XCTAssertEqual(result, "BreakStatement")
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 5.0)
    }
    
    // MARK: - Edge Cases
    
    func testEmptyBlock() {
        let stmt = Statement.block([])
        let result = StatementVisitor.debug.visit(stmt)
        XCTAssertEqual(result, "Block([])")
    }
    
    func testReturnWithoutValue() {
        let returnStmt = ReturnStatement(expression: nil)
        let stmt = Statement.returnStatement(returnStmt)
        let result = StatementVisitor.debug.visit(stmt)
        XCTAssertEqual(result, "ReturnStatement(nil)")
    }
    
    func testArrayElementAssignment() {
        let arrayAccess = Assignment.ArrayAccess(
            array: Expression.identifier("arr"),
            index: Expression.literal(.integer(0))
        )
        let assignment = Assignment.arrayElement(arrayAccess, Expression.literal(.integer(42)))
        let stmt = Statement.assignment(assignment)
        
        let result = StatementVisitor.debug.visit(stmt)
        XCTAssertTrue(result.contains("Assignment.arrayElement"))
        XCTAssertTrue(result.contains("ArrayAccess"))
    }
}