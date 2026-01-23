import Foundation

/// Errors that can occur during runtime execution.
public enum RuntimeError: Error, Equatable, CustomStringConvertible {
    /// Division by zero
    case divisionByZero

    /// Array index out of bounds
    case indexOutOfBounds(index: Int, size: Int)

    /// Type mismatch during operation
    case typeMismatch(expected: String, actual: String, operation: String)

    /// Undefined variable
    case undefinedVariable(name: String)

    /// Undefined function
    case undefinedFunction(name: String)

    /// Wrong number of arguments
    case wrongArgumentCount(function: String, expected: Int, actual: Int)

    /// Invalid operand for operation
    case invalidOperand(operation: String, operandType: String)

    /// Cannot assign to constant
    case cannotAssignToConstant(name: String)

    /// Return value from void function
    case returnInVoidContext

    /// Missing return value
    case missingReturnValue(function: String)

    /// Break outside loop
    case breakOutsideLoop

    /// Continue outside loop
    case continueOutsideLoop

    /// Stack overflow (recursion too deep)
    case stackOverflow

    /// Invalid field access
    case invalidFieldAccess(field: String, type: String)

    /// Not a callable value
    case notCallable(type: String)

    /// Generic runtime error
    case generic(message: String)

    // MARK: - CustomStringConvertible

    public var description: String {
        switch self {
        case .divisionByZero:
            return "Runtime error: Division by zero"

        case .indexOutOfBounds(let index, let size):
            return "Runtime error: Index \(index) out of bounds (array size: \(size))"

        case .typeMismatch(let expected, let actual, let operation):
            return "Runtime error: Type mismatch in \(operation) - expected \(expected), got \(actual)"

        case .undefinedVariable(let name):
            return "Runtime error: Undefined variable '\(name)'"

        case .undefinedFunction(let name):
            return "Runtime error: Undefined function '\(name)'"

        case .wrongArgumentCount(let function, let expected, let actual):
            return "Runtime error: Function '\(function)' expects \(expected) argument(s), got \(actual)"

        case .invalidOperand(let operation, let operandType):
            return "Runtime error: Invalid operand type '\(operandType)' for operation '\(operation)'"

        case .cannotAssignToConstant(let name):
            return "Runtime error: Cannot assign to constant '\(name)'"

        case .returnInVoidContext:
            return "Runtime error: Cannot return a value from a procedure"

        case .missingReturnValue(let function):
            return "Runtime error: Function '\(function)' must return a value"

        case .breakOutsideLoop:
            return "Runtime error: 'break' statement outside of loop"

        case .continueOutsideLoop:
            return "Runtime error: 'continue' statement outside of loop"

        case .stackOverflow:
            return "Runtime error: Stack overflow (maximum recursion depth exceeded)"

        case .invalidFieldAccess(let field, let type):
            return "Runtime error: Cannot access field '\(field)' on type '\(type)'"

        case .notCallable(let type):
            return "Runtime error: Value of type '\(type)' is not callable"

        case .generic(let message):
            return "Runtime error: \(message)"
        }
    }
}
