import FeLangRuntime
import Foundation
import Testing

@Suite("Error Handling E2E Tests", .serialized)
struct ErrorE2ETests {

    init() async throws {
        try CLITestHelper.ensureBinaryBuilt()
    }

    // MARK: - Frontend Error Tests

    @Test("Syntax error returns error")
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
}
