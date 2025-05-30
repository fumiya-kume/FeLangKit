import Testing
@testable import FeLangCore

@Suite("PrettyPrinter Tests")
struct PrettyPrinterTests {

    // MARK: - Literal Tests

    @Test func integerLiteral() {
        let printer = PrettyPrinter()
        let expr = Expression.literal(.integer(42))
        #expect(printer.print(expr) == "42")
    }

    @Test func realLiteral() {
        let printer = PrettyPrinter()
        let expr = Expression.literal(.real(3.14))
        #expect(printer.print(expr) == "3.14")
    }

    @Test func stringLiteral() {
        let printer = PrettyPrinter()
        let expr = Expression.literal(.string("hello"))
        #expect(printer.print(expr) == "\"hello\"")
    }

    @Test func stringLiteralWithEscapes() {
        let printer = PrettyPrinter()
        let expr = Expression.literal(.string("hello\nworld\t\"test\"\\"))
        #expect(printer.print(expr) == "\"hello\\nworld\\t\\\"test\\\"\\\\\"")
    }

    @Test func characterLiteral() {
        let printer = PrettyPrinter()
        let expr = Expression.literal(.character("a"))
        #expect(printer.print(expr) == "'a'")
    }

    @Test func characterLiteralWithEscapes() {
        let printer = PrettyPrinter()
        let expr = Expression.literal(.character("\n"))
        #expect(printer.print(expr) == "'\\n'")

        let expr2 = Expression.literal(.character("'"))
        #expect(printer.print(expr2) == "'\\''")

        let expr3 = Expression.literal(.character("\\"))
        #expect(printer.print(expr3) == "'\\\\'")
    }

    @Test func booleanLiterals() {
        let printer = PrettyPrinter()
        let trueExpr = Expression.literal(.boolean(true))
        #expect(printer.print(trueExpr) == "true")

        let falseExpr = Expression.literal(.boolean(false))
        #expect(printer.print(falseExpr) == "false")
    }

    // MARK: - Identifier Tests

    @Test func identifier() {
        let printer = PrettyPrinter()
        let expr = Expression.identifier("variable")
        #expect(printer.print(expr) == "variable")
    }

    // MARK: - Binary Expression Tests

    @Test func simpleBinaryExpression() {
        let printer = PrettyPrinter()
        let expr = Expression.binary(.add, .literal(.integer(1)), .literal(.integer(2)))
        #expect(printer.print(expr) == "1 + 2")
    }

    @Test func binaryExpressionWithPrecedence() {
        let printer = PrettyPrinter()
        // 1 + 2 * 3 should not have parentheses around 2 * 3
        let expr = Expression.binary(.add,
                                   .literal(.integer(1)),
                                   .binary(.multiply, .literal(.integer(2)), .literal(.integer(3))))
        #expect(printer.print(expr) == "1 + 2 * 3")
    }

    @Test func binaryExpressionNeedingParentheses() {
        let printer = PrettyPrinter()
        // (1 + 2) * 3 should have parentheses around 1 + 2
        let expr = Expression.binary(.multiply,
                                   .binary(.add, .literal(.integer(1)), .literal(.integer(2))),
                                   .literal(.integer(3)))
        #expect(printer.print(expr) == "(1 + 2) * 3")
    }

    @Test func unicodeOperators() {
        let printer = PrettyPrinter()
        let expr1 = Expression.binary(.notEqual, .identifier("a"), .identifier("b"))
        #expect(printer.print(expr1) == "a ≠ b")

        let expr2 = Expression.binary(.greaterEqual, .identifier("x"), .literal(.integer(5)))
        #expect(printer.print(expr2) == "x ≧ 5")

        let expr3 = Expression.binary(.lessEqual, .identifier("y"), .literal(.integer(10)))
        #expect(printer.print(expr3) == "y ≦ 10")
    }

    @Test func logicalOperators() {
        let printer = PrettyPrinter()
        let expr1 = Expression.binary(.and, .identifier("a"), .identifier("b"))
        #expect(printer.print(expr1) == "a and b")

        let expr2 = Expression.binary(.or, .identifier("x"), .identifier("y"))
        #expect(printer.print(expr2) == "x or y")
    }

    // MARK: - Unary Expression Tests

    @Test func unaryExpressions() {
        let printer = PrettyPrinter()
        let notExpr = Expression.unary(.not, .identifier("flag"))
        #expect(printer.print(notExpr) == "notflag")

        let plusExpr = Expression.unary(.plus, .literal(.integer(5)))
        #expect(printer.print(plusExpr) == "+5")

        let minusExpr = Expression.unary(.minus, .literal(.integer(10)))
        #expect(printer.print(minusExpr) == "-10")
    }

    // MARK: - Array Access Tests

    @Test func arrayAccess() {
        let printer = PrettyPrinter()
        let expr = Expression.arrayAccess(.identifier("arr"), .literal(.integer(0)))
        #expect(printer.print(expr) == "arr[0]")
    }

    @Test func nestedArrayAccess() {
        let printer = PrettyPrinter()
        let expr = Expression.arrayAccess(
            .arrayAccess(.identifier("matrix"), .literal(.integer(1))),
            .literal(.integer(2))
        )
        #expect(printer.print(expr) == "matrix[1][2]")
    }

    // MARK: - Field Access Tests

    @Test func fieldAccess() {
        let printer = PrettyPrinter()
        let expr = Expression.fieldAccess(.identifier("person"), "name")
        #expect(printer.print(expr) == "person.name")
    }

    @Test func chainedFieldAccess() {
        let printer = PrettyPrinter()
        let expr = Expression.fieldAccess(
            .fieldAccess(.identifier("person"), "address"),
            "street"
        )
        #expect(printer.print(expr) == "person.address.street")
    }

    // MARK: - Function Call Tests

    @Test func functionCallNoArgs() {
        let printer = PrettyPrinter()
        let expr = Expression.functionCall("getValue", [])
        #expect(printer.print(expr) == "getValue()")
    }

    @Test func functionCallWithArgs() {
        let printer = PrettyPrinter()
        let expr = Expression.functionCall("add", [.literal(.integer(1)), .literal(.integer(2))])
        #expect(printer.print(expr) == "add(1, 2)")
    }

    @Test func functionCallWithComplexArgs() {
        let printer = PrettyPrinter()
        let expr = Expression.functionCall("calculate", [
            .binary(.add, .identifier("x"), .literal(.integer(1))),
            .functionCall("getValue", [])
        ])
        #expect(printer.print(expr) == "calculate(x + 1, getValue())")
    }

    // MARK: - Assignment Statement Tests

    @Test func variableAssignment() {
        let printer = PrettyPrinter()
        let stmt = Statement.assignment(.variable("x", .literal(.integer(5))))
        #expect(printer.print(stmt) == "x ← 5")
    }

    @Test func arrayElementAssignment() {
        let printer = PrettyPrinter()
        let arrayAccess = Assignment.ArrayAccess(array: .identifier("arr"), index: .literal(.integer(0)))
        let stmt = Statement.assignment(.arrayElement(arrayAccess, .literal(.integer(10))))
        #expect(printer.print(stmt) == "arr[0] ← 10")
    }

    // MARK: - Declaration Statement Tests

    @Test func variableDeclaration() {
        let printer = PrettyPrinter()
        let varDecl = VariableDeclaration(name: "x", type: .integer)
        let stmt = Statement.variableDeclaration(varDecl)
        #expect(printer.print(stmt) == "変数 x: 整数型")
    }

    @Test func variableDeclarationWithInitialValue() {
        let printer = PrettyPrinter()
        let varDecl = VariableDeclaration(name: "y", type: .real, initialValue: .literal(.real(3.14)))
        let stmt = Statement.variableDeclaration(varDecl)
        #expect(printer.print(stmt) == "変数 y: 実数型 ← 3.14")
    }

    @Test func constantDeclaration() {
        let printer = PrettyPrinter()
        let constDecl = ConstantDeclaration(name: "PI", type: .real, initialValue: .literal(.real(3.14159)))
        let stmt = Statement.constantDeclaration(constDecl)
        #expect(printer.print(stmt) == "定数 PI: 実数型 ← 3.14159")
    }

    // MARK: - Data Type Tests

    @Test func dataTypes() {
        let printer = PrettyPrinter()
        let intDecl = VariableDeclaration(name: "i", type: .integer)
        #expect(printer.print(.variableDeclaration(intDecl)) == "変数 i: 整数型")

        let realDecl = VariableDeclaration(name: "r", type: .real)
        #expect(printer.print(.variableDeclaration(realDecl)) == "変数 r: 実数型")

        let charDecl = VariableDeclaration(name: "c", type: .character)
        #expect(printer.print(.variableDeclaration(charDecl)) == "変数 c: 文字型")

        let stringDecl = VariableDeclaration(name: "s", type: .string)
        #expect(printer.print(.variableDeclaration(stringDecl)) == "変数 s: 文字列型")

        let boolDecl = VariableDeclaration(name: "b", type: .boolean)
        #expect(printer.print(.variableDeclaration(boolDecl)) == "変数 b: 論理型")

        let arrayDecl = VariableDeclaration(name: "arr", type: .array(.integer))
        #expect(printer.print(.variableDeclaration(arrayDecl)) == "変数 arr: 配列[整数型]")

        let recordDecl = VariableDeclaration(name: "person", type: .record("Person"))
        #expect(printer.print(.variableDeclaration(recordDecl)) == "変数 person: レコード Person")
    }

    // MARK: - Control Flow Statement Tests

    @Test func ifStatement() {
        let printer = PrettyPrinter()
        let ifStmt = IfStatement(
            condition: .binary(.greater, .identifier("x"), .literal(.integer(0))),
            thenBody: [.assignment(.variable("y", .literal(.integer(1))))]
        )
        let stmt = Statement.ifStatement(ifStmt)
        let expected = """
        if x > 0 then
            y ← 1
        endif
        """
        #expect(printer.print(stmt) == expected)
    }

    @Test func ifElseStatement() {
        let printer = PrettyPrinter()
        let ifStmt = IfStatement(
            condition: .binary(.greater, .identifier("x"), .literal(.integer(0))),
            thenBody: [.assignment(.variable("y", .literal(.integer(1))))],
            elseBody: [.assignment(.variable("y", .literal(.integer(-1))))]
        )
        let stmt = Statement.ifStatement(ifStmt)
        let expected = """
        if x > 0 then
            y ← 1
        else
            y ← -1
        endif
        """
        #expect(printer.print(stmt) == expected)
    }

    @Test func ifElifElseStatement() {
        let printer = PrettyPrinter()
        let elseIf = IfStatement.ElseIf(
            condition: .binary(.equal, .identifier("x"), .literal(.integer(0))),
            body: [.assignment(.variable("y", .literal(.integer(0))))]
        )
        let ifStmt = IfStatement(
            condition: .binary(.greater, .identifier("x"), .literal(.integer(0))),
            thenBody: [.assignment(.variable("y", .literal(.integer(1))))],
            elseIfs: [elseIf],
            elseBody: [.assignment(.variable("y", .literal(.integer(-1))))]
        )
        let stmt = Statement.ifStatement(ifStmt)
        let expected = """
        if x > 0 then
            y ← 1
        elif x = 0 then
            y ← 0
        else
            y ← -1
        endif
        """
        #expect(printer.print(stmt) == expected)
    }

    @Test func whileStatement() {
        let printer = PrettyPrinter()
        let whileStmt = WhileStatement(
            condition: .binary(.less, .identifier("i"), .literal(.integer(10))),
            body: [.assignment(.variable("i", .binary(.add, .identifier("i"), .literal(.integer(1)))))]
        )
        let stmt = Statement.whileStatement(whileStmt)
        let expected = """
        while i < 10 do
            i ← i + 1
        endwhile
        """
        #expect(printer.print(stmt) == expected)
    }

    @Test func forRangeStatement() {
        let printer = PrettyPrinter()
        let forStmt = ForStatement.range(ForStatement.RangeFor(
            variable: "i",
            start: .literal(.integer(1)),
            end: .literal(.integer(10)),
            body: [.expressionStatement(.functionCall("print", [.identifier("i")]))]
        ))
        let stmt = Statement.forStatement(forStmt)
        let expected = """
        for i = 1 to 10 do
            print(i)
        endfor
        """
        #expect(printer.print(stmt) == expected)
    }

    @Test func forRangeWithStepStatement() {
        let printer = PrettyPrinter()
        let forStmt = ForStatement.range(ForStatement.RangeFor(
            variable: "i",
            start: .literal(.integer(0)),
            end: .literal(.integer(10)),
            step: .literal(.integer(2)),
            body: [.expressionStatement(.functionCall("print", [.identifier("i")]))]
        ))
        let stmt = Statement.forStatement(forStmt)
        let expected = """
        for i = 0 to 10 step 2 do
            print(i)
        endfor
        """
        #expect(printer.print(stmt) == expected)
    }

    @Test func forEachStatement() {
        let printer = PrettyPrinter()
        let forStmt = ForStatement.forEach(ForStatement.ForEachLoop(
            variable: "item",
            iterable: .identifier("items"),
            body: [.expressionStatement(.functionCall("process", [.identifier("item")]))]
        ))
        let stmt = Statement.forStatement(forStmt)
        let expected = """
        for item in items do
            process(item)
        endfor
        """
        #expect(printer.print(stmt) == expected)
    }

    // MARK: - Function and Procedure Declaration Tests

    @Test func functionDeclaration() {
        let printer = PrettyPrinter()
        let param = Parameter(name: "x", type: .integer)
        let funcDecl = FunctionDeclaration(
            name: "square",
            parameters: [param],
            returnType: .integer,
            body: [.returnStatement(ReturnStatement(expression: .binary(.multiply, .identifier("x"), .identifier("x"))))]
        )
        let stmt = Statement.functionDeclaration(funcDecl)
        let expected = """
        function square(x: 整数型): 整数型
            return x * x
        endfunction
        """
        #expect(printer.print(stmt) == expected)
    }

    @Test func functionDeclarationWithLocalVariables() {
        let printer = PrettyPrinter()
        let param = Parameter(name: "n", type: .integer)
        let localVar = VariableDeclaration(name: "result", type: .integer, initialValue: .literal(.integer(1)))
        let funcDecl = FunctionDeclaration(
            name: "factorial",
            parameters: [param],
            returnType: .integer,
            localVariables: [localVar],
            body: [
                .forStatement(.range(ForStatement.RangeFor(
                    variable: "i",
                    start: .literal(.integer(1)),
                    end: .identifier("n"),
                    body: [.assignment(.variable("result", .binary(.multiply, .identifier("result"), .identifier("i"))))]
                ))),
                .returnStatement(ReturnStatement(expression: .identifier("result")))
            ]
        )
        let stmt = Statement.functionDeclaration(funcDecl)
        let expected = """
        function factorial(n: 整数型): 整数型
            変数 result: 整数型 ← 1
            for i = 1 to n do
                result ← result * i
            endfor
            return result
        endfunction
        """
        #expect(printer.print(stmt) == expected)
    }

    @Test func procedureDeclaration() {
        let printer = PrettyPrinter()
        let param = Parameter(name: "message", type: .string)
        let procDecl = ProcedureDeclaration(
            name: "printMessage",
            parameters: [param],
            body: [.expressionStatement(.functionCall("print", [.identifier("message")]))]
        )
        let stmt = Statement.procedureDeclaration(procDecl)
        let expected = """
        procedure printMessage(message: 文字列型)
            print(message)
        endprocedure
        """
        #expect(printer.print(stmt) == expected)
    }

    // MARK: - Other Statement Tests

    @Test func returnStatement() {
        let printer = PrettyPrinter()
        let returnStmt = ReturnStatement(expression: .literal(.integer(42)))
        let stmt = Statement.returnStatement(returnStmt)
        #expect(printer.print(stmt) == "return 42")
    }

    @Test func returnStatementWithoutValue() {
        let printer = PrettyPrinter()
        let returnStmt = ReturnStatement()
        let stmt = Statement.returnStatement(returnStmt)
        #expect(printer.print(stmt) == "return")
    }

    @Test func breakStatement() {
        let printer = PrettyPrinter()
        let stmt = Statement.breakStatement
        #expect(printer.print(stmt) == "break")
    }

    @Test func expressionStatement() {
        let printer = PrettyPrinter()
        let stmt = Statement.expressionStatement(.functionCall("doSomething", []))
        #expect(printer.print(stmt) == "doSomething()")
    }

    @Test func blockStatement() {
        let printer = PrettyPrinter()
        let block = [
            Statement.assignment(.variable("x", .literal(.integer(1)))),
            Statement.assignment(.variable("y", .literal(.integer(2))))
        ]
        let stmt = Statement.block(block)
        let expected = """
        x ← 1
        y ← 2
        """
        #expect(printer.print(stmt) == expected)
    }

    // MARK: - Configuration Tests

    @Test func customIndentation() {
        let config = PrettyPrinter.Configuration(indentSize: 2, useSpaces: true)
        let customPrinter = PrettyPrinter(configuration: config)

        let ifStmt = IfStatement(
            condition: .literal(.boolean(true)),
            thenBody: [.assignment(.variable("x", .literal(.integer(1))))]
        )
        let stmt = Statement.ifStatement(ifStmt)
        let expected = """
        if true then
          x ← 1
        endif
        """
        #expect(customPrinter.print(stmt) == expected)
    }

    @Test func tabIndentation() {
        let config = PrettyPrinter.Configuration(indentSize: 1, useSpaces: false)
        let customPrinter = PrettyPrinter(configuration: config)

        let ifStmt = IfStatement(
            condition: .literal(.boolean(true)),
            thenBody: [.assignment(.variable("x", .literal(.integer(1))))]
        )
        let stmt = Statement.ifStatement(ifStmt)
        let expected = """
        if true then
        \tx ← 1
        endif
        """
        #expect(customPrinter.print(stmt) == expected)
    }

    // MARK: - Multiple Statements Tests

    @Test func multipleStatements() {
        let printer = PrettyPrinter()
        let statements = [
            Statement.variableDeclaration(VariableDeclaration(name: "x", type: .integer)),
            Statement.assignment(.variable("x", .literal(.integer(5)))),
            Statement.expressionStatement(.functionCall("print", [.identifier("x")]))
        ]
        let expected = """
        変数 x: 整数型
        x ← 5
        print(x)
        """
        #expect(printer.print(statements) == expected)
    }
}
