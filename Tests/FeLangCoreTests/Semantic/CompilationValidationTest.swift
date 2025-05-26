import Testing
import Foundation
@testable import FeLangCore

@Suite("Compilation Validation Tests")
struct CompilationValidationTest {
    
    @Test("SemanticAnalyzer can be instantiated")
    func testSemanticAnalyzerInstantiation() {
        let analyzer = SemanticAnalyzer()
        #expect(analyzer != nil)
    }
    
    @Test("TypeChecker can be instantiated")  
    func testTypeCheckerInstantiation() {
        let symbolTable = SymbolTable()
        let typeChecker = TypeChecker(symbolTable: symbolTable)
        #expect(typeChecker != nil)
    }
    
    @Test("SymbolTable can be instantiated")
    func testSymbolTableInstantiation() {
        let symbolTable = SymbolTable()
        #expect(symbolTable != nil)
    }
    
    @Test("Parser with semantic analysis can be instantiated")
    func testParserWithSemanticAnalysisInstantiation() {
        var options = Parser.Options()
        options.performSemanticAnalysis = true
        let parser = Parser(options: options)
        #expect(parser != nil)
    }
    
    @Test("FeType enumeration works correctly")
    func testFeTypeEnumeration() {
        let intType = FeType.integer
        let realType = FeType.real
        let stringType = FeType.string
        
        #expect(intType.description == "integer")
        #expect(realType.description == "real")
        #expect(stringType.description == "string")
        
        // Test compatibility
        #expect(intType.isCompatible(with: realType))
        #expect(!intType.isCompatible(with: stringType))
    }
    
    @Test("SemanticError enumeration works correctly")
    func testSemanticErrorEnumeration() {
        let position = SourcePosition(line: 1, column: 1, offset: 0)
        let error = SemanticError.typeMismatch(expected: .integer, actual: .string, at: position)
        
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("Type mismatch"))
    }
    
    @Test("SemanticAnalysisResult can be created")
    func testSemanticAnalysisResultCreation() {
        let symbolTable = SymbolTable()
        let result = SemanticAnalysisResult(
            isSuccessful: true,
            errors: [],
            warnings: [],
            symbolTable: symbolTable
        )
        
        #expect(result.isSuccessful)
        #expect(!result.hasErrors)
        #expect(!result.hasWarnings)
        #expect(result.issueCount == 0)
    }
    
    @Test("Symbol table operations work correctly")
    func testSymbolTableOperations() {
        let symbolTable = SymbolTable()
        let position = SourcePosition(line: 1, column: 1, offset: 0)
        
        // Declare a variable
        let result = symbolTable.declare(
            name: "testVar",
            type: .integer,
            kind: .variable,
            position: position,
            isInitialized: true
        )
        
        #expect(result.isSuccess)
        
        // Look it up
        let symbol = symbolTable.lookup("testVar")
        #expect(symbol != nil)
        #expect(symbol?.type == .integer)
        #expect(symbol?.kind == .variable)
    }
    
    @Test("Basic type checking works")
    func testBasicTypeChecking() {
        let symbolTable = SymbolTable()
        let typeChecker = TypeChecker(symbolTable: symbolTable)
        
        // Check literal types
        let intLiteral = Expression.literal(.integer(42))
        let stringLiteral = Expression.literal(.string("hello"))
        
        let intType = typeChecker.checkExpression(intLiteral)
        let stringType = typeChecker.checkExpression(stringLiteral)
        
        #expect(intType == .integer)
        #expect(stringType == .string)
    }
}