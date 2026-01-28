import Foundation
import Testing
@testable import FeLangCore

@Suite("StatementAST Tests")
struct StatementASTTests {

    // MARK: - DataType Tests

    @Test func testDataTypeInitFromIntegerType() throws {
        let dataType = DataType(tokenType: .integerType)
        #expect(dataType == .integer)
    }

    @Test func testDataTypeInitFromRealType() throws {
        let dataType = DataType(tokenType: .realType)
        #expect(dataType == .real)
    }

    @Test func testDataTypeInitFromCharacterType() throws {
        let dataType = DataType(tokenType: .characterType)
        #expect(dataType == .character)
    }

    @Test func testDataTypeInitFromStringType() throws {
        let dataType = DataType(tokenType: .stringType)
        #expect(dataType == .string)
    }

    @Test func testDataTypeInitFromBooleanType() throws {
        let dataType = DataType(tokenType: .booleanType)
        #expect(dataType == .boolean)
    }

    @Test func testDataTypeInitReturnsNilForArrayType() throws {
        let dataType = DataType(tokenType: .arrayType)
        #expect(dataType == nil)
    }

    @Test func testDataTypeInitReturnsNilForRecordType() throws {
        let dataType = DataType(tokenType: .recordType)
        #expect(dataType == nil)
    }

    @Test func testDataTypeInitReturnsNilForUnknownType() throws {
        let dataType = DataType(tokenType: .identifier)
        #expect(dataType == nil)
    }

    // MARK: - DataType Equatable Tests

    @Test func testDataTypeEquatable() throws {
        #expect(DataType.integer == DataType.integer)
        #expect(DataType.real == DataType.real)
        #expect(DataType.integer != DataType.real)
    }

    @Test func testDataTypeArrayEquatable() throws {
        #expect(DataType.array(.integer) == DataType.array(.integer))
        #expect(DataType.array(.integer) != DataType.array(.real))
    }

    @Test func testDataTypeRecordEquatable() throws {
        #expect(DataType.record("Person") == DataType.record("Person"))
        #expect(DataType.record("Person") != DataType.record("Car"))
    }

    // MARK: - VariableDeclaration Tests

    @Test func testVariableDeclarationInit() throws {
        let decl = VariableDeclaration(name: "myVar", type: .integer)
        #expect(decl.name == "myVar")
        #expect(decl.type == .integer)
        #expect(decl.initialValue == nil)
        #expect(decl.position == nil)
    }

    @Test func testVariableDeclarationWithInitialValue() throws {
        let initialValue = Expression.literal(.integer(42))
        let decl = VariableDeclaration(name: "myVar", type: .integer, initialValue: initialValue)
        #expect(decl.name == "myVar")
        #expect(decl.type == .integer)
        #expect(decl.initialValue != nil)
    }

    @Test func testVariableDeclarationWithPosition() throws {
        let position = SourcePosition(line: 1, column: 1, offset: 0)
        let decl = VariableDeclaration(name: "myVar", type: .integer, position: position)
        #expect(decl.position != nil)
        #expect(decl.position?.line == 1)
    }

    @Test func testVariableDeclarationEquatable() throws {
        let decl1 = VariableDeclaration(name: "myVar", type: .integer)
        let decl2 = VariableDeclaration(name: "myVar", type: .integer)
        let decl3 = VariableDeclaration(name: "otherVar", type: .integer)
        #expect(decl1 == decl2)
        #expect(decl1 != decl3)
    }

    // MARK: - ConstantDeclaration Tests

    @Test func testConstantDeclarationInit() throws {
        let initialValue = Expression.literal(.real(3.14))
        let decl = ConstantDeclaration(name: "PI", type: .real, initialValue: initialValue)
        #expect(decl.name == "PI")
        #expect(decl.type == .real)
    }

    @Test func testConstantDeclarationEquatable() throws {
        let value1 = Expression.literal(.integer(42))
        let value2 = Expression.literal(.integer(42))
        let decl1 = ConstantDeclaration(name: "X", type: .integer, initialValue: value1)
        let decl2 = ConstantDeclaration(name: "X", type: .integer, initialValue: value2)
        #expect(decl1 == decl2)
    }

    // MARK: - IfStatement Tests

    @Test func testIfStatementInit() throws {
        let condition = Expression.literal(.boolean(true))
        let body = [Statement.breakStatement]
        let ifStmt = IfStatement(condition: condition, thenBody: body)
        #expect(ifStmt.thenBody.count == 1)
        #expect(ifStmt.elseIfs.isEmpty)
        #expect(ifStmt.elseBody == nil)
    }

    @Test func testIfStatementWithElse() throws {
        let condition = Expression.literal(.boolean(true))
        let thenBody = [Statement.breakStatement]
        let elseBody = [Statement.continueStatement]
        let ifStmt = IfStatement(condition: condition, thenBody: thenBody, elseBody: elseBody)
        #expect(ifStmt.elseBody != nil)
        #expect(ifStmt.elseBody?.count == 1)
    }

    @Test func testIfStatementWithElseIf() throws {
        let condition = Expression.literal(.boolean(true))
        let thenBody = [Statement.breakStatement]
        let elseIfCondition = Expression.literal(.boolean(false))
        let elseIfBody = [Statement.continueStatement]
        let elseIf = IfStatement.ElseIf(condition: elseIfCondition, body: elseIfBody)
        let ifStmt = IfStatement(condition: condition, thenBody: thenBody, elseIfs: [elseIf])
        #expect(ifStmt.elseIfs.count == 1)
    }

    @Test func testIfStatementEquatable() throws {
        let condition = Expression.literal(.boolean(true))
        let body = [Statement.breakStatement]
        let if1 = IfStatement(condition: condition, thenBody: body)
        let if2 = IfStatement(condition: condition, thenBody: body)
        #expect(if1 == if2)
    }

    // MARK: - WhileStatement Tests

    @Test func testWhileStatementInit() throws {
        let condition = Expression.literal(.boolean(true))
        let body = [Statement.breakStatement]
        let whileStmt = WhileStatement(condition: condition, body: body)
        #expect(whileStmt.body.count == 1)
    }

    @Test func testWhileStatementEquatable() throws {
        let condition = Expression.literal(.boolean(true))
        let body = [Statement.breakStatement]
        let while1 = WhileStatement(condition: condition, body: body)
        let while2 = WhileStatement(condition: condition, body: body)
        #expect(while1 == while2)
    }

    // MARK: - ForStatement Tests

    @Test func testForStatementRangeInit() throws {
        let rangeFor = ForStatement.RangeFor(
            variable: "i",
            start: .literal(.integer(1)),
            end: .literal(.integer(10)),
            body: [.breakStatement]
        )
        let forStmt = ForStatement.range(rangeFor)
        guard case .range(let range) = forStmt else {
            Issue.record("Expected range for statement")
            return
        }
        #expect(range.variable == "i")
        #expect(range.step == nil)
    }

    @Test func testForStatementRangeWithStep() throws {
        let rangeFor = ForStatement.RangeFor(
            variable: "i",
            start: .literal(.integer(1)),
            end: .literal(.integer(10)),
            step: .literal(.integer(2)),
            body: [.breakStatement]
        )
        let forStmt = ForStatement.range(rangeFor)
        guard case .range(let range) = forStmt else {
            Issue.record("Expected range for statement")
            return
        }
        #expect(range.step != nil)
    }

    @Test func testForStatementForEachInit() throws {
        let forEach = ForStatement.ForEachLoop(
            variable: "item",
            iterable: .identifier("list"),
            body: [.breakStatement]
        )
        let forStmt = ForStatement.forEach(forEach)
        guard case .forEach(let loop) = forStmt else {
            Issue.record("Expected forEach statement")
            return
        }
        #expect(loop.variable == "item")
    }

    @Test func testForStatementEquatable() throws {
        let range1 = ForStatement.RangeFor(
            variable: "i",
            start: .literal(.integer(1)),
            end: .literal(.integer(10)),
            body: []
        )
        let range2 = ForStatement.RangeFor(
            variable: "i",
            start: .literal(.integer(1)),
            end: .literal(.integer(10)),
            body: []
        )
        #expect(ForStatement.range(range1) == ForStatement.range(range2))
    }

    // MARK: - Assignment Tests

    @Test func testAssignmentVariable() throws {
        let assignment = Assignment.variable("x", .literal(.integer(42)))
        guard case .variable(let name, _) = assignment else {
            Issue.record("Expected variable assignment")
            return
        }
        #expect(name == "x")
    }

    @Test func testAssignmentArrayElement() throws {
        let arrayAccess = Assignment.ArrayAccess(
            array: .identifier("arr"),
            index: .literal(.integer(0))
        )
        let assignment = Assignment.arrayElement(arrayAccess, .literal(.integer(42)))
        guard case .arrayElement(let access, _) = assignment else {
            Issue.record("Expected array element assignment")
            return
        }
        #expect(access.array == .identifier("arr"))
    }

    @Test func testAssignmentEquatable() throws {
        let assign1 = Assignment.variable("x", .literal(.integer(42)))
        let assign2 = Assignment.variable("x", .literal(.integer(42)))
        let assign3 = Assignment.variable("y", .literal(.integer(42)))
        #expect(assign1 == assign2)
        #expect(assign1 != assign3)
    }

    // MARK: - FunctionDeclaration Tests

    @Test func testFunctionDeclarationInit() throws {
        let func1 = FunctionDeclaration(
            name: "add",
            parameters: [
                Parameter(name: "a", type: .integer),
                Parameter(name: "b", type: .integer)
            ],
            returnType: .integer,
            body: [.returnStatement(ReturnStatement(expression: .literal(.integer(0))))]
        )
        #expect(func1.name == "add")
        #expect(func1.parameters.count == 2)
        #expect(func1.returnType == .integer)
    }

    @Test func testFunctionDeclarationWithoutReturnType() throws {
        let func1 = FunctionDeclaration(
            name: "doSomething",
            parameters: [],
            body: []
        )
        #expect(func1.returnType == nil)
    }

    @Test func testFunctionDeclarationEquatable() throws {
        let func1 = FunctionDeclaration(name: "test", parameters: [], body: [])
        let func2 = FunctionDeclaration(name: "test", parameters: [], body: [])
        #expect(func1 == func2)
    }

    // MARK: - ProcedureDeclaration Tests

    @Test func testProcedureDeclarationInit() throws {
        let proc = ProcedureDeclaration(
            name: "greet",
            parameters: [Parameter(name: "name", type: .string)],
            body: []
        )
        #expect(proc.name == "greet")
        #expect(proc.parameters.count == 1)
    }

    @Test func testProcedureDeclarationEquatable() throws {
        let proc1 = ProcedureDeclaration(name: "test", parameters: [], body: [])
        let proc2 = ProcedureDeclaration(name: "test", parameters: [], body: [])
        #expect(proc1 == proc2)
    }

    // MARK: - Parameter Tests

    @Test func testParameterInit() throws {
        let param = Parameter(name: "value", type: .integer)
        #expect(param.name == "value")
        #expect(param.type == .integer)
    }

    @Test func testParameterEquatable() throws {
        let param1 = Parameter(name: "x", type: .integer)
        let param2 = Parameter(name: "x", type: .integer)
        let param3 = Parameter(name: "y", type: .integer)
        #expect(param1 == param2)
        #expect(param1 != param3)
    }

    // MARK: - ReturnStatement Tests

    @Test func testReturnStatementWithExpression() throws {
        let returnStmt = ReturnStatement(expression: .literal(.integer(42)))
        #expect(returnStmt.expression != nil)
    }

    @Test func testReturnStatementWithoutExpression() throws {
        let returnStmt = ReturnStatement()
        #expect(returnStmt.expression == nil)
    }

    @Test func testReturnStatementEquatable() throws {
        let return1 = ReturnStatement(expression: .literal(.integer(42)))
        let return2 = ReturnStatement(expression: .literal(.integer(42)))
        #expect(return1 == return2)
    }

    // MARK: - Statement Enum Tests

    @Test func testStatementBreak() throws {
        let stmt = Statement.breakStatement
        guard case .breakStatement = stmt else {
            Issue.record("Expected break statement")
            return
        }
    }

    @Test func testStatementContinue() throws {
        let stmt = Statement.continueStatement
        guard case .continueStatement = stmt else {
            Issue.record("Expected continue statement")
            return
        }
    }

    @Test func testStatementBlock() throws {
        let stmt = Statement.block([.breakStatement, .continueStatement])
        guard case .block(let statements) = stmt else {
            Issue.record("Expected block statement")
            return
        }
        #expect(statements.count == 2)
    }

    @Test func testStatementEquatable() throws {
        #expect(Statement.breakStatement == Statement.breakStatement)
        #expect(Statement.continueStatement == Statement.continueStatement)
        #expect(Statement.breakStatement != Statement.continueStatement)
    }

    // MARK: - Codable Tests

    @Test func testDataTypeCodable() throws {
        let original = DataType.integer
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DataType.self, from: data)
        #expect(decoded == original)
    }

    @Test func testVariableDeclarationCodable() throws {
        let original = VariableDeclaration(name: "x", type: .integer)
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(VariableDeclaration.self, from: data)
        #expect(decoded == original)
    }

    @Test func testStatementCodable() throws {
        let original = Statement.breakStatement
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Statement.self, from: data)
        #expect(decoded == original)
    }

    // MARK: - Sendable Tests

    @Test func testStatementSendable() async throws {
        let stmt = Statement.breakStatement
        let task = Task {
            return stmt
        }
        let result = await task.value
        #expect(result == stmt)
    }
}
