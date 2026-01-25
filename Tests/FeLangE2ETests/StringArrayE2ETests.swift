import FeLangRuntime
import Foundation
import Testing

@Suite("String and Array E2E Tests", .serialized)
struct StringArrayE2ETests {

    // MARK: - Unicode String Handling

    @Test("charAt with Japanese characters")
    func testCharAtUnicode() throws {
        let output = try InProcessTestHelper.run("println(charAt(\"こんにちは\", 0))")
        #expect(output.contains("こ"))
    }

    @Test("charAt with second Japanese character")
    func testCharAtUnicodeSecond() throws {
        let output = try InProcessTestHelper.run("println(charAt(\"こんにちは\", 1))")
        #expect(output.contains("ん"))
    }

    @Test("length with Japanese string")
    func testLengthUnicode() throws {
        let output = try InProcessTestHelper.run("println(length(\"こんにちは\"))")
        #expect(output.contains("5"))
    }

    @Test("length with accented characters")
    func testLengthAccented() throws {
        let output = try InProcessTestHelper.run("println(length(\"café\"))")
        #expect(output.contains("4"))
    }

    @Test("substring with Unicode")
    func testSubstringUnicode() throws {
        let output = try InProcessTestHelper.run("println(substring(\"こんにちは\", 0, 3))")
        #expect(output.contains("こんに"))
    }

    // MARK: - Empty Collection Handling

    @Test("Empty string length is 0")
    func testEmptyStringLength() throws {
        let output = try InProcessTestHelper.run("println(length(\"\"))")
        #expect(output.trimmingCharacters(in: .whitespacesAndNewlines) == "0")
    }

    @Test("charAt on empty string should error")
    func testCharAtEmptyString() throws {
        let result = InProcessTestHelper.execute("println(charAt(\"\", 0))")
        #expect(!result.succeeded)
    }

    @Test("substring on empty string")
    func testSubstringEmpty() throws {
        let result = InProcessTestHelper.execute("println(substring(\"\", 0, 0))")
        #expect(result.succeeded)
    }

    @Test("Empty array creation")
    func testEmptyArrayCreation() throws {
        let code = """
        変数 arr: 配列 of 整数 ← []
        println(arrayLength(arr))
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.trimmingCharacters(in: .whitespacesAndNewlines) == "0")
    }

    @Test("Access empty array should error")
    func testAccessEmptyArray() throws {
        let code = """
        変数 arr: 配列 of 整数 ← []
        println(arr[0])
        """
        let result = InProcessTestHelper.execute(code)
        #expect(!result.succeeded)
    }

    // MARK: - Standard Library: Math Functions

    @Test("abs with negative real")
    func testAbsNegativeReal() throws {
        let output = try InProcessTestHelper.run("println(abs(-3.14))")
        #expect(output.contains("3.14"))
    }

    @Test("abs with negative integer")
    func testAbsNegativeInteger() throws {
        let output = try InProcessTestHelper.run("println(abs(-42))")
        #expect(output.contains("42"))
    }

    @Test("ceil function")
    func testCeil() throws {
        let output = try InProcessTestHelper.run("println(ceil(3.2))")
        #expect(output.contains("4"))
    }

    @Test("floor function")
    func testFloor() throws {
        let output = try InProcessTestHelper.run("println(floor(3.8))")
        #expect(output.contains("3"))
    }

    @Test("round function - round up")
    func testRoundUp() throws {
        let output = try InProcessTestHelper.run("println(round(3.6))")
        #expect(output.contains("4"))
    }

    @Test("round function - round down")
    func testRoundDown() throws {
        let output = try InProcessTestHelper.run("println(round(3.4))")
        #expect(output.contains("3"))
    }

    @Test("min function")
    func testMin() throws {
        let output = try InProcessTestHelper.run("println(min(5, 3))")
        #expect(output.contains("3"))
    }

    @Test("max function")
    func testMax() throws {
        let output = try InProcessTestHelper.run("println(max(5, 3))")
        #expect(output.contains("5"))
    }

    // MARK: - Standard Library: String Functions

    @Test("upper function")
    func testUpper() throws {
        let output = try InProcessTestHelper.run("println(upper(\"hello\"))")
        #expect(output.contains("HELLO"))
    }

    @Test("lower function")
    func testLower() throws {
        let output = try InProcessTestHelper.run("println(lower(\"WORLD\"))")
        #expect(output.contains("world"))
    }

    @Test("trim function")
    func testTrim() throws {
        let output = try InProcessTestHelper.run("println(trim(\"  hello  \"))")
        #expect(output.trimmingCharacters(in: .whitespacesAndNewlines) == "hello")
    }

    @Test("concat function")
    func testConcat() throws {
        let output = try InProcessTestHelper.run("println(concat(\"a\", \"b\", \"c\"))")
        #expect(output.contains("abc"))
    }

    // MARK: - Standard Library: Array Functions

    @Test("append to array")
    func testAppend() throws {
        let code = """
        変数 arr: 配列 of 整数 ← [1, 2]
        arr ← append(arr, 3)
        println(arr[2])
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.contains("3"))
    }

    @Test("prepend to array")
    func testPrepend() throws {
        let code = """
        変数 arr: 配列 of 整数 ← [2, 3]
        arr ← prepend(arr, 1)
        println(arr[0])
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.contains("1"))
    }

    @Test("concat_arrays function")
    func testConcatArrays() throws {
        let code = """
        変数 a: 配列 of 整数 ← [1, 2]
        変数 b: 配列 of 整数 ← [3, 4]
        変数 c: 配列 of 整数 ← concat_arrays(a, b)
        println(arrayLength(c))
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.contains("4"))
    }

    @Test("concat empty arrays")
    func testConcatEmptyArrays() throws {
        let code = """
        変数 a: 配列 of 整数 ← []
        変数 b: 配列 of 整数 ← []
        変数 c: 配列 of 整数 ← concat_arrays(a, b)
        println(arrayLength(c))
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.trimmingCharacters(in: .whitespacesAndNewlines) == "0")
    }

    // MARK: - String Edge Cases

    @Test("String with escape sequences")
    func testStringEscapeSequences() throws {
        let output = try InProcessTestHelper.run("println(\"Hello\\nWorld\")")
        #expect(output.contains("Hello"))
        #expect(output.contains("World"))
    }

    @Test("String with tab character")
    func testStringTabEscape() throws {
        let output = try InProcessTestHelper.run("println(\"A\\tB\")")
        #expect(output.contains("A"))
        #expect(output.contains("B"))
    }

    // MARK: - Array Element Assignment

    @Test("Array element assignment works correctly")
    func testArrayElementAssignment() throws {
        let code = """
        変数 arr: 配列 of 整数 ← [1, 2, 3]
        arr[0] ← 10
        println(arr[0])
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.trimmingCharacters(in: .whitespacesAndNewlines) == "10")
    }

    @Test("Array element assignment with expression index")
    func testArrayElementAssignmentWithExpressionIndex() throws {
        let code = """
        変数 arr: 配列 of 整数 ← [1, 2, 3]
        変数 i: 整数 ← 1
        arr[i] ← 20
        println(arr[1])
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.trimmingCharacters(in: .whitespacesAndNewlines) == "20")
    }

    @Test("Array element assignment out of bounds error")
    func testArrayElementAssignmentOutOfBounds() throws {
        let code = """
        変数 arr: 配列 of 整数 ← [1, 2, 3]
        arr[10] ← 99
        """
        let result = InProcessTestHelper.execute(code)
        // Should fail with runtime error (index out of bounds)
        #expect(!result.succeeded)
    }

    @Test("Multiple array element assignments")
    func testMultipleArrayElementAssignments() throws {
        let code = """
        変数 arr: 配列 of 整数 ← [0, 0, 0]
        arr[0] ← 1
        arr[1] ← 2
        arr[2] ← 3
        println(arr[0] + arr[1] + arr[2])
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.trimmingCharacters(in: .whitespacesAndNewlines) == "6")
    }

    // MARK: - Character Type Tests

    @Test("Character literal assignment")
    func testCharacterLiteral() throws {
        let code = """
        変数 ch: 文字 ← 'A'
        println(ch)
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.contains("A"))
    }

    @Test("Character comparison equality")
    func testCharacterComparison() throws {
        let code = """
        変数 ch1: 文字 ← 'A'
        変数 ch2: 文字 ← 'A'
        println(ch1 = ch2)
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.lowercased().contains("true"))
    }

    @Test("Character comparison inequality")
    func testCharacterComparisonInequality() throws {
        let code = """
        変数 ch1: 文字 ← 'A'
        変数 ch2: 文字 ← 'B'
        println(ch1 ≠ ch2)
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.lowercased().contains("true"))
    }

    @Test("charAt returns character type")
    func testCharAtReturnsCharacter() throws {
        let code = """
        変数 str: 文字列 ← "Hello"
        変数 ch: 文字 ← charAt(str, 0)
        println(ch)
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.contains("H"))
    }
}
