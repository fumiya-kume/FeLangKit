import XCTest
@testable import FeLangCore

final class SymbolTableTests: XCTestCase {
    var symbolTable: SymbolTable!

    override func setUp() {
        super.setUp()
        symbolTable = SymbolTable()
    }

    override func tearDown() {
        symbolTable = nil
        super.tearDown()
    }

    func testDeclareSymbolDirectly() throws {
        // Test the new declare method that accepts Symbol directly
        let symbol = SymbolTable.Symbol(
            name: "testVar",
            type: .integer,
            kind: .variable,
            position: SourcePosition(line: 1, column: 1, offset: 0),
            isInitialized: false
        )

        let result = symbolTable.declare(symbol)
        
        switch result {
        case .success:
            // Verify the symbol was added
            let lookupResult = symbolTable.lookup("testVar")
            XCTAssertNotNil(lookupResult)
            XCTAssertEqual(lookupResult?.name, "testVar")
            XCTAssertEqual(lookupResult?.type, .integer)
            XCTAssertEqual(lookupResult?.kind, .variable)
        case .failure(let error):
            XCTFail("Failed to declare symbol: \(error)")
        }
    }

    func testDeclareSymbolDirectlyDuplicateError() throws {
        // Test that declaring a symbol twice fails with the correct error
        let symbol = SymbolTable.Symbol(
            name: "testVar",
            type: .integer,
            kind: .variable,
            position: SourcePosition(line: 1, column: 1, offset: 0),
            isInitialized: false
        )

        // First declaration should succeed
        let firstResult = symbolTable.declare(symbol)
        XCTAssertTrue(firstResult.isSuccess)

        // Second declaration should fail
        let secondResult = symbolTable.declare(symbol)
        switch secondResult {
        case .success:
            XCTFail("Expected failure for duplicate symbol declaration")
        case .failure(let error):
            if case .variableAlreadyDeclared(let name, _) = error {
                XCTAssertEqual(name, "testVar")
            } else {
                XCTFail("Expected variableAlreadyDeclared error, got: \(error)")
            }
        }
    }

    func testBuiltinFunctionsExist() throws {
        // Test that built-in functions are properly initialized
        let builtinFunctions = ["readLine", "writeLine", "write", "toString", "toInteger", "toReal", "sqrt", "abs"]
        
        for functionName in builtinFunctions {
            let symbol = symbolTable.lookup(functionName)
            XCTAssertNotNil(symbol, "Built-in function '\(functionName)' should exist")
            XCTAssertTrue(symbol?.kind == .function || symbol?.kind == .procedure, 
                         "Built-in '\(functionName)' should be a function or procedure")
        }
    }

    func testScopeManagement() throws {
        // Test scope push/pop functionality
        let initialScope = symbolTable.currentScope?.name
        XCTAssertEqual(initialScope, "global")

        // Push a function scope
        let functionScopeId = symbolTable.pushScope(kind: .function(name: "testFunc", returnType: .integer))
        XCTAssertEqual(symbolTable.currentScope?.name, functionScopeId)
        XCTAssertTrue(symbolTable.isInFunction)

        // Pop the scope
        let poppedScope = symbolTable.popScope()
        XCTAssertEqual(poppedScope, functionScopeId)
        XCTAssertEqual(symbolTable.currentScope?.name, "global")
        XCTAssertFalse(symbolTable.isInFunction)
    }
}

// Helper extension for Result checking
extension Result {
    var isSuccess: Bool {
        switch self {
        case .success:
            return true
        case .failure:
            return false
        }
    }
}