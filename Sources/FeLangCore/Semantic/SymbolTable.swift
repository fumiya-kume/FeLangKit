import Foundation

/// Symbol table for tracking variables, functions, and their types across scopes.
public final class SymbolTable: @unchecked Sendable {

    // MARK: - Symbol Types

    /// Represents a symbol in the symbol table.
    public struct Symbol: Equatable, Sendable {
        public let name: String
        public let type: FeType
        public let kind: SymbolKind
        public let position: SourcePosition
        public let isInitialized: Bool
        public let isUsed: Bool

        public init(
            name: String,
            type: FeType,
            kind: SymbolKind,
            position: SourcePosition,
            isInitialized: Bool = false,
            isUsed: Bool = false
        ) {
            self.name = name
            self.type = type
            self.kind = kind
            self.position = position
            self.isInitialized = isInitialized
            self.isUsed = isUsed
        }

        /// Create a copy of this symbol with modified properties.
        public func with(
            isInitialized: Bool? = nil,
            isUsed: Bool? = nil
        ) -> Symbol {
            return Symbol(
                name: name,
                type: type,
                kind: kind,
                position: position,
                isInitialized: isInitialized ?? self.isInitialized,
                isUsed: isUsed ?? self.isUsed
            )
        }
    }

    /// Kinds of symbols that can be stored in the symbol table.
    public enum SymbolKind: Equatable, Sendable {
        case variable
        case constant
        case parameter
        case function
        case procedure
        case type
    }

    /// Represents a scope in the symbol table.
    public struct Scope: Sendable {
        public let name: String
        public let kind: ScopeKind
        public let parentScope: String?
        public private(set) var symbols: [String: Symbol]

        public init(name: String, kind: ScopeKind, parentScope: String? = nil) {
            self.name = name
            self.kind = kind
            self.parentScope = parentScope
            self.symbols = [:]
        }

        mutating func addSymbol(_ symbol: Symbol) {
            symbols[symbol.name] = symbol
        }

        mutating func updateSymbol(_ symbol: Symbol) {
            symbols[symbol.name] = symbol
        }
    }

    /// Types of scopes.
    public enum ScopeKind: Equatable, Sendable {
        case global
        case function(name: String, returnType: FeType?)
        case procedure(name: String)
        case block
        case loop
    }

    // MARK: - Properties

    private var scopes: [String: Scope] = [:]
    private var scopeStack: [String] = []
    private var currentScopeId: String = "global"
    private var nextScopeId: Int = 1
    private let lock = NSLock()

    // MARK: - Initialization

    public init() {
        // Create global scope
        let globalScope = Scope(name: "global", kind: .global)
        scopes["global"] = globalScope
        scopeStack.append("global")

        // Add built-in functions
        addBuiltinFunctions()
    }

    // MARK: - Scope Management

    /// Push a new scope onto the scope stack.
    public func pushScope(kind: ScopeKind) -> String {
        lock.lock()
        defer { lock.unlock() }

        let scopeName = generateScopeName(for: kind)
        let newScope = Scope(name: scopeName, kind: kind, parentScope: currentScopeId)
        scopes[scopeName] = newScope
        scopeStack.append(scopeName)
        currentScopeId = scopeName

        return scopeName
    }

    /// Pop the current scope from the scope stack.
    @discardableResult
    public func popScope() -> String? {
        lock.lock()
        defer { lock.unlock() }

        guard scopeStack.count > 1 else {
            return nil // Cannot pop global scope
        }

        let poppedScope = scopeStack.removeLast()
        currentScopeId = scopeStack.last ?? "global"

        return poppedScope
    }

    /// Get the current scope.
    public var currentScope: Scope? {
        lock.lock()
        defer { lock.unlock() }
        return scopes[currentScopeId]
    }

    /// Get a scope by its identifier.
    public func getScope(_ scopeId: String) -> Scope? {
        lock.lock()
        defer { lock.unlock() }
        return scopes[scopeId]
    }

    /// Check if we're currently in a function or procedure scope.
    public var isInFunction: Bool {
        lock.lock()
        defer { lock.unlock() }

        for scopeId in scopeStack.reversed() {
            if let scope = scopes[scopeId] {
                switch scope.kind {
                case .function, .procedure:
                    return true
                default:
                    continue
                }
            }
        }
        return false
    }

    /// Check if we're currently in a loop scope.
    public var isInLoop: Bool {
        lock.lock()
        defer { lock.unlock() }

        for scopeId in scopeStack.reversed() {
            if let scope = scopes[scopeId],
               case .loop = scope.kind {
                return true
            }
        }
        return false
    }

    /// Get the current function scope (if any).
    public var currentFunction: (name: String, returnType: FeType?)? {
        lock.lock()
        defer { lock.unlock() }

        for scopeId in scopeStack.reversed() {
            if let scope = scopes[scopeId] {
                switch scope.kind {
                case .function(let name, let returnType):
                    return (name, returnType)
                case .procedure(let name):
                    return (name, nil)
                default:
                    continue
                }
            }
        }
        return nil
    }

    // MARK: - Symbol Management

    /// Declare a symbol in the current scope.
    public func declare(
        name: String,
        type: FeType,
        kind: SymbolKind,
        position: SourcePosition,
        isInitialized: Bool = false
    ) -> Result<Void, SemanticError> {
        lock.lock()
        defer { lock.unlock() }

        guard var currentScope = scopes[currentScopeId] else {
            return .failure(.undeclaredVariable(name, at: position))
        }

        // Check if symbol already exists in current scope
        if currentScope.symbols[name] != nil {
            return .failure(.variableAlreadyDeclared(name, at: position))
        }

        let symbol = Symbol(
            name: name,
            type: type,
            kind: kind,
            position: position,
            isInitialized: isInitialized
        )

        currentScope.addSymbol(symbol)
        scopes[currentScopeId] = currentScope

        return .success(())
    }

    /// Look up a symbol by name, searching through scope hierarchy.
    public func lookup(_ name: String) -> Symbol? {
        lock.lock()
        defer { lock.unlock() }

        // Search from current scope up to global scope
        for scopeId in scopeStack.reversed() {
            if let scope = scopes[scopeId],
               let symbol = scope.symbols[name] {
                return symbol
            }
        }

        return nil
    }

    /// Mark a symbol as used.
    public func markAsUsed(_ name: String, at position: SourcePosition) -> Result<Void, SemanticError> {
        lock.lock()
        defer { lock.unlock() }

        // Find the symbol in scope hierarchy
        for scopeId in scopeStack.reversed() {
            if let scope = scopes[scopeId],
               let symbol = scope.symbols[name] {
                let updatedSymbol = symbol.with(isUsed: true)
                var updatedScope = scope
                updatedScope.updateSymbol(updatedSymbol)
                scopes[scopeId] = updatedScope
                return .success(())
            }
        }

        return .failure(.undeclaredVariable(name, at: position))
    }

    /// Mark a symbol as initialized.
    public func markAsInitialized(_ name: String, at position: SourcePosition) -> Result<Void, SemanticError> {
        lock.lock()
        defer { lock.unlock() }

        // Find the symbol in scope hierarchy
        for scopeId in scopeStack.reversed() {
            if let scope = scopes[scopeId],
               let symbol = scope.symbols[name] {
                let updatedSymbol = symbol.with(isInitialized: true)
                var updatedScope = scope
                updatedScope.updateSymbol(updatedSymbol)
                scopes[scopeId] = updatedScope
                return .success(())
            }
        }

        return .failure(.undeclaredVariable(name, at: position))
    }

    /// Check if a symbol exists in the current scope only.
    public func existsInCurrentScope(_ name: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard let currentScope = scopes[currentScopeId] else {
            return false
        }

        return currentScope.symbols[name] != nil
    }

    /// Get all symbols in a specific scope.
    public func getSymbols(in scopeId: String) -> [Symbol] {
        lock.lock()
        defer { lock.unlock() }

        guard let scope = scopes[scopeId] else {
            return []
        }

        return Array(scope.symbols.values)
    }

    /// Get all unused symbols for warning generation.
    public func getUnusedSymbols() -> [Symbol] {
        lock.lock()
        defer { lock.unlock() }

        var unusedSymbols: [Symbol] = []

        for scope in scopes.values {
            for symbol in scope.symbols.values {
                if !symbol.isUsed && symbol.kind != .function && symbol.kind != .procedure {
                    unusedSymbols.append(symbol)
                }
            }
        }

        return unusedSymbols
    }

    // MARK: - Helper Methods

    private func generateScopeName(for kind: ScopeKind) -> String {
        let name: String
        switch kind {
        case .global:
            name = "global"
        case .function(let funcName, _):
            name = "function_\(funcName)"
        case .procedure(let procName):
            name = "procedure_\(procName)"
        case .block:
            name = "block_\(nextScopeId)"
        case .loop:
            name = "loop_\(nextScopeId)"
        }

        nextScopeId += 1
        return name
    }

    private func addBuiltinFunctions() {
        // Built-in I/O functions
        let readLineType = FeType.function(parameters: [], returnType: .string)
        let writeLineType = FeType.function(parameters: [.string], returnType: nil)
        let writeType = FeType.function(parameters: [.string], returnType: nil)

        // Built-in conversion functions
        let toStringType = FeType.function(parameters: [.integer], returnType: .string)
        let toIntegerType = FeType.function(parameters: [.string], returnType: .integer)
        let toRealType = FeType.function(parameters: [.string], returnType: .real)

        // Built-in math functions
        let sqrtType = FeType.function(parameters: [.real], returnType: .real)
        let absType = FeType.function(parameters: [.real], returnType: .real)

        let builtins: [(String, FeType, SymbolKind)] = [
            ("readLine", readLineType, .function),
            ("writeLine", writeLineType, .procedure),
            ("write", writeType, .procedure),
            ("toString", toStringType, .function),
            ("toInteger", toIntegerType, .function),
            ("toReal", toRealType, .function),
            ("sqrt", sqrtType, .function),
            ("abs", absType, .function)
        ]

        guard var globalScope = scopes["global"] else { return }

        for (name, type, kind) in builtins {
            let symbol = Symbol(
                name: name,
                type: type,
                kind: kind,
                position: SourcePosition(line: 0, column: 0, offset: 0),
                isInitialized: true,
                isUsed: false
            )
            globalScope.addSymbol(symbol)
        }

        scopes["global"] = globalScope
    }
}

// MARK: - Debug Support

extension SymbolTable {
    /// Get a debug description of the current symbol table state.
    public var debugDescription: String {
        lock.lock()
        defer { lock.unlock() }

        var result = "SymbolTable Debug Information:\n"
        result += "Current scope: \(currentScopeId)\n"
        result += "Scope stack: \(scopeStack.joined(separator: " -> "))\n\n"

        for scopeId in scopeStack {
            if let scope = scopes[scopeId] {
                result += "Scope: \(scopeId) (\(scope.kind))\n"
                if let parent = scope.parentScope {
                    result += "  Parent: \(parent)\n"
                }

                for symbol in scope.symbols.values.sorted(by: { $0.name < $1.name }) {
                    let flags = [
                        symbol.isInitialized ? "init" : "",
                        symbol.isUsed ? "used" : ""
                    ].compactMap { $0.isEmpty ? nil : $0 }.joined(separator: ", ")

                    result += "  \(symbol.name): \(symbol.type) (\(symbol.kind))"
                    if !flags.isEmpty {
                        result += " [\(flags)]"
                    }
                    result += "\n"
                }
                result += "\n"
            }
        }

        return result
    }
}
