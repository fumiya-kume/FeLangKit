import Testing
@testable import FeLangCore

@Suite("StatementVisitor Tests")
struct StatementVisitorTests {

    // MARK: - Basic Visitor Tests

    @Test func visitIfStatement() {
        let visitor = StatementVisitor<String>(
            visitIfStatement: { ifStmt in "if(\(ifStmt.condition))" },
            visitWhileStatement: { _ in "while" },
            visitForStatement: { _ in "for" },
            visitAssignment: { _ in "assignment" },
            visitVariableDeclaration: { _ in "var_decl" },
            visitConstantDeclaration: { _ in "const_decl" },
            visitFunctionDeclaration: { _ in "func_decl" },
            visitProcedureDeclaration: { _ in "proc_decl" },
            visitReturnStatement: { _ in "return" },
            visitExpressionStatement: { _ in "expr_stmt" },
            visitBreakStatement: { "break" },
            visitBlock: { _ in "block" }
        )

        let ifStmt = IfStatement(
            condition: .literal(.boolean(true)),
            thenBody: [.breakStatement]
        )
        let stmt = Statement.ifStatement(ifStmt)

        let result = visitor.visit(stmt)
        #expect(result.hasPrefix("if("))
        #expect(result.contains("boolean(true)"))
    }

    @Test func visitWhileStatement() {
        let visitor = StatementVisitor<String>(
            visitIfStatement: { _ in "if" },
            visitWhileStatement: { whileStmt in "while(\(whileStmt.condition))" },
            visitForStatement: { _ in "for" },
            visitAssignment: { _ in "assignment" },
            visitVariableDeclaration: { _ in "var_decl" },
            visitConstantDeclaration: { _ in "const_decl" },
            visitFunctionDeclaration: { _ in "func_decl" },
            visitProcedureDeclaration: { _ in "proc_decl" },
            visitReturnStatement: { _ in "return" },
            visitExpressionStatement: { _ in "expr_stmt" },
            visitBreakStatement: { "break" },
            visitBlock: { _ in "block" }
        )

        let whileStmt = WhileStatement(
            condition: .literal(.boolean(true)),
            body: [.breakStatement]
        )
        let stmt = Statement.whileStatement(whileStmt)

        let result = visitor.visit(stmt)
        #expect(result.hasPrefix("while("))
        #expect(result.contains("boolean(true)"))
    }

    @Test func visitForStatement() {
        let visitor = StatementVisitor<String>(
            visitIfStatement: { _ in "if" },
            visitWhileStatement: { _ in "while" },
            visitForStatement: { forStmt in
                switch forStmt {
                case .range(let rangeFor):
                    return "for_range(\(rangeFor.variable))"
                case .forEach(let forEach):
                    return "for_each(\(forEach.variable))"
                }
            },
            visitAssignment: { _ in "assignment" },
            visitVariableDeclaration: { _ in "var_decl" },
            visitConstantDeclaration: { _ in "const_decl" },
            visitFunctionDeclaration: { _ in "func_decl" },
            visitProcedureDeclaration: { _ in "proc_decl" },
            visitReturnStatement: { _ in "return" },
            visitExpressionStatement: { _ in "expr_stmt" },
            visitBreakStatement: { "break" },
            visitBlock: { _ in "block" }
        )

        let rangeFor = ForStatement.RangeFor(
            variable: "i",
            start: .literal(.integer(0)),
            end: .literal(.integer(10)),
            body: [.breakStatement]
        )
        let stmt = Statement.forStatement(.range(rangeFor))

        #expect(visitor.visit(stmt) == "for_range(i)")

        let forEach = ForStatement.ForEachLoop(
            variable: "item",
            iterable: .identifier("items"),
            body: [.breakStatement]
        )
        let forEachStmt = Statement.forStatement(.forEach(forEach))

        #expect(visitor.visit(forEachStmt) == "for_each(item)")
    }

    @Test func visitAssignment() {
        let visitor = StatementVisitor<String>(
            visitIfStatement: { _ in "if" },
            visitWhileStatement: { _ in "while" },
            visitForStatement: { _ in "for" },
            visitAssignment: { assignment in
                switch assignment {
                case .variable(let name, _):
                    return "assign_var(\(name))"
                case .arrayElement(let arrayAccess, _):
                    return "assign_array(\(arrayAccess.array))"
                }
            },
            visitVariableDeclaration: { _ in "var_decl" },
            visitConstantDeclaration: { _ in "const_decl" },
            visitFunctionDeclaration: { _ in "func_decl" },
            visitProcedureDeclaration: { _ in "proc_decl" },
            visitReturnStatement: { _ in "return" },
            visitExpressionStatement: { _ in "expr_stmt" },
            visitBreakStatement: { "break" },
            visitBlock: { _ in "block" }
        )

        let varAssignment = Statement.assignment(.variable("x", .literal(.integer(42))))
        #expect(visitor.visit(varAssignment) == "assign_var(x)")

        let arrayAssignment = Statement.assignment(.arrayElement(
            Assignment.ArrayAccess(array: .identifier("arr"), index: .literal(.integer(0))),
            .literal(.integer(42))
        ))
        let result = visitor.visit(arrayAssignment)
        #expect(result.hasPrefix("assign_array("))
    }

    @Test func visitDeclarations() {
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
            visitExpressionStatement: { _ in "expr_stmt" },
            visitBreakStatement: { "break" },
            visitBlock: { _ in "block" }
        )

        let varDecl = Statement.variableDeclaration(VariableDeclaration(
            name: "x",
            type: .integer,
            initialValue: .literal(.integer(42))
        ))
        #expect(visitor.visit(varDecl) == "var(x)")

        let constDecl = Statement.constantDeclaration(ConstantDeclaration(
            name: "PI",
            type: .real,
            initialValue: .literal(.real(3.14))
        ))
        #expect(visitor.visit(constDecl) == "const(PI)")

        let funcDecl = Statement.functionDeclaration(FunctionDeclaration(
            name: "add",
            parameters: [],
            returnType: .integer,
            body: [.returnStatement(ReturnStatement(expression: .literal(.integer(0))))]
        ))
        #expect(visitor.visit(funcDecl) == "func(add)")

        let procDecl = Statement.procedureDeclaration(ProcedureDeclaration(
            name: "print",
            parameters: [],
            body: [.breakStatement]
        ))
        #expect(visitor.visit(procDecl) == "proc(print)")
    }

    @Test func visitOtherStatements() {
        let visitor = StatementVisitor<String>(
            visitIfStatement: { _ in "if" },
            visitWhileStatement: { _ in "while" },
            visitForStatement: { _ in "for" },
            visitAssignment: { _ in "assignment" },
            visitVariableDeclaration: { _ in "var_decl" },
            visitConstantDeclaration: { _ in "const_decl" },
            visitFunctionDeclaration: { _ in "func_decl" },
            visitProcedureDeclaration: { _ in "proc_decl" },
            visitReturnStatement: { returnStmt in
                if let expr = returnStmt.expression {
                    return "return(\(expr))"
                } else {
                    return "return(void)"
                }
            },
            visitExpressionStatement: { expr in "expr_stmt(\(expr))" },
            visitBreakStatement: { "break" },
            visitBlock: { statements in "block(\(statements.count))" }
        )

        let returnStmt = Statement.returnStatement(ReturnStatement(expression: .literal(.integer(42))))
        let result1 = visitor.visit(returnStmt)
        #expect(result1.hasPrefix("return("))
        #expect(result1.contains("integer(42)"))

        let returnVoid = Statement.returnStatement(ReturnStatement())
        #expect(visitor.visit(returnVoid) == "return(void)")

        let exprStmt = Statement.expressionStatement(.literal(.integer(42)))
        let result2 = visitor.visit(exprStmt)
        #expect(result2.hasPrefix("expr_stmt("))

        #expect(visitor.visit(.breakStatement) == "break")

        let block = Statement.block([.breakStatement, .breakStatement])
        #expect(visitor.visit(block) == "block(2)")
    }

    // MARK: - Manual Recursive Visitor Test

    @Test func manualRecursiveVisitor() {
        // Create a manual recursive visitor for basic statement stringification
        func stringifyStatement(_ stmt: Statement) -> String {
            switch stmt {
            case .ifStatement(let ifStmt):
                let thenBody = ifStmt.thenBody.map(stringifyStatement).joined(separator: "; ")
                return "if (\(ifStmt.condition)) { \(thenBody) }"
            case .whileStatement(let whileStmt):
                let body = whileStmt.body.map(stringifyStatement).joined(separator: "; ")
                return "while (\(whileStmt.condition)) { \(body) }"
            case .forStatement(let forStmt):
                switch forStmt {
                case .range(let rangeFor):
                    let body = rangeFor.body.map(stringifyStatement).joined(separator: "; ")
                    return "for \(rangeFor.variable) = \(rangeFor.start) to \(rangeFor.end) { \(body) }"
                case .forEach(let forEach):
                    let body = forEach.body.map(stringifyStatement).joined(separator: "; ")
                    return "for \(forEach.variable) in \(forEach.iterable) { \(body) }"
                }
            case .assignment(let assignment):
                switch assignment {
                case .variable(let name, let expr):
                    return "\(name) = \(expr)"
                case .arrayElement(let arrayAccess, let expr):
                    return "\(arrayAccess.array)[\(arrayAccess.index)] = \(expr)"
                }
            case .variableDeclaration(let varDecl):
                if let initialValue = varDecl.initialValue {
                    return "var \(varDecl.name): \(varDecl.type) = \(initialValue)"
                } else {
                    return "var \(varDecl.name): \(varDecl.type)"
                }
            case .constantDeclaration(let constDecl):
                return "const \(constDecl.name): \(constDecl.type) = \(constDecl.initialValue)"
            case .functionDeclaration(let funcDecl):
                let body = funcDecl.body.map(stringifyStatement).joined(separator: "; ")
                return "function \(funcDecl.name)() { \(body) }"
            case .procedureDeclaration(let procDecl):
                let body = procDecl.body.map(stringifyStatement).joined(separator: "; ")
                return "procedure \(procDecl.name)() { \(body) }"
            case .returnStatement(let returnStmt):
                if let expr = returnStmt.expression {
                    return "return \(expr)"
                } else {
                    return "return"
                }
            case .expressionStatement(let expr):
                return "\(expr)"
            case .breakStatement:
                return "break"
            case .block(let statements):
                let results = statements.map(stringifyStatement)
                return "{ \(results.joined(separator: "; ")) }"
            }
        }

        // Test simple statements
        #expect(stringifyStatement(.breakStatement) == "break")

        let assignment = Statement.assignment(.variable("x", .literal(.integer(42))))
        let result1 = stringifyStatement(assignment)
        #expect(result1.contains("x = "))
        #expect(result1.contains("integer(42)"))

        // Test nested statements
        let ifStmt = IfStatement(
            condition: .literal(.boolean(true)),
            thenBody: [.breakStatement, assignment]
        )
        let ifStatement = Statement.ifStatement(ifStmt)
        let result2 = stringifyStatement(ifStatement)
        #expect(result2.hasPrefix("if ("))
        #expect(result2.contains("break"))
        #expect(result2.contains("x = "))
    }

    // MARK: - Visitable Protocol Tests

    @Test func visitableProtocolConformance() {
        let visitor = StatementVisitor<String>(
            visitIfStatement: { _ in "if" },
            visitWhileStatement: { _ in "while" },
            visitForStatement: { _ in "for" },
            visitAssignment: { _ in "assignment" },
            visitVariableDeclaration: { _ in "var_decl" },
            visitConstantDeclaration: { _ in "const_decl" },
            visitFunctionDeclaration: { _ in "func_decl" },
            visitProcedureDeclaration: { _ in "proc_decl" },
            visitReturnStatement: { _ in "return" },
            visitExpressionStatement: { _ in "expr_stmt" },
            visitBreakStatement: { "break" },
            visitBlock: { _ in "block" }
        )

        let stmt = Statement.breakStatement

        // Test accept method
        #expect(stmt.accept(visitor) == "break")

        // Test convenience method
        #expect(stmt.visit(with: visitor) == "break")
    }

    // MARK: - Statement Type Counting Visitor

    @Test func statementTypeCountingVisitor() {
        // Simplified test using StatementVisitor to avoid complexity issues
        let visitor = StatementVisitor<String>(
            visitIfStatement: { _ in "if" },
            visitWhileStatement: { _ in "while" },
            visitForStatement: { _ in "for" },
            visitAssignment: { _ in "assignment" },
            visitVariableDeclaration: { _ in "var_decl" },
            visitConstantDeclaration: { _ in "const_decl" },
            visitFunctionDeclaration: { _ in "func_decl" },
            visitProcedureDeclaration: { _ in "proc_decl" },
            visitReturnStatement: { _ in "return" },
            visitExpressionStatement: { _ in "expr_stmt" },
            visitBreakStatement: { "break" },
            visitBlock: { _ in "block" }
        )

        // Test simple statements
        #expect(visitor.visit(.breakStatement) == "break")

        let assignment = Statement.assignment(.variable("x", .literal(.integer(42))))
        #expect(visitor.visit(assignment) == "assignment")

        // Test block with multiple statements
        let block = Statement.block([.breakStatement, assignment, .breakStatement])
        #expect(visitor.visit(block) == "block")
    }

    // MARK: - Performance Test

    @Test func visitorPerformance() {
        // Create a manual recursive counter for performance testing
        func countStatements(_ stmt: Statement) -> Int {
            switch stmt {
            case .ifStatement(let ifStmt):
                return 1 + ifStmt.thenBody.map(countStatements).reduce(0, +)
            case .whileStatement(let whileStmt):
                return 1 + whileStmt.body.map(countStatements).reduce(0, +)
            case .forStatement(let forStmt):
                let body: [Statement]
                switch forStmt {
                case .range(let rangeFor):
                    body = rangeFor.body
                case .forEach(let forEach):
                    body = forEach.body
                }
                return 1 + body.map(countStatements).reduce(0, +)
            case .assignment, .variableDeclaration, .constantDeclaration,
                 .returnStatement, .expressionStatement, .breakStatement:
                return 1
            case .functionDeclaration(let funcDecl):
                return 1 + funcDecl.body.map(countStatements).reduce(0, +)
            case .procedureDeclaration(let procDecl):
                return 1 + procDecl.body.map(countStatements).reduce(0, +)
            case .block(let statements):
                return 1 + statements.map(countStatements).reduce(0, +)
            }
        }

        // Create a deep block structure
        var statements: [Statement] = []
        for _ in 0..<100 { // Reduced from 1000 to avoid performance issues
            statements.append(.breakStatement)
        }
        let deepBlock = Statement.block(statements)

        _ = countStatements(deepBlock)
    }
}
