import XCTest
@testable import FeLangCore

final class ASTBuilderTests: XCTestCase {

    private let parser = Parser()

    // MARK: - Round-Trip: CST → AST matches direct parse

    func testVariableDeclarationRoundTrip() throws {
        let source = "variable x: integer ← 42"
        let direct = try parser.parse(source)
        let viaCST = try parser.parseViaCST(source)
        XCTAssertEqual(direct, viaCST)
    }

    func testConstantDeclarationRoundTrip() throws {
        let source = "constant PI: real ← 3.14"
        let direct = try parser.parse(source)
        let viaCST = try parser.parseViaCST(source)
        XCTAssertEqual(direct, viaCST)
    }

    func testSimpleAssignmentRoundTrip() throws {
        let source = "x ← 42"
        let direct = try parser.parse(source)
        let viaCST = try parser.parseViaCST(source)
        XCTAssertEqual(direct, viaCST)
    }

    func testBinaryExpressionRoundTrip() throws {
        let source = "x ← 1 + 2 * 3"
        let direct = try parser.parse(source)
        let viaCST = try parser.parseViaCST(source)
        XCTAssertEqual(direct, viaCST)
    }

    func testFunctionCallRoundTrip() throws {
        let source = "print(42)"
        let direct = try parser.parse(source)
        let viaCST = try parser.parseViaCST(source)
        XCTAssertEqual(direct, viaCST)
    }

    func testIfStatementRoundTrip() throws {
        let source = """
        if x > 0 then
            y ← 1
        endif
        """
        let direct = try parser.parse(source)
        let viaCST = try parser.parseViaCST(source)
        XCTAssertEqual(direct, viaCST)
    }

    func testIfElseRoundTrip() throws {
        let source = """
        if x > 0 then
            y ← 1
        else
            y ← 0
        endif
        """
        let direct = try parser.parse(source)
        let viaCST = try parser.parseViaCST(source)
        XCTAssertEqual(direct, viaCST)
    }

    func testWhileStatementRoundTrip() throws {
        let source = """
        while x > 0 do
            x ← x - 1
        endwhile
        """
        let direct = try parser.parse(source)
        let viaCST = try parser.parseViaCST(source)
        XCTAssertEqual(direct, viaCST)
    }

    func testForRangeRoundTrip() throws {
        let source = """
        for i ← 1 to 10 do
            x ← x + i
        endfor
        """
        let direct = try parser.parse(source)
        let viaCST = try parser.parseViaCST(source)
        XCTAssertEqual(direct, viaCST)
    }

    func testForEachRoundTrip() throws {
        let source = """
        for item in items do
            x ← item
        endfor
        """
        let direct = try parser.parse(source)
        let viaCST = try parser.parseViaCST(source)
        XCTAssertEqual(direct, viaCST)
    }

    func testFunctionDeclarationRoundTrip() throws {
        let source = """
        function add(a: integer, b: integer): integer
            return a + b
        endfunction
        """
        let direct = try parser.parse(source)
        let viaCST = try parser.parseViaCST(source)
        XCTAssertEqual(direct, viaCST)
    }

    func testProcedureDeclarationRoundTrip() throws {
        let source = """
        procedure greet(name: string)
            print(name)
        endprocedure
        """
        let direct = try parser.parse(source)
        let viaCST = try parser.parseViaCST(source)
        XCTAssertEqual(direct, viaCST)
    }

    func testReturnStatementRoundTrip() throws {
        let source = """
        function f(): integer
            return 42
        endfunction
        """
        let direct = try parser.parse(source)
        let viaCST = try parser.parseViaCST(source)
        XCTAssertEqual(direct, viaCST)
    }

    func testUnaryExpressionRoundTrip() throws {
        let source = "x ← -5"
        let direct = try parser.parse(source)
        let viaCST = try parser.parseViaCST(source)
        XCTAssertEqual(direct, viaCST)
    }

    func testArrayLiteralRoundTrip() throws {
        let source = "x ← {1, 2, 3}"
        let direct = try parser.parse(source)
        let viaCST = try parser.parseViaCST(source)
        XCTAssertEqual(direct, viaCST)
    }

    func testBreakContinueRoundTrip() throws {
        let source = """
        while true do
            break
        endwhile
        """
        let direct = try parser.parse(source)
        let viaCST = try parser.parseViaCST(source)
        XCTAssertEqual(direct, viaCST)
    }

    // MARK: - ASTBuilder error handling

    func testBuildFromNonSourceFileThrows() {
        let node = SyntaxNode(kind: .block, children: [])
        let builder = ASTBuilder(tokens: [])
        XCTAssertThrowsError(try builder.build(from: node)) { error in
            XCTAssertTrue(error is ASTBuildError)
        }
    }
}
