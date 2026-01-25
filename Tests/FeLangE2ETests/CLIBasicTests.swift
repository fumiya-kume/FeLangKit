import Foundation
import Testing

@Suite("CLI Basic Tests", .serialized)
struct CLIBasicTests {

    init() async throws {
        try CLITestHelper.ensureBinaryBuilt()
    }

    @Test("--version flag shows version")
    func testVersionFlag() throws {
        let result = try CLITestHelper.run(arguments: ["--version"])
        #expect(result.exitCode == 0)
        #expect(result.stdout.range(of: #"\d+\.\d+\.\d+"#, options: .regularExpression) != nil)
    }

    @Test("--help flag shows usage")
    func testHelpFlag() throws {
        let result = try CLITestHelper.run(arguments: ["--help"])
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("USAGE"))
        #expect(result.stdout.contains("felang"))
    }

    @Test("run --help shows run command help")
    func testRunHelpFlag() throws {
        let result = try CLITestHelper.run(arguments: ["run", "--help"])
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("Execute"))
    }

    @Test("parse --help shows parse command help")
    func testParseHelpFlag() throws {
        let result = try CLITestHelper.run(arguments: ["parse", "--help"])
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("AST"))
    }

    @Test("tokenize --help shows tokenize command help")
    func testTokenizeHelpFlag() throws {
        let result = try CLITestHelper.run(arguments: ["tokenize", "--help"])
        #expect(result.exitCode == 0)
        #expect(result.stdout.lowercased().contains("token"))
    }

    @Test("repl --help shows repl command help")
    func testReplHelpFlag() throws {
        let result = try CLITestHelper.run(arguments: ["repl", "--help"])
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("REPL"))
    }
}
