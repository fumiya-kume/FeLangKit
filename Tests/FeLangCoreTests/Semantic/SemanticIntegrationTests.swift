import Testing
import Foundation
@testable import FeLangCore

@Suite("Semantic Integration Tests")
struct SemanticIntegrationTests {
    
    // MARK: - Test Helpers
    
    private func createParserWithSemantics() -> Parser {
        var options = Parser.Options()
        options.performSemanticAnalysis = true
        return Parser(options: options)
    }
    
    // MARK: - End-to-End Integration Tests
    
    @Test("Valid program with semantic analysis")
    func testValidProgramWithSemanticAnalysis() throws {
        let parser = createParserWithSemantics()
        
        let sourceCode = """
        variable x: integer ← 42
        variable y: integer ← x + 10
        constant PI: real ← 3.14159
        """
        
        let result = try parser.parseWithAnalysis(sourceCode)
        
        #expect(result.isSuccessful)
        #expect(result.statements.count == 3)
        #expect(result.semanticAnalysis != nil)
        #expect(result.semanticAnalysis?.errors.isEmpty == true)
        
        // Check symbol table has correct entries
        let symbolTable = result.semanticAnalysis!.symbolTable
        let xSymbol = symbolTable.lookup("x")
        let ySymbol = symbolTable.lookup("y")
        let piSymbol = symbolTable.lookup("PI")
        
        #expect(xSymbol?.type == .integer)
        #expect(ySymbol?.type == .integer)
        #expect(piSymbol?.type == .real)
        #expect(piSymbol?.kind == .constant)
    }
    
    @Test("Program with semantic errors")
    func testProgramWithSemanticErrors() throws {
        let parser = createParserWithSemantics()
        
        let sourceCode = """
        variable x: integer ← "hello"
        variable y: integer ← x
        y ← true
        """
        
        let result = try parser.parseWithAnalysis(sourceCode)
        
        #expect(!result.isSuccessful)
        #expect(result.statements.count == 3)
        #expect(result.semanticAnalysis != nil)
        #expect(!result.semanticAnalysis!.errors.isEmpty)
        
        // Should have multiple type mismatch errors
        let typeMismatchErrors = result.semanticAnalysis!.errors.compactMap { error in
            if case .typeMismatch = error {
                return error
            }
            return nil
        }
        
        #expect(typeMismatchErrors.count >= 2)
    }
    
    @Test("Function declaration and call with semantic analysis")
    func testFunctionDeclarationAndCallWithSemanticAnalysis() throws {
        let parser = createParserWithSemantics()
        
        let sourceCode = """
        function add(a: integer, b: integer): integer
        begin
            return a + b
        end
        
        variable result: integer ← add(10, 20)
        """
        
        let result = try parser.parseWithAnalysis(sourceCode)
        
        #expect(result.isSuccessful)
        #expect(result.semanticAnalysis?.errors.isEmpty == true)
        
        // Check function is in symbol table
        let symbolTable = result.semanticAnalysis!.symbolTable
        let addFunction = symbolTable.lookup("add")
        
        #expect(addFunction?.kind == .function)
        if case .function(let params, let returnType) = addFunction?.type {
            #expect(params == [.integer, .integer])
            #expect(returnType == .integer)
        } else {
            #expect(Bool(false), "Expected function type")
        }
    }
    
    @Test("Function call with wrong arguments")
    func testFunctionCallWithWrongArguments() throws {
        let parser = createParserWithSemantics()
        
        let sourceCode = """
        function add(a: integer, b: integer): integer
        begin
            return a + b
        end
        
        variable result: integer ← add("hello", 20)
        """
        
        let result = try parser.parseWithAnalysis(sourceCode)
        
        #expect(!result.isSuccessful)
        #expect(!result.semanticAnalysis!.errors.isEmpty)
        
        // Should have argument type mismatch error
        let hasArgTypeError = result.semanticAnalysis!.errors.contains { error in
            if case .argumentTypeMismatch = error {
                return true
            }
            return false
        }
        #expect(hasArgTypeError)
    }
    
    @Test("Control flow with semantic analysis")
    func testControlFlowWithSemanticAnalysis() throws {
        let parser = createParserWithSemantics()
        
        let sourceCode = """
        variable x: integer ← 10
        variable condition: boolean ← x > 5
        
        if condition then
            variable localVar: integer ← x * 2
            x ← localVar + 1
        end if
        """
        
        let result = try parser.parseWithAnalysis(sourceCode)
        
        #expect(result.isSuccessful)
        #expect(result.semanticAnalysis?.errors.isEmpty == true)
    }
    
    @Test("Scope validation with semantic analysis")
    func testScopeValidationWithSemanticAnalysis() throws {
        let parser = createParserWithSemantics()
        
        let sourceCode = """
        variable x: integer ← 10
        
        if x > 5 then
            variable localVar: integer ← 20
        end if
        
        localVar ← 30
        """
        
        let result = try parser.parseWithAnalysis(sourceCode)
        
        #expect(!result.isSuccessful)
        #expect(!result.semanticAnalysis!.errors.isEmpty)
        
        // Should have undeclared variable error for localVar outside its scope
        let hasUndeclaredError = result.semanticAnalysis!.errors.contains { error in
            if case .undeclaredVariable("localVar", at: _) = error {
                return true
            }
            return false
        }
        #expect(hasUndeclaredError)
    }
    
    @Test("Array operations with semantic analysis")
    func testArrayOperationsWithSemanticAnalysis() throws {
        let parser = createParserWithSemantics()
        
        let sourceCode = """
        variable numbers: array[10] of integer
        numbers[0] ← 42
        variable firstNumber: integer ← numbers[0]
        """
        
        let result = try parser.parseWithAnalysis(sourceCode)
        
        #expect(result.isSuccessful)
        #expect(result.semanticAnalysis?.errors.isEmpty == true)
        
        // Check array type in symbol table
        let symbolTable = result.semanticAnalysis!.symbolTable
        let arraySymbol = symbolTable.lookup("numbers")
        
        if case .array(let elementType, let dimensions) = arraySymbol?.type {
            #expect(elementType == .integer)
            #expect(dimensions == [10])
        } else {
            #expect(Bool(false), "Expected array type")
        }
    }
    
    @Test("Invalid array access with semantic analysis")
    func testInvalidArrayAccessWithSemanticAnalysis() throws {
        let parser = createParserWithSemantics()
        
        let sourceCode = """
        variable x: integer ← 10
        variable value: integer ← x[0]
        """
        
        let result = try parser.parseWithAnalysis(sourceCode)
        
        #expect(!result.isSuccessful)
        #expect(!result.semanticAnalysis!.errors.isEmpty)
        
        // Should have invalid array access error
        let hasArrayAccessError = result.semanticAnalysis!.errors.contains { error in
            if case .invalidArrayAccess = error {
                return true
            }
            return false
        }
        #expect(hasArrayAccessError)
    }
    
    @Test("Unused variable warnings")
    func testUnusedVariableWarnings() throws {
        let parser = createParserWithSemantics()
        
        let sourceCode = """
        variable usedVar: integer ← 10
        variable unusedVar: integer ← 20
        variable result: integer ← usedVar + 5
        """
        
        let result = try parser.parseWithAnalysis(sourceCode)
        
        #expect(result.isSuccessful)
        #expect(result.semanticAnalysis?.hasWarnings == true)
        
        // Should have unused variable warning
        let hasUnusedWarning = result.semanticAnalysis!.warnings.contains { warning in
            if case .unusedVariable("unusedVar", at: _) = warning {
                return true
            }
            return false
        }
        #expect(hasUnusedWarning)
    }
    
    @Test("Complex expression type checking")
    func testComplexExpressionTypeChecking() throws {
        let parser = createParserWithSemantics()
        
        let sourceCode = """
        variable x: integer ← 10
        variable y: real ← 3.14
        variable result: real ← x + y * 2.0
        variable comparison: boolean ← result > 15.0
        """
        
        let result = try parser.parseWithAnalysis(sourceCode)
        
        #expect(result.isSuccessful)
        #expect(result.semanticAnalysis?.errors.isEmpty == true)
        
        // Check types are correctly inferred
        let symbolTable = result.semanticAnalysis!.symbolTable
        let resultSymbol = symbolTable.lookup("result")
        let comparisonSymbol = symbolTable.lookup("comparison")
        
        #expect(resultSymbol?.type == .real)
        #expect(comparisonSymbol?.type == .boolean)
    }
    
    @Test("Parser without semantic analysis")
    func testParserWithoutSemanticAnalysis() throws {
        // Use default parser (no semantic analysis)
        let parser = Parser()
        
        let sourceCode = """
        variable x: integer ← "hello"
        """
        
        let result = try parser.parseWithAnalysis(sourceCode)
        
        // Should succeed syntactically but no semantic analysis
        #expect(result.isSuccessful) // No semantic errors since analysis is disabled
        #expect(result.semanticAnalysis == nil)
    }
    
    // MARK: - Convenience Method Tests
    
    @Test("Validate with semantics convenience method")
    func testValidateWithSemanticsConvenienceMethod() {
        let parser = createParserWithSemantics()
        
        let validCode = "variable x: integer ← 42"
        let invalidCode = "variable x: integer ← \"hello\""
        
        #expect(parser.validateWithSemantics(validCode))
        #expect(!parser.validateWithSemantics(invalidCode))
    }
    
    @Test("Collect all errors convenience method")
    func testCollectAllErrorsConvenienceMethod() {
        let parser = createParserWithSemantics()
        
        let sourceCode = """
        variable x: integer ← "hello"
        variable y: integer ← x
        undeclaredVar ← 42
        """
        
        let errors = parser.collectAllErrors(sourceCode)
        
        #expect(!errors.isEmpty)
        #expect(errors.count >= 2) // At least type mismatch and undeclared variable
    }
}