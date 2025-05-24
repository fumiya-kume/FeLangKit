import Testing
@testable import FeLangCore

// Alias to avoid conflict with Foundation.Expression
typealias FEStatement = FeLangCore.Statement

@Suite("Statement Parser Tests")
struct StatementParserTests {

    let parser = StatementParser()

    /// Helper method to tokenize and parse statements
    private func parseStatements(_ input: String) throws -> [FEStatement] {
        let tokens = try ParsingTokenizer().tokenize(input)
        return try parser.parseStatements(from: tokens)
    }

    // MARK: - String Literal Tests

    @Test("String with Escape Sequences")
    func testStringWithEscapeSequences() throws {
        let statements = try parseStatements("writeLine(\"Hello\\nWorld\\t!\")")

        #expect(statements.count == 1)
        guard case .expressionStatement(.functionCall("writeLine", let args)) = statements[0] else {
            #expect(Bool(false), "Expected expression statement with function call")
            return
        }

        #expect(args.count == 1)
        #expect(args[0] == .literal(.string("Hello\nWorld\t!")))
    }

    @Test("String with Escaped Quotes")
    func testStringWithEscapedQuotes() throws {
        let statements = try parseStatements("writeLine(\"She said \\\"Hello\\\"\")")

        #expect(statements.count == 1)
        guard case .expressionStatement(.functionCall("writeLine", let args)) = statements[0] else {
            #expect(Bool(false), "Expected expression statement with function call")
            return
        }

        #expect(args.count == 1)
        #expect(args[0] == .literal(.string("She said \"Hello\"")))
    }

    // MARK: - Assignment Statement Tests

    @Test("Variable Assignment")
    func testVariableAssignment() throws {
        let statements = try parseStatements("x ← 5")

        #expect(statements.count == 1)
        if case .assignment(.variable("x", .literal(.integer(5)))) = statements[0] {
            // Test passed
        } else {
            #expect(Bool(false), "Expected variable assignment")
        }
    }

    @Test("Array Element Assignment")
    func testArrayElementAssignment() throws {
        let statements = try parseStatements("arr[0] ← 10")

        #expect(statements.count == 1)
        guard case .assignment(.arrayElement(let arrayAccess, .literal(.integer(10)))) = statements[0] else {
            #expect(Bool(false), "Expected array element assignment")
            return
        }
        #expect(arrayAccess.array == .identifier("arr"))
        #expect(arrayAccess.index == .literal(.integer(0)))
    }

    // MARK: - IF Statement Tests

    @Test("Basic IF Statement")
    func testBasicIfStatement() throws {
        let input = """
        if x > 0 then
            y ← 1
        endif
        """
        let statements = try parseStatements(input)

        #expect(statements.count == 1)
        guard case .ifStatement(let ifStmt) = statements[0] else {
            #expect(Bool(false), "Expected IF statement")
            return
        }

        #expect(ifStmt.condition == .binary(.greater, .identifier("x"), .literal(.integer(0))))
        #expect(ifStmt.thenBody.count == 1)
        #expect(ifStmt.elseIfs.isEmpty)
        #expect(ifStmt.elseBody == nil)
    }

    @Test("IF-ELSE Statement")
    func testIfElseStatement() throws {
        let input = """
        if x > 0 then
            y ← 1
        else
            y ← -1
        endif
        """
        let statements = try parseStatements(input)

        #expect(statements.count == 1)
        guard case .ifStatement(let ifStmt) = statements[0] else {
            #expect(Bool(false), "Expected IF statement")
            return
        }

        #expect(ifStmt.condition == .binary(.greater, .identifier("x"), .literal(.integer(0))))
        #expect(ifStmt.thenBody.count == 1)
        #expect(ifStmt.elseIfs.isEmpty)
        #expect(ifStmt.elseBody?.count == 1)
    }

    @Test("IF-ELIF-ELSE Statement")
    func testIfElifElseStatement() throws {
        let input = """
        if x > 0 then
            y ← 1
        elif x = 0 then
            y ← 0
        else
            y ← -1
        endif
        """
        let statements = try parseStatements(input)

        #expect(statements.count == 1)
        guard case .ifStatement(let ifStmt) = statements[0] else {
            #expect(Bool(false), "Expected IF statement")
            return
        }

        #expect(ifStmt.condition == .binary(.greater, .identifier("x"), .literal(.integer(0))))
        #expect(ifStmt.thenBody.count == 1)
        #expect(ifStmt.elseIfs.count == 1)
        #expect(ifStmt.elseBody?.count == 1)

        let elif = ifStmt.elseIfs[0]
        #expect(elif.condition == .binary(.equal, .identifier("x"), .literal(.integer(0))))
        #expect(elif.body.count == 1)
    }

    // MARK: - WHILE Statement Tests

    @Test("Basic WHILE Statement")
    func testWhileStatement() throws {
        let input = """
        while i ≦ 10 do
            sum ← sum + i
            i ← i + 1
        endwhile
        """
        let statements = try parseStatements(input)

        #expect(statements.count == 1)
        guard case .whileStatement(let whileStmt) = statements[0] else {
            #expect(Bool(false), "Expected WHILE statement")
            return
        }

        #expect(whileStmt.condition == .binary(.lessEqual, .identifier("i"), .literal(.integer(10))))
        #expect(whileStmt.body.count == 2)
    }

    // MARK: - FOR Statement Tests

    @Test("Range-based FOR Statement")
    func testRangeForStatement() throws {
        let input = """
        for i ← 1 to 10 step 1 do
            sum ← sum + i
        endfor
        """
        let statements = try parseStatements(input)

        #expect(statements.count == 1)
        guard case .forStatement(.range(let rangeFor)) = statements[0] else {
            #expect(Bool(false), "Expected range-based FOR statement")
            return
        }

        #expect(rangeFor.variable == "i")
        #expect(rangeFor.start == .literal(.integer(1)))
        #expect(rangeFor.end == .literal(.integer(10)))
        #expect(rangeFor.step == .literal(.integer(1)))
        #expect(rangeFor.body.count == 1)
    }

    @Test("Range-based FOR Statement without step")
    func testRangeForStatementNoStep() throws {
        let input = """
        for i ← 1 to 10 do
            sum ← sum + i
        endfor
        """
        let statements = try parseStatements(input)

        #expect(statements.count == 1)
        guard case .forStatement(.range(let rangeFor)) = statements[0] else {
            #expect(Bool(false), "Expected range-based FOR statement")
            return
        }

        #expect(rangeFor.variable == "i")
        #expect(rangeFor.start == .literal(.integer(1)))
        #expect(rangeFor.end == .literal(.integer(10)))
        #expect(rangeFor.step == nil)
        #expect(rangeFor.body.count == 1)
    }

    @Test("ForEach Statement")
    func testForEachStatement() throws {
        let input = """
        for item in array do
            writeLine(item)
        endfor
        """
        let statements = try parseStatements(input)

        #expect(statements.count == 1)
        guard case .forStatement(.forEach(let forEach)) = statements[0] else {
            #expect(Bool(false), "Expected forEach FOR statement")
            return
        }

        #expect(forEach.variable == "item")
        #expect(forEach.iterable == .identifier("array"))
        #expect(forEach.body.count == 1)
    }

    // MARK: - Return Statement Tests

    @Test("Return Statement with Expression")
    func testReturnWithExpression() throws {
        let statements = try parseStatements("return x + 1")

        #expect(statements.count == 1)
        guard case .returnStatement(let returnStmt) = statements[0] else {
            #expect(Bool(false), "Expected return statement")
            return
        }

        #expect(returnStmt.expression == .binary(.add, .identifier("x"), .literal(.integer(1))))
    }

    @Test("Return Statement without Expression")
    func testReturnWithoutExpression() throws {
        let statements = try parseStatements("return")

        #expect(statements.count == 1)
        guard case .returnStatement(let returnStmt) = statements[0] else {
            #expect(Bool(false), "Expected return statement")
            return
        }

        #expect(returnStmt.expression == nil)
    }

    // MARK: - Break Statement Tests

    @Test("Break Statement")
    func testBreakStatement() throws {
        let statements = try parseStatements("break")

        #expect(statements.count == 1)
        guard case .breakStatement = statements[0] else {
            #expect(Bool(false), "Expected break statement")
            return
        }
    }

    // MARK: - Function Declaration Tests

    @Test("Function Declaration with Return Type")
    func testFunctionDeclarationWithReturnType() throws {
        let input = """
        function add(a: 整数型, b: 整数型): 整数型
            return a + b
        endfunction
        """
        let statements = try parseStatements(input)

        #expect(statements.count == 1)
        guard case .functionDeclaration(let funcDecl) = statements[0] else {
            #expect(Bool(false), "Expected function declaration")
            return
        }

        #expect(funcDecl.name == "add")
        #expect(funcDecl.parameters.count == 2)
        #expect(funcDecl.parameters[0].name == "a")
        #expect(funcDecl.parameters[0].type == .integer)
        #expect(funcDecl.parameters[1].name == "b")
        #expect(funcDecl.parameters[1].type == .integer)
        #expect(funcDecl.returnType == .integer)
        #expect(funcDecl.body.count == 1)
    }

    @Test("Function Declaration without Return Type")
    func testFunctionDeclarationWithoutReturnType() throws {
        let input = """
        function getValue()
            return 42
        endfunction
        """
        let statements = try parseStatements(input)

        #expect(statements.count == 1)
        guard case .functionDeclaration(let funcDecl) = statements[0] else {
            #expect(Bool(false), "Expected function declaration")
            return
        }

        #expect(funcDecl.name == "getValue")
        #expect(funcDecl.parameters.isEmpty)
        #expect(funcDecl.returnType == nil)
        #expect(funcDecl.body.count == 1)
    }

    // MARK: - Procedure Declaration Tests

    @Test("Procedure Declaration")
    func testProcedureDeclaration() throws {
        let input = """
        procedure printValue(x: 整数型)
            writeLine(x)
        endprocedure
        """
        let statements = try parseStatements(input)

        #expect(statements.count == 1)
        guard case .procedureDeclaration(let procDecl) = statements[0] else {
            #expect(Bool(false), "Expected procedure declaration")
            return
        }

        #expect(procDecl.name == "printValue")
        #expect(procDecl.parameters.count == 1)
        #expect(procDecl.parameters[0].name == "x")
        #expect(procDecl.parameters[0].type == .integer)
        #expect(procDecl.body.count == 1)
    }

    // MARK: - Expression Statement Tests

    @Test("Expression Statement - Function Call")
    func testExpressionStatementFunctionCall() throws {
        let statements = try parseStatements("writeLine(x)")

        #expect(statements.count == 1)
        guard case .expressionStatement(.functionCall("writeLine", let args)) = statements[0] else {
            #expect(Bool(false), "Expected expression statement with function call")
            return
        }

        #expect(args.count == 1)
        #expect(args[0] == .identifier("x"))
    }

    // MARK: - Nested Statement Tests

    @Test("Nested Control Structures")
    func testNestedControlStructures() throws {
        let input = """
        if found then
            for i ← 0 to 10 do
                if array[i] = target then
                    writeLine(i)
                    break
                endif
            endfor
        else
            writeLine("Not found")
        endif
        """
        let statements = try parseStatements(input)

        #expect(statements.count == 1)
        guard case .ifStatement(let ifStmt) = statements[0] else {
            #expect(Bool(false), "Expected IF statement")
            return
        }

        #expect(ifStmt.condition == .identifier("found"))
        #expect(ifStmt.thenBody.count == 1)
        #expect(ifStmt.elseBody?.count == 1)

        // Check nested FOR statement
        guard case .forStatement(.range(let rangeFor)) = ifStmt.thenBody[0] else {
            #expect(Bool(false), "Expected nested FOR statement")
            return
        }

        #expect(rangeFor.variable == "i")
        #expect(rangeFor.body.count == 1)

        // Check nested IF statement
        guard case .ifStatement(let nestedIf) = rangeFor.body[0] else {
            #expect(Bool(false), "Expected nested IF statement")
            return
        }

        #expect(nestedIf.thenBody.count == 2)
        guard case .breakStatement = nestedIf.thenBody[1] else {
            #expect(Bool(false), "Expected break statement")
            return
        }
    }
}
