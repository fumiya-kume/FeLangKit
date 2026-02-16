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

    /// A class definition
    case classDefinition(ClassDefinition)

    /// A class instance
    case instance(InstanceValue)

    /// Represents nil/null/void
    case null

    /// A boxed value with type tag for ABI boundary crossing
    indirect case boxed(typeTag: Int, value: RuntimeValue)

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
        case .classDefinition(let classDef): return "Class<\(classDef.name)>"
        case .instance(let inst): return inst.className
        case .boxed(_, let inner): return "Boxed<\(inner.typeName)>"
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
        case .boxed(_, let inner):
            return inner.isTruthy
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
        case .boxed(_, let inner):
            return inner.toInteger()
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
        case .boxed(_, let inner):
            return inner.toReal()
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
        case .classDefinition(let classDef):
            return "<class \(classDef.name)>"
        case .instance(let inst):
            let fieldStrings = inst.fields.map { "\($0.key): \($0.value.toString())" }
            return "\(inst.className){\(fieldStrings.joined(separator: ", "))}"
        case .boxed(let tag, let inner):
            return "boxed(tag=\(tag), \(inner.toString()))"
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

    /// The captured environment (closure) using copy-on-write storage
    public let captured: Environment.CapturedEnvironment

    /// The return type
    public let returnType: DataType?

    /// Convenience accessor for captured environment values (for backward compatibility)
    public var capturedEnvironment: [String: RuntimeValue] {
        return captured.values
    }

    /// Convenience accessor for captured constants (for backward compatibility)
    public var capturedConstants: Set<String> {
        return captured.constants
    }

    /// Convenience accessor for captured types (for backward compatibility)
    public var capturedTypes: [String: DataType] {
        return captured.types
    }

    /// Convenience accessor for captured uninitialized variables (for backward compatibility)
    public var capturedUninitialized: Set<String> {
        return captured.uninitialized
    }

    /// Creates a function value with a captured environment.
    public init(
        name: String,
        parameters: [String],
        parameterTypes: [DataType] = [],
        body: [Statement],
        captured: Environment.CapturedEnvironment,
        returnType: DataType?
    ) {
        self.name = name
        self.parameters = parameters
        self.parameterTypes = parameterTypes
        self.body = body
        self.captured = captured
        self.returnType = returnType
    }

    /// Creates a function value with individual captured components (for backward compatibility).
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
        self.captured = Environment.CapturedEnvironment(
            values: capturedEnvironment,
            constants: capturedConstants,
            types: capturedTypes,
            uninitialized: capturedUninitialized
        )
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

    /// The captured environment (closure) using copy-on-write storage
    public let captured: Environment.CapturedEnvironment

    /// Convenience accessor for captured environment values (for backward compatibility)
    public var capturedEnvironment: [String: RuntimeValue] {
        return captured.values
    }

    /// Convenience accessor for captured constants (for backward compatibility)
    public var capturedConstants: Set<String> {
        return captured.constants
    }

    /// Convenience accessor for captured types (for backward compatibility)
    public var capturedTypes: [String: DataType] {
        return captured.types
    }

    /// Convenience accessor for captured uninitialized variables (for backward compatibility)
    public var capturedUninitialized: Set<String> {
        return captured.uninitialized
    }

    /// Creates a procedure value with a captured environment.
    public init(
        name: String,
        parameters: [String],
        parameterTypes: [DataType] = [],
        body: [Statement],
        captured: Environment.CapturedEnvironment
    ) {
        self.name = name
        self.parameters = parameters
        self.parameterTypes = parameterTypes
        self.body = body
        self.captured = captured
    }

    /// Creates a procedure value with individual captured components (for backward compatibility).
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
        self.captured = Environment.CapturedEnvironment(
            values: capturedEnvironment,
            constants: capturedConstants,
            types: capturedTypes,
            uninitialized: capturedUninitialized
        )
    }
}

/// Represents a class definition that can be instantiated.
public struct ClassDefinition: Equatable, Sendable {
    /// The name of the class
    public let name: String

    /// The name of the superclass (nil if no inheritance)
    public let superclassName: String?

    /// Member variable names and their types
    public let members: [String: DataType]

    /// Constructor parameters
    public let constructorParameters: [String]

    /// Constructor parameter types
    public let constructorParameterTypes: [DataType]

    /// Constructor body statements
    public let constructorBody: [Statement]

    /// Method definitions
    public let methods: [String: MethodDefinition]

    public init(
        name: String,
        superclassName: String? = nil,
        members: [String: DataType] = [:],
        constructorParameters: [String] = [],
        constructorParameterTypes: [DataType] = [],
        constructorBody: [Statement] = [],
        methods: [String: MethodDefinition] = [:]
    ) {
        self.name = name
        self.superclassName = superclassName
        self.members = members
        self.constructorParameters = constructorParameters
        self.constructorParameterTypes = constructorParameterTypes
        self.constructorBody = constructorBody
        self.methods = methods
    }
}

/// Represents a method definition within a class.
public struct MethodDefinition: Equatable, Sendable {
    /// The name of the method
    public let name: String

    /// Parameter names
    public let parameters: [String]

    /// Parameter types
    public let parameterTypes: [DataType]

    /// Return type (nil for void methods)
    public let returnType: DataType?

    /// Method body statements
    public let body: [Statement]

    public init(
        name: String,
        parameters: [String],
        parameterTypes: [DataType] = [],
        returnType: DataType? = nil,
        body: [Statement]
    ) {
        self.name = name
        self.parameters = parameters
        self.parameterTypes = parameterTypes
        self.returnType = returnType
        self.body = body
    }
}

/// Represents an instance of a class.
public struct InstanceValue: Equatable, Sendable {
    /// The name of the class this instance belongs to
    public let className: String

    /// The class definition reference
    public let classDefinition: ClassDefinition

    /// Instance field values (mutable through copy-on-write)
    public var fields: [String: RuntimeValue]

    public init(
        className: String,
        classDefinition: ClassDefinition,
        fields: [String: RuntimeValue] = [:]
    ) {
        self.className = className
        self.classDefinition = classDefinition
        self.fields = fields
    }
}
