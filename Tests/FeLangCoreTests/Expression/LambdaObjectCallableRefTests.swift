import Foundation
import Testing
@testable import FeLangCore

typealias FEExpr = FeLangCore.Expression

@Suite("Lambda / Object Literal / Callable Ref Tests")
struct LambdaObjectCallableRefTests {

    let parser = ExpressionParser()

    private func parseExpression(_ input: String) throws -> FEExpr {
        let tokens = try ParsingTokenizer.tokenize(input)
        return try parser.parseExpression(from: tokens)
    }

    // MARK: - Lambda Literal Parsing

    @Test func lambdaNoParams() throws {
        let expr = try parseExpression("lambda { 42 }")
        #expect(expr == .lambdaLiteral([], nil, .literal(.integer(42))))
    }

    @Test func lambdaSingleParam() throws {
        let expr = try parseExpression("lambda(x: 整数型) { x + 1 }")
        let expected = FEExpr.lambdaLiteral(
            [Parameter(name: "x", type: .integer)],
            nil,
            .binary(.add, .identifier("x"), .literal(.integer(1)))
        )
        #expect(expr == expected)
    }

    @Test func lambdaMultipleParams() throws {
        let expr = try parseExpression("lambda(a: 整数型, b: 整数型) { a + b }")
        let expected = FEExpr.lambdaLiteral(
            [Parameter(name: "a", type: .integer), Parameter(name: "b", type: .integer)],
            nil,
            .binary(.add, .identifier("a"), .identifier("b"))
        )
        #expect(expr == expected)
    }

    @Test func lambdaWithReturnType() throws {
        let expr = try parseExpression("lambda(x: 整数型): 整数型 { x * 2 }")
        let expected = FEExpr.lambdaLiteral(
            [Parameter(name: "x", type: .integer)],
            .integer,
            .binary(.multiply, .identifier("x"), .literal(.integer(2)))
        )
        #expect(expr == expected)
    }

    @Test func lambdaEmptyParams() throws {
        let expr = try parseExpression("lambda() { 0 }")
        #expect(expr == .lambdaLiteral([], nil, .literal(.integer(0))))
    }

    @Test func lambdaBodyWithNestedExpression() throws {
        let expr = try parseExpression("lambda(n: 整数型) { n * (n + 1) }")
        let expected = FEExpr.lambdaLiteral(
            [Parameter(name: "n", type: .integer)],
            nil,
            .binary(
                .multiply,
                .identifier("n"),
                .binary(.add, .identifier("n"), .literal(.integer(1)))
            )
        )
        #expect(expr == expected)
    }

    // MARK: - Object Literal Parsing

    @Test func objectLiteralSingleField() throws {
        let expr = try parseExpression("object { name ← 42 }")
        let expected = FEExpr.objectLiteral([
            ObjectLiteralField(name: "name", value: .literal(.integer(42)))
        ])
        #expect(expr == expected)
    }

    @Test func objectLiteralMultipleFields() throws {
        let expr = try parseExpression("object { x ← 1, y ← 2 }")
        let expected = FEExpr.objectLiteral([
            ObjectLiteralField(name: "x", value: .literal(.integer(1))),
            ObjectLiteralField(name: "y", value: .literal(.integer(2)))
        ])
        #expect(expr == expected)
    }

    @Test func objectLiteralEmpty() throws {
        let expr = try parseExpression("object { }")
        #expect(expr == .objectLiteral([]))
    }

    @Test func objectLiteralWithExpressionValues() throws {
        let expr = try parseExpression("object { sum ← 1 + 2 }")
        let expected = FEExpr.objectLiteral([
            ObjectLiteralField(
                name: "sum",
                value: .binary(.add, .literal(.integer(1)), .literal(.integer(2)))
            )
        ])
        #expect(expr == expected)
    }

    // MARK: - Callable Reference Parsing

    @Test func callableRefSimple() throws {
        let expr = try parseExpression("::myFunc")
        #expect(expr == .callableRef("myFunc"))
    }

    @Test func callableRefInExpression() throws {
        let expr = try parseExpression("::getValue")
        #expect(expr == .callableRef("getValue"))
    }

    // MARK: - Visitor Tests

    @Test func lambdaVisitor() {
        let expr = FEExpr.lambdaLiteral(
            [Parameter(name: "x", type: .integer)],
            .integer,
            .literal(.integer(42))
        )
        let visitor = ExpressionVisitor<String>(
            visitLiteral: { _ in "literal" },
            visitIdentifier: { _ in "identifier" },
            visitBinary: { _, _, _ in "binary" },
            visitUnary: { _, _ in "unary" },
            visitArrayAccess: { _, _ in "array_access" },
            visitFieldAccess: { _, _ in "field_access" },
            visitFunctionCall: { _, _ in "function_call" },
            visitMethodCall: { _, _, _ in "method_call" },
            visitArrayLiteral: { _ in "array_literal" },
            visitLambdaLiteral: { params, retType, _ in
                "lambda(\(params.count) params, ret=\(String(describing: retType)))"
            },
            visitObjectLiteral: { _ in "object" },
            visitCallableRef: { _ in "ref" }
        )
        let result = expr.accept(visitor)
        #expect(result == "lambda(1 params, ret=Optional(FeLangCore.DataType.integer))")
    }

    @Test func objectLiteralVisitor() {
        let expr = FEExpr.objectLiteral([
            ObjectLiteralField(name: "a", value: .literal(.integer(1)))
        ])
        let visitor = ExpressionVisitor<String>(
            visitLiteral: { _ in "literal" },
            visitIdentifier: { _ in "identifier" },
            visitBinary: { _, _, _ in "binary" },
            visitUnary: { _, _ in "unary" },
            visitArrayAccess: { _, _ in "array_access" },
            visitFieldAccess: { _, _ in "field_access" },
            visitFunctionCall: { _, _ in "function_call" },
            visitMethodCall: { _, _, _ in "method_call" },
            visitArrayLiteral: { _ in "array_literal" },
            visitLambdaLiteral: { _, _, _ in "lambda" },
            visitObjectLiteral: { fields in "object(\(fields.count) fields)" },
            visitCallableRef: { _ in "ref" }
        )
        #expect(expr.accept(visitor) == "object(1 fields)")
    }

    @Test func callableRefVisitor() {
        let expr = FEExpr.callableRef("doSomething")
        let visitor = ExpressionVisitor<String>(
            visitLiteral: { _ in "literal" },
            visitIdentifier: { _ in "identifier" },
            visitBinary: { _, _, _ in "binary" },
            visitUnary: { _, _ in "unary" },
            visitArrayAccess: { _, _ in "array_access" },
            visitFieldAccess: { _, _ in "field_access" },
            visitFunctionCall: { _, _ in "function_call" },
            visitMethodCall: { _, _, _ in "method_call" },
            visitArrayLiteral: { _ in "array_literal" },
            visitLambdaLiteral: { _, _, _ in "lambda" },
            visitObjectLiteral: { _ in "object" },
            visitCallableRef: { name in "ref(\(name))" }
        )
        #expect(expr.accept(visitor) == "ref(doSomething)")
    }

    // MARK: - PrettyPrinter Tests

    @Test func prettyPrintLambdaNoParams() {
        let printer = PrettyPrinter()
        let expr = FEExpr.lambdaLiteral([], nil, .literal(.integer(42)))
        let result = printer.print(expr)
        #expect(result.contains("lambda"))
        #expect(result.contains("42"))
    }

    @Test func prettyPrintLambdaWithParams() {
        let printer = PrettyPrinter()
        let expr = FEExpr.lambdaLiteral(
            [Parameter(name: "x", type: .integer)],
            .integer,
            .identifier("x")
        )
        let result = printer.print(expr)
        #expect(result.contains("lambda"))
        #expect(result.contains("x"))
    }

    @Test func prettyPrintObjectLiteral() {
        let printer = PrettyPrinter()
        let expr = FEExpr.objectLiteral([
            ObjectLiteralField(name: "a", value: .literal(.integer(1))),
            ObjectLiteralField(name: "b", value: .literal(.integer(2)))
        ])
        let result = printer.print(expr)
        #expect(result.contains("object"))
        #expect(result.contains("a"))
        #expect(result.contains("b"))
    }

    @Test func prettyPrintCallableRef() {
        let printer = PrettyPrinter()
        let expr = FEExpr.callableRef("myFunc")
        let result = printer.print(expr)
        #expect(result == "::myFunc")
    }

    // MARK: - Equatable / Codable Round-trip

    @Test func lambdaCodableRoundTrip() throws {
        let original = FEExpr.lambdaLiteral(
            [Parameter(name: "x", type: .integer)],
            .integer,
            .binary(.add, .identifier("x"), .literal(.integer(1)))
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FEExpr.self, from: data)
        #expect(decoded == original)
    }

    @Test func objectLiteralCodableRoundTrip() throws {
        let original = FEExpr.objectLiteral([
            ObjectLiteralField(name: "val", value: .literal(.integer(99)))
        ])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FEExpr.self, from: data)
        #expect(decoded == original)
    }

    @Test func callableRefCodableRoundTrip() throws {
        let original = FEExpr.callableRef("fn")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FEExpr.self, from: data)
        #expect(decoded == original)
    }

    // MARK: - ASTWalker Tests

    @Test func astWalkerCollectsLambdaIdentifiers() {
        let expr = FEExpr.lambdaLiteral(
            [Parameter(name: "x", type: .integer)],
            nil,
            .binary(.add, .identifier("x"), .identifier("y"))
        )
        let ids = ASTWalker.collectIdentifiers(from: expr)
        #expect(ids.contains("x"))
        #expect(ids.contains("y"))
    }

    @Test func astWalkerCollectsObjectFieldIdentifiers() {
        let expr = FEExpr.objectLiteral([
            ObjectLiteralField(name: "a", value: .identifier("val1")),
            ObjectLiteralField(name: "b", value: .identifier("val2"))
        ])
        let ids = ASTWalker.collectIdentifiers(from: expr)
        #expect(ids.contains("val1"))
        #expect(ids.contains("val2"))
    }

    @Test func astWalkerCollectsCallableRefIdentifier() {
        let expr = FEExpr.callableRef("targetFunc")
        let ids = ASTWalker.collectIdentifiers(from: expr)
        #expect(ids.contains("targetFunc"))
    }

    @Test func astWalkerCountsLambdaNodes() {
        let expr = FEExpr.lambdaLiteral([], nil, .literal(.integer(1)))
        let count = ASTWalker.countNodes(in: expr)
        #expect(count >= 2)
    }

    // MARK: - Error Cases

    @Test func lambdaMissingBody() throws {
        #expect(throws: ParsingError.self) {
            try parseExpression("lambda(x: 整数型)")
        }
    }

    @Test func objectLiteralMissingBrace() throws {
        #expect(throws: ParsingError.self) {
            try parseExpression("object")
        }
    }

    @Test func callableRefMissingName() throws {
        #expect(throws: ParsingError.self) {
            try parseExpression("::")
        }
    }
}
