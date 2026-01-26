import FeLangRuntime
import Foundation
import Testing

@Suite("Execution E2E Tests", .serialized)
struct ExecutionE2ETests {

    // MARK: - Basic Execution

    @Test("Run simple println via --code")
    func testSimplePrintln() throws {
        let output = try InProcessTestHelper.run("println(42)")
        #expect(output.trimmingCharacters(in: .whitespacesAndNewlines) == "42")
    }

    @Test("Run code via stdin")
    func testRunStdin() throws {
        // This test requires CLI stdin input, so we keep CLITestHelper
        try CLITestHelper.ensureBinaryBuilt()
        let result = try CLITestHelper.run(
            arguments: ["run", "-"],
            stdin: "println(1 + 2)"
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("3"))
    }

    @Test("Run string output")
    func testStringOutput() throws {
        let output = try InProcessTestHelper.run("println(\"Hello, World!\")")
        #expect(output.contains("Hello, World!"))
    }

    // MARK: - Arithmetic Tests

    @Test("Arithmetic operations")
    func testArithmetic() throws {
        let output = try InProcessTestHelper.run("println(10 + 5 * 2)")
        #expect(output.contains("20"))
    }

    @Test("Division operation")
    func testDivision() throws {
        let output = try InProcessTestHelper.run("println(100 / 5)")
        #expect(output.contains("20"))
    }

    @Test("Modulo operation")
    func testModulo() throws {
        let output = try InProcessTestHelper.run("println(17 % 5)")
        #expect(output.contains("2"))
    }

    // MARK: - Boolean Tests

    @Test("Boolean true")
    func testBooleanTrue() throws {
        let output = try InProcessTestHelper.run("println(5 > 3)")
        #expect(output.lowercased().contains("true"))
    }

    @Test("Boolean false")
    func testBooleanFalse() throws {
        let output = try InProcessTestHelper.run("println(3 > 5)")
        #expect(output.lowercased().contains("false"))
    }

    // MARK: - Multiple Statements

    @Test("Multiple println statements")
    func testMultipleStatements() throws {
        let code = """
        println(1)
        println(2)
        println(3)
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.contains("1"))
        #expect(output.contains("2"))
        #expect(output.contains("3"))
    }

    // MARK: - Complete Program Tests

    @Test("FizzBuzz implementation")
    func testFizzBuzz() throws {
        let code = """
        for i ← 1 to 15 do
            if i % 15 = 0 then
                println("FizzBuzz")
            elif i % 3 = 0 then
                println("Fizz")
            elif i % 5 = 0 then
                println("Buzz")
            else
                println(i)
            endif
        endfor
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.contains("FizzBuzz"))
        #expect(output.contains("Fizz"))
        #expect(output.contains("Buzz"))
    }

    @Test("Prime number checker")
    func testPrimeChecker() throws {
        let code = """
        function isPrime(n: 整数): 論理
            if n < 2 then
                return false
            endif
            変数 i: 整数 ← 2
            while i * i ≦ n do
                if n % i = 0 then
                    return false
                endif
                i ← i + 1
            endwhile
            return true
        endfunction
        println(isPrime(17))
        println(isPrime(18))
        println(isPrime(2))
        println(isPrime(1))
        """
        let output = try InProcessTestHelper.run(code)
        let lines = output.lowercased().split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }
        #expect(lines.count >= 4, "Expected 4 output lines, got \(lines.count): \(lines)")
        guard lines.count >= 4 else { return }
        #expect(lines[0] == "true")   // 17 is prime
        #expect(lines[1] == "false")  // 18 is not prime
        #expect(lines[2] == "true")   // 2 is prime
        #expect(lines[3] == "false")  // 1 is not prime
    }

    @Test("Sum of array elements")
    func testSumArray() throws {
        let code = """
        変数 arr: 配列 of 整数 ← [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        変数 sum: 整数 ← 0
        for item in arr do
            sum ← sum + item
        endfor
        println(sum)
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.contains("55"))
    }

    @Test("GCD calculation")
    func testGCD() throws {
        let code = """
        function gcd(a: 整数, b: 整数): 整数
            while b ≠ 0 do
                変数 temp: 整数 ← b
                b ← a % b
                a ← temp
            endwhile
            return a
        endfunction
        println(gcd(48, 18))
        println(gcd(100, 25))
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.contains("6"))   // GCD(48, 18) = 6
        #expect(output.contains("25"))  // GCD(100, 25) = 25
    }

    @Test("String manipulation program")
    func testStringManipulation() throws {
        let code = """
        変数 text: 文字列 ← "  Hello World  "
        変数 trimmed: 文字列 ← trim(text)
        変数 upper: 文字列 ← upper(trimmed)
        println(upper)
        println(length(trimmed))
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.contains("HELLO WORLD"))
        #expect(output.contains("11"))
    }

    @Test("Japanese identifiers in variable and function names")
    func testJapaneseIdentifiers() throws {
        let code = """
        変数 合計: 整数 ← 0
        function 加算(a: 整数, b: 整数): 整数
            return a + b
        endfunction
        合計 ← 加算(2, 3)
        println(合計)
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.trimmingCharacters(in: .whitespacesAndNewlines) == "5")
    }
}
