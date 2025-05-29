import XCTest
@testable import FeLangCore

final class ExpressionTransformerTests: XCTestCase {

    // MARK: - Basic Transformation Tests

    func testLiteralTransformation() {
        let doubler = ExpressionTransformer(
            transformLiteral: { literal in
                if case .integer(let value) = literal {
                    return .literal(.integer(value * 2))
                }
                return .literal(literal)
            }
        )

        let expr = Expression.literal(.integer(21))
        let transformed = doubler.transform(expr)

        XCTAssertEqual(transformed, .literal(.integer(42)))
    }

    func testIdentifierTransformation() {
        let uppercaser = ExpressionTransformer(
            transformIdentifier: { identifier in
                return .identifier(identifier.uppercased())
            }
        )

        let expr = Expression.identifier("variable")
        let transformed = uppercaser.transform(expr)

        XCTAssertEqual(transformed, .identifier("VARIABLE"))
    }

    func testRecursiveTransformation() {
        let doubler = ExpressionTransformer(
            transformLiteral: { literal in
                if case .integer(let value) = literal {
                    return .literal(.integer(value * 2))
                }
                return .literal(literal)
            }
        )

        // x + 1 should become x + 2
        let expr = Expression.binary(.add, .identifier("x"), .literal(.integer(1)))
        let transformed = doubler.transform(expr)

        XCTAssertEqual(transformed, .binary(.add, .identifier("x"), .literal(.integer(2))))
    }

    func testComplexRecursiveTransformation() {
        let doubler = ExpressionTransformer(
            transformLiteral: { literal in
                if case .integer(let value) = literal {
                    return .literal(.integer(value * 2))
                }
                return .literal(literal)
            }
        )

        // (x + 1) * 2 should become (x + 2) * 4
        let expr = Expression.binary(.multiply,
                                   .binary(.add, .identifier("x"), .literal(.integer(1))),
                                   .literal(.integer(2)))
        let transformed = doubler.transform(expr)

        let expected = Expression.binary(.multiply,
                                       .binary(.add, .identifier("x"), .literal(.integer(2))),
                                       .literal(.integer(4)))
        XCTAssertEqual(transformed, expected)
    }

    func testFunctionCallTransformation() {
        let doubler = ExpressionTransformer(
            transformLiteral: { literal in
                if case .integer(let value) = literal {
                    return .literal(.integer(value * 2))
                }
                return .literal(literal)
            }
        )

        // func(1, 2) should become func(2, 4)
        let expr = Expression.functionCall("func", [.literal(.integer(1)), .literal(.integer(2))])
        let transformed = doubler.transform(expr)

        let expected = Expression.functionCall("func", [.literal(.integer(2)), .literal(.integer(4))])
        XCTAssertEqual(transformed, expected)
    }

    // MARK: - Common Transformer Tests

    func testIdentifierReplacer() {
        let replacer = ExpressionTransformer.createIdentifierReplacer(
            identifier: "oldVar",
            replacement: .literal(.integer(42))
        )

        let expr = Expression.binary(.add, .identifier("oldVar"), .identifier("newVar"))
        let transformed = replacer.transform(expr)

        let expected = Expression.binary(.add, .literal(.integer(42)), .identifier("newVar"))
        XCTAssertEqual(transformed, expected)
    }

    func testConstantFolder() {
        let folder = ExpressionTransformer.createConstantFolder()

        // Test integer addition
        let addExpr = Expression.binary(.add, .literal(.integer(1)), .literal(.integer(2)))
        let addResult = folder.transform(addExpr)
        XCTAssertEqual(addResult, .literal(.integer(3)))

        // Test integer multiplication
        let mulExpr = Expression.binary(.multiply, .literal(.integer(3)), .literal(.integer(4)))
        let mulResult = folder.transform(mulExpr)
        XCTAssertEqual(mulResult, .literal(.integer(12)))

        // Test real addition
        let realExpr = Expression.binary(.add, .literal(.real(1.5)), .literal(.real(2.5)))
        let realResult = folder.transform(realExpr)
        XCTAssertEqual(realResult, .literal(.real(4.0)))

        // Test non-foldable expression (should remain unchanged)
        let nonFoldable = Expression.binary(.add, .identifier("x"), .literal(.integer(1)))
        let nonFoldableResult = folder.transform(nonFoldable)
        XCTAssertEqual(nonFoldableResult, nonFoldable)
    }

    func testConstantFolderWithComplexExpression() {
        let folder = ExpressionTransformer.createConstantFolder()

        // (1 + 2) * (3 + 4) should become 3 * 7, then 21
        let expr = Expression.binary(.multiply,
                                   .binary(.add, .literal(.integer(1)), .literal(.integer(2))),
                                   .binary(.add, .literal(.integer(3)), .literal(.integer(4))))
        let transformed = folder.transform(expr)

        XCTAssertEqual(transformed, .literal(.integer(21)))
    }

    func testBooleanNegator() {
        let negator = ExpressionTransformer.createBooleanNegator()

        let trueExpr = Expression.literal(.boolean(true))
        let falseResult = negator.transform(trueExpr)
        XCTAssertEqual(falseResult, .literal(.boolean(false)))

        let falseExpr = Expression.literal(.boolean(false))
        let trueResult = negator.transform(falseExpr)
        XCTAssertEqual(trueResult, .literal(.boolean(true)))

        // Non-boolean literals should remain unchanged
        let intExpr = Expression.literal(.integer(42))
        let intResult = negator.transform(intExpr)
        XCTAssertEqual(intResult, intExpr)
    }

    func testIdentifierUppercaser() {
        let uppercaser = ExpressionTransformer.createIdentifierUppercaser()

        let expr = Expression.binary(.add, .identifier("variable"), .identifier("another"))
        let transformed = uppercaser.transform(expr)

        let expected = Expression.binary(.add, .identifier("VARIABLE"), .identifier("ANOTHER"))
        XCTAssertEqual(transformed, expected)
    }

    func testCompositeTransformer() {
        let doubler = ExpressionTransformer(
            transformLiteral: { literal in
                if case .integer(let value) = literal {
                    return .literal(.integer(value * 2))
                }
                return .literal(literal)
            }
        )

        let uppercaser = ExpressionTransformer.createIdentifierUppercaser()
        _ = ExpressionTransformer.createComposite(doubler, uppercaser)

        // x + 1 should become VARIABLE + 2 if we replace x with variable first
        let replacer = ExpressionTransformer.createIdentifierReplacer(
            identifier: "x",
            replacement: .identifier("variable")
        )

        let firstComposite = ExpressionTransformer.createComposite(replacer, doubler)
        let fullComposite = ExpressionTransformer.createComposite(firstComposite, uppercaser)

        let expr = Expression.binary(.add, .identifier("x"), .literal(.integer(1)))
        let transformed = fullComposite.transform(expr)

        // The result should have uppercased identifiers and doubled integers
        if case .binary(.add, .identifier(let id), .literal(.integer(let value))) = transformed {
            XCTAssertEqual(id, "VARIABLE")
            XCTAssertEqual(value, 2)
        } else {
            XCTFail("Unexpected transformation result: \(transformed)")
        }
    }

    // MARK: - Transform Method Tests

    func testTransformMethod() {
        let doubler = ExpressionTransformer(
            transformLiteral: { literal in
                if case .integer(let value) = literal {
                    return .literal(.integer(value * 2))
                }
                return .literal(literal)
            }
        )

        let expr = Expression.literal(.integer(21))

        // Test the transform method
        let transformed = doubler.transform(expr)
        XCTAssertEqual(transformed, Expression.literal(.integer(42)))
    }

    // MARK: - Edge Cases

    func testNoTransformationProvided() {
        // Transformer with no transformation functions should return unchanged expressions
        let identity = ExpressionTransformer()

        let expr = Expression.binary(.add, .identifier("x"), .literal(.integer(1)))
        let transformed = identity.transform(expr)

        XCTAssertEqual(transformed, expr)
    }

    func testArrayAccessTransformation() {
        let doubler = ExpressionTransformer(
            transformLiteral: { literal in
                if case .integer(let value) = literal {
                    return .literal(.integer(value * 2))
                }
                return .literal(literal)
            }
        )

        // arr[1] should become arr[2]
        let expr = Expression.arrayAccess(.identifier("arr"), .literal(.integer(1)))
        let transformed = doubler.transform(expr)

        let expected = Expression.arrayAccess(.identifier("arr"), .literal(.integer(2)))
        XCTAssertEqual(transformed, expected)
    }

    func testFieldAccessTransformation() {
        let uppercaser = ExpressionTransformer.createIdentifierUppercaser()

        // obj.field should become OBJ.field
        let expr = Expression.fieldAccess(.identifier("obj"), "field")
        let transformed = uppercaser.transform(expr)

        let expected = Expression.fieldAccess(.identifier("OBJ"), "field")
        XCTAssertEqual(transformed, expected)
    }

    func testUnaryTransformation() {
        let doubler = ExpressionTransformer(
            transformLiteral: { literal in
                if case .integer(let value) = literal {
                    return .literal(.integer(value * 2))
                }
                return .literal(literal)
            }
        )

        // -1 should become -2
        let expr = Expression.unary(.minus, .literal(.integer(1)))
        let transformed = doubler.transform(expr)

        let expected = Expression.unary(.minus, .literal(.integer(2)))
        XCTAssertEqual(transformed, expected)
    }
}
