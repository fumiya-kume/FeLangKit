import XCTest
@testable import FeLangCore

final class ASTWalkerTests: XCTestCase {
    
    // MARK: - Expression Transformation Tests
    
    func testTransformExpressionLiteral() {
        let original = Expression.literal(.integer(5))
        let transformed = ASTWalker.transformExpression(original) { expr in
            if case .literal(.integer(let value)) = expr {
                return .literal(.integer(value * 2))
            }
            return expr
        }
        
        XCTAssertEqual(transformed, .literal(.integer(10)))
    }
    
    func testTransformExpressionBinary() {
        let original = Expression.binary(
            .add,
            .literal(.integer(1)),
            .literal(.integer(2))
        )
        
        let transformed = ASTWalker.transformExpression(original) { expr in
            if case .literal(.integer(let value)) = expr {
                return .literal(.integer(value * 10))
            }
            return expr
        }
        
        let expected = Expression.binary(
            .add,
            .literal(.integer(10)),
            .literal(.integer(20))
        )
        
        XCTAssertEqual(transformed, expected)
    }
    
    func testTransformExpressionUnary() {
        let original = Expression.unary(.minus, .literal(.integer(5)))
        
        let transformed = ASTWalker.transformExpression(original) { expr in
            if case .literal(.integer(let value)) = expr {
                return .literal(.integer(value + 1))
            }
            return expr
        }
        
        let expected = Expression.unary(.minus, .literal(.integer(6)))
        XCTAssertEqual(transformed, expected)
    }
    
    func testTransformExpressionArrayAccess() {
        let original = Expression.arrayAccess(
            .identifier("arr"),
            .literal(.integer(0))
        )
        
        let transformed = ASTWalker.transformExpression(original) { expr in
            if case .literal(.integer(let value)) = expr {
                return .literal(.integer(value + 1))
            }
            return expr
        }
        
        let expected = Expression.arrayAccess(
            .identifier("arr"),
            .literal(.integer(1))
        )
        
        XCTAssertEqual(transformed, expected)
    }
    
    func testTransformExpressionFieldAccess() {
        let original = Expression.fieldAccess(.identifier("obj"), "field")
        
        let transformed = ASTWalker.transformExpression(original) { expr in
            if case .identifier(let name) = expr {
                return .identifier(name.uppercased())
            }
            return expr
        }
        
        let expected = Expression.fieldAccess(.identifier("OBJ"), "field")
        XCTAssertEqual(transformed, expected)
    }
    
    func testTransformExpressionFunctionCall() {
        let original = Expression.functionCall("func", [
            .literal(.integer(1)),
            .identifier("x")
        ])
        
        let transformed = ASTWalker.transformExpression(original) { expr in
            if case .literal(.integer(let value)) = expr {
                return .literal(.integer(value * 2))
            }
            return expr
        }
        
        let expected = Expression.functionCall("func", [
            .literal(.integer(2)),
            .identifier("x")
        ])
        
        XCTAssertEqual(transformed, expected)
    }
    
    func testTransformExpressionNested() {
        // Test: func(arr[0] + 1, obj.field)
        let original = Expression.functionCall("func", [
            .binary(
                .add,
                .arrayAccess(.identifier("arr"), .literal(.integer(0))),
                .literal(.integer(1))
            ),
            .fieldAccess(.identifier("obj"), "field")
        ])
        
        let transformed = ASTWalker.transformExpression(original) { expr in
            if case .literal(.integer(let value)) = expr {
                return .literal(.integer(value * 10))
            }
            return expr
        }
        
        let expected = Expression.functionCall("func", [
            .binary(
                .add,
                .arrayAccess(.identifier("arr"), .literal(.integer(0))),
                .literal(.integer(10))
            ),
            .fieldAccess(.identifier("obj"), "field")
        ])
        
        XCTAssertEqual(transformed, expected)
    }
    
    // MARK: - Statement Transformation Tests
    
    func testTransformStatementIfStatement() {
        let original = Statement.ifStatement(IfStatement(
            condition: .literal(.integer(0)),
            thenBody: [.expressionStatement(.literal(.integer(1)))],
            elseIfs: [
                IfStatement.ElseIf(
                    condition: .literal(.integer(2)),
                    body: [.expressionStatement(.literal(.integer(3)))]
                )
            ],
            elseBody: [.expressionStatement(.literal(.integer(4)))]
        ))
        
        let transformed = ASTWalker.transformStatement(
            original,
            expressionTransformer: { expr in
                if case .literal(.integer(let value)) = expr {
                    return .literal(.integer(value + 10))
                }
                return expr
            }
        )
        
        if case .ifStatement(let ifStmt) = transformed {
            XCTAssertEqual(ifStmt.condition, .literal(.integer(10)))
            if case .expressionStatement(let expr) = ifStmt.thenBody[0] {
                XCTAssertEqual(expr, .literal(.integer(11)))
            } else {
                XCTFail("Expected expression statement in then body")
            }
            XCTAssertEqual(ifStmt.elseIfs[0].condition, .literal(.integer(12)))
            if case .expressionStatement(let expr) = ifStmt.elseIfs[0].body[0] {
                XCTAssertEqual(expr, .literal(.integer(13)))
            } else {
                XCTFail("Expected expression statement in else-if body")
            }
            if case .expressionStatement(let expr) = ifStmt.elseBody![0] {
                XCTAssertEqual(expr, .literal(.integer(14)))
            } else {
                XCTFail("Expected expression statement in else body")
            }
        } else {
            XCTFail("Expected if statement")
        }
    }
    
    func testTransformStatementWhileStatement() {
        let original = Statement.whileStatement(WhileStatement(
            condition: .literal(.integer(0)),
            body: [.expressionStatement(.literal(.integer(1)))]
        ))
        
        let transformed = ASTWalker.transformStatement(
            original,
            expressionTransformer: { expr in
                if case .literal(.integer(let value)) = expr {
                    return .literal(.integer(value + 5))
                }
                return expr
            }
        )
        
        if case .whileStatement(let whileStmt) = transformed {
            XCTAssertEqual(whileStmt.condition, .literal(.integer(5)))
            if case .expressionStatement(let expr) = whileStmt.body[0] {
                XCTAssertEqual(expr, .literal(.integer(6)))
            } else {
                XCTFail("Expected expression statement in while body")
            }
        } else {
            XCTFail("Expected while statement")
        }
    }
    
    func testTransformStatementForRange() {
        let original = Statement.forStatement(.range(ForStatement.RangeFor(
            variable: "i",
            start: .literal(.integer(0)),
            end: .literal(.integer(10)),
            step: .literal(.integer(1)),
            body: [.expressionStatement(.literal(.integer(42)))]
        )))
        
        let transformed = ASTWalker.transformStatement(
            original,
            expressionTransformer: { expr in
                if case .literal(.integer(let value)) = expr {
                    return .literal(.integer(value * 2))
                }
                return expr
            }
        )
        
        if case .forStatement(.range(let rangeFor)) = transformed {
            XCTAssertEqual(rangeFor.start, .literal(.integer(0)))
            XCTAssertEqual(rangeFor.end, .literal(.integer(20)))
            XCTAssertEqual(rangeFor.step, .literal(.integer(2)))
            if case .expressionStatement(let expr) = rangeFor.body[0] {
                XCTAssertEqual(expr, .literal(.integer(84)))
            } else {
                XCTFail("Expected expression statement in for body")
            }
        } else {
            XCTFail("Expected range for statement")
        }
    }
    
    func testTransformStatementForEach() {
        let original = Statement.forStatement(.forEach(ForStatement.ForEachLoop(
            variable: "item",
            iterable: .identifier("items"),
            body: [.expressionStatement(.literal(.integer(1)))]
        )))
        
        let transformed = ASTWalker.transformStatement(
            original,
            expressionTransformer: { expr in
                if case .literal(.integer(let value)) = expr {
                    return .literal(.integer(value + 100))
                }
                return expr
            }
        )
        
        if case .forStatement(.forEach(let forEach)) = transformed {
            XCTAssertEqual(forEach.iterable, .identifier("items"))
            if case .expressionStatement(let expr) = forEach.body[0] {
                XCTAssertEqual(expr, .literal(.integer(101)))
            } else {
                XCTFail("Expected expression statement in forEach body")
            }
        } else {
            XCTFail("Expected forEach statement")
        }
    }
    
    func testTransformStatementAssignment() {
        let variableAssignment = Statement.assignment(.variable("x", .literal(.integer(42))))
        
        let transformed = ASTWalker.transformStatement(
            variableAssignment,
            expressionTransformer: { expr in
                if case .literal(.integer(let value)) = expr {
                    return .literal(.integer(value * 3))
                }
                return expr
            }
        )
        
        if case .assignment(.variable(let name, let expr)) = transformed {
            XCTAssertEqual(name, "x")
            XCTAssertEqual(expr, .literal(.integer(126)))
        } else {
            XCTFail("Expected variable assignment")
        }
    }
    
    func testTransformStatementDeclarations() {
        let varDecl = Statement.variableDeclaration(VariableDeclaration(
            name: "x",
            type: .integer,
            initialValue: .literal(.integer(5))
        ))
        
        let constDecl = Statement.constantDeclaration(ConstantDeclaration(
            name: "PI",
            type: .real,
            initialValue: .literal(.real(3.14))
        ))
        
        let transformedVar = ASTWalker.transformStatement(
            varDecl,
            expressionTransformer: { expr in
                if case .literal(.integer(let value)) = expr {
                    return .literal(.integer(value * 2))
                }
                return expr
            }
        )
        
        let transformedConst = ASTWalker.transformStatement(
            constDecl,
            expressionTransformer: { expr in
                if case .literal(.real(let value)) = expr {
                    return .literal(.real(value * 2))
                }
                return expr
            }
        )
        
        if case .variableDeclaration(let varDeclaration) = transformedVar {
            XCTAssertEqual(varDeclaration.initialValue, .literal(.integer(10)))
        } else {
            XCTFail("Expected variable declaration")
        }
        
        if case .constantDeclaration(let constDeclaration) = transformedConst {
            XCTAssertEqual(constDeclaration.initialValue, .literal(.real(6.28)))
        } else {
            XCTFail("Expected constant declaration")
        }
    }
    
    // MARK: - Expression Collection Tests
    
    func testCollectExpressionsFromIfStatement() {
        let ifStmt = Statement.ifStatement(IfStatement(
            condition: .literal(.integer(1)),
            thenBody: [.expressionStatement(.literal(.integer(2)))],
            elseIfs: [
                IfStatement.ElseIf(
                    condition: .literal(.integer(3)),
                    body: [.expressionStatement(.literal(.integer(4)))]
                )
            ],
            elseBody: [.expressionStatement(.literal(.integer(5)))]
        ))
        
        let collector = ExpressionVisitor<Int>(
            visitLiteral: { literal in
                if case .integer(let value) = literal {
                    return value
                }
                return 0
            },
            visitIdentifier: { _ in 0 },
            visitBinary: { _, _, _ in 0 },
            visitUnary: { _, _ in 0 },
            visitArrayAccess: { _, _ in 0 },
            visitFieldAccess: { _, _ in 0 },
            visitFunctionCall: { _, _ in 0 }
        )
        
        let results = ASTWalker.collectExpressions(from: ifStmt, using: collector)
        
        // Should collect condition (1) and else-if condition (3)
        // Note: Expression statements are not collected by this specific collector
        XCTAssertEqual(Set(results), Set([1, 3]))
    }
    
    func testCollectExpressionsFromWhileStatement() {
        let whileStmt = Statement.whileStatement(WhileStatement(
            condition: .literal(.integer(10)),
            body: [.expressionStatement(.literal(.integer(20)))]
        ))
        
        let collector = ExpressionVisitor<String>(
            visitLiteral: { literal in
                if case .integer(let value) = literal {
                    return "int(\(value))"
                }
                return "other"
            },
            visitIdentifier: { name in "id(\(name))" },
            visitBinary: { _, _, _ in "binary" },
            visitUnary: { _, _ in "unary" },
            visitArrayAccess: { _, _ in "array" },
            visitFieldAccess: { _, _ in "field" },
            visitFunctionCall: { _, _ in "call" }
        )
        
        let results = ASTWalker.collectExpressions(from: whileStmt, using: collector)
        
        // Should collect condition (10) and expression statement (20)
        XCTAssertEqual(Set(results), Set(["int(10)", "int(20)"]))
    }
    
    // MARK: - Walking with Visitors Tests
    
    func testWalkExpressionWithVisitor() {
        let expr = Expression.binary(.add, .literal(.integer(1)), .literal(.integer(2)))
        
        let visitor = ExpressionVisitor<String>(
            visitLiteral: { _ in "L" },
            visitIdentifier: { _ in "I" },
            visitBinary: { _, _, _ in "B" },
            visitUnary: { _, _ in "U" },
            visitArrayAccess: { _, _ in "A" },
            visitFieldAccess: { _, _ in "F" },
            visitFunctionCall: { _, _ in "C" }
        )
        
        let result = ASTWalker.walk(expr, with: visitor)
        XCTAssertEqual(result, "B")
    }
    
    func testWalkStatementWithVisitor() {
        let stmt = Statement.breakStatement
        
        let visitor = StatementVisitor<Int>(
            visitIfStatement: { _ in 1 },
            visitWhileStatement: { _ in 2 },
            visitForStatement: { _ in 3 },
            visitAssignment: { _ in 4 },
            visitVariableDeclaration: { _ in 5 },
            visitConstantDeclaration: { _ in 6 },
            visitFunctionDeclaration: { _ in 7 },
            visitProcedureDeclaration: { _ in 8 },
            visitReturnStatement: { _ in 9 },
            visitExpressionStatement: { _ in 10 },
            visitBreakStatement: { 11 },
            visitBlock: { _ in 12 }
        )
        
        let result = ASTWalker.walk(stmt, with: visitor)
        XCTAssertEqual(result, 11)
    }
    
    // MARK: - Performance Tests
    
    func testTransformPerformance() {
        let complexExpr = Expression.binary(
            .add,
            .binary(.multiply, .literal(.integer(1)), .literal(.integer(2))),
            .binary(.divide, .literal(.integer(3)), .literal(.integer(4)))
        )
        
        measure {
            for _ in 0..<1000 {
                _ = ASTWalker.transformExpression(complexExpr) { expr in
                    if case .literal(.integer(let value)) = expr {
                        return .literal(.integer(value + 1))
                    }
                    return expr
                }
            }
        }
    }
}