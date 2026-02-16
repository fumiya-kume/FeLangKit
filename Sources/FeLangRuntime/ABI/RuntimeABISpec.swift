import Foundation

public enum ABIType: Equatable, Sendable {
    case void
    case int32
    case int64
    case float64
    case bool
    case opaquePointer
    case nullableOpaquePointer
    case cString
    case nullableCString

    public var cTypeName: String {
        switch self {
        case .void: return "void"
        case .int32: return "int32_t"
        case .int64: return "int64_t"
        case .float64: return "double"
        case .bool: return "bool"
        case .opaquePointer: return "void *"
        case .nullableOpaquePointer: return "void * _Nullable"
        case .cString: return "const char *"
        case .nullableCString: return "const char * _Nullable"
        }
    }

    public var isNullable: Bool {
        switch self {
        case .nullableOpaquePointer, .nullableCString:
            return true
        default:
            return false
        }
    }
}

public struct ABIParameterSpec: Equatable, Sendable {
    public let name: String
    public let type: ABIType

    public init(name: String, type: ABIType) {
        self.name = name
        self.type = type
    }
}

public struct ABIFunctionSpec: Equatable, Sendable {
    public let name: String
    public let returnType: ABIType
    public let parameters: [ABIParameterSpec]
    public let description: String

    public init(
        name: String,
        returnType: ABIType,
        parameters: [ABIParameterSpec],
        description: String
    ) {
        self.name = name
        self.returnType = returnType
        self.parameters = parameters
        self.description = description
    }

    public var cDeclaration: String {
        let params: String
        if parameters.isEmpty {
            params = "void"
        } else {
            params = parameters
                .map { "\($0.type.cTypeName) \($0.name)" }
                .joined(separator: ", ")
        }
        return "\(returnType.cTypeName) \(name)(\(params));"
    }
}

public enum RuntimeABISpec {
    public static let specVersion = "1.0.0"

    public static let allFunctions: [ABIFunctionSpec] = memoryFunctions
        + valueCreationFunctions
        + valueAccessFunctions
        + ioFunctions
        + arrayFunctions
        + environmentFunctions

    // MARK: - J16.1.1 Memory Management

    public static let memoryFunctions: [ABIFunctionSpec] = [
        ABIFunctionSpec(
            name: "kk_alloc",
            returnType: .nullableOpaquePointer,
            parameters: [
                ABIParameterSpec(name: "size", type: .int64)
            ],
            description: "Allocate size bytes. Returns NULL on failure."
        ),
        ABIFunctionSpec(
            name: "kk_realloc",
            returnType: .nullableOpaquePointer,
            parameters: [
                ABIParameterSpec(name: "ptr", type: .nullableOpaquePointer),
                ABIParameterSpec(name: "new_size", type: .int64)
            ],
            description: "Reallocate ptr to new_size bytes. Returns NULL on failure."
        ),
        ABIFunctionSpec(
            name: "kk_free",
            returnType: .void,
            parameters: [
                ABIParameterSpec(name: "ptr", type: .nullableOpaquePointer)
            ],
            description: "Free memory at ptr. No-op if ptr is NULL."
        ),
        ABIFunctionSpec(
            name: "kk_retain",
            returnType: .void,
            parameters: [
                ABIParameterSpec(name: "obj", type: .opaquePointer)
            ],
            description: "Increment reference count for obj."
        ),
        ABIFunctionSpec(
            name: "kk_release",
            returnType: .void,
            parameters: [
                ABIParameterSpec(name: "obj", type: .opaquePointer)
            ],
            description: "Decrement reference count for obj. Frees when count reaches 0."
        )
    ]

    // MARK: - J16.1.2 Value Creation

    public static let valueCreationFunctions: [ABIFunctionSpec] = [
        ABIFunctionSpec(
            name: "kk_value_integer",
            returnType: .opaquePointer,
            parameters: [
                ABIParameterSpec(name: "value", type: .int64)
            ],
            description: "Create a boxed integer value."
        ),
        ABIFunctionSpec(
            name: "kk_value_real",
            returnType: .opaquePointer,
            parameters: [
                ABIParameterSpec(name: "value", type: .float64)
            ],
            description: "Create a boxed real (double) value."
        ),
        ABIFunctionSpec(
            name: "kk_value_boolean",
            returnType: .opaquePointer,
            parameters: [
                ABIParameterSpec(name: "value", type: .bool)
            ],
            description: "Create a boxed boolean value."
        ),
        ABIFunctionSpec(
            name: "kk_value_string",
            returnType: .opaquePointer,
            parameters: [
                ABIParameterSpec(name: "str", type: .cString),
                ABIParameterSpec(name: "len", type: .int64)
            ],
            description: "Create a boxed string value from a UTF-8 buffer and byte length."
        ),
        ABIFunctionSpec(
            name: "kk_value_null",
            returnType: .opaquePointer,
            parameters: [],
            description: "Create a boxed null value."
        )
    ]

    // MARK: - J16.1.3 Value Access

    public static let valueAccessFunctions: [ABIFunctionSpec] = [
        ABIFunctionSpec(
            name: "kk_value_get_tag",
            returnType: .int32,
            parameters: [
                ABIParameterSpec(name: "val", type: .opaquePointer)
            ],
            description: "Return the type tag of a boxed value (0=int,1=real,2=bool,3=string,4=null,5=array)."
        ),
        ABIFunctionSpec(
            name: "kk_value_get_integer",
            returnType: .int64,
            parameters: [
                ABIParameterSpec(name: "val", type: .opaquePointer)
            ],
            description: "Extract integer payload. Undefined behaviour if tag != 0."
        ),
        ABIFunctionSpec(
            name: "kk_value_get_real",
            returnType: .float64,
            parameters: [
                ABIParameterSpec(name: "val", type: .opaquePointer)
            ],
            description: "Extract real payload. Undefined behaviour if tag != 1."
        ),
        ABIFunctionSpec(
            name: "kk_value_get_boolean",
            returnType: .bool,
            parameters: [
                ABIParameterSpec(name: "val", type: .opaquePointer)
            ],
            description: "Extract boolean payload. Undefined behaviour if tag != 2."
        ),
        ABIFunctionSpec(
            name: "kk_value_get_string",
            returnType: .cString,
            parameters: [
                ABIParameterSpec(name: "val", type: .opaquePointer)
            ],
            description: "Extract null-terminated UTF-8 string. Caller must free() the returned pointer. Undefined behaviour if tag != 3."
        ),
        ABIFunctionSpec(
            name: "kk_value_get_string_len",
            returnType: .int64,
            parameters: [
                ABIParameterSpec(name: "val", type: .opaquePointer)
            ],
            description: "Return byte length of string payload. Undefined behaviour if tag != 3."
        )
    ]

    // MARK: - J16.1.4 I/O

    public static let ioFunctions: [ABIFunctionSpec] = [
        ABIFunctionSpec(
            name: "kk_print",
            returnType: .void,
            parameters: [
                ABIParameterSpec(name: "str", type: .cString)
            ],
            description: "Print a null-terminated string to stdout (no trailing newline)."
        ),
        ABIFunctionSpec(
            name: "kk_println",
            returnType: .void,
            parameters: [
                ABIParameterSpec(name: "str", type: .cString)
            ],
            description: "Print a null-terminated string to stdout followed by a newline."
        ),
        ABIFunctionSpec(
            name: "kk_input",
            returnType: .nullableCString,
            parameters: [],
            description: "Read a line from stdin. Returns NULL on EOF. Caller must free() the returned pointer."
        )
    ]

    // MARK: - J16.1.5 Array

    public static let arrayFunctions: [ABIFunctionSpec] = [
        ABIFunctionSpec(
            name: "kk_array_new",
            returnType: .opaquePointer,
            parameters: [
                ABIParameterSpec(name: "capacity", type: .int64)
            ],
            description: "Create a new empty array with the given initial capacity."
        ),
        ABIFunctionSpec(
            name: "kk_array_length",
            returnType: .int64,
            parameters: [
                ABIParameterSpec(name: "arr", type: .opaquePointer)
            ],
            description: "Return the number of elements in the array."
        ),
        ABIFunctionSpec(
            name: "kk_array_get",
            returnType: .opaquePointer,
            parameters: [
                ABIParameterSpec(name: "arr", type: .opaquePointer),
                ABIParameterSpec(name: "index", type: .int64)
            ],
            description: "Return the element at the given index. Traps on out-of-bounds."
        ),
        ABIFunctionSpec(
            name: "kk_array_set",
            returnType: .void,
            parameters: [
                ABIParameterSpec(name: "arr", type: .opaquePointer),
                ABIParameterSpec(name: "index", type: .int64),
                ABIParameterSpec(name: "value", type: .opaquePointer)
            ],
            description: "Set the element at the given index. Traps on out-of-bounds."
        ),
        ABIFunctionSpec(
            name: "kk_array_push",
            returnType: .void,
            parameters: [
                ABIParameterSpec(name: "arr", type: .opaquePointer),
                ABIParameterSpec(name: "value", type: .opaquePointer)
            ],
            description: "Append value to the end of the array."
        )
    ]

    // MARK: - J16.1.6 Environment

    public static let environmentFunctions: [ABIFunctionSpec] = [
        ABIFunctionSpec(
            name: "kk_env_new",
            returnType: .opaquePointer,
            parameters: [],
            description: "Create a new runtime environment."
        ),
        ABIFunctionSpec(
            name: "kk_env_destroy",
            returnType: .void,
            parameters: [
                ABIParameterSpec(name: "env", type: .opaquePointer)
            ],
            description: "Destroy a runtime environment and free resources."
        ),
        ABIFunctionSpec(
            name: "kk_env_define",
            returnType: .void,
            parameters: [
                ABIParameterSpec(name: "env", type: .opaquePointer),
                ABIParameterSpec(name: "name", type: .cString),
                ABIParameterSpec(name: "value", type: .opaquePointer)
            ],
            description: "Define a variable in the current scope."
        ),
        ABIFunctionSpec(
            name: "kk_env_get",
            returnType: .nullableOpaquePointer,
            parameters: [
                ABIParameterSpec(name: "env", type: .opaquePointer),
                ABIParameterSpec(name: "name", type: .cString)
            ],
            description: "Look up a variable by name. Returns NULL if not found."
        ),
        ABIFunctionSpec(
            name: "kk_env_set",
            returnType: .bool,
            parameters: [
                ABIParameterSpec(name: "env", type: .opaquePointer),
                ABIParameterSpec(name: "name", type: .cString),
                ABIParameterSpec(name: "value", type: .opaquePointer)
            ],
            description: "Assign a new value to an existing variable. Returns false if undefined."
        ),
        ABIFunctionSpec(
            name: "kk_env_push_scope",
            returnType: .void,
            parameters: [
                ABIParameterSpec(name: "env", type: .opaquePointer)
            ],
            description: "Push a new variable scope."
        ),
        ABIFunctionSpec(
            name: "kk_env_pop_scope",
            returnType: .void,
            parameters: [
                ABIParameterSpec(name: "env", type: .opaquePointer)
            ],
            description: "Pop the innermost variable scope."
        )
    ]
}
