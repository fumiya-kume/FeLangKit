import XCTest
@testable import FeLangCore

final class PrettyPrinterTests: XCTestCase {

    var printer: PrettyPrinter!

    override func setUp() {
        super.setUp()
        printer = PrettyPrinter()
    }

    // MARK: - Literal Tests

    func testIntegerLiteral() {
        let expr = Expression.literal(.integer(42))
        XCTAssertEqual(printer.print(expr), "42")
    }

    func testRealLiteral() {
        let expr = Expression.literal(.real(3.14))
        XCTAssertEqual(printer.print(expr), "3.14")
    }

    func testStringLiteral() {
        let expr = Expression.literal(.string("hello"))
        XCTAssertEqual(printer.print(expr), "\"hello\"")
    }

    func testStringLiteralWithEscapes() {
        let expr = Expression.literal(.string("hello\nworld\t\"test\"\\"))
        XCTAssertEqual(printer.print(expr), "\"hello\\nworld\\t\\\"test\\\"\\\\\"")
    }

    func testCharacterLiteral() {
        let expr = Expression.literal(.character("a"))
        XCTAssertEqual(printer.print(expr), "'a'")
    }

    func testCharacterLiteralWithEscapes() {
        let expr = Expression.literal(.character("\n"))
        XCTAssertEqual(printer.print(expr), "'\\n'")

        let expr2 = Expression.literal(.character("'"))
        XCTAssertEqual(printer.print(expr2), "'\\''")

        let expr3 = Expression.literal(.character("\\"))
        XCTAssertEqual(printer.print(expr3), "'\\\\'")
    }

    func testBooleanLiterals() {
        let trueExpr = Expression.literal(.boolean(true))
        XCTAssertEqual(printer.print(trueExpr), "true")

        let falseExpr = Expression.literal(.boolean(false))
        XCTAssertEqual(printer.print(falseExpr), "false")
    }

    // MARK: - Identifier Tests

    func testIdentifier() {
        let expr = Expression.identifier("variable")
        XCTAssertEqual(printer.print(expr), "variable")
    }

    // MARK: - Binary Expression Tests

    func testSimpleBinaryExpression() {
        let expr = Expression.binary(.add, .literal(.integer(1)), .literal(.integer(2)))
        XCTAssertEqual(printer.print(expr), "1 + 2")
    }

    func testBinaryExpressionWithPrecedence() {
        // 1 + 2 * 3 should not have parentheses around 2 * 3
        let expr = Expression.binary(.add,
                                   .literal(.integer(1)),
                                   .binary(.multiply, .literal(.integer(2)), .literal(.integer(3))))
        XCTAssertEqual(printer.print(expr), "1 + 2 * 3")
    }

    func testBinaryExpressionNeedingParentheses() {
        // (1 + 2) * 3 should have parentheses around 1 + 2
        let expr = Expression.binary(.multiply,
                                   .binary(.add, .literal(.integer(1)), .literal(.integer(2))),
                                   .literal(.integer(3)))
        XCTAssertEqual(printer.print(expr), "(1 + 2) * 3")
    }

    func testUnicodeOperators() {
        let expr1 = Expression.binary(.notEqual, .identifier("a"), .identifier("b"))
        XCTAssertEqual(printer.print(expr1), "a ≠ b")

        let expr2 = Expression.binary(.greaterEqual, .identifier("x"), .literal(.integer(5)))
        XCTAssertEqual(printer.print(expr2), "x ≧ 5")

        let expr3 = Expression.binary(.lessEqual, .identifier("y"), .literal(.integer(10)))
        XCTAssertEqual(printer.print(expr3), "y ≦ 10")
    }

    func testLogicalOperators() {
        let expr1 = Expression.binary(.and, .identifier("a"), .identifier("b"))
        XCTAssertEqual(printer.print(expr1), "a and b")

        let expr2 = Expression.binary(.or, .identifier("x"), .identifier("y"))
        XCTAssertEqual(printer.print(expr2), "x or y")
    }

    // MARK: - Unary Expression Tests

    func testUnaryExpressions() {
        let notExpr = Expression.unary(.not, .identifier("flag"))
        XCTAssertEqual(printer.print(notExpr), "notflag")

        let plusExpr = Expression.unary(.plus, .literal(.integer(5)))
        XCTAssertEqual(printer.print(plusExpr), "+5")

        let minusExpr = Expression.unary(.minus, .literal(.integer(10)))
        XCTAssertEqual(printer.print(minusExpr), "-10")
    }

    // MARK: - Array Access Tests

    func testArrayAccess() {
        let expr = Expression.arrayAccess(.identifier("arr"), .literal(.integer(0)))
        XCTAssertEqual(printer.print(expr), "arr[0]")
    }

    func testNestedArrayAccess() {
        let expr = Expression.arrayAccess(
            .arrayAccess(.identifier("matrix"), .literal(.integer(1))),
            .literal(.integer(2))
        )
        XCTAssertEqual(printer.print(expr), "matrix[1][2]")
    }

    // MARK: - Field Access Tests

    func testFieldAccess() {
        let expr = Expression.fieldAccess(.identifier("person"), "name")
        XCTAssertEqual(printer.print(expr), "person.name")
    }

    func testChainedFieldAccess() {
        let expr = Expression.fieldAccess(
            .fieldAccess(.identifier("person"), "address"),
            "street"
        )
        XCTAssertEqual(printer.print(expr), "person.address.street")
    }

    // MARK: - Function Call Tests

    func testFunctionCallNoArgs() {
        let expr = Expression.functionCall("getValue", [])
        XCTAssertEqual(printer.print(expr), "getValue()")
    }

    func testFunctionCallWithArgs() {
        let expr = Expression.functionCall("add", [.literal(.integer(1)), .literal(.integer(2))])
        XCTAssertEqual(printer.print(expr), "add(1, 2)")
    }

    func testFunctionCallWithComplexArgs() {
        let expr = Expression.functionCall("calculate", [
            .binary(.add, .identifier("x"), .literal(.integer(1))),
            .functionCall("getValue", [])
        ])
        XCTAssertEqual(printer.print(expr), "calculate(x + 1, getValue())")
    }

    // MARK: - Assignment Statement Tests

    func testVariableAssignment() {
        let stmt = Statement.assignment(.variable("x", .literal(.integer(5))))
        XCTAssertEqual(printer.print(stmt), "x ← 5")
    }

    func testArrayElementAssignment() {
        let arrayAccess = Assignment.ArrayAccess(array: .identifier("arr"), index: .literal(.integer(0)))
        let stmt = Statement.assignment(.arrayElement(arrayAccess, .literal(.integer(10))))
        XCTAssertEqual(printer.print(stmt), "arr[0] ← 10")
    }

    // MARK: - Declaration Statement Tests

    func testVariableDeclaration() {
        let varDecl = VariableDeclaration(name: "x", type: .integer)
        let stmt = Statement.variableDeclaration(varDecl)
        XCTAssertEqual(printer.print(stmt), "変数 x: 整数型")
    }

    func testVariableDeclarationWithInitialValue() {
        let varDecl = VariableDeclaration(name: "y", type: .real, initialValue: .literal(.real(3.14)))
        let stmt = Statement.variableDeclaration(varDecl)
        XCTAssertEqual(printer.print(stmt), "変数 y: 実数型 ← 3.14")
    }

    func testConstantDeclaration() {
        let constDecl = ConstantDeclaration(name: "PI", type: .real, initialValue: .literal(.real(3.14159)))
        let stmt = Statement.constantDeclaration(constDecl)
        XCTAssertEqual(printer.print(stmt), "定数 PI: 実数型 ← 3.14159")
    }

    // MARK: - Data Type Tests

    func testDataTypes() {
        let intDecl = VariableDeclaration(name: "i", type: .integer)
        XCTAssertEqual(printer.print(.variableDeclaration(intDecl)), "変数 i: 整数型")

        let realDecl = VariableDeclaration(name: "r", type: .real)
        XCTAssertEqual(printer.print(.variableDeclaration(realDecl)), "変数 r: 実数型")

        let charDecl = VariableDeclaration(name: "c", type: .character)
        XCTAssertEqual(printer.print(.variableDeclaration(charDecl)), "変数 c: 文字型")

        let stringDecl = VariableDeclaration(name: "s", type: .string)
        XCTAssertEqual(printer.print(.variableDeclaration(stringDecl)), "変数 s: 文字列型")

        let boolDecl = VariableDeclaration(name: "b", type: .boolean)
        XCTAssertEqual(printer.print(.variableDeclaration(boolDecl)), "変数 b: 論理型")

        let arrayDecl = VariableDeclaration(name: "arr", type: .array(.integer))
        XCTAssertEqual(printer.print(.variableDeclaration(arrayDecl)), "変数 arr: 配列[整数型]")

        let recordDecl = VariableDeclaration(name: "person", type: .record("Person"))
        XCTAssertEqual(printer.print(.variableDeclaration(recordDecl)), "変数 person: レコード Person")
    }

    // MARK: - Control Flow Statement Tests

    func testIfStatement() {
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
        XCTAssertEqual(printer.print(stmt), expected)
    }

    func testIfElseStatement() {
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
        XCTAssertEqual(printer.print(stmt), expected)
    }

    func testIfElifElseStatement() {
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
        XCTAssertEqual(printer.print(stmt), expected)
    }

    func testWhileStatement() {
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
        XCTAssertEqual(printer.print(stmt), expected)
    }

    func testForRangeStatement() {
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
        XCTAssertEqual(printer.print(stmt), expected)
    }

    func testForRangeWithStepStatement() {
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
        XCTAssertEqual(printer.print(stmt), expected)
    }

    func testForEachStatement() {
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
        XCTAssertEqual(printer.print(stmt), expected)
    }

    // MARK: - Function and Procedure Declaration Tests

    func testFunctionDeclaration() {
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
        XCTAssertEqual(printer.print(stmt), expected)
    }

    func testFunctionDeclarationWithLocalVariables() {
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
        XCTAssertEqual(printer.print(stmt), expected)
    }

    func testProcedureDeclaration() {
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
        XCTAssertEqual(printer.print(stmt), expected)
    }

    // MARK: - Other Statement Tests

    func testReturnStatement() {
        let returnStmt = ReturnStatement(expression: .literal(.integer(42)))
        let stmt = Statement.returnStatement(returnStmt)
        XCTAssertEqual(printer.print(stmt), "return 42")
    }

    func testReturnStatementWithoutValue() {
        let returnStmt = ReturnStatement()
        let stmt = Statement.returnStatement(returnStmt)
        XCTAssertEqual(printer.print(stmt), "return")
    }

    func testBreakStatement() {
        let stmt = Statement.breakStatement
        XCTAssertEqual(printer.print(stmt), "break")
    }

    func testExpressionStatement() {
        let stmt = Statement.expressionStatement(.functionCall("doSomething", []))
        XCTAssertEqual(printer.print(stmt), "doSomething()")
    }

    func testBlockStatement() {
        let block = [
            Statement.assignment(.variable("x", .literal(.integer(1)))),
            Statement.assignment(.variable("y", .literal(.integer(2))))
        ]
        let stmt = Statement.block(block)
        let expected = """
        x ← 1
        y ← 2
        """
        XCTAssertEqual(printer.print(stmt), expected)
    }

    // MARK: - Configuration Tests

    func testCustomIndentation() {
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
        XCTAssertEqual(customPrinter.print(stmt), expected)
    }

    func testTabIndentation() {
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
        XCTAssertEqual(customPrinter.print(stmt), expected)
    }

    // MARK: - Multiple Statements Tests

    func testMultipleStatements() {
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
        XCTAssertEqual(printer.print(statements), expected)
    }
}
