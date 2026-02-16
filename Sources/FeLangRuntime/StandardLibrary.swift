import Foundation

/// Standard library functions for the FE interpreter.
public struct StandardLibrary: Sendable {
    /// Output handler for print operations
    public let printHandler: @Sendable (String) -> Void

    /// Input handler for input operations
    public let inputHandler: @Sendable () -> String?

    // MARK: - Initialization

    public init(
        printHandler: @escaping @Sendable (String) -> Void = { print($0, terminator: "") },
        inputHandler: @escaping @Sendable () -> String? = { readLine() }
    ) {
        self.printHandler = printHandler
        self.inputHandler = inputHandler
    }

    // MARK: - Function Registration

    /// Returns all standard library functions
    public var functions: [String: @Sendable ([RuntimeValue]) throws -> RuntimeValue] {
        [
            // I/O Functions
            "print": stdPrint,
            "println": stdPrintln,
            "input": stdInput,

            // Type Conversion
            "toString": stdToString,
            "toInteger": stdToInteger,
            "toReal": stdToReal,

            // Math Functions
            "abs": stdAbs,
            "sqrt": stdSqrt,
            "floor": stdFloor,
            "ceil": stdCeil,
            "round": stdRound,
            "min": stdMin,
            "max": stdMax,
            "pow": stdPow,

            // String Functions
            "length": stdLength,
            "substring": stdSubstring,
            "charAt": stdCharAt,
            "concat": stdConcat,
            "upper": stdUpper,
            "lower": stdLower,
            "trim": stdTrim,

            // Array Functions
            "arrayLength": stdArrayLength,
            "append": stdAppend,
            "prepend": stdPrepend,
            "concat_arrays": stdConcatArrays,

            // Boxing/ABI Functions
            "kk_println_any": stdKkPrintlnAny
        ]
    }

    // MARK: - I/O Functions

    private func stdPrint(_ args: [RuntimeValue]) throws -> RuntimeValue {
        let output = args.map { $0.toString() }.joined()
        printHandler(output)
        return .null
    }

    private func stdPrintln(_ args: [RuntimeValue]) throws -> RuntimeValue {
        let output = args.map { $0.toString() }.joined()
        printHandler(output + "\n")
        return .null
    }

    private func stdInput(_ args: [RuntimeValue]) throws -> RuntimeValue {
        if let prompt = args.first {
            printHandler(prompt.toString())
        }
        return .string(inputHandler() ?? "")
    }

    // MARK: - Type Conversion Functions

    private func stdToString(_ args: [RuntimeValue]) throws -> RuntimeValue {
        guard let value = args.first else {
            throw RuntimeError.wrongArgumentCount(function: "toString", expected: 1, actual: 0)
        }
        return .string(value.toString())
    }

    private func stdToInteger(_ args: [RuntimeValue]) throws -> RuntimeValue {
        guard let value = args.first else {
            throw RuntimeError.wrongArgumentCount(function: "toInteger", expected: 1, actual: 0)
        }
        guard let intValue = value.toInteger() else {
            throw RuntimeError.typeMismatch(
                expected: "convertible to integer",
                actual: value.typeName,
                operation: "toInteger"
            )
        }
        return .integer(intValue)
    }

    private func stdToReal(_ args: [RuntimeValue]) throws -> RuntimeValue {
        guard let value = args.first else {
            throw RuntimeError.wrongArgumentCount(function: "toReal", expected: 1, actual: 0)
        }
        guard let realValue = value.toReal() else {
            throw RuntimeError.typeMismatch(
                expected: "convertible to real",
                actual: value.typeName,
                operation: "toReal"
            )
        }
        return .real(realValue)
    }

    // MARK: - Math Functions

    private func stdAbs(_ args: [RuntimeValue]) throws -> RuntimeValue {
        guard let value = args.first else {
            throw RuntimeError.wrongArgumentCount(function: "abs", expected: 1, actual: 0)
        }
        switch value {
        case .integer(let num):
            return .integer(abs(num))
        case .real(let num):
            return .real(abs(num))
        default:
            throw RuntimeError.typeMismatch(
                expected: "numeric",
                actual: value.typeName,
                operation: "abs"
            )
        }
    }

    private func stdSqrt(_ args: [RuntimeValue]) throws -> RuntimeValue {
        guard let value = args.first else {
            throw RuntimeError.wrongArgumentCount(function: "sqrt", expected: 1, actual: 0)
        }
        guard let realValue = value.toReal() else {
            throw RuntimeError.typeMismatch(
                expected: "numeric",
                actual: value.typeName,
                operation: "sqrt"
            )
        }
        return .real(sqrt(realValue))
    }

    private func stdFloor(_ args: [RuntimeValue]) throws -> RuntimeValue {
        guard let value = args.first else {
            throw RuntimeError.wrongArgumentCount(function: "floor", expected: 1, actual: 0)
        }
        guard let realValue = value.toReal() else {
            throw RuntimeError.typeMismatch(
                expected: "numeric",
                actual: value.typeName,
                operation: "floor"
            )
        }
        return .integer(Int(floor(realValue)))
    }

    private func stdCeil(_ args: [RuntimeValue]) throws -> RuntimeValue {
        guard let value = args.first else {
            throw RuntimeError.wrongArgumentCount(function: "ceil", expected: 1, actual: 0)
        }
        guard let realValue = value.toReal() else {
            throw RuntimeError.typeMismatch(
                expected: "numeric",
                actual: value.typeName,
                operation: "ceil"
            )
        }
        return .integer(Int(ceil(realValue)))
    }

    private func stdRound(_ args: [RuntimeValue]) throws -> RuntimeValue {
        guard let value = args.first else {
            throw RuntimeError.wrongArgumentCount(function: "round", expected: 1, actual: 0)
        }
        guard let realValue = value.toReal() else {
            throw RuntimeError.typeMismatch(
                expected: "numeric",
                actual: value.typeName,
                operation: "round"
            )
        }
        return .integer(Int(realValue.rounded()))
    }

    private func stdMin(_ args: [RuntimeValue]) throws -> RuntimeValue {
        guard args.count >= 2 else {
            throw RuntimeError.wrongArgumentCount(function: "min", expected: 2, actual: args.count)
        }

        var minValue = args[0]
        for arg in args.dropFirst() {
            guard let result = compare(arg, minValue) else {
                throw RuntimeError.typeMismatch(
                    expected: "numeric",
                    actual: "\(arg.typeName) and \(minValue.typeName)",
                    operation: "min"
                )
            }
            if result < 0 {
                minValue = arg
            }
        }
        return minValue
    }

    private func stdMax(_ args: [RuntimeValue]) throws -> RuntimeValue {
        guard args.count >= 2 else {
            throw RuntimeError.wrongArgumentCount(function: "max", expected: 2, actual: args.count)
        }

        var maxValue = args[0]
        for arg in args.dropFirst() {
            guard let result = compare(arg, maxValue) else {
                throw RuntimeError.typeMismatch(
                    expected: "numeric",
                    actual: "\(arg.typeName) and \(maxValue.typeName)",
                    operation: "max"
                )
            }
            if result > 0 {
                maxValue = arg
            }
        }
        return maxValue
    }

    private func stdPow(_ args: [RuntimeValue]) throws -> RuntimeValue {
        guard args.count == 2 else {
            throw RuntimeError.wrongArgumentCount(function: "pow", expected: 2, actual: args.count)
        }
        guard let base = args[0].toReal(), let exponent = args[1].toReal() else {
            throw RuntimeError.typeMismatch(
                expected: "numeric",
                actual: "\(args[0].typeName) and \(args[1].typeName)",
                operation: "pow"
            )
        }
        return .real(pow(base, exponent))
    }

    private func compare(_ lhs: RuntimeValue, _ rhs: RuntimeValue) -> Int? {
        switch (lhs, rhs) {
        case (.integer(let left), .integer(let right)):
            return left < right ? -1 : (left > right ? 1 : 0)
        case (.real(let left), .real(let right)):
            return left < right ? -1 : (left > right ? 1 : 0)
        case (.integer(let left), .real(let right)):
            return Double(left) < right ? -1 : (Double(left) > right ? 1 : 0)
        case (.real(let left), .integer(let right)):
            return left < Double(right) ? -1 : (left > Double(right) ? 1 : 0)
        default:
            return nil
        }
    }

    // MARK: - String Functions

    private func stdLength(_ args: [RuntimeValue]) throws -> RuntimeValue {
        guard let value = args.first else {
            throw RuntimeError.wrongArgumentCount(function: "length", expected: 1, actual: 0)
        }
        switch value {
        case .string(let str):
            return .integer(str.count)
        case .array(let arr):
            return .integer(arr.count)
        default:
            throw RuntimeError.typeMismatch(
                expected: "string or array",
                actual: value.typeName,
                operation: "length"
            )
        }
    }

    private func stdSubstring(_ args: [RuntimeValue]) throws -> RuntimeValue {
        guard args.count >= 2 else {
            throw RuntimeError.wrongArgumentCount(function: "substring", expected: 2, actual: args.count)
        }
        guard case .string(let str) = args[0],
              case .integer(let start) = args[1] else {
            throw RuntimeError.typeMismatch(
                expected: "string and integer",
                actual: "\(args[0].typeName) and \(args[1].typeName)",
                operation: "substring"
            )
        }

        let end: Int
        if args.count >= 3 {
            guard case .integer(let endIndex) = args[2] else {
                throw RuntimeError.typeMismatch(
                    expected: "integer",
                    actual: args[2].typeName,
                    operation: "substring end index"
                )
            }
            end = endIndex
        } else {
            end = str.count
        }

        guard start >= 0, start <= str.count, end >= start, end <= str.count else {
            throw RuntimeError.indexOutOfBounds(index: start, size: str.count)
        }

        let startIndex = str.index(str.startIndex, offsetBy: start)
        let endIndex = str.index(str.startIndex, offsetBy: end)
        return .string(String(str[startIndex..<endIndex]))
    }

    private func stdCharAt(_ args: [RuntimeValue]) throws -> RuntimeValue {
        guard args.count == 2 else {
            throw RuntimeError.wrongArgumentCount(function: "charAt", expected: 2, actual: args.count)
        }
        guard case .string(let str) = args[0],
              case .integer(let index) = args[1] else {
            throw RuntimeError.typeMismatch(
                expected: "string and integer",
                actual: "\(args[0].typeName) and \(args[1].typeName)",
                operation: "charAt"
            )
        }

        guard index >= 0, index < str.count else {
            throw RuntimeError.indexOutOfBounds(index: index, size: str.count)
        }

        let charIndex = str.index(str.startIndex, offsetBy: index)
        return .character(str[charIndex])
    }

    private func stdConcat(_ args: [RuntimeValue]) throws -> RuntimeValue {
        .string(args.map { $0.toString() }.joined())
    }

    private func stdUpper(_ args: [RuntimeValue]) throws -> RuntimeValue {
        guard let value = args.first, case .string(let str) = value else {
            throw RuntimeError.typeMismatch(
                expected: "string",
                actual: args.first?.typeName ?? "none",
                operation: "upper"
            )
        }
        return .string(str.uppercased())
    }

    private func stdLower(_ args: [RuntimeValue]) throws -> RuntimeValue {
        guard let value = args.first, case .string(let str) = value else {
            throw RuntimeError.typeMismatch(
                expected: "string",
                actual: args.first?.typeName ?? "none",
                operation: "lower"
            )
        }
        return .string(str.lowercased())
    }

    private func stdTrim(_ args: [RuntimeValue]) throws -> RuntimeValue {
        guard let value = args.first, case .string(let str) = value else {
            throw RuntimeError.typeMismatch(
                expected: "string",
                actual: args.first?.typeName ?? "none",
                operation: "trim"
            )
        }
        return .string(str.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    // MARK: - Array Functions

    private func stdArrayLength(_ args: [RuntimeValue]) throws -> RuntimeValue {
        guard let value = args.first, case .array(let arr) = value else {
            throw RuntimeError.typeMismatch(
                expected: "array",
                actual: args.first?.typeName ?? "none",
                operation: "arrayLength"
            )
        }
        return .integer(arr.count)
    }

    private func stdAppend(_ args: [RuntimeValue]) throws -> RuntimeValue {
        guard args.count == 2, case .array(var arr) = args[0] else {
            throw RuntimeError.typeMismatch(
                expected: "array",
                actual: args.first?.typeName ?? "none",
                operation: "append"
            )
        }
        arr.append(args[1])
        return .array(arr)
    }

    private func stdPrepend(_ args: [RuntimeValue]) throws -> RuntimeValue {
        guard args.count == 2, case .array(var arr) = args[0] else {
            throw RuntimeError.typeMismatch(
                expected: "array",
                actual: args.first?.typeName ?? "none",
                operation: "prepend"
            )
        }
        arr.insert(args[1], at: 0)
        return .array(arr)
    }

    private func stdConcatArrays(_ args: [RuntimeValue]) throws -> RuntimeValue {
        var result: [RuntimeValue] = []
        for arg in args {
            guard case .array(let arr) = arg else {
                throw RuntimeError.typeMismatch(
                    expected: "array",
                    actual: arg.typeName,
                    operation: "concat_arrays"
                )
            }
            result.append(contentsOf: arr)
        }
        return .array(result)
    }

    // MARK: - Boxing/ABI Functions

    private func stdKkPrintlnAny(_ args: [RuntimeValue]) throws -> RuntimeValue {
        guard let value = args.first else {
            throw RuntimeError.wrongArgumentCount(function: "kk_println_any", expected: 1, actual: 0)
        }
        let output = formatAnyValue(value)
        printHandler(output + "\n")
        return .null
    }

    private func formatAnyValue(_ value: RuntimeValue) -> String {
        switch value {
        case .boxed(let tag, let inner):
            return "Any(tag=\(tag), \(formatAnyValue(inner)))"
        case .null:
            return "null"
        case .undefined:
            return "未定義"
        default:
            return value.toString()
        }
    }
}
