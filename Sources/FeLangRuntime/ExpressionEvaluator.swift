import Foundation
import FeLangCore

/// Type alias to disambiguate Expression
public typealias FEExpression = FeLangCore.Expression

/// Evaluates expressions and returns runtime values.
public struct ExpressionEvaluator: Sendable {
    /// The environment for variable lookups
    private let environment: Environment

    /// Function to call external functions
    private let callFunction: @Sendable (String, [RuntimeValue]) throws -> RuntimeValue

    /// Function to call methods on instances, returns (returnValue, modifiedInstance)
    private let callMethod: @Sendable (RuntimeValue, String, [RuntimeValue]) throws -> (RuntimeValue, RuntimeValue)

    // MARK: - Initialization

    public init(
        environment: Environment,
        callFunction: @escaping @Sendable (String, [RuntimeValue]) throws -> RuntimeValue,
        callMethod: @escaping @Sendable (RuntimeValue, String, [RuntimeValue]) throws -> (RuntimeValue, RuntimeValue)
    ) {
        self.environment = environment
        self.callFunction = callFunction
        self.callMethod = callMethod
    }

    // MARK: - Main Evaluation

    /// Evaluates an expression and returns its runtime value.
    public func evaluate(_ expression: FEExpression) throws -> RuntimeValue {
        switch expression {
        case .literal(let literal):
            return evaluateLiteral(literal)

        case .identifier(let name):
            return try environment.get(name)

        case .binary(let operatorType, let left, let right):
            if operatorType == .and {
                return try evaluateShortCircuitAnd(left, right)
            } else if operatorType == .or {
                return try evaluateShortCircuitOr(left, right)
            }
            let leftValue = try evaluate(left)
            let rightValue = try evaluate(right)
            return try evaluateBinary(operatorType, left: leftValue, right: rightValue)

        case .unary(let operatorType, let operand):
            let value = try evaluate(operand)
            return try evaluateUnary(operatorType, operand: value)

        case .arrayAccess(let array, let index):
            let arrayValue = try evaluate(array)
            let indexValue = try evaluate(index)
            return try evaluateArrayAccess(arrayValue, index: indexValue)

        case .fieldAccess(let object, let field):
            let objectValue = try evaluate(object)
            return try evaluateFieldAccess(objectValue, field: field)

        case .functionCall(let name, let arguments):
            let args = try arguments.map { try evaluate($0) }
            return try callFunction(name, args)

        case .methodCall(let receiver, let method, let arguments):
            let receiverValue = try evaluate(receiver)
            let args = try arguments.map { try evaluate($0) }
            let (returnValue, modifiedInstance) = try callMethod(receiverValue, method, args)
            // Update the receiver variable if it's an identifier to propagate instance state changes
            // Skip assignment for constants - they cannot be modified (this is intentional behavior)
            if case .identifier(let name) = receiver, !environment.isConstant(name) {
                try environment.assign(name, value: modifiedInstance)
            }
            return returnValue

        case .arrayLiteral(let elements):
            return try evaluateArrayLiteral(elements)
        }
    }

    private func evaluateArrayLiteral(_ elements: [FEExpression]) throws -> RuntimeValue {
        let values = try elements.map { try evaluate($0) }
        try validateArrayElementTypes(values)
        return .array(values)
    }

    private func validateArrayElementTypes(_ values: [RuntimeValue]) throws {
        guard let firstValue = values.first else { return }
        // Skip undefined values when determining expected type
        let expectedType: String
        if case .undefined = firstValue {
            // If first element is undefined, find first non-undefined element
            if let nonUndefined = values.first(where: { if case .undefined = $0 { return false } else { return true } }) {
                expectedType = nonUndefined.typeName
            } else {
                // All elements are undefined, no type checking needed
                return
            }
        } else {
            expectedType = firstValue.typeName
        }
        for (index, value) in values.enumerated() where index > 0 {
            if case .undefined = value {
                // Undefined is compatible with any type
                continue
            }
            if value.typeName != expectedType {
                throw RuntimeError.typeMismatch(
                    expected: expectedType,
                    actual: value.typeName,
                    operation: "array literal element at index \(index)"
                )
            }
        }
    }

    // MARK: - Literal Evaluation

    private func evaluateLiteral(_ literal: Literal) -> RuntimeValue {
        switch literal {
        case .integer(let value):
            return .integer(value)
        case .real(let value):
            return .real(value)
        case .string(let value):
            return .string(value)
        case .character(let value):
            return .character(value)
        case .boolean(let value):
            return .boolean(value)
        case .undefined:
            return .undefined
        }
    }

    // MARK: - Binary Operations

    private func evaluateBinary(
        _ operatorType: BinaryOperator,
        left: RuntimeValue,
        right: RuntimeValue
    ) throws -> RuntimeValue {
        switch operatorType {
        // Arithmetic
        case .add:
            return try evaluateAdd(left, right)
        case .subtract:
            return try evaluateArithmetic(left, right, operation: "-") { $0 - $1 }
        case .multiply:
            return try evaluateArithmetic(left, right, operation: "*") { $0 * $1 }
        case .divide:
            return try evaluateDivide(left, right)
        case .modulo:
            return try evaluateModulo(left, right)

        // Comparison
        case .equal:
            return .boolean(left == right)
        case .notEqual:
            return .boolean(left != right)
        case .less:
            return try evaluateComparison(left, right) { $0 < $1 }
        case .lessEqual:
            return try evaluateComparison(left, right) { $0 <= $1 }
        case .greater:
            return try evaluateComparison(left, right) { $0 > $1 }
        case .greaterEqual:
            return try evaluateComparison(left, right) { $0 >= $1 }

        // Bitwise
        case .bitwiseAnd:
            return try evaluateBitwiseAnd(left, right)
        case .bitwiseOr:
            return try evaluateBitwiseOr(left, right)
        case .leftShift:
            return try evaluateLeftShift(left, right)
        case .rightShift:
            return try evaluateRightShift(left, right)

        case .and, .or:
            fatalError("Logical operators should be handled by short-circuit evaluation")
        }
    }

    // MARK: - Logical Operations (Short-Circuit Evaluation)

    private func evaluateShortCircuitAnd(_ left: FEExpression, _ right: FEExpression) throws -> RuntimeValue {
        let leftValue = try evaluate(left)
        guard case .boolean(let leftBool) = leftValue else {
            throw RuntimeError.typeMismatch(expected: "Boolean", actual: leftValue.typeName, operation: "and")
        }
        if !leftBool {
            return .boolean(false)
        }
        let rightValue = try evaluate(right)
        guard case .boolean(let rightBool) = rightValue else {
            throw RuntimeError.typeMismatch(expected: "Boolean", actual: rightValue.typeName, operation: "and")
        }
        return .boolean(rightBool)
    }

    private func evaluateShortCircuitOr(_ left: FEExpression, _ right: FEExpression) throws -> RuntimeValue {
        let leftValue = try evaluate(left)
        guard case .boolean(let leftBool) = leftValue else {
            throw RuntimeError.typeMismatch(expected: "Boolean", actual: leftValue.typeName, operation: "or")
        }
        if leftBool {
            return .boolean(true)
        }
        let rightValue = try evaluate(right)
        guard case .boolean(let rightBool) = rightValue else {
            throw RuntimeError.typeMismatch(expected: "Boolean", actual: rightValue.typeName, operation: "or")
        }
        return .boolean(rightBool)
    }

    private func evaluateBitwiseAnd(_ left: RuntimeValue, _ right: RuntimeValue) throws -> RuntimeValue {
        guard case .integer(let leftInt) = left else {
            throw RuntimeError.typeMismatch(expected: "Integer", actual: left.typeName, operation: "∧")
        }
        guard case .integer(let rightInt) = right else {
            throw RuntimeError.typeMismatch(expected: "Integer", actual: right.typeName, operation: "∧")
        }
        return .integer(leftInt & rightInt)
    }

    private func evaluateBitwiseOr(_ left: RuntimeValue, _ right: RuntimeValue) throws -> RuntimeValue {
        guard case .integer(let leftInt) = left else {
            throw RuntimeError.typeMismatch(expected: "Integer", actual: left.typeName, operation: "∨")
        }
        guard case .integer(let rightInt) = right else {
            throw RuntimeError.typeMismatch(expected: "Integer", actual: right.typeName, operation: "∨")
        }
        return .integer(leftInt | rightInt)
    }

    private func evaluateLeftShift(_ left: RuntimeValue, _ right: RuntimeValue) throws -> RuntimeValue {
        guard case .integer(let leftInt) = left else {
            throw RuntimeError.typeMismatch(expected: "Integer", actual: left.typeName, operation: "<<")
        }
        guard case .integer(let rightInt) = right else {
            throw RuntimeError.typeMismatch(expected: "Integer", actual: right.typeName, operation: "<<")
        }
        guard rightInt >= 0 && rightInt < Int.bitWidth else {
            throw RuntimeError.invalidOperand(operation: "<<", operandType: "shift amount \(rightInt) out of valid range (0..<\(Int.bitWidth))")
        }
        return .integer(leftInt << rightInt)
    }

    private func evaluateRightShift(_ left: RuntimeValue, _ right: RuntimeValue) throws -> RuntimeValue {
        guard case .integer(let leftInt) = left else {
            throw RuntimeError.typeMismatch(expected: "Integer", actual: left.typeName, operation: ">>")
        }
        guard case .integer(let rightInt) = right else {
            throw RuntimeError.typeMismatch(expected: "Integer", actual: right.typeName, operation: ">>")
        }
        guard rightInt >= 0 && rightInt < Int.bitWidth else {
            throw RuntimeError.invalidOperand(operation: ">>", operandType: "shift amount \(rightInt) out of valid range (0..<\(Int.bitWidth))")
        }
        return .integer(leftInt >> rightInt)
    }

    private func evaluateAdd(_ left: RuntimeValue, _ right: RuntimeValue) throws -> RuntimeValue {
        switch (left, right) {
        case (.integer(let lhs), .integer(let rhs)):
            return .integer(lhs + rhs)
        case (.real(let lhs), .real(let rhs)):
            return .real(lhs + rhs)
        case (.integer(let lhs), .real(let rhs)):
            return .real(Double(lhs) + rhs)
        case (.real(let lhs), .integer(let rhs)):
            return .real(lhs + Double(rhs))
        case (.string(let lhs), .string(let rhs)):
            return .string(lhs + rhs)
        case (.string(let lhs), _):
            return .string(lhs + right.toString())
        case (_, .string(let rhs)):
            return .string(left.toString() + rhs)
        default:
            throw RuntimeError.typeMismatch(
                expected: "numeric or string",
                actual: "\(left.typeName) and \(right.typeName)",
                operation: "+"
            )
        }
    }

    private func evaluateArithmetic(
        _ left: RuntimeValue,
        _ right: RuntimeValue,
        operation: String,
        _ compute: (Double, Double) -> Double
    ) throws -> RuntimeValue {
        switch (left, right) {
        case (.integer(let lhs), .integer(let rhs)):
            return .integer(Int(compute(Double(lhs), Double(rhs))))
        case (.real(let lhs), .real(let rhs)):
            return .real(compute(lhs, rhs))
        case (.integer(let lhs), .real(let rhs)):
            return .real(compute(Double(lhs), rhs))
        case (.real(let lhs), .integer(let rhs)):
            return .real(compute(lhs, Double(rhs)))
        default:
            throw RuntimeError.typeMismatch(
                expected: "numeric",
                actual: "\(left.typeName) and \(right.typeName)",
                operation: operation
            )
        }
    }

    private func evaluateDivide(_ left: RuntimeValue, _ right: RuntimeValue) throws -> RuntimeValue {
        // Check for division by zero
        switch right {
        case .integer(0):
            throw RuntimeError.divisionByZero
        case .real(let rhs) where rhs == 0.0:
            throw RuntimeError.divisionByZero
        default:
            break
        }

        switch (left, right) {
        case (.integer(let lhs), .integer(let rhs)):
            return .integer(lhs / rhs)
        case (.real(let lhs), .real(let rhs)):
            return .real(lhs / rhs)
        case (.integer(let lhs), .real(let rhs)):
            return .real(Double(lhs) / rhs)
        case (.real(let lhs), .integer(let rhs)):
            return .real(lhs / Double(rhs))
        default:
            throw RuntimeError.typeMismatch(
                expected: "numeric",
                actual: "\(left.typeName) and \(right.typeName)",
                operation: "/"
            )
        }
    }

    private func evaluateModulo(_ left: RuntimeValue, _ right: RuntimeValue) throws -> RuntimeValue {
        switch (left, right) {
        case (.integer(let lhs), .integer(let rhs)):
            guard rhs != 0 else { throw RuntimeError.divisionByZero }
            return .integer(lhs % rhs)
        default:
            throw RuntimeError.typeMismatch(
                expected: "integer",
                actual: "\(left.typeName) and \(right.typeName)",
                operation: "%"
            )
        }
    }

    private func evaluateComparison(
        _ left: RuntimeValue,
        _ right: RuntimeValue,
        _ compare: (Double, Double) -> Bool
    ) throws -> RuntimeValue {
        switch (left, right) {
        case (.integer(let lhs), .integer(let rhs)):
            return .boolean(compare(Double(lhs), Double(rhs)))
        case (.real(let lhs), .real(let rhs)):
            return .boolean(compare(lhs, rhs))
        case (.integer(let lhs), .real(let rhs)):
            return .boolean(compare(Double(lhs), rhs))
        case (.real(let lhs), .integer(let rhs)):
            return .boolean(compare(lhs, Double(rhs)))
        case (.string(let lhs), .string(let rhs)):
            // Use lexicographic comparison: -1 for less, 0 for equal, 1 for greater
            let comparisonResult: Double
            if lhs < rhs {
                comparisonResult = -1
            } else if lhs > rhs {
                comparisonResult = 1
            } else {
                comparisonResult = 0
            }
            return .boolean(compare(comparisonResult, 0))
        default:
            throw RuntimeError.typeMismatch(
                expected: "comparable types",
                actual: "\(left.typeName) and \(right.typeName)",
                operation: "comparison"
            )
        }
    }

    // MARK: - Unary Operations

    private func evaluateUnary(
        _ operatorType: UnaryOperator,
        operand: RuntimeValue
    ) throws -> RuntimeValue {
        switch operatorType {
        case .minus:
            switch operand {
            case .integer(let value):
                return .integer(-value)
            case .real(let value):
                return .real(-value)
            default:
                throw RuntimeError.invalidOperand(operation: "-", operandType: operand.typeName)
            }

        case .plus:
            // Unary plus is a no-op for numbers
            switch operand {
            case .integer, .real:
                return operand
            default:
                throw RuntimeError.invalidOperand(operation: "+", operandType: operand.typeName)
            }

        case .not:
            return .boolean(!operand.isTruthy)
        }
    }

    // MARK: - Array Access

    private func evaluateArrayAccess(
        _ array: RuntimeValue,
        index: RuntimeValue
    ) throws -> RuntimeValue {
        guard case .array(let elements) = array else {
            throw RuntimeError.typeMismatch(
                expected: "array",
                actual: array.typeName,
                operation: "index access"
            )
        }

        guard case .integer(let idx) = index else {
            throw RuntimeError.typeMismatch(
                expected: "integer",
                actual: index.typeName,
                operation: "array index"
            )
        }

        guard idx >= 0, idx < elements.count else {
            throw RuntimeError.indexOutOfBounds(index: idx, size: elements.count)
        }

        return elements[idx]
    }

    // MARK: - Field Access

    private func evaluateFieldAccess(
        _ object: RuntimeValue,
        field: String
    ) throws -> RuntimeValue {
        switch object {
        case .record(let fields):
            guard let value = fields[field] else {
                throw RuntimeError.invalidFieldAccess(field: field, type: "record")
            }
            return value

        case .instance(let inst):
            guard let value = inst.fields[field] else {
                throw RuntimeError.invalidFieldAccess(field: field, type: inst.className)
            }
            return value

        default:
            throw RuntimeError.invalidFieldAccess(field: field, type: object.typeName)
        }
    }
}
