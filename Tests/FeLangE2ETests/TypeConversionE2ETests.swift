import FeLangRuntime
import Foundation
import Testing

@Suite("Type Conversion E2E Tests", .serialized)
struct TypeConversionE2ETests {

    @Test("Builtin conversions smoke")
    func testBuiltinConversionsSmoke() throws {
        let code = """
        println(toInteger("42"))
        println(toReal("3.14"))
        println(toString(true))
        println(toString(toInteger(3.7)))
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.contains("42"))
        #expect(output.contains("3.14"))
        #expect(output.lowercased().contains("true"))
        #expect(output.contains("3"))
    }

    // MARK: - English Type Alias Tests

    @Test("English type aliases: double/float/str/char/bool")
    func testEnglishTypeAliasesDoubleFloatStr() throws {
        let code = """
        変数 r: double ← 1.5
        変数 f: float ← 2.5
        変数 s: str ← "ok"
        変数 c: char ← 'A'
        変数 b: bool ← true
        println(r + f)
        println(s)
        println(c)
        println(b)
        """
        let output = try InProcessTestHelper.run(code)
        let lines = output
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        #expect(lines.count >= 4, "Expected 4 output lines, got \(lines.count): \(lines)")
        guard lines.count >= 4 else { return }
        #expect(lines[0] == "4" || lines[0] == "4.0")
        #expect(lines[1] == "ok")
        #expect(lines[2] == "A")
        #expect(lines[3].lowercased() == "true")
    }

    @Test("English type aliases in function declaration")
    func testEnglishTypeAliasesInFunction() throws {
        let code = """
        function describe(x: int, ok: bool): string
            if ok then
                return toString(x)
            endif
            return "no"
        endfunction

        println(describe(3, true))
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.contains("3"))
    }

    // MARK: - Japanese Type Keywords Tests

    @Test("Japanese type keywords (整数型/実数型/文字列型/文字型/論理型)")
    func testJapaneseTypeKeywords() throws {
        let code = """
        変数 i: 整数型 ← 1
        変数 r: 実数型 ← 1.5
        変数 s: 文字列型 ← "ok"
        変数 c: 文字型 ← 'A'
        変数 b: 論理型 ← true
        println(i)
        println(r)
        println(s)
        println(c)
        println(b)
        """
        let output = try InProcessTestHelper.run(code)
        let lines = output.split(separator: "\n").map {
            String($0).trimmingCharacters(in: .whitespaces)
        }
        #expect(lines.count >= 5, "Expected 5 output lines, got \(lines.count): \(lines)")
        guard lines.count >= 5 else { return }
        #expect(lines[0] == "1")
        #expect(lines[1] == "1.5")
        #expect(lines[2] == "ok")
        #expect(lines[3] == "A")
        #expect(lines[4].lowercased() == "true")
    }
}
