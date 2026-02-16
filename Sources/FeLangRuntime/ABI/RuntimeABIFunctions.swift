import Foundation

private enum ValueTag: Int32 {
    case integer = 0
    case real = 1
    case boolean = 2
    case string = 3
    case null = 4
    case array = 5
}

private final class BoxedValue {
    let tag: ValueTag
    var integerPayload: Int64 = 0
    var realPayload: Double = 0.0
    var booleanPayload: Bool = false
    var stringPayload: String = ""
    var arrayPayload: [BoxedValue] = []

    init(tag: ValueTag) {
        self.tag = tag
    }
}

private func retainedPointer(_ box: BoxedValue) -> UnsafeMutableRawPointer {
    let unmanaged = Unmanaged.passRetained(box)
    return unmanaged.toOpaque()
}

private func borrowedBox(_ ptr: UnsafeMutableRawPointer) -> BoxedValue {
    return Unmanaged<BoxedValue>.fromOpaque(ptr).takeUnretainedValue()
}

// MARK: - J16.1.1 Memory Management

@_cdecl("kk_alloc")
public func kk_alloc(_ size: Int64) -> UnsafeMutableRawPointer? {
    guard size > 0 else { return nil }
    return malloc(Int(size))
}

@_cdecl("kk_realloc")
public func kk_realloc(
    _ ptr: UnsafeMutableRawPointer?,
    _ newSize: Int64
) -> UnsafeMutableRawPointer? {
    guard newSize > 0 else {
        if let ptr = ptr { free(ptr) }
        return nil
    }
    return realloc(ptr, Int(newSize))
}

@_cdecl("kk_free")
public func kk_free(_ ptr: UnsafeMutableRawPointer?) {
    guard let ptr = ptr else { return }
    free(ptr)
}

@_cdecl("kk_retain")
public func kk_retain(_ obj: UnsafeMutableRawPointer) {
    Unmanaged<BoxedValue>.fromOpaque(obj).retain()
}

@_cdecl("kk_release")
public func kk_release(_ obj: UnsafeMutableRawPointer) {
    Unmanaged<BoxedValue>.fromOpaque(obj).release()
}

// MARK: - J16.1.2 Value Creation

@_cdecl("kk_value_integer")
public func kk_value_integer(_ value: Int64) -> UnsafeMutableRawPointer {
    let box = BoxedValue(tag: .integer)
    box.integerPayload = value
    return retainedPointer(box)
}

@_cdecl("kk_value_real")
public func kk_value_real(_ value: Double) -> UnsafeMutableRawPointer {
    let box = BoxedValue(tag: .real)
    box.realPayload = value
    return retainedPointer(box)
}

@_cdecl("kk_value_boolean")
public func kk_value_boolean(_ value: Bool) -> UnsafeMutableRawPointer {
    let box = BoxedValue(tag: .boolean)
    box.booleanPayload = value
    return retainedPointer(box)
}

@_cdecl("kk_value_string")
public func kk_value_string(
    _ str: UnsafePointer<CChar>,
    _ len: Int64
) -> UnsafeMutableRawPointer {
    let box = BoxedValue(tag: .string)
    let data = Data(bytes: str, count: Int(len))
    box.stringPayload = String(data: data, encoding: .utf8) ?? ""
    return retainedPointer(box)
}

@_cdecl("kk_value_null")
public func kk_value_null() -> UnsafeMutableRawPointer {
    let box = BoxedValue(tag: .null)
    return retainedPointer(box)
}

// MARK: - J16.1.3 Value Access

@_cdecl("kk_value_get_tag")
public func kk_value_get_tag(_ val: UnsafeMutableRawPointer) -> Int32 {
    let box = borrowedBox(val)
    return box.tag.rawValue
}

@_cdecl("kk_value_get_integer")
public func kk_value_get_integer(_ val: UnsafeMutableRawPointer) -> Int64 {
    let box = borrowedBox(val)
    return box.integerPayload
}

@_cdecl("kk_value_get_real")
public func kk_value_get_real(_ val: UnsafeMutableRawPointer) -> Double {
    let box = borrowedBox(val)
    return box.realPayload
}

@_cdecl("kk_value_get_boolean")
public func kk_value_get_boolean(_ val: UnsafeMutableRawPointer) -> Bool {
    let box = borrowedBox(val)
    return box.booleanPayload
}

@_cdecl("kk_value_get_string")
public func kk_value_get_string(
    _ val: UnsafeMutableRawPointer
) -> UnsafePointer<CChar> {
    let box = borrowedBox(val)
    return box.stringPayload.withCString { ptr in
        return UnsafePointer(strdup(ptr)!)
    }
}

@_cdecl("kk_value_get_string_len")
public func kk_value_get_string_len(_ val: UnsafeMutableRawPointer) -> Int64 {
    let box = borrowedBox(val)
    return Int64(box.stringPayload.utf8.count)
}

// MARK: - J16.1.4 I/O

@_cdecl("kk_print")
public func kk_print(_ str: UnsafePointer<CChar>) {
    let text = String(cString: str)
    print(text, terminator: "")
}

@_cdecl("kk_println")
public func kk_println(_ str: UnsafePointer<CChar>) {
    let text = String(cString: str)
    print(text)
}

@_cdecl("kk_input")
public func kk_input() -> UnsafePointer<CChar>? {
    guard let line = readLine() else { return nil }
    return line.withCString { ptr in
        return UnsafePointer(strdup(ptr)!)
    }
}

// MARK: - J16.1.5 Array

@_cdecl("kk_array_new")
public func kk_array_new(_ capacity: Int64) -> UnsafeMutableRawPointer {
    let box = BoxedValue(tag: .array)
    box.arrayPayload.reserveCapacity(Int(capacity))
    return retainedPointer(box)
}

@_cdecl("kk_array_length")
public func kk_array_length(_ arr: UnsafeMutableRawPointer) -> Int64 {
    let box = borrowedBox(arr)
    return Int64(box.arrayPayload.count)
}

@_cdecl("kk_array_get")
public func kk_array_get(
    _ arr: UnsafeMutableRawPointer,
    _ index: Int64
) -> UnsafeMutableRawPointer {
    let box = borrowedBox(arr)
    precondition(index >= 0 && Int(index) < box.arrayPayload.count, "kk_array_get: index out of bounds")
    let element = box.arrayPayload[Int(index)]
    return Unmanaged.passRetained(element).toOpaque()
}

@_cdecl("kk_array_set")
public func kk_array_set(
    _ arr: UnsafeMutableRawPointer,
    _ index: Int64,
    _ value: UnsafeMutableRawPointer
) {
    let box = borrowedBox(arr)
    precondition(index >= 0 && Int(index) < box.arrayPayload.count, "kk_array_set: index out of bounds")
    let newElement = borrowedBox(value)
    box.arrayPayload[Int(index)] = newElement
}

@_cdecl("kk_array_push")
public func kk_array_push(
    _ arr: UnsafeMutableRawPointer,
    _ value: UnsafeMutableRawPointer
) {
    let box = borrowedBox(arr)
    let element = borrowedBox(value)
    box.arrayPayload.append(element)
}

// MARK: - J16.1.6 Environment

private final class BoxedEnvironment {
    let environment: Environment

    init() {
        self.environment = Environment()
    }
}

@_cdecl("kk_env_new")
public func kk_env_new() -> UnsafeMutableRawPointer {
    let boxed = BoxedEnvironment()
    return Unmanaged.passRetained(boxed).toOpaque()
}

@_cdecl("kk_env_destroy")
public func kk_env_destroy(_ env: UnsafeMutableRawPointer) {
    Unmanaged<BoxedEnvironment>.fromOpaque(env).release()
}

@_cdecl("kk_env_define")
public func kk_env_define(
    _ env: UnsafeMutableRawPointer,
    _ name: UnsafePointer<CChar>,
    _ value: UnsafeMutableRawPointer
) {
    let boxedEnv = Unmanaged<BoxedEnvironment>.fromOpaque(env).takeUnretainedValue()
    let nameStr = String(cString: name)
    let runtimeValue = boxedValueToRuntimeValue(value)
    boxedEnv.environment.define(nameStr, value: runtimeValue)
}

@_cdecl("kk_env_get")
public func kk_env_get(
    _ env: UnsafeMutableRawPointer,
    _ name: UnsafePointer<CChar>
) -> UnsafeMutableRawPointer? {
    let boxedEnv = Unmanaged<BoxedEnvironment>.fromOpaque(env).takeUnretainedValue()
    let nameStr = String(cString: name)
    guard let value = boxedEnv.environment.lookup(nameStr) else { return nil }
    return runtimeValueToBoxedPointer(value)
}

@_cdecl("kk_env_set")
public func kk_env_set(
    _ env: UnsafeMutableRawPointer,
    _ name: UnsafePointer<CChar>,
    _ value: UnsafeMutableRawPointer
) -> Bool {
    let boxedEnv = Unmanaged<BoxedEnvironment>.fromOpaque(env).takeUnretainedValue()
    let nameStr = String(cString: name)
    let runtimeValue = boxedValueToRuntimeValue(value)
    do {
        try boxedEnv.environment.assign(nameStr, value: runtimeValue)
        return true
    } catch {
        return false
    }
}

@_cdecl("kk_env_push_scope")
public func kk_env_push_scope(_ env: UnsafeMutableRawPointer) {
    let boxedEnv = Unmanaged<BoxedEnvironment>.fromOpaque(env).takeUnretainedValue()
    try? boxedEnv.environment.pushScope()
}

@_cdecl("kk_env_pop_scope")
public func kk_env_pop_scope(_ env: UnsafeMutableRawPointer) {
    let boxedEnv = Unmanaged<BoxedEnvironment>.fromOpaque(env).takeUnretainedValue()
    boxedEnv.environment.popScope()
}

// MARK: - Internal Conversion

private func boxedValueToRuntimeValue(_ ptr: UnsafeMutableRawPointer) -> RuntimeValue {
    let box = borrowedBox(ptr)
    switch box.tag {
    case .integer: return .integer(Int(box.integerPayload))
    case .real: return .real(box.realPayload)
    case .boolean: return .boolean(box.booleanPayload)
    case .string: return .string(box.stringPayload)
    case .null: return .null
    case .array:
        let elements = box.arrayPayload.map { child -> RuntimeValue in
            let childPtr = Unmanaged.passUnretained(child).toOpaque()
            return boxedValueToRuntimeValue(childPtr)
        }
        return .array(elements)
    }
}

private func runtimeValueToBoxedPointer(_ value: RuntimeValue) -> UnsafeMutableRawPointer {
    switch value {
    case .integer(let intVal):
        let box = BoxedValue(tag: .integer)
        box.integerPayload = Int64(intVal)
        return retainedPointer(box)
    case .real(let realVal):
        let box = BoxedValue(tag: .real)
        box.realPayload = realVal
        return retainedPointer(box)
    case .boolean(let boolVal):
        let box = BoxedValue(tag: .boolean)
        box.booleanPayload = boolVal
        return retainedPointer(box)
    case .string(let strVal):
        let box = BoxedValue(tag: .string)
        box.stringPayload = strVal
        return retainedPointer(box)
    case .array(let arrayElements):
        let box = BoxedValue(tag: .array)
        box.arrayPayload = arrayElements.map { element -> BoxedValue in
            let ptr = runtimeValueToBoxedPointer(element)
            let child = Unmanaged<BoxedValue>.fromOpaque(ptr).takeRetainedValue()
            return child
        }
        return retainedPointer(box)
    default:
        let box = BoxedValue(tag: .null)
        return retainedPointer(box)
    }
}
