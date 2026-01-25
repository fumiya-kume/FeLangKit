import Foundation
import Testing

@Suite("Variadic Function E2E Tests", .serialized)
struct VariadicFunctionE2ETests {

    init() async throws {
        try CLITestHelper.ensureBinaryBuilt()
    }

    // MARK: - min() with Multiple Arguments

    @Test("min with three arguments")
    func testMinThreeArgs() throws {
        let result = try CLITestHelper.run(
            arguments: ["run", "--code", "println(min(5, 3, 7))"]
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "3")
    }

    @Test("min with four arguments")
    func testMinFourArgs() throws {
        let result = try CLITestHelper.run(
            arguments: ["run", "--code", "println(min(5, 3, 7, 1))"]
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "1")
    }

    @Test("min with five arguments including negative")
    func testMinFiveArgsNegative() throws {
        let result = try CLITestHelper.run(
            arguments: ["run", "--code", "println(min(5, -3, 7, 1, 0))"]
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "-3")
    }

    // MARK: - max() with Multiple Arguments

    @Test("max with three arguments")
    func testMaxThreeArgs() throws {
        let result = try CLITestHelper.run(
            arguments: ["run", "--code", "println(max(1, 5, 3))"]
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "5")
    }

    @Test("max with four arguments")
    func testMaxFourArgs() throws {
        let result = try CLITestHelper.run(
            arguments: ["run", "--code", "println(max(1, 5, 3, 8))"]
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "8")
    }

    @Test("max with five arguments including negative")
    func testMaxFiveArgsNegative() throws {
        let result = try CLITestHelper.run(
            arguments: ["run", "--code", "println(max(-10, -5, -20, -1, -15))"]
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "-1")
    }

    // MARK: - concat() with Multiple Arguments

    @Test("concat with four strings")
    func testConcatFourStrings() throws {
        let result = try CLITestHelper.run(
            arguments: ["run", "--code", "println(concat(\"a\", \"b\", \"c\", \"d\"))"]
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("abcd"))
    }

    @Test("concat with five strings")
    func testConcatFiveStrings() throws {
        let result = try CLITestHelper.run(
            arguments: ["run", "--code", "println(concat(\"Hello\", \" \", \"World\", \"!\", \"!\"))"]
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("Hello World!!"))
    }

    // MARK: - concat_arrays() with Multiple Arrays

    @Test("concat_arrays with three arrays")
    func testConcatArraysThree() throws {
        let code = """
        変数 a: 配列 of 整数 ← [1, 2]
        変数 b: 配列 of 整数 ← [3, 4]
        変数 c: 配列 of 整数 ← [5, 6]
        変数 result: 配列 of 整数 ← concat_arrays(a, b, c)
        println(arrayLength(result))
        """
        let result = try CLITestHelper.run(arguments: ["run", "--code", code])
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("6"))
    }

    @Test("concat_arrays with four arrays")
    func testConcatArraysFour() throws {
        let code = """
        変数 a: 配列 of 整数 ← [1]
        変数 b: 配列 of 整数 ← [2]
        変数 c: 配列 of 整数 ← [3]
        変数 d: 配列 of 整数 ← [4]
        変数 result: 配列 of 整数 ← concat_arrays(a, b, c, d)
        println(arrayLength(result))
        println(result[0])
        println(result[3])
        """
        let result = try CLITestHelper.run(arguments: ["run", "--code", code])
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("4"))
        #expect(result.stdout.contains("1"))
    }

    // MARK: - Mixed Variadic Calls

    @Test("nested variadic function calls")
    func testNestedVariadicCalls() throws {
        let result = try CLITestHelper.run(
            arguments: ["run", "--code", "println(max(min(5, 3), min(7, 2), min(9, 4)))"]
        )
        #expect(result.exitCode == 0)
        // max(3, 2, 4) = 4
        #expect(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "4")
    }

    @Test("variadic with expressions")
    func testVariadicWithExpressions() throws {
        let result = try CLITestHelper.run(
            arguments: ["run", "--code", "println(min(1 + 2, 2 * 2, 10 - 5))"]
        )
        #expect(result.exitCode == 0)
        // min(3, 4, 5) = 3
        #expect(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "3")
    }
}
