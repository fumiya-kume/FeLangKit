import Foundation
import Testing

@Suite("Parse Command E2E Tests", .serialized)
struct ParseCommandTests {

    init() async throws {
        try CLITestHelper.ensureBinaryBuilt()
    }

    @Test("Parse command outputs AST")
    func testParseCommand() throws {
        let result = try CLITestHelper.run(
            arguments: ["parse", "--code", "println(42)"]
        )
        #expect(result.exitCode == 0)
        #expect(!result.stdout.isEmpty)
    }

    @Test("Parse with --pretty flag")
    func testParsePretty() throws {
        let result = try CLITestHelper.run(
            arguments: ["parse", "--pretty", "--code", "println(42)"]
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("println"))
    }

    @Test("Parse multiple statements")
    func testParseMultipleStatements() throws {
        let code = """
        println(1)
        println(2)
        """
        let result = try CLITestHelper.run(arguments: ["parse", "--code", code])
        #expect(result.exitCode == 0)
        #expect(!result.stdout.isEmpty)
    }

    @Test("Parse from stdin with '-' path")
    func testParseFromStdin() throws {
        let result = try CLITestHelper.run(
            arguments: ["parse", "-"],
            stdin: "println(1)\n"
        )
        #expect(result.exitCode == 0)
        #expect(!result.stdout.isEmpty)
    }

    @Test("Parse command reports syntax errors")
    func testParseCommandSyntaxError() throws {
        let result = try CLITestHelper.run(
            arguments: ["parse", "--code", "println("]
        )
        #expect(result.exitCode != 0)
        #expect(result.stderr.contains("Parse error:"))
    }

    @Test("Parse empty code returns success with no output")
    func testParseEmptyCode() throws {
        let result = try CLITestHelper.run(
            arguments: ["parse", "--code", ""]
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    @Test("Parse prefers --code over file argument")
    func testParsePrefersCodeOverFile() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("felang-parse-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let filePath = tempDir.appendingPathComponent("input.fe")
        try "println(2)".write(to: filePath, atomically: true, encoding: .utf8)

        let result = try CLITestHelper.run(
            arguments: ["parse", "--pretty", "--code", "println(1)", filePath.path]
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("println(1)"))
        #expect(!result.stdout.contains("println(2)"))
    }

    @Test("Tokenize command outputs tokens")
    func testTokenizeCommand() throws {
        let result = try CLITestHelper.run(
            arguments: ["tokenize", "--code", "x + y"]
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("x"))
        #expect(result.stdout.contains("y"))
    }

    @Test("Tokenize shows token positions")
    func testTokenizePositions() throws {
        let result = try CLITestHelper.run(
            arguments: ["tokenize", "--code", "abc"]
        )
        #expect(result.exitCode == 0)
        // Should contain line:column format
        #expect(result.stdout.contains("1:"))
    }

    @Test("Tokenize arithmetic expression")
    func testTokenizeArithmetic() throws {
        let result = try CLITestHelper.run(
            arguments: ["tokenize", "--code", "1 + 2 * 3"]
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("1"))
        #expect(result.stdout.contains("2"))
        #expect(result.stdout.contains("3"))
    }
}
