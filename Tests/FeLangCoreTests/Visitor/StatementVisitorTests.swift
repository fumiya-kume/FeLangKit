import XCTest
@testable import FeLangCore

final class StatementVisitorTests: XCTestCase {
    
    // MARK: - Basic Functionality Tests
    
    func testVisitIfStatement() {
        let visitor = StatementVisitor<String>(
            visitIfStatement: { ifStmt in "if(\(ifStmt.elseIfs.count) elseifs)" },
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
        
        let ifStmt = IfStatement(
            condition: .literal(.boolean(true)),
            thenBody: [.breakStatement],
            elseIfs: [
                IfStatement.ElseIf(condition: .literal(.boolean(false)), body: [.breakStatement])
            ],
            elseBody: [.breakStatement]
        )
        
        XCTAssertEqual(visitor.visit(.ifStatement(ifStmt)), "if(1 elseifs)")
    }
    
    func testVisitWhileStatement() {
        let visitor = StatementVisitor<String>(
            visitIfStatement: { _ in "if" },
            visitWhileStatement: { whileStmt in "while(condition)" },
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
        
        let whileStmt = WhileStatement(
            condition: .literal(.boolean(true)),
            body: [.breakStatement]
        )
        
        XCTAssertEqual(visitor.visit(.whileStatement(whileStmt)), "while(condition)")
    }
    
    func testVisitForStatement() {
        let visitor = StatementVisitor<String>(
            visitIfStatement: { _ in "if" },
            visitWhileStatement: { _ in "while" },
            visitForStatement: { forStmt in
                switch forStmt {
                case .range(let rangeFor): return "for-range(\(rangeFor.variable))"
                case .forEach(let forEach): return "for-each(\(forEach.variable))"
                }
            },
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
        
        let rangeFor = ForStatement.RangeFor(
            variable: "i",
            start: .literal(.integer(0)),
            end: .literal(.integer(10)),
            step: nil,
            body: [.breakStatement]
        )
        
        let forEach = ForStatement.ForEachLoop(
            variable: "item",
            iterable: .identifier("items"),
            body: [.breakStatement]
        )
        
        XCTAssertEqual(visitor.visit(.forStatement(.range(rangeFor))), "for-range(i)")
        XCTAssertEqual(visitor.visit(.forStatement(.forEach(forEach))), "for-each(item)")
    }
    
    func testVisitAssignment() {
        let visitor = StatementVisitor<String>(
            visitIfStatement: { _ in "if" },
            visitWhileStatement: { _ in "while" },
            visitForStatement: { _ in "for" },
            visitAssignment: { assignment in
                switch assignment {
                case .variable(let name, _): return "assign-var(\(name))"
                case .arrayElement(_, _): return "assign-array"
                }
            },
            visitVariableDeclaration: { _ in "var" },
            visitConstantDeclaration: { _ in "const" },
            visitFunctionDeclaration: { _ in "func" },
            visitProcedureDeclaration: { _ in "proc" },
            visitReturnStatement: { _ in "return" },
            visitExpressionStatement: { _ in "expr" },
            visitBreakStatement: { "break" },
            visitBlock: { _ in "block" }
        )
        
        let varAssignment = Assignment.variable("x", .literal(.integer(42)))
        let arrayAssignment = Assignment.arrayElement(
            Assignment.ArrayAccess(array: .identifier("arr"), index: .literal(.integer(0))),
            .literal(.integer(42))
        )
        
        XCTAssertEqual(visitor.visit(.assignment(varAssignment)), "assign-var(x)")
        XCTAssertEqual(visitor.visit(.assignment(arrayAssignment)), "assign-array")
    }
    
    func testVisitDeclarations() {
        let visitor = StatementVisitor<String>(
            visitIfStatement: { _ in "if" },
            visitWhileStatement: { _ in "while" },
            visitForStatement: { _ in "for" },
            visitAssignment: { _ in "assignment" },
            visitVariableDeclaration: { varDecl in "var(\(varDecl.name))" },
            visitConstantDeclaration: { constDecl in "const(\(constDecl.name))" },
            visitFunctionDeclaration: { funcDecl in "func(\(funcDecl.name))" },
            visitProcedureDeclaration: { procDecl in "proc(\(procDecl.name))" },
            visitReturnStatement: { _ in "return" },
            visitExpressionStatement: { _ in "expr" },
            visitBreakStatement: { "break" },
            visitBlock: { _ in "block" }
        )
        
        let varDecl = VariableDeclaration(name: "x", type: .integer, initialValue: nil)
        let constDecl = ConstantDeclaration(name: "PI", type: .real, initialValue: .literal(.real(3.14)))
        let funcDecl = FunctionDeclaration(name: "add", parameters: [], returnType: .integer, body: [])
        let procDecl = ProcedureDeclaration(name: "print", parameters: [], body: [])
        
        XCTAssertEqual(visitor.visit(.variableDeclaration(varDecl)), "var(x)")
        XCTAssertEqual(visitor.visit(.constantDeclaration(constDecl)), "const(PI)")
        XCTAssertEqual(visitor.visit(.functionDeclaration(funcDecl)), "func(add)")
        XCTAssertEqual(visitor.visit(.procedureDeclaration(procDecl)), "proc(print)")
    }
    
    func testVisitOtherStatements() {
        let visitor = StatementVisitor<String>(
            visitIfStatement: { _ in "if" },
            visitWhileStatement: { _ in "while" },
            visitForStatement: { _ in "for" },
            visitAssignment: { _ in "assignment" },
            visitVariableDeclaration: { _ in "var" },
            visitConstantDeclaration: { _ in "const" },
            visitFunctionDeclaration: { _ in "func" },
            visitProcedureDeclaration: { _ in "proc" },
            visitReturnStatement: { returnStmt in
                return returnStmt.expression != nil ? "return-expr" : "return-void"
            },
            visitExpressionStatement: { _ in "expr-stmt" },
            visitBreakStatement: { "break" },
            visitBlock: { statements in "block[\(statements.count)]" }
        )
        
        let returnWithExpr = ReturnStatement(expression: .literal(.integer(42)))
        let returnVoid = ReturnStatement(expression: nil)
        let exprStmt = Expression.identifier("x")
        let block = [Statement.breakStatement, Statement.breakStatement]
        
        XCTAssertEqual(visitor.visit(.returnStatement(returnWithExpr)), "return-expr")
        XCTAssertEqual(visitor.visit(.returnStatement(returnVoid)), "return-void")
        XCTAssertEqual(visitor.visit(.expressionStatement(exprStmt)), "expr-stmt")
        XCTAssertEqual(visitor.visit(.breakStatement), "break")
        XCTAssertEqual(visitor.visit(.block(block)), "block[2]")
    }
    
    // MARK: - Generic Result Type Tests
    
    func testIntegerResultType() {
        let counter = StatementVisitor<Int>(
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
        
        let block = [Statement.breakStatement, Statement.breakStatement, Statement.breakStatement]
        XCTAssertEqual(counter.visit(.block(block)), 3)
        XCTAssertEqual(counter.visit(.breakStatement), 1)
    }
    
    func testSetResultType() {
        let variableCollector = StatementVisitor<Set<String>>(
            visitIfStatement: { _ in Set() },
            visitWhileStatement: { _ in Set() },
            visitForStatement: { forStmt in
                switch forStmt {
                case .range(let rangeFor): return Set([rangeFor.variable])
                case .forEach(let forEach): return Set([forEach.variable])
                }
            },
            visitAssignment: { assignment in
                switch assignment {
                case .variable(let name, _): return Set([name])
                case .arrayElement(_, _): return Set()
                }
            },
            visitVariableDeclaration: { varDecl in Set([varDecl.name]) },
            visitConstantDeclaration: { constDecl in Set([constDecl.name]) },
            visitFunctionDeclaration: { _ in Set() },
            visitProcedureDeclaration: { _ in Set() },
            visitReturnStatement: { _ in Set() },
            visitExpressionStatement: { _ in Set() },
            visitBreakStatement: { Set() },
            visitBlock: { _ in Set() }
        )
        
        let varDecl = VariableDeclaration(name: "x", type: .integer, initialValue: nil)
        let assignment = Assignment.variable("y", .literal(.integer(42)))
        
        XCTAssertEqual(variableCollector.visit(.variableDeclaration(varDecl)), Set(["x"]))
        XCTAssertEqual(variableCollector.visit(.assignment(assignment)), Set(["y"]))
    }
    
    // MARK: - Complex Statement Tests
    
    func testComplexStatementStructure() {
        let analyzer = StatementVisitor<(depth: Int, statements: Int)>(
            visitIfStatement: { ifStmt in
                let thenCount = ifStmt.thenBody.count
                let elseIfCount = ifStmt.elseIfs.reduce(0) { $0 + $1.body.count }
                let elseCount = ifStmt.elseBody?.count ?? 0
                return (depth: 1, statements: thenCount + elseIfCount + elseCount)
            },
            visitWhileStatement: { whileStmt in (depth: 1, statements: whileStmt.body.count) },
            visitForStatement: { forStmt in
                switch forStmt {
                case .range(let rangeFor): return (depth: 1, statements: rangeFor.body.count)
                case .forEach(let forEach): return (depth: 1, statements: forEach.body.count)
                }
            },
            visitAssignment: { _ in (depth: 0, statements: 1) },
            visitVariableDeclaration: { _ in (depth: 0, statements: 1) },
            visitConstantDeclaration: { _ in (depth: 0, statements: 1) },
            visitFunctionDeclaration: { funcDecl in (depth: 1, statements: funcDecl.body.count) },
            visitProcedureDeclaration: { procDecl in (depth: 1, statements: procDecl.body.count) },
            visitReturnStatement: { _ in (depth: 0, statements: 1) },
            visitExpressionStatement: { _ in (depth: 0, statements: 1) },
            visitBreakStatement: { (depth: 0, statements: 1) },
            visitBlock: { statements in (depth: 1, statements: statements.count) }
        )
        
        let complexIf = IfStatement(
            condition: .literal(.boolean(true)),
            thenBody: [.breakStatement, .breakStatement],
            elseIfs: [
                IfStatement.ElseIf(condition: .literal(.boolean(false)), body: [.breakStatement])
            ],
            elseBody: [.breakStatement, .breakStatement, .breakStatement]
        )
        
        let result = analyzer.visit(.ifStatement(complexIf))
        XCTAssertEqual(result.depth, 1)
        XCTAssertEqual(result.statements, 6) // 2 + 1 + 3 = 6
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentAccess() {
        let visitor = StatementVisitor<String>(
            visitIfStatement: { _ in
                Thread.sleep(forTimeInterval: 0.001)
                return "if"
            },
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
        
        let expectation = XCTestExpectation(description: "Concurrent visitor access")
        expectation.expectedFulfillmentCount = 10
        
        for _ in 0..<10 {
            Task {
                let ifStmt = IfStatement(condition: .literal(.boolean(true)), thenBody: [])
                let result = visitor.visit(.ifStatement(ifStmt))
                XCTAssertEqual(result, "if")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    // MARK: - Visitable Protocol Tests
    
    func testVisitableAccept() {
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
        
        let stmt = Statement.breakStatement
        XCTAssertEqual(stmt.accept(visitor), "break")
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceVsDirectSwitch() {
        let statements = (0..<1000).map { _ in Statement.breakStatement }
        
        let visitor = StatementVisitor<Int>(
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
            visitBlock: { _ in 1 }
        )
        
        measure {
            for stmt in statements {
                _ = visitor.visit(stmt)
            }
        }
    }
}