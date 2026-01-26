import Foundation
import FeLangCore

/// Represents a value at runtime in the FE interpreter.
public enum RuntimeValue: Equatable, Sendable, CustomStringConvertible {
    /// An integer value
    case integer(Int)

    /// A real (floating-point) value
    case real(Double)

    /// A string value
    case string(String)

    /// A character value
    case character(Character)

    /// A boolean value
    case boolean(Bool)

    /// An array value
    case array([RuntimeValue])

    /// A record value with named fields
    case record([String: RuntimeValue])

    /// A function value (closure)
    case function(FunctionValue)

    /// A procedure value
    case procedure(ProcedureValue)

    /// Represents nil/null/void
    case null

    /// Represents an undefined value (未定義)
    case undefined

    // MARK: - Properties

    /// Returns the type name of this value
    public var typeName: String {
        switch self {
        case .integer: return "Integer"
        case .real: return "Real"
        case .string: return "String"
        case .character: return "Character"
        case .boolean: return "Boolean"
        case .array: return "Array"
        case .record: return "Record"
        case .function: return "Function"
        case .procedure: return "Procedure"
        case .null: return "Null"
        case .undefined: return "Undefined"
        }
    }

    /// Returns true if this value is truthy
    public var isTruthy: Bool {
        switch self {
        case .boolean(let value):
            return value
        case .integer(let value):
            return value != 0
        case .null, .undefined:
            return false
        default:
            return true
        }
    }

    // MARK: - Conversion Methods

    /// Attempts to convert to an integer
    public func toInteger() -> Int? {
        switch self {
        case .integer(let value):
            return value
        case .real(let value):
            return Int(value)
        case .string(let value):
            return Int(value)
        case .boolean(let value):
            return value ? 1 : 0
        default:
            return nil
        }
    }

    /// Attempts to convert to a real number
    public func toReal() -> Double? {
        switch self {
        case .integer(let value):
            return Double(value)
        case .real(let value):
            return value
        case .string(let value):
            return Double(value)
        default:
            return nil
        }
    }

    /// Attempts to convert to a string
    public func toString() -> String {
        switch self {
        case .integer(let value):
            return String(value)
        case .real(let value):
            return String(value)
        case .string(let value):
            return value
        case .character(let value):
            return String(value)
        case .boolean(let value):
            return value ? "true" : "false"
        case .array(let elements):
            let elementStrings = elements.map { $0.toString() }
            return "[\(elementStrings.joined(separator: ", "))]"
        case .record(let fields):
            let fieldStrings = fields.map { "\($0.key): \($0.value.toString())" }
            return "{\(fieldStrings.joined(separator: ", "))}"
        case .function(let functionValue):
            return "<function \(functionValue.name)>"
        case .procedure(let proc):
            return "<procedure \(proc.name)>"
        case .null:
            return "null"
        case .undefined:
            return "未定義"
        }
    }

    // MARK: - CustomStringConvertible

    public var description: String {
        toString()
    }
}

/// Represents a function value that can be called.
public struct FunctionValue: Equatable, Sendable {
    /// The name of the function
    public let name: String

    /// Parameter names
    public let parameters: [String]

    /// Parameter types
    public let parameterTypes: [DataType]

    /// The body statements
    public let body: [Statement]

    /// The captured environment (closure)
    public let capturedEnvironment: [String: RuntimeValue]

    /// The captured constants from the closure environment
    public let capturedConstants: Set<String>

    /// The captured types from the closure environment
    public let capturedTypes: [String: DataType]

    /// The captured uninitialized variables from the closure environment
    public let capturedUninitialized: Set<String>

    /// The return type
    public let returnType: DataType?

    public init(
        name: String,
        parameters: [String],
        parameterTypes: [DataType] = [],
        body: [Statement],
        capturedEnvironment: [String: RuntimeValue] = [:],
        capturedConstants: Set<String> = [],
        capturedTypes: [String: DataType] = [:],
        capturedUninitialized: Set<String> = [],
        returnType: DataType?
    ) {
        self.name = name
        self.parameters = parameters
        self.parameterTypes = parameterTypes
        self.body = body
        self.capturedEnvironment = capturedEnvironment
        self.capturedConstants = capturedConstants
        self.capturedTypes = capturedTypes
        self.capturedUninitialized = capturedUninitialized
        self.returnType = returnType
    }
}

/// Represents a procedure value that can be called.
public struct ProcedureValue: Equatable, Sendable {
    /// The name of the procedure
    public let name: String

    /// Parameter names
    public let parameters: [String]

    /// Parameter types
    public let parameterTypes: [DataType]

    /// The body statements
    public let body: [Statement]

    /// The captured environment (closure)
    public let capturedEnvironment: [String: RuntimeValue]

    /// The captured constants from the closure environment
    public let capturedConstants: Set<String>

    /// The captured types from the closure environment
    public let capturedTypes: [String: DataType]

    /// The captured uninitialized variables from the closure environment
    public let capturedUninitialized: Set<String>

    public init(
        name: String,
        parameters: [String],
        parameterTypes: [DataType] = [],
        body: [Statement],
        capturedEnvironment: [String: RuntimeValue] = [:],
        capturedConstants: Set<String> = [],
        capturedTypes: [String: DataType] = [:],
        capturedUninitialized: Set<String> = []
    ) {
        self.name = name
        self.parameters = parameters
        self.parameterTypes = parameterTypes
        self.body = body
        self.capturedEnvironment = capturedEnvironment
        self.capturedConstants = capturedConstants
        self.capturedTypes = capturedTypes
        self.capturedUninitialized = capturedUninitialized
    }
}
