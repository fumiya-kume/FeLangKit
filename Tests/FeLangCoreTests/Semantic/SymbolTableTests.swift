import Testing
import Foundation
@testable import FeLangCore

@Suite("SymbolTable Tests")
struct SymbolTableTests {

    // MARK: - Basic Symbol Management Tests

    @Test("Basic symbol declaration and lookup")
    func testBasicSymbolDeclarationAndLookup() throws {
        let symbolTable = SymbolTable()
        let position = SourcePosition(line: 1, column: 1, offset: 0)

        // Declare a variable
        let result = symbolTable.declare(
            name: "x",
            type: .integer,
            kind: .variable,
            position: position
        )

        switch result {
        case .success:
            // Expected
            break
        case .failure:
            Issue.record("Expected success for symbol declaration")
        }

        // Look up the variable
        let symbol = symbolTable.lookup("x")
        #expect(symbol != nil)
        #expect(symbol?.name == "x")
        #expect(symbol?.type == .integer)
        #expect(symbol?.kind == .variable)
        #expect(symbol?.isInitialized == false)
        #expect(symbol?.isUsed == false)
    }

    @Test("Symbol redeclaration error")
    func testSymbolRedeclarationError() throws {
        let symbolTable = SymbolTable()
        let position = SourcePosition(line: 1, column: 1, offset: 0)

        // First declaration should succeed
        let firstResult = symbolTable.declare(
            name: "x",
            type: .integer,
            kind: .variable,
            position: position
        )
        switch firstResult {
        case .success:
            // Expected
            break
        case .failure:
            Issue.record("Expected success for first symbol declaration")
        }

        // Second declaration should fail
        let secondResult = symbolTable.declare(
            name: "x",
            type: .real,
            kind: .variable,
            position: position
        )

        switch secondResult {
        case .failure(.variableAlreadyDeclared("x", at: _)):
            // Expected
            break
        default:
            Issue.record("Expected variableAlreadyDeclared error")
        }
    }

    @Test("Symbol not found lookup")
    func testSymbolNotFoundLookup() throws {
        let symbolTable = SymbolTable()

        let symbol = symbolTable.lookup("nonexistent")
        #expect(symbol == nil)
    }

    // MARK: - Scope Management Tests

    @Test("Basic scope management")
    func testBasicScopeManagement() throws {
        let symbolTable = SymbolTable()

        // Should start with global scope
        #expect(symbolTable.currentScope?.kind == .global)

        // Push a function scope
        let functionScopeId = symbolTable.pushScope(kind: .function(name: "testFunc", returnType: .integer))
        #expect(functionScopeId.contains("function_testFunc"))
        #expect(symbolTable.currentScope?.kind == .function(name: "testFunc", returnType: .integer))

        // Pop the scope
        let poppedScopeId = symbolTable.popScope()
        #expect(poppedScopeId == functionScopeId)
        #expect(symbolTable.currentScope?.kind == .global)

        // Cannot pop global scope
        let globalPop = symbolTable.popScope()
        #expect(globalPop == nil)
    }

    @Test("Nested scope variable lookup")
    func testNestedScopeVariableLookup() throws {
        let symbolTable = SymbolTable()
        let position = SourcePosition(line: 1, column: 1, offset: 0)

        // Declare variable in global scope
        _ = symbolTable.declare(name: "global_var", type: .string, kind: .variable, position: position)

        // Push function scope
        _ = symbolTable.pushScope(kind: .function(name: "func", returnType: nil))

        // Declare variable in function scope
        _ = symbolTable.declare(name: "local_var", type: .integer, kind: .variable, position: position)

        // Should find both variables
        let globalVar = symbolTable.lookup("global_var")
        let localVar = symbolTable.lookup("local_var")

        #expect(globalVar?.name == "global_var")
        #expect(localVar?.name == "local_var")

        // Pop function scope
        _ = symbolTable.popScope()

        // Should still find global variable but not local
        let globalVarAfterPop = symbolTable.lookup("global_var")
        let localVarAfterPop = symbolTable.lookup("local_var")

        #expect(globalVarAfterPop?.name == "global_var")
        #expect(localVarAfterPop == nil)
    }

    @Test("Scope context queries")
    func testScopeContextQueries() throws {
        let symbolTable = SymbolTable()

        // Initially not in function or loop
        #expect(symbolTable.isInFunction == false)
        #expect(symbolTable.isInLoop == false)
        #expect(symbolTable.currentFunction == nil)

        // Push function scope
        _ = symbolTable.pushScope(kind: .function(name: "testFunc", returnType: .real))
        #expect(symbolTable.isInFunction == true)
        #expect(symbolTable.currentFunction?.name == "testFunc")
        #expect(symbolTable.currentFunction?.returnType == .real)

        // Push loop scope inside function
        _ = symbolTable.pushScope(kind: .loop)
        #expect(symbolTable.isInFunction == true)  // Still in function
        #expect(symbolTable.isInLoop == true)      // Now also in loop

        // Pop loop scope
        _ = symbolTable.popScope()
        #expect(symbolTable.isInFunction == true)
        #expect(symbolTable.isInLoop == false)

        // Pop function scope
        _ = symbolTable.popScope()
        #expect(symbolTable.isInFunction == false)
        #expect(symbolTable.currentFunction == nil)
    }

    // MARK: - Symbol State Management Tests

    @Test("Mark symbol as used")
    func testMarkSymbolAsUsed() throws {
        let symbolTable = SymbolTable()
        let position = SourcePosition(line: 1, column: 1, offset: 0)

        // Declare variable
        _ = symbolTable.declare(name: "x", type: .integer, kind: .variable, position: position)

        // Initially not used
        let symbol = symbolTable.lookup("x")
        #expect(symbol?.isUsed == false)

        // Mark as used
        let result = symbolTable.markAsUsed("x", at: position)
        switch result {
        case .success:
            // Expected
            break
        case .failure:
            Issue.record("Expected success for markAsUsed")
        }

        // Should now be marked as used
        let usedSymbol = symbolTable.lookup("x")
        #expect(usedSymbol?.isUsed == true)
    }

    @Test("Mark symbol as initialized")
    func testMarkSymbolAsInitialized() throws {
        let symbolTable = SymbolTable()
        let position = SourcePosition(line: 1, column: 1, offset: 0)

        // Declare variable
        _ = symbolTable.declare(name: "x", type: .integer, kind: .variable, position: position)

        // Initially not initialized
        let symbol = symbolTable.lookup("x")
        #expect(symbol?.isInitialized == false)

        // Mark as initialized
        let result = symbolTable.markAsInitialized("x", at: position)
        switch result {
        case .success:
            // Expected
            break
        case .failure:
            Issue.record("Expected success for markAsInitialized")
        }

        // Should now be marked as initialized
        let initializedSymbol = symbolTable.lookup("x")
        #expect(initializedSymbol?.isInitialized == true)
    }

    @Test("Mark nonexistent symbol errors")
    func testMarkNonexistentSymbolErrors() throws {
        let symbolTable = SymbolTable()
        let position = SourcePosition(line: 1, column: 1, offset: 0)

        // Try to mark nonexistent symbol as used
        let usedResult = symbolTable.markAsUsed("nonexistent", at: position)
        switch usedResult {
        case .failure(.undeclaredVariable("nonexistent", at: _)):
            // Expected
            break
        default:
            Issue.record("Expected undeclaredVariable error for markAsUsed")
        }

        // Try to mark nonexistent symbol as initialized
        let initResult = symbolTable.markAsInitialized("nonexistent", at: position)
        switch initResult {
        case .failure(.undeclaredVariable("nonexistent", at: _)):
            // Expected
            break
        default:
            Issue.record("Expected undeclaredVariable error for markAsInitialized")
        }
    }

    // MARK: - Built-in Functions Tests

    @Test("Built-in functions are available")
    func testBuiltinFunctionsAvailable() throws {
        let symbolTable = SymbolTable()

        // Test I/O functions
        let readLine = symbolTable.lookup("readLine")
        #expect(readLine?.kind == .function)
        #expect(readLine?.isInitialized == true)

        let writeLine = symbolTable.lookup("writeLine")
        #expect(writeLine?.kind == .procedure)
        #expect(writeLine?.isInitialized == true)

        // Test conversion functions
        let toString = symbolTable.lookup("toString")
        #expect(toString?.kind == .function)

        let toInteger = symbolTable.lookup("toInteger")
        #expect(toInteger?.kind == .function)

        // Test math functions
        let sqrt = symbolTable.lookup("sqrt")
        #expect(sqrt?.kind == .function)

        let abs = symbolTable.lookup("abs")
        #expect(abs?.kind == .function)
    }

    // MARK: - Utility Functions Tests

    @Test("Exists in current scope check")
    func testExistsInCurrentScope() throws {
        let symbolTable = SymbolTable()
        let position = SourcePosition(line: 1, column: 1, offset: 0)

        // Declare variable in global scope
        _ = symbolTable.declare(name: "global_var", type: .string, kind: .variable, position: position)
        #expect(symbolTable.existsInCurrentScope("global_var") == true)

        // Push new scope
        _ = symbolTable.pushScope(kind: .block)

        // Variable from parent scope should not exist in current scope only
        #expect(symbolTable.existsInCurrentScope("global_var") == false)

        // Declare variable in current scope
        _ = symbolTable.declare(name: "local_var", type: .integer, kind: .variable, position: position)
        #expect(symbolTable.existsInCurrentScope("local_var") == true)
    }

    @Test("Get symbols in scope")
    func testGetSymbolsInScope() throws {
        let symbolTable = SymbolTable()
        let position = SourcePosition(line: 1, column: 1, offset: 0)

        // Get global scope ID
        let globalScopeId = "global"

        // Declare some variables in global scope
        _ = symbolTable.declare(name: "var1", type: .integer, kind: .variable, position: position)
        _ = symbolTable.declare(name: "var2", type: .string, kind: .variable, position: position)

        let globalSymbols = symbolTable.getSymbols(in: globalScopeId)

        // Should include our variables plus built-in functions
        let ourSymbols = globalSymbols.filter { !["readLine", "writeLine", "write", "toString", "toInteger", "toReal", "sqrt", "abs"].contains($0.name) }
        #expect(ourSymbols.count == 2)

        let symbolNames = Set(ourSymbols.map { $0.name })
        #expect(symbolNames.contains("var1"))
        #expect(symbolNames.contains("var2"))
    }

    @Test("Get unused symbols")
    func testGetUnusedSymbols() throws {
        let symbolTable = SymbolTable()
        let position = SourcePosition(line: 1, column: 1, offset: 0)

        // Declare some variables
        _ = symbolTable.declare(name: "used_var", type: .integer, kind: .variable, position: position)
        _ = symbolTable.declare(name: "unused_var", type: .string, kind: .variable, position: position)

        // Mark one as used
        _ = symbolTable.markAsUsed("used_var", at: position)

        let unusedSymbols = symbolTable.getUnusedSymbols()
        let unusedNames = Set(unusedSymbols.map { $0.name })

        // Should include unused_var but not used_var
        #expect(unusedNames.contains("unused_var"))
        #expect(!unusedNames.contains("used_var"))

        // Built-in functions are unused by default but shouldn't be included
        #expect(!unusedNames.contains("readLine"))
    }

    // MARK: - Thread Safety Tests

    @Test("Concurrent access safety")
    func testConcurrentAccessSafety() async throws {
        let symbolTable = SymbolTable()
        let position = SourcePosition(line: 1, column: 1, offset: 0)

        // Perform concurrent operations
        await withTaskGroup(of: Void.self) { group in
            // Concurrent declarations
            for index in 0..<10 {
                group.addTask {
                    _ = symbolTable.declare(
                        name: "var\(index)",
                        type: .integer,
                        kind: .variable,
                        position: position
                    )
                }
            }

            // Concurrent lookups
            for index in 0..<10 {
                group.addTask {
                    _ = symbolTable.lookup("var\(index)")
                }
            }

            // Concurrent scope operations
            group.addTask {
                _ = symbolTable.pushScope(kind: .block)
                _ = symbolTable.popScope()
            }
        }

        // Verify state is consistent after concurrent operations
        let symbols = symbolTable.getSymbols(in: "global")
        #expect(symbols.count >= 10) // At least our variables plus built-ins
    }

    // MARK: - Debug Support Tests

    @Test("Debug description functionality")
    func testDebugDescription() throws {
        let symbolTable = SymbolTable()
        let position = SourcePosition(line: 1, column: 1, offset: 0)

        // Add some symbols and scopes
        _ = symbolTable.declare(name: "test_var", type: .integer, kind: .variable, position: position)
        _ = symbolTable.markAsUsed("test_var", at: position)

        _ = symbolTable.pushScope(kind: .function(name: "test_func", returnType: .string))
        _ = symbolTable.declare(name: "param", type: .integer, kind: .parameter, position: position, isInitialized: true)

        let description = symbolTable.debugDescription

        // Should contain scope information
        #expect(description.contains("SymbolTable Debug Information"))
        #expect(description.contains("Current scope:"))
        #expect(description.contains("Scope stack:"))
        #expect(description.contains("test_var"))
        #expect(description.contains("param"))
        #expect(description.contains("used"))
        #expect(description.contains("init"))

        _ = symbolTable.popScope()
    }

    // MARK: - Symbol Types and Kinds Tests

    @Test("Different symbol kinds")
    func testDifferentSymbolKinds() throws {
        let symbolTable = SymbolTable()
        let position = SourcePosition(line: 1, column: 1, offset: 0)

        // Test all symbol kinds
        _ = symbolTable.declare(name: "var", type: .integer, kind: .variable, position: position)
        _ = symbolTable.declare(name: "const", type: .string, kind: .constant, position: position)
        _ = symbolTable.declare(name: "param", type: .real, kind: .parameter, position: position)
        _ = symbolTable.declare(name: "func", type: .function(parameters: [.integer], returnType: .string), kind: .function, position: position)
        _ = symbolTable.declare(name: "proc", type: .function(parameters: [.string], returnType: nil), kind: .procedure, position: position)
        _ = symbolTable.declare(name: "type", type: .string, kind: .type, position: position)

        // Verify all can be looked up with correct kinds
        #expect(symbolTable.lookup("var")?.kind == .variable)
        #expect(symbolTable.lookup("const")?.kind == .constant)
        #expect(symbolTable.lookup("param")?.kind == .parameter)
        #expect(symbolTable.lookup("func")?.kind == .function)
        #expect(symbolTable.lookup("proc")?.kind == .procedure)
        #expect(symbolTable.lookup("type")?.kind == .type)
    }

    @Test("Complex type support")
    func testComplexTypeSupport() throws {
        let symbolTable = SymbolTable()
        let position = SourcePosition(line: 1, column: 1, offset: 0)

        // Test array type
        let arrayType = FeType.array(elementType: .integer, dimensions: [10, 20])
        _ = symbolTable.declare(name: "matrix", type: arrayType, kind: .variable, position: position)

        // Test record type
        let recordType = FeType.record(name: "Person", fields: ["name": .string, "age": .integer])
        _ = symbolTable.declare(name: "person", type: recordType, kind: .variable, position: position)

        // Test function type
        let functionType = FeType.function(parameters: [.string, .integer], returnType: .boolean)
        _ = symbolTable.declare(name: "validator", type: functionType, kind: .function, position: position)

        // Verify types are preserved
        #expect(symbolTable.lookup("matrix")?.type == arrayType)
        #expect(symbolTable.lookup("person")?.type == recordType)
        #expect(symbolTable.lookup("validator")?.type == functionType)
    }
}
