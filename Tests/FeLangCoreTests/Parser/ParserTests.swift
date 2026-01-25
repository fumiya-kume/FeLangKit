import Foundation
import Testing
@testable import FeLangCore

@Suite("Parser Tests")
struct ParserTests {

    private let parser = Parser()

    // MARK: - Basic Parsing Tests

    @Test func testParseEmptyInput() throws {
        let statements = try parser.parse("")
        #expect(statements.isEmpty)
    }

    @Test func testParseSingleStatement() throws {
        let input = "変数 x: 整数型 ← 42"
        let statements = try parser.parse(input)
        #expect(statements.count == 1)
    }

    @Test func testParseMultipleStatements() throws {
        let input = """
        変数 x: 整数型 ← 1
        変数 y: 整数型 ← 2
        """
        let statements = try parser.parse(input)
        #expect(statements.count == 2)
    }

    // MARK: - Expression Parsing Tests

    @Test func testParseExpressionSimple() throws {
        let input = "42"
        let expression = try parser.parseExpression(input)

        if case .literal(let literal) = expression {
            if case .integer(let value) = literal {
                #expect(value == 42)
            } else {
                Issue.record("Expected integer literal")
            }
        } else {
            Issue.record("Expected literal expression")
        }
    }

    @Test func testParseExpressionComplex() throws {
        let input = "1 + 2 * 3"
        let expression = try parser.parseExpression(input)

        // Should parse as 1 + (2 * 3) due to operator precedence
        if case .binary(let binaryOp, let left, _) = expression {
            #expect(binaryOp == .add)
            if case .literal(let literal) = left {
                if case .integer(let value) = literal {
                    #expect(value == 1)
                }
            }
        } else {
            Issue.record("Expected binary expression")
        }
    }

    // MARK: - Validation Tests

    @Test func testValidateValidCode() throws {
        let input = "変数 x: 整数型 ← 42"
        let isValid = parser.validate(input)
        #expect(isValid == true)
    }

    @Test func testValidateInvalidCode() throws {
        let input = "変数 x: ← 42"  // Missing type
        let isValid = parser.validate(input)
        #expect(isValid == false)
    }

    // MARK: - Error Collection Tests

    @Test func testCollectErrorsNoErrors() throws {
        let input = "変数 x: 整数型 ← 42"
        let errors = parser.collectErrors(input)
        #expect(errors.isEmpty)
    }

    @Test func testCollectErrorsWithSyntaxError() throws {
        let input = "変数 x: ← 42"  // Missing type
        let errors = parser.collectErrors(input)
        #expect(!errors.isEmpty)
    }

    // MARK: - Statement Fragment Tests

    @Test func testParseFragmentVariableDeclaration() throws {
        let input = "変数 counter: 整数型 ← 0"
        let statements = try parser.parse(input)

        #expect(statements.count == 1)
        if case .variableDeclaration(let decl) = statements[0] {
            #expect(decl.name == "counter")
            #expect(decl.type == .integer)
        } else {
            Issue.record("Expected variable declaration")
        }
    }

    @Test func testParseFragmentConstantDeclaration() throws {
        let input = "定数 PI: 実数型 ← 3.14"
        let statements = try parser.parse(input)

        #expect(statements.count == 1)
        if case .constantDeclaration(let decl) = statements[0] {
            #expect(decl.name == "PI")
            #expect(decl.type == .real)
        } else {
            Issue.record("Expected constant declaration")
        }
    }

    @Test func testParseFragmentIfStatement() throws {
        let input = "if x > 0 then y ← 1 endif"
        let statements = try parser.parse(input)

        #expect(statements.count == 1)
        if case .ifStatement(let ifStmt) = statements[0] {
            #expect(ifStmt.thenBody.count == 1)
        } else {
            Issue.record("Expected if statement")
        }
    }

    @Test func testParseFragmentWhileStatement() throws {
        let input = "while x > 0 do x ← x - 1 endwhile"
        let statements = try parser.parse(input)

        #expect(statements.count == 1)
        if case .whileStatement(let whileStmt) = statements[0] {
            #expect(whileStmt.body.count == 1)
        } else {
            Issue.record("Expected while statement")
        }
    }

    @Test func testParseFragmentForStatement() throws {
        let input = "for i ← 1 to 10 do sum ← sum + i endfor"
        let statements = try parser.parse(input)

        #expect(statements.count == 1)
        if case .forStatement(let forStmt) = statements[0] {
            if case .range(let rangeFor) = forStmt {
                #expect(rangeFor.variable == "i")
                #expect(rangeFor.body.count == 1)
            } else {
                Issue.record("Expected range for statement")
            }
        } else {
            Issue.record("Expected for statement")
        }
    }

    @Test func testParseFragmentFunctionDeclaration() throws {
        let input = "function add(a: integer, b: integer): integer return a + b endfunction"
        let statements = try parser.parse(input)

        #expect(statements.count == 1)
        if case .functionDeclaration(let funcDecl) = statements[0] {
            #expect(funcDecl.name == "add")
            #expect(funcDecl.parameters.count == 2)
            #expect(funcDecl.returnType == .integer)
        } else {
            Issue.record("Expected function declaration")
        }
    }

    @Test func testParseFragmentProcedureDeclaration() throws {
        let input = "procedure greet(name: string) x ← 1 endprocedure"
        let statements = try parser.parse(input)

        #expect(statements.count == 1)
        if case .procedureDeclaration(let procDecl) = statements[0] {
            #expect(procDecl.name == "greet")
            #expect(procDecl.parameters.count == 1)
        } else {
            Issue.record("Expected procedure declaration")
        }
    }

    @Test func testParseFragmentAssignment() throws {
        let input = "x ← 42"
        let statements = try parser.parse(input)

        #expect(statements.count == 1)
        if case .assignment(let assignment) = statements[0] {
            if case .variable(let name, _) = assignment {
                #expect(name == "x")
            } else {
                Issue.record("Expected variable assignment")
            }
        } else {
            Issue.record("Expected assignment statement")
        }
    }

    @Test func testParseFragmentReturnStatement() throws {
        let input = "function getValue(): integer return 42 endfunction"
        let statements = try parser.parse(input)

        #expect(statements.count == 1)
        if case .functionDeclaration(let funcDecl) = statements[0] {
            #expect(funcDecl.body.count == 1)
            if case .returnStatement = funcDecl.body[0] {
                // Success
            } else {
                Issue.record("Expected return statement in function body")
            }
        } else {
            Issue.record("Expected function declaration")
        }
    }

}
