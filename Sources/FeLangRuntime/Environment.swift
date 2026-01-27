import Foundation
import FeLangCore

/// Manages variable scopes and bindings during runtime execution.
public final class Environment: @unchecked Sendable {
    /// A single scope containing variable bindings
    private struct Scope {
        var variables: [String: RuntimeValue] = [:]
        var constants: Set<String> = []
        var types: [String: DataType] = [:]
        var uninitialized: Set<String> = []
    }

    /// Stack of scopes (innermost scope is last)
    private var scopes: [Scope] = []

    /// Maximum allowed scope depth to prevent stack overflow
    private let maxScopeDepth: Int

    /// Current recursion depth for function calls
    private var callDepth: Int = 0

    /// Maximum allowed call depth
    private let maxCallDepth: Int

    /// Record type definitions.
    ///
    /// Note:
    /// - These definitions are intentionally **global** within an `Environment`
    ///   instance and are **not** tied to the lexical / runtime scopes managed
    ///   by `scopes`.
    /// - This differs from variable bindings, which are pushed/popped with
    ///   `pushScope`/`popScope`. Record (type) declarations are treated as
    ///   language-level, module-wide definitions that remain visible across all
    ///   scopes once declared, similar to how many languages handle type
    ///   declarations.
    /// - If per-scope record types are ever required, they should be modeled
    ///   separately (e.g. by making record definitions part of `Scope`) instead
    ///   of changing this global behavior.
    /// - TODO: Consider making this thread-safe (e.g., using a concurrent dictionary or lock)
    ///   if multiple threads can define/lookup records concurrently.
    private var recordDefinitions: [String: [RecordField]] = [:]

    /// Class definitions (similar to record definitions, globally scoped).
    private var classDefinitions: [String: ClassDefinition] = [:]

    // MARK: - Initialization

    public init(maxScopeDepth: Int = 1000, maxCallDepth: Int = 500) {
        self.maxScopeDepth = maxScopeDepth
        self.maxCallDepth = maxCallDepth
        // Create initial global scope
        scopes.append(Scope())
    }

    // MARK: - Scope Management

    /// Creates a new nested scope.
    public func pushScope() throws {
        guard scopes.count < maxScopeDepth else {
            throw RuntimeError.stackOverflow
        }
        scopes.append(Scope())
    }

    /// Removes the innermost scope.
    public func popScope() {
        guard scopes.count > 1 else { return }
        scopes.removeLast()
    }

    /// Clears the innermost scope without removing it from the stack.
    /// This is used for loop optimization to reuse the same scope across iterations
    /// instead of repeatedly pushing and popping new scopes.
    public func clearCurrentScope() {
        guard scopes.count > 1 else { return }
        let lastIndex = scopes.count - 1
        scopes[lastIndex].variables.removeAll(keepingCapacity: true)
        scopes[lastIndex].constants.removeAll(keepingCapacity: true)
        scopes[lastIndex].types.removeAll(keepingCapacity: true)
        scopes[lastIndex].uninitialized.removeAll(keepingCapacity: true)
    }

    /// Returns the current scope depth.
    public var scopeDepth: Int {
        scopes.count
    }

    // MARK: - Call Stack Management

    /// Enters a function call.
    public func enterCall() throws {
        callDepth += 1
        guard callDepth < maxCallDepth else {
            callDepth -= 1
            throw RuntimeError.stackOverflow
        }
    }

    /// Exits a function call.
    public func exitCall() {
        if callDepth > 0 {
            callDepth -= 1
        }
    }

    // MARK: - Variable Operations

    /// Defines a new variable in the global (first) scope.
    ///
    /// - Parameters:
    ///   - name: The variable name
    ///   - value: The initial value
    ///   - type: Optional declared type for type checking
    ///   - isInitialized: Whether the variable is initialized (default: true)
    ///
    /// - Note: This method always defines the variable in the first (global) scope,
    ///   regardless of the current scope depth. This is used for global variable
    ///   declarations that should be accessible from all scopes.
    public func defineGlobal(
        _ name: String,
        value: RuntimeValue,
        type: DataType? = nil,
        isInitialized: Bool = true
    ) {
        guard !scopes.isEmpty else { return }
        scopes[0].variables[name] = value
        scopes[0].constants.remove(name)
        if let type = type {
            scopes[0].types[name] = type
        } else {
            scopes[0].types.removeValue(forKey: name)
        }
        if isInitialized {
            scopes[0].uninitialized.remove(name)
        } else {
            scopes[0].uninitialized.insert(name)
        }
    }

    /// Defines a new variable in the current scope.
    ///
    /// - Parameters:
    ///   - name: The variable name
    ///   - value: The initial value
    ///   - isConstant: Whether this is a constant (default: false)
    ///   - type: Optional declared type for type checking
    ///   - isInitialized: Whether the variable is initialized (default: true)
    ///
    /// - Note: If a variable with the same name already exists in the current scope,
    ///   this method will overwrite it. The constant status is updated on
    ///   redefinition: if `isConstant` is false, any previous constant flag for
    ///   this name is removed. The initialization status is also updated: if
    ///   `isInitialized` is true, the name is removed from the `uninitialized`
    ///   set; otherwise, it is added to `uninitialized`. This ensures that both
    ///   constant and initialization state are consistent after redefinition.
    public func define(
        _ name: String,
        value: RuntimeValue,
        isConstant: Bool = false,
        type: DataType? = nil,
        isInitialized: Bool = true
    ) {
        guard var currentScope = scopes.last else { return }
        currentScope.variables[name] = value
        // Update constant status - remove if not constant (handles redefinition)
        if isConstant {
            currentScope.constants.insert(name)
        } else {
            currentScope.constants.remove(name)
        }
        // Update type info - remove if nil (handles redefinition)
        if let type = type {
            currentScope.types[name] = type
        } else {
            currentScope.types.removeValue(forKey: name)
        }
        // Track initialization status
        if isInitialized {
            currentScope.uninitialized.remove(name)
        } else {
            currentScope.uninitialized.insert(name)
        }
        scopes[scopes.count - 1] = currentScope
    }

    /// Looks up a variable by name, searching from innermost to outermost scope.
    public func lookup(_ name: String) -> RuntimeValue? {
        for scope in scopes.reversed() {
            if let value = scope.variables[name] {
                return value
            }
        }
        return nil
    }

    /// Checks if a variable exists.
    public func exists(_ name: String) -> Bool {
        lookup(name) != nil
    }

    /// Checks if a name refers to a constant.
    public func isConstant(_ name: String) -> Bool {
        for scope in scopes.reversed() {
            if scope.constants.contains(name) {
                return true
            }
            if scope.variables[name] != nil {
                // Found the variable but it's not a constant
                return false
            }
        }
        return false
    }

    /// Checks if a variable is uninitialized.
    public func isUninitialized(_ name: String) -> Bool {
        for scope in scopes.reversed() {
            if scope.uninitialized.contains(name) {
                return true
            }
            if scope.variables[name] != nil {
                // Found the variable but it's not uninitialized
                return false
            }
        }
        return false
    }

    /// Looks up the declared type of a variable.
    public func lookupType(_ name: String) -> DataType? {
        for scope in scopes.reversed() {
            if let type = scope.types[name] {
                return type
            }
            if scope.variables[name] != nil {
                // Variable exists but no type recorded
                return nil
            }
        }
        return nil
    }

    /// Assigns a new value to an existing variable.
    public func assign(_ name: String, value: RuntimeValue) throws {
        // Check if it's a constant
        if isConstant(name) {
            throw RuntimeError.cannotAssignToConstant(name: name)
        }

        // Find and update the variable
        for index in (0..<scopes.count).reversed() where scopes[index].variables[name] != nil {
            scopes[index].variables[name] = value
            // Mark as initialized when assigned
            scopes[index].uninitialized.remove(name)
            return
        }

        throw RuntimeError.undefinedVariable(name: name)
    }

    /// Gets a variable, throwing if not found or uninitialized.
    /// Uses single-pass lookup to avoid traversing the scope stack multiple times.
    public func get(_ name: String) throws -> RuntimeValue {
        for scope in scopes.reversed() {
            if scope.uninitialized.contains(name) {
                throw RuntimeError.uninitializedVariable(name: name)
            }
            if let value = scope.variables[name] {
                return value
            }
        }
        throw RuntimeError.undefinedVariable(name: name)
    }

    // MARK: - Bulk Operations

    /// Represents a captured environment snapshot including constant metadata, type information, and initialization status.
    public struct CapturedEnvironment {
        public let values: [String: RuntimeValue]
        public let constants: Set<String>
        public let types: [String: DataType]
        public let uninitialized: Set<String>

        public init(
            values: [String: RuntimeValue],
            constants: Set<String>,
            types: [String: DataType] = [:],
            uninitialized: Set<String> = []
        ) {
            self.values = values
            self.constants = constants
            self.types = types
            self.uninitialized = uninitialized
        }
    }

    /// Imports variables from a dictionary into the current scope.
    public func importVariables(_ variables: [String: RuntimeValue]) {
        for (name, value) in variables {
            define(name, value: value)
        }
    }

    /// Imports variables from a captured environment, preserving constant metadata, type information, and initialization status.
    public func importVariables(_ captured: CapturedEnvironment) {
        for (name, value) in captured.values {
            let type = captured.types[name]
            let isInitialized = !captured.uninitialized.contains(name)
            define(name, value: value, isConstant: captured.constants.contains(name), type: type, isInitialized: isInitialized)
        }
    }

    /// Imports variables with constant metadata.
    public func importVariables(_ variables: [String: RuntimeValue], constants: Set<String>) {
        for (name, value) in variables {
            define(name, value: value, isConstant: constants.contains(name))
        }
    }

    /// Exports the current scope's variables.
    public func exportCurrentScope() -> [String: RuntimeValue] {
        scopes.last?.variables ?? [:]
    }

    /// Creates a snapshot of the current environment for closures (without constant metadata).
    /// - Note: For closures that need to preserve constant semantics, use `captureEnvironmentWithConstants()` instead.
    public func captureEnvironment() -> [String: RuntimeValue] {
        var captured: [String: RuntimeValue] = [:]
        for scope in scopes {
            for (name, value) in scope.variables {
                captured[name] = value
            }
        }
        return captured
    }

    /// Creates a snapshot of the current environment for closures, including constant metadata, type information, and initialization status.
    /// This correctly handles shadowing: if an outer constant is shadowed by an inner non-constant,
    /// the captured binding will be non-constant.
    public func captureEnvironmentWithConstants() -> CapturedEnvironment {
        var capturedValues: [String: RuntimeValue] = [:]
        var capturedConstants: Set<String> = []
        var capturedTypes: [String: DataType] = [:]
        var capturedUninitialized: Set<String> = []
        for scope in scopes {
            for (name, value) in scope.variables {
                capturedValues[name] = value
                // Update constant status based on current scope's binding
                // Inner scope shadows outer scope, so we update (not union) the constant flag
                if scope.constants.contains(name) {
                    capturedConstants.insert(name)
                } else {
                    // Non-constant in this scope shadows any outer constant
                    capturedConstants.remove(name)
                }
                // Update initialization status based on current scope's binding
                if scope.uninitialized.contains(name) {
                    capturedUninitialized.insert(name)
                } else {
                    // Initialized in this scope shadows any outer uninitialized
                    capturedUninitialized.remove(name)
                }
            }
            // Capture type information for type checking in closures
            // When a variable is shadowed, update or clear type info based on the inner scope
            for name in scope.variables.keys {
                if let type = scope.types[name] {
                    capturedTypes[name] = type
                } else {
                    // Variable exists in this scope but has no type - remove any outer type
                    capturedTypes.removeValue(forKey: name)
                }
            }
        }
        return CapturedEnvironment(
            values: capturedValues,
            constants: capturedConstants,
            types: capturedTypes,
            uninitialized: capturedUninitialized
        )
    }

    // MARK: - Debugging

    /// Returns all variable names visible in the current scope.
    public var visibleVariables: [String] {
        var names: Set<String> = []
        for scope in scopes {
            names.formUnion(scope.variables.keys)
        }
        return Array(names).sorted()
    }

    // MARK: - Record Type Definitions

    /// Defines a new record type.
    /// - Parameters:
    ///   - name: The name of the record type
    ///   - fields: The fields of the record type
    public func defineRecord(_ name: String, fields: [RecordField]) {
        recordDefinitions[name] = fields
    }

    /// Looks up a record type definition by name.
    /// - Parameter name: The name of the record type to look up
    /// - Returns: The record fields if found, nil otherwise
    public func lookupRecordDefinition(_ name: String) -> [RecordField]? {
        return recordDefinitions[name]
    }

    // MARK: - Class Definitions

    /// Defines a new class.
    /// - Parameters:
    ///   - name: The name of the class
    ///   - definition: The class definition
    public func defineClass(_ name: String, definition: ClassDefinition) {
        classDefinitions[name] = definition
    }

    /// Looks up a class definition by name.
    /// - Parameter name: The name of the class to look up
    /// - Returns: The class definition if found, nil otherwise
    public func lookupClassDefinition(_ name: String) -> ClassDefinition? {
        return classDefinitions[name]
    }
}
