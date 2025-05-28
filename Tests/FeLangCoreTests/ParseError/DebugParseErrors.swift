import Testing
import Foundation
@testable import FeLangCore

/// Debug test to see actual error messages for golden file generation
@Suite("Debug Parse Errors")
struct DebugParseErrors {

    @Test("Debug Actual Error Messages")
    func debugActualErrorMessages() async throws {
        let testCases = [
            ("invalid_keyword", "invalidkeyword x"),
            ("missing_then_keyword", "if x > 5\nwriteLine(x)")
        ]

        for (name, input) in testCases {
            print("\n=== Testing: \(name) ===")
            print("Input: '\(input)'")

            do {
                let tokens = try ParsingTokenizer().tokenize(input)
                let parser = StatementParser()
                let result = try parser.parseStatements(from: tokens)
                print("✅ Parsing succeeded (unexpected): \(result.count) statements")
            } catch {
                let formatted = ErrorFormatter.formatWithContext(error, input: input)
                print("❌ Error: \(formatted)")
                print("Raw error: \(error)")
            }
        }
    }
}
