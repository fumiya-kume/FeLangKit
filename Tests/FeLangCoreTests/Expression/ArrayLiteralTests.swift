import Testing
@testable import FeLangCore

@Suite("Array Literal Tests")
struct ArrayLiteralTests {

    let parser = ExpressionParser()

    // MARK: - Helper Methods

    private func parseExpression(_ input: String) throws -> Expression {
        let tokens = try ParsingTokenizer.tokenize(input)
        return try parser.parseExpression(from: tokens)
    }

    // MARK: - Empty Array Tests

    @Test func emptyArrayLiteral() throws {
        let expr = try parseExpression("[]")

        guard case .arrayLiteral(let elements) = expr else {
            Issue.record("Expected arrayLiteral but got \(expr)")
            return
        }

        #expect(elements.isEmpty)
    }

    // MARK: - Single Element Tests

    @Test func singleIntegerElement() throws {
        let expr = try parseExpression("[42]")

        guard case .arrayLiteral(let elements) = expr else {
            Issue.record("Expected arrayLiteral but got \(expr)")
            return
        }

        #expect(elements.count == 1)
        guard case .literal(.integer(42)) = elements[0] else {
            Issue.record("Expected integer literal 42 but got \(elements[0])")
            return
        }
    }

    @Test func singleStringElement() throws {
        let expr = try parseExpression("[\"hello\"]")

        guard case .arrayLiteral(let elements) = expr else {
            Issue.record("Expected arrayLiteral but got \(expr)")
            return
        }

        #expect(elements.count == 1)
        guard case .literal(.string("hello")) = elements[0] else {
            Issue.record("Expected string literal 'hello' but got \(elements[0])")
            return
        }
    }

    // MARK: - Multiple Elements Tests

    @Test func multipleIntegerElements() throws {
        let expr = try parseExpression("[1, 2, 3]")

        guard case .arrayLiteral(let elements) = expr else {
            Issue.record("Expected arrayLiteral but got \(expr)")
            return
        }

        #expect(elements.count == 3)
        guard case .literal(.integer(1)) = elements[0],
              case .literal(.integer(2)) = elements[1],
              case .literal(.integer(3)) = elements[2] else {
            Issue.record("Expected integer literals 1, 2, 3")
            return
        }
    }

    @Test func multipleMixedElements() throws {
        let expr = try parseExpression("[1, \"hello\", true]")

        guard case .arrayLiteral(let elements) = expr else {
            Issue.record("Expected arrayLiteral but got \(expr)")
            return
        }

        #expect(elements.count == 3)
        guard case .literal(.integer(1)) = elements[0],
              case .literal(.string("hello")) = elements[1],
              case .literal(.boolean(true)) = elements[2] else {
            Issue.record("Expected mixed literals")
            return
        }
    }

    // MARK: - Nested Array Tests

    @Test func nestedArrayLiteral() throws {
        let expr = try parseExpression("[[1, 2], [3, 4]]")

        guard case .arrayLiteral(let elements) = expr else {
            Issue.record("Expected arrayLiteral but got \(expr)")
            return
        }

        #expect(elements.count == 2)

        guard case .arrayLiteral(let firstArray) = elements[0],
              case .arrayLiteral(let secondArray) = elements[1] else {
            Issue.record("Expected nested array literals")
            return
        }

        #expect(firstArray.count == 2)
        #expect(secondArray.count == 2)
    }

    // MARK: - Expression Elements Tests

    @Test func arrayWithExpressions() throws {
        let expr = try parseExpression("[1 + 2, 3 * 4]")

        guard case .arrayLiteral(let elements) = expr else {
            Issue.record("Expected arrayLiteral but got \(expr)")
            return
        }

        #expect(elements.count == 2)

        guard case .binary(.add, _, _) = elements[0],
              case .binary(.multiply, _, _) = elements[1] else {
            Issue.record("Expected binary expressions")
            return
        }
    }

    @Test func arrayWithIdentifiers() throws {
        let expr = try parseExpression("[x, y, z]")

        guard case .arrayLiteral(let elements) = expr else {
            Issue.record("Expected arrayLiteral but got \(expr)")
            return
        }

        #expect(elements.count == 3)
        guard case .identifier("x") = elements[0],
              case .identifier("y") = elements[1],
              case .identifier("z") = elements[2] else {
            Issue.record("Expected identifiers x, y, z")
            return
        }
    }

    @Test func arrayWithFunctionCalls() throws {
        let expr = try parseExpression("[f(1), g(2, 3)]")

        guard case .arrayLiteral(let elements) = expr else {
            Issue.record("Expected arrayLiteral but got \(expr)")
            return
        }

        #expect(elements.count == 2)
        guard case .functionCall("f", let args1) = elements[0],
              case .functionCall("g", let args2) = elements[1] else {
            Issue.record("Expected function calls")
            return
        }

        #expect(args1.count == 1)
        #expect(args2.count == 2)
    }

    // MARK: - PrettyPrinter Tests

    @Test func prettyPrintEmptyArray() {
        let expr = Expression.arrayLiteral([])
        let printer = PrettyPrinter()
        let result = printer.print(expr)
        #expect(result == "[]")
    }

    @Test func prettyPrintSingleElement() {
        let expr = Expression.arrayLiteral([.literal(.integer(42))])
        let printer = PrettyPrinter()
        let result = printer.print(expr)
        #expect(result == "[42]")
    }

    @Test func prettyPrintMultipleElements() {
        let expr = Expression.arrayLiteral([
            .literal(.integer(1)),
            .literal(.integer(2)),
            .literal(.integer(3))
        ])
        let printer = PrettyPrinter()
        let result = printer.print(expr)
        #expect(result == "[1, 2, 3]")
    }

    @Test func prettyPrintNestedArray() {
        let expr = Expression.arrayLiteral([
            .arrayLiteral([.literal(.integer(1)), .literal(.integer(2))]),
            .arrayLiteral([.literal(.integer(3)), .literal(.integer(4))])
        ])
        let printer = PrettyPrinter()
        let result = printer.print(expr)
        #expect(result == "[[1, 2], [3, 4]]")
    }

    // MARK: - Brace-based Array Literal Tests (FE pseudo-language syntax)

    @Test func emptyBraceArrayLiteral() throws {
        let expr = try parseExpression("{}")

        guard case .arrayLiteral(let elements) = expr else {
            Issue.record("Expected arrayLiteral but got \(expr)")
            return
        }

        #expect(elements.isEmpty)
    }

    @Test func singleIntegerElementBrace() throws {
        let expr = try parseExpression("{42}")

        guard case .arrayLiteral(let elements) = expr else {
            Issue.record("Expected arrayLiteral but got \(expr)")
            return
        }

        #expect(elements.count == 1)
        guard case .literal(.integer(42)) = elements[0] else {
            Issue.record("Expected integer literal 42 but got \(elements[0])")
            return
        }
    }

    @Test func multipleIntegerElementsBrace() throws {
        let expr = try parseExpression("{12, 34, 56}")

        guard case .arrayLiteral(let elements) = expr else {
            Issue.record("Expected arrayLiteral but got \(expr)")
            return
        }

        #expect(elements.count == 3)
        guard case .literal(.integer(12)) = elements[0],
              case .literal(.integer(34)) = elements[1],
              case .literal(.integer(56)) = elements[2] else {
            Issue.record("Expected integer literals 12, 34, 56")
            return
        }
    }

    @Test func nestedBraceArrayLiteral() throws {
        let expr = try parseExpression("{{1, 2}, {3, 4}}")

        guard case .arrayLiteral(let elements) = expr else {
            Issue.record("Expected arrayLiteral but got \(expr)")
            return
        }

        #expect(elements.count == 2)

        guard case .arrayLiteral(let firstArray) = elements[0],
              case .arrayLiteral(let secondArray) = elements[1] else {
            Issue.record("Expected nested array literals")
            return
        }

        #expect(firstArray.count == 2)
        #expect(secondArray.count == 2)
    }

    @Test func braceArrayWithExpressions() throws {
        let expr = try parseExpression("{1 + 2, 3 * 4}")

        guard case .arrayLiteral(let elements) = expr else {
            Issue.record("Expected arrayLiteral but got \(expr)")
            return
        }

        #expect(elements.count == 2)

        guard case .binary(.add, _, _) = elements[0],
              case .binary(.multiply, _, _) = elements[1] else {
            Issue.record("Expected binary expressions")
            return
        }
    }

    @Test func braceArrayWithIdentifiers() throws {
        let expr = try parseExpression("{x, y, z}")

        guard case .arrayLiteral(let elements) = expr else {
            Issue.record("Expected arrayLiteral but got \(expr)")
            return
        }

        #expect(elements.count == 3)
        guard case .identifier("x") = elements[0],
              case .identifier("y") = elements[1],
              case .identifier("z") = elements[2] else {
            Issue.record("Expected identifiers x, y, z")
            return
        }
    }

    // MARK: - Mixed Bracket-Brace Nesting Tests

    @Test func bracketContainingBraceArrays() throws {
        let expr = try parseExpression("[{1, 2}, {3, 4}]")

        guard case .arrayLiteral(let elements) = expr else {
            Issue.record("Expected arrayLiteral but got \(expr)")
            return
        }

        #expect(elements.count == 2)

        guard case .arrayLiteral(let firstArray) = elements[0],
              case .arrayLiteral(let secondArray) = elements[1] else {
            Issue.record("Expected nested array literals")
            return
        }

        #expect(firstArray.count == 2)
        #expect(secondArray.count == 2)
    }

    @Test func braceContainingBracketArrays() throws {
        let expr = try parseExpression("{[1, 2], [3, 4]}")

        guard case .arrayLiteral(let elements) = expr else {
            Issue.record("Expected arrayLiteral but got \(expr)")
            return
        }

        #expect(elements.count == 2)

        guard case .arrayLiteral(let firstArray) = elements[0],
              case .arrayLiteral(let secondArray) = elements[1] else {
            Issue.record("Expected nested array literals")
            return
        }

        #expect(firstArray.count == 2)
        #expect(secondArray.count == 2)
    }
}
