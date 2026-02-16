import XCTest
@testable import FeLangCore

final class CSTParserTests: XCTestCase {

    private let tokenizer = ParsingTokenizer()
    private let cstParser = CSTParser()

    private func parseCST(_ source: String) throws -> SyntaxNode {
        let tokens = try tokenizer.tokenize(source)
        return try cstParser.parse(tokens)
    }

    // MARK: - Top-Level Structure

    func testSourceFileStructure() throws {
        let cst = try parseCST("variable x: integer ← 42")
        XCTAssertEqual(cst.kind, .sourceFile)
        XCTAssertEqual(cst.children.count, 2)
        XCTAssertEqual(cst.children[0].kind, .importList)
        XCTAssertEqual(cst.children[1].kind, .declarationList)
    }

    func testImportListContainsTopLevelDeclarations() throws {
        let cst = try parseCST("variable x: integer ← 1\nvariable y: integer ← 2")
        let importList = cst.firstChild(ofKind: .importList)!
        XCTAssertEqual(importList.children.count, 2)
        XCTAssertEqual(importList.children[0].kind, .variableDeclaration)
        XCTAssertEqual(importList.children[1].kind, .variableDeclaration)
    }

    func testDeclarationListContainsFunctions() throws {
        let source = """
        function add(a: integer, b: integer): integer
            return a + b
        endfunction
        """
        let cst = try parseCST(source)
        let declList = cst.firstChild(ofKind: .declarationList)!
        XCTAssertEqual(declList.children.count, 1)
        XCTAssertEqual(declList.children[0].kind, .functionDeclaration)
    }

    // MARK: - Variable / Constant Declarations

    func testVariableDeclaration() throws {
        let cst = try parseCST("variable x: integer ← 10")
        let importList = cst.firstChild(ofKind: .importList)!
        let varDecl = importList.children[0]
        XCTAssertEqual(varDecl.kind, .variableDeclaration)
    }

    func testConstantDeclaration() throws {
        let cst = try parseCST("constant PI: real ← 3.14")
        let importList = cst.firstChild(ofKind: .importList)!
        let constDecl = importList.children[0]
        XCTAssertEqual(constDecl.kind, .constantDeclaration)
    }

    // MARK: - Control Flow

    func testIfStatement() throws {
        let source = """
        if x > 0 then
            y ← 1
        endif
        """
        let cst = try parseCST(source)
        let declList = cst.firstChild(ofKind: .declarationList)!
        let ifStmt = declList.children[0]
        XCTAssertEqual(ifStmt.kind, .ifStatement)
        XCTAssertNotNil(ifStmt.firstChild(ofKind: .conditionClause))
        XCTAssertNotNil(ifStmt.firstChild(ofKind: .thenClause))
    }

    func testIfElseStatement() throws {
        let source = """
        if x > 0 then
            y ← 1
        else
            y ← 0
        endif
        """
        let cst = try parseCST(source)
        let declList = cst.firstChild(ofKind: .declarationList)!
        let ifStmt = declList.children[0]
        XCTAssertEqual(ifStmt.kind, .ifStatement)
        XCTAssertNotNil(ifStmt.firstChild(ofKind: .elseClause))
    }

    func testIfElseIfStatement() throws {
        let source = """
        if x > 0 then
            y ← 1
        elseif x < 0 then
            y ← -1
        else
            y ← 0
        endif
        """
        let cst = try parseCST(source)
        let declList = cst.firstChild(ofKind: .declarationList)!
        let ifStmt = declList.children[0]
        XCTAssertFalse(ifStmt.children(ofKind: .elseIfClause).isEmpty)
        XCTAssertNotNil(ifStmt.firstChild(ofKind: .elseClause))
    }

    func testWhileStatement() throws {
        let source = """
        while x > 0 do
            x ← x - 1
        endwhile
        """
        let cst = try parseCST(source)
        let declList = cst.firstChild(ofKind: .declarationList)!
        let whileStmt = declList.children[0]
        XCTAssertEqual(whileStmt.kind, .whileStatement)
        XCTAssertNotNil(whileStmt.firstChild(ofKind: .conditionClause))
    }

    func testForRangeStatement() throws {
        let source = """
        for i ← 1 to 10 do
            x ← x + i
        endfor
        """
        let cst = try parseCST(source)
        let declList = cst.firstChild(ofKind: .declarationList)!
        let forStmt = declList.children[0]
        XCTAssertEqual(forStmt.kind, .forStatement)
        XCTAssertNotNil(forStmt.firstChild(ofKind: .forRangeClause))
    }

    func testForRangeWithStep() throws {
        let source = """
        for i ← 0 to 100 step 2 do
            x ← x + i
        endfor
        """
        let cst = try parseCST(source)
        let declList = cst.firstChild(ofKind: .declarationList)!
        let forStmt = declList.children[0]
        let rangeClause = forStmt.firstChild(ofKind: .forRangeClause)!
        XCTAssertGreaterThan(rangeClause.children.count, 3)
    }

    func testForEachStatement() throws {
        let source = """
        for item in items do
            x ← item
        endfor
        """
        let cst = try parseCST(source)
        let declList = cst.firstChild(ofKind: .declarationList)!
        let forStmt = declList.children[0]
        XCTAssertEqual(forStmt.kind, .forStatement)
        XCTAssertNotNil(forStmt.firstChild(ofKind: .forEachClause))
    }

    // MARK: - Expressions

    func testCallExpr() throws {
        let cst = try parseCST("print(42)")
        let declList = cst.firstChild(ofKind: .declarationList)!
        let exprStmt = declList.children[0]
        XCTAssertEqual(exprStmt.kind, .expressionStatement)
        let callExpr = exprStmt.children[0]
        XCTAssertEqual(callExpr.kind, .callExpr)
        XCTAssertNotNil(callExpr.firstChild(ofKind: .argumentList))
    }

    func testBinaryExpr() throws {
        let cst = try parseCST("x ← 1 + 2")
        let declList = cst.firstChild(ofKind: .declarationList)!
        let assign = declList.children[0]
        XCTAssertEqual(assign.kind, .assignmentStatement)
        let exprChildren = assign.children.filter { $0.kind.isExpression }
        guard let binExpr = exprChildren.first else {
            XCTFail("Expected binary expression")
            return
        }
        XCTAssertEqual(binExpr.kind, .binaryExpr)
    }

    func testUnaryExpr() throws {
        let cst = try parseCST("x ← -5")
        let declList = cst.firstChild(ofKind: .declarationList)!
        let assign = declList.children[0]
        let exprChildren = assign.children.filter { $0.kind.isExpression }
        guard let unaryExpr = exprChildren.first else {
            XCTFail("Expected unary expression")
            return
        }
        XCTAssertEqual(unaryExpr.kind, .unaryExpr)
    }

    func testLiteralExpr() throws {
        let cst = try parseCST("x ← 42")
        let declList = cst.firstChild(ofKind: .declarationList)!
        let assign = declList.children[0]
        let exprChildren = assign.children.filter { $0.kind.isExpression }
        guard let litExpr = exprChildren.first else {
            XCTFail("Expected literal expression")
            return
        }
        XCTAssertEqual(litExpr.kind, .literalExpr)
    }

    func testArrayLiteralExpr() throws {
        let cst = try parseCST("x ← {1, 2, 3}")
        let declList = cst.firstChild(ofKind: .declarationList)!
        let assign = declList.children[0]
        let exprChildren = assign.children.filter { $0.kind.isExpression }
        guard let arrExpr = exprChildren.first else {
            XCTFail("Expected array literal expression")
            return
        }
        XCTAssertEqual(arrExpr.kind, .arrayLiteralExpr)
    }

    // MARK: - Function / Procedure

    func testFunctionDeclaration() throws {
        let source = """
        function add(a: integer, b: integer): integer
            return a + b
        endfunction
        """
        let cst = try parseCST(source)
        let declList = cst.firstChild(ofKind: .declarationList)!
        let funcDecl = declList.children[0]
        XCTAssertEqual(funcDecl.kind, .functionDeclaration)
        XCTAssertNotNil(funcDecl.firstChild(ofKind: .parameterList))
        XCTAssertNotNil(funcDecl.firstChild(ofKind: .typeAnnotation))
        XCTAssertNotNil(funcDecl.firstChild(ofKind: .block))
    }

    func testProcedureDeclaration() throws {
        let source = """
        procedure greet(name: string)
            print(name)
        endprocedure
        """
        let cst = try parseCST(source)
        let declList = cst.firstChild(ofKind: .declarationList)!
        let procDecl = declList.children[0]
        XCTAssertEqual(procDecl.kind, .procedureDeclaration)
        XCTAssertNotNil(procDecl.firstChild(ofKind: .parameterList))
    }

    // MARK: - Assignment

    func testSimpleAssignment() throws {
        let cst = try parseCST("x ← 42")
        let declList = cst.firstChild(ofKind: .declarationList)!
        XCTAssertEqual(declList.children[0].kind, .assignmentStatement)
    }

    // MARK: - Return / Break / Continue

    func testReturnStatement() throws {
        let source = """
        function f(): integer
            return 42
        endfunction
        """
        let cst = try parseCST(source)
        let funcDecl = cst.firstChild(ofKind: .declarationList)!.children[0]
        let body = funcDecl.firstChild(ofKind: .block)!
        let retStmt = body.children[0]
        XCTAssertEqual(retStmt.kind, .returnStatement)
    }

    func testBreakStatement() throws {
        let source = """
        while true do
            break
        endwhile
        """
        let cst = try parseCST(source)
        let whileStmt = cst.firstChild(ofKind: .declarationList)!.children[0]
        let body = whileStmt.children(ofKind: .block)
        let block = body.first!
        let breakStmt = block.children[0]
        XCTAssertEqual(breakStmt.kind, .breakStatement)
    }

    // MARK: - Error Handling

    func testNestingTooDeep() {
        var source = ""
        for _ in 0..<105 {
            source += "if true then\n"
        }
        for _ in 0..<105 {
            source += "endif\n"
        }
        XCTAssertThrowsError(try parseCST(source)) { error in
            XCTAssertTrue(error is CSTParsingError)
        }
    }
}
