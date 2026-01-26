import FeLangRuntime
import Foundation
import Testing

@Suite("Error Handling E2E Tests", .serialized)
struct ErrorE2ETests {

    init() async throws {
        try CLITestHelper.ensureBinaryBuilt()
    }

    // MARK: - Parse Error Tests
    // These tests require CLI because they test parse errors before execution

    @Test("Syntax error returns non-zero exit code")
    func testSyntaxError() throws {
        let code = "println("  // Missing closing paren and argument
        let result = InProcessTestHelper.execute(code)
        #expect(!result.succeeded)
    }

    @Test("Invalid token returns error")
    func testInvalidToken() throws {
        let code = "@@@invalid@@@"
        let result = InProcessTestHelper.execute(code)
        #expect(!result.succeeded)
    }

    @Test("Return outside function returns error")
    func testReturnOutsideFunction() throws {
        let code = "return 1"
        let result = InProcessTestHelper.execute(code)
        #expect(!result.succeeded)
    }

    // MARK: - File Error Tests
    // These tests require CLI because they test file path handling

    @Test("Non-existent file returns error")
    func testFileNotFound() throws {
        let result = try CLITestHelper.run(
            arguments: ["run", "/nonexistent/path/to/file.fe"]
        )
        #expect(result.exitCode != 0)
    }

    @Test("Directory path returns error")
    func testDirectoryPathReturnsError() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("felang-dir-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let result = try CLITestHelper.run(arguments: ["run", tempDir.path])
        #expect(result.exitCode != 0)
        #expect(result.stderr.contains("Cannot read file"))
    }

    // MARK: - No Input Error Tests
    // These tests require CLI because they test CLI argument handling

    @Test("No input shows error")
    func testNoInput() throws {
        let result = try CLITestHelper.run(arguments: ["run"])
        #expect(result.exitCode != 0)
    }

    @Test("Parse command with no input shows error")
    func testParseNoInput() throws {
        let result = try CLITestHelper.run(arguments: ["parse"])
        #expect(result.exitCode != 0)
    }

    @Test("Tokenize command with no input shows error")
    func testTokenizeNoInput() throws {
        let result = try CLITestHelper.run(arguments: ["tokenize"])
        #expect(result.exitCode != 0)
    }

    // MARK: - Runtime Error Tests

    @Test("Division by zero returns error")
    func testDivisionByZero() throws {
        let result = InProcessTestHelper.execute("println(10 / 0)")
        #expect(!result.succeeded)
    }

    @Test("Modulo by zero returns error")
    func testModuloByZero() throws {
        let result = InProcessTestHelper.execute("println(10 % 0)")
        #expect(!result.succeeded)
    }

    @Test("Undefined variable returns error")
    func testUndefinedVariable() throws {
        let result = InProcessTestHelper.execute("println(undefinedVar)")
        #expect(!result.succeeded)
    }

    @Test("Undefined function returns error")
    func testUndefinedFunction() throws {
        let result = InProcessTestHelper.execute("println(notAFunction())")
        #expect(!result.succeeded)
    }

    @Test("Array out of bounds returns error")
    func testArrayOutOfBounds() throws {
        let code = """
        変数 arr: 配列 of 整数 ← [1, 2, 3]
        println(arr[10])
        """
        let result = InProcessTestHelper.execute(code)
        #expect(!result.succeeded)
    }

    @Test("Negative array index returns error")
    func testNegativeArrayIndex() throws {
        let code = """
        変数 arr: 配列 of 整数 ← [1, 2, 3]
        println(arr[-1])
        """
        let result = InProcessTestHelper.execute(code)
        #expect(!result.succeeded)
    }

    @Test("Wrong number of function arguments returns error")
    func testWrongArgumentCount() throws {
        let code = """
        function add(a: 整数, b: 整数): 整数
            return a + b
        endfunction
        println(add(1))
        """
        let result = InProcessTestHelper.execute(code)
        #expect(!result.succeeded)
    }

    @Test("Reassign constant returns error")
    func testReassignConstant() throws {
        let code = """
        定数 x: 整数 ← 10
        x ← 20
        """
        let result = InProcessTestHelper.execute(code)
        #expect(!result.succeeded)
    }

    // MARK: - Type Mismatch Error Tests
    // NOTE: FeLang uses dynamic typing - some operations that would fail
    // in statically typed languages may succeed or fail at runtime

    @Test("Boolean used as integer returns error")
    func testBooleanAsInteger() throws {
        let result = InProcessTestHelper.execute("println(true + 1)")
        #expect(!result.succeeded)
    }

    @Test("String used in arithmetic returns error")
    func testStringInArithmetic() throws {
        let result = InProcessTestHelper.execute("println(\"hello\" * 2)")
        #expect(!result.succeeded)
    }

    @Test("Non-integer array index returns error")
    func testNonIntegerArrayIndex() throws {
        let code = """
        変数 arr: 配列 of 整数 ← [1, 2, 3]
        println(arr["0"])
        """
        let result = InProcessTestHelper.execute(code)
        #expect(!result.succeeded)
    }

    @Test("Type reassignment causes error")
    func testTypeReassignmentError() throws {
        // FeLang enforces type checking on assignment
        let code = """
        変数 b: 論理 ← true
        b ← 42
        println(b)
        """
        let result = InProcessTestHelper.execute(code)
        // Should fail with type mismatch error
        #expect(!result.succeeded)
    }

    @Test("String to integer variable assignment causes error")
    func testStringToIntegerAssignmentError() throws {
        // FeLang enforces type checking on assignment
        let code = """
        変数 n: 整数 ← 10
        n ← "hello"
        println(n)
        """
        let result = InProcessTestHelper.execute(code)
        // Should fail with type mismatch error
        #expect(!result.succeeded)
    }

    @Test("Non-boolean condition in if causes type error")
    func testNonBooleanIfCondition() throws {
        // FeLang requires boolean type for if conditions
        let code = """
        if 42 then
            println("truthy")
        endif
        """
        let result = InProcessTestHelper.execute(code)
        // Should fail with type mismatch error
        #expect(!result.succeeded)
    }

    @Test("Non-boolean condition in while causes type error")
    func testNonBooleanWhileCondition() throws {
        let code = """
        while "yes" do
            println("loop")
        endwhile
        """
        let result = InProcessTestHelper.execute(code)
        // Should fail with type mismatch error (not infinite loop)
        #expect(!result.succeeded)
    }

    @Test("Return type mismatch causes error")
    func testReturnTypeMismatchError() throws {
        // FeLang enforces return type checking
        let code = """
        function getNumber(): 整数
            return "hello"
        endfunction
        println(getNumber())
        """
        let result = InProcessTestHelper.execute(code)
        // Should fail with type mismatch error
        #expect(!result.succeeded)
    }

    @Test("Function parameter type mismatch causes runtime error")
    func testParameterTypeMismatch() throws {
        let code = """
        function double(n: 整数): 整数
            return n * 2
        endfunction
        println(double("five"))
        """
        let result = InProcessTestHelper.execute(code)
        // Runtime error when trying to multiply string by integer
        #expect(!result.succeeded)
    }

    // MARK: - Missing Return Value Tests

    @Test("Missing return value in function causes error")
    func testMissingReturnValue() throws {
        // Function declares return type but not all paths return a value
        let code = """
        function abs1(n: 整数): 整数
            if n > 0 then
                return n
            endif
        endfunction
        println(abs1(-1))
        """
        let result = InProcessTestHelper.execute(code)
        // Should fail because function doesn't return value in all paths
        #expect(!result.succeeded)
    }
}
