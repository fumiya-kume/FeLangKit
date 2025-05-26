import Foundation
import Testing
@testable import FeLangCore

// Alias to avoid conflict with Foundation.Expression
typealias FEExpression = FeLangCore.Expression

@Suite("Visitor Basic Tests")
struct VisitorBasicTests {
    
    @Test func testExpressionVisitorCreation() {
        let visitor = ExpressionVisitor<String>(
            visitLiteral: { literal in "literal" },
            visitIdentifier: { name in "id" },
            visitBinary: { _, _, _ in "binary" },
            visitUnary: { _, _ in "unary" },
            visitArrayAccess: { _, _ in "array" },
            visitFieldAccess: { _, _ in "field" },
            visitFunctionCall: { _, _ in "func" }
        )
        
        let expr = FEExpression.literal(.integer(42))
        let result = visitor.visit(expr)
        #expect(result == "literal")
    }
    
    @Test func testStatementVisitorCreation() {
        let visitor = StatementVisitor<String>(
            visitIfStatement: { _ in "if" },
            visitWhileStatement: { _ in "while" },
            visitForStatement: { _ in "for" },
            visitAssignment: { _ in "assignment" },
            visitVariableDeclaration: { _ in "var" },
            visitConstantDeclaration: { _ in "const" },
            visitFunctionDeclaration: { _ in "func" },
            visitProcedureDeclaration: { _ in "proc" },
            visitReturnStatement: { _ in "return" },
            visitExpressionStatement: { _ in "expr" },
            visitBreakStatement: { "break" },
            visitBlock: { _ in "block" }
        )
        
        let stmt = Statement.breakStatement
        let result = visitor.visit(stmt)
        #expect(result == "break")
    }
    
    @Test func testVisitableProtocol() {
        let visitor = ExpressionVisitor.debugStringifier()
        let expr = FEExpression.literal(.integer(42))
        
        let result = expr.accept(visitor)
        #expect(result == "42")
    }
    
    @Test func testASTWalkerBasic() {
        let expr = FEExpression.binary(.add, .literal(.integer(1)), .literal(.integer(2)))
        let walked = ASTWalker.walkExpression(expr)
        
        #expect(walked.count == 3) // binary + 2 literals
    }
}