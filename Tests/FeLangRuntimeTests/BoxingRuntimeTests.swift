@testable import FeLangRuntime
import FeLangCore
import Foundation
import Testing

struct BoxingRuntimeTests {

    // MARK: - Thread-safe output capture

    private final class OutputCapture: @unchecked Sendable {
        private var _output = ""
        private let lock = NSLock()

        func append(_ text: String) {
            lock.lock()
            _output += text
            lock.unlock()
        }

        var output: String {
            lock.lock()
            defer { lock.unlock() }
            return _output
        }
    }

    // MARK: - Boxed RuntimeValue Tests

    @Test func testBoxedValueTypeName() {
        let boxed = RuntimeValue.boxed(typeTag: 0, value: .integer(42))
        #expect(boxed.typeName == "Boxed<Integer>")
    }

    @Test func testBoxedValueToString() {
        let boxed = RuntimeValue.boxed(typeTag: 0, value: .integer(42))
        #expect(boxed.toString() == "boxed(tag=0, 42)")
    }

    @Test func testBoxedValueIsTruthy() {
        let boxedTrue = RuntimeValue.boxed(typeTag: 4, value: .boolean(true))
        let boxedFalse = RuntimeValue.boxed(typeTag: 4, value: .boolean(false))
        let boxedNull = RuntimeValue.boxed(typeTag: 8, value: .null)

        #expect(boxedTrue.isTruthy == true)
        #expect(boxedFalse.isTruthy == false)
        #expect(boxedNull.isTruthy == false)
    }

    @Test func testBoxedValueToInteger() {
        let boxed = RuntimeValue.boxed(typeTag: 0, value: .integer(42))
        #expect(boxed.toInteger() == 42)
    }

    @Test func testBoxedValueToReal() {
        let boxed = RuntimeValue.boxed(typeTag: 1, value: .real(3.14))
        #expect(boxed.toReal() == 3.14)
    }

    @Test func testBoxedValueEquality() {
        let boxed1 = RuntimeValue.boxed(typeTag: 0, value: .integer(42))
        let boxed2 = RuntimeValue.boxed(typeTag: 0, value: .integer(42))
        let boxed3 = RuntimeValue.boxed(typeTag: 0, value: .integer(99))

        #expect(boxed1 == boxed2)
        #expect(boxed1 != boxed3)
    }

    @Test func testBoxedStringValue() {
        let boxed = RuntimeValue.boxed(typeTag: 2, value: .string("hello"))
        #expect(boxed.typeName == "Boxed<String>")
        #expect(boxed.toString() == "boxed(tag=2, hello)")
    }

    @Test func testBoxedBooleanValue() {
        let boxed = RuntimeValue.boxed(typeTag: 4, value: .boolean(true))
        #expect(boxed.typeName == "Boxed<Boolean>")
        #expect(boxed.isTruthy == true)
    }

    // MARK: - kk_println_any Tests

    @Test func testKkPrintlnAnyWithInteger() throws {
        let capture = OutputCapture()
        let stdlib = StandardLibrary(
            printHandler: { capture.append($0) },
            inputHandler: { nil }
        )
        _ = try stdlib.functions["kk_println_any"]?([.integer(42)])
        #expect(capture.output == "42\n")
    }

    @Test func testKkPrintlnAnyWithString() throws {
        let capture = OutputCapture()
        let stdlib = StandardLibrary(
            printHandler: { capture.append($0) },
            inputHandler: { nil }
        )
        _ = try stdlib.functions["kk_println_any"]?([.string("hello")])
        #expect(capture.output == "hello\n")
    }

    @Test func testKkPrintlnAnyWithNull() throws {
        let capture = OutputCapture()
        let stdlib = StandardLibrary(
            printHandler: { capture.append($0) },
            inputHandler: { nil }
        )
        _ = try stdlib.functions["kk_println_any"]?([.null])
        #expect(capture.output == "null\n")
    }

    @Test func testKkPrintlnAnyWithBoxedValue() throws {
        let capture = OutputCapture()
        let stdlib = StandardLibrary(
            printHandler: { capture.append($0) },
            inputHandler: { nil }
        )
        _ = try stdlib.functions["kk_println_any"]?([.boxed(typeTag: 0, value: .integer(42))])
        #expect(capture.output == "Any(tag=0, 42)\n")
    }

    @Test func testKkPrintlnAnyWithBoolean() throws {
        let capture = OutputCapture()
        let stdlib = StandardLibrary(
            printHandler: { capture.append($0) },
            inputHandler: { nil }
        )
        _ = try stdlib.functions["kk_println_any"]?([.boolean(true)])
        #expect(capture.output == "true\n")
    }

    @Test func testKkPrintlnAnyWithReal() throws {
        let capture = OutputCapture()
        let stdlib = StandardLibrary(
            printHandler: { capture.append($0) },
            inputHandler: { nil }
        )
        _ = try stdlib.functions["kk_println_any"]?([.real(3.14)])
        #expect(capture.output == "3.14\n")
    }

    @Test func testKkPrintlnAnyNoArgs() {
        let stdlib = StandardLibrary(
            printHandler: { _ in },
            inputHandler: { nil }
        )
        #expect(throws: RuntimeError.self) {
            _ = try stdlib.functions["kk_println_any"]?([])
        }
    }

    // MARK: - Nullable Default Value Tests

    @Test func testNullableDefaultValueExecution() throws {
        let env = Environment()
        let executor = StatementExecutor(environment: env)

        _ = try executor.execute([
            .variableDeclaration(VariableDeclaration(
                name: "x",
                type: .nullable(.integer),
                initialValue: nil
            ))
        ])

        let value = env.lookup("x")
        #expect(value == .null)
    }

    @Test func testAnyDefaultValueExecution() throws {
        let env = Environment()
        let executor = StatementExecutor(environment: env)

        _ = try executor.execute([
            .variableDeclaration(VariableDeclaration(
                name: "x",
                type: .any,
                initialValue: nil
            ))
        ])

        let value = env.lookup("x")
        #expect(value == .null)
    }
}
