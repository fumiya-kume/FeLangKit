import FeLangCore

public struct MethodSlot: Equatable, Sendable {
    public let index: Int
    public let methodName: String
    public let declaringClass: String
    public let method: MethodDefinition

    public init(index: Int, methodName: String, declaringClass: String, method: MethodDefinition) {
        self.index = index
        self.methodName = methodName
        self.declaringClass = declaringClass
        self.method = method
    }
}

public struct VTable: Equatable, Sendable {
    public let className: String
    public private(set) var slots: [MethodSlot]
    public private(set) var nameToSlot: [String: Int]

    public init(className: String) {
        self.className = className
        self.slots = []
        self.nameToSlot = [:]
    }

    public mutating func addOrOverride(methodName: String, declaringClass: String, method: MethodDefinition) {
        if let existingSlotIndex = nameToSlot[methodName] {
            slots[existingSlotIndex] = MethodSlot(
                index: existingSlotIndex,
                methodName: methodName,
                declaringClass: declaringClass,
                method: method
            )
        } else {
            let newIndex = slots.count
            nameToSlot[methodName] = newIndex
            slots.append(MethodSlot(
                index: newIndex,
                methodName: methodName,
                declaringClass: declaringClass,
                method: method
            ))
        }
    }

    public func resolve(methodName: String) -> MethodSlot? {
        guard let slotIndex = nameToSlot[methodName] else { return nil }
        return slots[slotIndex]
    }

    public func resolve(slotIndex: Int) -> MethodSlot? {
        guard slotIndex >= 0, slotIndex < slots.count else { return nil }
        return slots[slotIndex]
    }
}

public struct InterfaceDefinition: Equatable, Sendable {
    public let name: String
    public let methodSignatures: [String: InterfaceMethodSignature]

    public init(name: String, methodSignatures: [String: InterfaceMethodSignature] = [:]) {
        self.name = name
        self.methodSignatures = methodSignatures
    }
}

public struct InterfaceMethodSignature: Equatable, Sendable {
    public let name: String
    public let parameterCount: Int
    public let parameterTypes: [DataType]
    public let returnType: DataType?

    public init(name: String, parameterCount: Int, parameterTypes: [DataType] = [], returnType: DataType? = nil) {
        self.name = name
        self.parameterCount = parameterCount
        self.parameterTypes = parameterTypes
        self.returnType = returnType
    }
}

public struct ITable: Equatable, Sendable {
    public let className: String
    public let interfaceName: String
    public private(set) var methodToVTableSlot: [String: Int]

    public init(className: String, interfaceName: String) {
        self.className = className
        self.interfaceName = interfaceName
        self.methodToVTableSlot = [:]
    }

    public mutating func map(interfaceMethod: String, toVTableSlot slotIndex: Int) {
        methodToVTableSlot[interfaceMethod] = slotIndex
    }

    public func resolve(methodName: String) -> Int? {
        return methodToVTableSlot[methodName]
    }
}

public enum MethodCallKind: Equatable, Sendable {
    case directCall(MethodDefinition)
    case virtualDispatch(slotIndex: Int)
    case interfaceDispatch(interfaceName: String, methodName: String)
}
