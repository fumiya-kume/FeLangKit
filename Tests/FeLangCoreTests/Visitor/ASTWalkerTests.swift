import XCTest
@testable import FeLangCore

final class ASTWalkerTests: XCTestCase {

    // MARK: - Expression Walker Tests

    func testExpressionCounter() {
        let counter = ASTWalker.createExpressionCounter()

        // Test simple literal
        XCTAssertEqual(counter.visit(.literal(.integer(42))), 1)

        // Test identifier
        XCTAssertEqual(counter.visit(.identifier("x")), 1)

        // Test binary expression: 1 + 2 (3 nodes total)
        let binaryExpr = Expression.binary(.add, .literal(.integer(1)), .literal(.integer(2)))
        XCTAssertEqual(counter.visit(binaryExpr), 3)

        // Test nested binary expression: (1 + 2) * 3 (5 nodes total)
        let nestedExpr = Expression.binary(.multiply, binaryExpr, .literal(.integer(3)))
        XCTAssertEqual(counter.visit(nestedExpr), 5)

        // Test unary expression: not true (2 nodes total)
        let unaryExpr = Expression.unary(.not, .literal(.boolean(true)))
        XCTAssertEqual(counter.visit(unaryExpr), 2)

        // Test array access: arr[0] (3 nodes total)
        let arrayAccess = Expression.arrayAccess(.identifier("arr"), .literal(.integer(0)))
        XCTAssertEqual(counter.visit(arrayAccess), 3)

        // Test field access: obj.prop (2 nodes total)
        let fieldAccess = Expression.fieldAccess(.identifier("obj"), "prop")
        XCTAssertEqual(counter.visit(fieldAccess), 2)

        // Test function call: func(1, x) (4 nodes total)
        let funcCall = Expression.functionCall("func", [.literal(.integer(1)), .identifier("x")])
        XCTAssertEqual(counter.visit(funcCall), 4)
    }

    func testIdentifierCollector() {
        let collector = ASTWalker.createIdentifierCollector()

        // Test literal (no identifiers)
        XCTAssertEqual(collector.visit(.literal(.integer(42))), [])

        // Test single identifier
        XCTAssertEqual(collector.visit(.identifier("x")), ["x"])

        // Test binary expression with identifiers: x + y
        let binaryExpr = Expression.binary(.add, .identifier("x"), .identifier("y"))
        XCTAssertEqual(Set(collector.visit(binaryExpr)), Set(["x", "y"]))

        // Test mixed expression: x + 1
        let mixedExpr = Expression.binary(.add, .identifier("x"), .literal(.integer(1)))
        XCTAssertEqual(collector.visit(mixedExpr), ["x"])

        // Test function call: func(x, y, 1)
        let funcCall = Expression.functionCall("func", [
            .identifier("x"),
            .identifier("y"),
            .literal(.integer(1))
        ])
        XCTAssertEqual(Set(collector.visit(funcCall)), Set(["x", "y"]))

        // Test array access: arr[index]
        let arrayAccess = Expression.arrayAccess(.identifier("arr"), .identifier("index"))
        XCTAssertEqual(Set(collector.visit(arrayAccess)), Set(["arr", "index"]))

        // Test field access: obj.prop
        let fieldAccess = Expression.fieldAccess(.identifier("obj"), "prop")
        XCTAssertEqual(collector.visit(fieldAccess), ["obj"])
    }

    func testExpressionStringifier() {
        let stringifier = ASTWalker.createExpressionStringifier()

        // Test literals
        XCTAssertEqual(stringifier.visit(.literal(.integer(42))), "42")
        XCTAssertEqual(stringifier.visit(.literal(.real(3.14))), "3.14")
        XCTAssertEqual(stringifier.visit(.literal(.string("hello"))), "\"hello\"")
        XCTAssertEqual(stringifier.visit(.literal(.character("x"))), "'x'")
        XCTAssertEqual(stringifier.visit(.literal(.boolean(true))), "true")

        // Test identifier
        XCTAssertEqual(stringifier.visit(.identifier("variable")), "variable")

        // Test binary expression with proper parentheses
        let binaryExpr = Expression.binary(.add, .literal(.integer(1)), .literal(.integer(2)))
        XCTAssertEqual(stringifier.visit(binaryExpr), "(1 + 2)")

        // Test nested binary expression
        let nestedExpr = Expression.binary(.multiply, binaryExpr, .literal(.integer(3)))
        XCTAssertEqual(stringifier.visit(nestedExpr), "((1 + 2) * 3)")

        // Test unary expression
        let unaryExpr = Expression.unary(.not, .literal(.boolean(true)))
        XCTAssertEqual(stringifier.visit(unaryExpr), "not true")

        // Test array access
        let arrayAccess = Expression.arrayAccess(.identifier("arr"), .literal(.integer(0)))
        XCTAssertEqual(stringifier.visit(arrayAccess), "arr[0]")

        // Test field access
        let fieldAccess = Expression.fieldAccess(.identifier("obj"), "prop")
        XCTAssertEqual(stringifier.visit(fieldAccess), "obj.prop")

        // Test function call
        let funcCall = Expression.functionCall("max", [.literal(.integer(1)), .literal(.integer(2))])
        XCTAssertEqual(stringifier.visit(funcCall), "max(1, 2)")
    }

    // MARK: - Statement Walker Tests

    func testStatementCounter() {
        let counter = ASTWalker.createStatementCounter()

        // Test simple statements
        XCTAssertEqual(counter.visit(.breakStatement), 1)

        let assignment = Statement.assignment(.variable("x", .literal(.integer(42))))
        XCTAssertEqual(counter.visit(assignment), 1)

        // Test if statement with body
        let ifStmt = IfStatement(
            condition: .literal(.boolean(true)),
            thenBody: [.breakStatement, assignment]
        )
        let ifStatement = Statement.ifStatement(ifStmt)
        XCTAssertEqual(counter.visit(ifStatement), 3) // if + break + assignment

        // Test while statement with body
        let whileStmt = WhileStatement(
            condition: .literal(.boolean(true)),
            body: [.breakStatement]
        )
        let whileStatement = Statement.whileStatement(whileStmt)
        XCTAssertEqual(counter.visit(whileStatement), 2) // while + break

        // Test for range statement
        let rangeFor = ForStatement.RangeFor(
            variable: "i",
            start: .literal(.integer(0)),
            end: .literal(.integer(10)),
            body: [.breakStatement]
        )
        let forStatement = Statement.forStatement(.range(rangeFor))
        XCTAssertEqual(counter.visit(forStatement), 2) // for + break

        // Test block statement
        let block = Statement.block([.breakStatement, assignment])
        XCTAssertEqual(counter.visit(block), 3) // block + break + assignment
    }

    func testNameCollector() {
        let collector = ASTWalker.createNameCollector()

        // Test simple statements (no names)
        XCTAssertEqual(collector.visit(.breakStatement), [])

        // Test variable assignment
        let assignment = Statement.assignment(.variable("x", .literal(.integer(42))))
        XCTAssertEqual(collector.visit(assignment), ["x"])

        // Test variable declaration
        let varDecl = Statement.variableDeclaration(VariableDeclaration(
            name: "y",
            type: .integer,
            initialValue: .literal(.integer(0))
        ))
        XCTAssertEqual(collector.visit(varDecl), ["y"])

        // Test constant declaration
        let constDecl = Statement.constantDeclaration(ConstantDeclaration(
            name: "PI",
            type: .real,
            initialValue: .literal(.real(3.14))
        ))
        XCTAssertEqual(collector.visit(constDecl), ["PI"])

        // Test function declaration
        let funcDecl = Statement.functionDeclaration(FunctionDeclaration(
            name: "add",
            parameters: [
                Parameter(name: "a", type: .integer),
                Parameter(name: "b", type: .integer)
            ],
            returnType: .integer,
            localVariables: [
                VariableDeclaration(name: "temp", type: .integer)
            ],
            body: [.breakStatement]
        ))
        let names = collector.visit(funcDecl)
        XCTAssertTrue(names.contains("add"))
        XCTAssertTrue(names.contains("a"))
        XCTAssertTrue(names.contains("b"))
        XCTAssertTrue(names.contains("temp"))

        // Test for statement
        let rangeFor = ForStatement.RangeFor(
            variable: "i",
            start: .literal(.integer(0)),
            end: .literal(.integer(10)),
            body: [varDecl]
        )
        let forStatement = Statement.forStatement(.range(rangeFor))
        let forNames = collector.visit(forStatement)
        XCTAssertTrue(forNames.contains("i"))
        XCTAssertTrue(forNames.contains("y"))
    }

    func testStatementStringifier() {
        let stringifier = ASTWalker.createStatementStringifier()

        // Test simple statements
        XCTAssertEqual(stringifier.visit(.breakStatement), "break")

        let assignment = Statement.assignment(.variable("x", .literal(.integer(42))))
        XCTAssertEqual(stringifier.visit(assignment), "x = 42")

        // Test variable declaration
        let varDecl = Statement.variableDeclaration(VariableDeclaration(
            name: "y",
            type: .integer,
            initialValue: .literal(.integer(0))
        ))
        let varResult = stringifier.visit(varDecl)
        XCTAssertTrue(varResult.contains("var y"))
        XCTAssertTrue(varResult.contains("integer"))
        XCTAssertTrue(varResult.contains("= 0"))

        // Test if statement
        let ifStmt = IfStatement(
            condition: .literal(.boolean(true)),
            thenBody: [.breakStatement]
        )
        let ifStatement = Statement.ifStatement(ifStmt)
        let ifResult = stringifier.visit(ifStatement)
        XCTAssertTrue(ifResult.contains("if (true)"))
        XCTAssertTrue(ifResult.contains("break"))
        XCTAssertTrue(ifResult.contains("{"))
        XCTAssertTrue(ifResult.contains("}"))

        // Test while statement
        let whileStmt = WhileStatement(
            condition: .literal(.boolean(true)),
            body: [.breakStatement]
        )
        let whileStatement = Statement.whileStatement(whileStmt)
        let whileResult = stringifier.visit(whileStatement)
        XCTAssertTrue(whileResult.contains("while (true)"))
        XCTAssertTrue(whileResult.contains("break"))
    }

    // MARK: - Generic Walker Tests

    func testExpressionTransformer() {
        // Create a transformer that converts all integer literals to their doubled values
        let doubler = ASTWalker.createExpressionTransformer { expr in
            if case .literal(.integer(let value)) = expr {
                return .literal(.integer(value * 2))
            }
            return expr
        }

        // Test simple literal transformation
        let result1 = doubler.visit(.literal(.integer(5)))
        XCTAssertEqual(result1, .literal(.integer(10)))

        // Test that other literals are unchanged
        let result2 = doubler.visit(.literal(.string("hello")))
        XCTAssertEqual(result2, .literal(.string("hello")))

        // Test binary expression transformation
        let binaryExpr = Expression.binary(.add, .literal(.integer(1)), .literal(.integer(2)))
        let transformedBinary = doubler.visit(binaryExpr)
        let expectedBinary = Expression.binary(.add, .literal(.integer(2)), .literal(.integer(4)))
        XCTAssertEqual(transformedBinary, expectedBinary)

        // Test nested expression transformation
        let nestedExpr = Expression.binary(.multiply,
                                         .binary(.add, .literal(.integer(1)), .literal(.integer(2))),
                                         .literal(.integer(3)))
        let transformedNested = doubler.visit(nestedExpr)
        let expectedNested = Expression.binary(.multiply,
                                             .binary(.add, .literal(.integer(2)), .literal(.integer(4))),
                                             .literal(.integer(6)))
        XCTAssertEqual(transformedNested, expectedNested)
    }

    // MARK: - Integration Tests

    func testComplexExpressionWalking() {
        // Create a complex expression: (x + 1) * func(y, 2)
        let complexExpr = Expression.binary(.multiply,
                                          .binary(.add, .identifier("x"), .literal(.integer(1))),
                                          .functionCall("func", [.identifier("y"), .literal(.integer(2))]))

        // Test node counting
        let counter = ASTWalker.createExpressionCounter()
        XCTAssertEqual(counter.visit(complexExpr), 7) // binary + (binary + identifier + literal) + (functionCall + identifier + literal)

        // Test identifier collection
        let collector = ASTWalker.createIdentifierCollector()
        let identifiers = collector.visit(complexExpr)
        XCTAssertEqual(Set(identifiers), Set(["x", "y"]))

        // Test stringification
        let stringifier = ASTWalker.createExpressionStringifier()
        let stringResult = stringifier.visit(complexExpr)
        XCTAssertEqual(stringResult, "((x + 1) * func(y, 2))")
    }

    func testComplexStatementWalking() {
        // Create a complex statement structure
        let varDecl = VariableDeclaration(name: "x", type: .integer, initialValue: .literal(.integer(0)))
        let assignment = Statement.assignment(.variable("x", .literal(.integer(42))))

        let ifStmt = IfStatement(
            condition: .binary(.greater, .identifier("x"), .literal(.integer(0))),
            thenBody: [assignment, .breakStatement],
            elseIfs: [],
            elseBody: [.breakStatement]
        )
        let complexStmt = Statement.ifStatement(ifStmt)

        // Test node counting
        let counter = ASTWalker.createStatementCounter()
        XCTAssertEqual(counter.visit(complexStmt), 4) // if + assignment + break + break

        // Test name collection
        let collector = ASTWalker.createNameCollector()
        let names = collector.visit(complexStmt)
        XCTAssertTrue(names.contains("x"))

        // Test stringification
        let stringifier = ASTWalker.createStatementStringifier()
        let stringResult = stringifier.visit(complexStmt)
        XCTAssertTrue(stringResult.contains("if"))
        XCTAssertTrue(stringResult.contains("else"))
        XCTAssertTrue(stringResult.contains("x = 42"))
        XCTAssertTrue(stringResult.contains("break"))
    }

    // MARK: - Performance Tests

    func testWalkerPerformance() {
        // Create a deep expression tree
        var expr = Expression.literal(.integer(1))
        for index in 2...50 { // Reduced from 100 to avoid performance issues
            expr = .binary(.add, expr, .literal(.integer(index)))
        }

        let counter = ASTWalker.createExpressionCounter()

        measure {
            _ = counter.visit(expr)
        }
    }

    func testStringifierPerformance() {
        // Create a moderately complex expression
        var expr = Expression.literal(.integer(1))
        for index in 2...20 { // Reduced for performance
            expr = .binary(.add, expr, .literal(.integer(index)))
        }

        let stringifier = ASTWalker.createExpressionStringifier()

        measure {
            _ = stringifier.visit(expr)
        }
    }
}
