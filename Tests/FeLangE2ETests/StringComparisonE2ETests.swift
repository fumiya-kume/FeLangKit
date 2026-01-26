import FeLangRuntime
import Foundation
import Testing

@Suite("String Comparison E2E Tests", .serialized)
struct StringComparisonE2ETests {

    // MARK: - Basic Lexicographic Comparison

    @Test("String less than: \"apple\" < \"banana\" = true")
    func testStringLessThan() throws {
        let output = try InProcessTestHelper.run("println(\"apple\" < \"banana\")")
        #expect(output.lowercased().contains("true"))
    }

    @Test("String less than (false): \"banana\" < \"apple\" = false")
    func testStringLessThanFalse() throws {
        let output = try InProcessTestHelper.run("println(\"banana\" < \"apple\")")
        #expect(output.lowercased().contains("false"))
    }

    @Test("String greater than: \"banana\" > \"apple\" = true")
    func testStringGreaterThan() throws {
        let output = try InProcessTestHelper.run("println(\"banana\" > \"apple\")")
        #expect(output.lowercased().contains("true"))
    }

    @Test("String greater than (false): \"apple\" > \"banana\" = false")
    func testStringGreaterThanFalse() throws {
        let output = try InProcessTestHelper.run("println(\"apple\" > \"banana\")")
        #expect(output.lowercased().contains("false"))
    }

    // MARK: - Equality Comparison

    @Test("String equality: \"hello\" = \"hello\" = true")
    func testStringEquality() throws {
        let output = try InProcessTestHelper.run("println(\"hello\" = \"hello\")")
        #expect(output.lowercased().contains("true"))
    }

    @Test("String equality (false): \"hello\" = \"world\" = false")
    func testStringEqualityFalse() throws {
        let output = try InProcessTestHelper.run("println(\"hello\" = \"world\")")
        #expect(output.lowercased().contains("false"))
    }

    @Test("String inequality: \"hello\" ≠ \"world\" = true")
    func testStringInequality() throws {
        let output = try InProcessTestHelper.run("println(\"hello\" ≠ \"world\")")
        #expect(output.lowercased().contains("true"))
    }

    @Test("String inequality (false): \"hello\" ≠ \"hello\" = false")
    func testStringInequalityFalse() throws {
        let output = try InProcessTestHelper.run("println(\"hello\" ≠ \"hello\")")
        #expect(output.lowercased().contains("false"))
    }

    // MARK: - Less Than or Equal

    @Test("String less or equal (less): \"apple\" <= \"banana\" = true")
    func testStringLessOrEqualLess() throws {
        let output = try InProcessTestHelper.run("println(\"apple\" <= \"banana\")")
        #expect(output.lowercased().contains("true"))
    }

    @Test("String less or equal (equal): \"apple\" <= \"apple\" = true")
    func testStringLessOrEqualEqual() throws {
        let output = try InProcessTestHelper.run("println(\"apple\" <= \"apple\")")
        #expect(output.lowercased().contains("true"))
    }

    @Test("String less or equal (false): \"banana\" <= \"apple\" = false")
    func testStringLessOrEqualFalse() throws {
        let output = try InProcessTestHelper.run("println(\"banana\" <= \"apple\")")
        #expect(output.lowercased().contains("false"))
    }

    // MARK: - Greater Than or Equal

    @Test("String greater or equal (greater): \"banana\" >= \"apple\" = true")
    func testStringGreaterOrEqualGreater() throws {
        let output = try InProcessTestHelper.run("println(\"banana\" >= \"apple\")")
        #expect(output.lowercased().contains("true"))
    }

    @Test("String greater or equal (equal): \"apple\" >= \"apple\" = true")
    func testStringGreaterOrEqualEqual() throws {
        let output = try InProcessTestHelper.run("println(\"apple\" >= \"apple\")")
        #expect(output.lowercased().contains("true"))
    }

    @Test("String greater or equal (false): \"apple\" >= \"banana\" = false")
    func testStringGreaterOrEqualFalse() throws {
        let output = try InProcessTestHelper.run("println(\"apple\" >= \"banana\")")
        #expect(output.lowercased().contains("false"))
    }

    // MARK: - Edge Cases

    @Test("String comparison with empty string")
    func testEmptyStringComparison() throws {
        // Use multi-char string to avoid Character type mismatch
        let output = try InProcessTestHelper.run("println(\"\" < \"abc\")")
        #expect(output.lowercased().contains("true"))
    }

    @Test("String comparison with same prefix")
    func testSamePrefixComparison() throws {
        let output = try InProcessTestHelper.run("println(\"app\" < \"apple\")")
        #expect(output.lowercased().contains("true"))
    }

    @Test("String comparison case sensitivity")
    func testCaseSensitiveComparison() throws {
        // ASCII: 'A' (65) < 'a' (97), using multi-char strings to avoid Character type
        let output = try InProcessTestHelper.run("println(\"Apple\" < \"apple\")")
        #expect(output.lowercased().contains("true"))
    }

    // MARK: - String Comparison with Variables

    @Test("String comparison with variables")
    func testStringComparisonWithVariables() throws {
        let code = """
        変数 s1: 文字列 ← "apple"
        変数 s2: 文字列 ← "banana"
        println(s1 < s2)
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.lowercased().contains("true"))
    }

    @Test("String comparison in conditional")
    func testStringComparisonInConditional() throws {
        let code = """
        変数 fruit: 文字列 ← "apple"
        if fruit < "banana" then
            println("apple comes first")
        else
            println("banana comes first")
        endif
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.contains("apple comes first"))
    }
}
