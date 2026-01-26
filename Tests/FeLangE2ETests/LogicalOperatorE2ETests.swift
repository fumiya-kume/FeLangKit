import FeLangRuntime
import Foundation
import Testing

@Suite("Logical Operator E2E Tests", .serialized)
struct LogicalOperatorE2ETests {

    // MARK: - AND Operator Tests

    @Test("and operator: true and true = true")
    func testAndTrueTrue() throws {
        let output = try InProcessTestHelper.run("println(true and true)")
        #expect(output.lowercased().contains("true"))
    }

    @Test("and operator: true and false = false")
    func testAndTrueFalse() throws {
        let output = try InProcessTestHelper.run("println(true and false)")
        #expect(output.lowercased().contains("false"))
    }

    @Test("and operator: false and true = false")
    func testAndFalseTrue() throws {
        let output = try InProcessTestHelper.run("println(false and true)")
        #expect(output.lowercased().contains("false"))
    }

    @Test("and operator: false and false = false")
    func testAndFalseFalse() throws {
        let output = try InProcessTestHelper.run("println(false and false)")
        #expect(output.lowercased().contains("false"))
    }

    // MARK: - OR Operator Tests

    @Test("or operator: true or true = true")
    func testOrTrueTrue() throws {
        let output = try InProcessTestHelper.run("println(true or true)")
        #expect(output.lowercased().contains("true"))
    }

    @Test("or operator: true or false = true")
    func testOrTrueFalse() throws {
        let output = try InProcessTestHelper.run("println(true or false)")
        #expect(output.lowercased().contains("true"))
    }

    @Test("or operator: false or true = true")
    func testOrFalseTrue() throws {
        let output = try InProcessTestHelper.run("println(false or true)")
        #expect(output.lowercased().contains("true"))
    }

    @Test("or operator: false or false = false")
    func testOrFalseFalse() throws {
        let output = try InProcessTestHelper.run("println(false or false)")
        #expect(output.lowercased().contains("false"))
    }

    // MARK: - NOT Operator Tests

    @Test("not operator: not true = false")
    func testNotTrue() throws {
        let output = try InProcessTestHelper.run("println(not true)")
        #expect(output.lowercased().contains("false"))
    }

    @Test("not operator: not false = true")
    func testNotFalse() throws {
        let output = try InProcessTestHelper.run("println(not false)")
        #expect(output.lowercased().contains("true"))
    }

    @Test("double negation: not not true = true")
    func testDoubleNegation() throws {
        let output = try InProcessTestHelper.run("println(not not true)")
        #expect(output.lowercased().contains("true"))
    }

    // MARK: - Complex Logical Expressions

    @Test("logical with comparison: (5 > 3) and (2 < 4)")
    func testLogicalWithComparison() throws {
        let output = try InProcessTestHelper.run("println((5 > 3) and (2 < 4))")
        #expect(output.lowercased().contains("true"))
    }

    @Test("logical with comparison: (5 > 3) or (2 > 4)")
    func testOrWithComparison() throws {
        let output = try InProcessTestHelper.run("println((5 > 3) or (2 > 4))")
        #expect(output.lowercased().contains("true"))
    }

    @Test("not with comparison: not (5 = 3)")
    func testNotWithComparison() throws {
        let output = try InProcessTestHelper.run("println(not (5 = 3))")
        #expect(output.lowercased().contains("true"))
    }

    @Test("complex expression: (a and b) or c")
    func testComplexExpression() throws {
        let code = """
        変数 a: 論理 ← true
        変数 b: 論理 ← false
        変数 c: 論理 ← true
        println((a and b) or c)
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.lowercased().contains("true"))
    }

    @Test("nested logical: not (a and (b or c))")
    func testNestedLogical() throws {
        let code = """
        変数 a: 論理 ← true
        変数 b: 論理 ← false
        変数 c: 論理 ← false
        println(not (a and (b or c)))
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.lowercased().contains("true"))
    }

    // MARK: - Boolean Equality/Inequality Tests

    @Test("boolean equality: true = true")
    func testBooleanEqualityTrueTrue() throws {
        let output = try InProcessTestHelper.run("println(true = true)")
        #expect(output.lowercased().contains("true"))
    }

    @Test("boolean equality: true = false")
    func testBooleanEqualityTrueFalse() throws {
        let output = try InProcessTestHelper.run("println(true = false)")
        #expect(output.lowercased().contains("false"))
    }

    @Test("boolean equality: false = false")
    func testBooleanEqualityFalseFalse() throws {
        let output = try InProcessTestHelper.run("println(false = false)")
        #expect(output.lowercased().contains("true"))
    }

    @Test("boolean inequality: true ≠ false")
    func testBooleanInequalityTrueFalse() throws {
        let output = try InProcessTestHelper.run("println(true ≠ false)")
        #expect(output.lowercased().contains("true"))
    }

    @Test("boolean inequality: true ≠ true")
    func testBooleanInequalityTrueTrue() throws {
        let output = try InProcessTestHelper.run("println(true ≠ true)")
        #expect(output.lowercased().contains("false"))
    }

    @Test("boolean inequality: false ≠ false")
    func testBooleanInequalityFalseFalse() throws {
        let output = try InProcessTestHelper.run("println(false ≠ false)")
        #expect(output.lowercased().contains("false"))
    }

    @Test("combined boolean equality and inequality")
    func testCombinedBooleanEqualityInequality() throws {
        let code = """
        println(true = false)
        println(true ≠ false)
        """
        let output = try InProcessTestHelper.run(code)
        let lines = output.lowercased().split(separator: "\n")
        #expect(lines.count >= 2)
        #expect(lines[0].contains("false"))
        #expect(lines[1].contains("true"))
    }
}
