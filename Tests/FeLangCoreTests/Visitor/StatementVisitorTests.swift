import XCTest
@testable import FeLangCore

final class StatementVisitorTests: XCTestCase {
    
    func testVisitVariableDeclaration() {
        let visitor = StatementVisitor<String>(
            visitIfStatement: { _ in "if" },
            visitWhileStatement: { _ in "while" },
            visitForStatement: { _ in "for" },
            visitAssignment: { _ in "assignment" },
            visitVariableDeclaration: { varDecl in "var \(varDecl.name): \(varDecl.type)" },
            visitConstantDeclaration: { _ in "const" },
            visitFunctionDeclaration: { _ in "function" },
            visitProcedureDeclaration: { _ in "procedure" },
            visitReturnStatement: { _ in "return" },
            visitExpressionStatement: { _ in "expression" },
            visitBreakStatement: { "break" },
            visitBlock: { _ in "block" }
        )
        
        let varDecl = VariableDeclaration(name: "x", type: .integer)
        let stmt = Statement.variableDeclaration(varDecl)
        XCTAssertEqual(visitor.visit(stmt), "var x: DataType.integer")
    }
    
    func testVisitConstantDeclaration() {
        let visitor = StatementVisitor<String>(
            visitIfStatement: { _ in "if" },
            visitWhileStatement: { _ in "while" },
            visitForStatement: { _ in "for" },
            visitAssignment: { _ in "assignment" },
            visitVariableDeclaration: { _ in "var" },
            visitConstantDeclaration: { constDecl in "const \(constDecl.name): \(constDecl.type)" },
            visitFunctionDeclaration: { _ in "function" },
            visitProcedureDeclaration: { _ in "procedure" },
            visitReturnStatement: { _ in "return" },
            visitExpressionStatement: { _ in "expression" },
            visitBreakStatement: { "break" },
            visitBlock: { _ in "block" }
        )
        
        let constDecl = ConstantDeclaration(name: "PI", type: .real, initialValue: .literal(.real(3.14)))
        let stmt = Statement.constantDeclaration(constDecl)
        XCTAssertEqual(visitor.visit(stmt), "const PI: DataType.real")
    }
    
    func testVisitAssignment() {
        let visitor = StatementVisitor<String>(
            visitIfStatement: { _ in "if" },
            visitWhileStatement: { _ in "while" },
            visitForStatement: { _ in "for" },
            visitAssignment: { assignment in
                switch assignment {
                case .variable(let name, _):
                    return "assign to \(name)"
                case .arrayElement(_, _):
                    return "assign to array element"
                }
            },
            visitVariableDeclaration: { _ in "var" },
            visitConstantDeclaration: { _ in "const" },
            visitFunctionDeclaration: { _ in "function" },
            visitProcedureDeclaration: { _ in "procedure" },
            visitReturnStatement: { _ in "return" },
            visitExpressionStatement: { _ in "expression" },
            visitBreakStatement: { "break" },
            visitBlock: { _ in "block" }
        )
        
        // Test variable assignment
        let varAssignment = Assignment.variable("x", .literal(.integer(42)))
        let varStmt = Statement.assignment(varAssignment)
        XCTAssertEqual(visitor.visit(varStmt), "assign to x")
        
        // Test array element assignment
        let arrayAccess = Assignment.ArrayAccess(array: .identifier("arr"), index: .literal(.integer(0)))
        let arrayAssignment = Assignment.arrayElement(arrayAccess, .literal(.integer(10)))
        let arrayStmt = Statement.assignment(arrayAssignment)
        XCTAssertEqual(visitor.visit(arrayStmt), "assign to array element")
    }
    
    func testVisitIfStatement() {
        let visitor = StatementVisitor<String>(
            visitIfStatement: { ifStmt in "if condition with \(ifStmt.thenBody.count) then statements" },
            visitWhileStatement: { _ in "while" },
            visitForStatement: { _ in "for" },
            visitAssignment: { _ in "assignment" },
            visitVariableDeclaration: { _ in "var" },
            visitConstantDeclaration: { _ in "const" },
            visitFunctionDeclaration: { _ in "function" },
            visitProcedureDeclaration: { _ in "procedure" },
            visitReturnStatement: { _ in "return" },
            visitExpressionStatement: { _ in "expression" },
            visitBreakStatement: { "break" },
            visitBlock: { _ in "block" }
        )
        
        let ifStmt = IfStatement(
            condition: .literal(.boolean(true)),
            thenBody: [.breakStatement, .breakStatement]
        )
        let stmt = Statement.ifStatement(ifStmt)
        XCTAssertEqual(visitor.visit(stmt), "if condition with 2 then statements")
    }
    
    func testVisitWhileStatement() {
        let visitor = StatementVisitor<String>(
            visitIfStatement: { _ in "if" },
            visitWhileStatement: { whileStmt in "while loop with \(whileStmt.body.count) statements" },
            visitForStatement: { _ in "for" },
            visitAssignment: { _ in "assignment" },
            visitVariableDeclaration: { _ in "var" },
            visitConstantDeclaration: { _ in "const" },
            visitFunctionDeclaration: { _ in "function" },
            visitProcedureDeclaration: { _ in "procedure" },
            visitReturnStatement: { _ in "return" },
            visitExpressionStatement: { _ in "expression" },
            visitBreakStatement: { "break" },
            visitBlock: { _ in "block" }
        )
        
        let whileStmt = WhileStatement(
            condition: .literal(.boolean(true)),
            body: [.breakStatement]
        )
        let stmt = Statement.whileStatement(whileStmt)
        XCTAssertEqual(visitor.visit(stmt), "while loop with 1 statements")
    }
    
    func testVisitForStatement() {
        let visitor = StatementVisitor<String>(
            visitIfStatement: { _ in "if" },
            visitWhileStatement: { _ in "while" },
            visitForStatement: { forStmt in
                switch forStmt {
                case .range(let rangeFor):
                    return "range for \(rangeFor.variable)"
                case .forEach(let forEachLoop):
                    return "forEach for \(forEachLoop.variable)"
                }
            },
            visitAssignment: { _ in "assignment" },
            visitVariableDeclaration: { _ in "var" },
            visitConstantDeclaration: { _ in "const" },
            visitFunctionDeclaration: { _ in "function" },
            visitProcedureDeclaration: { _ in "procedure" },
            visitReturnStatement: { _ in "return" },
            visitExpressionStatement: { _ in "expression" },
            visitBreakStatement: { "break" },
            visitBlock: { _ in "block" }
        )
        
        // Test range for
        let rangeFor = ForStatement.RangeFor(
            variable: "i",
            start: .literal(.integer(1)),
            end: .literal(.integer(10)),
            body: [.breakStatement]
        )
        let rangeStmt = Statement.forStatement(.range(rangeFor))
        XCTAssertEqual(visitor.visit(rangeStmt), "range for i")
        
        // Test forEach
        let forEachLoop = ForStatement.ForEachLoop(
            variable: "item",
            iterable: .identifier("items"),
            body: [.breakStatement]
        )
        let forEachStmt = Statement.forStatement(.forEach(forEachLoop))
        XCTAssertEqual(visitor.visit(forEachStmt), "forEach for item")
    }
    
    func testVisitFunctionDeclaration() {
        let visitor = StatementVisitor<String>(
            visitIfStatement: { _ in "if" },
            visitWhileStatement: { _ in "while" },
            visitForStatement: { _ in "for" },
            visitAssignment: { _ in "assignment" },
            visitVariableDeclaration: { _ in "var" },
            visitConstantDeclaration: { _ in "const" },
            visitFunctionDeclaration: { funcDecl in "function \(funcDecl.name) with \(funcDecl.parameters.count) params" },
            visitProcedureDeclaration: { _ in "procedure" },
            visitReturnStatement: { _ in "return" },
            visitExpressionStatement: { _ in "expression" },
            visitBreakStatement: { "break" },
            visitBlock: { _ in "block" }
        )
        
        let param = Parameter(name: "x", type: .integer)
        let funcDecl = FunctionDeclaration(
            name: "add",
            parameters: [param],
            returnType: .integer,
            body: [.breakStatement]
        )
        let stmt = Statement.functionDeclaration(funcDecl)
        XCTAssertEqual(visitor.visit(stmt), "function add with 1 params")
    }
    
    func testVisitReturnStatement() {
        let visitor = StatementVisitor<String>(
            visitIfStatement: { _ in "if" },
            visitWhileStatement: { _ in "while" },
            visitForStatement: { _ in "for" },
            visitAssignment: { _ in "assignment" },
            visitVariableDeclaration: { _ in "var" },
            visitConstantDeclaration: { _ in "const" },
            visitFunctionDeclaration: { _ in "function" },
            visitProcedureDeclaration: { _ in "procedure" },
            visitReturnStatement: { returnStmt in
                return returnStmt.expression != nil ? "return with value" : "return void"
            },
            visitExpressionStatement: { _ in "expression" },
            visitBreakStatement: { "break" },
            visitBlock: { _ in "block" }
        )
        
        // Test return with value
        let returnWithValue = ReturnStatement(expression: .literal(.integer(42)))
        let returnStmt = Statement.returnStatement(returnWithValue)
        XCTAssertEqual(visitor.visit(returnStmt), "return with value")
        
        // Test return without value
        let returnVoid = ReturnStatement()
        let voidStmt = Statement.returnStatement(returnVoid)
        XCTAssertEqual(visitor.visit(voidStmt), "return void")
    }
    
    func testVisitExpressionStatement() {
        let visitor = StatementVisitor<String>(
            visitIfStatement: { _ in "if" },
            visitWhileStatement: { _ in "while" },
            visitForStatement: { _ in "for" },
            visitAssignment: { _ in "assignment" },
            visitVariableDeclaration: { _ in "var" },
            visitConstantDeclaration: { _ in "const" },
            visitFunctionDeclaration: { _ in "function" },
            visitProcedureDeclaration: { _ in "procedure" },
            visitReturnStatement: { _ in "return" },
            visitExpressionStatement: { expr in "expression: \(expr)" },
            visitBreakStatement: { "break" },
            visitBlock: { _ in "block" }
        )
        
        let exprStmt = Statement.expressionStatement(.literal(.integer(42)))
        let result = visitor.visit(exprStmt)
        XCTAssertTrue(result.contains("expression: literal(Literal.integer(42))"))
    }
    
    func testVisitBreakStatement() {
        let visitor = StatementVisitor<String>(
            visitIfStatement: { _ in "if" },
            visitWhileStatement: { _ in "while" },
            visitForStatement: { _ in "for" },
            visitAssignment: { _ in "assignment" },
            visitVariableDeclaration: { _ in "var" },
            visitConstantDeclaration: { _ in "const" },
            visitFunctionDeclaration: { _ in "function" },
            visitProcedureDeclaration: { _ in "procedure" },
            visitReturnStatement: { _ in "return" },
            visitExpressionStatement: { _ in "expression" },
            visitBreakStatement: { "break statement" },
            visitBlock: { _ in "block" }
        )
        
        XCTAssertEqual(visitor.visit(.breakStatement), "break statement")
    }
    
    func testVisitBlock() {
        let visitor = StatementVisitor<String>(
            visitIfStatement: { _ in "if" },
            visitWhileStatement: { _ in "while" },
            visitForStatement: { _ in "for" },
            visitAssignment: { _ in "assignment" },
            visitVariableDeclaration: { _ in "var" },
            visitConstantDeclaration: { _ in "const" },
            visitFunctionDeclaration: { _ in "function" },
            visitProcedureDeclaration: { _ in "procedure" },
            visitReturnStatement: { _ in "return" },
            visitExpressionStatement: { _ in "expression" },
            visitBreakStatement: { "break" },
            visitBlock: { statements in "block with \(statements.count) statements" }
        )
        
        let blockStmt = Statement.block([.breakStatement, .breakStatement, .breakStatement])
        XCTAssertEqual(visitor.visit(blockStmt), "block with 3 statements")
    }
    
    func testDebugVisitor() {
        let visitor = StatementVisitor<String>.makeDebugVisitor()
        
        // Test simple statements
        XCTAssertEqual(visitor.visit(.breakStatement), "break")
        
        let varDecl = VariableDeclaration(name: "x", type: .integer, initialValue: .literal(.integer(42)))
        let varStmt = Statement.variableDeclaration(varDecl)
        XCTAssertEqual(visitor.visit(varStmt), "var x: DataType.integer := 42")
        
        let constDecl = ConstantDeclaration(name: "PI", type: .real, initialValue: .literal(.real(3.14)))
        let constStmt = Statement.constantDeclaration(constDecl)
        XCTAssertEqual(visitor.visit(constStmt), "const PI: DataType.real := 3.14")
        
        // Test assignment
        let assignment = Assignment.variable("x", .literal(.integer(10)))
        let assignStmt = Statement.assignment(assignment)
        XCTAssertEqual(visitor.visit(assignStmt), "x := 10")
        
        // Test return statement
        let returnStmt = Statement.returnStatement(ReturnStatement(expression: .literal(.integer(42))))
        XCTAssertEqual(visitor.visit(returnStmt), "return 42")
        
        // Test expression statement
        let exprStmt = Statement.expressionStatement(.identifier("x"))
        XCTAssertEqual(visitor.visit(exprStmt), "x")
    }
    
    func testSendableCompliance() {
        // Test that StatementVisitor can be used in concurrent contexts
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
        
        // This should compile without warnings if Sendable is properly implemented
        Task {
            let result = visitor.visit(.breakStatement)
            XCTAssertEqual(result, 1)
        }
    }
    
    func testCountingVisitor() {
        // Create a visitor that counts the number of statements
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
        
        // Test simple statement
        XCTAssertEqual(countingVisitor.visit(.breakStatement), 1)
        
        // Test block statement
        let blockStmt = Statement.block([.breakStatement, .breakStatement, .breakStatement])
        XCTAssertEqual(countingVisitor.visit(blockStmt), 3)
    }
}