import Foundation
import FeLangCore

/// Manages variable scopes and bindings during runtime execution.
public final class Environment: @unchecked Sendable {
    /// A single scope containing variable bindings
    private struct Scope {
        var variables: [String: RuntimeValue] = [:]
        var constants: Set<String> = []
        var types: [String: DataType] = [:]
    }

    /// Stack of scopes (innermost scope is last)
    private var scopes: [Scope] = []

    /// Maximum allowed scope depth to prevent stack overflow
    private let maxScopeDepth: Int

    /// Current recursion depth for function calls
    private var callDepth: Int = 0

    /// Maximum allowed call depth
    private let maxCallDepth: Int

    /// Record type definitions (global, not scope-dependent)
    private var recordDefinitions: [String: [RecordField]] = [:]

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

    /// Defines a new variable in the current scope.
    public func define(_ name: String, value: RuntimeValue, isConstant: Bool = false, type: DataType? = nil) {
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
            return
        }

        throw RuntimeError.undefinedVariable(name: name)
    }

    /// Gets a variable, throwing if not found.
    public func get(_ name: String) throws -> RuntimeValue {
        guard let value = lookup(name) else {
            throw RuntimeError.undefinedVariable(name: name)
        }
        return value
    }

    // MARK: - Bulk Operations

    /// Represents a captured environment snapshot including constant metadata and type information.
    public struct CapturedEnvironment {
        public let values: [String: RuntimeValue]
        public let constants: Set<String>
        public let types: [String: DataType]

        public init(values: [String: RuntimeValue], constants: Set<String>, types: [String: DataType] = [:]) {
            self.values = values
            self.constants = constants
            self.types = types
        }
    }

    /// Imports variables from a dictionary into the current scope.
    public func importVariables(_ variables: [String: RuntimeValue]) {
        for (name, value) in variables {
            define(name, value: value)
        }
    }

    /// Imports variables from a captured environment, preserving constant metadata and type information.
    public func importVariables(_ captured: CapturedEnvironment) {
        for (name, value) in captured.values {
            let type = captured.types[name]
            define(name, value: value, isConstant: captured.constants.contains(name), type: type)
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

    /// Creates a snapshot of the current environment for closures, including constant metadata and type information.
    /// This correctly handles shadowing: if an outer constant is shadowed by an inner non-constant,
    /// the captured binding will be non-constant.
    public func captureEnvironmentWithConstants() -> CapturedEnvironment {
        var capturedValues: [String: RuntimeValue] = [:]
        var capturedConstants: Set<String> = []
        var capturedTypes: [String: DataType] = [:]
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
        return CapturedEnvironment(values: capturedValues, constants: capturedConstants, types: capturedTypes)
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
}
