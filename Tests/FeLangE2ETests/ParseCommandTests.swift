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
