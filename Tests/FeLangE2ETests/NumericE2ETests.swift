import FeLangRuntime
import Foundation
import Testing

@Suite("Numeric E2E Tests", .serialized)
struct NumericE2ETests {

    // MARK: - Negative Integer Arithmetic

    @Test("Negative integer arithmetic: -5 + 3 = -2")
    func testNegativeIntegerArithmetic() throws {
        let output = try InProcessTestHelper.run("println(-5 + 3)")
        #expect(output.trimmingCharacters(in: .whitespacesAndNewlines) == "-2")
    }

    @Test("Negative modulo operation: -17 % 5")
    func testNegativeModulo() throws {
        let output = try InProcessTestHelper.run("println(-17 % 5)")
        // Verify actual behavior - Swift uses truncated division so -17 % 5 = -2
        #expect(output.contains("-2"))
    }

    @Test("Unary minus with parentheses: -(5 + 3) = -8")
    func testUnaryMinusParens() throws {
        let output = try InProcessTestHelper.run("println(-(5 + 3))")
        #expect(output.trimmingCharacters(in: .whitespacesAndNewlines) == "-8")
    }

    @Test("Double negation: --5 = 5")
    func testDoubleNegation() throws {
        let output = try InProcessTestHelper.run("println(--5)")
        #expect(output.trimmingCharacters(in: .whitespacesAndNewlines) == "5")
    }

    // MARK: - Negative Array Index and sqrt

    @Test("Negative array index should error")
    func testNegativeArrayIndex() throws {
        let code = """
        変数 arr: 配列 of 整数 ← [1, 2, 3]
        println(arr[-1])
        """
        let result = InProcessTestHelper.execute(code)
        #expect(!result.succeeded)
    }

    @Test("Square root of negative number")
    func testSqrtNegative() throws {
        let result = InProcessTestHelper.execute("println(sqrt(-1))")
        // This may produce NaN or an error - documenting actual behavior
        // If succeeded, output should contain NaN
        if result.succeeded {
            #expect(result.output.lowercased().contains("nan") || result.output.contains("-nan"))
        }
    }

    @Test("Square root of zero")
    func testSqrtZero() throws {
        let output = try InProcessTestHelper.run("println(sqrt(0))")
        #expect(output.contains("0"))
    }

    @Test("Square root of positive number")
    func testSqrtPositive() throws {
        let output = try InProcessTestHelper.run("println(sqrt(16))")
        #expect(output.contains("4"))
    }

    // MARK: - Type Coercion and Precision

    @Test("Mixed type multiplication: 3 * 2.5 = 7.5")
    func testMixedTypeMultiply() throws {
        let output = try InProcessTestHelper.run("println(3 * 2.5)")
        #expect(output.contains("7.5"))
    }

    @Test("Integer division: 7 / 3 = 2")
    func testIntegerDivision() throws {
        let output = try InProcessTestHelper.run("println(7 / 3)")
        #expect(output.trimmingCharacters(in: .whitespacesAndNewlines) == "2")
    }

    @Test("Real division: 7.0 / 3.0")
    func testRealDivision() throws {
        let output = try InProcessTestHelper.run("println(7.0 / 3.0)")
        #expect(output.contains("2.3"))
    }

    @Test("IEEE 754 precision: 0.1 + 0.2 != 0.3")
    func testFloatPrecision() throws {
        let output = try InProcessTestHelper.run("println(0.1 + 0.2 = 0.3)")
        // IEEE 754 means 0.1 + 0.2 != 0.3 exactly
        #expect(output.lowercased().contains("false"))
    }

    @Test("Large number with pow: 2^10 = 1024")
    func testPowLargeNumber() throws {
        let output = try InProcessTestHelper.run("println(pow(2.0, 10.0))")
        #expect(output.contains("1024"))
    }

    @Test("Very large number: 2^50")
    func testVeryLargeNumber() throws {
        let output = try InProcessTestHelper.run("println(pow(2.0, 50.0))")
        // 2^50 = 1125899906842624
        #expect(output.contains("1125899906842624"))
    }

    // MARK: - Edge Cases

    @Test("Zero division should error")
    func testZeroDivision() throws {
        let result = InProcessTestHelper.execute("println(10 / 0)")
        #expect(!result.succeeded)
    }

    @Test("Zero modulo should error")
    func testZeroModulo() throws {
        let result = InProcessTestHelper.execute("println(10 % 0)")
        #expect(!result.succeeded)
    }

    @Test("Negative number comparison")
    func testNegativeComparison() throws {
        let output = try InProcessTestHelper.run("println(-5 < -3)")
        #expect(output.lowercased().contains("true"))
    }

    // MARK: - ASCII Comparison Operators (<=, >=)

    @Test("Less than or equal (true): 3 <= 3")
    func testLessOrEqualTrue() throws {
        let output = try InProcessTestHelper.run("println(3 <= 3)")
        #expect(output.lowercased().contains("true"))
    }

    @Test("Less than or equal (false): 4 <= 3")
    func testLessOrEqualFalse() throws {
        let output = try InProcessTestHelper.run("println(4 <= 3)")
        #expect(output.lowercased().contains("false"))
    }

    @Test("Greater than or equal (false): 4 >= 5")
    func testGreaterOrEqualFalse() throws {
        let output = try InProcessTestHelper.run("println(4 >= 5)")
        #expect(output.lowercased().contains("false"))
    }

    @Test("Greater than or equal (true): 5 >= 5")
    func testGreaterOrEqualTrue() throws {
        let output = try InProcessTestHelper.run("println(5 >= 5)")
        #expect(output.lowercased().contains("true"))
    }

    // MARK: - Operator Precedence Tests

    @Test("Multiplication before addition: 1 + 2 * 3 = 7")
    func testArithmeticPrecedence() throws {
        let output = try InProcessTestHelper.run("println(1 + 2 * 3)")
        #expect(output.trimmingCharacters(in: .whitespacesAndNewlines) == "7")
    }

    @Test("Division before subtraction: 10 - 6 / 2 = 7")
    func testDivisionPrecedence() throws {
        let output = try InProcessTestHelper.run("println(10 - 6 / 2)")
        #expect(output.trimmingCharacters(in: .whitespacesAndNewlines) == "7")
    }

    @Test("Parentheses override precedence: (1 + 2) * 3 = 9")
    func testParenthesesOverride() throws {
        let output = try InProcessTestHelper.run("println((1 + 2) * 3)")
        #expect(output.trimmingCharacters(in: .whitespacesAndNewlines) == "9")
    }

    @Test("Comparison with arithmetic: 1 + 2 = 3")
    func testComparisonWithArithmetic() throws {
        let output = try InProcessTestHelper.run("println(1 + 2 = 3)")
        #expect(output.lowercased().contains("true"))
    }

    @Test("Comparison precedence: 2 * 3 > 5")
    func testComparisonPrecedenceMultiply() throws {
        let output = try InProcessTestHelper.run("println(2 * 3 > 5)")
        #expect(output.lowercased().contains("true"))
    }

    @Test("Complex expression: 2 + 3 * 4 - 5 = 9")
    func testComplexPrecedence() throws {
        let output = try InProcessTestHelper.run("println(2 + 3 * 4 - 5)")
        #expect(output.trimmingCharacters(in: .whitespacesAndNewlines) == "9")
    }

    @Test("Nested parentheses: ((2 + 3) * (4 - 1)) = 15")
    func testNestedParentheses() throws {
        let output = try InProcessTestHelper.run("println(((2 + 3) * (4 - 1)))")
        #expect(output.trimmingCharacters(in: .whitespacesAndNewlines) == "15")
    }

    @Test("Modulo precedence: 10 + 7 % 3 = 11")
    func testModuloPrecedence() throws {
        let output = try InProcessTestHelper.run("println(10 + 7 % 3)")
        #expect(output.trimmingCharacters(in: .whitespacesAndNewlines) == "11")
    }
}
