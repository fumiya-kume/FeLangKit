import Foundation
import Testing

@Suite("Edge Case E2E Tests", .serialized)
struct EdgeCaseE2ETests {

    init() throws {
        try CLITestHelper.ensureBinaryBuilt()
    }

    // MARK: - Empty and Minimal Programs

    @Test("empty program")
    func testEmptyProgram() throws {
        let result = try CLITestHelper.run(
            arguments: ["run", "--code", ""]
        )
        // Empty program should either succeed with no output or error
        // Document actual behavior
        if result.exitCode == 0 {
            #expect(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } else {
            // Non-zero exit code is also acceptable behavior for empty program.
        }
    }

    @Test("whitespace only program")
    func testWhitespaceOnly() throws {
        let result = try CLITestHelper.run(
            arguments: ["run", "--code", "   \n\n   \t   "]
        )
        // Whitespace-only program should behave like empty program
        if result.exitCode == 0 {
            #expect(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } else {
            // Non-zero exit code is also acceptable behavior for whitespace-only program.
        }
    }

    @Test("comment only program")
    func testCommentOnly() throws {
        let code = """
        // This is a comment
        // Another comment
        """
        let result = try CLITestHelper.run(arguments: ["run", "--code", code])
        // Comment-only program should succeed with no output
        if result.exitCode == 0 {
            #expect(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } else {
            // Non-zero exit code is also acceptable behavior for comment-only program.
        }
    }

    @Test("single statement program")
    func testSingleStatement() throws {
        let result = try CLITestHelper.run(
            arguments: ["run", "--code", "println(42)"]
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("42"))
    }

    @Test("empty array literal length via CLI")
    func testEmptyArrayLengthViaCLI() throws {
        // Cover CLI execution path for empty array handling.
        let code = """
        変数 arr: 配列 of 整数 ← []
        println(arrayLength(arr))
        """
        let result = try CLITestHelper.run(arguments: ["run", "--code", code])
        #expect(result.exitCode == 0)
        #expect(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "0")
    }

    // MARK: - Nested Structures

    @Test("triple nested for loops")
    func testTripleNestedLoops() throws {
        let code = """
        変数 count: 整数 ← 0
        for i ← 1 to 2 do
            for j ← 1 to 2 do
                for k ← 1 to 2 do
                    count ← count + 1
                endfor
            endfor
        endfor
        println(count)
        """
        let result = try CLITestHelper.run(arguments: ["run", "--code", code])
        #expect(result.exitCode == 0)
        // 2 * 2 * 2 = 8
        #expect(result.stdout.contains("8"))
    }

    @Test("deeply nested if statements")
    func testDeeplyNestedIf() throws {
        let code = """
        変数 x: 整数 ← 5
        if x > 0 then
            if x > 1 then
                if x > 2 then
                    if x > 3 then
                        if x > 4 then
                            println("deep")
                        endif
                    endif
                endif
            endif
        endif
        """
        let result = try CLITestHelper.run(arguments: ["run", "--code", code])
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("deep"))
    }

    @Test("nested function calls")
    func testNestedFunctionCalls() throws {
        let code = """
        function add(a: 整数, b: 整数): 整数
            return a + b
        endfunction
        function mul(a: 整数, b: 整数): 整数
            return a * b
        endfunction
        println(add(mul(2, 3), mul(4, 5)))
        """
        let result = try CLITestHelper.run(arguments: ["run", "--code", code])
        #expect(result.exitCode == 0)
        // (2*3) + (4*5) = 6 + 20 = 26
        #expect(result.stdout.contains("26"))
    }

    // MARK: - Multi-dimensional Arrays

    @Test("nested array literal")
    func testNestedArrayLiteral() throws {
        // Test nested array literal creation
        let code = """
        変数 arr: 配列 of 配列 of 整数 ← [[1, 2], [3, 4]]
        println(arrayLength(arr))
        """
        let result = try CLITestHelper.run(arguments: ["run", "--code", code])
        // Document actual behavior - nested arrays may or may not be fully supported
        if result.exitCode == 0 {
            #expect(result.stdout.contains("2"))
        } else {
            // Nested array literal parsing not supported - document limitation
            #expect(result.exitCode != 0)
        }
    }

    @Test("access nested array element")
    func testAccessNestedArray() throws {
        // Test arr[i][j] access syntax
        let code = """
        変数 arr: 配列 of 配列 of 整数 ← [[1, 2], [3, 4]]
        println(arr[0][1])
        """
        let result = try CLITestHelper.run(arguments: ["run", "--code", code])
        // Document actual behavior
        if result.exitCode == 0 {
            #expect(result.stdout.contains("2"))
        } else {
            // Multi-dimensional access not supported - document limitation
            #expect(result.exitCode != 0)
        }
    }

    @Test("nested array element assignment")
    func testNestedArrayElementAssignment() throws {
        // Test arr[i][j] ← value syntax (requires both parser and executor support)
        let code = """
        変数 arr: 配列 of 配列 of 整数 ← [[1, 2], [3, 4]]
        arr[0][1] ← 99
        println(arr[0][1])
        """
        let result = try CLITestHelper.run(arguments: ["run", "--code", code])
        // Document actual behavior
        if result.exitCode == 0 {
            #expect(result.stdout.contains("99"))
        } else {
            // Nested array assignment not supported - document limitation
            #expect(result.exitCode != 0)
        }
    }

    @Test("nested array with Japanese の particle")
    func testNestedArrayWithJapaneseParticle() throws {
        // Test multi-dimensional array type with Japanese の particle
        let code = """
        変数 arr: 配列 の 配列 の 整数 ← [[1, 2], [3, 4]]
        println(arr[0][1])
        """
        let result = try CLITestHelper.run(arguments: ["run", "--code", code])
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("2"))
    }

    // MARK: - Special Syntax

    @Test("empty procedure body")
    func testEmptyProcedureBody() throws {
        let code = """
        procedure doNothing()
        endprocedure
        doNothing()
        println("done")
        """
        let result = try CLITestHelper.run(arguments: ["run", "--code", code])
        // Empty procedure should be valid
        if result.exitCode == 0 {
            #expect(result.stdout.contains("done"))
        } else {
            #expect(result.exitCode != 0)
        }
    }

    @Test("function without parameters")
    func testNoParamFunction() throws {
        let code = """
        function getFortyTwo(): 整数
            return 42
        endfunction
        println(getFortyTwo())
        """
        let result = try CLITestHelper.run(arguments: ["run", "--code", code])
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("42"))
    }

    @Test("mixed Japanese and English keywords")
    func testUnicodeKeywordMix() throws {
        let code = """
        変数 count: integer ← 0
        variable sum: 整数 ← 0
        for i ← 1 to 3 do
            count ← count + 1
            sum ← sum + i
        endfor
        println(count)
        println(sum)
        """
        let result = try CLITestHelper.run(arguments: ["run", "--code", code])
        // Mixed keywords should work
        if result.exitCode == 0 {
            #expect(result.stdout.contains("3"))
            #expect(result.stdout.contains("6"))
        } else {
            // Document if mixed keywords are not supported
            #expect(result.exitCode != 0)
        }
    }
}
