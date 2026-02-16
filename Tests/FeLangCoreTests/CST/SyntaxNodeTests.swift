import XCTest
@testable import FeLangCore

final class SyntaxNodeTests: XCTestCase {

    func testLeafNode() {
        let node = SyntaxNode(token: 5)
        XCTAssertEqual(node.kind, .token)
        XCTAssertEqual(node.tokenIndex, 5)
        XCTAssertEqual(node.startTokenIndex, 5)
        XCTAssertEqual(node.endTokenIndex, 6)
        XCTAssertTrue(node.isToken)
        XCTAssertTrue(node.children.isEmpty)
        XCTAssertEqual(node.tokenCount, 1)
    }

    func testInternalNode() {
        let child1 = SyntaxNode(token: 0)
        let child2 = SyntaxNode(token: 1)
        let child3 = SyntaxNode(token: 2)
        let node = SyntaxNode(kind: .binaryExpr, children: [child1, child2, child3])

        XCTAssertEqual(node.kind, .binaryExpr)
        XCTAssertNil(node.tokenIndex)
        XCTAssertEqual(node.startTokenIndex, 0)
        XCTAssertEqual(node.endTokenIndex, 3)
        XCTAssertFalse(node.isToken)
        XCTAssertEqual(node.children.count, 3)
        XCTAssertEqual(node.tokenCount, 3)
    }

    func testEmptyInternalNode() {
        let node = SyntaxNode(kind: .block, children: [])
        XCTAssertEqual(node.startTokenIndex, 0)
        XCTAssertEqual(node.endTokenIndex, 0)
        XCTAssertEqual(node.tokenCount, 0)
    }

    func testExplicitTokenRange() {
        let node = SyntaxNode(kind: .importList, children: [], startTokenIndex: 3, endTokenIndex: 3)
        XCTAssertEqual(node.startTokenIndex, 3)
        XCTAssertEqual(node.endTokenIndex, 3)
    }

    func testFirstChildOfKind() {
        let lit = SyntaxNode(kind: .literalExpr, children: [SyntaxNode(token: 0)])
        let ident = SyntaxNode(kind: .identifierExpr, children: [SyntaxNode(token: 1)])
        let parent = SyntaxNode(kind: .block, children: [lit, ident])

        XCTAssertEqual(parent.firstChild(ofKind: .literalExpr), lit)
        XCTAssertEqual(parent.firstChild(ofKind: .identifierExpr), ident)
        XCTAssertNil(parent.firstChild(ofKind: .callExpr))
    }

    func testChildrenOfKind() {
        let lit1 = SyntaxNode(kind: .literalExpr, children: [SyntaxNode(token: 0)])
        let ident = SyntaxNode(kind: .identifierExpr, children: [SyntaxNode(token: 1)])
        let lit2 = SyntaxNode(kind: .literalExpr, children: [SyntaxNode(token: 2)])
        let parent = SyntaxNode(kind: .block, children: [lit1, ident, lit2])

        XCTAssertEqual(parent.children(ofKind: .literalExpr).count, 2)
        XCTAssertEqual(parent.children(ofKind: .identifierExpr).count, 1)
    }

    func testTokensProperty() {
        let tok1 = SyntaxNode(token: 0)
        let expr = SyntaxNode(kind: .literalExpr, children: [SyntaxNode(token: 1)])
        let tok2 = SyntaxNode(token: 2)
        let parent = SyntaxNode(kind: .block, children: [tok1, expr, tok2])

        XCTAssertEqual(parent.tokens.count, 2)
    }

    func testDebugDescription() {
        let node = SyntaxNode(kind: .literalExpr, children: [SyntaxNode(token: 0)])
        let desc = node.debugDescription
        XCTAssertTrue(desc.contains("literalExpr"))
        XCTAssertTrue(desc.contains("token[0]"))
    }
}
