import Testing
@testable import FeLangCore

@Suite("Visitable Tests")
struct VisitableTests {

    // MARK: - Protocol Conformance Tests

    @Test func expressionVisitableConformance() {
        let visitor = ExpressionVisitor<String>(
            visitLiteral: { _ in "literal" },
            visitIdentifier: { _ in "identifier" },
            visitBinary: { _, _, _ in "binary" },
            visitUnary: { _, _ in "unary" },
            visitArrayAccess: { _, _ in "array_access" },
            visitFieldAccess: { _, _ in "field_access" },
            visitFunctionCall: { _, _ in "function_call" }
        )

        let expr = Expression.literal(.integer(42))

        // Test that Expression conforms to Visitable
        #expect(expr.accept(visitor) == "literal")

        // Test that ExpressionVisitor conforms to Visitor
        #expect(visitor.visit(expr) == "literal")
    }

    @Test func statementVisitableConformance() {
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

        // Test that Statement conforms to Visitable
        #expect(stmt.accept(visitor) == "break")

        // Test that StatementVisitor conforms to Visitor
        #expect(visitor.visit(stmt) == "break")
    }

    // MARK: - Convenience Method Tests

    @Test func expressionConvenienceMethod() {
        let visitor = ExpressionVisitor<String>(
            visitLiteral: { literal in
                switch literal {
                case .integer(let value): return "int(\(value))"
                case .real(let value): return "real(\(value))"
                case .string(let value): return "string(\(value))"
                case .character(let value): return "char(\(value))"
                case .boolean(let value): return "bool(\(value))"
                }
            },
            visitIdentifier: { "id(\($0))" },
            visitBinary: { op, _, _ in "binary(\(op.rawValue))" },
            visitUnary: { op, _ in "unary(\(op.rawValue))" },
            visitArrayAccess: { _, _ in "array_access" },
            visitFieldAccess: { _, field in "field_access(\(field))" },
            visitFunctionCall: { function, _ in "function_call(\(function))" }
        )

        // Test all expression types with convenience method
        #expect(Expression.literal(.integer(42)).visit(with: visitor) == "int(42)")
        #expect(Expression.identifier("x").visit(with: visitor) == "id(x)")
        #expect(Expression.binary(.add, .literal(.integer(1)), .literal(.integer(2))).visit(with: visitor) == "binary(+)")
        #expect(Expression.unary(.not, .literal(.boolean(true))).visit(with: visitor) == "unary(not)")
        #expect(Expression.arrayAccess(.identifier("arr"), .literal(.integer(0))).visit(with: visitor) == "array_access")
        #expect(Expression.fieldAccess(.identifier("obj"), "prop").visit(with: visitor) == "field_access(prop)")
        #expect(Expression.functionCall("func", []).visit(with: visitor) == "function_call(func)")
    }

    @Test func statementConvenienceMethod() {
        let visitor = StatementVisitor<String>(
            visitIfStatement: { _ in "if" },
            visitWhileStatement: { _ in "while" },
            visitForStatement: { forStmt in
                switch forStmt {
                case .range: return "for_range"
                case .forEach: return "for_each"
                }
            },
            visitAssignment: { assignment in
                switch assignment {
                case .variable: return "assign_var"
                case .arrayElement: return "assign_array"
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

        // Test all statement types with convenience method
        let ifStmt = IfStatement(condition: .literal(.boolean(true)), thenBody: [])
        #expect(Statement.ifStatement(ifStmt).visit(with: visitor) == "if")

        let whileStmt = WhileStatement(condition: .literal(.boolean(true)), body: [])
        #expect(Statement.whileStatement(whileStmt).visit(with: visitor) == "while")

        let rangeFor = ForStatement.RangeFor(variable: "i", start: .literal(.integer(0)), end: .literal(.integer(10)), body: [])
        #expect(Statement.forStatement(.range(rangeFor)).visit(with: visitor) == "for_range")

        let forEach = ForStatement.ForEachLoop(variable: "item", iterable: .identifier("items"), body: [])
        #expect(Statement.forStatement(.forEach(forEach)).visit(with: visitor) == "for_each")

        #expect(Statement.assignment(.variable("x", .literal(.integer(42)))).visit(with: visitor) == "assign_var")

        let arrayAccess = Assignment.ArrayAccess(array: .identifier("arr"), index: .literal(.integer(0)))
        #expect(Statement.assignment(.arrayElement(arrayAccess, .literal(.integer(42)))).visit(with: visitor) == "assign_array")

        let varDecl = VariableDeclaration(name: "x", type: .integer)
        #expect(Statement.variableDeclaration(varDecl).visit(with: visitor) == "var_decl")

        let constDecl = ConstantDeclaration(name: "PI", type: .real, initialValue: .literal(.real(3.14)))
        #expect(Statement.constantDeclaration(constDecl).visit(with: visitor) == "const_decl")

        let funcDecl = FunctionDeclaration(name: "test", parameters: [], body: [])
        #expect(Statement.functionDeclaration(funcDecl).visit(with: visitor) == "func_decl")

        let procDecl = ProcedureDeclaration(name: "test", parameters: [], body: [])
        #expect(Statement.procedureDeclaration(procDecl).visit(with: visitor) == "proc_decl")

        let returnStmt = ReturnStatement(expression: .literal(.integer(42)))
        #expect(Statement.returnStatement(returnStmt).visit(with: visitor) == "return")

        #expect(Statement.expressionStatement(.literal(.integer(42))).visit(with: visitor) == "expr_stmt")
        #expect(Statement.breakStatement.visit(with: visitor) == "break")
        #expect(Statement.block([]).visit(with: visitor) == "block")
    }

    // MARK: - Generic Visitor Interface Tests

    @Test func genericVisitorInterface() {
        // Create a generic function that can work with any Visitable type
        func processVisitable<T: Visitable, V: Visitor>(_ visitable: T, with visitor: V) -> V.Result where V.NodeType == T {
            return visitable.accept(visitor)
        }

        let exprVisitor = ExpressionVisitor<String>(
            visitLiteral: { _ in "literal" },
            visitIdentifier: { _ in "identifier" },
            visitBinary: { _, _, _ in "binary" },
            visitUnary: { _, _ in "unary" },
            visitArrayAccess: { _, _ in "array_access" },
            visitFieldAccess: { _, _ in "field_access" },
            visitFunctionCall: { _, _ in "function_call" }
        )

        let stmtVisitor = StatementVisitor<String>(
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

        let expr = Expression.literal(.integer(42))
        let stmt = Statement.breakStatement

        // Test that the generic function works with both types
        #expect(processVisitable(expr, with: exprVisitor) == "literal")
        #expect(processVisitable(stmt, with: stmtVisitor) == "break")
    }

    // MARK: - Sendable Compliance Tests

    @Test func sendableCompliance() {
        // This test ensures that our visitor types are Sendable
        let exprVisitor = ExpressionVisitor<String>(
            visitLiteral: { _ in "literal" },
            visitIdentifier: { _ in "identifier" },
            visitBinary: { _, _, _ in "binary" },
            visitUnary: { _, _ in "unary" },
            visitArrayAccess: { _, _ in "array_access" },
            visitFieldAccess: { _, _ in "field_access" },
            visitFunctionCall: { _, _ in "function_call" }
        )

        let stmtVisitor = StatementVisitor<String>(
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

        // Test that we can use visitors in async contexts
        Task {
            let expr = Expression.literal(.integer(42))
            let stmt = Statement.breakStatement

            #expect(expr.visit(with: exprVisitor) == "literal")
            #expect(stmt.visit(with: stmtVisitor) == "break")
        }
    }

    // MARK: - Type Safety Tests

    @Test func typeSafetyBetweenVisitorTypes() {
        let exprVisitor = ExpressionVisitor<String>(
            visitLiteral: { _ in "literal" },
            visitIdentifier: { _ in "identifier" },
            visitBinary: { _, _, _ in "binary" },
            visitUnary: { _, _ in "unary" },
            visitArrayAccess: { _, _ in "array_access" },
            visitFieldAccess: { _, _ in "field_access" },
            visitFunctionCall: { _, _ in "function_call" }
        )

        let stmtVisitor = StatementVisitor<String>(
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

        let expr = Expression.literal(.integer(42))
        let stmt = Statement.breakStatement

        // Test that expression visitors work with expressions
        #expect(expr.visit(with: exprVisitor) == "literal")
        #expect(expr.accept(exprVisitor) == "literal")

        // Test that statement visitors work with statements
        #expect(stmt.visit(with: stmtVisitor) == "break")
        #expect(stmt.accept(stmtVisitor) == "break")

        // The following should not compile due to type safety:
        // expr.visit(with: stmtVisitor) // Compile error: StatementVisitor cannot process Expression
        // stmt.visit(with: exprVisitor) // Compile error: ExpressionVisitor cannot process Statement
    }
}
