import FeLangRuntime
import Foundation
import Testing

@Suite("Control Flow E2E Tests", .serialized)
struct ControlFlowE2ETests {

    // MARK: - Recursion Depth Limits

    // Note: Deep recursion tests (100+ levels) must use CLITestHelper
    // because in-process execution can hit Swift's stack limits.
    // See BoundaryE2ETests for deep recursion tests.

    @Test("Shallow recursion succeeds")
    func testShallowRecursion() throws {
        let code = """
        function countdown(n: 整数): 整数
            if n ≦ 0 then
                return 0
            endif
            return countdown(n - 1)
        endfunction
        println(countdown(10))
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.contains("0"))
    }

    // Deep recursion tests (500+ levels) are in BoundaryE2ETests
    // using CLITestHelper which spawns a separate process.

    // MARK: - Nested Structures

    @Test("Deeply nested if-while-for")
    func testDeeplyNestedStructures() throws {
        let code = """
        変数 result: 整数 ← 0
        if true then
            変数 i: 整数 ← 0
            while i < 3 do
                for j ← 1 to 2 do
                    if j = 1 then
                        result ← result + 1
                    endif
                endfor
                i ← i + 1
            endwhile
        endif
        println(result)
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.contains("3"))
    }

    @Test("Nested function calls in expressions")
    func testNestedFunctionCalls() throws {
        // This covers nested function calls in-process; CLI coverage lives in EdgeCaseE2ETests.
        // max(3, -2) = 3, min(-5, 3) = -5, abs(-5) = 5
        let output = try InProcessTestHelper.run("println(abs(min(-5, max(3, -2))))")
        #expect(output.contains("5"))
    }

    @Test("If-elif-else chain")
    func testIfElifElseChain() throws {
        let code = """
        変数 x: 整数 ← 2
        if x = 1 then
            println("one")
        elif x = 2 then
            println("two")
        elif x = 3 then
            println("three")
        else
            println("other")
        endif
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.contains("two"))
    }

    // MARK: - Break and Continue

    @Test("Break in while loop")
    func testBreakInWhile() throws {
        let code = """
        変数 i: 整数 ← 0
        while i < 10 do
            if i = 5 then
                break
            endif
            i ← i + 1
        endwhile
        println(i)
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.contains("5"))
    }

    @Test("Break in nested while loops")
    func testBreakNestedWhile() throws {
        let code = """
        変数 outer: 整数 ← 0
        変数 breakCount: 整数 ← 0
        while outer < 3 do
            変数 inner: 整数 ← 0
            while inner < 10 do
                if inner = 2 then
                    breakCount ← breakCount + 1
                    break
                endif
                inner ← inner + 1
            endwhile
            outer ← outer + 1
        endwhile
        println(breakCount)
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.contains("3"))
    }

    @Test("Continue in for loop")
    func testContinueForLoop() throws {
        let code = """
        変数 sum: 整数 ← 0
        for i ← 1 to 5 do
            if i = 3 then
                continue
            endif
            sum ← sum + i
        endfor
        println(sum)
        """
        let output = try InProcessTestHelper.run(code)
        // 1+2+4+5 = 12 (skipping 3)
        #expect(output.contains("12"))
    }

    @Test("Continue in while loop")
    func testContinueWhile() throws {
        let code = """
        変数 i: 整数 ← 0
        変数 sum: 整数 ← 0
        while i < 5 do
            i ← i + 1
            if i = 3 then
                continue
            endif
            sum ← sum + i
        endwhile
        println(sum)
        """
        let output = try InProcessTestHelper.run(code)
        // 1+2+4+5 = 12 (skipping 3)
        #expect(output.contains("12"))
    }

    @Test("Break outside loop should error")
    func testBreakOutsideLoop() throws {
        let result = InProcessTestHelper.execute("break")
        #expect(!result.succeeded)
        if let error = result.error {
            let message = String(describing: error).lowercased()
            #expect(message.contains("break") || message.contains("loop"))
        }
    }

    @Test("Continue outside loop should error")
    func testContinueOutsideLoop() throws {
        let result = InProcessTestHelper.execute("continue")
        #expect(!result.succeeded)
        if let error = result.error {
            let message = String(describing: error).lowercased()
            #expect(message.contains("continue") || message.contains("loop"))
        }
    }

    // MARK: - For Loop Variations

    @Test("For loop with step")
    func testForLoopWithStep() throws {
        let code = """
        変数 sum: 整数 ← 0
        for i ← 0 to 10 step 2 do
            sum ← sum + i
        endfor
        println(sum)
        """
        let output = try InProcessTestHelper.run(code)
        // 0+2+4+6+8+10 = 30
        #expect(output.contains("30"))
    }

    @Test("For each loop over array")
    func testForEachLoop() throws {
        let code = """
        変数 arr: 配列 of 整数 ← [1, 2, 3, 4, 5]
        変数 sum: 整数 ← 0
        for item in arr do
            sum ← sum + item
        endfor
        println(sum)
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.contains("15"))
    }

    // MARK: - While Loop Edge Cases

    @Test("While loop with false condition")
    func testWhileFalseCondition() throws {
        let code = """
        変数 count: 整数 ← 0
        while false do
            count ← count + 1
        endwhile
        println(count)
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.trimmingCharacters(in: .whitespacesAndNewlines) == "0")
    }

    @Test("While loop executes at least once check")
    func testWhileExecutesOnce() throws {
        let code = """
        変数 count: 整数 ← 0
        変数 condition: 論理 ← true
        while condition do
            count ← count + 1
            condition ← false
        endwhile
        println(count)
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.trimmingCharacters(in: .whitespacesAndNewlines) == "1")
    }
}
