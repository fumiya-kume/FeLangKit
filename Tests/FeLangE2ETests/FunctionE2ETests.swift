import FeLangRuntime
import Foundation
import Testing

@Suite("Function E2E Tests", .serialized)
struct FunctionE2ETests {

    // MARK: - Constant Handling

    @Test("Constant shadowing in function scope")
    func testConstantShadowing() throws {
        let code = """
        定数 x: 整数 ← 10
        function test(): 整数
            変数 x: 整数 ← 20
            return x
        endfunction
        println(test())
        println(x)
        """
        let output = try InProcessTestHelper.run(code)
        let lines = output.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        #expect(lines == ["20", "10"])
    }

    @Test("Constant capture in function")
    func testConstantCapture() throws {
        let code = """
        定数 multiplier: 整数 ← 5
        function multiply(n: 整数): 整数
            return n * multiplier
        endfunction
        println(multiply(3))
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.contains("15"))
    }

    @Test("Cannot reassign constant")
    func testCannotReassignConstant() throws {
        let code = """
        定数 x: 整数 ← 10
        x ← 20
        """
        let result = InProcessTestHelper.execute(code)
        #expect(!result.succeeded)
    }

    @Test("Variable can be reassigned")
    func testVariableReassignment() throws {
        let code = """
        変数 x: 整数 ← 10
        x ← 20
        println(x)
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.contains("20"))
    }

    // MARK: - Recursive Functions

    @Test("Fibonacci recursive")
    func testFibonacciRecursive() throws {
        let code = """
        function fib(n: 整数): 整数
            if n < 2 then
                return n
            endif
            return (fib(n - 1) + fib(n - 2))
        endfunction
        println(fib(10))
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.contains("55"))
    }

    @Test("Factorial recursive")
    func testFactorialRecursive() throws {
        let code = """
        function factorial(n: 整数): 整数
            if n < 2 then
                return 1
            endif
            return (n * factorial(n - 1))
        endfunction
        println(factorial(5))
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.contains("120"))
    }

    @Test("Mutual recursion")
    func testMutualRecursion() throws {
        let code = """
        function isEven(n: 整数): 論理
            if n = 0 then
                return true
            endif
            return isOdd(n - 1)
        endfunction

        function isOdd(n: 整数): 論理
            if n = 0 then
                return false
            endif
            return isEven(n - 1)
        endfunction

        println(isEven(10))
        println(isOdd(10))
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.lowercased().contains("true"))
        #expect(output.lowercased().contains("false"))
    }

    // MARK: - Function Parameters

    @Test("Function with multiple parameters")
    func testMultipleParameters() throws {
        let code = """
        function add(a: 整数, b: 整数, c: 整数): 整数
            return a + b + c
        endfunction
        println(add(1, 2, 3))
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.contains("6"))
    }

    @Test("Function with string parameter")
    func testStringParameter() throws {
        let code = """
        function greet(name: 文字列): 文字列
            return concat("Hello, ", name, "!")
        endfunction
        println(greet("World"))
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.contains("Hello, World!"))
    }

    // MARK: - Procedures

    @Test("Procedure with local output")
    func testProcedureWithOutput() throws {
        let code = """
        procedure greet(name: 文字列)
            println(concat("Hello, ", name))
        endprocedure
        greet("World")
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.contains("Hello, World"))
    }

    @Test("Procedure with parameter")
    func testProcedureWithParameter() throws {
        let code = """
        procedure printDouble(n: 整数)
            println(n * 2)
        endprocedure
        printDouble(5)
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.contains("10"))
    }

    // MARK: - Return Statements

    @Test("Multiple return paths")
    func testMultipleReturnPaths() throws {
        let code = """
        function absoluteValue(n: 整数): 整数
            if n < 0 then
                return -n
            endif
            return n
        endfunction
        println(absoluteValue(-5))
        println(absoluteValue(5))
        """
        let output = try InProcessTestHelper.run(code)
        let lines = output.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }
        #expect(lines.contains("5"))
    }

    @Test("Early return from loop")
    func testEarlyReturnFromLoop() throws {
        let code = """
        function findFirst(target: 整数): 整数
            for i ← 0 to 10 do
                if i = target then
                    return i
                endif
            endfor
            return -1
        endfunction
        println(findFirst(5))
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.contains("5"))
    }

    // MARK: - Scope Tests

    @Test("Local variables don't affect global")
    func testLocalVariableScope() throws {
        let code = """
        変数 x: 整数 ← 100
        function modify(): 整数
            変数 x: 整数 ← 50
            return x
        endfunction
        println(modify())
        println(x)
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.contains("50"))
        #expect(output.contains("100"))
    }

    @Test("Function calls function")
    func testFunctionCallsFunction() throws {
        let code = """
        function double(n: 整数): 整数
            return n * 2
        endfunction
        function quadruple(n: 整数): 整数
            return double(double(n))
        endfunction
        println(quadruple(5))
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.contains("20"))
    }
}
