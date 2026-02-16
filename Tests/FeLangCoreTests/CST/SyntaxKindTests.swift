import XCTest
@testable import FeLangCore

final class SyntaxKindTests: XCTestCase {

    func testIsExpression() {
        let expressionKinds: [SyntaxKind] = [
            .callExpr, .methodCallExpr, .ifExpr, .whenExpr, .tryExpr,
            .binaryExpr, .unaryExpr, .literalExpr, .identifierExpr,
            .arrayAccessExpr, .fieldAccessExpr, .arrayLiteralExpr, .parenExpr
        ]
        for kind in expressionKinds {
            XCTAssertTrue(kind.isExpression, "\(kind) should be expression")
        }
        XCTAssertFalse(SyntaxKind.ifStatement.isExpression)
        XCTAssertFalse(SyntaxKind.sourceFile.isExpression)
        XCTAssertFalse(SyntaxKind.token.isExpression)
    }

    func testIsStatement() {
        let statementKinds: [SyntaxKind] = [
            .ifStatement, .whileStatement, .doWhileStatement, .forStatement,
            .variableDeclaration, .constantDeclaration, .globalDeclaration,
            .functionDeclaration, .procedureDeclaration, .classDeclaration,
            .returnStatement, .breakStatement, .continueStatement,
            .assignmentStatement, .expressionStatement, .block
        ]
        for kind in statementKinds {
            XCTAssertTrue(kind.isStatement, "\(kind) should be statement")
        }
        XCTAssertFalse(SyntaxKind.callExpr.isStatement)
        XCTAssertFalse(SyntaxKind.sourceFile.isStatement)
    }

    func testIsTopLevel() {
        XCTAssertTrue(SyntaxKind.sourceFile.isTopLevel)
        XCTAssertTrue(SyntaxKind.importList.isTopLevel)
        XCTAssertTrue(SyntaxKind.declarationList.isTopLevel)
        XCTAssertFalse(SyntaxKind.ifStatement.isTopLevel)
        XCTAssertFalse(SyntaxKind.callExpr.isTopLevel)
    }

    func testCaseIterable() {
        XCTAssertGreaterThan(SyntaxKind.allCases.count, 0)
        XCTAssertTrue(SyntaxKind.allCases.contains(.sourceFile))
        XCTAssertTrue(SyntaxKind.allCases.contains(.token))
    }
}
