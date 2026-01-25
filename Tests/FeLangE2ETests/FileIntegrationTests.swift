import Foundation
import Testing

@Suite("File Integration E2E Tests", .serialized)
struct FileIntegrationTests {

    init() throws {
        try CLITestHelper.ensureBinaryBuilt()
    }

    private func withTempDir<T>(_ body: (URL) throws -> T) throws -> T {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("felang-e2e-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tempDir) }
        return try body(tempDir)
    }

    @Test("Execute file from path")
    func testExecuteFile() throws {
        try withTempDir { tempDir in
            let code = "println(42)"
            let filePath = tempDir.appendingPathComponent("test.fe")
            try code.write(to: filePath, atomically: true, encoding: .utf8)

            let result = try CLITestHelper.run(arguments: ["run", filePath.path])
            #expect(result.exitCode == 0)
            #expect(result.stdout.contains("42"))
        }
    }

    @Test("Execute file with multiple lines")
    func testExecuteMultilineFile() throws {
        try withTempDir { tempDir in
            let code = """
            println(1)
            println(2)
            println(3)
            """
            let filePath = tempDir.appendingPathComponent("multiline.fe")
            try code.write(to: filePath, atomically: true, encoding: .utf8)

            let result = try CLITestHelper.run(arguments: ["run", filePath.path])
            #expect(result.exitCode == 0)
            #expect(result.stdout.contains("1"))
            #expect(result.stdout.contains("2"))
            #expect(result.stdout.contains("3"))
        }
    }

    @Test("Parse file from path")
    func testParseFile() throws {
        try withTempDir { tempDir in
            let code = "println(42)"
            let filePath = tempDir.appendingPathComponent("parse-test.fe")
            try code.write(to: filePath, atomically: true, encoding: .utf8)

            let result = try CLITestHelper.run(arguments: ["parse", filePath.path])
            #expect(result.exitCode == 0)
            #expect(!result.stdout.isEmpty)
        }
    }

    @Test("Tokenize file from path")
    func testTokenizeFile() throws {
        try withTempDir { tempDir in
            let code = "x + y"
            let filePath = tempDir.appendingPathComponent("tokenize-test.fe")
            try code.write(to: filePath, atomically: true, encoding: .utf8)

            let result = try CLITestHelper.run(arguments: ["tokenize", filePath.path])
            #expect(result.exitCode == 0)
            #expect(result.stdout.contains("x"))
        }
    }

    @Test("Parse file with pretty flag")
    func testParseFilePretty() throws {
        try withTempDir { tempDir in
            let code = "println(42)"
            let filePath = tempDir.appendingPathComponent("pretty-test.fe")
            try code.write(to: filePath, atomically: true, encoding: .utf8)

            let result = try CLITestHelper.run(arguments: ["parse", "--pretty", filePath.path])
            #expect(result.exitCode == 0)
            #expect(result.stdout.contains("println"))
        }
    }
}
