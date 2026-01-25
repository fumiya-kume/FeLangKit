import Foundation
import Testing

@Suite("File Integration E2E Tests", .serialized)
struct FileIntegrationTests {

    let tempDir: URL

    init() async throws {
        try CLITestHelper.ensureBinaryBuilt()

        // Create temp directory for test files
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("felang-e2e-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
    }

    @Test("Execute file from path")
    func testExecuteFile() throws {
        let code = "println(42)"
        let filePath = tempDir.appendingPathComponent("test.fe")
        try code.write(to: filePath, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: filePath) }

        let result = try CLITestHelper.run(arguments: ["run", filePath.path])
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("42"))
    }

    @Test("Execute file with multiple lines")
    func testExecuteMultilineFile() throws {
        let code = """
        println(1)
        println(2)
        println(3)
        """
        let filePath = tempDir.appendingPathComponent("multiline.fe")
        try code.write(to: filePath, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: filePath) }

        let result = try CLITestHelper.run(arguments: ["run", filePath.path])
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("1"))
        #expect(result.stdout.contains("2"))
        #expect(result.stdout.contains("3"))
    }

    @Test("Parse file from path")
    func testParseFile() throws {
        let code = "println(42)"
        let filePath = tempDir.appendingPathComponent("parse-test.fe")
        try code.write(to: filePath, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: filePath) }

        let result = try CLITestHelper.run(arguments: ["parse", filePath.path])
        #expect(result.exitCode == 0)
        #expect(!result.stdout.isEmpty)
    }

    @Test("Tokenize file from path")
    func testTokenizeFile() throws {
        let code = "x + y"
        let filePath = tempDir.appendingPathComponent("tokenize-test.fe")
        try code.write(to: filePath, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: filePath) }

        let result = try CLITestHelper.run(arguments: ["tokenize", filePath.path])
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("x"))
    }

    @Test("Parse file with pretty flag")
    func testParseFilePretty() throws {
        let code = "println(42)"
        let filePath = tempDir.appendingPathComponent("pretty-test.fe")
        try code.write(to: filePath, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: filePath) }

        let result = try CLITestHelper.run(arguments: ["parse", "--pretty", filePath.path])
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("println"))
    }
}
