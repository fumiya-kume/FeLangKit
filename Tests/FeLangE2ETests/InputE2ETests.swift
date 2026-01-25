import Foundation
import Testing

@Suite("Input Function E2E Tests", .serialized)
struct InputE2ETests {

    init() async throws {
        try CLITestHelper.ensureBinaryBuilt()
    }

    // MARK: - Basic Input Tests

    @Test("input with prompt displays prompt and reads stdin")
    func testInputWithPrompt() throws {
        let code = """
        変数 name: 文字列 ← input("Enter name: ")
        println(name)
        """
        let result = try CLITestHelper.run(
            arguments: ["run", "--code", code],
            stdin: "Alice"
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("Alice"))
    }

    @Test("input without prompt reads stdin")
    func testInputWithoutPrompt() throws {
        let code = """
        変数 value: 文字列 ← input()
        println(value)
        """
        let result = try CLITestHelper.run(
            arguments: ["run", "--code", code],
            stdin: "Hello"
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("Hello"))
    }

    @Test("input with empty string")
    func testInputEmptyString() throws {
        let code = """
        変数 value: 文字列 ← input()
        println(length(value))
        """
        let result = try CLITestHelper.run(
            arguments: ["run", "--code", code],
            stdin: ""
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("0"))
    }

    @Test("input in expression")
    func testInputInExpression() throws {
        let code = """
        println(concat("Hello, ", input()))
        """
        let result = try CLITestHelper.run(
            arguments: ["run", "--code", code],
            stdin: "World"
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("Hello, World"))
    }

    @Test("multiple input calls")
    func testInputMultipleCalls() throws {
        let code = """
        変数 a: 文字列 ← input()
        変数 b: 文字列 ← input()
        println(concat(a, " ", b))
        """
        let result = try CLITestHelper.run(
            arguments: ["run", "--code", code],
            stdin: "Hello\nWorld"
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("Hello World"))
    }

    @Test("input with numeric conversion")
    func testInputWithNumericConversion() throws {
        let code = """
        変数 numStr: 文字列 ← input()
        変数 num: 整数 ← toInteger(numStr)
        println(num * 2)
        """
        let result = try CLITestHelper.run(
            arguments: ["run", "--code", code],
            stdin: "21"
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("42"))
    }
}
