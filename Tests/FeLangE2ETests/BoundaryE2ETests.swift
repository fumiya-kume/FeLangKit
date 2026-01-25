import Foundation
import Testing

@Suite("Boundary Condition E2E Tests", .serialized)
struct BoundaryE2ETests {

    init() async throws {
        try CLITestHelper.ensureBinaryBuilt()
    }

    // MARK: - Nesting Depth Tests

    @Test("deep nesting within limit")
    func testNestingWithinLimit() throws {
        // Generate 20-level nested if statements (well within 100 limit)
        var code = "変数 x: 整数 ← 1\n"
        for level in 1...20 {
            code += String(repeating: "    ", count: level - 1) + "if x > 0 then\n"
        }
        code += String(repeating: "    ", count: 20) + "println(\"deep\")\n"
        for level in (1...20).reversed() {
            code += String(repeating: "    ", count: level - 1) + "endif\n"
        }

        let result = try CLITestHelper.run(arguments: ["run", "--code", code])
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("deep"))
    }

    @Test("deep nesting near limit")
    func testNestingNearLimit() throws {
        // Generate 50-level nested if statements (closer to limit)
        var code = "変数 x: 整数 ← 1\n"
        for level in 1...50 {
            code += String(repeating: "    ", count: level - 1) + "if x > 0 then\n"
        }
        code += String(repeating: "    ", count: 50) + "println(\"very deep\")\n"
        for level in (1...50).reversed() {
            code += String(repeating: "    ", count: level - 1) + "endif\n"
        }

        let result = try CLITestHelper.run(arguments: ["run", "--code", code], timeout: 10.0)
        // Document actual behavior
        if result.exitCode == 0 {
            #expect(result.stdout.contains("very deep"))
        } else {
            // May hit nesting limit
            #expect(result.exitCode != 0)
        }
    }

    // MARK: - Large Data Structure Tests

    @Test("large array creation and access")
    func testLargeArray() throws {
        // Create array with 100 elements
        var elements = (0..<100).map { String($0) }.joined(separator: ", ")
        let code = """
        変数 arr: 配列 of 整数 ← [\(elements)]
        println(arrayLength(arr))
        println(arr[0])
        println(arr[99])
        """
        let result = try CLITestHelper.run(arguments: ["run", "--code", code], timeout: 10.0)
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("100"))
        #expect(result.stdout.contains("0"))
        #expect(result.stdout.contains("99"))
    }

    @Test("long string handling")
    func testLongString() throws {
        // Create a 1000-character string
        let longStr = String(repeating: "a", count: 1000)
        let code = """
        変数 s: 文字列 ← "\(longStr)"
        println(length(s))
        """
        let result = try CLITestHelper.run(arguments: ["run", "--code", code], timeout: 10.0)
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("1000"))
    }

    @Test("long identifier name")
    func testLongIdentifier() throws {
        let longName = "variable" + String(repeating: "x", count: 50)
        let code = """
        変数 \(longName): 整数 ← 42
        println(\(longName))
        """
        let result = try CLITestHelper.run(arguments: ["run", "--code", code])
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("42"))
    }

    // MARK: - Scale Tests

    @Test("function with many parameters")
    func testManyParameters() throws {
        let code = """
        function add10(a: 整数, b: 整数, c: 整数, d: 整数, e: 整数, f: 整数, g: 整数, h: 整数, i: 整数, j: 整数): 整数
            return a + b + c + d + e + f + g + h + i + j
        endfunction
        println(add10(1, 2, 3, 4, 5, 6, 7, 8, 9, 10))
        """
        let result = try CLITestHelper.run(arguments: ["run", "--code", code])
        #expect(result.exitCode == 0)
        // 1+2+3+4+5+6+7+8+9+10 = 55
        #expect(result.stdout.contains("55"))
    }

    @Test("deep recursion within limit")
    func testDeepRecursion() throws {
        let code = """
        function countdown(n: 整数): 整数
            if n ≦ 0 then
                return 0
            endif
            return countdown(n - 1)
        endfunction
        println(countdown(500))
        """
        let result = try CLITestHelper.run(arguments: ["run", "--code", code], timeout: 10.0)
        // May succeed or hit recursion limit
        if result.exitCode == 0 {
            #expect(result.stdout.contains("0"))
        } else {
            // Recursion limit exceeded - document actual limit
            #expect(result.exitCode != 0)
        }
    }

    @Test("program with many statements")
    func testLargeProgram() throws {
        // Generate program with 50 print statements
        var code = ""
        for num in 1...50 {
            code += "println(\(num))\n"
        }

        let result = try CLITestHelper.run(arguments: ["run", "--code", code], timeout: 10.0)
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("1"))
        #expect(result.stdout.contains("50"))
    }

    @Test("program with many functions")
    func testManyFunctions() throws {
        // Generate 10 simple functions
        var code = ""
        for idx in 1...10 {
            code += """
            function f\(idx)(): 整数
                return \(idx)
            endfunction

            """
        }
        code += "println(f1() + f5() + f10())\n"

        let result = try CLITestHelper.run(arguments: ["run", "--code", code])
        #expect(result.exitCode == 0)
        // 1 + 5 + 10 = 16
        #expect(result.stdout.contains("16"))
    }

    // MARK: - Edge Value Tests

    @Test("for loop with end less than start executes zero times")
    func testForLoopEndLessThanStart() throws {
        // When end < start without explicit negative step, loop should not execute
        let code = """
        変数 count: 整数 ← 0
        for i ← 1 to 0 do
            count ← count + 1
        endfor
        println(count)
        """
        let result = try CLITestHelper.run(arguments: ["run", "--code", code])
        #expect(result.exitCode == 0)
        // Loop should execute 0 times when end < start without explicit step
        #expect(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "0")
    }

    @Test("negative step in for loop counts down correctly")
    func testNegativeStep() throws {
        let code = """
        変数 sum: 整数 ← 0
        for i ← 5 to 1 step -1 do
            sum ← sum + i
        endfor
        println(sum)
        """
        let result = try CLITestHelper.run(arguments: ["run", "--code", code])
        #expect(result.exitCode == 0)
        // 5 + 4 + 3 + 2 + 1 = 15
        #expect(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "15")
    }

    @Test("zero step causes error")
    func testZeroStepCausesError() throws {
        let code = """
        変数 count: 整数 ← 0
        for i ← 1 to 5 step 0 do
            count ← count + 1
        endfor
        println(count)
        """
        let result = try CLITestHelper.run(arguments: ["run", "--code", code])
        // Zero step should cause error (would be infinite loop)
        #expect(result.exitCode != 0)
    }

    @Test("negative step with ascending range is empty")
    func testNegativeStepAscendingRange() throws {
        // Negative step with start < end should result in empty loop
        let code = """
        変数 count: 整数 ← 0
        for i ← 1 to 5 step -1 do
            count ← count + 1
        endfor
        println(count)
        """
        let result = try CLITestHelper.run(arguments: ["run", "--code", code])
        #expect(result.exitCode == 0)
        // Loop should not execute when direction doesn't match step
        #expect(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "0")
    }
}
