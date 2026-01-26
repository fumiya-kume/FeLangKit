import FeLangRuntime
import Foundation
import Testing

@Suite("Type Conversion E2E Tests", .serialized)
struct TypeConversionE2ETests {

    // MARK: - toInteger Tests

    @Test("toInteger from string")
    func testToIntegerFromString() throws {
        let output = try InProcessTestHelper.run("println(toInteger(\"42\"))")
        #expect(output.contains("42"))
    }

    @Test("toInteger from real number")
    func testToIntegerFromReal() throws {
        let output = try InProcessTestHelper.run("println(toInteger(3.14))")
        #expect(output.contains("3"))
    }

    @Test("toInteger from negative real")
    func testToIntegerFromNegativeReal() throws {
        let output = try InProcessTestHelper.run("println(toInteger(-3.7))")
        // Should truncate toward zero
        #expect(output.contains("-3"))
    }

    @Test("toInteger from zero")
    func testToIntegerFromZero() throws {
        let output = try InProcessTestHelper.run("println(toInteger(0.0))")
        #expect(output.contains("0"))
    }

    // MARK: - toReal Tests

    @Test("toReal from string")
    func testToRealFromString() throws {
        let output = try InProcessTestHelper.run("println(toReal(\"3.14\"))")
        #expect(output.contains("3.14"))
    }

    @Test("toReal from integer")
    func testToRealFromInteger() throws {
        let output = try InProcessTestHelper.run("println(toReal(42))")
        #expect(output.contains("42"))
    }

    @Test("toReal from negative integer")
    func testToRealFromNegativeInteger() throws {
        let output = try InProcessTestHelper.run("println(toReal(-10))")
        #expect(output.contains("-10"))
    }

    @Test("toReal from integer string")
    func testToRealFromIntegerString() throws {
        let output = try InProcessTestHelper.run("println(toReal(\"100\"))")
        #expect(output.contains("100"))
    }

    // MARK: - toString Tests

    @Test("toString from integer")
    func testToStringFromInteger() throws {
        let output = try InProcessTestHelper.run("println(toString(123))")
        #expect(output.contains("123"))
    }

    @Test("toString from negative integer")
    func testToStringFromNegativeInteger() throws {
        let output = try InProcessTestHelper.run("println(toString(-456))")
        #expect(output.contains("-456"))
    }

    @Test("toString from real")
    func testToStringFromReal() throws {
        let output = try InProcessTestHelper.run("println(toString(3.14))")
        #expect(output.contains("3.14"))
    }

    @Test("toString from boolean true")
    func testToStringFromBooleanTrue() throws {
        let output = try InProcessTestHelper.run("println(toString(true))")
        #expect(output.lowercased().contains("true"))
    }

    @Test("toString from boolean false")
    func testToStringFromBooleanFalse() throws {
        let output = try InProcessTestHelper.run("println(toString(false))")
        #expect(output.lowercased().contains("false"))
    }

    // MARK: - Chained Conversions

    @Test("chained conversion: toString(toInteger(x))")
    func testChainedConversion() throws {
        let output = try InProcessTestHelper.run("println(toString(toInteger(3.7)))")
        #expect(output.contains("3"))
    }

    @Test("conversion in expression")
    func testConversionInExpression() throws {
        let output = try InProcessTestHelper.run("println(toInteger(\"10\") + 5)")
        #expect(output.contains("15"))
    }

    @Test("toString with concat")
    func testToStringWithConcat() throws {
        let output = try InProcessTestHelper.run("println(concat(\"Value: \", toString(42)))")
        #expect(output.contains("Value: 42"))
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
