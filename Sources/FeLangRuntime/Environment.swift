import Foundation

/// Manages variable scopes and bindings during runtime execution.
public final class Environment: @unchecked Sendable {
    /// A single scope containing variable bindings
    private struct Scope {
        var variables: [String: RuntimeValue] = [:]
        var constants: Set<String> = []
    }

    /// Stack of scopes (innermost scope is last)
    private var scopes: [Scope] = []

    /// Maximum allowed scope depth to prevent stack overflow
    private let maxScopeDepth: Int

    /// Current recursion depth for function calls
    private var callDepth: Int = 0

    /// Maximum allowed call depth
    private let maxCallDepth: Int

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
    public func define(_ name: String, value: RuntimeValue, isConstant: Bool = false) {
        guard var currentScope = scopes.last else { return }
        currentScope.variables[name] = value
        if isConstant {
            currentScope.constants.insert(name)
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

    /// Assigns a new value to an existing variable.
    public func assign(_ name: String, value: RuntimeValue) throws {
        // Check if it's a constant
        if isConstant(name) {
            throw RuntimeError.cannotAssignToConstant(name: name)
        }

        // Find and update the variable
        for index in (0..<scopes.count).reversed() {
            if scopes[index].variables[name] != nil {
                scopes[index].variables[name] = value
                return
            }
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

    /// Represents a captured environment snapshot including constant metadata.
    public struct CapturedEnvironment {
        public let values: [String: RuntimeValue]
        public let constants: Set<String>

        public init(values: [String: RuntimeValue], constants: Set<String>) {
            self.values = values
            self.constants = constants
        }
    }

    /// Imports variables from a dictionary into the current scope.
    public func importVariables(_ variables: [String: RuntimeValue]) {
        for (name, value) in variables {
            define(name, value: value)
        }
    }

    /// Imports variables from a captured environment, preserving constant metadata.
    public func importVariables(_ captured: CapturedEnvironment) {
        for (name, value) in captured.values {
            define(name, value: value, isConstant: captured.constants.contains(name))
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

    /// Creates a snapshot of the current environment for closures, including constant metadata.
    public func captureEnvironmentWithConstants() -> CapturedEnvironment {
        var capturedValues: [String: RuntimeValue] = [:]
        var capturedConstants: Set<String> = []
        for scope in scopes {
            for (name, value) in scope.variables {
                capturedValues[name] = value
            }
            capturedConstants.formUnion(scope.constants)
        }
        return CapturedEnvironment(values: capturedValues, constants: capturedConstants)
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
}
