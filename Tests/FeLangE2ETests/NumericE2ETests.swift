import FeLangRuntime
import Foundation
import Testing

@Suite("Numeric E2E Tests", .serialized)
struct NumericE2ETests {
    @Test("Numeric smoke test")
    func testNumericSmoke() throws {
        let code = """
        println(-5 + 3)
        println(-(5 + 3))
        println(--5)
        println(-17 % 5)
        println(pow(2.0, 10.0))
        println(sqrt(16))
        """
        let output = try InProcessTestHelper.run(code)
        let lines = output
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        #expect(lines.count >= 6, "Expected 6 output lines, got \(lines.count): \(lines)")
        guard lines.count >= 6 else { return }
        #expect(lines[0] == "-2")
        #expect(lines[1] == "-8")
        #expect(lines[2] == "5")
        #expect(lines[3] == "-2")
        #expect(lines[4].contains("1024"))
        #expect(lines[5] == "4" || lines[5] == "4.0")
    }
}
